-- Deterministic UI work counts supplement human native acceptance; they do not
-- measure frame time or establish client layout and responsiveness.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, event = fixture.addon, fixture.eventFrame
event.scripts.OnEvent(event, "ADDON_LOADED", "DungeonPro")
SlashCmdList.DUNGEONPRO("")
local ui = addon.UI
GetLocale = function() return "enUS" end
addon.db.locale = "enUS"
for _, dungeon in ipairs(addon.dungeons) do if dungeon.key == "dm" then ui.dungeon = dungeon end end
ui.search, ui.range = "", false
local counts, total, catalogArt = {}, 0, {}
local function track(owner, key, name)
    local original = assert(owner[key], key)
    owner[key] = function(...)
        counts[name or key] = (counts[name or key] or 0) + 1
        if key == "PaintDungeonArt" and catalogArt[select(1, ...)] then
            counts.catalogArt = (counts.catalogArt or 0) + 1
        end
        return original(...)
    end
end
for _, key in ipairs({ "Context", "DungeonName", "DungeonArt", "PaintDungeonArt", "QuestRewards",
    "CachedQuestRewards", "Description", "QuestObjectives", "SearchFold", "QuestSourceSearchTerms" }) do
    track(addon, key)
end
track(addon.Planner, "New", "Planner.New")
track(addon.Entrances, "Get", "Entrance.Get")
for _, key in ipairs({ "GetTitleForQuestID", "IsOnQuest", "IsQuestFlaggedCompleted", "RequestLoadQuestByID" }) do
    track(C_QuestLog, key, "API." .. key)
end
local function check(condition, message)
    total = total + 1
    assert(condition, message)
