-- Deterministic UI work counts supplement human native acceptance; they do not
-- measure frame time or establish client layout and responsiveness.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, event = fixture.addon, fixture.eventFrame
event.scripts.OnEvent(event, "ADDON_LOADED", "DungeonPro")
SlashCmdList.DUNGEONPRO("")
local ui = addon.UI
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
    cards[index] = { row = row, click = row.scripts.OnClick, title = row.title.text,
        artwork = row.art.texture, match = row.matchQuestID, note = row.note.text }
end
local database, character, dungeon = addon.db, addon.char, ui.dungeon
local function retained()
    check(ui.catalogGeneration == generation and ui.catalogQueryKey == query, "hover retains catalogue results generation")
    check(ui.catalogScroll.verticalScroll == 137 and ui.catalogScroll.scrollWrites == scrollWrites,
        "hover retains search reading position without scroll writes")
    check(addon.db == database and addon.char == character and ui.dungeon == dungeon, "hover retains current character and selection")
    for index, before in ipairs(cards) do
        local row = ui.cards[index]
        check(row == before.row and row.scripts.OnClick == before.click and row.title.text == before.title
            and row.art.texture == before.artwork and row.matchQuestID == before.match,
            "hover retains catalogue row identity, title, artwork and click ownership")
    end
end
local function bounded()
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
check(ui.cards[1].note.text:find(addon.L("CATALOG_LEVELS", source.minLevel, source.maxLevel), 1, true) ~= nil,
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
check(lowerCard.title.text == addon.L("DUNGEON_WING_lower", "Client dungeon")
    and not lowerCard.title.text:find("Lower wing", 1, true), "Russian hover updates actual client-named wing suffix")
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
    if not heightEntered and value > 64 then
        heightEntered = true
        session.rows[2].scripts.OnEnter()
        nestedHeight, nestedAnchor = self.height, followingRow.point[5]
    end
    return rowHeight(self, value)
end
session.rows[3].scripts.OnEnter()
heightRow.note.GetStringHeight, heightRow.SetHeight = noteHeight, rowHeight
check(heightEntered and nestedHeight == 64, "old tall-language native setter triggers a newer short-language row")
check(heightRow.height == nestedHeight and followingRow.point[5] == nestedAnchor,
    "old native row height and anchor cannot overwrite the newer language layout")
check(addon.L("NEXT") == addon.locales.enUS.NEXT, "reentrant layout retains the newer language selection")
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
print("Dungeon Pro language hover: PASS (" .. total .. " checks)")