end
local function reset() counts = {} end
local function count(key) return counts[key] or 0 end
ui:Refresh()
check(#ui.cards == #addon.dungeons and #ui.cards > 1, "actual catalogue is populated")
ui.catalogScroll:SetVerticalScroll(137)
local generation, query, scrollWrites = ui.catalogGeneration, ui.catalogQueryKey, ui.catalogScroll.scrollWrites
local cards = {}
for index, row in ipairs(ui.cards) do
    catalogArt[row.art] = true
    local titleSetter = row.title.SetText
    row.title.SetText = function(self, value)
        if value == self.text then counts.unchangedTitleWrites = (counts.unchangedTitleWrites or 0) + 1 end
        return titleSetter(self, value)
    end
    cards[index] = { row = row, click = row.scripts.OnClick, title = row.title.text,
        artwork = row.art.texture, match = row.matchQuestID, note = row.note.text,
        entrance = row.entranceControl, entranceBinding = row.entranceBinding,
        entranceClick = row.entranceControl and row.entranceControl.scripts.OnClick }
end
local database, character, dungeon = addon.db, addon.char, ui.dungeon
local function retained()
    check(ui.catalogGeneration == generation and ui.catalogQueryKey == query, "hover retains catalogue results generation")
    check(ui.catalogScroll.verticalScroll == 137 and ui.catalogScroll.scrollWrites == scrollWrites,
        "hover retains search reading position without scroll writes")
    check(addon.db == database and addon.char == character and ui.dungeon == dungeon, "hover retains current character and selection")
    for index, before in ipairs(cards) do
        local row = ui.cards[index]
        check(row == before.row and row.scripts.OnClick == before.click and row.title.text == addon.DungeonName(addon.dungeons[index])
            and row.art.texture == before.artwork and row.matchQuestID == before.match,
            "hover translates titles while retaining catalogue row identity, artwork and click ownership")
        check(row.entranceControl == before.entrance and row.entranceBinding == before.entranceBinding and
            (not row.entranceControl or row.entranceControl.scripts.OnClick == before.entranceClick),
            "hover retains per-card entrance controls and route ownership")
    end
end
local function bounded()
    check(count("Entrance.Get") <= 1, "hover does not resolve every dungeon entrance again")
    check(count("unchangedTitleWrites") == 0, "hover does not repeat native writes for unchanged catalogue titles")
    check(count("catalogArt") == 0 and count("PaintDungeonArt") <= 1 and count("DungeonArt") <= 1,
        "hover retains catalogue artwork with at most the active pane artwork pass")
    check(count("SearchFold") == 0 and count("QuestSourceSearchTerms") == 0, "hover does not rescan catalogue search sources")
    check(count("Context") <= 1 and count("Planner.New") <= 1, "hover builds at most the active quest pane model")
end
ui.language.scripts.OnEnter()
local session = assert(addon.Language.session)
reset()
session.rows[3].scripts.OnEnter()
check(addon.L("NEXT") == addon.locales.ruRU.NEXT and addon.db.locale == "enUS", "Russian hover translates without saving")
check(ui.cards[1].note.text ~= cards[1].note, "retained catalogue notes relocalize immediately")
bounded(); retained()
reset()
session.rows[2].scripts.OnEnter()
check(addon.L("NEXT") == addon.locales.enUS.NEXT, "next language hover translates immediately")
check(ui.cards[1].note.text == cards[1].note, "English hover restores retained catalogue note")
bounded(); retained()
reset()
session.rows[2].scripts.OnEnter()
check(next(counts) == nil, "same-row hover does not repeat model or API work")
reset()
session.rows[3].scripts.OnEnter()
addon.Language:Cancel(ui)
check(addon.db.locale == "enUS" and ui.cards[1].note.text == cards[1].note, "cancel restores committed catalogue text")
check(count("catalogArt") == 0, "cancel does not rebuild catalogue artwork")
retained()
ui.language.scripts.OnEnter()
session = assert(addon.Language.session)
reset()
session.rows[3].scripts.OnClick()
check(addon.db.locale == "ruRU" and addon.Language.session == nil, "click commits selected locale")
check(ui.catalogGeneration ~= generation and count("PaintDungeonArt") > 0, "commit performs normal fresh catalogue refresh")

-- A changed source member invalidates retained results rather than reusing the
-- old count/level/match proof merely because the tables still have one identity.
ui.language.scripts.OnEnter()
session = assert(addon.Language.session)
local source, sourceMinimum = addon.dungeons[1], addon.dungeons[1].minLevel
local beforeSourceChange = ui.catalogGeneration
source.minLevel = sourceMinimum + 1
reset(); session.rows[2].scripts.OnEnter()
check(ui.catalogGeneration ~= beforeSourceChange and count("catalogArt") > 0,
    "changed catalogue member falls back to a fresh validated result scan")
check(ui.cards[1].note.text:find(addon.L("CATALOG_COMPACT_META", source.minLevel, source.maxLevel, #source.quests), 1, true) ~= nil,
    "source change refresh publishes the new localized level range")
source.minLevel = sourceMinimum
addon.Language:Cancel(ui)
ui.search = ""; ui:Refresh()

-- A native setter can synchronously produce a newer search view and then write
-- its old argument. The older language repaint must preserve that new ownership.
ui.language.scripts.OnEnter()
session = assert(addon.Language.session)
local note = ui.cards[1].note
local setText, nestedGeneration, nestedText = note.SetText
local entered = false
note.SetText = function(self, value)
    if not entered then
        entered = true
        ui.search = "166"
        ui:Refresh()
        nestedGeneration, nestedText = ui.catalogGeneration, ui.cards[1].note.text
    end
    return setText(self, value)
end
session.rows[2].scripts.OnEnter()
note.SetText = setText
check(entered and nestedGeneration ~= nil, "native note setter exercises a synchronous replacement catalogue")
check(ui.catalogGeneration == nestedGeneration, "older preview does not replace newer catalogue generation")
check(ui.cards[1].note.text == nestedText and ui.search == "166", "older native note write cannot overwrite newer search text")
addon.Language:Cancel(ui)

-- Empty cached search results still have localized copy and a valid ownership
-- proof; repainting that notice must not repeat the unsuccessful catalogue scan.
ui.search = "99999999"
ui:Refresh()
local emptyGeneration = ui.catalogGeneration
check(ui.catalogNotice:IsShown(), "empty result fixture displays no-dungeon notice")
ui.language.scripts.OnEnter()
session = assert(addon.Language.session)
reset(); session.rows[2].scripts.OnEnter()
check(ui.catalogGeneration == emptyGeneration and count("catalogArt") == 0 and count("SearchFold") == 0,
    "empty retained results do not repeat filtering or artwork work")
check(ui.catalogNotice.text == addon.L("NO_DUNGEONS") and ui.catalogNotice:IsShown(),
    "empty retained results relocalize the visible notice")
addon.Language:Cancel(ui)

-- A previously proven asynchronous source match can expire without replacing
-- the source getter. A hover must revalidate it before retaining results/actions.
local sourceGetter, sourceValid = addon.QuestSourceSearchTerms, true
addon.QuestSourceSearchTerms = function(quest)
    if quest.id == 166 then
        return { { kind = "npc", text = "hover-source-match" } },
            function() return sourceValid end, function() return true end
    end
    return sourceGetter(quest)
end
ui.search = "hover-source-match"
ui:Refresh()
local sourceGeneration, staleCard = ui.catalogGeneration, ui.cards[1].scripts.OnClick
check(ui.cards[1]:IsShown() and ui.cards[1].matchQuestID == 166, "live source match enters retained filtered results")
sourceValid = false
ui.language.scripts.OnEnter()
session = assert(addon.Language.session)
reset(); session.rows[2].scripts.OnEnter()
check(ui.catalogGeneration ~= sourceGeneration and ui.catalogNotice:IsShown() and not ui.cards[1]:IsShown(),
    "expired source match forces a new filter scan and removes old result")
local selected = ui.dungeon
staleCard()
check(ui.dungeon == selected and ui.catalogNotice:IsShown(), "expired source match cannot activate its old card callback")
addon.Language:Cancel(ui)
addon.QuestSourceSearchTerms = sourceGetter
ui.search = ""; ui:Refresh()

-- Localized wing suffixes are addon text even when the base dungeon name comes
-- from the client. Retained artwork does not permit retaining the old suffix.
local zoneGetter = GetRealZoneText
GetRealZoneText = function() return "Client dungeon" end
addon.db.locale = "enUS"
ui:Refresh()
local lowerIndex
for index, sourceDungeon in ipairs(addon.dungeons) do
    if sourceDungeon.key == "lbrs" then lowerIndex = index end
end
local lowerCard = assert(ui.cards[assert(lowerIndex)])
check(lowerCard.title.text == addon.L("DUNGEON_WING_lower", "Client dungeon"),
    "actual lower-wing card has the client's base name and English UI suffix")
ui.language.scripts.OnEnter()
session = assert(addon.Language.session)
local beforeWingHover = ui.catalogGeneration
reset(); session.rows[3].scripts.OnEnter()
check(lowerCard.title.text == addon.DungeonName(addon.dungeons[lowerIndex])
    and lowerCard.title.text ~= addon.locales.enUS.DUNGEON_WING_lower:format("Client dungeon"),
    "Russian hover replaces the client-language base with the selected-language dungeon name")
check(ui.catalogGeneration == beforeWingHover and count("catalogArt") == 0,
    "empty-query wing relocalization retains catalogue artwork and results")
addon.Language:Cancel(ui)

ui.search = "Lower wing"
ui:Refresh()
check(ui.cards[1]:IsShown() and ui.cards[1].title.text:find("Lower wing", 1, true),
    "English free-text query matches the localized lower-wing name")
local englishWingGeneration = ui.catalogGeneration
ui.language.scripts.OnEnter()
session = assert(addon.Language.session)
session.rows[3].scripts.OnEnter()
check(ui.catalogGeneration ~= englishWingGeneration and ui.catalogNotice:IsShown() and not ui.cards[1]:IsShown(),
    "language-sensitive free-text search recomputes membership for the new wing suffix")
addon.Language:Cancel(ui)

ui.search = "166"
ui:Refresh()
local numericGeneration, numericClick = ui.catalogGeneration, ui.cards[1].scripts.OnClick
check(ui.cards[1]:IsShown() and ui.cards[1].matchQuestID == 166, "numeric query has one direct quest match")
ui.language.scripts.OnEnter()
session = assert(addon.Language.session)
reset(); session.rows[3].scripts.OnEnter()
check(ui.catalogGeneration == numericGeneration and ui.cards[1].scripts.OnClick == numericClick and count("catalogArt") == 0,
    "numeric query keeps its locale-independent match and action during hover")
addon.Language:Cancel(ui)
GetRealZoneText = zoneGetter
ui.search = ""; ui:Refresh()

-- A taller old-language row may finish its native SetHeight call after that
-- setter synchronously rendered a newer short-language layout. Repair both the
-- row height and following row anchor using the newer paint's ownership ledger.
ui.language.scripts.OnEnter()
session = assert(addon.Language.session)
local heightRow, followingRow = ui.cards[1], ui.cards[2]
local noteHeight, rowHeight = heightRow.note.GetStringHeight, heightRow.SetHeight
local nestedHeight, nestedAnchor, heightEntered
heightRow.note.GetStringHeight = function()
    return addon.L("NEXT") == addon.locales.ruRU.NEXT and 100 or 18
end
heightRow.SetHeight = function(self, value)
    if not heightEntered and value > 76 then
        heightEntered = true
        session.rows[2].scripts.OnEnter()
        nestedHeight, nestedAnchor = self.height, followingRow.point[3]
    end
    return rowHeight(self, value)
end
session.rows[3].scripts.OnEnter()
heightRow.note.GetStringHeight, heightRow.SetHeight = noteHeight, rowHeight
check(heightEntered and nestedHeight == 76, "old tall-language native setter triggers a newer short-language row")
check(type(nestedAnchor) == "number" and heightRow.height == nestedHeight and followingRow.point[3] == nestedAnchor,
    "old native row height and anchor cannot overwrite the newer language layout")
check(addon.L("NEXT") == addon.locales.enUS.NEXT, "reentrant layout retains the newer language selection")
addon.Language:Cancel(ui)

-- A getter may synchronously select another preview. A no-op text optimization
-- must revalidate the paint after readback before treating the old value as safe.
ui.language.scripts.OnEnter()
session = assert(addon.Language.session)
local titleGetter = ui.cards[1].title.GetText
local getterEntered = false
ui.cards[1].title.GetText = function(self)
    local previous = titleGetter(self)
    if not getterEntered then getterEntered = true; session.rows[2].scripts.OnEnter() end
    return previous
end
session.rows[3].scripts.OnEnter()
ui.cards[1].title.GetText = titleGetter
check(getterEntered and addon.L("NEXT") == addon.locales.enUS.NEXT,
    "native text getter reentry keeps the newer English preview")
check(ui.cards[1].note.text:find(addon.L("CATALOG_COMPACT_META", addon.dungeons[1].minLevel, addon.dungeons[1].maxLevel, #addon.dungeons[1].quests), 1, true) ~= nil,
    "superseded getter cannot leave older-language catalogue notes")
addon.Language:Cancel(ui)

-- The newer English paint can be a native text no-op because the old Russian
-- setter has not written yet. It must still own a binding that repairs that late write.
ui.language.scripts.OnEnter()
session = assert(addon.Language.session)
local noOpNote = ui.cards[1].note
local noOpSetter, englishNote, noteEntered = noOpNote.SetText, noOpNote.text, false
noOpNote.SetText = function(self, value)
    if not noteEntered and value ~= englishNote then
        noteEntered = true
        check(self.text == englishNote, "newer English paint starts with matching native text")
        session.rows[2].scripts.OnEnter()
    end
    return noOpSetter(self, value)
end
session.rows[3].scripts.OnEnter()
noOpNote.SetText = noOpSetter
check(noteEntered and addon.L("NEXT") == addon.locales.enUS.NEXT and noOpNote.text == englishNote,
    "newer no-op English binding repairs a late older Russian native write")
addon.Language:Cancel(ui)

-- A callback from an old picker cannot repaint a replacement database or frame.
ui.language.scripts.OnEnter()
session = assert(addon.Language.session)
local oldRow = session.rows[2].scripts.OnEnter
local savedDB = addon.db
addon.db = { locale = "enUS", window = savedDB.window }
reset(); oldRow()
check(next(counts) == nil and addon.db.locale == "enUS", "foreign database invalidates stale hover without model/API work")
addon.db = savedDB
addon.Language:Cancel(ui)

-- The native-shaped fixture normally ignores SetFont. Give a separate actual
-- TOC instance truthful font setters/readback and count warm direct/owned paths.
for _, ownedFonts in ipairs({ false, true }) do
    local fontFixture = assert(loadfile("tests/client_ui.lua"))("fixture")
    local fontAddon, fontMethods = fontFixture.addon, fontFixture.methods
    local nativeCalls, regionCalls = 0, {}
    local function native(region, method)
        nativeCalls = nativeCalls + 1
        local calls = regionCalls[region] or {}; regionCalls[region] = calls
        calls[method] = (calls[method] or 0) + 1
    end
    function fontMethods:SetFont(path, height, flags)
        native(self, "SetFont")
        self.fontPath, self.fontHeight, self.fontFlags = path, height, flags
        if self.kind ~= "FontObject" then return true end
    end
    function fontMethods:GetFont()
        if self.fontPath then return self.fontPath, self.fontHeight, self.fontFlags end
        if self.fontObject then
            local path, height, flags = self.fontObject:GetFont()
            return path, self.fontHeight or height, flags
        end
    end
    function fontMethods:SetFontObject(value)
        native(self, "SetFontObject")
        self.fontObject, self.fontPath, self.fontHeight, self.fontFlags = value, nil, nil, nil
    end
    function fontMethods:GetFontObject() return self.fontObject end
    function fontMethods:SetFontHeight(value) native(self, "SetFontHeight"); self.fontHeight = value end
    function fontMethods:GetFontString()
        self.nativeLabel = self.nativeLabel or self:CreateFontString()
        return self.nativeLabel
    end
    local oldCreator, oldFamily, oldHighlight = CreateFont, ChatFontNormal, GameFontHighlight
    local function makeFont()
        return setmetatable({ kind = "FontObject", fontPath = "Fonts\\ARIALN.TTF", fontHeight = 14, fontFlags = "" },
            { __index = fontMethods })
    end
    ChatFontNormal, GameFontHighlight = makeFont(), nil
    CreateFont = ownedFonts and function() return makeFont() end or nil
    fontFixture.eventFrame.scripts.OnEvent(fontFixture.eventFrame, "ADDON_LOADED", "DungeonPro")
    SlashCmdList.DUNGEONPRO("")
    local fontUI = fontAddon.UI
    fontAddon.db.locale = "enUS"
    for _, sourceDungeon in ipairs(fontAddon.dungeons) do if sourceDungeon.key == "dm" then fontUI.dungeon = sourceDungeon end end
    fontUI:Refresh(); fontUI:InspectQuest(166)
    fontUI.language.scripts.OnEnter()
    local fontSession = assert(fontAddon.Language.session)
    fontSession.rows[10].scripts.OnEnter()
    fontSession.rows[9].scripts.OnEnter()
    nativeCalls, regionCalls = 0, {}
    fontSession.rows[10].scripts.OnEnter()
    local warmChanges = nativeCalls
    check(warmChanges > 0 and fontUI.heading:GetFont() == "Fonts\\ARKai_T.ttf",
        "warm Chinese hover changes actual native fonts and renders the selected script")
    local duplicateWrites = 0
    for region, methodsForRegion in pairs(regionCalls) do
        if region.kind == "FontString" then
            for _, calls in pairs(methodsForRegion) do if calls > 1 then duplicateWrites = duplicateWrites + calls - 1 end end
        end
    end
    check(duplicateWrites == 0, "warm CJK preview does not repeat a native font setter on the same text region")
    nativeCalls, regionCalls = 0, {}
    fontSession.rows[10].scripts.OnEnter()
    check(nativeCalls == 0, "repeated same CJK row performs no native font mutations")
    fontAddon.Theme.RefreshFonts()
    fontUI:RefreshLanguagePreview()
    check(nativeCalls == 0, "warm same-source font refresh and pooled detail repaint avoid redundant native font setters")
    check(fontUI.heading:GetFont() == "Fonts\\ARKai_T.ttf" and fontAddon.db.locale == "enUS",
        "font optimization retains Chinese rendering without saving preview selection")
    fontAddon.Language:Cancel(fontUI)
    check(fontUI.heading:GetFont() == "Interface\\AddOns\\DungeonPro\\Media\\Fonts\\NotoSans-Regular.ttf",
        "CJK cancel restores the committed Latin/Cyrillic font")
    CreateFont, ChatFontNormal, GameFontHighlight = oldCreator, oldFamily, oldHighlight
end
print("Dungeon Pro language hover: PASS (" .. total .. " checks)")
