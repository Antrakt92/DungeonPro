local methods, measurement, updateScrollRange = {}, nil, nil
function methods:SetSize(w, h)
    self.width, self.height = w, h
    if updateScrollRange then updateScrollRange(self) end
end
function methods:GetWidth() return self.width or 340 end
function methods:GetHeight() return self.height or 100 end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h; if updateScrollRange then updateScrollRange(self) end end
function methods:SetPoint(...) self.point = { ... } end
function methods:GetPoint() return unpack(self.point) end
function methods:ClearAllPoints() self.point = nil end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:SetText(value)
    self.text, self.fontSizeAtText, self.fontResetBeforeText = value, self.fontSize, self.fontPending == true
    self.fontPending = false
end
function methods:SetFont(path, size, flags)
    self.fontFamily = nil
    self.fontPath, self.fontSize, self.fontFlags, self.fontPending = path, size, flags, true
    return true
end
function methods:SetFontObject(font)
    self.fontFamily, self.fontPending = font, true
    if self.kind == "EditBox" then self.fontSize = font.fontSize or font.nativeHeight end
    if self.kind ~= "EditBox" and font.fontSize then self.fontSize,self.fontPath,self.fontFamily=font.fontSize,font.fontPath,font.family end
end
function methods:SetTextHeight(size) self.scaledText = true; self.fontSize, self.fontPending = size, true end
function methods:SetFontHeight(size) self.fontSize, self.fontPending = size, true end
function methods:SetShadowOffset(x,y) self.shadow={x,y} end
function methods:SetTextColor(...) self.textColor = { ... } end
function methods:SetTextInsets(...) self.textInsets = { ... } end
function methods:SetTexture(value) self.texture = value; return true end
function methods:SetTexCoord(...) self.texCoords={...} end
function methods:SetAtlas(value)self.atlas=value end
function methods:GetAtlas()return self.atlas end
function methods:SetRotation(value)self.rotation=value end
function methods:GetStringWidth()return #(self.text or "")*5 end
function methods:SetAlpha(value) self.alpha=value end
function methods:SetDesaturated(value) self.desaturated=value end
function methods:SetMotionScriptsWhileDisabled(value) self.disabledMotion=value end
function methods:GetText() return self.text or "" end
function methods:SetFocus() self.focused = true end
function methods:ClearFocus() self.focused = false end
function methods:HighlightText() self.highlighted = true end
function methods:SetEnabled(value) self.enabled = value end
function methods:SetHighlightTexture(asset)
    assert((type(asset) == "string" and asset ~= "") or (type(asset) == "number" and asset > 0),
        "SetHighlightTexture requires an asset; nil is not supported")
    self.highlightTexture = asset
end
function methods:GetStringHeight() if measurement then return measurement(self) end; return 18 end
function methods:SetScale(value) self.scale = value end
function methods:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
function methods:SetVerticalScroll(value) self.verticalScroll = value; self.scrollWrites = (self.scrollWrites or 0) + 1 end
function methods:GetVerticalScroll() self.scrollReads = (self.scrollReads or 0) + 1; return self.verticalScroll or 0 end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:SetClampedToScreen(value) self.clamped = value end
function methods:IsShown() return self.shown end
function methods:Hide() self.shown = false end
function methods:Show() self.shown = true end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
for _, name in ipairs({ "SetJustifyH", "SetAllPoints", "SetColorTexture",
    "SetFrameStrata", "EnableMouse", "SetMovable", "RegisterForDrag",
    "StartMoving", "StopMovingOrSizing", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "SetAutoFocus" }) do methods[name] = function() end end
function methods:SetScrollChild(child)
    self.scrollChild = child
    updateScrollRange(self)
end
function methods:GetVerticalScrollRange()
    return math.max(0, (self.scrollChild and self.scrollChild:GetHeight() or 0) - self:GetHeight())
end
-- Model only the pinned SecureScrollTemplates visibility/range contract, not native pixels or engine clamping.
local function templateRangeChanged(scroll, _, range)
    range = math.floor(range or scroll:GetVerticalScrollRange())
    scroll.templateRangeEvents = (scroll.templateRangeEvents or 0) + 1
    local bar = scroll.ScrollBar
    bar.minimum, bar.maximum = 0, range
    bar.value = math.min(bar.value or 0, range)
    local shown = range ~= 0 or not scroll.scrollBarHideable
    for _, part in ipairs({ bar, bar.ScrollUpButton, bar.ScrollDownButton, bar.ThumbTexture }) do part:SetShown(shown) end
end
updateScrollRange = function(changed)
    local scroll = changed.kind == "ScrollFrame" and changed or changed.parent
    if scroll and scroll.scrollChild and (changed == scroll or changed == scroll.scrollChild) and scroll.scripts.OnScrollRangeChanged then
        scroll.scripts.OnScrollRangeChanged(scroll, 0, scroll:GetVerticalScrollRange())
    end
end
local function object(kind, name, parent, template)
    local frame = setmetatable({ scripts = {}, name = name, kind = kind, parent = parent }, { __index = methods })
    if kind == "EditBox" then frame.SetFontHeight = false end
    if template == "UIPanelScrollFrameTemplate" then
        frame.ScrollBar = setmetatable({ scripts = {}, shown = true, value = 0 }, { __index = methods })
        for _, key in ipairs({ "ScrollUpButton", "ScrollDownButton", "ThumbTexture" }) do
            frame.ScrollBar[key] = setmetatable({ scripts = {}, shown = true }, { __index = methods })
        end
        frame.scripts.OnScrollRangeChanged = templateRangeChanged
        frame.templateRangeHandler = templateRangeChanged
        frame.scripts.OnVerticalScroll = function() end
        frame.scripts.OnMouseWheel = function() end
        frame.templateVerticalHandler, frame.templateWheelHandler = frame.scripts.OnVerticalScroll, frame.scripts.OnMouseWheel
    end
    if name then _G[name] = frame end
    return frame
end
function methods:CreateTexture() local texture = object(); texture.shown = true; return texture end
function methods:CreateFontString() return object() end
CreateFrame = object
UIParent, UISpecialFrames = object(), {}
local screenWidth, screenHeight = 1920, 480
GetScreenWidth = function() return screenWidth end
GetScreenHeight = function() return screenHeight end
GetLocale = function() return "enUS" end
ChatFontNormal = { nativeHeight = 14 }
local addon, done = {}, { [7] = true }
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Database/SearchCaseFold.lua"))("DungeonPro", addon)
assert(loadfile("Core/Search.lua"))("DungeonPro", addon)
assert(loadfile("Locales/Strings.lua"))("DungeonPro", addon)
assert(loadfile("Locales/Translations.lua"))("DungeonPro", addon)
assert(loadfile("Core/Planner.lua"))("DungeonPro", addon)
addon.db = { locale = "enUS", window = { x = 999999, y = -999999 } }
addon.char = { filters = { range = "true", preparation = 1, includeUnavailable = "true", other = "preserve" } }
addon.Context = function() return {
    level = 20, completed = function(id) return done[id] or false end,
    active = function(id) return id == 6 end,
} end
addon.QuestName = function(id) return "Quest " .. id end
addon.DungeonName = function(d) return d.name end
addon.DungeonArt = function() return "art" end
addon.PaintDungeonArt = function(texture, dungeon)
    local ok = texture:SetTexture(addon.DungeonArt(dungeon))
    texture:SetShown(ok == true)
    return ok == true
end
addon.Description = function() return "Description" end
addon.quests = {}
for _, id in ipairs({ 1, 2, 3, 4, 5, 6, 7, 100, 101 }) do
    addon.quests[id] = { id = id, minLevel = 1, requirementsKnown = true,
        start = { mapID = 1, x = 10 + id, y = 20, name = "Giver " .. id } }
end
addon.quests[100].requires = { { ids = { 1 } }, { ids = { 2 } } }
addon.quests[101].requires = { { ids = { 1 } } }
addon.quests[3].requirementsKnown = false
addon.quests[4].startsInside = true
addon.quests[5].minLevel = 30
addon.dungeons = { { key = "fixture", name = "Dungeon", minLevel = 10, maxLevel = 30,
    coverage = "reviewed", quests = { 100, 101, 3, 4, 5, 6, 7 } } }
assert(loadfile("UI/Theme.lua"))("DungeonPro", addon)
assert(loadfile("UI/QuestStatus.lua"))("DungeonPro", addon)
assert(loadfile("Core/QuestTree.lua"))("DungeonPro", addon)
assert(loadfile("Core/QuestRowInfo.lua"))("DungeonPro", addon)
assert(loadfile("Core/DungeonStatus.lua"))("DungeonPro", addon)
assert(loadfile("UI/QuestListRewards.lua"))("DungeonPro", addon)
assert(loadfile("UI/QuestNavigation.lua"))("DungeonPro", addon)
assert(loadfile("UI/QuestHistory.lua"))("DungeonPro", addon)
assert(loadfile("UI/PreparationOverview.lua"))("DungeonPro", addon)
assert(loadfile("UI/Window.lua"))("DungeonPro", addon)
function methods:SetToplevel(value) self.topLevel=value end
function methods:Raise() self.raises=(self.raises or 0)+1 end
local ui, total = addon.UI, 0
local function hasDestination(coordinates) return ui:NavigationDestination(coordinates) ~= nil end
local function dispatchGiverMap()
    local action, giver = ui:NavigationDestination(false)
    if action then ui:DispatchDetail(action, true, giver) end
end
local function planSummary()
    local p=ui.currentPlan;local c=p and p.counts or {}
    return addon.L("SUMMARY",(c.ACTIVE or 0)+(c.READY or 0),c.COMPLETED or 0,(c.LOCKED or 0)+(c.AVAILABLE or 0),c.UNKNOWN or 0)
end
local function planCoverage()
    local p=ui.currentPlan
    return addon.L(not p and "PICK"or p.notice or(p.unknown and "PARTIAL"or(p.ready and "PREPARED"or"NOT_PREPARED")), p and p.notice == "NO_CHARACTER_QUESTS" and addon.L("FILTER_QUEST_ALL") or nil)
end
local function check(name, fn)
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err))
    total = total + 1; print("PASS " .. name)
end
local function visibleRows()
    local result = {}
    for _, row in ipairs(ui.rows) do if row.shown and not row.heading and not row.questTreeAnchor and (not row.questTreeNode or row.questTreeTarget) then result[#result + 1] = row end end
    return result
end
-- Exercise the retained planner grouping model directly; no mode widget is exposed.
local function togglePreparationFixture()
    ui.preparation = not ui.preparation
    ui:RefreshQuests(); ui:RefreshDetail()
end
local function canGoBack() return #ui.detailHistory > 0 or ui:CanReturnToOverview() end
ui:Create(); ui.frame:Show(); ui.dungeon = addon.dungeons[1]; ui:Refresh()
check("Dungeon Pro uses the localized product title and its own escape-close frame", function()
    assert(ui.title.text == addon.L("TITLE") and ui.title.text == "Dungeon Pro")
    assert(ui.frame.name == "DungeonProWindow" and _G.DungeonProWindow == ui.frame)
    assert(UISpecialFrames[#UISpecialFrames] == "DungeonProWindow" and _G.DungeonPrepWindow == nil)
    local count = 0
    for _, strings in pairs(addon.locales) do
        assert(strings.TITLE == "Dungeon Pro")
        count = count + 1
    end
    assert(count == 10)
end)
check("Character filters default safely and reject non-boolean saved values", function()
    assert(not ui.range and not ui.preparation and not ui.includeUnavailable)
    assert(addon.L(ui.characterButton.filterLabelKey) == addon.L("FILTER_QUEST_MINE"))
    assert(addon.char.filters.includeUnavailable == "true" and addon.char.filters.other == "preserve")
end)
check("Window fits a short screen and clamps a stale saved position", function()
    assert(ui.frame.scale * 700 <= screenHeight * 0.92 + 0.001)
    assert(ui.frame.scale * 1100 <= screenWidth * 0.92 + 0.001)
    assert(ui.frame.clamped)
    local _, _, _, x, y = ui.frame:GetPoint()
    assert(math.abs(x) < 999999 and math.abs(y) < 999999)
end)
check("Quest view retains every eligible target", function() assert(#visibleRows() == 7) end)
check("Preparation lists both independent prerequisites and deduplicates a shared step", function()
    togglePreparationFixture()
    local rows = visibleRows()
    assert(#rows == 6 and rows[1].title.text == "Quest 1" and rows[2].title.text == "Quest 2")
    assert(rows[1].note.text:find("Pick up", 1, true))
end)
check("Preparation has translated non-actionable headings for every populated group", function()
    local groups = {}
    for _, row in ipairs(ui.rows) do
        if row.shown and row.heading then
            assert(not row.enabled and not row.scripts.OnClick and row.note.text == "")
            assert(row.title.text == addon.L(row.heading))
            groups[#groups + 1] = row.heading
        end
    end
    assert(table.concat(groups, ",") == "PREP_outside,PREP_inside,PREP_level,PREP_progress,PREP_uncertain")
end)
check("Inside pickup, level gates and active completion remain distinct", function()
    local rows = visibleRows()
    assert(rows[3].note.text:find("Pick up inside the dungeon", 1, true))
    assert(rows[4].note.text:find("Reach level 30", 1, true))
    assert(rows[5].note.text:find("Finish this quest", 1, true))
end)
check("Active quests stay in progress regardless of their original pickup location", function()
    addon.quests[6].startsInside = true
    ui:RefreshQuests(); ui:RefreshDetail()
    local group, found
    for _, row in ipairs(ui.rows) do
        if row.shown then
            if row.heading then group = row.heading
            elseif row.title.text == "Quest 6" then found = group end
        end
    end
    assert(found == "PREP_progress")
    addon.quests[6].startsInside = nil
end)
check("Any preparation action opens its own quest and navigation target", function()
    local nav = addon.Navigation
    addon.Navigation = { Start = function() end, Map = function() end }
    visibleRows()[2].scripts.OnClick()
    assert(ui.quest == 2 and ui.action.id == 2 and ui.action.place.x == 12 and hasDestination(true))
    addon.Navigation = nav
end)
check("Unknown quests remain visible without an invented action", function()
    local nav = addon.Navigation
    addon.Navigation = { Start = function() end, Map = function() end }
    local row = visibleRows()[6]
    assert(row.title.text == "Quest 3" and row.note.text:find(addon.L("UNKNOWN_REQUIREMENTS"), 1, true))
    row.scripts.OnClick()
    assert(ui.quest == 3 and not ui.action and hasDestination(false) and hasDestination(true) and ui.giver.footerLabelKey=="VISIT_GIVER")
    addon.Navigation = nav
end)
check("Quest progress removes a shared prerequisite from preparation", function()
    done[1] = true; ui:RefreshQuests(); ui:RefreshDetail()
    assert(#visibleRows() == 6 and visibleRows()[1].title.text == "Quest 2")
    local unlocked = false
    for _, row in ipairs(visibleRows()) do
        assert(row.title.text ~= "Quest 1")
        if row.title.text == "Quest 101" then unlocked = true end
    end
    assert(unlocked)
end)
check("Returning to target view clears recycled preparation labels", function()
    togglePreparationFixture()
    assert(#visibleRows() == 7)
    assert(visibleRows()[1].title.text == "Quest 100")
    assert(visibleRows()[1].note.text:find("Preparation needed", 1, true))
    for _, row in ipairs(visibleRows()) do assert(not row.heading and row.enabled and row.scripts.OnClick) end
end)
check("Inside classification uses quest metadata instead of quest names", function()
    local original = addon.QuestName
    addon.QuestName = function() return "An outside-sounding name" end
    togglePreparationFixture()
    local group, insideRows = nil, 0
    for _, row in ipairs(ui.rows) do
        if row.shown then
            if row.heading then group = row.heading
            elseif group == "PREP_inside" then
                insideRows = insideRows + 1
                row.scripts.OnClick(); assert(ui.quest == 4 and ui.action.kind == "inside")
            end
        end
    end
    assert(insideRows == 1)
    addon.QuestName = original
    togglePreparationFixture()
end)
check("Locked target with an unavailable prerequisite stays visible", function()
    local oldContext = addon.Context
    addon.Context = function() local c = oldContext(); c.faction = "Alliance"; return c end
    addon.quests[200] = { id = 200, minLevel = 1, requirementsKnown = true, requires = { { ids = { 201 } } } }
    addon.quests[201] = { id = 201, minLevel = 1, requirementsKnown = true, factions = { "Horde" } }
    local ids = ui.dungeon.quests
    ids[#ids + 1] = 200
    ui.preparation = true; ui:RefreshQuests(); ui:RefreshDetail()
    local found = false
    for _, row in ipairs(visibleRows()) do
        if row.title.text == "Quest 200" then found = true; row.scripts.OnClick() end
    end
    assert(found and ui.quest == 200 and not ui.action and not hasDestination(true))
    ids[#ids] = nil; addon.quests[200], addon.quests[201] = nil, nil
    addon.Context = oldContext; ui.preparation = false; ui.quest = nil; ui:Refresh()
end)
local function audienceText(value)
    return (value:gsub("|A:[^|]+|a ", ""))
end
local function detailHas(value)
    for _, fs in ipairs(ui.details) do if fs.shown then
        local text=audienceText(fs.text)
        if text==value then return true end
        -- Compact metadata and inventory counts share a line. Keep exact
        -- component matching rather than matching arbitrary name substrings.
        local start=1
        while start<=#text do
            local first,last=text:find(value,start,true)
            if not first then break end
            if (first==1 or text:sub(first-#" · ",first-1)==" · ") and
                (last==#text or text:sub(last+1,last+#" · ")==" · ") then return true end
            start=first+1
        end
    end end
    return false
end
local function unknownObjective(name) return name .. " ×?" end
local function startButton(index)
    local q=addon.quests[ui.quest]
    if q and not q.start and q.startAlternatives then
        if index<=2 then return ui.giverButtons[index]end
        return ui.startButtons[index-2]
    end
    return ui.startButtons[index]
end
local function showCompactDetail(id, context)
    ui.quest = id; ui.engine = addon.Planner.New(addon.quests, context or addon.Context()); return ui:RefreshDetail()
end
-- Source and story cases explicitly choose their own contextual view.
local function expandDetail()
    local id = ui.quest
    if ui.quest == id and ui.referenceToggle and ui.referenceToggle.shown and not ui.detailReferencesExpanded then ui.referenceToggle.scripts.OnClick() end
    if ui.quest == id and ui.storyToggle and ui.storyToggle.shown and not ui.detailChainExpanded then ui.storyToggle.scripts.OnClick() end
end
local function showDetail(id, context)
    -- Ordinary work assertions use Quest; separate helpers inspect secondary views.
    ui.detailObjectivesQuest,ui.detailObjectivesDungeon,ui.detailObjectivesCharacter=id,ui.dungeon,addon.char
    ui.detailObjectivesExpanded=true
    local generation = showCompactDetail(id, context)
    if generation and ui.rewardGeneration == generation and ui.quest == id and ui:SetDetailTab("quest") then return ui.rewardGeneration end
end
local function showSources(id, context)
    local generation = showDetail(id, context)
    if generation and ui.rewardGeneration == generation and ui.quest == id then return ui:SetDetailTab("sources") end
end
local function showStory(id, context)
    local generation = showDetail(id, context)
    if generation and ui.rewardGeneration == generation and ui.quest == id then return ui:SetDetailTab("story") end
end
check("Mandatory prerequisites live in the middle tree without a duplicate right-pane chain", function()
    local dungeon, nav = ui.dungeon, addon.Navigation
    addon.Navigation = { Start = function() end, Map = function() end }
    for _, id in ipairs({ 99220, 99221, 99222 }) do
        addon.quests[id] = { id = id, name = "Same title", minLevel = 1, requirementsKnown = true,
            start = { mapID = 1, x = 20, y = 30 } }
    end
    addon.quests[99220].requires = { { ids = { 99221 } } }
    addon.quests[99221].requires = { { ids = { 99222 } } }
    ui.dungeon = { key = "compact", quests = { 99220 } }
    showCompactDetail(99220)
    assert(ui.giver.enabled and ui.action.id == 99222)
    assert(not(ui.referenceToggle and ui.referenceToggle.shown) and not(ui.storyToggle and ui.storyToggle.shown))
    ui.questTreeRoot,ui.questTreeDungeon=99220,ui.dungeon;ui:RefreshQuests()
    local seen={};for _,row in ipairs(ui.rows)do if row.shown and row.questTreeNode and row.questID then seen[row.questID]=true end end
    assert(seen[99220] and seen[99221] and seen[99222],"all exact prerequisite IDs remain inspectable in the middle pane")
    assert(not detailHas(addon.L("NEXT")) and not detailHas(addon.L("DETAIL_CHAIN")))
    for _, id in ipairs({ 99220, 99221, 99222 }) do addon.quests[id] = nil end
    ui.questTreeRoot,ui.questTreeDungeon=nil,nil;ui.dungeon = dungeon; addon.Navigation = nav; showDetail(2)
end)
check("Compact OR context never selects an arbitrary mandatory predecessor and disclosures retain actions", function()
    local dungeon, nav = ui.dungeon, addon.Navigation
    addon.Navigation = { Start = function() end, Map = function() end }
    for _, id in ipairs({ 99230, 99231, 99232 }) do addon.quests[id] = { id = id, minLevel = 1, requirementsKnown = true } end
    addon.quests[99230].requires = { { ids = { 99231, 99232 } } }
    addon.quests[99230].start = { mapID = 1, x = 20, y = 30 }
    ui.dungeon = { key = "compact-or", quests = { 99230 } }; showCompactDetail(99230)
    assert(not(ui.branchButtons and ui.branchButtons[1]and ui.branchButtons[1].shown))
    local action, status = ui.action, ui.engine:State(99230).status
    ui.questTreeRoot,ui.questTreeDungeon=99230,ui.dungeon;ui:RefreshQuests();ui:RefreshDetail()
    local seen={};for _,row in ipairs(ui.rows)do if row.shown and row.questTreeNode and row.questID then seen[row.questID]=true end end
    assert(seen[99231] and seen[99232] and ui.giver.enabled and ui.action.id == action.id and ui.action.kind == action.kind and ui.engine:State(99230).status == status)
    assert(not(ui.referenceToggle and ui.referenceToggle.shown) and not(ui.storyToggle and ui.storyToggle.shown))
    for _, id in ipairs({ 99230, 99231, 99232 }) do addon.quests[id] = nil end
    ui.questTreeRoot,ui.questTreeDungeon=nil,nil;ui.dungeon = dungeon; addon.Navigation = nav; showDetail(2)
end)
check("Detail tabs reset on a different card and stale callbacks cannot change its successor", function()
    local first,second=addon.quests[1].startAlternatives,addon.quests[2].startAlternatives
    addon.quests[1].startAlternatives={addon.quests[1].start};addon.quests[2].startAlternatives={addon.quests[2].start}
    showCompactDetail(1); local old = ui.detailTabButtons.sources.scripts.OnClick
    old(); assert(ui.detailTab == "sources")
    ui:RefreshDetail(); assert(ui.detailTab == "sources")
    showCompactDetail(2); assert(ui.detailTab == "quest")
    old(); assert(ui.quest == 2 and ui.detailTab == "quest")
    local current = ui.detailTabButtons.sources.scripts.OnClick
    ui.frame:Hide(); ui.frame.scripts.OnHide(); current(); assert(ui.detailTab == "quest")
    ui.frame:Show(); ui.frame.scripts.OnShow();addon.quests[1].startAlternatives,addon.quests[2].startAlternatives=first,second;showDetail(2)
end)
check("Tab offset getters cannot transfer a view or restoration to a replaced scroll owner", function()
    local alternatives=addon.quests[100].startAlternatives;addon.quests[100].startAlternatives={addon.quests[100].start}
    do
        showDetail(100)
        ui:SetDetailTab("sources")
        local scroll, tab = ui.detailScroll, ui.detailTab
        local getter = scroll.GetVerticalScroll
        local replacement = object("ScrollFrame"); replacement:SetHeight(425)
        scroll.GetVerticalScroll = function() ui.detailScroll = replacement; return 125 end
        local toggle = ui.detailTabButtons.quest
        toggle.scripts.OnClick()
        assert(ui.detailTab == tab and not replacement.scrollWrites)
        scroll.GetVerticalScroll, ui.detailScroll = getter, scroll
    end
    addon.quests[100].startAlternatives=alternatives;showDetail(2)
end)
check("Owned acquisition styling that replaces settings aborts without indexing stale settings", function()
    local alternatives=addon.quests[100].startAlternatives;addon.quests[100].startAlternatives={addon.quests[100].start}
    showDetail(100)
    local database, style, armed = addon.db, addon.Theme.StyleRow, true
    addon.Theme.StyleRow = function(row, ...)
        local result = style(row, ...)
        if armed and row == ui.detailTabButtons.sources then armed = false; addon.db = nil end
        return result
    end
    local ok = pcall(ui.RefreshDetail, ui)
    addon.db, addon.Theme.StyleRow = database, style
    assert(ok and not armed and not ui.detailTabButtons.sources.shown)
    addon.quests[100].startAlternatives=alternatives;showDetail(2)
end)
check("Unknown quests allow an explicit location visit without claiming availability", function()
    local started, mapped = {}, {}
    addon.Navigation = { Start = function(action) started[#started + 1] = action end,
        Map = function(place) mapped[#mapped + 1] = place end }
    showDetail(3)
    assert(ui.engine:State(3).status == "UNKNOWN" and not ui.action and hasDestination(true))
    assert(ui.giver.enabled and ui.giver.footerLabelKey=="VISIT_GIVER" and not detailHas(addon.L("AVAILABLE")) and #started == 0 and #mapped == 0)
    ui.giver.scripts.OnClick()
    assert(#started == 1 and started[1].kind == "visit" and started[1].id == 3)
    assert(started[1].place == addon.quests[3].start and not ui.action)
    showDetail(2)
    assert(not detailHas(addon.L("LOCATION_ONLY")))
end)
check("Quest-giver visits keep prerequisite guidance on its original action", function()
    local originalStart, started = addon.quests[100].start, {}
    addon.quests[100].start = { mapID = 1, x = 30, y = 40 }
    addon.Navigation.Start = function(action) started[#started + 1] = action end
    showDetail(100)
    local prerequisite = ui.action
    assert(prerequisite.id == 2 and ui.giverAction.id == 100 and ui.giver.footerLabelKey=="VISIT_GIVER")
    ui.giver.scripts.OnClick()
    assert(started[1].id == 100 and started[1].kind == "visit" and ui.action == prerequisite)
    assert(ui.giver.footerLabelKey == "VISIT_GIVER")
    addon.quests[100].start = originalStart
end)
check("Map-only quest givers open their known zone and missing givers disable visits", function()
    local originalStart, mapped, started = addon.quests[2].start, {}, 0
    addon.Navigation = { Map = function(place) mapped[#mapped + 1] = place end,
        Start = function() started = started + 1 end }
    addon.quests[2].start = { mapID = 1436, name = "Known zone only" }
    showDetail(2)
    assert(ui.giver.enabled and not ui.giver.caption and ui.giver.width==24 and ui.giver.footerLabelKey == "GIVER_MAP")
    ui.giver.scripts.OnClick()
    assert(#mapped == 1 and mapped[1].mapID == 1436 and started == 0)
    addon.quests[2].start = nil; showDetail(2)
    assert(not ui.giver.enabled and not ui.giverAction)
    ui.giver.scripts.OnClick(); assert(#mapped == 1 and started == 0)
    ui.quest = nil; ui:RefreshDetail(); assert(not ui.giver.enabled and not ui.giverAction)
    addon.quests[2].start = originalStart
end)
check("Detail distinguishes unfinished prerequisites from unverified requirements", function()
    showDetail(100)
    assert(ui.engine:State(100).status == "LOCKED" and detailHas(addon.L("REASON_requirements")))
    showDetail(3)
    assert(ui.engine:State(3).status == "UNKNOWN" and detailHas(addon.L("REASON_requirementsUnknown")))
    assert(not detailHas(addon.L("REASON_requirements")) and not ui.action and hasDestination(true))
end)
check("Compact level metadata preserves required levels without inventing a missing character level", function()
    showDetail(5)
    local function contains(value)for _,fs in ipairs(ui.details)do if fs.shown and fs.text:find(value,1,true)then return true end end end
    assert(contains(addon.L("DETAIL_MIN_LEVEL",30)) and ui.engine:State(5).reason=="level")
    local context = addon.Context(); context.level = nil
    showDetail(5, context)
    assert(ui.engine:State(5).status == "UNKNOWN")
    assert(contains(addon.L("DETAIL_MIN_LEVEL",30)) and ui.engine:State(5).reason=="level")
    assert(not detailHas(addon.L("REASON_level_current", 30, 20)) and not ui.action)
end)
check("Missing catalogue records display an honest reason instead of a selection prompt", function()
    showDetail(999)
    assert(detailHas(addon.L("REASON_missing")) and not ui.action and not hasDestination(true))
end)
check("Character history and each restriction have specific detail reasons", function()
    local context = addon.Context()
    context.completed = function() return nil end
    showDetail(2, context)
    assert(detailHas(addon.L("REASON_character")) and not ui.action)
    for _, rule in ipairs({ { "factions", "faction", "Horde", "Alliance" },
        { "classes", "class", "WARRIOR", "MAGE" } }) do
        context = addon.Context(); context[rule[2]] = rule[4]
        addon.quests[2][rule[1]] = { rule[3] }
        showDetail(2, context)
        assert(ui.engine:State(2).status == "UNAVAILABLE" and detailHas(addon.L("REASON_" .. rule[2])))
        assert(not ui.action)
        addon.quests[2][rule[1]] = nil
    end
end)
check("Cycle reasons render without making the quest available and clear on redraw", function()
    ui.quest = 2
    ui.engine = { context = {}, State = function() return { status = "UNKNOWN", reason = "cycle" } end,
        Next = function() return {}, true end }
    ui:RefreshDetail()
    assert(detailHas(addon.L("REASON_cycle")) and not ui.action)
    showDetail(2)
    assert(ui.engine:State(2).status == "AVAILABLE")
    for key, value in pairs(addon.locales.enUS) do
        if key:find("REASON_", 1, true) and not value:find("%%d") then assert(not detailHas(value)) end
    end
end)
check("All-character browsing preserves restricted quests for inspection without actions", function()
    local originalContext, filters = addon.Context, addon.char.filters
    addon.Context = function() local c = originalContext(); c.faction = "Alliance"; return c end
    addon.quests[300] = { id = 300, minLevel = 1, requirementsKnown = true, factions = { "Horde" } }
    local ids = ui.dungeon.quests; ids[#ids + 1] = 300
    ui.preparation = false; ui:Refresh()
    assert(#visibleRows() == 7)
    ui.characterButton.scripts.OnClick()
    assert(ui.includeUnavailable and addon.char.filters.includeUnavailable == true)
    assert(addon.L(ui.characterButton.filterLabelKey) == addon.L("FILTER_QUEST_ALL") and #visibleRows() == 8)
    local function selectRestricted()
        for _, row in ipairs(visibleRows()) do
            if row.title.text == "Quest 300" then
                row.scripts.OnClick()
                if ui.referenceToggle and ui.referenceToggle.shown and not ui.detailReferencesExpanded then ui.referenceToggle.scripts.OnClick() end
                assert(detailHas(addon.L("REASON_faction")) and not ui.action and not hasDestination(true))
                return true
            end
        end
        return false
    end
    assert(selectRestricted())
    togglePreparationFixture()
    local heading
    for _, row in ipairs(ui.rows) do
        if row.shown and row.heading == "PREP_unavailable" then heading = row end
    end
    assert(heading and not heading.enabled and not heading.scripts.OnClick and selectRestricted())
    ui:LoadFilters()
    assert(ui.includeUnavailable and not ui.preparation and addon.char.filters == filters and filters.other == "preserve")
    ui.characterButton.scripts.OnClick()
    for _, row in ipairs(visibleRows()) do assert(row.title.text ~= "Quest 300") end
    ui:Refresh()
    for _, row in ipairs(visibleRows()) do assert(row.enabled and not row.heading and row.scripts.OnClick) end
    ids[#ids] = nil; addon.quests[300] = nil
    addon.Context = originalContext; ui.quest = nil; ui:Refresh()
end)
check("Level and audience filters persist without reviving or rewriting the retired preparation preference", function()
    local filters = addon.char.filters
    ui.rangeButton.scripts.OnClick()
    assert(filters.range == true)
    ui.range = false; ui:LoadFilters(); assert(ui.range)
    ui.rangeButton.scripts.OnClick()
    assert(filters.range == false and filters.preparation == 1 and filters.includeUnavailable == false and not ui.preparation)
    assert(addon.char.filters == filters and filters.other == "preserve")
end)
check("Filtered-out quests are distinguished from missing dungeon data", function()
    local originalContext, originalDungeon = addon.Context, ui.dungeon
    addon.Context = function() local c = originalContext(); c.faction = "Alliance"; return c end
    addon.quests[301] = { id = 301, minLevel = 1, requirementsKnown = true, factions = { "Horde" } }
    ui.dungeon = { name = "Faction fixture", coverage = "reviewed", quests = { 301 } }
    ui:Refresh()
    assert(#visibleRows() == 0 and planCoverage() == addon.L("NO_CHARACTER_QUESTS", addon.L("FILTER_QUEST_ALL")))
    ui.characterButton.scripts.OnClick()
    assert(#visibleRows() == 1 and visibleRows()[1].title.text == "Quest 301")
    assert(planCoverage() ~= addon.L("NO_CHARACTER_QUESTS", addon.L("FILTER_QUEST_ALL")) and planCoverage() ~= addon.L("EMPTY"))
    ui.characterButton.scripts.OnClick()
    ui.dungeon.quests = {}; ui:Refresh()
    assert(#visibleRows() == 0 and planCoverage() == addon.L("EMPTY"))
    ui.dungeon = originalDungeon; addon.Context = originalContext; addon.quests[301] = nil; ui:Refresh()
end)
check("Wrapped catalogue, quest and giver text expands cumulative rows without overlap", function()
    local questName, dungeonName, giver = addon.QuestName, addon.DungeonName, addon.quests[2].start.name
    addon.QuestName = function(id) return "LONG_TITLE " .. id end
    addon.DungeonName = function() return "LONG_TITLE dungeon" end
    addon.quests[2].start.name = "LONG_NOTE giver"
    measurement = function(fs)
        if fs.text and fs.text:find("LONG_TITLE", 1, true) then return 72 end
        if fs.text and fs.text:find("LONG_NOTE", 1, true) then return 54 end
        return 18
    end
    ui.preparation = false; ui:Refresh()
    local first = visibleRows()[1]
    assert(first.height >= 84 and not first.note.shown)
    assert(-visibleRows()[2].point[3] >= first.height + 2)
    assert(ui.cards[1].height >= 108 and ui.catalog.height >= ui.cards[1].height)
    ui.preparation = true; ui:RefreshQuests(); ui:RefreshDetail()
    local totalHeight, sawLongNote = 0, false
    for _, row in ipairs(ui.rows) do
        if row.shown then
            assert(row.point[3] == -totalHeight)
            totalHeight = totalHeight + row.height + 4
            if row.note.text:find("LONG_NOTE", 1, true) then
                sawLongNote = true; assert(row.height >= 7 + 72 + 4 + 54 + 7)
            end
        end
    end
    assert(sawLongNote and ui.questList.height == totalHeight)
    ui.preparation=false;ui.questTreeRoot,ui.questTreeDungeon=100,ui.dungeon;ui:RefreshQuests();showDetail(100)
    local previous
    for _,row in ipairs(ui.rows)do if row.shown and row.questTreeNode then
        assert(row.height>=84)
        if previous then assert(-row.point[3]>=-previous.point[3]+previous.height)end
        previous=row
    end end
    assert(previous)
    addon.QuestName, addon.DungeonName, addon.quests[2].start.name = questName, dungeonName, giver
    measurement = nil;ui.questTreeRoot,ui.questTreeDungeon=nil,nil; ui.preparation = false; ui:Refresh(); showDetail(100)
    assert(visibleRows()[1] == first and first.height == 30 and ui.cards[1].height == 76)
    assert(not first.note.shown and not(ui.storyToggle and ui.storyToggle.shown))
end)
check("Invalid and restricted text measurements reuse clean geometry safely", function()
    ui.preparation = false; ui:Refresh(); showDetail(100)
    local height, detailHeight = visibleRows()[1].height, ui.detail.height
    for _, value in ipairs({ math.huge, -1, 0 / 0, 777 }) do
        measurement = function() return value end
        issecretvalue = function(v) return type(v) == "number" and v == 777 end
        ui:Refresh(); showDetail(100)
        assert(visibleRows()[1].height == height and ui.detail.height == detailHeight)
        assert(ui.questList.height < math.huge and ui.detail.height < math.huge)
    end
    measurement = function() error("height unavailable") end
    ui:Refresh(); showDetail(100)
    assert(visibleRows()[1].height == height and ui.detail.height == detailHeight)
    measurement, issecretvalue = nil, nil
end)
check("Middle OR controls preserve persisted choices automatic reset and safe stale fallback", function()
    local originalContext, originalDungeon, originalChoices = addon.Context, ui.dungeon, addon.char.choices
    addon.Context = function() local c = originalContext(); c.faction = "Alliance"; return c end
    for _, id in ipairs({ 400, 401, 402, 403, 404 }) do
        addon.quests[id] = { id = id, minLevel = 1, requirementsKnown = true,
            start = { mapID = 1, x = 20, y = 30 } }
    end
    addon.quests[400].requires = { { ids = { 401, 402, 403, 404 } } }
    addon.quests[403].factions = { "Horde" }; addon.quests[404].requirementsKnown = false
    addon.char.choices = { [999] = { retain = true }, [400] = { [2] = 777 } }
    local choices = addon.char.choices
    ui.dungeon = { name = "Branch fixture", coverage = "reviewed", quests = { 400 } }
    ui.preparation, ui.quest = false, 400; ui:Refresh();expandDetail()
    ui.questTreeRoot,ui.questTreeDungeon=400,ui.dungeon;ui:RefreshQuests()
    local function option(parent)
        for _,row in ipairs(ui.rows)do local b=row.branchControl
            if row.shown and b and b.shown and b.branchChild==400 and b.branchGroup==1 and b.branchParent==parent then return b end
        end
        error("Missing middle alternative control "..tostring(parent))
    end
    assert(ui.action.id == 401)
    assert(not option(403).enabled);option(403).scripts.OnClick();assert(choices[400][1]==nil)
    assert(not ui:ChooseBranch(400, 1, 403) and not ui:ChooseBranch(400, 1, 999))
    assert(not ui:ChooseBranch(math.huge, 1, 401) and choices[400][1] == nil)
    option(402).scripts.OnClick()
    assert(ui.action.id == 402 and choices[400][1] == 402)
    assert(addon.char.choices == choices and choices[999].retain and choices[400][2] == 777)
    ui:Refresh(); assert(ui.action.id == 402)
    option(404).scripts.OnClick()
    assert(choices[400][1] == 404 and not ui.action and hasDestination(true) and ui.giver.footerLabelKey=="VISIT_GIVER")
    assert(option(404).branchSelected);option(404).scripts.OnClick()
    assert(choices[400][1] == nil and ui.action.id == 401)
    option(402).scripts.OnClick();local stale=option(402).scripts.OnClick
    addon.quests[400].requires[1].ids = { 401, 403, 404 }
    ui:Refresh()
    stale();assert(choices[400][1]==402)
    assert(ui.action.id == 401 and choices[400][1] == 402)
    assert(ui.action.id==401,"a removed saved preference must fall back to the current automatic route")
    ui.quest = 2; ui:RefreshDetail()
    for _, b in ipairs(ui.branchButtons or {}) do assert(not b.shown) end
    for _, id in ipairs({ 400, 401, 402, 403, 404 }) do addon.quests[id] = nil end
    addon.Context, addon.char.choices, ui.dungeon = originalContext, originalChoices, originalDungeon
    ui.questTreeRoot,ui.questTreeDungeon=nil,nil;ui.quest = nil; ui:Refresh()
end)
check("Completed preparation keeps the prepared result instead of empty data warning", function()
    local context = addon.Context
    addon.Context = function()
        local value = context()
        value.active = function() return false end
        return value
    end
    for id in pairs(addon.quests) do done[id] = true end
    togglePreparationFixture()
    assert(#visibleRows() == 0 and planCoverage() == addon.L("PREPARED"))
    assert(ui.rows[1].shown and not ui.rows[1].enabled and not ui.rows[1].scripts.OnClick)
    assert(ui.rows[1].title.text == addon.L("PREPARATION_EMPTY", addon.L("QUESTS")))
    for index = 2, #ui.rows do assert(not ui.rows[index].shown) end
    addon.Context = context
end)
check("Completion history cannot hide the current held quest from preparation progress", function()
    assert(done[6] == true)
    ui:RefreshQuests(); ui:RefreshDetail()
    assert(ui.engine:State(6).status == "ACTIVE" and ui.engine:State(6).completedHistory == true)
    local rows = visibleRows()
    assert(#rows == 1 and rows[1].title.text == "Quest 6")
    assert(rows[1].note.text:find(addon.L("complete"), 1, true))
    assert(planCoverage() == addon.L("PREPARED"), "held repeat work does not revoke preparation")
end)
check("Reopening recalculates fit after a screen change", function()
    screenWidth, screenHeight = 800, 900
    ui.frame.scripts.OnShow()
    assert(ui.frame.scale * 1100 <= 800 * 0.92 + 0.001)
end)
check("Detail renders native objective text and removes stale objectives", function()
    addon.QuestObjectives = function(id)
        assert(id == 2)
        return { { text = "Native objective: 2/6", finished = false } }
    end
    showDetail(2)
    local function hasObjective()
        for _, fs in ipairs(ui.details) do
            if fs.shown and fs.text:find("Native objective: 2/6", 1, true) then return true end
        end
        return false
    end
    assert(hasObjective())
    addon.QuestObjectives = function() return nil end
    ui:RefreshDetail(); assert(not hasObjective())
end)
check("Reward details distinguish fixed items from choices and show their counts", function()
    local moneyCalls = 0
    addon.QuestRewards = function(id)
        assert(id == 2)
        return { items = { { id = 101, name = "Reward token", count = 3 } },
            choices = { { id = 102, name = "Choice blade", count = 1 }, { id = 103, name = "Choice robe", count = 2 } }, money = 150 }
    end
    GetCoinTextureString = function(value) assert(value == 150); moneyCalls = moneyCalls + 1; return "Native coin texture" end
    showDetail(2)
    assert(detailHas(addon.L("DETAIL_GUARANTEED")) and detailHas(addon.L("REWARD_CHOICES")))
    assert(detailHas(addon.L("REWARD_ITEM", "Reward token", 3)))
    assert(detailHas("Choice blade") and detailHas(addon.L("REWARD_ITEM", "Choice robe", 2)))
    assert(not detailHas(addon.L("REWARD_NO_ITEMS")) and not detailHas(addon.L("REWARD_UNAVAILABLE")))
    assert(detailHas(addon.L("REWARD_MONEY") .. ": Native coin texture") and moneyCalls == 1)
end)
check("Empty and unavailable reward data remain quiet without invented items or currency", function()
    local moneyCalls = 0
    GetCoinTextureString = function() moneyCalls = moneyCalls + 1; error("zero must not be formatted") end
    addon.QuestRewards = function() return { items = {}, choices = {}, money = 0 } end
    showDetail(2)
    assert(not detailHas(addon.L("REWARD_NO_ITEMS")) and not detailHas(addon.L("REWARD_UNAVAILABLE")))
    assert(not detailHas(addon.L("DETAIL_GUARANTEED")) and not detailHas(addon.L("REWARD_CHOICES")))
    assert(not detailHas(addon.L("REWARD_MONEY_UNKNOWN")) and moneyCalls == 0)
    addon.QuestRewards = function() return nil end
    showDetail(2)
    assert(not detailHas(addon.L("REWARD_UNAVAILABLE")) and not detailHas(addon.L("REWARD_NO_ITEMS")))
    addon.QuestRewards = nil; showDetail(2)
    assert(not detailHas(addon.L("REWARD_UNAVAILABLE")))
    for _,button in ipairs(ui.rewardButtons)do assert(not button.shown)end
end)
check("Reward redraw clears another quest's items and money text", function()
    addon.QuestRewards = function(id)
        if id == 2 then return { items = {}, choices = { { id = 103, name = "Only selected quest robe", count = 1 } }, money = 99 } end
        return nil
    end
    GetCoinTextureString = function() return "Selected coin texture" end
    showDetail(2)
    assert(detailHas(addon.L("REWARD_CHOICES")) and not detailHas(addon.L("DETAIL_GUARANTEED")))
    assert(not detailHas(addon.L("REWARD_NO_ITEMS")))
    showDetail(3)
    assert(not detailHas(addon.L("REWARD_UNAVAILABLE")))
    assert(not detailHas("Only selected quest robe"))
    assert(not detailHas(addon.L("REWARD_MONEY") .. ": Selected coin texture"))
end)
check("Unavailable money formatter retains the exact known copper amount", function()
    addon.QuestRewards = function() return { items = {}, choices = {}, money = 100 } end
    GetCoinTextureString = nil; showDetail(2)
    assert(detailHas(addon.L("REWARD_MONEY") .. ": " .. addon.L("MONEY_COPPER",100)))
    addon.QuestRewards = function() error("reward API unavailable") end
    showDetail(2)
    assert(not detailHas(addon.L("REWARD_UNAVAILABLE")) and not detailHas(addon.L("REWARD_MONEY_UNKNOWN")))
    addon.QuestRewards = nil
end)
check("Search matches localized and source names literally while preserving selection", function()
    local dungeons, dungeonName, selected, quest, savedSelection = addon.dungeons, addon.DungeonName, ui.dungeon, ui.quest, addon.char.selectedDungeon
    addon.dungeons = {
        { key = "search-dm", name = "The Deadmines", localized = "Мёртвые Копи", minLevel = 10, maxLevel = 25, quests = { 2 } },
        { key = "search-sfk", name = "Shadowfang Keep", localized = "Крепость Тёмного Клыка", minLevel = 20, maxLevel = 30, quests = {} },
        { key = "search-literal", name = "[100%] Dungeon", localized = "测试[100%]", minLevel = 50, maxLevel = 60, quests = {} },
    }
    addon.DungeonName = function(d) return d.localized end
    ui.dungeon, ui.quest, addon.char.selectedDungeon = addon.dungeons[1], 2, "search-dm"
    local searchSelected = ui.dungeon
    local function search(value)
        ui.searchBox:SetText(value); ui.searchBox.scripts.OnTextChanged(ui.searchBox)
    end
    local function cards()
        local result = {}
        for _, card in ipairs(ui.cards) do if card.shown then result[#result + 1] = card end end
        return result
    end
    search("  deAdMiNeS  ")
    assert(#cards() == 1 and cards()[1].title.text == "Мёртвые Копи")
    assert(ui.searchHint.shown and ui.searchHint.text == addon.L("SEARCH_HELP") and not ui.searchPlaceholder.shown)
    search("Крепость")
    assert(#cards() == 1 and cards()[1].title.text == "Крепость Тёмного Клыка")
    assert(ui.dungeon == searchSelected and ui.quest == 2 and addon.char.selectedDungeon == "search-dm")
    search("крепость")
    assert(#cards() == 1 and cards()[1].title.text == "Крепость Тёмного Клыка")
    search("[100%]")
    assert(#cards() == 1 and cards()[1].title.text == "测试[100%]")
    search(".*")
    assert(#cards() == 0 and ui.catalogNotice.shown)
    search("[")
    assert(#cards() == 1)
    ui.range = true; search("[100%]")
    assert(#cards() == 0 and ui.catalogNotice.shown)
    ui.range = false
    ui.clearSearch.scripts.OnClick()
    assert(ui.search == "" and ui.searchBox:GetText() == "" and #cards() == 3)
    assert(not ui.catalogNotice.shown and not ui.searchHint.shown and ui.searchPlaceholder.shown)
    assert(not ui.clearSearch.enabled and addon.char.filters.search == nil)
    assert(ui.dungeon == searchSelected and ui.quest == 2)
    addon.dungeons, addon.DungeonName, ui.dungeon, ui.quest, addon.char.selectedDungeon = dungeons, dungeonName, selected, quest, savedSelection
    ui:Refresh()
end)
check("Completion material quests stay separate from acceptance and inventory claims", function()
    addon.quests[800] = { id = 800, minLevel = 1, requirementsKnown = true, repeatable = true,
        completionQuests = { { id = 801, itemID = 701 }, { id = 802, itemID = 702 } } }
    addon.quests[801] = { id = 801, minLevel = 1, requirementsKnown = false, repeatable = false }
    addon.quests[802] = { id = 802, minLevel = 1, requirementsKnown = true }
    done[802] = true
    showSources(800)
    assert(ui.engine:State(800).status == "AVAILABLE" and ui.action.id == 800)
    assert(detailHas(addon.L("MATERIAL_QUESTS")) and detailHas(addon.L("MATERIAL_NOTICE")))
    assert(detailHas(addon.L("REPEATABLE")))
    local first, second = ui.materialButtons[1], ui.materialButtons[2]
    assert(first.shown and first.questID == 801 and first.itemID == 701)
    assert(first.note.text:find(addon.L("MATERIAL_ITEM", 701), 1, true))
    assert(first.note.text:find(addon.L("UNKNOWN_REQUIREMENTS"), 1, true))
    assert(second.shown and second.note.text:find(addon.L("COMPLETED"), 1, true))
    first.scripts.OnClick()
    assert(ui.quest == 801 and not ui.action and not hasDestination(true))
    assert(not detailHas(addon.L("MATERIAL_QUESTS")) and not detailHas(addon.L("MATERIAL_NOTICE")))
    assert(not detailHas(addon.L("REPEATABLE")) and not first.shown and not second.shown)
    showSources(800)
    assert(ui.materialButtons[1] == first and first.shown and ui.action.id == 800)
end)
check("Material rows wrap, clear on redraw and tolerate an older planner", function()
    measurement = function(fs)
        if fs.text == "Quest 801" then return 72 end
        if fs.text and fs.text:find(addon.L("MATERIAL_ITEM", 701), 1, true) then return 36 end
        return 18
    end
    showSources(800)
    local first, second = ui.materialButtons[1], ui.materialButtons[2]
    assert(first.height >= 7 + 72 + 4 + 36 + 7)
    assert(first.point[3] - second.point[3] >= first.height + 4)
    measurement = nil; showSources(800)
    assert(first.height == 59)
    ui.engine.CompletionSteps = nil; ui:RefreshDetail()
    assert(not first.shown and not second.shown and not detailHas(addon.L("MATERIAL_QUESTS")))
    addon.quests[800].repeatable = "true"; showSources(800)
    assert(not detailHas(addon.L("REPEATABLE")))
    addon.quests[800], addon.quests[801], addon.quests[802], done[802] = nil, nil, nil, nil
    showSources(2)
    for _, b in ipairs(ui.materialButtons) do assert(not b.shown) end
end)
check("Native quest portrait renders a display ID in its own measured flow space", function()
    local beforeHeight
    showDetail(2); beforeHeight = ui.detail.height
    local rendered, portraitCalls = {}, 0
    addon.QuestPortrait = function(id) assert(id == 2); return { displayID = 12345, name = "Native" } end
    SetPortraitTextureFromCreatureDisplayID = function(texture, displayID)
        portraitCalls = portraitCalls + 1
        assert(not texture.shown, "portrait must stay hidden until rendering succeeds")
        rendered.texture, rendered.displayID = texture, displayID
        texture:SetTexture("rendered portrait")
    end
    measurement = function(fs) if fs.text == addon.L("QUEST_PORTRAIT") then return 54 end; return 18 end
    showDetail(2)
    assert(ui.portrait.shown and ui.portrait.width == 64 and ui.portrait.height == 64)
    assert(rendered.texture == ui.portrait and rendered.displayID == 12345 and portraitCalls == 1)
    assert(detailHas(addon.L("QUEST_PORTRAIT")))
    assert(ui.detail.height == beforeHeight + 54 + 8 + 64 + 8)
    local portraitBottom = -ui.portrait.point[3] + 64
    local captionBottom
    for _, fs in ipairs(ui.details) do
        if fs.shown and fs.text==addon.L("QUEST_PORTRAIT") then captionBottom = -fs.point[3]+fs:GetStringHeight() end
    end
    assert(captionBottom and -ui.portrait.point[3]>=captionBottom and ui.detail.height>=portraitBottom)
    assert(not detailHas("Description"),"Quest portrait does not pull hidden Story prose into the work view")
    measurement = nil
end)
check("Portrait redraw reuses one texture and clears it when switching quests", function()
    local first = ui.portrait
    addon.QuestPortrait = function(id) return id == 2 and { displayID = 54321 } or nil end
    showDetail(2)
    assert(ui.portrait == first and first.shown and first.texture == "rendered portrait")
    showDetail(3)
    assert(not first.shown and first.texture == nil and not detailHas(addon.L("QUEST_PORTRAIT")))
    showDetail(2)
    assert(ui.portrait == first and first.shown)
    ui.quest = nil; ui:RefreshDetail()
    assert(not first.shown and first.texture == nil)
end)
check("Missing or throwing portrait producer and renderer leave no stale image", function()
    local first = ui.portrait
    addon.QuestPortrait = nil; showDetail(2)
    assert(not first.shown and first.texture == nil)
    addon.QuestPortrait = function() error("portrait not available") end; showDetail(2)
    assert(not first.shown and not detailHas(addon.L("QUEST_PORTRAIT")))
    addon.QuestPortrait = function() return { displayID = 12345 } end
    SetPortraitTextureFromCreatureDisplayID = nil; showDetail(2)
    assert(not first.shown and first.texture == nil)
    SetPortraitTextureFromCreatureDisplayID = function(texture)
        texture:SetTexture("partial failed image"); error("renderer failed")
    end
    showDetail(2)
    assert(not first.shown and first.texture == nil and not detailHas(addon.L("QUEST_PORTRAIT")))
end)
check("Portrait UI rejects invalid and restricted display IDs without fallback", function()
    local calls, restricted = 0, {}
    SetPortraitTextureFromCreatureDisplayID = function() calls = calls + 1 end
    for _, displayID in ipairs({ 0, -1, 1.5, "12345", math.huge, 0 / 0, restricted }) do
        addon.QuestPortrait = function() return { displayID = displayID } end
        issecretvalue = function(value) return value == restricted end
        showDetail(2)
        assert(not ui.portrait.shown and ui.portrait.texture == nil and not detailHas(addon.L("QUEST_PORTRAIT")))
    end
    assert(calls == 0)
    addon.QuestPortrait, SetPortraitTextureFromCreatureDisplayID, issecretvalue = nil, nil, nil
end)
check("Item starters show their actual source dungeon without invented giver coordinates", function()
    local start, dungeons, itemName = addon.quests[2].start, addon.dungeons, addon.ItemName
    addon.quests[2].start = { itemID = 17008, name = "Small Scroll", dungeonKey = "rfk", dropNPCID = 4421, dropName = "Charlga" }
    addon.dungeons = { { key = "rfk", name = "Razorfen Kraul" } }
    addon.ItemName = function(id) assert(id == 17008); return "Localized scroll" end
    showDetail(2, { level = 20, completed = function() return false end, active = function() return false end })
    assert(detailHas("" .. addon.L("ITEM_STARTER", "Localized scroll")))
    assert(detailHas(addon.L("ITEM_DROP_SOURCE", "Charlga", "Razorfen Kraul")))
    assert(not ui.giver.enabled and not ui.giverAction and not hasDestination(true))
    assert(ui.engine:State(2).status == "AVAILABLE" and ui.action.kind == "pickup")
    addon.ItemName = nil; showDetail(2, { level = 20, completed = function() return false end, active = function() return false end })
    assert(detailHas("" .. addon.L("ITEM_STARTER", "Small Scroll")))
    showDetail(3)
    assert(not detailHas(addon.L("ITEM_DROP_SOURCE", "Charlga", "Razorfen Kraul")))
    addon.quests[2].start, addon.dungeons, addon.ItemName = start, dungeons, itemName
    ui:Refresh()
end)
check("Material rows use fresh client item names and retain explicit ID fallback", function()
    addon.quests[900] = { id = 900, minLevel = 1, requirementsKnown = true,
        completionQuests = { { id = 901, itemID = 7083 } } }
    addon.quests[901] = { id = 901, minLevel = 1, requirementsKnown = false }
    addon.ItemName = function(id) assert(id == 7083); return "Localized material" end
    showSources(900)
    assert(ui.materialButtons[1].note.text:find("Localized material", 1, true))
    assert(not ui.materialButtons[1].note.text:find(addon.L("MATERIAL_ITEM", 7083), 1, true))
    addon.ItemName = function() return nil end; showSources(900)
    assert(ui.materialButtons[1].note.text:find(addon.L("MATERIAL_ITEM", 7083), 1, true))
    addon.ItemName = nil; addon.quests[900], addon.quests[901] = nil, nil
end)
check("Multiple item drop sources remain distinct without an invented interior pickup", function()
    local start = addon.quests[2].start
    addon.quests[2].start = { itemID = 7666, name = "Shattered Necklace", dropSources = {
        { npcID = 4852, name = "Stonevault Oracle", locationName = "Uldaman" },
        { npcID = 4845, name = "Shadowforge Ruffian", locationName = "Badlands" },
    } }
    showSources(2)
    assert(detailHas(addon.L("ITEM_DROP_SOURCE", "Stonevault Oracle", "Uldaman")))
    assert(detailHas(addon.L("ITEM_DROP_SOURCE", "Shadowforge Ruffian", "Badlands")))
    assert(not ui.giver.enabled and not hasDestination(true) and not addon.quests[2].startsInside)
    showSources(3)
    assert(not detailHas(addon.L("ITEM_DROP_SOURCE", "Stonevault Oracle", "Uldaman")))
    addon.quests[2].start = start
end)
check("Alternative starters remain uncertain and navigate only the explicitly selected location", function()
    local visited, mapped = {}, {}
    addon.Navigation = { Start = function(a) visited[#visited + 1] = a end,
        Map = function(a) mapped[#mapped + 1] = a end }
    addon.quests[2861] = { id = 2861, minLevel = 1, requirementsKnown = false,
        startAlternatives = {
            { npcID = 4568, name = "Anastasia", mapID = 1, x = 10, y = 20 },
            { objectID = 142702, name = "Bottle", zoneName = "Known zone" },
            { npcID = 5144, name = "Bink", mapID = 2 },
        } }
    measurement = function(fs) if fs.text == "Anastasia" then return 54 end; return 18 end
    showSources(2861)
    assert(detailHas(addon.L("START_ALTERNATIVES")))
    assert(ui.engine:State(2861).status == "UNKNOWN" and ui.action == nil)
    assert(not ui.giver.enabled and not hasDestination(true) and #visited == 0 and #mapped == 0)
    assert(startButton(1).title.text == "Anastasia" and startButton(1).height > 59)
    assert(startButton(2).title.text == "Bottle" and startButton(2).note.text == "Known zone — |cffff594d" .. addon.L("SOURCE_POSITION_UNKNOWN") .. "|r")
    assert(not startButton(2).enabled and not startButton(2).scripts.OnClick)
    startButton(1).scripts.OnClick()
    assert(#visited == 1 and visited[1].kind == "visit" and visited[1].place.npcID == 4568)
    startButton(3).scripts.OnClick()
    assert(#mapped == 1 and mapped[1].npcID == 5144 and mapped[1].mapID == 2 and mapped[1].place == nil)
    assert(ui.engine:State(2861).status == "UNKNOWN" and ui.action == nil)
    assert(not addon.quests[2861].classes and not addon.quests[2861].start)
    measurement = nil
    showSources(2)
    for _, row in ipairs(ui.startButtons) do
        assert(not row.shown and not row.enabled and not row.scripts.OnClick)
    end
    assert(not detailHas(addon.L("START_ALTERNATIVES")))
    addon.quests[2861].startAlternatives = { { npcID = 10, name = "Short" }, { objectID = 11, name = "Other" } }
    showSources(2861)
    assert(startButton(1).title.text == "Short" and startButton(1).height == 59)
    assert(not startButton(3).shown and not startButton(3).scripts.OnClick)
    addon.quests[2861].requirementsKnown = true
    addon.quests[2861].requires = { { ids = { 1 } } }
    addon.quests[2861].startAlternatives[1] = { npcID = 10, name = "Known", mapID = 3, x = 40, y = 50 }
    showSources(2861, { level = 20, completed = function() return false end, active = function() return false end })
    local prerequisite = ui.action
    assert(ui.engine:State(2861).status == "LOCKED" and prerequisite.id == 1)
    startButton(1).scripts.OnClick()
    assert(ui.action == prerequisite and visited[#visited].place.npcID == 10)
    assert(ui.engine:State(2861).status == "LOCKED")
    addon.quests[2861] = nil
end)
check("Known source zones display without inventing a client map or navigation", function()
    local start, finish, maps = addon.quests[2].start, addon.quests[2].finish, C_Map
    addon.quests[2].start = { npcID = 1, name = "Olvek", zoneName = "Alterac Mountains" }
    addon.quests[2].finish = { npcID = 2, name = "Other", zoneName = "Known finish" }
    showDetail(2)
    assert(detailHas("Olvek — Alterac Mountains"))
    assert(detailHas(addon.L("DETAIL_TURNIN")..": Other — Known finish"))
    assert(not ui.giver.enabled and not hasDestination(true) and not hasDestination(false))
    addon.quests[2].start.mapID = 1
    C_Map = { GetMapInfo = function() return { name = "Native zone" } end }
    showDetail(2)
    assert(detailHas("Olvek — Native zone"))
    assert(ui.giver.enabled and not ui.giverHasCoordinates)
    addon.quests[2].start, addon.quests[2].finish, C_Map = start, finish, maps
end)
check("Grouped middle stories keep source grouping separate from acceptance requirements",function()
    local dungeon,context=ui.dungeon,addon.Context
    addon.quests[910]={id=910,minLevel=1,requirementsKnown=false,storylineGroups={{911,912},{910}}}
    addon.quests[911]={id=911,minLevel=1,requirementsKnown=true,requires={{ids={1}}}}
    addon.quests[912]={id=912,minLevel=1,requirementsKnown=true,factions={"Horde"}}
    addon.Context=function()return {level=20,faction="Alliance",completed=function()return false end,active=function()return false end}end
    ui.dungeon={key="grouped",quests={910}};ui.quest,ui.questTreeRoot,ui.questTreeDungeon=910,910,ui.dungeon
    ui:RefreshQuests();ui:RefreshDetail()
    assert(ui.engine:State(910).status=="UNKNOWN" and not ui.action)
    local byID={};for _,row in ipairs(ui.rows)do if row.shown and row.questTreeNode and row.questID then byID[row.questID]=row end end
    assert(byID[911] and byID[912] and byID[910] and byID[1],"optional source ancestors remain inspectable")
    assert(byID[1].questTreeRelation=="required" and not byID[1].questTreePath)
    assert(byID[911].questTreeRelation=="story" and byID[912].questTreeRelation=="story")
    byID[912].scripts.OnClick();assert(ui.quest==912 and ui.engine:State(912).status=="UNAVAILABLE" and not ui.action)
    assert(not detailHas(addon.L("STORY_GROUP_NOTICE")))
    addon.quests[910],addon.quests[911],addon.quests[912]=nil,nil,nil
    addon.Context,ui.dungeon=context,dungeon;ui.questTreeRoot,ui.questTreeDungeon=nil,nil;showDetail(2);ui:RefreshQuests()
end)
check("Grouped middle rows wrap recycle and avoid duplicating a single source target",function()
    local dungeon=ui.dungeon
    addon.quests[910]={id=910,minLevel=1,requirementsKnown=false,storylineGroups={{911,910}}}
    addon.quests[911]={id=911,minLevel=1,requirementsKnown=false}
    ui.dungeon={key="group-wrap",quests={910}};ui.quest,ui.questTreeRoot,ui.questTreeDungeon=910,910,ui.dungeon
    measurement=function(fs)return fs.text and fs.text:find("Quest 911",1,true) and 72 or 18 end
    ui:RefreshQuests();local long,following
    for _,row in ipairs(ui.rows)do if row.shown and row.questID==911 then long=row elseif row.shown and row.questTreeNode and row.questID==910 then following=row end end
    assert(long and long.height>=84 and following and -following.point[3]>=-long.point[3]+long.height)
    measurement=nil;addon.quests[910].storylineGroups=nil;addon.quests[910].storyline={910};ui:RefreshQuests()
    for _,row in ipairs(ui.rows)do assert(not(row.shown and row.questID==911))end
    addon.quests[910],addon.quests[911]=nil,nil;ui.dungeon=dungeon;ui.questTreeRoot,ui.questTreeDungeon=nil,nil;showDetail(2);ui:RefreshQuests()
end)
check("Alternative turn-ins are explicit location visits without readiness or action changes", function()
    local started, mapped
    addon.Navigation = { Start = function(a) started = a end, Map = function(p) mapped = p end }
    addon.quests[3801] = { id = 3801, minLevel = 1, requirementsKnown = false,
        finishAlternatives = {
            { npcID = 8888, name = "Franclorn", mapID = 1, x = 10, y = 20 },
            { npcID = 184290, name = "Other Franclorn", mapID = 2 },
            { objectID = 10, name = "Unknown monument", zoneName = "Known zone" },
        } }
    measurement = function(fs) if fs.text == "Franclorn" then return 72 end; return 18 end
    showSources(3801)
    assert(detailHas(addon.L("POSSIBLE_TURNINS")))
    assert(ui.engine:State(3801).status == "UNKNOWN" and ui.action == nil and not started and not mapped)
    assert(ui.finishButtons[1].height > 59 and ui.finishButtons[2].title.text == "Other Franclorn")
    assert(ui.finishButtons[3].note.text == "Known zone — |cffff594d" .. addon.L("SOURCE_POSITION_UNKNOWN") .. "|r" and not ui.finishButtons[3].enabled)
    ui.finishButtons[1].scripts.OnClick()
    assert(started.id == 3801 and started.kind == "visit" and started.place.npcID == 8888)
    ui.finishButtons[2].scripts.OnClick()
    assert(mapped == addon.quests[3801].finishAlternatives[2] and not mapped.place)
    assert(ui.engine:State(3801).status == "UNKNOWN" and ui.action == nil)
    addon.quests[3801].requirementsKnown = true
    addon.quests[3801].requires = { { ids = { 1 } } }
    local context = { level = 20, completed = function() return false end, active = function() return false end }
    showSources(3801, context)
    local nextAction = ui.action
    assert(nextAction.id == 1 and ui.engine:State(3801).status == "LOCKED")
    ui.finishButtons[1].scripts.OnClick()
    assert(ui.action == nextAction and ui.engine:State(3801).status == "LOCKED")
    measurement = nil
    showSources(2)
    for _, b in ipairs(ui.finishButtons) do assert(not b.shown and not b.enabled and not b.scripts.OnClick) end
    assert(not detailHas(addon.L("POSSIBLE_TURNINS")))
    addon.quests[3801].finishAlternatives = { { npcID = 1, name = "Short" }, { objectID = 2, name = "Other" } }
    showSources(3801, context)
    assert(ui.finishButtons[1].height == 59 and not ui.finishButtons[1].enabled and not ui.finishButtons[3].shown)
    addon.quests[3801] = nil
end)
check("Starter item requirements stay informational for unknown and available quests", function()
    local oldNames = LOCALIZED_CLASS_NAMES_MALE
    LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Localized warrior", PALADIN = "Localized paladin" }
    addon.quests[920] = { id = 920, minLevel = 1, requirementsKnown = false,
        start = { itemID = 18469, itemClasses = { "WARRIOR", "PALADIN" }, itemMinLevel = 54 } }
    local context = { level = 20, class = "MAGE", completed = function() return false end,
        active = function() return false end }
    showSources(920, context)
    assert(detailHas(addon.L("ITEM_CLASSES", "Localized warrior, Localized paladin")))
    assert(detailHas(addon.L("ITEM_MIN_LEVEL", 54)) and detailHas(addon.L("ITEM_REQUIREMENTS_NOTICE")))
    assert(addon.Planner.Eligible(addon.quests[920], context) == true)
    assert(ui.engine:State(920).status == "UNKNOWN" and ui.action == nil)
    local actions, uncertain = ui.engine:Next(920)
    assert(#actions == 0 and uncertain)
    addon.quests[920].requirementsKnown = true
    showSources(920, context)
    assert(ui.engine:State(920).status == "AVAILABLE" and ui.action.kind == "pickup" and ui.action.id == 920)
    context.class, context.level = "WARRIOR", 60
    showSources(920, context)
    assert(ui.engine:State(920).status == "AVAILABLE" and ui.action.kind == "pickup")
    addon.quests[920].classes = { "MAGE" }
    showSources(920, context)
    assert(ui.engine:State(920).status == "UNAVAILABLE" and ui.action == nil)
    showSources(2)
    assert(not detailHas(addon.L("ITEM_MIN_LEVEL", 54)) and not detailHas(addon.L("ITEM_REQUIREMENTS_NOTICE")))
    addon.quests[920], LOCALIZED_CLASS_NAMES_MALE = nil, oldNames
end)
check("Starter item class labels use native localization and safe token fallback", function()
    local oldNames, oldList = LOCALIZED_CLASS_NAMES_MALE, LocalizedClassList
    LOCALIZED_CLASS_NAMES_MALE = nil
    local calls = 0
    LocalizedClassList = function(female)
        assert(female == false); calls = calls + 1
        return { WARRIOR = calls == 1 and "First locale" or "Second locale" }
    end
    addon.quests[920] = { id = 920, minLevel = 1, requirementsKnown = false,
        start = { itemID = 18469, itemClasses = { "WARRIOR", "PALADIN" } } }
    showSources(920)
    assert(detailHas(addon.L("ITEM_CLASSES", "First locale, PALADIN")))
    showSources(920)
    assert(detailHas(addon.L("ITEM_CLASSES", "Second locale, PALADIN")))
    LocalizedClassList = function() error("native unavailable") end
    showSources(920)
    assert(detailHas(addon.L("ITEM_CLASSES", "WARRIOR, PALADIN")))
    LOCALIZED_CLASS_NAMES_MALE = setmetatable({}, { __index = function() error("restricted lookup") end })
    showSources(920)
    assert(detailHas(addon.L("ITEM_CLASSES", "WARRIOR, PALADIN")))
    addon.quests[920].start.itemID = nil
    showSources(920)
    assert(not detailHas(addon.L("ITEM_CLASSES", "WARRIOR, PALADIN")))
    assert(not detailHas(addon.L("ITEM_REQUIREMENTS_NOTICE")))
    addon.quests[920], LOCALIZED_CLASS_NAMES_MALE, LocalizedClassList = nil, oldNames, oldList
end)
check("Open dialogue rewards take precedence and display experience without reading another source", function()
    local logReads = 0
    addon.QuestRewards = function() logReads = logReads + 1; return { items = {}, choices = {} } end
    addon.DialogueRewards = function(id)
        assert(id == 2)
        return { source = "dialogue", items = { { name = "Offered token", count = 2 } },
            choices = {}, money = 0, xp = 1234 }
    end
    showDetail(2)
    assert(detailHas(addon.L("REWARD_ITEM", "Offered token", 2)))
    assert(not detailHas(addon.L("REWARD_DIALOGUE")) and detailHas(addon.L("REWARD_XP", 1234)))
    assert(logReads == 0)
    addon.DialogueRewards = function() return nil end
    showDetail(2)
    assert(logReads == 1 and not detailHas(addon.L("REWARD_ITEM", "Offered token", 2)))
    assert(not detailHas(addon.L("REWARD_DIALOGUE")) and not detailHas(addon.L("REWARD_XP", 1234)))
    addon.DialogueRewards, addon.QuestRewards = nil, nil
end)
check("Hidden dialogue rewards never become an empty list or fall through to quest log rewards", function()
    addon.DialogueRewards = function() return { source = "dialogue", hidden = true } end
    addon.QuestRewards = function() error("hidden dialogue must not use log fallback") end
    showDetail(2)
    assert(not detailHas(addon.L("REWARD_HIDDEN")))
    assert(not detailHas(addon.L("REWARD_NO_ITEMS")) and not detailHas(addon.L("REWARD_UNAVAILABLE")))
    addon.DialogueRewards = function() return { source = "dialogue", items = {}, choices = {}, xp = 0 } end
    showDetail(2)
    assert(not detailHas(addon.L("REWARD_NO_ITEMS")) and detailHas(addon.L("REWARD_XP", 0)))
    assert(not detailHas(addon.L("REWARD_HIDDEN")))
    addon.DialogueRewards, addon.QuestRewards = nil, nil
end)
check("Live dialogue objective prose stays separate from accepted progress and hidden rewards", function()
    local oldObjective, oldProgress, oldRewards = addon.DialogueObjectiveText, addon.QuestObjectives, addon.DialogueRewards
    showDetail(2)
    local previousState, previousKind = ui.engine:State(2).status, ui.action and ui.action.kind
    local open, calls = true, 0
    addon.DialogueObjectiveText = function(id)
        calls = calls + 1
        if open and id == 2 then return "Bring the sealed report to its recipient." end
    end
    addon.QuestObjectives = function(id)
        if id == 2 then return { { text = "Report delivered: 0/1", finished = false } } end
    end
    addon.DialogueRewards = function() return { source = "dialogue", hidden = true } end
    showDetail(2)
    assert(detailHas(addon.L("OBJECTIVE_DIALOGUE")))
    assert(detailHas("Bring the sealed report to its recipient."))
    assert(detailHas(addon.L("OBJECTIVE_PROGRESS")))
    local summaryIndex, progressIndex, progressText
    for i, fs in ipairs(ui.details) do
        if fs.shown and fs.text == addon.L("OBJECTIVE_DIALOGUE") then summaryIndex = i end
        if fs.shown and fs.text == addon.L("OBJECTIVE_PROGRESS") then progressIndex = i end
        if fs.shown and fs.text:find("Report delivered: 0/1", 1, true) then progressText = true end
    end
    assert(progressIndex < summaryIndex and progressText and not detailHas(addon.L("REWARD_HIDDEN")))
    assert(ui.engine:State(2).status == previousState and (ui.action and ui.action.kind) == previousKind)
    showDetail(1)
    assert(not detailHas(addon.L("OBJECTIVE_DIALOGUE")) and not detailHas(addon.L("OBJECTIVE_PROGRESS")))
    assert(not detailHas("Bring the sealed report to its recipient."))
    showDetail(2)
    assert(detailHas(addon.L("OBJECTIVE_DIALOGUE")) and calls == 3)
    open = false; ui:Refresh()
    assert(not detailHas(addon.L("OBJECTIVE_DIALOGUE")) and not detailHas("Bring the sealed report to its recipient."))
    assert(detailHas(addon.L("OBJECTIVE_PROGRESS")) and not detailHas(addon.L("REWARD_HIDDEN")))
    addon.DialogueObjectiveText, addon.QuestObjectives, addon.DialogueRewards = oldObjective, oldProgress, oldRewards
end)
check("Missing or unusable dialogue objective summaries leave no recycled heading or text", function()
    local previous = addon.DialogueObjectiveText
    addon.DialogueObjectiveText = function() return "Temporary dialogue summary" end
    showDetail(2); assert(detailHas("Temporary dialogue summary"))
    for _, producer in ipairs({ false, function() return nil end, function() return "" end,
        function() return 42 end, function() return string.rep("x", 30001) end,
        function() error("dialogue unavailable") end }) do
        addon.DialogueObjectiveText = producer
        ui:Refresh()
        assert(not detailHas(addon.L("OBJECTIVE_DIALOGUE")) and not detailHas("Temporary dialogue summary"))
    end
    addon.DialogueObjectiveText = previous
end)
check("Catalogue labels follow character eligibility and retain selection", function()
    local dungeons, context = addon.dungeons, addon.Context
    local search, range, includeUnavailable = ui.search, ui.range, ui.includeUnavailable
    local selected, quest = ui.dungeon, ui.quest
    local factions = addon.quests[2].factions
    addon.quests[2].factions = { "Horde" }
    addon.Context = function() return { level = 20, faction = "Alliance", completed=function()return false end, active=function()return false end } end
    local listed = { key = "listed", name = "Listed dungeon", minLevel = 10, maxLevel = 30, quests = { 1, 2 } }
    local empty = { key = "empty", name = "Empty dungeon", minLevel = 40, maxLevel = 50, quests = {} }
    addon.dungeons = { listed, empty }
    ui.search, ui.range, ui.includeUnavailable, ui.dungeon, ui.quest = "", false, false, listed, 2
    measurement = function(fs) return fs.text and fs.text:find("\n", 1, true) and 36 or 18 end
    ui:RefreshDungeons()
    local card = ui.cards[1]
    assert(card.note.text == addon.L("CATALOG_COMPACT_META", 10, 30, 1))
    assert(card.height == 76 and ui.cards[2].point[3] == -84, "compact metadata and cover fit cumulative geometry")
    assert(addon.Planner.Eligible(addon.quests[2], addon.Context()) == false)
    ui.includeUnavailable = true; ui:RefreshDungeons()
    assert(card.note.text==addon.L("CATALOG_COMPACT_META",10,30,2), "All counts every listed root")
    ui.search = "Empty"; ui:RefreshDungeons()
    assert(ui.cards[1] == card and card.title.text == "Empty dungeon")
    assert(card.note.text == addon.L("CATALOG_COMPACT_META",40,50,0))
    assert(not ui.cards[2].shown and ui.dungeon == listed and ui.quest == 2)
    ui.search = "no such dungeon"; ui:RefreshDungeons()
    assert(ui.catalogNotice.shown and not card.shown and ui.dungeon == listed and ui.quest == 2)
    measurement = nil
    addon.quests[2].factions, addon.dungeons, addon.Context = factions, dungeons, context
    ui.search, ui.range, ui.includeUnavailable, ui.dungeon, ui.quest = search, range, includeUnavailable, selected, quest
    ui:Refresh()
end)
check("Middle prerequisites expose AND and OR structure and distinguish acceptance from completion",function()
    local oldContext,dungeon=addon.Context,ui.dungeon
    local context={level=20,faction="Alliance",active=function(id)return id==971 end,completed=function(id)return id==972 end}
    addon.Context=function()return context end
    addon.quests[970]={id=970,minLevel=1,requirementsKnown=true,requires={{ids={971}},{ids={972,973},mode="active"}}}
    addon.quests[971]={id=971,minLevel=1,requirementsKnown=true}
    addon.quests[972]={id=972,minLevel=1,requirementsKnown=true}
    addon.quests[973]={id=973,minLevel=1,requirementsKnown=true,factions={"Horde"}}
    ui.dungeon={key="requirements",quests={970}};ui.quest,ui.questTreeRoot,ui.questTreeDungeon=970,970,ui.dungeon
    measurement=function(fs)return fs.text=="Quest 971" and 72 or 18 end
    ui:RefreshQuests();ui:RefreshDetail()
    assert(ui.engine:State(970).status=="LOCKED" and ui.action.id==971 and ui.action.kind=="complete")
    local function rowFor(id)for _,row in ipairs(ui.rows)do if row.shown and row.questTreeNode and row.questID==id then return row end end end
    local row=rowFor(971);assert(row and row.title.text=="Quest 971" and row.height>=84 and row.questTreeRelation=="required")
    assert(row.note.text:find(addon.L("ACTIVE"),1,true))
    assert(rowFor(972).note.text:find(addon.L("REQUIREMENT_ACTIVE"),1,true))
    local unavailable=rowFor(973).branchControl;assert(unavailable and not unavailable.enabled)
    local click=row.scripts.OnClick;click();assert(ui.quest==971 and ui.engine:State(971).status=="ACTIVE" and ui.questTreeRoot==970)
    ui.quest=970;ui:RefreshQuests();ui:RefreshDetail();click();assert(ui.quest==970,"old middle-row callbacks expire after publication")
    addon.quests[970].requirementsKnown=false;addon.quests[970].requires={{ids={974}}}
    ui:RefreshQuests();ui:RefreshDetail();assert(ui.engine:State(970).status=="UNKNOWN" and not ui.action)
    row=rowFor(974);assert(row and row.note.text:find(addon.L("UNKNOWN"),1,true));row.scripts.OnClick()
    assert(ui.quest==974 and detailHas(addon.L("REASON_missing")) and not ui.action)
    for _,id in ipairs({970,971,972,973})do addon.quests[id]=nil end
    measurement=nil;addon.Context,ui.dungeon=oldContext,dungeon;ui.questTreeRoot,ui.questTreeDungeon=nil,nil;showDetail(2);ui:RefreshQuests()
end)
check("Explicit supporting-card inspection can go back without recording refreshes or branch choices", function()
    local dungeons, selected, quest, preparation = addon.dungeons, ui.dungeon, ui.quest, ui.preparation
    local choices, selectedDungeon = addon.char.choices, addon.char.selectedDungeon
    addon.char.choices = {}
    for _, id in ipairs({ 980, 981, 982, 983, 984 }) do
        addon.quests[id] = { id = id, minLevel = 1, requirementsKnown = true }
    end
    addon.quests[980].requires = { { ids = { 981 } }, { ids = { 982, 983 } } }
    addon.quests[980].storyline = { 981, 980 }
    addon.quests[980].completionQuests = { { id = 984, itemID = 7000 } }
    local dungeon = { key = "history", name = "History dungeon", minLevel = 1, maxLevel = 30,
        quests = { 980, 981 }, coverage = "partial" }
    local other = { key = "other", name = "Other dungeon", minLevel = 1, maxLevel = 30, quests = { 982 } }
    addon.dungeons, ui.dungeon, ui.quest, ui.preparation, ui.detailHistory = { dungeon, other }, dungeon, 980, false, {}
    ui:Refresh()
    assert(canGoBack() and ui.back == nil, "a root quest can now return to its selected dungeon overview")
    ui.questTreeRoot,ui.questTreeDungeon=980,dungeon;ui:RefreshQuests()
    local function parentRow()for _,row in ipairs(ui.rows)do if row.shown and row.questTreeNode and row.questID==981 then return row end end end
    expandDetail()
    local singleton = parentRow()
    singleton.scripts.OnClick()
    assert(ui.quest == 981 and #ui.detailHistory == 1 and ui.detailHistory[1] == 980 and canGoBack())
    assert(ui.questTreeRoot==980,"supporting inspection preserves the middle context")
    ui:BackQuest()
    assert(ui.quest == 980 and #ui.detailHistory == 0 and canGoBack(), "history is exhausted; overview remains reachable")
    expandDetail()
    parentRow().scripts.OnClick()
    assert(ui.quest == 981 and #ui.detailHistory == 1)
    ui:BackQuest()
    assert(ui:SetDetailTab("sources"))
    local material = ui.materialButtons[1]
    material.scripts.OnClick()
    assert(ui.quest == 984 and #ui.detailHistory == 1 and not material.scripts.OnClick)
    ui:BackQuest()
    parentRow().scripts.OnClick()
    assert(ui.quest == 981 and #ui.detailHistory == 1)
    ui:BackQuest()
    ui:Refresh(); ui:RefreshDetail(); ui:InspectQuest(980)
    assert(#ui.detailHistory == 0)
    assert(ui:ChooseBranch(980, 2, 982) and #ui.detailHistory == 0 and ui.quest == 980)
    ui:InspectQuest(981)
    assert(#ui.detailHistory == 1)
    ui.cards[2].scripts.OnClick()
    assert(ui.dungeon == other and ui.quest == nil and #ui.detailHistory == 0 and not canGoBack())
    for _, row in ipairs(ui.rows) do if not row.shown then assert(not row.scripts.OnClick) end end
    assert(addon.char.detailHistory == nil and addon.db.detailHistory == nil)
    for _, id in ipairs({ 980, 981, 982, 983, 984 }) do addon.quests[id] = nil end
    addon.char.choices, addon.char.selectedDungeon = choices, selectedDungeon
    addon.dungeons, ui.dungeon, ui.quest, ui.preparation, ui.detailHistory = dungeons, selected, quest, preparation, {}
    ui.questTreeRoot,ui.questTreeDungeon=nil,nil
    ui:Refresh()
end)
check("Back history caps clean IDs at twenty and supports unknown cards without repushing", function()
    local quest, history = ui.quest, ui.detailHistory
    ui.quest, ui.detailHistory = 2000, {}
    for id = 2001, 2025 do assert(ui:InspectQuest(id)) end
    assert(#ui.detailHistory == 20 and ui.detailHistory[1] == 2005 and ui.detailHistory[20] == 2024)
    ui:InspectQuest(2025); ui:RefreshDetail(); expandDetail()
    assert(#ui.detailHistory == 20 and detailHas(addon.L("REASON_missing")))
    for _, id in ipairs({ 0, -1, 1.5, math.huge, "2026", false }) do assert(not ui:InspectQuest(id)) end
    assert(ui.quest == 2025 and #ui.detailHistory == 20)
    for expected = 2024, 2005, -1 do assert(ui:BackQuest() and ui.quest == expected) end
    assert(#ui.detailHistory == 0 and canGoBack())
    assert(ui:BackQuest() and ui.quest == nil and not canGoBack() and not ui:BackQuest(), "one further Back reaches the overview without a history sentinel")
    ui.quest, ui.detailHistory = quest, history
    ui:RefreshDetail()
end)
check("Detail scroll resets on changed card identity but preserves same-card reading position", function()
    local quest, history, locale = ui.quest, ui.detailHistory, addon.db.locale
    ui.detailHistory = {}
    showDetail(1)
    local scroll = ui.detailScroll
    assert(scroll and scroll ~= ui.detail)
    scroll:SetVerticalScroll(170)
    local writes = scroll.scrollWrites
    ui:RefreshDetail(); ui:Refresh(); ui:InspectQuest(1)
    ui.language.scripts.OnClick()
    assert(scroll.verticalScroll == 170 and scroll.scrollWrites == writes)
    ui:InspectQuest(2)
    assert(scroll.verticalScroll == 0 and scroll.scrollWrites == writes + 1)
    scroll:SetVerticalScroll(90)
    assert(ui:BackQuest() and ui.quest == 1)
    assert(scroll.verticalScroll == math.min(170, scroll:GetVerticalScrollRange()),
        "Back restores the saved reading offset within the fresh card range")
    scroll:SetVerticalScroll(125)
    ui.cards[1].scripts.OnClick()
    assert(ui.quest == nil and scroll.verticalScroll == 0)
    scroll:SetVerticalScroll(30); writes = scroll.scrollWrites
    ui:RefreshDetail()
    assert(scroll.verticalScroll == 30 and scroll.scrollWrites == writes, "same nil-card redraw is not new navigation")
    addon.db.locale, ui.quest, ui.detailHistory = locale, quest, history
    ui:Refresh()
end)
check("Held quests with past completion show history consistently without implying repeatability", function()
    local function context(done)
        return { level = 20, completed = function(id) return id == 993 or ((id == 991 or id == 992) and done) end,
            active = function(id) return id == 991 or id == 992 end, ready = function(id) return id == 992 end }
    end
    for _, id in ipairs({ 990, 991, 992, 993 }) do
        addon.quests[id] = { id = id, minLevel = 1, requirementsKnown = true }
    end
    addon.quests[990].requires = { { ids = { 991 } }, { ids = { 992, 993 } } }
    addon.quests[990].completionQuests = { { id = 991, itemID = 7000 } }
    local marker = addon.L("COMPLETED_BEFORE")
    local function headerContains(value)
        for _, fs in ipairs(ui.details) do if fs.shown and fs.text:find(value, 1, true) then return true end end
        return false
    end
    showDetail(991, context(true))
    assert(headerContains(addon.L("ACTIVE") .. " — " .. marker) and not detailHas(addon.L("REPEATABLE")))
    assert(ui.action.id == 991 and ui.action.kind == "complete")
    showDetail(992, context(true))
    assert(headerContains(addon.L("READY") .. " — " .. marker) and ui.action.kind == "turnin")
    showDetail(990, context(true))
    assert(ui.engine:State(990).status == "AVAILABLE" and ui.action.id == 990)
    local previousContext,dungeon=addon.Context,ui.dungeon
    addon.Context=function()return context(true)end
    ui.dungeon={key="history-status",quests={990}};ui.questTreeRoot,ui.questTreeDungeon=990,ui.dungeon;ui:RefreshQuests()
    local branchMarked,chainMarked=false,0
    for _,row in ipairs(ui.rows)do if row.shown and row.questTreeNode then
        if row.questID==991 then assert(row.note.text:find(addon.L("ACTIVE").." — "..marker,1,true))end
        if row.questID==992 then branchMarked=row.note.text:find(addon.L("READY").." — "..marker,1,true)end
        if row.questID==993 then assert(not row.note.text:find(marker,1,true))end
        if row.note.text:find(marker,1,true)then chainMarked=chainMarked+1 end
    end end
    assert(branchMarked and chainMarked == 2)
    showSources(990, context(true))
    assert(ui.materialButtons[1].shown and ui.materialButtons[1].note.text:find(marker, 1, true))
    addon.Context,ui.dungeon=previousContext,dungeon;ui.questTreeRoot,ui.questTreeDungeon=nil,nil
    showDetail(993, context(true))
    assert(ui.engine:State(993).status == "COMPLETED" and not headerContains(marker))
    showDetail(991, context(false))
    assert(ui.engine:State(991).status == "ACTIVE" and not headerContains(marker))
    showDetail(991, context(nil))
    assert(ui.engine:State(991).status == "ACTIVE" and not headerContains(marker))
    ui.engine.states[991].completedHistory = "true"; ui:RefreshDetail()
    assert(not headerContains(marker))
    ui.engine.states[991].status, ui.engine.states[991].completedHistory = "UNKNOWN", true
    ui:RefreshDetail(); assert(not headerContains(marker))
    for _, id in ipairs({ 990, 991, 992, 993 }) do addon.quests[id] = nil end
    showDetail(2)
end)
local function detailIncludes(value)
    for _, fs in ipairs(ui.details) do if fs.shown and audienceText(fs.text):find(value, 1, true) then return true end end
    return false
end
check("Current NPC names refresh start finish and preparation without changing places or catalogue", function()
    local oldContext, preparation = addon.Context, ui.preparation
    addon.Context = function() return { level = 20, completed = function() return false end, active = function() return false end } end
    local oldStart, oldFinish, producer = addon.quests[2].start, addon.quests[2].finish, addon.GiverName
    local start = { npcID = 101, name = "Catalog start", mapID = 1, x = 12, y = 20 }
    local finish = { npcID = 102, name = "Catalog finish" }
    addon.quests[2].start, addon.quests[2].finish = start, finish
    local current = 101
    addon.GiverName = function(place) return place.npcID == current and ("Native " .. current) or nil end
    showDetail(2)
    assert(detailIncludes("Native 101") and detailIncludes("Catalog finish"))
    assert(ui.action.place == start and start.name == "Catalog start" and finish.name == "Catalog finish")
    ui.preparation = true; ui:RefreshQuests(); ui:RefreshDetail()
    local marked = false
    for _, row in ipairs(visibleRows()) do if row.questID == 2 or row.title.text == "Quest 2" then
        marked = row.note.text:find("Native 101", 1, true) ~= nil
    end end
    assert(marked, "preparation uses same fresh giver name")
    current = 102; ui:RefreshDetail()
    assert(detailIncludes("Catalog start") and detailIncludes(addon.L("DETAIL_TURNIN")..": Native 102"))
    current = nil; ui:RefreshDetail()
    assert(not detailIncludes("Native 101") and not detailIncludes("Native 102") and detailIncludes("Catalog finish"))
    addon.quests[2].start, addon.quests[2].finish, addon.GiverName = oldStart, oldFinish, producer
    addon.Context, ui.preparation = oldContext, preparation; ui:Refresh()
end)
check("Missing throwing invalid and restricted NPC names retain safe catalogue labels", function()
    local old, producer = addon.quests[2].start, addon.GiverName
    local restricted = {}
    addon.quests[2].start = { npcID = 101, name = "Catalog fallback" }
    issecretvalue = function(value) return value == restricted end
    for _, value in ipairs({ "", false, 123, {}, restricted, string.rep("x", 1025) }) do
        addon.GiverName = function() return value end; showDetail(2)
        assert(detailIncludes("Catalog fallback"))
    end
    addon.GiverName = function() error("unavailable") end; showDetail(2)
    assert(detailIncludes("Catalog fallback"))
    addon.GiverName = nil; showDetail(2); assert(detailIncludes("Catalog fallback"))
    addon.quests[2].start.name = nil; showDetail(2)
    assert(detailIncludes(addon.L("GIVER_LOCATION_UNKNOWN")) and not ui.giver.enabled)
    issecretvalue = nil
    addon.quests[2].start, addon.GiverName = old, producer; ui:Refresh()
end)
check("Alternative NPC rows refresh while object labels and item names keep separate ownership", function()
    local start, finish, alternatives, finishes = addon.quests[2].start, addon.quests[2].finish,
        addon.quests[2].startAlternatives, addon.quests[2].finishAlternatives
    local producer, itemName = addon.GiverName, addon.ItemName
    local current, native, invalidCalls = 101, "Native alternative", 0
    addon.GiverName = function(place)
        if not place.npcID or place.itemID or place.objectID then invalidCalls = invalidCalls + 1 end
        assert(invalidCalls == 0, "only actual NPC descriptors go to producer")
        return place.npcID == current and native or nil
    end
    local npc = { npcID = 101, name = "Catalog alternative", mapID = 1, x = 10, y = 20 }
    local object = { objectID = 202, name = "Catalog object", mapID = 1 }
    addon.quests[2].startAlternatives = { npc, object }
    addon.quests[2].finishAlternatives = { npc, object }
    showSources(2)
    assert(startButton(1).title.text == native and ui.finishButtons[1].title.text == native)
    assert(startButton(2).title.text == "Catalog object" and ui.finishButtons[2].title.text == "Catalog object")
    assert(npc.name == "Catalog alternative" and startButton(1).enabled)
    current = nil; ui:RefreshDetail()
    assert(startButton(1).title.text == "Catalog alternative")
    assert(ui.finishButtons[1].title.text == "Catalog alternative")
    addon.quests[2].startAlternatives, addon.quests[2].finishAlternatives = nil, nil
    addon.quests[2].start = { itemID = 999, name = "Catalog item", dropNPCID = 101, dropName = "Catalog drop",
        dropSources = { { npcID = 101, name = "Catalog multi drop", locationName = "Source zone" } } }
    addon.ItemName = function(id) assert(id == 999); return "Native item" end
    current = 101; native = "Native drop"; showSources(2)
    assert(detailIncludes(addon.L("ITEM_STARTER", "Native item")))
    assert(detailIncludes(addon.L("ITEM_DROP_SOURCE", native, "Source zone")))
    assert(not startButton(1).shown and not ui.finishButtons[1].shown)
    assert(addon.quests[2].start.dropName == "Catalog drop")
    current = nil; ui:RefreshDetail()
    assert(not detailIncludes("Native drop") and detailIncludes("Catalog multi drop"))
    addon.quests[2].start, addon.quests[2].finish = start, finish
    addon.quests[2].startAlternatives, addon.quests[2].finishAlternatives = alternatives, finishes
    assert(invalidCalls == 0, "object and item labels never query current NPC names")
    addon.GiverName, addon.ItemName = producer, itemName; ui:Refresh()
end)
local function reportedFixture()
    local start = { npcID = 101, name = "Reported NPC", mapID = 1, x = 10, y = 20, zoneName = "Start zone",
        reportedLocations = { { mapID = 1, x = 10, y = 20 }, { mapID = 1, x = 11, y = 21 } } }
    local finish = { objectID = 202, name = "Reported object", mapID = 2, x = 30, y = 40, zoneName = "End zone",
        reportedLocations = { { mapID = 2, x = 30, y = 40 }, { mapID = 2, x = 31, y = 41 } } }
    addon.quests[9920] = { id = 9920, minLevel = 1, requirementsKnown = false, start = start, finish = finish }
    return start, finish
end
local function reportToggle(key)
    for _, b in ipairs(ui.reportedToggles or {}) do if b.shown and b.locationKey == key then return b end end
end
local function reportRows()
    local rows = {}; for _, b in ipairs(ui.reportedRows or {}) do if b.shown then rows[#rows + 1] = b end end
    return rows
end
local function endReports()
    addon.quests[9920] = nil; showDetail(2)
end
check("Reported NPC and object positions default closed without changing primary guidance or availability", function()
    local start, finish = reportedFixture()
    local nav, calls = addon.Navigation, 0
    addon.Navigation = { Start = function() calls = calls + 1 end }
    showSources(9920)
    assert(reportToggle("start") and reportToggle("finish") and #reportRows() == 0)
    assert(reportToggle("start").title.text:find(addon.L("REPORTED_POSITIONS", "Reported NPC", 2), 1, true))
    assert(not detailHas(addon.L("REPORTED_NOTICE")) and calls == 0)
    assert(ui.giverAction.place == start and ui.giverAction.place.x == 10 and not ui.action)
    assert(ui.engine:State(9920).status == "UNKNOWN" and start.x == 10 and finish.x == 30)
    addon.Navigation = nav; endReports()
end)
check("Explicit reported position clicks create detached visit actions and keep each parent independent", function()
    local start, finish = reportedFixture()
    local nav, actions = addon.Navigation, {}
    addon.Navigation = { Start = function(action) actions[#actions + 1] = action end }
    showSources(9920); reportToggle("start").scripts.OnClick()
    local rows = reportRows(); assert(#rows == 2 and #actions == 0 and not ui.action)
    assert(detailHas(addon.L("REPORTED_NOTICE")))
    rows[2].scripts.OnClick()
    assert(#actions == 1 and actions[1].id == 9920 and actions[1].kind == "visit")
    local p = actions[1].place
    assert(p.npcID == 101 and not p.objectID and p.mapID == 1 and p.x == 11 and p.y == 21)
    assert(p ~= start and p ~= start.reportedLocations[2] and start.x == 10 and start.reportedLocations[2].x == 11)
    reportToggle("finish").scripts.OnClick(); rows = reportRows(); assert(#rows == 4)
    rows[4].scripts.OnClick(); p = actions[2].place
    assert(p.objectID == 202 and not p.npcID and p.mapID == 2 and p.x == 31 and p.y == 41)
    assert(ui.giverAction.place == start and ui.engine:State(9920).status == "UNKNOWN")
    reportToggle("start").scripts.OnClick()
    assert(#reportRows() == 2 and reportRows()[1].locationKey == "finish")
    addon.Navigation = nav; endReports()
end)
check("Each alternative endpoint owns its own reported-position expansion and original navigation", function()
    local a, b = reportedFixture()
    local other = { npcID = 101, name = "Second location set", mapID = 3, x = 50, y = 60,
        reportedLocations = { { mapID = 3, x = 50, y = 60 }, { mapID = 3, x = 51, y = 61 } } }
    addon.quests[9920].startAlternatives = { a, other }
    addon.quests[9920].finishAlternatives = { b }
    local nav, actions = addon.Navigation, {}
    addon.Navigation = { Start = function(action) actions[#actions + 1] = action end }
    showSources(9920)
    assert(not reportToggle("start") and not reportToggle("finish"))
    assert(reportToggle("startAlternative:1") and reportToggle("startAlternative:2") and reportToggle("finishAlternative:1"))
    reportToggle("startAlternative:2").scripts.OnClick()
    assert(#reportRows() == 2 and reportRows()[1].destination.mapID == 3)
    assert(not ui.reportedExpanded["startAlternative:1"] and not ui.reportedExpanded["finishAlternative:1"])
    startButton(1).scripts.OnClick()
    assert(actions[1].place == a and actions[1].place.x == 10, "ordinary location visit retains actual primary")
    reportRows()[2].scripts.OnClick()
    assert(actions[2].place.npcID == 101 and actions[2].place.x == 51 and actions[2].place.mapID == 3)
    assert(not ui.action and addon.quests[9920].start == a)
    addon.Navigation = nav; endReports()
end)
check("Same-card refresh preserves expansion while Back restores reading offset but resets expansion", function()
    reportedFixture()
    local locale, history, nav = addon.db.locale, ui.detailHistory, addon.Navigation
    local calls = 0; addon.Navigation = { Start = function() calls = calls + 1 end }; ui.detailHistory = {}
    showSources(9920); reportToggle("start").scripts.OnClick()
    local staleVisit = reportRows()[1].scripts.OnClick
    ui.detailScroll:SetVerticalScroll(77); ui:RefreshDetail()
    assert(#reportRows() == 2 and ui.detailScroll.verticalScroll == 77)
    staleVisit(); assert(calls == 0, "old generation cannot navigate")
    addon.db.locale = "ruRU"; ui:RefreshDetail()
    assert(#reportRows() == 2 and detailHas(addon.L("REPORTED_NOTICE")) and ui.detailScroll.verticalScroll == 77)
    local oldRows = { unpack(reportRows()) }; ui:InspectQuest(2)
    for _, row in ipairs(oldRows) do assert(not row.shown and not row.enabled and row.scripts.OnClick == nil) end
    for _, row in ipairs(ui.reportedToggles) do assert(not row.shown and row.scripts.OnClick == nil) end
    ui:BackQuest(); assert(ui.quest == 9920 and #reportRows() == 0 and not ui.reportedExpanded.start)
    assert(ui.detailScroll.verticalScroll == math.min(77, math.max(0, ui.detail:GetHeight() - ui.detailScroll:GetHeight())) and calls == 0)
    addon.db.locale, ui.detailHistory, addon.Navigation = locale, history, nav; endReports()
end)
check("Reported positions use measured wrapping and recycle expanded rows without stale destinations", function()
    reportedFixture()
    measurement = function(fs)
        if fs.text and fs.text:find("reported positions", 1, true) then return 72 end
        if fs.text == addon.L("REPORTED_VISIT") then return 54 end
        if fs.text and fs.text:find("(10.0, 20.0)", 1, true) then return 70 end
        return 18
    end
    showSources(9920); reportToggle("start").scripts.OnClick()
    local first, second = reportRows()[1], reportRows()[2]
    assert(reportToggle("start").height >= 7 + 72 + 7)
    assert(first.height >= 7 + 70 + 4 + 54 + 7 and first.point[3] - second.point[3] >= first.height + 4)
    reportToggle("start").scripts.OnClick()
    assert(not first.shown and first.scripts.OnClick == nil)
    reportToggle("finish").scripts.OnClick()
    assert(reportRows()[1] == first and first.destination.objectID == 202 and first.destination.x == 30)
    assert(not first.destination.npcID and first.locationKey == "finish")
    measurement = nil; endReports()
end)
check("Reported position rendering is bounded and invalid or restricted reports never create visits", function()
    local start = reportedFixture()
    start.reportedLocations = {}; for i = 1, 100 do start.reportedLocations[i] = { mapID = 1, x = i - 1, y = 20 } end
    showSources(9920); reportToggle("start").scripts.OnClick(); assert(#reportRows() == 100)
    start.reportedLocations[101] = { mapID = 1, x = 100, y = 20 }
    ui:RefreshDetail(); assert(not reportToggle("start") and #reportRows() == 0)
    local restricted = {}; issecretvalue = function(v) return v == restricted end
    for _, bad in ipairs({ restricted, {}, { { mapID = 1, x = 10, y = 20 } },
        { { mapID = 1, x = 10, y = 20 }, { mapID = 0, x = 11, y = 21 } },
        { { mapID = 1, x = 10, y = 20 }, { mapID = 1, x = restricted, y = 21 } },
        { { mapID = 1, x = 10, y = 20 }, { mapID = 1, x = 11, y = 101 } } }) do
        start.reportedLocations = bad; ui:RefreshDetail()
        assert(not reportToggle("start") and #reportRows() == 0)
    end
    issecretvalue = nil; endReports()
end)
check("A report on another map does not borrow the primary zone label when native map names are unavailable", function()
    local start = reportedFixture(); local maps = C_Map
    C_Map = nil; start.reportedLocations[2].mapID = 3
    showSources(9920); reportToggle("start").scripts.OnClick()
    assert(reportRows()[1].title.text == "Start zone (10.0, 20.0)")
    assert(reportRows()[2].title.text == addon.L("UNKNOWN_PLACE") .. " (11.0, 21.0)")
    C_Map = maps; endReports()
end)
check("Reported-position copy is explicitly translated for all ten locales", function()
    local count = 0
    for locale, strings in pairs(addon.locales) do
        for _, key in ipairs({ "REPORTED_POSITIONS", "REPORTED_NOTICE", "REPORTED_VISIT" }) do
            assert(type(strings[key]) == "string" and strings[key] ~= "", locale .. " missing " .. key)
        end
        local label = string.format(strings.REPORTED_POSITIONS, "Entity", 2)
        assert(label:find("Entity", 1, true) and label:find("2", 1, true)); count = count + 1
    end
    assert(count == 10)
end)
check("Item containers stay separate from quest starters and navigate only explicit current locations", function()
    local nav = addon.Navigation
    local visits, maps = {}, {}
    addon.Navigation = { Start = function(action) visits[#visits + 1] = action end,
        Map = function(destination) maps[#maps + 1] = destination end }
    local container = { objectID = 19861, name = "Journal container", zoneName = "Thousand Needles",
        mapID = 1441, x = 30.7, y = 24.4,
        reportedLocations = { { mapID = 1441, x = 30.7, y = 24.4 }, { mapID = 1441, x = 30.7, y = 24.5 } } }
    addon.quests[9930] = { id = 9930, minLevel = 1, requirementsKnown = false,
        start = { itemID = 5791, name = "Journal starter", containerSource = container },
        requires = { { ids = { 9931 } } } }
    addon.quests[9931] = { id = 9931, minLevel = 1, requirementsKnown = true,
        start = { npcID = 111, name = "Prerequisite giver", mapID = 1, x = 10, y = 20 } }
    local context = { level = 40, completed = function() return false end, active = function() return false end }
    measurement = function(fs) return fs.text == "Journal container" and 72 or 18 end
    showSources(9930, context)
    local row = ui.containerButtons[1]
    assert(detailHas(addon.L("CONTAINER_SOURCE")) and row.shown and row.enabled and row.height == 108)
    assert(ui.engine:State(9930).status == "UNKNOWN" and not ui.giverAction)
    assert(ui.action.id == 9931 and ui.action.kind == "pickup" and ui.action.place == addon.quests[9931].start)
    local _, uncertain = ui.engine:Next(9930); assert(uncertain)
    assert(addon.quests[9930].start.itemID == 5791 and not addon.quests[9930].start.objectID)
    assert(#visits == 0 and #maps == 0)
    row.scripts.OnClick()
    assert(#visits == 1 and visits[1].kind == "visit" and visits[1].id == 9930 and visits[1].place == container)
    local staleContainer = row.scripts.OnClick
    reportToggle("container:1").scripts.OnClick()
    staleContainer(); assert(#visits == 1)
    local reported = reportRows()
    assert(#reported == 2 and reported[2].destination.objectID == 19861 and not reported[2].destination.itemID)
    local staleReport = reported[2].scripts.OnClick
    reported[2].scripts.OnClick()
    assert(#visits == 2 and visits[2].place.y == 24.5 and visits[2].place.mapID == 1441)
    addon.quests[9930].requirementsKnown = true
    showSources(9930, context)
    assert(ui.action.id == 9931 and ui.action.place == addon.quests[9931].start and not ui.giverAction)
    local action = ui.action
    ui.containerButtons[1].scripts.OnClick()
    assert(ui.action == action and ui.action.id == 9931)
    container.x, container.y, container.reportedLocations = nil, nil, nil
    showSources(9930, context)
    staleReport(); assert(#visits == 3)
    row.scripts.OnClick()
    assert(#maps == 1 and maps[1] == container and maps[1].mapID == 1441 and not maps[1].place)
    local staleMap = row.scripts.OnClick
    container.mapID = nil
    container.name = "Container with unknown map"
    measurement = nil; showSources(9930, context)
    assert(row.shown and not row.enabled and not row.scripts.OnClick and row.height == 59)
    assert(detailHas(addon.L("CONTAINER_SOURCE")) and row.note.text == "Thousand Needles — |cffff594d" .. addon.L("SOURCE_POSITION_UNKNOWN") .. "|r")
    staleMap(); assert(#maps == 1)
    showSources(2)
    staleContainer(); staleReport(); staleMap()
    assert(#visits == 3 and #maps == 1 and not row.shown and not row.enabled and not row.scripts.OnClick)
    assert(not detailHas(addon.L("CONTAINER_SOURCE")))
    addon.quests[9930], addon.quests[9931], addon.Navigation = nil, nil, nav
end)
check("Alternative-place callbacks from an older detail generation cannot visit or open maps", function()
    local nav, calls = addon.Navigation, 0
    addon.Navigation = { Start = function() calls = calls + 1 end, Map = function() calls = calls + 1 end }
    addon.quests[9932] = { id = 9932, minLevel = 1, requirementsKnown = false,
        startAlternatives = { { npcID = 1, name = "Located", mapID = 1, x = 10, y = 20 }, { npcID = 2, name = "Unknown" } },
        finishAlternatives = { { objectID = 1, name = "Map only", mapID = 1 }, { objectID = 2, name = "Unknown" } } }
    showSources(9932)
    local startClick, finishClick = startButton(1).scripts.OnClick, ui.finishButtons[1].scripts.OnClick
    ui:RefreshDetail(); startClick(); finishClick(); assert(calls == 0)
    startButton(1).scripts.OnClick(); ui.finishButtons[1].scripts.OnClick(); assert(calls == 2)
    startClick, finishClick = startButton(1).scripts.OnClick, ui.finishButtons[1].scripts.OnClick
    showSources(2); startClick(); finishClick(); assert(calls == 2)
    addon.quests[9932], addon.Navigation = nil, nav
end)
check("Unverified inactive quests identify missing requirements in rows and details without an action", function()
    local selected, context, preparation = ui.quest, addon.Context, ui.preparation
    addon.Context = function() return { level = 20, completed = function() return false end,
        active = function() return false end } end
    ui.quest, ui.preparation = 3, false; ui:Refresh()
    local expected = "|cffb4aacd" .. addon.L("UNKNOWN_REQUIREMENTS") .. "|r"
    assert(detailHas(addon.L("REASON_requirementsUnknown")) and not detailHas(expected) and ui.engine:State(3).status == "UNKNOWN")
    assert(ui.engine:State(3).reason == "requirements" and not ui.action and hasDestination(true) and hasDestination(false))
    local found
    for _, row in ipairs(visibleRows()) do if row.title.text == "Quest 3" then found = row.note.text end end
    assert(found == expected)
    ui.preparation = true; ui:RefreshQuests(); ui:RefreshDetail()
    for _, row in ipairs(visibleRows()) do
        if row.title.text == "Quest 3" then assert(row.note.text == expected) end
        if row.title.text == "Quest 1" then assert(row.note.text:find(addon.L("pickup"), 1, true)) end
    end
    addon.Context, ui.quest, ui.preparation = context, selected, preparation; ui:Refresh()
end)
check("Requirement wording does not replace other unknown reasons or explicit storyline titles", function()
    showDetail(3, { level = 20, active = function() return false end, completed = function() return nil end })
    assert(ui.engine:State(3).reason == "character")
    assert(detailHas(addon.L("REASON_character")) and not ui.action)
    for _, reason in ipairs({ "character", "missing", "cycle", "level" }) do
        ui.quest = 3
        ui.engine = { context = {}, State = function() return { status = "UNKNOWN", reason = reason } end,
            Next = function() return {}, true end }
        ui:RefreshDetail()
        if reason~="level" then assert(detailHas(addon.L("REASON_"..reason)))end
        assert(not detailHas("|cffb4aacd" .. addon.L("UNKNOWN_REQUIREMENTS") .. "|r") and not ui.action)
    end
    local story = addon.quests[3].storyline
    addon.quests[3].storyline = { 3 }
    showDetail(3, { level = 20, active = function() return false end, completed = function() return false end })
    assert(not(ui.chainButtons and ui.chainButtons[1] and ui.chainButtons[1].shown) and not(ui.storyToggle and ui.storyToggle.shown), "the inspected quest is not repeated as a one-entry story")
    addon.quests[3].storyline = story; showDetail(2)
end)
check("Requirement label is translated in every locale and held or completed evidence keeps its status", function()
    local locale, count = addon.db.locale, 0
    for key, strings in pairs(addon.locales) do
        assert(type(strings.UNKNOWN_REQUIREMENTS) == "string" and strings.UNKNOWN_REQUIREMENTS ~= "")
        assert(strings.UNKNOWN_REQUIREMENTS ~= strings.UNKNOWN)
        addon.db.locale = key
        showDetail(3, { level = 20, active = function() return false end, completed = function() return false end })
        assert(detailHas(strings.REASON_requirementsUnknown) and not detailHas("|cffb4aacd" .. strings.UNKNOWN_REQUIREMENTS .. "|r")); count = count + 1
    end
    assert(count == 10); addon.db.locale = locale
    local context = addon.Context()
    context.completed = function() return true end
    context.active = function() return true end
    for _, ready in ipairs({ false, true }) do
        context.ready = function() return ready end
        showDetail(3, context)
        local status, color = ready and "READY" or "ACTIVE", ready and "ffe066" or "88bfff"
        assert(detailIncludes("|cff" .. color .. addon.L(status) .. " — " .. addon.L("COMPLETED_BEFORE") .. "|r"))
        assert(ui.engine:State(3).status == status and ui.action.kind == (ready and "turnin" or "complete"))
    end
    context.active = function() return false end; showDetail(3, context)
    assert(detailHas("|cff66dd99" .. addon.L("COMPLETED") .. "|r") and not ui.action)
    showDetail(2)
end)
check("Partial requirement chains show held-parent work while keeping the target unknown and unprepared", function()
    local context, dungeon, selected, preparation = addon.Context, ui.dungeon, ui.quest, ui.preparation
    local ready = false
    addon.quests[9950] = { id = 9950, minLevel = 1, requirementsKnown = false,
        requires = { { ids = { 9951 } }, { ids = { 9952 } } } }
    addon.quests[9951] = { id = 9951, minLevel = 1, requirementsKnown = false,
        finish = { npcID = 55, name = "Known turn-in", mapID = 1, x = 40, y = 50 } }
    addon.quests[9952] = { id = 9952, minLevel = 1, requirementsKnown = false,
        start = { npcID = 56, name = "Unverified pickup", mapID = 1, x = 60, y = 70 } }
    addon.Context = function() return { level = 20, faction = "Alliance",
        completed = function() return false end, active = function(id) return id == 9951 end,
        ready = function(id) return ready and id == 9951 end } end
    ui.dungeon = { key = "partial-held", name = "Partial requirements", coverage = "reviewed", quests = { 9950 } }
    for _, turnin in ipairs({ false, true }) do
        ready, ui.quest, ui.preparation = turnin, 9950, true; ui:RefreshQuests(); ui:RefreshDetail()
        local state = ui.engine:State(9950)
        local plan = ui.engine:Dungeon(ui.dungeon)
        assert(state.status == "UNKNOWN" and state.reason == "requirements")
        assert(plan.unknown and not plan.ready and planCoverage() == addon.L("PARTIAL"))
        assert(#plan.actions == 1 and plan.actions[1].id == 9951)
        assert(plan.actions[1].kind == (turnin and "turnin" or "complete"))
        assert(ui.action and ui.action.id == 9951 and ui.action.kind == plan.actions[1].kind)
        assert(not hasDestination(true) and not hasDestination(false), "missing selected giver cannot navigate to a prerequisite instead")
        assert(detailIncludes(addon.L("REASON_requirementsUnknown")))
        local heldRow, targetRow
        for _, row in ipairs(visibleRows()) do
            if row.title.text == "Quest 9951" then heldRow = row end
            if row.title.text == "Quest 9950" then targetRow = row end
            assert(row.title.text ~= "Quest 9952", "unknown leaf must not become a pickup action")
        end
        assert(heldRow and heldRow.note.text:find(addon.L(plan.actions[1].kind), 1, true))
        assert(targetRow and targetRow.note.text:find(addon.L("UNKNOWN_REQUIREMENTS"), 1, true))
        assert(ui.engine:State(9952).status == "UNKNOWN")
        local actions, uncertain = ui.engine:Next(9950)
        assert(#actions == 1 and uncertain, "safe progress cannot certify complete requirements")
    end
    addon.quests[9950].factions = { "Horde" }; ui:Refresh()
    assert(ui.engine:State(9950).status == "UNAVAILABLE" and not ui.action)
    assert(#ui.engine:Dungeon(ui.dungeon).actions == 0 and #visibleRows() == 0)
    addon.quests[9950].factions = nil
    addon.Context = function() return { level = 20, faction = "Alliance",
        completed = function(id) if id == 9950 then return nil end; return false end,
        active = function(id) return id == 9951 end } end
    ui:Refresh()
    assert(ui.engine:State(9950).reason == "character" and not ui.action)
    assert(#ui.engine:Dungeon(ui.dungeon).actions == 0)
    assert(#visibleRows() == 1 and visibleRows()[1].title.text == "Quest 9950")
    for _, id in ipairs({ 9950, 9951, 9952 }) do addon.quests[id] = nil end
    addon.Context, ui.dungeon, ui.quest, ui.preparation = context, dungeon, selected, preparation; ui:Refresh()
end)
local function cachedRewardFixture()
    addon.quests[9950] = { id = 9950, minLevel = 1, requirementsKnown = false }
    addon.quests[9951] = { id = 9951, minLevel = 1, requirementsKnown = false }
    return { level = 20, completed = function() return false end, active = function() return false end }
end
local function endCachedRewards()
    addon.quests[9950], addon.quests[9951] = nil, nil
    addon.DialogueRewards, addon.QuestRewards, addon.CachedQuestRewards = nil, nil, nil
    showDetail(2)
end
check("Cached rewards preview an unaccepted unknown quest without changing its actions", function()
    local context = cachedRewardFixture()
    local dialogue, log, cached = 0, 0, 0
    addon.DialogueRewards = function(id) assert(id == 9950); dialogue = dialogue + 1 end
    addon.QuestRewards = function(id) assert(id == 9950); log = log + 1 end
    addon.CachedQuestRewards = function(id)
        assert(id == 9950); cached = cached + 1
        return { source = "cache", items = { { name = "Cached fixed item", count = 2 } },
            choices = { { name = "Cached choice item", count = 1 } }, xp = 123, money = 500 }
    end
    local formatter = GetCoinTextureString; GetCoinTextureString = function(value) return "coin:" .. value end
    showDetail(9950, context)
    assert(not detailHas(addon.L("REWARD_PREVIEW")) and not detailHas(addon.L("REWARD_UNAVAILABLE")))
    assert(detailHas(addon.L("REWARD_ITEM", "Cached fixed item", 2)))
    assert(detailHas("Cached choice item"))
    assert(detailIncludes(addon.L("REWARD_XP",123)) and detailIncludes(addon.L("REWARD_MONEY")..": coin:500"))
    assert(dialogue == 1 and log == 1 and cached == 1)
    assert(ui.engine:State(9950).status == "UNKNOWN" and not ui.action and not hasDestination(true) and not ui.giverAction)
    assert(addon.quests[9950].requirementsKnown == false)
    GetCoinTextureString = formatter; endCachedRewards()
end)
check("Dialogue including explicit hide wins before selected log and cached reward sources", function()
    local context = cachedRewardFixture(); local logReads, cacheReads = 0, 0
    addon.CachedQuestRewards = function() cacheReads = cacheReads + 1; return { source = "cache", items = {}, choices = {}, xp = 111 } end
    addon.QuestRewards = function() logReads = logReads + 1; return { items = {}, choices = {}, xp = 222 } end
    addon.DialogueRewards = function() return { source = "dialogue", hidden = true } end
    showDetail(9950, context)
    assert(not detailHas(addon.L("REWARD_HIDDEN")) and not detailHas(addon.L("REWARD_PREVIEW")))
    assert(logReads == 0 and cacheReads == 0 and not detailHas(addon.L("REWARD_NO_ITEMS")))
    addon.DialogueRewards = function() return { source = "dialogue", items = {}, choices = {}, xp = 333 } end
    ui:RefreshDetail(); assert(detailHas(addon.L("REWARD_XP", 333)) and cacheReads == 0 and logReads == 0)
    addon.DialogueRewards = function() return nil end
    ui:RefreshDetail(); assert(detailHas(addon.L("REWARD_XP", 222)) and logReads == 1 and cacheReads == 0)
    assert(not detailHas(addon.L("REWARD_PREVIEW")))
    addon.DialogueRewards = function() error("offer unavailable") end
    addon.QuestRewards = function() logReads = logReads + 1; error("log unavailable") end
    ui:RefreshDetail(); assert(detailHas(addon.L("REWARD_XP", 111)) and cacheReads == 1)
    assert(not detailHas(addon.L("REWARD_PREVIEW")))
    endCachedRewards()
end)
check("Missing throwing invalid and restricted cache producers stay unknown instead of empty rewards", function()
    local context = cachedRewardFixture(); local restricted = {}
    addon.DialogueRewards, addon.QuestRewards = nil, nil
    issecretvalue = function(value) return value == restricted end
    for _, value in ipairs({ false, true, 0, "bad", restricted, {}, { source = "cache", items = false, choices = {} } }) do
        addon.CachedQuestRewards = function() return value end; showDetail(9950, context)
        assert(not detailHas(addon.L("REWARD_UNAVAILABLE")) and not detailHas(addon.L("REWARD_NO_ITEMS")))
    end
    addon.CachedQuestRewards = function() error("cache unavailable") end; ui:RefreshDetail()
    assert(not detailHas(addon.L("REWARD_UNAVAILABLE")))
    addon.CachedQuestRewards = nil; ui:RefreshDetail(); assert(not detailHas(addon.L("REWARD_UNAVAILABLE")))
    issecretvalue = nil; endCachedRewards()
end)
check("Cached preview refreshes the same card and clears recycled reward fields on another card", function()
    local context = cachedRewardFixture(); local name, xp, reads = "First cached item", 10, 0
    addon.CachedQuestRewards = function(id)
        reads = reads + 1
        if id == 9950 then return { source = "cache", items = { { name = name, count = 1 } }, choices = {}, xp = xp } end
    end
    showDetail(9950, context); ui.detailScroll:SetVerticalScroll(83)
    assert(detailHas(name))
    name, xp = "Updated cached item", 20; ui:RefreshDetail()
    assert(reads == 2 and ui.detailScroll.verticalScroll == 83)
    assert(detailHas(name) and detailHas(addon.L("REWARD_XP", 20)))
    assert(not detailHas("First cached item") and not detailHas(addon.L("REWARD_XP", 10)))
    showDetail(9951, context)
    assert(not detailHas(addon.L("REWARD_PREVIEW")) and not detailHas(addon.L("REWARD_UNAVAILABLE")))
    assert(not detailHas(name) and not detailHas(addon.L("REWARD_XP", 20)))
    assert(not ui.action and ui.engine:State(9951).status == "UNKNOWN")
    endCachedRewards()
end)
check("Confirmed empty cached rewards preserve real zero experience and all preview translations", function()
    local context = cachedRewardFixture()
    addon.CachedQuestRewards = function() return { source = "cache", items = {}, choices = {}, xp = 0, money = 0 } end
    showDetail(9950, context)
    assert(not detailHas(addon.L("REWARD_PREVIEW")) and not detailHas(addon.L("REWARD_NO_ITEMS")))
    assert(detailHas(addon.L("REWARD_XP", 0)) and not detailHas(addon.L("REWARD_UNAVAILABLE")))
    local count = 0
    for locale, strings in pairs(addon.locales) do
        assert(type(strings.REWARD_PREVIEW) == "string" and strings.REWARD_PREVIEW ~= "", locale)
        count = count + 1
    end
    assert(count == 10); endCachedRewards()
end)
check("Carried item counts show real zero and refresh without authorizing quest actions", function()
    local oldCount, oldNavigation = addon.CarriedItemCount, addon.Navigation
    local counts, calls, visits = { [80001] = 0, [80002] = 3 }, {}, 0
    addon.CarriedItemCount = function(id) calls[#calls + 1] = id; return counts[id] end
    addon.Navigation = { Start = function() visits = visits + 1 end, Map = function() visits = visits + 1 end }
    addon.quests[9960] = { id = 9960, minLevel = 1, requirementsKnown = false,
        start = { itemID = 80001, name = "Starter" }, completionQuests = { { id = 9961, itemID = 80002 } } }
    addon.quests[9961] = { id = 9961, minLevel = 1, requirementsKnown = false }
    showDetail(9960)
    assert(detailHas(addon.L("ITEM_CARRIED", 0)))
    assert(ui:SetDetailTab("sources"))
    local initialReads = #calls
    local row = ui.materialButtons[1]
    assert(row.shown and row.note.text:find(addon.L("ITEM_CARRIED", 3), 1, true))
    assert(ui.engine:State(9960).status == "UNKNOWN" and not ui.action and not hasDestination(true) and visits == 0)
    counts[80001], counts[80002] = 2, 0; ui:RefreshDetail()
    assert(detailHas(addon.L("ITEM_CARRIED", 2)) and not detailHas(addon.L("ITEM_CARRIED", 0)))
    assert(row.note.text:find(addon.L("ITEM_CARRIED", 0), 1, true) and not row.note.text:find(addon.L("ITEM_CARRIED", 3), 1, true))
    counts[80001], counts[80002] = nil, nil; ui:RefreshDetail()
    assert(not detailHas(addon.L("ITEM_CARRIED", 2)) and not row.note.text:find(addon.L("ITEM_CARRIED", 0), 1, true))
    assert(ui.engine:State(9960).status == "UNKNOWN" and not ui.action and visits == 0)
    assert(#calls - initialReads == 4, "each Sources refresh reads each distinct carried item once")
    counts[80001], counts[80002] = 1e20, 1e20; ui:RefreshDetail()
    assert(detailHas(addon.L("ITEM_CARRIED", 1e20)))
    assert(addon.L("ITEM_CARRIED", 1e20):find("100000000000000000000", 1, true))
    assert(row.note.text:find("100000000000000000000", 1, true))
    showDetail(9961)
    assert(not row.shown and not row.scripts.OnClick and not detailHas(addon.L("ITEM_CARRIED", 2)))
    addon.quests[9960], addon.quests[9961] = nil, nil
    addon.CarriedItemCount, addon.Navigation = oldCount, oldNavigation
end)
check("Missing or invalid carried-count data is omitted and recycled material rows lose it", function()
    local oldCount, oldSecret = addon.CarriedItemCount, issecretvalue
    addon.quests[9962] = { id = 9962, minLevel = 1, requirementsKnown = true,
        start = { itemID = 80003, name = "Starter" }, completionQuests = { { id = 9963, itemID = 80004 } } }
    addon.quests[9963] = { id = 9963, minLevel = 1, requirementsKnown = true }
    addon.CarriedItemCount = function() return 7 end; showDetail(9962)
    assert(detailHas(addon.L("ITEM_CARRIED", 7)))
    assert(ui:SetDetailTab("sources"))
    local row = ui.materialButtons[1]
    assert(detailHas(addon.L("ITEM_CARRIED", 7)) and row.note.text:find(addon.L("ITEM_CARRIED", 7), 1, true))
    local function absent()
        ui:RefreshDetail()
        assert(not detailHas(addon.L("ITEM_CARRIED", 7)) and not row.note.text:find(addon.L("ITEM_CARRIED", 7), 1, true))
        assert(ui.engine:State(9962).status == "AVAILABLE" and ui.action.id == 9962)
    end
    addon.CarriedItemCount = nil; absent()
    for _, bad in ipairs({ -1, 1.5, math.huge, "7", true }) do
        addon.CarriedItemCount = function() return bad end; absent()
    end
    addon.CarriedItemCount = function() error("Unavailable") end; absent()
    issecretvalue = function(value) return value == 7 end
    addon.CarriedItemCount = function() return 7 end; absent()
    issecretvalue = oldSecret
    addon.CarriedItemCount = function() return 7 end; ui:RefreshDetail()
    row.scripts.OnClick()
    assert(ui.quest == 9963 and not row.shown and not row.scripts.OnClick and not detailHas(addon.L("ITEM_CARRIED", 7)))
    addon.quests[9962], addon.quests[9963] = nil, nil
    addon.CarriedItemCount, issecretvalue = oldCount, oldSecret
    showDetail(2)
end)
check("Quest log capacity stays informational without a development footer", function()
    local producer, navigation = addon.QuestLogCapacity, addon.Navigation
    local count, capacity, reads, visits = 0, 20, 0, 0
    addon.QuestLogCapacity = function() reads = reads + 1; return { count = count, capacity = capacity } end
    addon.Navigation = { Start = function() visits = visits + 1 end, Map = function() visits = visits + 1 end }
    showDetail(2); ui:Refresh()
    assert(ui.capacityStatus.shown and ui.capacityStatus.text == addon.L("QUEST_LOG_CAPACITY", 0, 20))
    assert(ui.footer == nil)
    local status, action, quest = ui.engine:State(2).status, ui.action and ui.action.kind, ui.quest
    count = 23; ui:Refresh()
    assert(ui.capacityStatus.text == addon.L("QUEST_LOG_CAPACITY", 23, 20))
    assert(ui.engine:State(2).status == status and (ui.action and ui.action.kind) == action and ui.quest == quest and visits == 0)
    count = 5; ui:Refresh()
    assert(ui.capacityStatus.text == addon.L("QUEST_LOG_CAPACITY", 5, 20) and reads >= 3)
    ui.frame:Hide(); count = 8
    ui:Toggle()
    ui.frame.scripts.OnShow(ui.frame)
    assert(ui.capacityStatus.text == addon.L("QUEST_LOG_CAPACITY", 8, 20) and ui.footer == nil)
    addon.QuestLogCapacity, addon.Navigation = producer, navigation
    ui:Refresh()
end)
check("Missing invalid or restricted capacity clears the reused status instead of claiming zero", function()
    local producer, checker = addon.QuestLogCapacity, issecretvalue
    addon.QuestLogCapacity = function() return { count = 2, capacity = 20 } end; ui:Refresh()
    assert(ui.capacityStatus.shown)
    local function omitted()
        ui:Refresh()
        assert(not ui.capacityStatus.shown and ui.capacityStatus.text == "" and ui.footer == nil)
    end
    addon.QuestLogCapacity = nil; omitted()
    addon.QuestLogCapacity = function() return nil end; omitted()
    addon.QuestLogCapacity = function() error("Cold") end; omitted()
    for _, value in ipairs({ {}, { count = 0 }, { count = -1, capacity = 20 }, { count = 1.5, capacity = 20 },
        { count = 2, capacity = 0 }, { count = 2, capacity = 20.5 }, { count = math.huge, capacity = 20 },
        { count = 2, capacity = math.huge }, { count = "2", capacity = 20 }, false }) do
        addon.QuestLogCapacity = function() return value end; omitted()
    end
    issecretvalue = function(value) return value == 20 end
    addon.QuestLogCapacity = function() return { count = 2, capacity = 20 } end; omitted()
    issecretvalue = checker
    addon.QuestLogCapacity = producer; ui:Refresh()
end)
check("Capacity formats safely in all locales without restoring a footer", function()
    local producer, locale = addon.QuestLogCapacity, addon.db.locale
    addon.QuestLogCapacity = function() return { count = 1e20, capacity = 20 } end
    local dictionaries = 0
    for code, strings in pairs(addon.locales) do
        addon.db.locale = code; ui:Refresh()
        assert(ui.capacityStatus.shown and ui.capacityStatus.text == string.format(strings.QUEST_LOG_CAPACITY, 1e20, 20))
        assert(ui.capacityStatus.text:find("100000000000000000000", 1, true))
        assert(ui.footer == nil)
        dictionaries = dictionaries + 1
    end
    assert(dictionaries == 10)
    addon.QuestLogCapacity, addon.db.locale = producer, locale; ui:Refresh()
end)
local function rewardPresentationFixture()
    local f = { oldDialogue = addon.DialogueRewards, oldLog = addon.QuestRewards,
        oldCache = addon.CachedQuestRewards, oldTooltip = GameTooltip, oldSecret = issecretvalue }
    addon.quests[9970] = { id = 9970, minLevel = 1, requirementsKnown = false }
    addon.quests[9971] = { id = 9971, minLevel = 1, requirementsKnown = false }
    f.data = { source = "dialogue", items = { { id = 701, name = "Fixed reward", count = 2, texture = 123 } },
        choices = { { id = 702, name = "Choice reward", count = 1, texture = "Interface\\Icons\\Reward" } } }
    addon.DialogueRewards = function(id) assert(id == 9970 or id == 9971); return f.data end
    addon.QuestRewards, addon.CachedQuestRewards = nil, nil
    f.tip = { hides = 0, items = {}, cold = false }
    function f.tip:IsOwned(owner) return self.owner == owner end
    function f.tip:SetOwner(owner, anchor)
        assert(anchor == "ANCHOR_RIGHT"); self.owner = owner
        if f.ownerHook then f.ownerHook() end
    end
    function f.tip:SetItemByID(id, ...)
        assert(select("#", ...) == 0); self.items[#self.items + 1] = id
        if f.itemHook then f.itemHook() end
        self.shown = not self.cold
        return not self.cold
    end
    function f.tip:Hide()
        self.hides = self.hides + 1; self.shown = false
        if f.hideHook then f.hideHook() end
    end
    function f.tip:Show() error("Native item setter owns cold-data visibility") end
    GameTooltip = f.tip; showDetail(9970)
    function f:finish()
        measurement = nil
        ui:ResetRewardPresentation()
        addon.DialogueRewards, addon.QuestRewards, addon.CachedQuestRewards = self.oldDialogue, self.oldLog, self.oldCache
        GameTooltip, issecretvalue = self.oldTooltip, self.oldSecret
        addon.quests[9970], addon.quests[9971] = nil, nil
        showDetail(2)
    end
    return f
end
check("Reward icons preserve exact text, measured wrapping and fixed versus choice item IDs", function()
    local f = rewardPresentationFixture()
    measurement = function(fs) return fs.text == addon.L("REWARD_ITEM", "Fixed reward", 2) and 72 or 18 end
    ui:RefreshDetail()
    assert(detailHas(addon.L("REWARD_ITEM", "Fixed reward", 2)) and detailHas("Choice reward"))
    local first, second = ui.rewardButtons[1], ui.rewardButtons[2]
    assert(first.shown and first.icon.texture == 123 and first.width == 32 and first.height == 32)
    assert(second.shown and second.icon.texture == "Interface\\Icons\\Reward")
    assert(first.rewardBinding.kind == "items" and second.rewardBinding.kind == "choices")
    assert(first.point[3] - second.point[3] >= 72 + 8)
    first.scripts.OnEnter(); assert(f.tip.owner == first and f.tip.items[1] == 701 and f.tip.shown)
    first.scripts.OnLeave(); assert(f.tip.hides == 1 and not f.tip.shown)
    second.scripts.OnEnter(); assert(f.tip.owner == second and f.tip.items[2] == 702)
    assert(ui.engine:State(9970).status == "UNKNOWN" and not ui.action)
    f:finish()
end)
check("Reward cold data and absent tooltip capabilities preserve readable reward text", function()
    local f = rewardPresentationFixture(); local first = ui.rewardButtons[1]
    f.tip.cold = true; first.scripts.OnEnter()
    assert(not f.tip.shown and not ui.rewardTooltip and detailHas(addon.L("REWARD_ITEM", "Fixed reward", 2)))
    GameTooltip = nil; first.scripts.OnEnter(); assert(not ui.rewardTooltip)
    GameTooltip = f.tip; local setter = f.tip.SetItemByID
    f.tip.SetItemByID = nil; first.scripts.OnEnter(); assert(not ui.rewardTooltip)
    f.tip.SetItemByID = function() error("Unavailable") end
    first.scripts.OnEnter(); assert(not ui.rewardTooltip)
    f.tip.SetItemByID = setter
    local owned = f.tip.IsOwned
    f.tip.IsOwned = function() error("Restricted owner") end
    first.scripts.OnEnter(); assert(not ui.rewardTooltip)
    f.tip.IsOwned = owned
    f:finish()
end)
check("Missing zero failing or restricted icons revert recycled text to ordinary width", function()
    local f = rewardPresentationFixture(); local first = ui.rewardButtons[1]
    local decorated
    for _, fs in ipairs(ui.details) do if fs.shown and fs.text == addon.L("REWARD_ITEM", "Fixed reward", 2) then decorated = fs end end
    local content=ui.detail:GetWidth()-8;local tileWidth=content>=340 and (content-8)/2 or content
    assert(decorated.width == tileWidth-40 and decorated.point[2] == 44)
    for _, texture in ipairs({ 0, -1, "", false, {} }) do
        f.data.items[1].texture, f.data.choices[1].texture = texture, nil
        ui:RefreshDetail()
        assert(not first.shown and decorated.width == tileWidth and decorated.point[2] == 4)
        assert(detailHas(addon.L("REWARD_ITEM", "Fixed reward", 2)))
    end
    f.data.items[1].texture = nil; ui:RefreshDetail(); assert(not first.shown)
    f.data.items[1].texture = 123
    first.icon.SetTexture = function() return false end; ui:RefreshDetail(); assert(not first.shown and decorated.width == tileWidth)
    first.icon.SetTexture = function() error("Texture unavailable") end; ui:RefreshDetail(); assert(not first.shown and decorated.width == tileWidth)
    first.icon.SetTexture = false; ui:RefreshDetail(); assert(not first.shown and decorated.width == tileWidth)
    first.icon.SetTexture = methods.SetTexture
    issecretvalue = function(value) return value == 123 end; ui:RefreshDetail(); assert(not first.shown)
    issecretvalue = f.oldSecret
    f.data = nil; ui:RefreshDetail()
    assert(not first.shown and not first.scripts.OnEnter and first.icon.texture == nil)
    for _, fs in ipairs(ui.details) do if fs.shown then assert(fs.width == ui.detail:GetWidth()-8-(fs.detailStyle=="title"and 40 or fs.navigationInset or 0) and fs.point[2] == 4+(fs.navigationInset or 0)) end end
    f:finish()
end)
check("Hover freshly rejects changed source hidden dialogue kind slot and item before redraw", function()
    local f = rewardPresentationFixture(); local first = ui.rewardButtons[1]; local enter = first.scripts.OnEnter
    local data = f.data
    f.data = { source = "dialogue", hidden = true }
    addon.QuestRewards = function() return data end
    enter(); assert(#f.tip.items == 0 and f.tip.owner == nil)
    addon.QuestRewards = nil; f.data = data
    data.items[1].id = 703; enter(); assert(#f.tip.items == 0)
    data.items[1].id = 701; data.items, data.choices = data.choices, data.items
    enter(); assert(#f.tip.items == 0)
    data.items, data.choices = data.choices, data.items
    data.source = "cache"; enter(); assert(#f.tip.items == 0)
    data.source = "dialogue"
    addon.DialogueRewards = function() return data end
    enter(); assert(#f.tip.items == 0, "replacement producer invalidates captured binding")
    ui:RefreshDetail(); ui.rewardButtons[1].scripts.OnEnter(); assert(#f.tip.items == 1)
    data.hidden = true
    local hides = f.tip.hides; ui.rewardButtons[1].scripts.OnEnter()
    assert(not ui.rewardTooltip and not f.tip.shown and f.tip.hides == hides + 1)
    f:finish()
end)
check("Recycled enter leave and window hide cannot revive or dismiss newer reward tooltips", function()
    local f = rewardPresentationFixture(); local first = ui.rewardButtons[1]
    local oldEnter = first.scripts.OnEnter; oldEnter(); local oldLeave = first.scripts.OnLeave
    ui:RefreshDetail(); local current = ui.rewardButtons[1]
    current.scripts.OnEnter(); local hides, count = f.tip.hides, #f.tip.items
    oldEnter(); oldLeave()
    assert(f.tip.hides == hides and #f.tip.items == count and f.tip.shown)
    local leave = current.scripts.OnLeave
    current.scripts.OnEnter(); hides = f.tip.hides
    leave(); assert(f.tip.hides == hides and ui.rewardTooltip and f.tip.shown, "hover token differs even on same binding")
    local foreign = {}; f.tip.owner = foreign
    current.scripts.OnLeave(); assert(f.tip.hides == hides and f.tip.owner == foreign)
    current.scripts.OnEnter(); local stale = current.scripts.OnEnter
    ui.frame:Hide(); ui.frame.scripts.OnHide(ui.frame)
    hides, count = f.tip.hides, #f.tip.items
    stale(); assert(f.tip.hides == hides and #f.tip.items == count and not current.shown and not current.scripts.OnEnter)
    ui:Toggle(); ui.frame.scripts.OnShow(ui.frame)
    showDetail(9971); stale(); assert(#f.tip.items == count and ui.quest == 9971)
    f:finish()
end)
check("Reentrant tooltip owner item and cleanup operations preserve newer binding ownership", function()
    local f = rewardPresentationFixture(); local first = ui.rewardButtons[1]
    f.ownerHook = function() f.ownerHook = nil; ui:RefreshDetail() end
    first.scripts.OnEnter(); assert(#f.tip.items == 0 and not ui.rewardTooltip)
    f.itemHook = function()
        f.itemHook = nil; ui:RefreshDetail(); ui.rewardButtons[2].scripts.OnEnter()
    end
    ui.rewardButtons[1].scripts.OnEnter()
    assert(ui.rewardTooltip and ui.rewardTooltip.button == ui.rewardButtons[2] and f.tip.owner == ui.rewardButtons[2])
    f.hideHook = function()
        f.hideHook = nil; ui.rewardButtons[1].scripts.OnEnter()
    end
    ui.rewardButtons[2].scripts.OnLeave()
    assert(ui.rewardTooltip and ui.rewardTooltip.button == ui.rewardButtons[1] and f.tip.owner == ui.rewardButtons[1])
    local foreign = {}; f.itemHook = function() f.tip.owner = foreign end
    local hides = f.tip.hides
    ui.rewardButtons[2].scripts.OnEnter()
    assert(f.tip.owner == foreign and not ui.rewardTooltip and f.tip.hides == hides + 1)
    f:finish()
end)
check("Replacing tooltip object or capability during ownership setup never loads a stale item", function()
    local f = rewardPresentationFixture(); local first = ui.rewardButtons[1]
    local foreign = { Hide = function() error("foreign tooltip must remain untouched") end }
    f.ownerHook = function() f.ownerHook = nil; GameTooltip = foreign end
    first.scripts.OnEnter()
    assert(#f.tip.items == 0 and not ui.rewardTooltip and GameTooltip == foreign)
    GameTooltip = f.tip
    local setter = f.tip.SetItemByID
    f.ownerHook = function() f.ownerHook = nil; f.tip.SetItemByID = function() error("replacement must not be called") end end
    first.scripts.OnEnter()
    assert(#f.tip.items == 0 and not ui.rewardTooltip)
    f.tip.SetItemByID = setter
    local owned = f.tip.IsOwned
    f.tip.IsOwned = function() return {} end
    first.scripts.OnEnter(); assert(#f.tip.items == 0 and not ui.rewardTooltip)
    f.tip.IsOwned = owned
    f:finish()
end)
check("Texture reentry aborts the old card while nested cards keep text and rebuild icons later", function()
    for mode = 1, 3 do
        local f = rewardPresentationFixture()
        local nextData = { source = "dialogue", items = { { id = 799, name = "New reward", count = 1, texture = 456 } }, choices = {} }
        addon.DialogueRewards = function(id)
            if id == 9970 then return f.data end
            if id == 9971 then return nextData end
        end
        ui:RefreshDetail()
        local first, armed, nestedHeight = ui.rewardButtons[1], true, nil
        local original = first.icon.SetTexture
        first.icon.SetTexture = function(icon, value)
            if value and armed then
                armed = false
                if mode == 1 then showDetail(2)
                elseif mode == 2 then showDetail(9971)
                else f.data = nextData; ui:RefreshDetail() end
                nestedHeight = ui.detail.height
            end
            return original(icon, value)
        end
        ui:RefreshDetail()
        assert(not armed and ui.quest == (mode == 1 and 2 or mode == 2 and 9971 or 9970))
        assert(not ui.rewardTextureBusy and ui.detail.height == nestedHeight)
        assert(not detailHas(addon.L("REWARD_ITEM", "Fixed reward", 2)))
        for _, row in ipairs(ui.rewardButtons) do
            assert(not row.shown and not row.rewardBinding and not row.scripts.OnEnter, "outer renderer revived an old reward")
        end
        if mode > 1 then assert(detailHas("New reward")) end
        first.icon.SetTexture = original; ui:RefreshDetail()
        if mode > 1 then
            assert(ui.rewardButtons[1].shown and ui.rewardButtons[1].rewardBinding.id == 799)
        else assert(not ui.rewardButtons[1].shown) end
        f:finish()
    end
end)
check("A throwing icon setter releases its busy guard before the next ordinary redraw", function()
    local f = rewardPresentationFixture(); local first = ui.rewardButtons[1]
    local original = first.icon.SetTexture
    first.icon.SetTexture = function(_, value) if value then error("Native texture rejected") end; return true end
    ui:RefreshDetail()
    assert(not ui.rewardTextureBusy and not first.shown and detailHas(addon.L("REWARD_ITEM", "Fixed reward", 2)))
    first.icon.SetTexture = original; ui:RefreshDetail()
    assert(not ui.rewardTextureBusy and first.shown and first.rewardBinding.id == 701)
    f:finish()
end)
check("All-character inspection explains class and minimum level without racial restrictions", function()
    local oldContext, className, raceName = addon.Context, addon.ClassName, addon.RaceName
    local dungeon, include, quest = ui.dungeon, ui.includeUnavailable, ui.quest
    addon.Context = function() return { level = 60, class = "WARRIOR", race = 1,
        completed = function() return false end, active = function() return false end } end
    addon.quests[9980] = { id = 9980, minLevel = 40, requirementsKnown = true, classes = { "MAGE" }, races = { 95 } }
    ui.dungeon = { key = "restrictions", name = "Restrictions", minLevel = 1, maxLevel = 60, coverage = "partial", quests = { 9980 } }
    addon.ClassName = function(token) assert(token == "MAGE"); return "Native mage" end
    addon.RaceName = function(id) assert(id == 95); return "Native new race" end
    ui.includeUnavailable, ui.quest = true, 9980; ui:Refresh()
    assert(ui.engine:State(9980).status == "UNAVAILABLE" and not ui.action and not hasDestination(true))
    assert(detailIncludes(addon.L("DETAIL_MIN_LEVEL",40))and detailIncludes("Native mage"))
    assert(not(ui.referenceToggle and ui.referenceToggle.shown),"class and level facts do not create an empty acquisition disclosure")
    assert(detailIncludes(addon.L("DETAIL_MIN_LEVEL",40)))
    assert(detailIncludes("Native mage") and not detailIncludes(addon.L("QUEST_RACES", "Native new race")))
    local found = false
    for _, row in ipairs(visibleRows()) do if row.title.text == "Quest 9980" then found = true end end
    assert(found)
    addon.ClassName, addon.RaceName = nil, nil; ui:RefreshDetail()
    assert(detailIncludes("MAGE") and not detailIncludes(addon.L("QUEST_RACES", addon.L("RACE_ID", 95))))
    assert(not detailIncludes(addon.L("QUEST_RACES", "Native new race")) and ui.engine:State(9980).status == "UNAVAILABLE" and not ui.action)
    addon.Context, addon.ClassName, addon.RaceName = oldContext, className, raceName
    addon.quests[9980] = nil; ui.dungeon, ui.includeUnavailable, ui.quest = dungeon, include, quest; ui:Refresh()
end)
check("Restriction display cleans deduplicates and bounds entries without guessing unknown names", function()
    local className, raceName, checker = addon.ClassName, addon.RaceName, issecretvalue
    local restricted = {}
    issecretvalue = function(value) return value == restricted end
    local classReads, raceReads = 0, 0
    addon.quests[9981] = { id = 9981, minLevel = 35, requirementsKnown = false,
        classes = { "MAGE", "MAGE", "", "   ", false, restricted }, races = { 95, 95, 1, 0, -1, 1.5, "95", restricted } }
    addon.ClassName = function() classReads = classReads + 1; return restricted end
    addon.RaceName = function(id) raceReads = raceReads + 1; if id == 1 then error("Cold") end; return "   " end
    local context = { level = 60, active = function() return true end, completed = function() return false end }
    showDetail(9981, context)
    classReads, raceReads = 0, 0; ui:RefreshDetail()
    assert(classReads == 1 and raceReads == 0)
    assert(detailIncludes("MAGE"))
    assert(not detailIncludes(addon.L("QUEST_RACES", addon.L("RACE_ID", 95) .. ", " .. addon.L("RACE_ID", 1))))
    assert(ui.engine:State(9981).status == "ACTIVE")
    local many = {}; for i = 1, 101 do many[i] = i end
    addon.quests[9981].races = many; raceReads = 0; addon.RaceName = function() raceReads = raceReads + 1; return nil end
    ui:RefreshDetail(); assert(raceReads == 0)
    for _, minimum in ipairs({ 0, -1, 1.5, "35", math.huge, restricted }) do
        addon.quests[9981].minLevel = minimum; ui:RefreshDetail()
        assert(not detailIncludes(addon.L("DETAIL_MIN_LEVEL", 35)))
    end
    addon.quests[9981].classes, addon.quests[9981].races = nil, nil; ui:RefreshDetail()
    for _, fs in ipairs(ui.details) do
        if fs.shown then assert(not fs.text:find(addon.L("RACE_ID", 95), 1, true)) end
    end
    addon.quests[9981] = nil
    addon.ClassName, addon.RaceName, issecretvalue = className, raceName, checker; showDetail(2)
end)
check("Restriction labels refresh all locales and recycled cards omit absent limits", function()
    local className, raceName, locale = addon.ClassName, addon.RaceName, addon.db.locale
    addon.quests[9982] = { id = 9982, minLevel = 50, requirementsKnown = false, classes = { "MAGE" }, races = { 95 } }
    addon.ClassName = function() return "Client class" end
    addon.RaceName = function() return nil end
    local dictionaries = 0
    for code in pairs(addon.locales) do
        addon.db.locale = code; showDetail(9982)
        assert(detailIncludes(addon.L("DETAIL_MIN_LEVEL", 50)))
        assert(detailIncludes("Client class"))
        assert(not detailIncludes(addon.L("QUEST_RACES", addon.L("RACE_ID", 95))))
        assert(ui.engine:State(9982).status == "UNKNOWN" and not ui.action)
        dictionaries = dictionaries + 1
    end
    assert(dictionaries == 10)
    addon.db.locale = locale; showDetail(2)
    assert(not detailIncludes(addon.L("DETAIL_MIN_LEVEL", 50)) and not detailIncludes("Client class"))
    assert(not detailIncludes(addon.L("QUEST_RACES", addon.L("RACE_ID", 95))))
    addon.ClassName, addon.RaceName = className, raceName; addon.quests[9982] = nil
end)
check("Restriction name reentry cannot append old labels after quest or generation changes", function()
    local className, raceName = addon.ClassName, addon.RaceName
    for _, helper in ipairs({ "ClassName" }) do
        for _, sameQuest in ipairs({ false, true }) do
            local classes, races = { "MAGE" }, { 95 }
            addon.quests[9984] = { id = 9984, minLevel = 1, requirementsKnown = false, classes = classes, races = races }
            addon.ClassName = function() return "Current class" end
            addon.RaceName = function() return "Current race" end
            local armed, nestedHeight = true, nil
            local getter = function()
                if armed then
                    armed = false
                    if sameQuest then ui:RefreshDetail() else showDetail(2) end
                    nestedHeight = ui.detail.height
                    return "Stale outer restriction"
                end
                return helper == "ClassName" and "Current class" or "Current race"
            end
            addon[helper] = getter
            showDetail(9984)
            assert(not armed and ui.quest == (sameQuest and 9984 or 2))
            assert(ui.detail.height == nestedHeight, "stale restriction loop changed the newer card geometry")
            assert(not detailIncludes("Stale outer restriction"))
            assert(not detailIncludes(addon.L("QUEST_RACES", "Stale outer restriction")))
            if sameQuest then
                assert(detailIncludes("Current class") and not detailIncludes(addon.L("QUEST_RACES", "Current race")))
            else
                assert(not detailIncludes("Current class") and not detailIncludes(addon.L("QUEST_RACES", "Current race")))
            end
            assert(addon[helper] == getter and addon.quests[9984].classes == classes and addon.quests[9984].races == races)
            assert(addon.quests[9984].requirementsKnown == false)
        end
    end
    addon.ClassName, addon.RaceName = className, raceName; addon.quests[9984] = nil; showDetail(2)
end)
check("Listed item objectives remain separate from native progress and informational carried counts", function()
    local itemName, count, objectives = addon.ItemName, addon.CarriedItemCount, addon.QuestObjectives
    addon.quests[9985] = { id = 9985, minLevel = 1, requirementsKnown = false,
        objectiveItems = { { itemID = 81001, quantity = 2, name = "Source feather" }, { itemID = 81002, quantity = 3 } } }
    addon.ItemName = function(id) if id == 81001 then return "Native feather" end end
    addon.CarriedItemCount = function(id) return id == 81001 and 0 or 8 end
    addon.QuestObjectives = function() return { { text = "Native progress remains separate", finished = false } } end
    showDetail(9985)
    assert(detailHas(addon.L("DETAIL_OBJECTIVES")) and not detailHas(addon.L("OBJECTIVE_ITEMS_NOTICE")))
    assert(detailHas(addon.L("OBJECTIVE_ITEM","Native feather",2).." · "..addon.L("ITEM_CARRIED",0)) and detailHas(addon.L("OBJECTIVE_ITEM","#81002",3).." · "..addon.L("ITEM_CARRIED",8)))
    assert(detailHas(addon.L("ITEM_CARRIED",0)) and detailHas(addon.L("ITEM_CARRIED",8)))
    assert(detailHas(addon.L("OBJECTIVE_PROGRESS")))
    assert(ui.engine:State(9985).status == "UNKNOWN" and not ui.action and not hasDestination(true))
    addon.ItemName = function() return nil end; addon.CarriedItemCount = function() return nil end; ui:RefreshDetail()
    assert(detailHas(addon.L("OBJECTIVE_ITEM", "Source feather", 2)))
    assert(not detailHas(addon.L("ITEM_CARRIED", 0)) and not detailHas(addon.L("ITEM_CARRIED", 8)))
    addon.ItemName, addon.CarriedItemCount, addon.QuestObjectives = itemName, count, objectives
    addon.quests[9985] = nil; showDetail(2)
    assert(not detailHas(addon.L("DETAIL_OBJECTIVES")) and not detailHas(addon.L("OBJECTIVE_ITEMS_NOTICE")))
end)
check("Objective entries skip malformed duplicates and restricted names with safe integer quantities", function()
    local itemName, count, checker = addon.ItemName, addon.CarriedItemCount, issecretvalue
    local restricted = {}; issecretvalue = function(value) return value == restricted end
    local reads = 0
    addon.ItemName = function() reads = reads + 1; return restricted end
    addon.CarriedItemCount = function() return -1 end
    addon.quests[9986] = { id = 9986, minLevel = 1, requirementsKnown = false, objectiveItems = {
        false, restricted, { itemID = 1, quantity = 0 }, { itemID = 2, quantity = 1.5 }, { itemID = "3", quantity = 2 },
        { itemID = 4, quantity = math.huge }, { itemID = 5, quantity = 9007199254740992 }, { itemID = 6, quantity = restricted },
        { itemID = 81003, quantity = 2, name = "Source name" }, { itemID = 81003, quantity = 7, name = "Duplicate" },
        { itemID = 9007199254740991, quantity = 9007199254740991, name = "   " },
    } }
    showDetail(9986)
    assert(reads == 2 and detailHas(addon.L("OBJECTIVE_ITEM", "Source name", 2)))
    assert(not detailHas(addon.L("OBJECTIVE_ITEM", "Duplicate", 7)))
    assert(detailHas(addon.L("OBJECTIVE_ITEM", "#9007199254740991", 9007199254740991)))
    local entries = {}; for i = 1, 101 do entries[i] = { itemID = i + 82000, quantity = 1 } end
    addon.quests[9986].objectiveItems = entries; reads = 0; ui:RefreshDetail(); assert(reads == 100)
    addon.quests[9986].objectiveItems = { false, { itemID = 0, quantity = 2 } }; ui:RefreshDetail()
    assert(not detailHas(addon.L("DETAIL_OBJECTIVES")) and not detailHas(addon.L("OBJECTIVE_ITEMS_NOTICE")))
    addon.quests[9986].objectiveItems = {}; ui:RefreshDetail(); assert(not detailHas(addon.L("DETAIL_OBJECTIVES")))
    addon.ItemName, addon.CarriedItemCount, issecretvalue = itemName, count, checker
    addon.quests[9986] = nil; showDetail(2)
end)
check("Objective headings translate while client names hydrate and recycled text clears", function()
    local itemName, count, locale = addon.ItemName, addon.CarriedItemCount, addon.db.locale
    addon.quests[9987] = { id = 9987, minLevel = 1, requirementsKnown = false,
        objectiveItems = { { itemID = 81004, quantity = 2, name = "Fact name" } } }
    addon.ItemName = function() error("Cold") end; addon.CarriedItemCount = nil; showDetail(9987)
    assert(detailHas(addon.L("OBJECTIVE_ITEM", "Fact name", 2)))
    addon.ItemName = function() return "Client feather" end
    local dictionaries = 0
    for code in pairs(addon.locales) do
        addon.db.locale = code; showDetail(9987)
        assert(detailHas(addon.L("DETAIL_OBJECTIVES")) and not detailHas(addon.L("OBJECTIVE_ITEMS_NOTICE")))
        assert(detailHas(addon.L("OBJECTIVE_ITEM", "Client feather", 2)))
        assert(ui.engine:State(9987).status == "UNKNOWN" and not ui.action)
        dictionaries = dictionaries + 1
    end
    assert(dictionaries == 10)
    addon.db.locale = locale; addon.quests[9987].objectiveItems = nil; ui:RefreshDetail()
    assert(not detailHas(addon.L("DETAIL_OBJECTIVES")) and not detailHas(addon.L("OBJECTIVE_ITEM", "Client feather", 2)))
    addon.ItemName, addon.CarriedItemCount = itemName, count; addon.quests[9987] = nil; showDetail(2)
end)
check("Optional objective name and count reads cannot append stale outer rows after reentry", function()
    local itemName, count = addon.ItemName, addon.CarriedItemCount
    for _, helper in ipairs({ "ItemName", "CarriedItemCount" }) do
        for _, sameQuest in ipairs({ false, true }) do
            local entries = { { itemID = 81005, quantity = 2, name = "Fact name" } }
            addon.quests[9988] = { id = 9988, minLevel = 1, requirementsKnown = false, objectiveItems = entries }
            addon.ItemName = function() return "Current item" end
            addon.CarriedItemCount = function() return 1 end
            local armed, nestedHeight = true, nil
            local getter = function()
                if armed then
                    armed = false
                    if sameQuest then ui:RefreshDetail() else showDetail(2) end
                    nestedHeight = ui.detail.height
                    return helper == "ItemName" and "Stale item" or 9
                end
                return helper == "ItemName" and "Current item" or 1
            end
            addon[helper] = getter; showDetail(9988)
            assert(not armed and ui.quest == (sameQuest and 9988 or 2) and ui.detail.height == nestedHeight)
            assert(not detailHas(addon.L("OBJECTIVE_ITEM", "Stale item", 2)) and not detailHas(addon.L("ITEM_CARRIED", 9)))
            assert(detailHas(addon.L("DETAIL_OBJECTIVES")) == sameQuest)
            if sameQuest then assert(detailHas(addon.L("OBJECTIVE_ITEM", "Current item", 2)) and detailHas(addon.L("ITEM_CARRIED", 1))) end
            assert(addon[helper] == getter and addon.quests[9988].objectiveItems == entries and addon.quests[9988].requirementsKnown == false)
        end
    end
    addon.ItemName, addon.CarriedItemCount = itemName, count; addon.quests[9988] = nil; showDetail(2)
end)
check("All three native-template scrollbars hide short and exact-fit content and show overflow", function()
    for _, child in ipairs({ ui.catalog, ui.questList, ui.detail }) do
        local scroll = child.parent
        assert(scroll and scroll.kind == "ScrollFrame" and scroll.scrollChild == child)
        local oldHeight, viewport = child:GetHeight(), scroll:GetHeight()
        child:SetHeight(viewport - 1)
        assert(not scroll.ScrollBar.shown and scroll.ScrollBar.maximum == 0)
        child:SetHeight(viewport)
        assert(not scroll.ScrollBar.shown and scroll.ScrollBar.maximum == 0)
        child:SetHeight(viewport + 1)
        assert(scroll.ScrollBar.shown and scroll.ScrollBar.maximum == 1)
        child:SetHeight(viewport + 0.5)
        assert(not scroll.ScrollBar.shown, "native template floors subpixel ranges")
        assert(scroll.scripts.OnScrollRangeChanged == scroll.templateRangeHandler)
        assert(scroll.scripts.OnVerticalScroll == scroll.templateVerticalHandler and scroll.scripts.OnMouseWheel == scroll.templateWheelHandler)
        assert(not scroll.scripts.OnUpdate, "scroll visibility must not require polling")
        child:SetHeight(oldHeight)
    end
end)
check("Native range changes update scrollbar visibility after viewport resize and content shrink", function()
    for _, child in ipairs({ ui.catalog, ui.questList, ui.detail }) do
        local scroll = child.parent
        local oldChild, oldView = child:GetHeight(), scroll:GetHeight()
        local events = scroll.templateRangeEvents
        child:SetHeight(600); scroll:SetSize(scroll:GetWidth(), 300)
        assert(scroll.ScrollBar.shown and scroll.ScrollBar.maximum == 300)
        scroll:SetSize(scroll:GetWidth(), 600)
        assert(not scroll.ScrollBar.shown and scroll.ScrollBar.maximum == 0)
        scroll:SetHeight(200)
        assert(scroll.ScrollBar.shown and scroll.ScrollBar.maximum == 400)
        child:SetHeight(100)
        assert(not scroll.ScrollBar.shown and scroll.ScrollBar.maximum == 0 and scroll.templateRangeEvents > events)
        scroll:SetHeight(oldView); child:SetHeight(oldChild)
    end
end)
check("Dungeon search and a shortened quest detail refresh inherited scrollbar state", function()
    local dungeons, search, range, description, quest = addon.dungeons, ui.search, ui.range, addon.Description, ui.quest
    local catalogScroll = ui.catalog.parent
    addon.dungeons = {}
    for index = 1, 30 do addon.dungeons[index] = { key = "scroll" .. index, name = "Scroll dungeon " .. index,
        minLevel = 1, maxLevel = 60, quests = {} } end
    ui.search, ui.range = "", false; ui:RefreshDungeons()
    assert(catalogScroll.ScrollBar.shown)
    ui.searchBox:SetText("Scroll dungeon 30"); ui.searchBox.scripts.OnTextChanged(ui.searchBox)
    assert(ui.cards[1].shown and ui.cards[1].title.text == "Scroll dungeon 30" and not ui.cards[2].shown)
    assert(not catalogScroll.ScrollBar.shown and ui.catalog:GetHeight() <= catalogScroll:GetHeight())
    ui.clearSearch.scripts.OnClick(); assert(catalogScroll.ScrollBar.shown)
    local definition = addon.quests[2]
    addon.quests[2] = { id = 2, minLevel = 1, requirementsKnown = true }
    local long = "Long description for overflow"
    addon.Description = function() return long end
    measurement = function(fs) return fs.text == long and 700 or 18 end
    showStory(2); assert(ui.detailScroll.ScrollBar.shown)
    addon.Description = function() return "Short description" end
    ui:RefreshDetail()
    assert(ui.detail:GetHeight() <= ui.detailScroll:GetHeight() and not ui.detailScroll.ScrollBar.shown)
    addon.quests[2] = definition
    addon.dungeons, ui.search, ui.range, addon.Description, ui.quest = dungeons, search, range, description, quest
    measurement = nil; ui.searchBox:SetText(search); ui:Refresh()
end)
do
    local function longDungeonLists()
        local old = { dungeons = addon.dungeons, quests = addon.quests, dungeon = ui.dungeon, quest = ui.quest,
            search = ui.search, range = ui.range, preparation = ui.preparation, locale = addon.db.locale,
            history = ui.detailHistory, selected = addon.char.selectedDungeon }
        local first = { key = "list-first", name = "First long dungeon", minLevel = 1, maxLevel = 60, quests = {} }
        local second = { key = "list-second", name = "Second long dungeon", minLevel = 1, maxLevel = 60, quests = {} }
        addon.quests, addon.dungeons = {}, { first, second }
        for index = 1, 40 do
            for wing, dungeon in ipairs(addon.dungeons) do
                local id = 12000 + wing * 100 + index
                dungeon.quests[index] = id
                addon.quests[id] = { id = id, minLevel = 1, requirementsKnown = true }
            end
        end
        ui.dungeon, ui.quest, ui.search, ui.range, ui.preparation, ui.detailHistory = first, nil, "", false, false, {}
        ui:Refresh()
        local function restore()
            addon.dungeons, addon.quests, addon.db.locale = old.dungeons, old.quests, old.locale
            ui.dungeon, ui.quest, ui.search, ui.range, ui.preparation, ui.detailHistory =
                old.dungeon, old.quest, old.search, old.range, old.preparation, old.history
            addon.char.selectedDungeon = old.selected
            ui:Refresh()
        end
        return first, second, ui.questList.parent, restore
    end
    check("Changing between long dungeon lists starts the new list at the top", function()
        local first, second, scroll, restore = longDungeonLists()
        assert(ui.questList:GetHeight() > scroll:GetHeight() + 500)
        scroll:SetVerticalScroll(500)
        ui:InspectQuest(first.quests[1]); ui:InspectQuest(first.quests[2])
        assert(#ui.detailHistory == 1)
        ui.cards[2].scripts.OnClick()
        assert(ui.dungeon == second and ui.quest == nil and #ui.detailHistory == 0)
        assert(ui.rows[1].title.text == addon.QuestName(second.quests[1]))
        assert(scroll.verticalScroll == 0, "new dungeon must not inherit the previous list offset")
        scroll:SetVerticalScroll(300); ui.dungeon = nil; ui:RefreshQuests()
        assert(scroll.verticalScroll == 0)
        ui.dungeon = first; ui:RefreshQuests(); assert(scroll.verticalScroll == 0)
        restore()
    end)
    check("Same dungeon refresh search locale inspection and reselect preserve quest-list reading position", function()
        local first, _, scroll, restore = longDungeonLists()
        scroll:SetVerticalScroll(350)
        local writes = scroll.scrollWrites
        ui:Refresh(); ui.search = "No matching dungeon"; ui:RefreshDungeons()
        assert(ui.dungeon == first and not ui.cards[1].shown)
        addon.db.locale = "ruRU"; ui:Refresh()
        ui:InspectQuest(first.quests[1]); ui:InspectQuest(first.quests[2]); assert(ui:BackQuest())
        assert(scroll.verticalScroll == 350 and scroll.scrollWrites == writes)
        ui.search = ""; ui:RefreshDungeons(); ui.cards[1].scripts.OnClick()
        assert(ui.dungeon == first and ui.quest == nil and scroll.verticalScroll == 350 and scroll.scrollWrites == writes)
        restore()
    end)
end
check("Source copy field clears its URL and focus on inspection Back and dungeon clearing", function()
    local quest, dungeon, history = ui.quest, ui.dungeon, ui.detailHistory
    ui.detailHistory = {}; showDetail(1)
    ui.source.scripts.OnClick()
    assert(ui.copy.shown and ui.copy.focused and ui.copy.highlighted and ui.copy.text == "https://www.wowhead.com/forever/quest=1")
    ui:InspectQuest(2)
    assert(not ui.copy.shown and not ui.copy.focused and ui.copy.text == "", "old source URL must not accompany the next quest")
    ui.source.scripts.OnClick(); assert(ui.copy.text == "https://www.wowhead.com/forever/quest=2")
    assert(ui:BackQuest() and ui.quest == 1)
    assert(not ui.copy.shown and not ui.copy.focused and ui.copy.text == "")
    ui.source.scripts.OnClick(); ui.quest = nil; ui:RefreshDetail()
    assert(not ui.copy.shown and not ui.copy.focused and ui.copy.text == "")
    showDetail(1); ui.source.scripts.OnClick(); ui.cards[1].scripts.OnClick()
    assert(ui.quest == nil and not ui.copy.shown and not ui.copy.focused and ui.copy.text == "")
    ui.quest, ui.dungeon, ui.detailHistory = quest, dungeon, history; ui:Refresh()
end)
check("Same-card source copying survives refresh but closing the window clears the cached link", function()
    local quest, history, locale = ui.quest, ui.detailHistory, addon.db.locale
    ui.detailHistory = {}; showDetail(1); ui.source.scripts.OnClick()
    local box, url = ui.copy, ui.copy.text
    ui:RefreshDetail(); ui:Refresh(); ui:InspectQuest(1); ui.language.scripts.OnClick()
    assert(box.shown and box.focused and box.text == url and #ui.detailHistory == 0)
    ui.frame:Hide(); ui.frame.scripts.OnHide(ui.frame); ui.quest = 2; ui:Refresh()
    assert(box.text == "" and not box.shown and not box.focused, "closing the window clears copy state before reopening")
    ui.frame:Show(); ui.frame.scripts.OnShow(ui.frame)
    assert(ui.quest == 2 and #ui.detailHistory == 0 and not box.shown and not box.focused and box.text == "")
    addon.db.locale, ui.quest, ui.detailHistory = locale, quest, history; ui:Refresh()
end)
check("Unknown objective quantity remains explicit through known and unknown redraws in ten locales", function()
    local itemName, count, locale = addon.ItemName, addon.CarriedItemCount, addon.db.locale
    local entry = { itemID = 83001, name = "Source relic" }
    addon.quests[9991] = { id = 9991, minLevel = 1, requirementsKnown = false, objectiveItems = { entry } }
    addon.ItemName = function() return "Native relic" end; addon.CarriedItemCount = function() return 0 end
    showDetail(9991)
    assert(detailHas(unknownObjective( "Native relic")) and detailHas(addon.L("ITEM_CARRIED", 0)))
    assert(ui.engine:State(9991).status == "UNKNOWN" and not ui.action and not hasDestination(true))
    entry.quantity = 2; ui:RefreshDetail()
    assert(detailHas(addon.L("OBJECTIVE_ITEM", "Native relic", 2)) and not detailHas(unknownObjective( "Native relic")))
    entry.quantity = nil; addon.ItemName = nil; addon.CarriedItemCount = nil
    local dictionaries = 0
    for code, strings in pairs(addon.locales) do
        assert(type(strings.OBJECTIVE_ITEM_UNKNOWN) == "string" and strings.OBJECTIVE_ITEM_UNKNOWN:find("%%s"))
        addon.db.locale = code; ui:RefreshDetail(); dictionaries = dictionaries + 1
        assert(detailHas(unknownObjective( "Source relic")) and not detailHas(addon.L("ITEM_CARRIED", 0)))
        assert(not detailHas(addon.L("OBJECTIVE_ITEM", "Native relic", 2)) and ui.engine:State(9991).status == "UNKNOWN" and not ui.action)
    end
    assert(dictionaries == 10)
    addon.ItemName, addon.CarriedItemCount, addon.db.locale = itemName, count, locale
    addon.quests[9991] = nil; showDetail(2); assert(not detailHas(addon.L("DETAIL_OBJECTIVES")))
end)
check("Present malformed or restricted objective quantity never becomes unknown", function()
    local checker, itemName = issecretvalue, addon.ItemName
    local restricted, reads = {}, 0
    issecretvalue = function(value) return value == restricted end
    addon.ItemName = function() reads = reads + 1; return "Should not read" end
    addon.quests[9992] = { id = 9992, minLevel = 1, requirementsKnown = false, objectiveItems = {} }
    for _, value in ipairs({ false, 0, -1, 1.5, "2", {}, restricted, math.huge, 9007199254740992 }) do
        addon.quests[9992].objectiveItems = { { itemID = 83002, quantity = value } }; showDetail(9992)
        assert(not detailHas(addon.L("DETAIL_OBJECTIVES")) and reads == 0)
    end
    addon.ItemName, issecretvalue = itemName, checker; addon.quests[9992] = nil; showDetail(2)
end)
check("Unknown objective quantity retains stale-render protection for both optional producers", function()
    local itemName, count = addon.ItemName, addon.CarriedItemCount
    for _, helper in ipairs({ "ItemName", "CarriedItemCount" }) do
        for _, sameQuest in ipairs({ false, true }) do
            local entries = { { itemID = 83003, name = "Source relic" } }
            addon.quests[9993] = { id = 9993, minLevel = 1, requirementsKnown = false, objectiveItems = entries }
            addon.ItemName = function() return "Fresh relic" end; addon.CarriedItemCount = function() return 0 end
            local armed, nestedHeight = true, nil
            addon[helper] = function()
                if armed then
                    armed = false
                    if sameQuest then ui:RefreshDetail() else showDetail(2) end
                    nestedHeight = ui.detail.height
                    return helper == "ItemName" and "Stale relic" or 9
                end
                return helper == "ItemName" and "Fresh relic" or 0
            end
            showDetail(9993)
            assert(not armed and ui.quest == (sameQuest and 9993 or 2) and ui.detail.height == nestedHeight)
            assert(not detailHas(unknownObjective( "Stale relic")) and not detailHas(addon.L("ITEM_CARRIED", 9)))
            assert(detailHas(addon.L("DETAIL_OBJECTIVES")) == sameQuest)
            if sameQuest then assert(detailHas(unknownObjective( "Fresh relic")) and detailHas(addon.L("ITEM_CARRIED", 0))) end
            assert(entries[1].quantity == nil and addon.quests[9993].requirementsKnown == false)
        end
    end
    addon.ItemName, addon.CarriedItemCount = itemName, count; addon.quests[9993] = nil; showDetail(2)
end)
do
    local function audienceFixture()
        local old = { quests = addon.quests, dungeons = addon.dungeons, context = addon.Context,
            dungeon = ui.dungeon, quest = ui.quest, unavailable = ui.includeUnavailable, preparation = ui.preparation,
            className = addon.ClassName, raceName = addon.RaceName, locale = addon.db.locale }
        addon.quests = {}
        for id = 13001, 13008 do addon.quests[id] = { id = id, minLevel = 1, requirementsKnown = true } end
        addon.quests[13001].factions = { "Alliance" }
        addon.quests[13002].classes = { "PALADIN" }
        addon.quests[13003].factions, addon.quests[13003].classes, addon.quests[13003].races = { "Alliance" }, { "PALADIN" }, { 1, 95 }
        addon.quests[13004].requirementsKnown = false
        addon.quests[13005].factions, addon.quests[13006].classes = { "Alliance" }, { "PALADIN" }
        addon.quests[13008].classes = {}
        addon.Context = function() return { level = 60, faction = "Horde", class = "MAGE", race = 2,
            active = function(id) return id == 13005 end, completed = function(id) return id == 13006 end } end
        addon.ClassName = function(token) assert(token == "PALADIN"); return "Paladin" end
        addon.RaceName = function(id) return id == 1 and "Human" or "New race" end
        addon.dungeons = { { key = "audience", name = "Audience", minLevel = 1, maxLevel = 60, quests =
            { 13001, 13002, 13003, 13004, 13005, 13006, 13007, 13008 } } }
        ui.dungeon, ui.quest, ui.includeUnavailable, ui.preparation = addon.dungeons[1], nil, true, false
        ui:RefreshQuests()
        return function()
            addon.quests, addon.dungeons, addon.Context = old.quests, old.dungeons, old.context
            addon.ClassName, addon.RaceName, addon.db.locale = old.className, old.raceName, old.locale
            ui.dungeon, ui.quest, ui.includeUnavailable, ui.preparation = old.dungeon, old.quest, old.unavailable, old.preparation
            ui:Refresh()
        end
    end
    check("Faction and class icons accompany readable audience text in quest rows compact metadata and starter limits", function()
        local restore = audienceFixture()
        local alliance = "|A:UI-HUD-UnitFrame-Player-PVP-AllianceIcon:14:14|a "
        local paladin = "|A:classicon-paladin:14:14|a "
        assert(ui.rows[3].note.text:find(alliance .. addon.L("FACTION_Alliance"), 1, true))
        assert(ui.rows[3].note.text:find(paladin .. "Paladin", 1, true))
        local q = addon.quests[13003]
        q.start = { itemID = 123, itemClasses = { "PALADIN" } }
        local localized = LOCALIZED_CLASS_NAMES_MALE; LOCALIZED_CLASS_NAMES_MALE = { PALADIN = "Paladin" }
        for code in pairs(addon.locales) do
            addon.db.locale = code; ui:RefreshQuests()
            assert(ui.rows[3].note.text:find(alliance .. addon.L("FACTION_Alliance"), 1, true))
            showCompactDetail(13003)
            local found = false
            for _, fs in ipairs(ui.details) do if fs.shown and fs.text:find(alliance, 1, true) then found = true end end
            local classFound=false
            for _,fs in ipairs(ui.details)do if fs.shown and fs.text:find(paladin,1,true)then classFound=true end end
            assert(classFound)
            assert(found and ui.engine:State(13003).status == "UNAVAILABLE" and not ui.action)
            assert(ui:SetDetailTab("sources")); found = false
            local expected = addon.L("ITEM_CLASSES", paladin .. "Paladin")
            for _, fs in ipairs(ui.details) do if fs.shown and fs.text == expected then found = true end end
            assert(found)
            assert(ui:SetDetailTab("quest"))
        end
        LOCALIZED_CLASS_NAMES_MALE = localized; restore()
    end)
    check("Audience icons retain factions and classes while race labels remain absent", function()
        local restore = audienceFixture()
        local q = addon.quests[13003]
        q.factions = { "Alliance", "Horde", "Neutral", "Alliance" }
        q.classes = { "PALADIN", "MAGE", "CUSTOM", "PALADIN" }
        addon.ClassName = function(token) return token end
        showCompactDetail(13003)
        local metadata = ""
        for _, fs in ipairs(ui.details) do
            if fs.shown and (fs.text:find("classicon-paladin", 1, true) or fs.text:find("PVP-AllianceIcon",1,true)) then metadata = metadata .. fs.text end
        end
        assert(metadata)
        local _, paladins = metadata:gsub("classicon%-paladin", "")
        assert(paladins == 1 and metadata:find("classicon-mage:14:14|a MAGE", 1, true))
        assert(metadata:find("PVP-HordeIcon:14:14|a " .. addon.L("FACTION_Horde"), 1, true))
        assert(metadata:find("PVP-AllianceIcon:14:14|a " .. addon.L("FACTION_Alliance"), 1, true))
        assert(metadata:find(", CUSTOM", 1, true) and not metadata:find("classicon-custom", 1, true))
        assert(metadata:find(addon.L("FACTION_Neutral"), 1, true) and not metadata:find("NeutralIcon", 1, true))
        assert(not metadata:find("Human, New race", 1, true) and not metadata:find("raceicon", 1, true))
        q.factions, q.classes = nil, { "CUSTOM" }; ui:RefreshDetail()
        for _, fs in ipairs(ui.details) do if fs.shown then assert(not fs.text:find("|A:", 1, true)) end end
        restore()
    end)
    check("Unavailable quest rows show faction and class audiences without racial exclusions", function()
        local restore = audienceFixture()
        assert(ui.rows[1].note.text:find(addon.L("FACTION_Alliance"), 1, true))
        assert(ui.rows[2].note.text:find("Paladin", 1, true) and not ui.rows[2].note.text:find(addon.L("UNAVAILABLE"), 1, true))
        assert(audienceText(ui.rows[3].note.text):find(addon.L("FACTION_Alliance") .. " · Paladin", 1, true))
        assert(not ui.rows[3].note.text:find("Human, New race", 1, true))
        assert(ui.rows[4].note.text:find(addon.L("UNKNOWN_REQUIREMENTS"), 1, true))
        assert(ui.rows[5].note.text:find(addon.L("ACTIVE"), 1, true) and not ui.rows[5].note.text:find(addon.L("FACTION_Alliance"), 1, true))
        assert(ui.rows[6].note.text:find(addon.L("COMPLETED"), 1, true) and not ui.rows[6].note.text:find("Paladin", 1, true))
        assert(ui.rows[7].note.text:find(addon.L("AVAILABLE"), 1, true))
        assert(ui.rows[8].note.text:find(addon.L("UNAVAILABLE"), 1, true), "no recorded labels keeps the honest generic fallback")
        for _, preparation in ipairs({ true, false }) do
            ui.preparation = preparation; ui:RefreshQuests()
            local found
            for _, row in ipairs(visibleRows()) do if row.title.text == "Quest 13003" then found = row end end
            assert(found and found.note.text:find("Paladin", 1, true) and ui.engine:State(13003).status == "UNAVAILABLE")
        end
        restore()
    end)
    check("Audience rows translate factions use safe native-name fallbacks and wrap in the existing row layout", function()
        local restore = audienceFixture()
        local restricted = {}; local checker = issecretvalue
        issecretvalue = function(value) return value == restricted end
        addon.ClassName = function() return restricted end; addon.RaceName = nil
        for code, strings in pairs(addon.locales) do
            addon.db.locale = code; ui:RefreshQuests()
            assert(type(strings.FACTION_Alliance) == "string" and type(strings.FACTION_Horde) == "string" and type(strings.FACTION_Neutral) == "string")
            assert(audienceText(ui.rows[3].note.text):find(addon.L("FACTION_Alliance") .. " · PALADIN", 1, true))
            assert(not ui.rows[3].note.text:find(addon.L("RACE_ID", 95), 1, true))
        end
        issecretvalue = checker
        local long = string.rep("Long localized paladin ", 12)
        addon.ClassName = function() return long end
        measurement = function(fs) return fs.text and fs.text:find(long, 1, true) and 78 or 18 end
        ui:RefreshQuests()
        assert(ui.rows[2].height == 30 and not ui.rows[2].note.shown and -ui.rows[3].point[3] >= -ui.rows[2].point[3] + ui.rows[2].height + 2)
        addon.ClassName = function() return "Paladin" end; measurement = nil; ui:RefreshQuests()
        assert(ui.rows[2].height == 30 and ui.rows[2].note.text:find("Paladin", 1, true))
        restore()
    end)
    check("Reentrant audience-name reads cannot overwrite the newly rendered dungeon list", function()
        local restore = audienceFixture()
        local other = { key = "audience-other", name = "Other", minLevel = 1, maxLevel = 60, quests = { 13007 } }
        for _, helper in ipairs({ "ClassName" }) do
            ui.dungeon = addon.dungeons[1]
            addon.ClassName = function() return "Paladin" end; addon.RaceName = function() return "Human" end
            local armed = true
            addon[helper] = function()
                if armed then armed = false; ui.dungeon = other; ui:RefreshQuests() end
                return "Stale audience"
            end
            ui:RefreshQuests()
            assert(not armed and ui.dungeon == other and ui.rows[1].shown and not ui.rows[2].shown)
            assert(ui.rows[1].title.text == "Quest 13007" and ui.rows[1].note.text:find(addon.L("AVAILABLE"), 1, true))
            assert(not ui.rows[1].note.text:find("Stale audience", 1, true))
        end
        restore()
    end)
end
check("Preparation headings retain valid highlights and real row click arguments open the quest card", function()
    local quest, dungeon, preparation, history = ui.quest, ui.dungeon, ui.preparation, ui.detailHistory
    local quests, dungeons, context = addon.quests, addon.dungeons, addon.Context
    addon.quests = {
        [15001] = { id = 15001, minLevel = 1, requirementsKnown = true, requires = { { ids = { 15002 } } } },
        [15002] = { id = 15002, minLevel = 1, requirementsKnown = true },
    }
    addon.dungeons = { { key = "click-fixture", name = "Click fixture", minLevel = 1, maxLevel = 60, quests = { 15001 } } }
    addon.Context = function() return { level = 60, active = function() return false end, completed = function() return false end } end
    ui.dungeon, ui.quest, ui.preparation, ui.detailHistory = addon.dungeons[1], nil, true, {}
    ui:RefreshDungeons(); ui:RefreshQuests(); ui:RefreshDetail()
    assert(detailHas(addon.L("OVERVIEW_PICK")) and not ui.source.enabled)
    local first, headings = nil, 0
    for _, row in ipairs(ui.rows) do
        if row.shown then
            assert(type(row.highlightTexture) == "string" and row.highlightTexture ~= "")
            if row.heading then
                headings = headings + 1
                assert(not row.enabled and not row.scripts.OnClick)
            else
                assert(row.enabled and type(row.scripts.OnClick) == "function")
                first = first or row
            end
        end
    end
    assert(headings > 0 and first and first.title.text == "Quest 15002")
    first.scripts.OnClick(first, "LeftButton", false)
    assert(ui.quest == 15002 and detailHas(addon.QuestName(15002)) and not detailHas(addon.L("PICK")) and ui.source.enabled)
    first.scripts.OnClick(first, "LeftButton", false)
    assert(ui.quest == 15002 and #ui.detailHistory == 0 and ui.source.enabled)
    ui.preparation = false; ui:RefreshQuests()
    local row = visibleRows()[1]
    assert(row.enabled and row.title.text == "Quest 15001")
    row.scripts.OnClick(row, "LeftButton", false)
    assert(ui.quest == 15001 and detailHas(addon.QuestName(15001)) and ui.source.enabled)
    ui:BackQuest()
    assert(ui.quest == 15002 and ui.source.enabled)
    addon.quests, addon.dungeons, addon.Context = quests, dungeons, context
    ui.quest, ui.dungeon, ui.preparation, ui.detailHistory = quest, dungeon, preparation, history; ui:Refresh()
end)
check("Optional theme styles the shell controls and recycled row selection without changing behavior", function()
    local previous, quest, preparation, history = addon.Theme, ui.quest, ui.preparation, ui.detailHistory
    local calls = 0
    addon.Theme = {
        Apply = function(target) assert(target == ui); calls = calls + 1; return true end,
        StyleRow = function(row, options)
            assert(row and type(options.kind) == "string" and type(options.selected) == "boolean")
            row.themeKind, row.themeSelected = options.kind, options.selected
            return true
        end,
    }
    ui.quest, ui.preparation, ui.detailHistory = nil, false, {}; ui:Refresh()
    assert(calls > 0 and ui.cards[1].themeKind == "dungeon" and ui.cards[1].themeSelected)
    for _, key in ipairs({ "rangeButton", "characterButton" }) do assert(ui[key].themeKind == "control") end
    local row = visibleRows()[1]; local note, callback, height = row.note.text, row.scripts.OnClick, row.height
    callback(row, "LeftButton", false)
    row=visibleRows()[1]
    assert(row.themeSelected and row.note.text == note and type(row.scripts.OnClick)=="function" and row.height == height)
    assert(ui.quest == 100 and ui.source.enabled)
    local second = visibleRows()[2]; local firstID,secondID=row.questID,second.questID
    second.scripts.OnClick(second, "LeftButton", false)
    local function selected(id)
        for _,entry in ipairs(visibleRows())do if entry.questID==id then return entry.themeSelected end end
    end
    assert(selected(secondID) and not selected(firstID))
    ui:BackQuest(); assert(selected(firstID) and not selected(secondID))
    ui.preparation = true; ui:RefreshQuests(); ui:RefreshDetail()
    assert(ui.preparationButton==nil)
    for _, current in ipairs(ui.rows) do if current.shown then assert(current.themeKind == (current.heading and "section" or "quest")) end end
    addon.Theme = { Apply = function() error("optional theme failed") end, StyleRow = function() error("optional theme failed") end }
    ui:Refresh(); assert(ui.quest == 100 and ui.source.enabled)
    addon.Theme, ui.quest, ui.preparation, ui.detailHistory = previous, quest, preparation, history; ui:Refresh()
end)
check("Dungeon art painting handles rejected reused icons and aborts a stale catalogue render after reentry", function()
    local paint, dungeons, search, range = addon.PaintDungeonArt, addon.dungeons, ui.search, ui.range
    addon.dungeons = {
        { key = "paint-first", name = "First painted dungeon", minLevel = 1, maxLevel = 60, quests = {} },
        { key = "paint-second", name = "Second painted dungeon", minLevel = 1, maxLevel = 60, quests = {} },
    }
    ui.search, ui.range = "", false
    addon.PaintDungeonArt = function(texture, dungeon) texture:SetTexture(dungeon.key); texture:Show(); return true end
    ui:RefreshDungeons(); assert(ui.cards[1].art.shown and ui.cards[1].art.texture == "paint-first")
    addon.PaintDungeonArt = function() return false end
    ui:RefreshDungeons(); assert(not ui.cards[1].art.shown and not ui.cards[2].art.shown)
    addon.PaintDungeonArt = function() error("unavailable") end
    ui:RefreshDungeons(); assert(not ui.cards[1].art.shown)
    local armed = true
    addon.PaintDungeonArt = function(texture, dungeon)
        if armed then
            armed = false; ui.search = "Second painted dungeon"; ui:RefreshDungeons()
            return false
        end
        texture:SetTexture(dungeon.key); texture:Show(); return true
    end
    ui:RefreshDungeons()
    assert(not armed and ui.cards[1].title.text == "Second painted dungeon" and not ui.cards[2].shown)
    assert(ui.cards[1].art.shown and ui.cards[1].art.texture == "paint-second", "stale painter result must not hide the newer icon")
    addon.PaintDungeonArt, addon.dungeons, ui.search, ui.range = paint, dungeons, search, range; ui:Refresh()
end)
check("The real optional theme paints modern surfaces and removes native control artwork without changing actions", function()
    local previous, saved = addon.Theme, {}
    for _, key in ipairs({ "SetColorTexture", "SetTextColor", "SetAlpha", "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetFontString" }) do saved[key] = methods[key] end
    methods.SetColorTexture = function(region, ...) region.themeColor = { ... } end
    methods.SetTextColor = function(region, ...) region.themeTextColor = { ... } end
    methods.SetAlpha = function(region, value) region.alpha = value end
    for _, key in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetFontString" }) do
        local field = "native" .. key
        methods[key] = function(region)
            region[field] = region[field] or object()
            return region[field]
        end
    end
    local sourceAction, guideAction, quest = ui.source.scripts.OnClick, ui.giver.scripts.OnClick, ui.quest
    for _, key in ipairs({ "clearSearch", "rangeButton", "characterButton", "language", "source", "giver" }) do
        for _, part in ipairs({ "Left", "Middle", "Right" }) do ui[key][part] = ui[key][part] or object() end
    end
    assert(loadfile("UI/Theme.lua"))("DungeonPro", addon)
    ui:Refresh()
    assert(ui.title.themeTextColor and ui.frame:GetWidth() == 1100 and ui.frame:GetHeight() == 700)
    assert(ui.cards[1].bg.themeColor and ui.rows[1].bg.themeColor)
    for _, key in ipairs({ "clearSearch", "rangeButton", "characterButton", "language", "source", "giver" }) do
        assert(ui[key]:GetNormalTexture().alpha == 0 and ui[key]:GetPushedTexture().alpha == 0 and ui[key]:GetDisabledTexture().alpha == 0)
        assert(ui[key].Left.alpha == 0 and ui[key].Middle.alpha == 0 and ui[key].Right.alpha == 0)
    end
    assert(ui.source.scripts.OnClick == sourceAction and ui.giver.scripts.OnClick == guideAction and ui.quest == quest)
    for _, key in ipairs({ "SetColorTexture", "SetTextColor", "SetAlpha", "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetFontString" }) do methods[key] = saved[key] end
    addon.Theme = previous; ui:Refresh()
end)
do
    local function overviewFixture()
        local old = { quests = addon.quests, dungeons = addon.dungeons, context = addon.Context, paint = addon.PaintDungeonArt,
            dungeon = ui.dungeon, quest = ui.quest, history = ui.detailHistory, search = ui.search, range = ui.range,
            preparation = ui.preparation, unavailable = ui.includeUnavailable, locale = addon.db.locale }
        addon.quests = { [16001] = { id = 16001, minLevel = 1, requirementsKnown = false },
            [16002] = { id = 16002, minLevel = 1, requirementsKnown = true, factions = { "Horde" } } }
        local first = { key = "overview-first", name = "First overview", minLevel = 12, maxLevel = 24, coverage = "partial", quests = { 16001, 16002 } }
        local second = { key = "overview-empty", name = "Empty overview", minLevel = 30, maxLevel = 40, coverage = "pending", quests = {} }
        addon.dungeons = { first, second }
        addon.Context = function() return { level = 20, faction = "Alliance", active = function() return false end, completed = function() return false end } end
        addon.PaintDungeonArt = function(texture, dungeon) texture:SetTexture(dungeon.key); texture:Show(); return true end
        ui.dungeon, ui.quest, ui.detailHistory, ui.search, ui.range, ui.preparation, ui.includeUnavailable = first, nil, {}, "", false, false, false
        ui:Refresh()
        return first, second, function()
            addon.quests, addon.dungeons, addon.Context, addon.PaintDungeonArt = old.quests, old.dungeons, old.context, old.paint
            ui.dungeon, ui.quest, ui.detailHistory, ui.search, ui.range, ui.preparation, ui.includeUnavailable =
                old.dungeon, old.quest, old.history, old.search, old.range, old.preparation, old.unavailable
            addon.db.locale = old.locale; ui:Refresh()
        end
    end
    check("Selected dungeon overview shows listed facts without auto-selecting or overriding character filters", function()
        local first, _, restore = overviewFixture()
        assert(ui.quest == nil and #ui.detailHistory == 0 and #visibleRows() == 1)
        assert(detailHas(first.name) and detailHas(addon.L("CATALOG_LEVELS", 12, 24)))
        assert(detailHas(addon.L("CATALOG_QUESTS", 1)) and not detailHas(addon.L("PARTIAL")) and detailHas(addon.L("OVERVIEW_PICK")))
        assert(not detailHas(addon.L("PREPARED")) and not detailHas(addon.L("PICK")))
        assert(ui.overviewArt and ui.overviewArt.kind ~= "Button" and ui.overviewArt.width <= ui.detail:GetWidth()-8 and ui.overviewArt.shown)
        assert(ui.overviewArt.texture == first.key and not ui.source.enabled and not hasDestination(true) and not hasDestination(false) and not ui.giver.enabled)
        local filters = addon.char.filters
        ui.includeUnavailable = true; ui:Refresh()
        assert(#visibleRows() == 2 and detailHas(addon.L("CATALOG_QUESTS", 2)) and addon.char.filters == filters)
        restore()
    end)
    check("Overview artwork and reading position follow dungeon and quest navigation and clear on no selection", function()
        local first, second, restore = overviewFixture()
        local art = ui.overviewArt
        ui.detailScroll:SetVerticalScroll(80); local writes = ui.detailScroll.scrollWrites
        ui:RefreshDetail(); assert(ui.detailScroll.verticalScroll == 80 and ui.detailScroll.scrollWrites == writes)
        local row = visibleRows()[1]; row.scripts.OnClick(row, "LeftButton", false)
        assert(ui.quest == 16001 and not art.shown and ui.source.enabled)
        ui:InspectQuest(16002); assert(ui:BackQuest() and ui.quest == 16001 and not art.shown)
        ui.cards[2].scripts.OnClick(ui.cards[2], "LeftButton", false)
        assert(ui.dungeon == second and ui.quest == nil and art.shown and art.texture == second.key and ui.detailScroll.verticalScroll == 0)
        assert(detailHas(addon.L("EMPTY")) and detailHas(addon.L("CATALOG_QUESTS", 0)) and not detailHas(addon.L("PREPARED")))
        ui.detailScroll:SetVerticalScroll(60); ui.dungeon = first; ui:Refresh()
        assert(ui.detailScroll.verticalScroll == 0 and art.texture == first.key and art.shown)
        ui.dungeon = nil; ui:Refresh()
        assert(detailHas(addon.L("PICK")) and not art.shown and not ui.source.enabled)
        restore()
    end)
    check("Overview omits coverage labels and rejects stale painter results after quest or dungeon reentry", function()
        local first, second, restore = overviewFixture()
        first.coverage = "reviewed"
        for code, strings in pairs(addon.locales) do
            assert(type(strings.OVERVIEW_PICK) == "string" and type(strings.OVERVIEW_REVIEWED) == "string")
            addon.db.locale = code; ui:RefreshDetail()
            assert(not detailHas(addon.L("OVERVIEW_REVIEWED")) and detailHas(addon.L("OVERVIEW_PICK")))
        end
        addon.PaintDungeonArt = function() return false end; ui:RefreshDetail(); assert(not ui.overviewArt.shown)
        for _, targetQuest in ipairs({ false, true }) do
            ui.dungeon, ui.quest = first, nil
            local armed, nestedHeight = true, nil
            addon.PaintDungeonArt = function(texture, dungeon)
                if armed then
                    armed = false
                    if targetQuest then ui:InspectQuest(16001) else ui.dungeon = second; ui:RefreshDetail() end
                    nestedHeight = ui.detail.height
                    return false
                end
                texture:SetTexture(dungeon.key); texture:Show(); return true
            end
            ui:RefreshDetail()
            assert(not armed and ui.detail.height == nestedHeight)
            if targetQuest then assert(ui.quest == 16001 and not ui.overviewArt.shown and detailHas(addon.QuestName(16001)))
            else assert(ui.dungeon == second and ui.quest == nil and detailHas(second.name) and ui.overviewArt.texture == second.key and ui.overviewArt.shown) end
            assert(not detailHas(first.name), "stale outer overview cannot overwrite the new card")
        end
        restore()
    end)
end
check("Detail typography uses explicit title section and body styles and resets pooled fonts before text", function()
    local quest, dungeon, history = ui.quest, ui.dungeon, ui.detailHistory
    local description, rewards = addon.Description, addon.QuestRewards
    addon.quests[17001] = { id = 17001, minLevel = 1, requirementsKnown = true, requires = { { ids = { 17002 } } } }
    addon.quests[17002] = { id = 17002, minLevel = 1, requirementsKnown = true }
    addon.Description = function() return addon.L("DETAIL_STORY") end
    addon.QuestRewards = function() return { items = { { id = 701, name = "Body reward", count = 1, texture = 123 } }, choices = {}, money = 0 } end
    showDetail(17001)
    local title = ui.details[1]
    assert(title.text == addon.QuestName(17001) and title.fontSize == 22 and title.fontSizeAtText == 22 and title.fontResetBeforeText)
    local reward
    for _, fs in ipairs(ui.details)do if fs.shown and fs.text=="Body reward"then reward=fs end end
    local content=ui.detail:GetWidth()-8;local tile=content>=340 and (content-8)/2 or content
    assert(reward and reward.fontSize == 15 and reward.fontResetBeforeText and reward.width == tile-40)
    local headingPath
    for _, fs in ipairs(ui.details) do if fs.shown and fs.fontSize == 13 then
        assert(fs.fontResetBeforeText); headingPath = fs.fontPath
    end end
    assert(headingPath, "Quest section captions use their explicit heading style")
    assert(ui:SetDetailTab("story"))
    local body
    for _, fs in ipairs(ui.details) do
        if fs.shown and fs.text == addon.L("DETAIL_STORY") and fs.fontSize == 14 then body = fs end
    end
    assert(body and body.fontResetBeforeText, "native prose matching a heading stays body text without a redundant caption")
    assert(title.fontPath:find("NotoSans-Regular.ttf",1,true) and headingPath==title.fontPath and body.fontPath==title.fontPath)
    local titleColor = title.textColor[1]
    title.measuredHeight = 90; measurement = function() error("cold measurement after style change") end
    ui.quest, ui.dungeon = nil, nil; ui:RefreshDetail()
    assert(ui.details[1] == title and title.text == addon.L("PICK") and title.fontSize == 15 and title.fontSizeAtText == 15 and title.fontResetBeforeText)
    assert(title.textColor[1] ~= titleColor and ui.detail.height < 90, "body recycling resets color and old title measurement")
    measurement = nil
    addon.Description, addon.QuestRewards = description, rewards
    addon.quests[17001], addon.quests[17002] = nil, nil
    ui.quest, ui.dungeon, ui.detailHistory = quest, dungeon, history; ui:Refresh()
end)
check("Large localized quest and overview titles measure wrapping without resetting same-card scroll", function()
    local questName, quest, dungeon, locale = addon.QuestName, ui.quest, ui.dungeon, addon.db.locale
    local long = "Длинное локализованное название задания для проверки переноса"
    addon.QuestName = function(id) return id == 2 and long or questName(id) end
    measurement = function(fs) return fs.text == long and fs.fontSize * 3 or 18 end
    showDetail(2)
    assert(ui.details[1].fontSize == 22 and ui.details[1].fontResetBeforeText)
    assert(-ui.details[2].point[3] >= 68)
    ui.detailScroll:SetVerticalScroll(95); local writes = ui.detailScroll.scrollWrites
    ui:RefreshDetail(); ui.language.scripts.OnClick()
    assert(ui.detailScroll.verticalScroll == 95 and ui.detailScroll.scrollWrites == writes and ui.details[1].fontSize == 22)
    ui.quest = nil; ui.dungeon = { key = "type-overview", name = "Overview title", minLevel = 1, maxLevel = 60, coverage = "partial", quests = {} }
    ui:RefreshDetail()
    assert(ui.details[1].text == "Overview title" and ui.details[1].fontSize == 22 and ui.details[1].fontResetBeforeText)
    measurement = nil; addon.QuestName, addon.db.locale = questName, locale
    ui.quest, ui.dungeon = quest, dungeon; ui:Refresh()
end)
check("Actual catalogue browsing folds localized Unicode case while preserving accents and literal CJK", function()
    local dungeons, dungeonName, search, range = addon.dungeons, addon.DungeonName, ui.search, ui.range
    local selected, quest, savedSelection, locale = ui.dungeon, ui.quest, addon.char.selectedDungeon, addon.db.locale
    local actual = {}; assert(loadfile("Database/Catalog.lua"))("DungeonPro", actual)
    addon.dungeons = actual.dungeons
    local native = { dm = "МЁРТВЫЕ КОПИ", sfk = "École des ombres", lbrs = "Straße", rfc = "怒焰裂谷[100%]" }
    addon.DungeonName = function(dungeon) return native[dungeon.key] or dungeon.name end
    ui.range = false
    local function searchFor(value, expected)
        ui.searchBox:SetText(value); ui.searchBox.scripts.OnTextChanged(ui.searchBox)
        local cards = {}; for _, card in ipairs(ui.cards) do if card.shown then cards[#cards + 1] = card end end
        if expected then assert(#cards == 1 and cards[1].title.text == expected)
        else assert(#cards == 0 and ui.catalogNotice.shown) end
        assert(ui.dungeon == selected and ui.quest == quest and addon.char.selectedDungeon == savedSelection)
    end
    searchFor("мёртвые копи", native.dm); searchFor("МёРтВыЕ КоПи", native.dm)
    searchFor("éCOLE", native.sfk); searchFor("ecole", nil); searchFor("école", nil)
    searchFor("STRASSE", native.lbrs); searchFor("straße", native.lbrs)
    searchFor("怒焰裂谷", native.rfc); searchFor("[100%]", native.rfc); searchFor(".*", nil)
    searchFor("rAgEfIrE cHaSm", native.rfc)
    for code, strings in pairs(addon.locales) do
        addon.db.locale = code; ui:RefreshDungeons()
        assert(ui.searchHint.text == strings.SEARCH_HELP and strings.SEARCH_HELP:find("A–Z", 1, true) == nil)
    end
    local bad = string.char(255) .. "A"; native.sfk = bad
    searchFor(bad, bad); searchFor(string.char(255) .. "a", nil)
    addon.dungeons, addon.DungeonName, ui.search, ui.range, addon.db.locale = dungeons, dungeonName, search, range, locale
    ui.searchBox:SetText(search); ui:Refresh()
end)
check("Back from the first quest returns to its dungeon overview and clears quest-only presentation", function()
    local quest, dungeon, history = ui.quest, ui.dungeon, ui.detailHistory
    ui.dungeon, ui.quest, ui.detailHistory = addon.dungeons[1], nil, {}; ui:Refresh()
    assert(not canGoBack() and ui.overviewArt.shown)
    local listScroll = ui.questScroll.verticalScroll
    ui:InspectQuest(1); ui.source.scripts.OnClick(ui.source, "LeftButton", false)
    assert(canGoBack() and #ui.detailHistory == 0 and not ui.overviewArt.shown and ui.copy.shown)
    ui.detailScroll:SetVerticalScroll(150)
    ui:BackQuest()
    assert(ui.quest == nil and ui.dungeon == addon.dungeons[1] and #ui.detailHistory == 0 and not canGoBack())
    assert(ui.overviewArt.shown and detailHas(addon.L("OVERVIEW_PICK")) and not ui.source.enabled and not hasDestination(true) and not hasDestination(false))
    assert(not ui.copy.shown and not ui.copy.focused and ui.copy.text == "" and ui.detailScroll.verticalScroll == 0)
    assert(ui.questScroll.verticalScroll == listScroll and not ui:BackQuest())
    ui.quest, ui.dungeon, ui.detailHistory = quest, dungeon, history; ui:Refresh()
end)
check("Back exhausts positive quest history before overview and never fabricates a standalone dungeon", function()
    local quest, dungeon, history = ui.quest, ui.dungeon, ui.detailHistory
    ui.dungeon, ui.quest, ui.detailHistory = addon.dungeons[1], nil, {}; ui:Refresh()
    ui:InspectQuest(1); ui:InspectQuest(2); ui:InspectQuest(3)
    assert(#ui.detailHistory == 2 and ui:BackQuest() and ui.quest == 2 and #ui.detailHistory == 1)
    assert(ui:BackQuest() and ui.quest == 1 and #ui.detailHistory == 0 and canGoBack())
    assert(ui:BackQuest() and ui.quest == nil and #ui.detailHistory == 0 and not canGoBack())
    ui.dungeon, ui.quest, ui.detailHistory = nil, nil, {}; ui:InspectQuest(2000)
    assert(ui.quest == 2000 and not canGoBack() and not ui:BackQuest() and ui.quest == 2000)
    ui:InspectQuest(2001); assert(ui:BackQuest() and ui.quest == 2000 and not canGoBack())
    assert(not ui:BackQuest() and addon.char.detailHistory == nil and addon.db.detailHistory == nil)
    ui.quest, ui.dungeon, ui.detailHistory = quest, dungeon, history; ui:Refresh()
end)
check("Source copy instructions live inside the detail scroll content and remain readable across locales", function()
    local quest, history, locale = ui.quest, ui.detailHistory, addon.db.locale
    ui.detailHistory = {}; showDetail(1); ui.source.scripts.OnClick(ui.source, "LeftButton", false)
    assert(ui.copyHint and ui.copyHint.shown and ui.copyHint.text == addon.L("COPY"))
    assert(ui.copy.parent == ui.detail and ui.copy.width <= 334 and ui.copyHint.width <= 334 and ui.copy.point[1] == "TOPLEFT")
    local url = ui.copy.text
    assert(ui.copy.focused and ui.detailScroll.verticalScroll == math.max(0, ui.detail:GetHeight() - ui.detailScroll:GetHeight()))
    measurement = function(fs) return fs == ui.copyHint and 54 or 18 end
    ui.source.scripts.OnClick(ui.source, "LeftButton", false)
    local top = -ui.copy.point[3] - ui.detailScroll.verticalScroll
    assert(top >= 0 and top + 34 + 54 <= ui.detailScroll:GetHeight(), "the full wrapped copy hint stays inside its scroll viewport")
    ui.copy:SetText("User-selected text")
    for code in pairs(addon.locales) do
        addon.db.locale = code; ui:Refresh()
        assert(ui.copy.text == "User-selected text" and ui.copy.focused and ui.copyHint.text == addon.L("COPY") and ui.copyHint.shown)
    end
    ui.source.scripts.OnClick(ui.source, "LeftButton", false); assert(ui.copy.text == url and ui.copy.focused)
    ui.copy.scripts.OnEscapePressed(ui.copy)
    assert(not ui.copy.shown and not ui.copy.focused and ui.copy.text == "" and not ui.copyHint.shown and ui.copyHint.text == "")
    assert(ui.quest == 1 and #ui.detailHistory == 0)
    assert(not ui:CopyLink(2) and ui.copy.text == "" and not ui.copy.shown, "a stale requested quest cannot reopen a cached link")
    measurement = nil; addon.db.locale, ui.quest, ui.detailHistory = locale, quest, history; ui:Refresh()
end)
check("Source copy drawer clears cached URLs and focus on quest Back and window close without touching external tooltips", function()
    local quest, history, tooltip = ui.quest, ui.detailHistory, GameTooltip
    local foreign = {}; GameTooltip = foreign
    ui.detailHistory = {}; showDetail(1); ui:InspectQuest(2); ui.source.scripts.OnClick(ui.source, "LeftButton", false)
    assert(ui.copyHint.shown); assert(ui:BackQuest() and ui.quest == 1)
    assert(ui.copy.text == "" and not ui.copy.shown and not ui.copyHint.shown and not ui.copy.focused)
    ui.source.scripts.OnClick(ui.source, "LeftButton", false)
    ui.frame:Hide(); ui.frame.scripts.OnHide(ui.frame)
    assert(ui.copy.text == "" and not ui.copy.shown and not ui.copyHint.shown and not ui.copy.focused)
    ui.frame:Show(); ui.frame.scripts.OnShow(ui.frame)
    assert(ui.quest == 1 and not ui.copy.shown and ui.copy.text == "" and GameTooltip == foreign)
    ui.source.scripts.OnClick(ui.source, "LeftButton", false); assert(ui:BackQuest() and ui.quest == nil)
    assert(not ui.copy.shown and not ui.copyHint.shown and ui.copy.text == "" and not ui.source.enabled)
    assert(addon.char.copyQuest == nil and addon.db.copyQuest == nil)
    GameTooltip, ui.quest, ui.detailHistory = tooltip, quest, history; ui:Refresh()
end)
check("Escape restores the first pre-copy reading position without replacing it on repeated Source clicks", function()
    local quest, history, description = ui.quest, ui.detailHistory, addon.Description
    local long = "Long original reader paragraph"
    addon.Description = function() return long end
    measurement = function(fs) return fs.text == long and 900 or 18 end
    ui.detailHistory = {}; showStory(1); ui.detailScroll:SetVerticalScroll(95)
    local reads = ui.detailScroll.scrollReads or 0
    ui.source.scripts.OnClick(ui.source, "LeftButton", false)
    assert(ui.detailScroll.verticalScroll > 95 and ui.detailScroll.scrollReads == reads + 1)
    ui.source.scripts.OnClick(ui.source, "LeftButton", false); ui:RefreshDetail()
    assert(ui.detailScroll.scrollReads == reads + 1)
    ui.copy.scripts.OnEscapePressed(ui.copy)
    assert(ui.quest == 1 and ui.detailScroll.verticalScroll == 95 and not ui.copy.shown and not ui.copy.focused)
    ui.detailScroll:SetVerticalScroll(0); ui.source.scripts.OnClick(ui.source, "LeftButton", false)
    ui.copy.scripts.OnEscapePressed(ui.copy); assert(ui.detailScroll.verticalScroll == 0, "top is a real reading position")
    measurement = nil; addon.Description = description; ui.quest, ui.detailHistory = quest, history; ui:Refresh()
end)
check("Copy Escape clamps against fresh content and never restores another card or window session", function()
    local quest, history, description = ui.quest, ui.detailHistory, addon.Description
    local long, shortened = "Long changing reader paragraph", false
    addon.Description = function() return shortened and "Short paragraph" or long end
    measurement = function(fs) return fs.text == long and 900 or 18 end
    ui.detailHistory = {}; showStory(1); ui.detailScroll:SetVerticalScroll(95)
    ui.source.scripts.OnClick(ui.source, "LeftButton", false); shortened = true
    ui.copy.scripts.OnEscapePressed(ui.copy)
    assert(ui.detailScroll.verticalScroll == math.min(95, math.max(0, ui.detail:GetHeight() - ui.detailScroll:GetHeight())))
    shortened = false; ui:RefreshDetail(); ui.detailScroll:SetVerticalScroll(75)
    ui.source.scripts.OnClick(ui.source, "LeftButton", false)
    local sourceOffset = ui.detailScroll.verticalScroll
    ui:InspectQuest(2)
    assert(ui.detailScroll.verticalScroll == 0 and not ui.copy.shown)
    assert(ui:BackQuest() and ui.quest == 1 and ui.detailScroll.verticalScroll == math.min(sourceOffset, math.max(0, ui.detail:GetHeight() - ui.detailScroll:GetHeight())))
    ui.detailScroll:SetVerticalScroll(23); ui.source.scripts.OnClick(ui.source, "LeftButton", false)
    ui.frame:Hide(); ui.frame.scripts.OnHide(ui.frame); ui.frame:Show(); ui.frame.scripts.OnShow(ui.frame)
    assert(ui:SetDetailTab("story"))
    ui.detailScroll:SetVerticalScroll(31); ui.source.scripts.OnClick(ui.source, "LeftButton", false)
    ui.copy.scripts.OnEscapePressed(ui.copy); assert(ui.detailScroll.verticalScroll == 31)
    assert(addon.char.copyReturn == nil and addon.db.copyReturn == nil)
    measurement = nil; addon.Description = description; ui.quest, ui.detailHistory = quest, history; ui:Refresh()
end)
check("Unknown restricted and throwing scroll offsets never become restoration positions", function()
    local getter, checker, quest = ui.detailScroll.GetVerticalScroll, issecretvalue, ui.quest
    local restricted = {}; issecretvalue = function(value) return value == restricted end
    for _, value in ipairs({ restricted, -1, math.huge, 0/0, "95", false }) do
        showDetail(1); ui.detailScroll.GetVerticalScroll = function() return value end
        assert(ui:CopyLink(1)); local writes = ui.detailScroll.scrollWrites
        ui.copy.scripts.OnEscapePressed(ui.copy)
        assert(ui.detailScroll.scrollWrites == writes and not ui.copy.shown)
    end
    ui.detailScroll.GetVerticalScroll = function() error("scroll offset unavailable") end
    assert(ui:CopyLink(1)); local writes = ui.detailScroll.scrollWrites
    ui.copy.scripts.OnEscapePressed(ui.copy); assert(ui.detailScroll.scrollWrites == writes)
    ui.detailScroll.GetVerticalScroll, issecretvalue, ui.quest = getter, checker, quest; ui:Refresh()
end)
check("Reentrant offset and content reads cannot restore a prior quest's copy position", function()
    local quest, history = ui.quest, ui.detailHistory
    local offsetGetter, heightGetter = ui.detailScroll.GetVerticalScroll, ui.detail.GetHeight
    ui.detailHistory = {}; showDetail(1)
    local armed = true
    ui.detailScroll.GetVerticalScroll = function()
        if armed then armed = false; ui:InspectQuest(2) end
        return 95
    end
    assert(not ui:CopyLink(1) and ui.quest == 2 and not ui.copy.shown and not ui.copy.focused)
    ui.detailScroll.GetVerticalScroll = offsetGetter
    showDetail(1); ui.detailScroll:SetVerticalScroll(95); assert(ui:CopyLink(1))
    armed = true
    ui.detail.GetHeight = function(region)
        if armed then armed = false; ui:InspectQuest(2) end
        return heightGetter(region)
    end
    ui.copy.scripts.OnEscapePressed(ui.copy)
    assert(not armed and ui.quest == 2 and ui.detailScroll.verticalScroll == 0 and not ui.copy.shown)
    ui.detail.GetHeight = heightGetter; ui.quest, ui.detailHistory = quest, history; ui:Refresh()
end)
check("A copy close during reentrant same-quest reopen invalidates the older Escape restoration", function()
    local quest, history, description, heightGetter = ui.quest, ui.detailHistory, addon.Description, ui.detail.GetHeight
    local long, armed = "Long copy lifecycle paragraph", false
    addon.Description = function()
        if armed then
            armed = false
            ui.frame:Hide(); ui.frame.scripts.OnHide(ui.frame)
            ui.frame:Show(); ui.frame.scripts.OnShow(ui.frame)
            ui.detailScroll:SetVerticalScroll(7)
        end
        return long
    end
    measurement = function(fs) return fs.text == long and 900 or 18 end
    ui.detailHistory = {}; showStory(1); ui.detailScroll:SetVerticalScroll(95); assert(ui:CopyLink(1))
    armed = true; ui.copy.scripts.OnEscapePressed(ui.copy)
    assert(not armed and ui.quest == 1 and ui.detailScroll.verticalScroll == 7, "old Escape must not overwrite the reopened window session")
    ui.detailScroll:SetVerticalScroll(95); assert(ui:CopyLink(1))
    armed = true
    ui.detail.GetHeight = function(region)
        if armed then armed = false; ui:CloseCopyLink(); ui.detailScroll:SetVerticalScroll(7) end
        return heightGetter(region)
    end
    ui.copy.scripts.OnEscapePressed(ui.copy)
    assert(not armed and ui.detailScroll.verticalScroll == 7, "a later close during geometry read also invalidates restoration")
    measurement = nil; addon.Description, ui.detail.GetHeight = description, heightGetter
    ui.quest, ui.detailHistory = quest, history; ui:Refresh()
end)
do
    local function historyReadingFixture()
        local old = { quest = ui.quest, history = ui.detailHistory, dungeon = ui.dungeon, description = addon.Description,root=ui.questTreeRoot,treeDungeon=ui.questTreeDungeon }
        addon.quests[18001] = { id = 18001, minLevel = 1, requirementsKnown = true, requires = { { ids = { 18002 } } } }
        addon.quests[18002] = { id = 18002, minLevel = 1, requirementsKnown = true }
        addon.quests[18003] = { id = 18003, minLevel = 1, requirementsKnown = true }
        local long = "Long related quest reading text"
        addon.Description = function() return long end
        -- Keep every inspected card scrollable independently of disclosure defaults.
        measurement = function(fs) return (fs.text == long or fs.text:find(addon.L("DETAIL_MIN_LEVEL", 1), 1, true)) and 900 or 18 end
        ui.dungeon={key="reading-tree",quests={18001}};ui.questTreeRoot,ui.questTreeDungeon=18001,ui.dungeon;ui:RefreshQuests()
        ui.detailHistory = {};showStory(18001);ui:RefreshQuests();ui:RefreshDetail()
        return function()
            addon.quests[18001], addon.quests[18002], addon.quests[18003] = nil, nil, nil
            measurement = nil; addon.Description = old.description
            ui.quest, ui.detailHistory, ui.dungeon = old.quest, old.history, old.dungeon; ui:Refresh()
            ui.questTreeRoot,ui.questTreeDungeon=old.root,old.treeDungeon
        end
    end
    check("Back from a clicked prerequisite returns to the original reading location", function()
        local restore = historyReadingFixture()
        assert(ui:SetDetailTab("story")); ui.detailScroll:SetVerticalScroll(480)
        local row;for _,candidate in ipairs(ui.rows)do if candidate.shown and candidate.questTreeNode and candidate.questID==18002 then row=candidate end end
        assert(row.questID == 18002 and row.enabled)
        row.scripts.OnClick(row, "LeftButton", false)
        assert(ui.quest == 18002 and ui.detailScroll.verticalScroll == 0 and ui.detailHistory[1] == 18001)
        ui:BackQuest()
        assert(ui.quest == 18001 and ui.detailScroll.verticalScroll == 480 and #ui.detailHistory == 0)
        restore()
    end)
    check("Reading offsets follow duplicate history entries and preserve zero without entering saved data", function()
        local restore = historyReadingFixture()
        assert(ui:SetDetailTab("story")); ui.detailScroll:SetVerticalScroll(480); ui:InspectQuest(18002)
        assert(ui:SetDetailTab("story")); ui.detailScroll:SetVerticalScroll(220); ui:InspectQuest(18001)
        assert(ui:SetDetailTab("story")); ui.detailScroll:SetVerticalScroll(130); ui:InspectQuest(18003)
        assert(ui:BackQuest() and ui.quest == 18001 and ui.detailScroll.verticalScroll == 130)
        assert(ui:BackQuest() and ui.quest == 18002 and ui.detailScroll.verticalScroll == 220)
        assert(ui:BackQuest() and ui.quest == 18001 and ui.detailScroll.verticalScroll == 480)
        assert(ui:SetDetailTab("story")); ui.detailScroll:SetVerticalScroll(0); ui:InspectQuest(18002)
        assert(ui:BackQuest() and ui.quest == 18001 and ui.detailScroll.verticalScroll == 0)
        for _, id in ipairs(ui.detailHistory) do assert(type(id) == "number" and id > 0 and id % 1 == 0) end
        assert(addon.char.detailOffsets == nil and addon.db.detailOffsets == nil)
        restore()
    end)
    check("History reading positions stay aligned when the twenty-entry limit removes older visits", function()
        local restore = historyReadingFixture()
        for visit = 1, 25 do
            assert(ui:SetDetailTab("story")); ui.detailScroll:SetVerticalScroll(visit * 10)
            assert(ui:InspectQuest(ui.quest == 18001 and 18002 or 18001))
        end
        assert(#ui.detailHistory == 20)
        for visit = 25, 6, -1 do
            assert(ui:BackQuest() and ui.detailScroll.verticalScroll == visit * 10)
        end
        assert(#ui.detailHistory == 0)
        restore()
    end)
    check("Unknown reading offsets are omitted and reentrant scroll reads cannot overwrite a newer visit", function()
        local restore = historyReadingFixture()
        local getter = ui.detailScroll.GetVerticalScroll
        for _, result in ipairs({ false, -1, math.huge, "95" }) do
            ui.detailScroll.GetVerticalScroll = function() return result end
            ui:InspectQuest(18002)
            ui.detailScroll.GetVerticalScroll = getter
            assert(ui:BackQuest() and ui.quest == 18001 and ui.detailScroll.verticalScroll == 0)
        end
        local armed = true
        ui.detailScroll.GetVerticalScroll = function(region)
            if armed then armed = false; ui:InspectQuest(18003) end
            return getter(region)
        end
        assert(not ui:InspectQuest(18002) and ui.quest == 18003 and #ui.detailHistory == 1)
        ui.detailScroll.GetVerticalScroll = getter
        assert(ui:BackQuest() and ui.quest == 18001)
        restore()
    end)
    check("Back restoration clamps shortened content and cannot overwrite a reentered window session", function()
        local restore = historyReadingFixture()
        local description, height, title = addon.Description, ui.detail.GetHeight, addon.QuestName
        assert(ui:SetDetailTab("story")); ui.detailScroll:SetVerticalScroll(480); ui:InspectQuest(18002)
        addon.Description = function() return "Shortened reading text" end
        assert(ui:BackQuest() and ui.detailScroll.verticalScroll == math.min(480, math.max(0, ui.detail:GetHeight() - ui.detailScroll:GetHeight())))
        addon.Description = description
        ui:RefreshDetail(); assert(ui:SetDetailTab("story")); ui.detailScroll:SetVerticalScroll(480); ui:InspectQuest(18002)
        local armed = true
        addon.QuestName = function(id)
            if armed then
                armed = false
                ui.frame:Hide(); ui.frame.scripts.OnHide(ui.frame)
                ui.frame:Show(); ui.frame.scripts.OnShow(ui.frame)
                ui.detailScroll:SetVerticalScroll(7)
            end
            return title(id)
        end
        assert(ui:BackQuest() and ui.quest == 18001 and ui.detailScroll.verticalScroll == 7)
        addon.QuestName = title
        assert(ui:SetDetailTab("story")); ui.detailScroll:SetVerticalScroll(480); ui:InspectQuest(18002)
        armed = true
        ui.detail.GetHeight = function(region)
            if armed then armed = false; ui:ResetHistoryReading(); ui.detailScroll:SetVerticalScroll(9) end
            return height(region)
        end
        assert(ui:BackQuest() and ui.detailScroll.verticalScroll == 9)
        ui.detail.GetHeight = height
        restore()
    end)
    check("External history replacement dungeon changes and window close drop former reading offsets", function()
        local restore = historyReadingFixture()
        assert(ui:SetDetailTab("story")); ui.detailScroll:SetVerticalScroll(480); ui:InspectQuest(18002)
        ui.detailHistory = { 18001 }
        assert(ui:BackQuest() and ui.quest == 18001 and ui.detailScroll.verticalScroll == 0)
        assert(ui:SetDetailTab("story")); ui.detailScroll:SetVerticalScroll(480); ui:InspectQuest(18002)
        ui.frame:Hide(); ui.frame.scripts.OnHide(ui.frame); ui.frame:Show(); ui.frame.scripts.OnShow(ui.frame)
        assert(ui:BackQuest() and ui.quest == 18001 and ui.detailScroll.verticalScroll == 0)
        assert(ui:SetDetailTab("story")); ui.detailScroll:SetVerticalScroll(480); ui:InspectQuest(18002)
        ui.dungeon = { key = "other-reading-context", name = "Other context", minLevel = 1, maxLevel = 60, coverage = "partial", quests = {} }
        assert(ui:BackQuest() and ui.quest == 18001 and ui.detailScroll.verticalScroll == 0)
        restore()
    end)
end
check("Middle OR inspection remains separate from preference and foreign-character availability",function()
    local context,dungeon,quest,history,choices=addon.Context,ui.dungeon,ui.quest,ui.detailHistory,addon.char.choices
    local description,locale=addon.Description,addon.db.locale
    addon.Description=function()return "Long OR inspection text"end
    measurement=function(fs)return fs.text=="Long OR inspection text" and 900 or 18 end
    addon.Context=function()local c=context();c.faction="Alliance";return c end
    addon.quests[19001]={id=19001,minLevel=1,requirementsKnown=true,requires={{ids={19002,19003}}}}
    addon.quests[19002]={id=19002,minLevel=1,requirementsKnown=true}
    addon.quests[19003]={id=19003,minLevel=1,requirementsKnown=true,factions={"Horde"}}
    ui.dungeon={name="Inspection fixture",key="inspection-fixture",quests={19001},coverage="partial"}
    addon.char.choices={[19001]={[1]=19002}};ui.detailHistory={};showDetail(19001)
    ui.questTreeRoot,ui.questTreeDungeon=19001,ui.dungeon;ui:RefreshQuests();ui:RefreshDetail()
    local function rowFor(id)for _,row in ipairs(ui.rows)do if row.shown and row.questTreeNode and row.questID==id then return row end end end
    local button=rowFor(19003);assert(button and button.enabled and not button.branchControl.enabled and ui.action.id==19002)
    local picked=addon.char.choices;ui.detailScroll:SetVerticalScroll(12);button.scripts.OnClick()
    assert(ui.quest==19003 and addon.char.choices==picked and picked[19001][1]==19002)
    assert(detailHas(addon.L("REASON_faction")) and not ui.action)
    assert(ui:BackQuest() and ui.quest==19001 and ui.action.id==19002 and ui.detailScroll.verticalScroll==math.min(12,math.max(0,ui.detail.height-ui.detailScroll:GetHeight())))
    local stale=rowFor(19002).scripts.OnClick;ui:RefreshQuests();stale();assert(ui.quest==19001)
    for language in pairs(addon.locales)do
        addon.db.locale=language;ui:RefreshQuests();assert(rowFor(19002).note.text:find(addon.L("REQUIREMENT_NOTICE"),1,true))
    end
    local reused=rowFor(19002)
    measurement=function(fs)if fs==reused.title then return 54 end;if fs.text=="Long OR inspection text"then return 900 end;return 18 end
    ui:RefreshQuests();assert(reused.height>=66)
    local late=rowFor(19002).scripts.OnClick;showDetail(19002);late();assert(ui.quest==19002 and picked[19001][1]==19002)
    addon.Context,addon.char.choices=context,choices;addon.Description,addon.db.locale=description,locale;measurement=nil
    addon.quests[19001],addon.quests[19002],addon.quests[19003]=nil,nil,nil
    ui.dungeon,ui.quest,ui.detailHistory=dungeon,quest,history;ui.questTreeRoot,ui.questTreeDungeon=nil,nil;ui:Refresh()
end)
check("Native font families retain alphabet fallback while detail sizes and pooled styles stay explicit", function()
    local previous, family, getter = ChatFontNormal, {}, GetLocale
    GetLocale=function()return "koKR"end
    ChatFontNormal = family
    local row = ui:MakeRow(ui.questList, {}, 1, 59)
    assert(row.title.fontFamily == family and row.title.fontSize == 17)
    assert(row.note.fontFamily == family and row.note.fontSize == 14)
    showDetail(1)
    local title = ui.details[1]
    assert(title.fontFamily == family and title.fontSize == 22 and title.fontSizeAtText == 22)
    local oldFamily = family; ChatFontNormal = {}
    title.measuredHeight = 777
    ui:RefreshDetail()
    assert(title.fontFamily == ChatFontNormal and title.fontFamily ~= oldFamily)
    assert(title.measuredHeight ~= 777 and title.fontResetBeforeText)
    ui.source.scripts.OnClick(ui.source, "LeftButton", false)
    assert(ui.copyHint.fontFamily == ChatFontNormal and ui.copyHint.fontSize == 13)
    ui:CloseCopyLink(); row:Hide(); ChatFontNormal = previous; GetLocale=getter; ui:Refresh()
end)
check("Missing restricted and failing optional family setters retain the working font path", function()
    local previous, objectSetter, heightSetter, checker = ChatFontNormal, methods.SetFontObject, methods.SetFontHeight, issecretvalue
    local restricted = {}
    issecretvalue = function(value) return value == restricted end
    for mode = 1, 6 do
        ChatFontNormal, methods.SetFontObject, methods.SetFontHeight = {}, objectSetter, heightSetter
        if mode == 1 then ChatFontNormal = nil
        elseif mode == 2 then ChatFontNormal = restricted
        elseif mode == 3 then methods.SetFontObject = false
        elseif mode == 4 then methods.SetFontHeight = false
        elseif mode == 5 then methods.SetFontObject = function() error("font object unavailable") end
        else methods.SetFontHeight = function() error("font sizing unavailable") end end
        local row = ui:MakeRow(ui.questList, {}, 1, 59)
        assert(row.title.fontPath and row.title.fontFamily == nil and row.title.fontSize == 17)
        assert(row.note.fontPath and row.note.fontFamily == nil and row.note.fontSize == 14)
        row:Hide()
    end
    ChatFontNormal, methods.SetFontObject, methods.SetFontHeight, issecretvalue = previous, objectSetter, heightSetter, checker
    ui:Refresh()
end)
local function languageMenuFixture()
    local old, rows = MenuUtil, {}
    MenuUtil={CreateContextMenu=function(owner,generator)
        assert(owner==ui.language)
        rows={}
        local root={CreateRadio=function(_,name,checked,select,data)
            rows[#rows+1]={name=name,checked=checked,select=select,data=data};return {}
        end}
        generator(owner,root);return {}
    end}
    return function() return rows end,function()MenuUtil=old end
end
check("Language button opens eleven explicit native-language radio choices without cycling",function()
    local locale=addon.db.locale
    local rows,restore=languageMenuFixture()
    addon.db.locale="enUS";showDetail(1);ui.detailScroll:SetVerticalScroll(23)
    ui.language.scripts.OnClick(ui.language,"LeftButton",false)
    assert(addon.db.locale=="enUS" and #rows()==11)
    assert(rows()[1].data=="auto" and rows()[1].name==addon.L("LANGUAGE_AUTO"))
    assert(rows()[2].name=="English" and rows()[2].checked() and not rows()[3].checked())
    assert(rows()[3].name=="Русский" and rows()[9].name=="한국어" and rows()[11].name=="繁體中文")
    for _,row in ipairs(rows()) do
        local code=row.data
        ui.language.scripts.OnClick();local live
        for _,choice in ipairs(rows()) do if choice.data==code then live=choice end end
        live.select(code);assert(addon.db.locale==code and ui.quest==1 and ui.detailScroll.verticalScroll==23)
    end
    addon.db.locale="unknown";ui.language.scripts.OnClick()
    for _,row in ipairs(rows())do assert(row.checked() == (row.data == "enUS"))end
    rows()[1].select("auto");assert(addon.db.locale=="auto")
    restore();addon.db.locale=locale;ui:Refresh()
end)
check("Missing failing and malformed language menus retain one fallback cycle without double selection",function()
    local original,locale=MenuUtil,addon.db.locale
    for _,creator in ipairs({false,function()error("not ready")end,function(_,generator)generator(ui.language,nil)end,function()return nil end})do
        MenuUtil={CreateContextMenu=creator};addon.db.locale="auto"
        ui.language.scripts.OnClick();assert(addon.db.locale=="enUS")
    end
    MenuUtil={CreateContextMenu=function(owner,generator)
        local root={CreateRadio=function(_,name,checked,select,code)
            if code=="ruRU" then select(code);error("failure after actual selection")end
        end}
        generator(owner,root)
    end}
    addon.db.locale="auto";ui.language.scripts.OnClick();assert(addon.db.locale=="ruRU")
    MenuUtil,addon.db.locale=original,locale;ui:Refresh()
end)
check("Old language menu callbacks cannot edit a replacement database closed window or newer menu",function()
    local database,locale=addon.db,addon.db.locale
    local rows,restore=languageMenuFixture()
    addon.db.locale="enUS";ui.language.scripts.OnClick();local old=rows()[3].select
    ui.language.scripts.OnClick();old();assert(addon.db.locale=="enUS")
    local replaced=rows()[3].select
    addon.db={locale="enUS"};replaced();assert(addon.db.locale=="enUS" and database.locale=="enUS")
    addon.db=database;ui.language.scripts.OnClick();local hidden=rows()[3].select
    ui.frame:Hide();ui.frame.scripts.OnHide(ui.frame)
    ui.frame:Show();ui.frame.scripts.OnShow(ui.frame);hidden();assert(addon.db.locale=="enUS")
    restore();addon.db.locale=locale;ui:Refresh()
end)
local function actionTreeRow(id)
    for _,row in ipairs(ui.rows)do if row.shown and row.questTreeNode and row.questID==id then return row end end
end
local function multiActionFixture()
    local saved={context=addon.Context,quest=ui.quest,dungeon=ui.dungeon,history=ui.detailHistory,nav=addon.Navigation,root=ui.questTreeRoot,treeDungeon=ui.questTreeDungeon}
    addon.Context=function()return {level=60,active=function()return false end,completed=function()return false end}end
    addon.quests[20001]={id=20001,minLevel=1,requirementsKnown=true,requires={{ids={20002}},{ids={20003}}}}
    for _,id in ipairs({20002,20003})do addon.quests[id]={id=id,minLevel=1,requirementsKnown=true,start={mapID=1,x=20,y=30,name="Giver "..id}}end
    ui.dungeon={key="independent-steps",quests={20001}};ui.questTreeRoot,ui.questTreeDungeon=20001,ui.dungeon
    ui.detailHistory={};showDetail(20001);ui:RefreshQuests();ui:RefreshDetail()
    return function()
        addon.Context,addon.Navigation=saved.context,saved.nav
        addon.quests[20001],addon.quests[20002],addon.quests[20003]=nil,nil,nil
        ui.quest,ui.dungeon,ui.detailHistory=saved.quest,saved.dungeon,saved.history
        ui.questTreeRoot,ui.questTreeDungeon=saved.root,saved.treeDungeon;ui:Refresh()
    end
end
check("Independent middle prerequisites open their own giver before explicit navigation",function()
    local restore=multiActionFixture();local routed={}
    addon.Navigation={Start=function(action)routed[#routed+1]=action end,Map=function(point)routed[#routed+1]=point end}
    assert(actionTreeRow(20002) and actionTreeRow(20003) and ui.action.id==20002)
    ui.giver.scripts.OnClick();dispatchGiverMap();assert(#routed==0 and not ui.giverAction)
    actionTreeRow(20003).scripts.OnClick();assert(ui.quest==20003 and ui.action.id==20003)
    ui.giver.scripts.OnClick();assert(routed[1].id==20003 and routed[1].place==addon.quests[20003].start)
    dispatchGiverMap();assert(routed[2]==addon.quests[20003].start)
    local old=addon.quests[20003].start;local fresh={mapID=9,x=70,y=80,name="Moved giver"}
    addon.quests[20003].start=fresh;ui:RefreshDetail();assert(ui.action.place==fresh)
    addon.quests[20003].start=old;restore()
end)
check("Middle unknown and level prerequisites allow inspection without authorizing quest availability",function()
    local restore=multiActionFixture()
    addon.quests[20003].requirementsKnown=false;ui:RefreshQuests();ui:RefreshDetail()
    actionTreeRow(20003).scripts.OnClick();assert(ui.quest==20003 and not ui.action and ui.giverAction.kind=="visit")
    assert(detailHas(addon.L("REASON_requirementsUnknown")))
    addon.quests[20003].requirementsKnown=true;addon.quests[20003].minLevel=80
    ui:RefreshQuests();ui:RefreshDetail();assert(ui.action.kind=="level" and ui.giverAction.kind=="visit")
    assert(ui.engine:State(20003).status=="LOCKED");restore()
end)
check("Middle action inspection restores reading while stale row callbacks remain inert",function()
    local restore=multiActionFixture();local description=addon.Description
    addon.Description=function()return "Long action source reading"end
    measurement=function(fs)return fs.text=="Long action source reading" and 900 or 18 end
    ui:RefreshDetail();ui.detailScroll:SetVerticalScroll(200)
    actionTreeRow(20003).scripts.OnClick();assert(ui.quest==20003 and #ui.detailHistory==1)
    assert(ui:BackQuest() and ui.quest==20001 and ui.detailScroll.verticalScroll==math.min(200,math.max(0,ui.detail.height-ui.detailScroll:GetHeight())))
    local stale=actionTreeRow(20003).scripts.OnClick;ui:RefreshQuests();stale();assert(ui.quest==20001)
    showDetail(20002);stale();assert(ui.quest==20002)
    addon.Description=description;measurement=nil;restore()
end)
check("Middle prerequisite rows wrap and stale character or session callbacks cannot select an old step",function()
    local restore=multiActionFixture();local first=actionTreeRow(20002)
    measurement=function(fs)return fs==first.title and 72 or 18 end
    ui:RefreshQuests();assert(actionTreeRow(20002).height>=84)
    local stale=actionTreeRow(20003).scripts.OnClick;local character=addon.char
    addon.char={};stale();assert(ui.quest==20001);addon.char=character
    ui.frame:Hide();ui.frame.scripts.OnHide();stale();assert(ui.quest==20001)
    ui.frame:Show();ui.frame.scripts.OnShow();measurement=nil;restore()
end)
check("Hydrating a middle action title cannot overwrite a newer selected supporting card",function()
    local restore=multiActionFixture();local name,armed=addon.QuestName,true
    addon.QuestName=function(id)if armed and id==20003 then armed=false;ui:InspectQuest(20002)end;return name(id)end
    ui:RefreshQuests();assert(not armed and ui.quest==20002 and ui.action.id==20002 and hasDestination(true))
    addon.QuestName=name;restore()
end)
check("Middle title hydration cannot leave actionable rows for a former character",function()
    local restore=multiActionFixture();local character,name=addon.char,addon.QuestName;local armed=true
    local stale=actionTreeRow(20003).scripts.OnClick
    addon.QuestName=function(id)if armed and id==20002 then armed=false;addon.char={}end;return name(id)end
    ui:RefreshQuests();assert(not armed);stale();assert(ui.quest==20001)
    for _,row in ipairs(ui.rows)do assert(not row.shown,"a former character's staged middle rows stay hidden")end
    addon.char,addon.QuestName=character,name;restore()
end)
check("Right details never hydrate a duplicate prepared-action name or giver list",function()
    local restore=multiActionFixture();local name,map=addon.QuestName,C_Map;local reads=0
    addon.QuestName=function(id)if id==20002 or id==20003 then reads=reads+1 end;return name(id)end
    C_Map={GetMapInfo=function()error("unselected supporting giver must not be queried")end}
    ui:RefreshDetail();assert(reads==0 and ui.action.id==20002 and not ui.giverAction)
    assert(not detailHas(addon.L("NEXT")))
    addon.QuestName,C_Map=name,map;restore()
end)
check("Guidance is published only after a current engine finishes later detail hydration",function()
    local restore=multiActionFixture()
    local objectives=addon.QuestObjectives
    local current=ui.engine.Current
    addon.QuestObjectives=function()
        ui.engine.Current=function()return false end
        return nil
    end
    ui:RefreshDetail()
    assert(ui.action==nil and not hasDestination(false) and not hasDestination(true))
    addon.QuestObjectives=objectives;ui.engine.Current=current;restore()
end)
check("Explicit map and guide clicks reject invalid throwing and reentered engine contexts",function()
    local restore=multiActionFixture()
    addon.quests[20001].start={mapID=1,x=45,y=55,name="Selected giver"};ui:RefreshDetail()
    local calls=0;addon.Navigation={Map=function()calls=calls+1 end,Start=function()calls=calls+1 end}
    local current=ui.engine.Current
    for _,getter in ipairs({function()return false end,function()return nil end,function()error("expired")end})do
        ui.engine.Current=getter
        dispatchGiverMap();ui.giver.scripts.OnClick();assert(calls==0)
    end
    ui.engine.Current=current
    local armed=true
    ui.engine.Current=function(engine)
        if armed then armed=false;ui:InspectQuest(20002)end
        return current(engine)
    end
    ui.giver.scripts.OnClick()
    assert(not armed and calls==0 and ui.quest==20002 and ui.action.id==20002 and hasDestination(false) and hasDestination(true))
    ui.engine.Current=current
    ui.giver.scripts.OnClick();assert(calls==1)
    restore()
end)
local function preparationForFixture()
    local saved={context=addon.Context,quest=ui.quest,dungeon=ui.dungeon,history=ui.detailHistory,choices=addon.char.choices,preparation=ui.preparation,all=ui.includeUnavailable}
    addon.Context=function()return{level=60,faction="Alliance",completed=function()return false end,active=function()return false end}end
    for id=21001,21006 do addon.quests[id]={id=id,minLevel=1,requirementsKnown=true,start={mapID=1,x=20,y=30}}end
    addon.quests[21001].requires={{ids={21003}}}
    addon.quests[21002].requires={{ids={21003,21004}}}
    addon.quests[21005].storyline={21003,21005}
    addon.quests[21006].requirementsKnown=false
    addon.char.choices={}
    ui.dungeon={key="preparation-for-fixture",name="Plan fixture",coverage="partial",quests={21001,21002,21005,21006}}
    ui.detailHistory={};ui.quest=21003;ui:Refresh();expandDetail()
    return function()
        addon.Context,addon.char.choices=saved.context,saved.choices
        ui.preparation,ui.includeUnavailable=saved.preparation,saved.all
        for id=21001,21006 do addon.quests[id]=nil end
        ui.quest,ui.dungeon,ui.detailHistory=saved.quest,saved.dungeon,saved.history;ui:Refresh()
    end
end
check("Shared supporting steps stay deduplicated in preparation while exact targets remain in the middle pane",function()
    local restore=preparationForFixture();ui.preparation=true;ui.quest=nil;ui:RefreshQuests();ui:RefreshDetail()
    local matches,sharedRow=0,nil
    for _,row in ipairs(ui.rows)do if row.shown and row.questID==21003 then matches=matches+1;sharedRow=row end end
    assert(matches==1 and sharedRow);sharedRow.scripts.OnClick()
    assert(matches==1 and ui.quest==21003)
    assert(ui.engine:Next(21001)[1].id==21003 and ui.engine:Next(21002)[1].id==21003)
    assert(not detailHas(addon.L("PREPARATION_FOR")))
    addon.char.choices[21002]={[1]=21004};ui:Refresh();assert(ui.engine:Next(21002)[1].id==21004 and ui.action.id==21003)
    ui.preparation=false;ui.questTreeRoot,ui.questTreeDungeon=21001,ui.dungeon;ui:RefreshQuests()
    local root;for _,row in ipairs(ui.rows)do if row.shown and row.anchorQuestID==21001 then root=row end end
    assert(root);root.scripts.OnClick();assert(ui.quest==21001 and ui.detailHistory[#ui.detailHistory]==21003)
    assert(ui:BackQuest() and ui.quest==21003);ui.questTreeRoot,ui.questTreeDungeon=nil,nil;restore()
end)
check("Middle target context wraps and refreshes locales without reviving duplicate right-side associations",function()
    local restore=preparationForFixture();local locale=addon.db.locale;local preferences=addon.char.choices
    ui.currentPlan.rows[#ui.currentPlan.rows+1]=ui.currentPlan.rows[1];ui:RefreshDetail()
    assert(not detailHas(addon.L("PREPARATION_FOR")))
    ui.questTreeRoot,ui.questTreeDungeon=21001,ui.dungeon
    measurement=function(fs)return fs.text=="Quest 21003" and 72 or 18 end
    for code in pairs(addon.locales)do
        addon.db.locale=code;ui:RefreshQuests();local count=0
        for _,row in ipairs(ui.rows)do if row.shown and row.questTreeNode and row.questID==21003 then count=count+1;assert(row.height>=84)end end
        assert(count==1 and addon.char.choices==preferences)
    end
    local stale;for _,row in ipairs(ui.rows)do if row.shown and row.questTreeNode and row.questID==21003 then stale=row.scripts.OnClick end end
    addon.db.locale=addon.db.locale=="ruRU"and"enUS"or"ruRU";ui:RefreshQuests()
    ui:InspectQuest(21005);local reading,history=ui.detailScroll.verticalScroll,#ui.detailHistory
    stale();assert(ui.quest==21005 and ui.detailScroll.verticalScroll==reading and #ui.detailHistory==history)
    measurement=nil;addon.db.locale=locale;ui.questTreeRoot,ui.questTreeDungeon=nil,nil;restore()
end)
check("Story-only unknown or absent-dungeon cards never invent preparation target links",function()
    local restore=preparationForFixture()
    showDetail(21005);assert(not detailHas(addon.L("PREPARATION_FOR")))
    showDetail(21006);assert(not detailHas(addon.L("PREPARATION_FOR")))
    ui.quest=21003;ui.dungeon=nil;ui:Refresh();assert(not ui.currentPlan and not detailHas(addon.L("PREPARATION_FOR")))
    for _,row in ipairs(ui.preparationForButtons or {})do assert(not row.shown and not row.scripts.OnClick)end
    restore()
end)
check("Supporting detail no longer hydrates unrelated target names or publishes links from an expired engine",function()
    local restore=preparationForFixture();local name=addon.QuestName;local reads=0
    addon.QuestName=function(id)if id==21001 or id==21002 then reads=reads+1 end;return name(id)end
    ui:RefreshDetail();assert(reads==0 and ui.quest==21003 and not detailHas(addon.L("PREPARATION_FOR")))
    ui.engine.Current=function()return false end;ui:RefreshDetail()
    assert(not ui.action and not hasDestination(false) and not hasDestination(true))
    addon.QuestName=name;restore()
end)
check("Foreign-character targets remain inspectable without adding their steps to character preparation",function()
    local restore=preparationForFixture();addon.quests[21002].factions={"Horde"};addon.char.choices[21002]={[1]=21004}
    for _,all in ipairs({false,true})do
        ui.includeUnavailable=all;ui:Refresh();assert(ui.engine:State(21002).status=="UNAVAILABLE")
        local plan=ui.engine:Dungeon(ui.dungeon,{includeUnavailable=all});local shared=0
        for _,action in ipairs(plan.actions)do assert(action.id~=21004);if action.id==21003 then shared=shared+1 end end
        assert(shared==1 and not detailHas(addon.L("PREPARATION_FOR")))
    end
    restore()
end)
local function giverReentryFixture(mode)
    local saved={context=addon.Context,map=C_Map,nav=addon.Navigation,quest=ui.quest,history=ui.detailHistory}
    addon.Context=function()return{level=60,completed=function()return false end,active=function()return false end}end
    for id=23001,23002 do
        local place={npcID=id,mapID=id-23000,x=20,y=30,name="Giver "..id}
        local q={id=id,minLevel=1,requirementsKnown=true}
        if mode=="finish"then q.finishAlternatives={place}
        elseif mode=="container"then place.npcID=nil;place.objectID=id;q.start={itemID=id,containerSource=place}
        elseif mode=="reported"then place.reportedLocations={{mapID=id-23000,x=20,y=30},{mapID=id-23000,x=40,y=50}};q.start=place
        else q.start=place end
        addon.quests[id]=q
    end
    ui.detailHistory={};showDetail(23001)
    return function()
        addon.Context,C_Map,addon.Navigation=saved.context,saved.map,saved.nav
        addon.quests[23001],addon.quests[23002]=nil,nil
        ui.quest,ui.detailHistory=saved.quest,saved.history;ui:Refresh()
    end
end
check("Giver location hydration cannot replace a newly inspected card's visit action",function()
    local restore=giverReentryFixture("giver")
    local armed=true
    C_Map={GetMapInfo=function(id)
        if armed and id==1 then armed=false;ui:InspectQuest(23002)end
        return{name="Zone"..id}
    end}
    local routed;addon.Navigation={Start=function(action)routed=action end}
    ui:RefreshDetail();assert(not armed and ui.quest==23002)
    ui.giver.scripts.OnClick(ui.giver,"LeftButton",false)
    assert(routed and routed.id==23002 and routed.place==addon.quests[23002].start)
    restore()
end)
check("Alternative and container hydration cannot overwrite the replacement card's pooled visit controls",function()
    for _,mode in ipairs({"finish","container"})do
        local restore=giverReentryFixture(mode)
        assert(ui:SetDetailTab("sources"))
        local armed=true
        C_Map={GetMapInfo=function(id)
            if armed and id==1 then armed=false;ui:InspectQuest(23002);assert(ui:SetDetailTab("sources"))end
            return{name="Zone"..id}
        end}
        local routed;addon.Navigation={Start=function(action)routed=action end}
        ui:RefreshDetail();assert(not armed and ui.quest==23002)
        local row=(mode=="finish"and ui.finishButtons or ui.containerButtons)[1]
        assert(row.shown and row.enabled and row.scripts.OnClick)
        row.scripts.OnClick(row,"LeftButton",false)
        assert(routed and routed.id==23002 and routed.place.mapID==2,mode)
        restore()
    end
end)
check("A replacement unknown map-only giver keeps informational navigation without inheriting old coordinate controls",function()
    local restore=giverReentryFixture("giver")
    addon.quests[23002].requirementsKnown=false
    addon.quests[23002].start.x,addon.quests[23002].start.y=nil,nil
    local armed=true
    C_Map={GetMapInfo=function(id)
        if armed and id==1 then armed=false;ui:InspectQuest(23002);expandDetail()end
        return{name="Zone"..id}
    end}
    local mapped,started;addon.Navigation={Map=function(point)mapped=point end,Start=function()started=true end}
    ui:RefreshDetail()
    assert(ui.quest==23002 and ui.engine:State(23002).status=="UNKNOWN" and ui.giver.enabled and not ui.giverHasCoordinates)
    assert(ui.giver.text=="" and ui.giver.footerLabelKey=="GIVER_MAP" and ui.giverAction.kind=="visit" and not ui.action)
    ui.giver.scripts.OnClick();assert(mapped==addon.quests[23002].start and not started)
    restore()
end)
check("Reported position hydration cannot resurrect old expanded points over a new collapsed card",function()
    local restore=giverReentryFixture("reported")
    assert(ui:SetDetailTab("sources"))
    ui.reportedExpanded.start=true
    local calls=0
    C_Map={GetMapInfo=function(id)
        if id==1 then calls=calls+1;if calls==2 then ui:InspectQuest(23002)end end
        return{name="Zone"..id}
    end}
    local routed;addon.Navigation={Start=function(action)routed=action end}
    ui:RefreshDetail();assert(ui.quest==23002 and not ui.reportedExpanded.start)
    for _,row in ipairs(ui.reportedRows)do assert(not row.shown and not row.enabled and not row.scripts.OnClick)end
    ui.giver.scripts.OnClick();assert(routed and routed.id==23002 and routed.place.mapID==2)
    restore()
end)
check("Same-card location redraw and character loss preserve only the newly owned giver binding",function()
    for _,mode in ipairs({"redraw","character"})do
        local restore=giverReentryFixture("giver")
        local character=addon.char
        local armed=true
        C_Map={GetMapInfo=function(id)
            if armed and id==1 then
                armed=false
                if mode=="character"then addon.char={}
                else addon.quests[23001].start={mapID=2,x=70,y=80,name="Replaced source"};ui:RefreshDetail()end
            end
            return{name="Zone"..id}
        end}
        local routed;addon.Navigation={Start=function(action)routed=action end}
        ui:RefreshDetail();assert(not armed)
        if mode=="character"then assert(not ui.giverAction and not ui.giver.enabled)
        else ui.giver.scripts.OnClick();assert(routed and routed.place.mapID==2 and routed.place==addon.quests[23001].start)end
        addon.char=character;restore()
    end
end)
check("Noto and probed CJK assets retain actual sizes and unscaled reusable rows",function()
    local old,locale=ChatFontNormal,addon.db.locale
    assert(ui.searchBox.fontSize==14 and not ui.searchBox.scaledText and ui.searchBox.SetFontHeight==false)
    assert(ui.copy and ui.copy.fontSize==14 and ui.copy.SetFontHeight==false)
    assert(ui.title.fontSize==22 and ui.heading.fontSize==26 and ui.summary==nil and ui.coverage==nil)
    assert(ui.footer==nil and ui.capacityStatus.fontSize==12 and ui.searchPlaceholder.fontSize==13)
    ChatFontNormal={unchanged=true}
    for code in pairs(addon.locales)do
        addon.db.locale=code;showDetail(1)
        local title=ui.details[1]
        local cjk={koKR="Fonts\\2002.ttf",zhCN="Fonts\\ARKai_T.ttf",zhTW="Fonts\\bHEI00M.ttf"}
        if cjk[code]then assert(title.fontPath==cjk[code] and title.fontFamily==nil)
        else assert(title.fontPath:find("NotoSans-Regular.ttf",1,true) and title.fontFamily==nil)end
        assert(title.fontSize==22 and not title.scaledText and title.shadow[1]==0 and title.shadow[2]==0)
    end
    addon.db.locale="enUS"
    local row=ui:MakeRow(ui.questList,{},1,59)
    assert(row.title.fontPath:find("NotoSans-Regular.ttf",1,true) and row.title.fontSize==17 and row.note.fontSize==14)
    assert(not row.title.scaledText and not row.note.scaledText and not ChatFontNormal.fontSize and ChatFontNormal.unchanged)
    row:Hide();ChatFontNormal,addon.db.locale=old,locale;ui:Refresh()
end)
check("Heading reflow moves only quest rows while detail retains its reclaimed title band",function()
    local selected,quest=ui.dungeon,ui.quest
    measurement=function(fs)if fs==ui.heading then return 68 end;return 18 end
    ui.questScroll:SetVerticalScroll(30);ui:RefreshQuests()
    assert(ui.summary==nil and ui.coverage==nil)
    assert(ui.questScroll.point[3]==-(66+68+8)and ui.detailScroll.point[3]==-66)
    assert(ui.questScroll.height==688+ui.questScroll.point[3]and ui.detailScroll.height==622 and ui.questScroll.verticalScroll==30)
    assert(ui.dungeon==selected and ui.quest==quest)
    measurement=nil;ui:RefreshQuests();assert(ui.questScroll.point[3]==-100 and ui.questScroll.height==588)
end)
local function questListReentryFixture()
    local saved={context=addon.Context,quest=ui.quest,dungeon=ui.dungeon,preparation=ui.preparation,all=ui.includeUnavailable,
        name=addon.QuestName,dungeonName=addon.DungeonName,giver=addon.GiverName,history=ui.detailHistory,character=addon.char}
    addon.Context=function()return{level=60,completed=function()return false end,active=function()return false end}end
    for id=24001,24002 do addon.quests[id]={id=id,minLevel=1,requirementsKnown=true,start={npcID=id,mapID=id-24000,x=20,y=30,name="Giver "..id}}end
    local old={key="oldlist",name="Old list",quests={24001},coverage="reviewed"}
    local new={key="newlist",name="New list",quests={24002},coverage="reviewed"}
    ui.preparation,ui.includeUnavailable=false,false;ui.dungeon=old;ui.detailHistory={};ui.quest=nil;ui:RefreshQuests()
    return old,new,function()
        addon.Context,addon.QuestName,addon.DungeonName,addon.GiverName=saved.context,saved.name,saved.dungeonName,saved.giver
        addon.char=saved.character
        addon.quests[24001],addon.quests[24002]=nil,nil
        ui.quest,ui.dungeon,ui.preparation,ui.includeUnavailable,ui.detailHistory=saved.quest,saved.dungeon,saved.preparation,saved.all,saved.history;ui:Refresh()
    end
end
check("A title hydration callback cannot overwrite a newly selected dungeon list",function()
    local old,new,restore=questListReentryFixture()
    local getter,armed=addon.QuestName,true
    addon.QuestName=function(id)
        if armed and id==24001 then armed=false;ui.dungeon=new;ui:RefreshQuests()end
        return getter(id)
    end
    ui:RefreshQuests()
    assert(not armed and ui.dungeon==new and ui.rows[1].title.text=="Quest 24002" and ui.rows[1].questID==24002)
    ui.rows[1].scripts.OnClick(ui.rows[1],"LeftButton",false);assert(ui.quest==24002)
    restore()
end)
check("Preparation giver and dungeon-heading hydration preserve the newer list's titles notes and plan",function()
    for _,mode in ipairs({"giver","heading"})do
        local old,new,restore=questListReentryFixture()
        local armed=true
        if mode=="giver"then
            ui.preparation=true
            addon.GiverName=function(place)
                if armed and place.npcID==24001 then armed=false;ui.dungeon=new;ui:RefreshQuests()end
                return "Native giver "..place.npcID
            end
        else
            addon.DungeonName=function(dungeon)
                if armed and dungeon==old then armed=false;ui.dungeon=new;ui:RefreshQuests()end
                return dungeon.name
            end
        end
        ui:RefreshQuests();assert(not armed and ui.dungeon==new and ui.heading.text==new.name)
        local found=false
        for _,row in ipairs(ui.rows)do
            if row.shown and row.questID then
                assert(row.questID==24002 and row.title.text=="Quest 24002")
                if mode=="giver"then assert(row.note.text:find("Native giver 24002",1,true))end
                found=true
            end
        end
        assert(found and ui.currentPlan.dungeon==new and ui.currentPlan.engine==ui.engine)
        restore()
    end
end)
check("A reentrant character-context read cannot replace the new list engine and captured clicks reject changed owners",function()
    local old,new,restore=questListReentryFixture()
    local getter,armed=addon.Context,true
    addon.Context=function()
        if armed then armed=false;ui.dungeon=new;ui:RefreshQuests()end
        return getter()
    end
    ui:RefreshQuests()
    assert(not armed and ui.dungeon==new and ui.rows[1].questID==24002 and ui.currentPlan.engine==ui.engine)
    local oldClick=ui.rows[1].scripts.OnClick
    ui:RefreshQuests();ui.quest=nil;oldClick();assert(ui.quest==nil)
    local character=addon.char;local changedCharacter=ui.rows[1].scripts.OnClick
    addon.char={};changedCharacter();assert(ui.quest==nil);addon.char=character
    local changedDungeon=ui.rows[1].scripts.OnClick
    ui.dungeon=old;changedDungeon();assert(ui.quest==nil)
    restore()
end)
check("Stable unknown-character quest rows remain visible and inspectable without invented actions",function()
    local old,new,restore=questListReentryFixture()
    addon.Context=function()return{level=60,completed=function()return nil end,active=function()return nil end}end
    ui:RefreshQuests()
    local row=ui.rows[1]
    assert(row.shown and row.enabled and row.questID==24001 and ui.engine:State(24001).status=="UNKNOWN")
    row.scripts.OnClick(row,"LeftButton",false)
    assert(ui.quest==24001 and ui.engine:State(24001).status=="UNKNOWN" and not ui.action)
    restore()
end)
check("All-character detail records the actual faction requirement without changing eligibility or guidance",function()
    local context,quest,dungeon,all=addon.Context,ui.quest,ui.dungeon,ui.includeUnavailable
    addon.Context=function()return{level=60,faction="Alliance",class="WARRIOR",race=1,completed=function()return false end,active=function()return false end}end
    addon.quests[25001]={id=25001,minLevel=1,requirementsKnown=true,factions={"Horde"},classes={"PALADIN"}}
    ui.dungeon={key="faction-detail",name="Faction detail",quests={25001},coverage="reviewed"}
    ui.includeUnavailable=true;ui.quest=25001;ui:Refresh()
    assert(ui.engine:State(25001).status=="UNAVAILABLE" and ui.engine:State(25001).reason=="faction")
    assert(detailIncludes(addon.L("FACTION_Horde"))and detailIncludes("PALADIN"))
    assert(not(ui.referenceToggle and ui.referenceToggle.shown))
    assert(detailIncludes(addon.L("FACTION_Horde")))
    assert(detailIncludes("PALADIN") and not ui.action and not hasDestination(false) and not hasDestination(true))
    addon.quests[25001]=nil;addon.Context=context
    ui.quest,ui.dungeon,ui.includeUnavailable=quest,dungeon,all;ui:Refresh()
end)
check("Faction detail labels localize deduplicated recorded audiences and clear on an unrestricted card",function()
    local quest,dungeon,locale=ui.quest,ui.dungeon,addon.db.locale
    addon.quests[25002]={id=25002,minLevel=1,requirementsKnown=true,factions={"Alliance","Horde","Neutral","Alliance"}}
    addon.quests[25003]={id=25003,minLevel=1,requirementsKnown=true}
    local context={level=60,faction="Alliance",class="WARRIOR",race=1,completed=function()return false end,active=function()return false end}
    for code in pairs(addon.locales)do
        addon.db.locale=code;showDetail(25002,context)
        local expected=table.concat({addon.L("FACTION_Alliance"),addon.L("FACTION_Horde"),addon.L("FACTION_Neutral")},", ")
        assert(detailIncludes(expected) and ui.engine:State(25002).status=="AVAILABLE")
        showDetail(25003,context)
        assert(not detailIncludes(expected) and ui.engine:State(25003).status=="AVAILABLE")
    end
    addon.db.locale=locale;addon.quests[25002],addon.quests[25003]=nil,nil
    ui.quest,ui.dungeon=quest,dungeon;ui:Refresh()
end)
local function giverPortraitFixture()
    local quest,dungeon=ui.quest,ui.dungeon
    local producer,journal,dialogue,setter=addon.GiverPortrait,addon.QuestPortrait,addon.DialoguePortrait,SetPortraitTextureFromCreatureDisplayID
    addon.quests[26001]={id=26001,minLevel=1,requirementsKnown=true,start={npcID=4001,creatureDisplayID=5001,name="Reference One",portraitSource="https://www.wowhead.com/forever/npc=4001"}}
    addon.quests[26002]={id=26002,minLevel=1,requirementsKnown=true,start={npcID=4002,creatureDisplayID=5002,name="Reference Two",portraitSource="https://www.wowhead.com/forever/npc=4002"}}
    -- Reference art is optional inside practical acquisition details. A listed
    -- completion-material source keeps this fixture on that presentation path
    -- without changing its start/finish identity or ordinary requirements.
    for _,id in ipairs({26001,26002})do addon.quests[id].completionQuests={{id=26003,itemID=7000}}end
    addon.GiverPortrait=function(place)return{npcID=place.npcID,displayID=place.creatureDisplayID,source=place.portraitSource,name=place.name}end
    addon.QuestPortrait,addon.DialoguePortrait=nil,nil
    SetPortraitTextureFromCreatureDisplayID=function(texture,id)texture:SetTexture("display:"..id)end
    return function()
        addon.GiverPortrait,addon.QuestPortrait,addon.DialoguePortrait,SetPortraitTextureFromCreatureDisplayID=producer,journal,dialogue,setter
        addon.quests[26001],addon.quests[26002]=nil,nil;ui.quest,ui.dungeon=quest,dungeon;ui:Refresh()
    end
end
check("Explicit sourced start NPC has its own measured reference portrait distinct from native journal artwork",function()
    local restore=giverPortraitFixture()
    addon.QuestPortrait=function()return{displayID=6001}end
    measurement=function(fs)if fs.text==addon.L("GIVER_REFERENCE_PORTRAIT","Reference One")then return 56 end;return 18 end
    showDetail(26001)
    assert(ui.portrait.shown and ui.portrait.texture=="display:6001")
    assert(ui:SetDetailTab("sources") and not ui.portrait.shown)
    assert(ui.giverPortrait~=ui.portrait and ui.giverPortrait.shown and ui.giverPortrait.texture=="display:5001")
    assert(ui.giverPortrait.width==64 and ui.giverPortrait.height==64 and not ui.giverPortrait.scripts.OnClick)
    assert(detailHas(addon.L("GIVER_REFERENCE_PORTRAIT","Reference One")))
    local caption
    for _,fs in ipairs(ui.details)do if fs.shown and fs.text==addon.L("GIVER_REFERENCE_PORTRAIT","Reference One")then caption=fs end end
    assert(caption and caption.measuredHeight==56 and -ui.giverPortrait.point[3]>=-caption.point[3]+56+8)
    assert(ui.detail:GetHeight() >= -ui.giverPortrait.point[3] + 64, "the source portrait fits its independently measured Sources content")
    local before=ui.engine:State(26001).status
    assert(before=="AVAILABLE" and ui.action and ui.action.id==26001)
    addon.DialoguePortrait=function()return{hidden=true,displayID=6002}end
    showSources(26001)
    assert(not ui.portrait.shown and ui.giverPortrait.shown and not detailHas(addon.L("QUEST_PORTRAIT")))
    measurement=nil;restore()
end)
check("Reference portraits recycle across quests and ten locales without using finish alternative item or object identities",function()
    local restore=giverPortraitFixture();local locale=addon.db.locale
    showSources(26001);local texture=ui.giverPortrait
    for code in pairs(addon.locales)do
        addon.db.locale=code;showSources(26001)
        assert(detailHas(addon.L("GIVER_REFERENCE_PORTRAIT","Reference One")) and ui.giverPortrait==texture)
    end
    local q=addon.quests[26001];local start=q.start
    q.finish,q.startAlternatives=start,{start}
    for _,value in ipairs({false,{itemID=10,dropNPCID=4001,creatureDisplayID=5001},{objectID=10,npcID=4001,creatureDisplayID=5001},{npcID=4001}})do
        q.start=value or nil;showSources(26001)
        assert(not texture.shown and texture.texture==nil and not detailHas(addon.L("GIVER_REFERENCE_PORTRAIT","Reference One")))
    end
    q.start=start;showSources(26001);assert(texture.shown)
    ui.quest=nil;ui:RefreshDetail();assert(not texture.shown and texture.texture==nil)
    addon.db.locale=locale;restore()
end)
check("Missing malformed restricted and throwing portrait capabilities omit the source image without changing quest state",function()
    local restore=giverPortraitFixture();local producer=addon.GiverPortrait
    showSources(26001);local texture=ui.giverPortrait
    for _,fn in ipairs({false,function()error("cold")end,function()return{npcID=4001,displayID="5001",source="wrong"}end})do
        addon.GiverPortrait=fn or nil;showSources(26001)
        assert(not texture.shown and texture.texture==nil and ui.engine:State(26001).status=="AVAILABLE")
    end
    addon.GiverPortrait=producer
    local checker=issecretvalue;local restricted={}
    issecretvalue=function(v)return v==restricted end
    addon.GiverPortrait=function()return{npcID=4001,displayID=restricted,source=addon.quests[26001].start.portraitSource}end
    showSources(26001);assert(not texture.shown)
    issecretvalue=checker;addon.GiverPortrait=producer
    SetPortraitTextureFromCreatureDisplayID=function(t)t:SetTexture("partial");error("no image")end
    showSources(26001);assert(not texture.shown and texture.texture==nil and not ui.portraitRenderBusy)
    SetPortraitTextureFromCreatureDisplayID=nil;showSources(26001);assert(not texture.shown)
    restore()
end)
check("Reentrant reference rendering cannot publish an older card or overwrite a newer same-card generation",function()
    local restore=giverPortraitFixture()
    for _,destination in ipairs({26002,26001})do
        showSources(26001)
        local armed=true
        SetPortraitTextureFromCreatureDisplayID=function(t,id)
            if armed then armed=false;showSources(destination)end
            t:SetTexture("old opaque:"..id)
        end
        ui:RefreshDetail()
        assert(not armed and ui.quest==destination and detailHas("Quest "..destination))
        assert(not ui.giverPortrait.shown and not ui.portraitRenderBusy)
        assert(not detailHas(addon.L("GIVER_REFERENCE_PORTRAIT","Reference One")))
        SetPortraitTextureFromCreatureDisplayID=function(t,id)t:SetTexture("recovered:"..id)end
        ui:RefreshDetail();assert(ui.giverPortrait.shown and ui.giverPortrait.texture=="recovered:"..(destination==26001 and 5001 or 5002))
    end
    restore()
end)
check("Source portrait metadata and helper changes during native rendering invalidate the old image and recover freshly",function()
    local restore=giverPortraitFixture();local q=addon.quests[26001];local producer=addon.GiverPortrait
    for _,mutate in ipairs({function()q.start.creatureDisplayID=5003 end,function()q.start.portraitSource=q.start.portraitSource.."/changed"end,
        function()addon.GiverPortrait=function(p)return producer(p)end end,function()q.start={npcID=4001}end})do
        q.start={npcID=4001,creatureDisplayID=5001,name="Reference One",portraitSource="https://www.wowhead.com/forever/npc=4001"};addon.GiverPortrait=producer
        local armed=true;SetPortraitTextureFromCreatureDisplayID=function(t,id)if armed then armed=false;mutate()end;t:SetTexture("opaque:"..id)end
        showSources(26001);assert(not armed and not ui.giverPortrait.shown)
        SetPortraitTextureFromCreatureDisplayID=function(t,id)t:SetTexture("fresh:"..id)end
        ui:RefreshDetail()
        assert(ui.giverPortrait.shown==(q.start.creatureDisplayID~=nil))
    end
    restore()
end)
check("Native journal portrait rendering also rejects reentrant old-card publication",function()
    local restore=giverPortraitFixture();addon.GiverPortrait=nil
    addon.QuestPortrait=function(id)return{displayID=id==26001 and 6001 or 6002}end
    local armed=true;SetPortraitTextureFromCreatureDisplayID=function(t,id)if armed then armed=false;showDetail(26002)end;t:SetTexture("opaque:"..id)end
    showDetail(26001)
    assert(ui.quest==26002 and not ui.portrait.shown and detailHas("Quest 26002") and not detailHas(addon.L("QUEST_PORTRAIT")))
    SetPortraitTextureFromCreatureDisplayID=function(t,id)t:SetTexture("fresh:"..id)end
    ui:RefreshDetail();assert(ui.portrait.shown and ui.portrait.texture=="fresh:6002")
    restore()
end)
check("Sourced kill objectives show known and unknown quantities separately from live quest-log progress",function()
    local objectives,itemName,giverPortrait=addon.QuestObjectives,addon.ItemName,addon.GiverPortrait
    local calls=0
    addon.quests[27001]={id=27001,minLevel=1,requirementsKnown=false,objectiveKills={
        {npcID=3001,name="Known target",quantity=6},{npcID=3002,name="Unknown target"}}}
    addon.QuestObjectives=function(id)assert(id==27001);calls=calls+1;return{{text="Native progress 1/9",finished=false}}end
    addon.ItemName=function()error("kill objective must not request item names")end
    addon.GiverPortrait=function()error("kill objective must not derive an NPC portrait")end
    showDetail(27001)
    assert(detailHas(addon.L("OBJECTIVE_KILLS")) and not detailHas(addon.L("OBJECTIVE_KILLS_NOTICE")))
    assert(detailHas(addon.L("OBJECTIVE_ITEM","Known target",6)) and detailHas(unknownObjective("Unknown target")))
    local live=false;for _,fs in ipairs(ui.details)do if fs.shown and fs.text:find("Native progress 1/9",1,true)then live=true end end
    assert(calls==1 and live and detailHas(addon.L("OBJECTIVE_PROGRESS")))
    assert(ui.engine:State(27001).status=="UNKNOWN" and not ui.action and not hasDestination(false) and not hasDestination(true))
    addon.QuestObjectives,addon.ItemName,addon.GiverPortrait=objectives,itemName,giverPortrait
    addon.quests[27001]=nil;showDetail(2)
    assert(not detailHas(addon.L("OBJECTIVE_KILLS")) and not detailHas(unknownObjective("Unknown target")))
end)
check("Kill objective counts remain explicit through known unknown locale and recycled-card changes",function()
    local locale=addon.db.locale
    local row={npcID=3003,name="Source creature"}
    addon.quests[27002]={id=27002,minLevel=1,requirementsKnown=true,objectiveKills={row}}
    for code in pairs(addon.locales)do
        addon.db.locale=code;showDetail(27002)
        assert(detailHas(unknownObjective(row.name)))
        row.quantity=2;ui:RefreshDetail()
        assert(detailHas(addon.L("OBJECTIVE_ITEM",row.name,2)) and not detailHas(unknownObjective(row.name)))
        row.quantity=nil;ui:RefreshDetail()
        assert(not detailHas(addon.L("OBJECTIVE_ITEM",row.name,2)) and ui.engine:State(27002).status=="AVAILABLE")
        addon.quests[27002].objectiveKills=nil;ui:RefreshDetail();assert(not detailHas(addon.L("OBJECTIVE_KILLS")))
        addon.quests[27002].objectiveKills={row}
    end
    addon.db.locale=locale;addon.quests[27002]=nil;showDetail(2)
end)
check("Malformed restricted duplicate and over-bound kill entries cannot become unknown objectives",function()
    local checker=issecretvalue;local restricted={}
    issecretvalue=function(value)return value==restricted end
    local q={id=27003,minLevel=1,requirementsKnown=false};addon.quests[27003]=q
    for _,entry in ipairs({{npcID=0,name="Invalid"},{npcID=4294967296,name="Invalid"},{npcID=1.5,name="Invalid"},
        {npcID="1",name="Invalid"},{npcID=3004},{npcID=3004,name=" "},{npcID=3004,name=string.rep("x",501)},
        {npcID=3004,name=restricted},{npcID=3004,name="Invalid",quantity=false},{npcID=3004,name="Invalid",quantity=0},
        {npcID=3004,name="Invalid",quantity=1.5},{npcID=3004,name="Invalid",quantity=restricted},
        {npcID=3004,name="Invalid",quantity=9007199254740992}})do
        q.objectiveKills={entry};showDetail(27003);assert(not detailHas(addon.L("OBJECTIVE_KILLS")))
    end
    q.objectiveKills={{npcID=3004,name="First"},{npcID=3004,name="Duplicate"}}
    for index=3,101 do q.objectiveKills[index]={npcID=3004+index,name="Target "..index}end
    showDetail(27003)
    assert(detailHas(unknownObjective("First")) and not detailHas(unknownObjective("Duplicate")))
    assert(detailHas(unknownObjective("Target 100")) and not detailHas(unknownObjective("Target 101")))
    issecretvalue=checker;addon.quests[27003]=nil;showDetail(2)
end)
check("Kill objective sanitization cannot continue an old card or generation after reentrant ownership changes",function()
    local checker=issecretvalue
    for _,sameQuest in ipairs({false,true})do
        local q={id=27004,minLevel=1,requirementsKnown=false,objectiveKills={{npcID=3005,name="Old kill target",quantity=3}}}
        addon.quests[27004]=q;local armed=true;local nestedHeight
        issecretvalue=function(value)
            if armed and value=="Old kill target"then
                armed=false
                if sameQuest then q.objectiveKills={{npcID=3006,name="Fresh kill target"}};ui:RefreshDetail()else showDetail(2)end
                nestedHeight=ui.detail.height
            end
            return false
        end
        showDetail(27004)
        assert(not armed and ui.detail.height==nestedHeight and not detailHas(addon.L("OBJECTIVE_ITEM","Old kill target",3)))
        if sameQuest then assert(detailHas(unknownObjective("Fresh kill target")))else assert(ui.quest==2 and not detailHas(addon.L("OBJECTIVE_KILLS")))end
        issecretvalue=checker;addon.quests[27004]=nil;showDetail(2)
    end
end)
check("Kill objective source names follow the explicit 500 UTF-8 byte budget across alphabets",function()
    local q={id=27005,minLevel=1,requirementsKnown=false};addon.quests[27005]=q
    for _,entry in ipairs({{name=string.rep("界",166),accepted=true},{name=string.rep("界",167),accepted=false},
        {name=string.rep("x",500),accepted=true},{name=string.rep("x",501),accepted=false}})do
        q.objectiveKills={{npcID=3010,name=entry.name,quantity=2}};showDetail(27005)
        assert(detailHas(addon.L("OBJECTIVE_KILLS"))==entry.accepted)
        assert(detailHas(addon.L("OBJECTIVE_ITEM",entry.name,2))==entry.accepted)
        assert(ui.engine:State(27005).status=="UNKNOWN" and not ui.action)
    end
    addon.quests[27005]=nil;showDetail(2)
end)
local function materialReentryFixture()
    local quest,dungeon=ui.quest,ui.dungeon
    local names,items,counts=addon.QuestName,addon.ItemName,addon.CarriedItemCount
    for _,id in ipairs({28001,28002,28003,28004})do addon.quests[id]={id=id,minLevel=1,requirementsKnown=true}end
    addon.quests[28001].completionQuests={{id=28002,itemID=4001}}
    addon.quests[28003].completionQuests={{id=28004,itemID=4002}}
    addon.ItemName=function(itemID)return"Item "..itemID end;addon.CarriedItemCount=function()return 0 end
    return function()
        addon.QuestName,addon.ItemName,addon.CarriedItemCount=names,items,counts
        for _,id in ipairs({28001,28002,28003,28004})do addon.quests[id]=nil end
        ui.quest,ui.dungeon=quest,dungeon;ui:Refresh()
    end
end
check("Material hydration preserves the replacement card's visible row and actual native-style inspect click",function()
    local restore=materialReentryFixture()
    for _,helper in ipairs({"ItemName","CarriedItemCount","QuestName"})do
        local original=addon[helper];local armed=true
        addon[helper]=function(value)
            if armed and value==(helper=="QuestName"and 28002 or 4001)then armed=false;ui:InspectQuest(28003);assert(ui:SetDetailTab("sources"))end
            return original(value)
        end
        showSources(28001)
        local row=ui.materialButtons[1]
        assert(not armed and ui.quest==28003 and row.questID==28004 and row.title.text=="Quest 28004")
        local freshNote=row.note.text:find("Item 4002",1,true) and not row.note.text:find("Item 4001",1,true)
        row.scripts.OnClick(row,"LeftButton",false);assert(ui.quest==28004,"material click must inspect the visible new target")
        assert(freshNote)
        assert(ui:BackQuest() and ui.quest==28003)
        addon[helper]=original
    end
    restore()
end)
check("Same-card material hydration supersession and CompletionSteps reentry abort only the old renderer",function()
    local restore=materialReentryFixture()
    for _,helper in ipairs({"CompletionSteps","ItemName","CarriedItemCount"})do
        addon.quests[28001].completionQuests={{id=28002,itemID=4001}}
        showSources(28001)
        local owner=helper=="CompletionSteps"and ui.engine or addon
        local original=owner[helper];local armed=true;local nestedHeight
        owner[helper]=function(...)
            local result=original(...)
            if armed then
                armed=false;addon.quests[28001].completionQuests={{id=28004,itemID=4002}};ui:RefreshDetail();nestedHeight=ui.detail.height
            end
            return result
        end
        ui:RefreshDetail();assert(not armed and ui.quest==28001 and ui.detail.height==nestedHeight)
        local row=ui.materialButtons[1];assert(row.questID==28004 and row.note.text:find("Item 4002",1,true))
        row.scripts.OnClick(row,"LeftButton",false);assert(ui.quest==28004)
        owner[helper]=original
    end
    restore()
end)
check("Captured material inspect callbacks reject redraw character and source ownership changes",function()
    local restore=materialReentryFixture();showSources(28001)
    local stale=ui.materialButtons[1].scripts.OnClick;ui:RefreshDetail();stale();assert(ui.quest==28001)
    local character=addon.char;local callback=ui.materialButtons[1].scripts.OnClick
    addon.char={};callback();assert(ui.quest==28001);addon.char=character
    addon.quests[28001].completionQuests={{id=28004,itemID=4002}};callback();assert(ui.quest==28001)
    ui:RefreshDetail();ui.materialButtons[1].scripts.OnClick();assert(ui.quest==28004)
    restore()
end)
check("An old CurrentOffer result cannot label a newer quest or same-card generation as currently offered",function()
    local getter=addon.CurrentOffer
    for _,sameQuest in ipairs({false,true})do
        for _,id in ipairs({29001,29002})do addon.quests[id]={id=id,minLevel=1,requirementsKnown=false}end
        local armed=true;local nestedHeight
        addon.CurrentOffer=function(id)
            if armed and id==29001 then
                armed=false
                if sameQuest then ui:RefreshDetail()else ui:InspectQuest(29002)end
                nestedHeight=ui.detail.height
                return{offeredNow=true}
            end
        end
        showDetail(29001)
        assert(not armed and ui.quest==(sameQuest and 29001 or 29002) and not detailHas(addon.L("OFFERED_NOW")))
        assert(ui.detail.height==nestedHeight and not ui.action)
        addon.quests[29001],addon.quests[29002]=nil,nil
    end
    addon.CurrentOffer=getter;showDetail(2)
end)
local function objectivePresentationFixture()
    local icon,name,count=addon.ItemIcon,addon.ItemName,addon.CarriedItemCount
    local f=rewardPresentationFixture()
    addon.quests[9970].objectiveItems={{itemID=801,name="Source objective",quantity=6},{itemID=802,name="Unknown amount"}}
    addon.ItemIcon=function(id)return id+1000 end
    addon.ItemName=function(id)return"Objective "..id end
    addon.CarriedItemCount=function()return 0 end
    local finish=f.finish
    function f:finish()
        addon.ItemIcon,addon.ItemName,addon.CarriedItemCount=icon,name,count
        finish(self)
    end
    ui:RefreshDetail();return f
end
local function objectiveText(value)
    local result
    for _,fs in ipairs(ui.details)do if fs.shown and
        (fs.text==value or fs.text:sub(1,#value+#" · ")==value.." · ") then result=fs end end
    return result
end
check("Optional objective icons retain exact collection text unknown amounts carried zero and source-only tooltips",function()
    local f=objectivePresentationFixture()
    local first,second=ui.objectiveButtons[1],ui.objectiveButtons[2]
    local line=objectiveText(addon.L("OBJECTIVE_ITEM","Objective 801",6))
    assert(first.shown and first.width==24 and first.height==24 and first.icon.texture==1801 and second.icon.texture==1802)
    assert(line.width==ui.detail:GetWidth()-38 and line.point[2]==34 and detailHas(unknownObjective("Objective 802")))
    assert(detailHas(addon.L("ITEM_CARRIED",0)) and ui.engine:State(9970).status=="UNKNOWN" and not ui.action)
    local reads=0;addon.DialogueRewards=function()reads=reads+1;return{source="dialogue",hidden=true}end
    ui:RefreshDetail();assert(first.shown and not detailHas(addon.L("REWARD_HIDDEN")))
    local before=reads;first.scripts.OnEnter();assert(reads==before and f.tip.owner==first and f.tip.items[#f.tip.items]==801)
    first.scripts.OnLeave();assert(not f.tip.shown and not ui.objectiveTooltip)
    f:finish()
end)
check("Missing cold malformed or failing objective icons leave ordinary text and recycle the original width",function()
    local f=objectivePresentationFixture();local first=ui.objectiveButtons[1]
    local value=addon.L("OBJECTIVE_ITEM","Objective 801",6)
    for _,icon in ipairs({false,function()return nil end,function()return"Interface/Icons/no"end,function()return 0 end,
        function()return 4294967296 end,function()error("cold")end})do
        addon.ItemIcon=icon or nil;ui:RefreshDetail()
        local text=objectiveText(value);assert(text and text.width==ui.detail:GetWidth()-8 and text.point[2]==4 and not first.shown and not first.objectiveBinding)
    end
    addon.ItemIcon=function()return 1801 end
    local setter=first.icon.SetTexture
    for _,failure in ipairs({"false","throw"})do
        first.icon.SetTexture=function(self,texture)if texture then if failure=="throw"then error("no texture")end;return false end;return setter(self,texture)end
        ui:RefreshDetail();assert(not first.shown and objectiveText(value).width==ui.detail:GetWidth()-8 and not ui.rewardTextureBusy)
    end
    first.icon.SetTexture=setter;ui:RefreshDetail();assert(first.shown)
    local before=#ui.objectiveButtons;for n=1,20 do ui:RefreshDetail()end;assert(#ui.objectiveButtons==before)
    f:finish()
end)
check("Objective tooltip cold data source edits and recycled bindings never show or target stale items",function()
    local f=objectivePresentationFixture();local first=ui.objectiveButtons[1]
    f.tip.cold=true;first.scripts.OnEnter();assert(not f.tip.shown and not ui.objectiveTooltip)
    f.tip.cold=false;first.scripts.OnEnter();local oldEnter,oldLeave=first.scripts.OnEnter,first.scripts.OnLeave
    ui:RefreshDetail();first.scripts.OnEnter();local hides=f.tip.hides
    oldLeave();assert(ui.objectiveTooltip and f.tip.hides==hides)
    local count=#f.tip.items;oldEnter();assert(#f.tip.items==count)
    addon.quests[9970].objectiveItems[1].quantity=nil
    first.scripts.OnEnter();assert(#f.tip.items==count and not ui.objectiveTooltip)
    ui:RefreshDetail();first.scripts.OnEnter();assert(ui.objectiveTooltip)
    addon.quests[9970].objectiveItems={};first.scripts.OnEnter();assert(not ui.objectiveTooltip)
    f:finish()
end)
check("Objective reward and foreign tooltip owners survive unrelated old leaves and resets",function()
    local f=objectivePresentationFixture();local objective,reward=ui.objectiveButtons[1],ui.rewardButtons[1]
    objective.scripts.OnEnter();local objectiveLeave=objective.scripts.OnLeave
    reward.scripts.OnEnter();local hides=f.tip.hides;objectiveLeave();assert(f.tip.hides==hides and f.tip.owner==reward and ui.rewardTooltip)
    local rewardLeave=reward.scripts.OnLeave;objective.scripts.OnEnter();hides=f.tip.hides;rewardLeave()
    assert(f.tip.hides==hides and f.tip.owner==objective and ui.objectiveTooltip)
    f.tip.owner={foreign=true};f.tip.shown=true;ui:RefreshDetail()
    assert(f.tip.hides==hides and f.tip.shown and not ui.objectiveTooltip)
    objective.scripts.OnEnter();ui.frame:Hide();ui.frame.scripts.OnHide(ui.frame)
    assert(not f.tip.shown and not objective.shown and not ui.objectiveTooltip)
    ui.frame:Show();f:finish()
end)
check("Objective icon producer and texture reentry cannot publish old artwork or destroy a newer card",function()
    local f=objectivePresentationFixture();local first=ui.objectiveButtons[1]
    for _,boundary in ipairs({"producer","texture"})do
        for _,sameQuest in ipairs({false,true})do
            local armed=true;local nestedHeight
            addon.ItemIcon=function()
                if boundary=="producer"and armed then armed=false;if sameQuest then ui:RefreshDetail()else showDetail(9971)end;nestedHeight=ui.detail.height end
                return 1801
            end
            local setter=first.icon.SetTexture
            if boundary=="texture"then first.icon.SetTexture=function(self,value)
                if value and armed then armed=false;if sameQuest then ui:RefreshDetail()else showDetail(9971)end;nestedHeight=ui.detail.height end
                return setter(self,value)
            end end
            showDetail(9970);assert(not armed and ui.detail.height==nestedHeight and not ui.rewardTextureBusy)
            if not sameQuest then assert(ui.quest==9971 and not first.shown)
            elseif boundary=="texture"then assert(not first.shown)end
            first.icon.SetTexture=setter;addon.ItemIcon=function(id)return id+1000 end
            showDetail(9970);assert(first.shown and first.icon.texture==1801)
        end
    end
    f:finish()
end)
check("Reentrant objective tooltip owner item and hide calls preserve the newer source binding",function()
    local f=objectivePresentationFixture();local first,second=ui.objectiveButtons[1],ui.objectiveButtons[2]
    for _,boundary in ipairs({"owner","item","hide"})do
        ui:RefreshDetail()
        if boundary=="hide"then first.scripts.OnEnter()end
        local function supersede()
            f.ownerHook,f.itemHook,f.hideHook=nil,nil,nil
            second.scripts.OnEnter()
        end
        if boundary=="owner"then f.ownerHook=supersede
        elseif boundary=="item"then f.itemHook=supersede
        else f.hideHook=supersede end
        if boundary=="hide"then first.scripts.OnLeave()else first.scripts.OnEnter()end
        assert(ui.objectiveTooltip and ui.objectiveTooltip.button==second and f.tip.owner==second and f.tip.shown)
    end
    f:finish()
end)
check("Objective icons reject restricted file IDs and keep Lua-safe oversized source item IDs as truthful text only",function()
    local f=objectivePresentationFixture();local restricted={};local checker=issecretvalue
    issecretvalue=function(value)return value==restricted end
    addon.ItemIcon=function()return restricted end;ui:RefreshDetail()
    assert(not ui.objectiveButtons[1].shown and objectiveText(addon.L("OBJECTIVE_ITEM","Objective 801",6)).width==ui.detail:GetWidth()-8)
    issecretvalue=checker
    local calls=0;addon.ItemIcon=function()calls=calls+1;return 1801 end
    addon.quests[9970].objectiveItems={{itemID=9007199254740991,name="Oversized source ID"}}
    ui:RefreshDetail()
    assert(calls==0 and not ui.objectiveButtons[1].shown and detailHas(unknownObjective("Objective "..tostring(9007199254740991))))
    f:finish()
end)
check("Cross-kind tooltip cleanup never consumes a newer reentrant objective or reward hover",function()
    local f=objectivePresentationFixture()
    local objective,secondObjective=ui.objectiveButtons[1],ui.objectiveButtons[2]
    local reward,secondReward=ui.rewardButtons[1],ui.rewardButtons[2]
    objective.scripts.OnEnter()
    f.hideHook=function()f.hideHook=nil;secondObjective.scripts.OnEnter()end
    reward.scripts.OnEnter()
    assert(ui.objectiveTooltip and ui.objectiveTooltip.button==secondObjective and f.tip.owner==secondObjective and not ui.rewardTooltip)
    ui:RefreshDetail();reward.scripts.OnEnter()
    f.hideHook=function()f.hideHook=nil;secondReward.scripts.OnEnter()end
    objective.scripts.OnEnter()
    assert(ui.rewardTooltip and ui.rewardTooltip.button==secondReward and f.tip.owner==secondReward and not ui.objectiveTooltip)
    f:finish()
end)
check("Final objective binding validation rejects entry or quantity replacement during restriction cleaning",function()
    local f=objectivePresentationFixture();local first=ui.objectiveButtons[1]
    local setter,checker=first.icon.SetTexture,issecretvalue
    for _,change in ipairs({"entry","quantity"})do
        addon.quests[9970].objectiveItems={{itemID=801,name="Original",quantity=6}};local armed=false
        first.icon.SetTexture=function(self,value)if value then armed=true end;return setter(self,value)end
        issecretvalue=function(value)
            if armed and value==6 then
                armed=false
                if change=="entry"then addon.quests[9970].objectiveItems[1]={itemID=999,name="Replacement",quantity=6}
                else addon.quests[9970].objectiveItems[1].quantity=7 end
            end
            return false
        end
        ui:RefreshDetail();assert(not first.shown and not first.objectiveBinding)
        first.icon.SetTexture=setter;issecretvalue=checker;ui:RefreshDetail()
        assert(first.shown and first.objectiveBinding.id==(change=="entry"and 999 or 801))
    end
    first.icon.SetTexture=setter;issecretvalue=checker;f:finish()
end)
check("Quest-provided items remain a separate informational role with unknown quantity and neutral carried zero",function()
    local f=objectivePresentationFixture();local q=addon.quests[9970]
    q.objectiveItems=nil;q.providedItems={{itemID=801,name="Provided tool"}};f.data={source="dialogue",hidden=true}
    ui:RefreshDetail()
    assert(detailHas(addon.L("PROVIDED_ITEMS")) and not detailHas(addon.L("PROVIDED_ITEMS_NOTICE")))
    assert(not detailHas(addon.L("DETAIL_OBJECTIVES")) and detailHas(unknownObjective("Objective 801")))
    assert(detailHas(addon.L("ITEM_CARRIED",0)) and not detailHas(addon.L("OBJECTIVE_ITEM","Objective 801",1)))
    local button=ui.objectiveButtons[1]
    assert(button.shown and button.objectiveBinding.role=="provided" and button.objectiveBinding.sourceField=="providedItems")
    button.scripts.OnEnter();assert(f.tip.owner==button and f.tip.items[#f.tip.items]==801)
    assert(ui.engine:State(9970).status=="UNKNOWN" and not ui.action and not hasDestination(true))
    addon.CarriedItemCount=nil;ui:RefreshDetail()
    assert(detailHas(addon.L("PROVIDED_ITEMS")) and not detailHas(addon.L("ITEM_CARRIED",0)))
    f:finish()
end)
check("Identical item IDs in provided and objective roles keep separate source bindings and quantities",function()
    local f=objectivePresentationFixture();local q=addon.quests[9970]
    q.objectiveItems={{itemID=801,name="Objective source",quantity=6}};q.providedItems={{itemID=801,name="Provided source"}}
    ui:RefreshDetail();local objective,provided=ui.objectiveButtons[1],ui.objectiveButtons[2]
    assert(detailHas(addon.L("DETAIL_OBJECTIVES")) and detailHas(addon.L("PROVIDED_ITEMS")))
    assert(detailHas(addon.L("OBJECTIVE_ITEM","Objective 801",6)) and detailHas(unknownObjective("Objective 801")))
    assert(objective.objectiveBinding.role=="objective" and provided.objectiveBinding.role=="provided")
    assert(objective.objectiveBinding~=provided.objectiveBinding)
    provided.scripts.OnEnter();local oldLeave=provided.scripts.OnLeave;objective.scripts.OnEnter();local hides=f.tip.hides
    oldLeave();assert(f.tip.hides==hides and f.tip.owner==objective)
    q.providedItems={};provided.scripts.OnEnter();assert(f.tip.owner==objective)
    objective.scripts.OnEnter();assert(ui.objectiveTooltip and ui.objectiveTooltip.button==objective)
    assert(q.objectiveItems[1].quantity==6 and ui.engine:State(9970).status=="UNKNOWN")
    f:finish()
end)
check("Provided item labels translate independently and recycle known unknown and absent source data",function()
    local f=objectivePresentationFixture();local locale=addon.db.locale;local objectives=addon.QuestObjectives
    local q=addon.quests[9970];q.objectiveItems=nil;q.providedItems={{itemID=801,name="Provided source",quantity=2}}
    addon.QuestObjectives=function()return{{text="Actual native objective",finished=false}}end
    for code in pairs(addon.locales)do
        addon.db.locale=code;ui:RefreshDetail()
        assert(detailHas(addon.L("PROVIDED_ITEMS")) and detailHas(addon.L("OBJECTIVE_ITEM","Objective 801",2)))
        q.providedItems[1].quantity=nil;ui:RefreshDetail()
        assert(detailHas(unknownObjective("Objective 801")) and not detailHas(addon.L("OBJECTIVE_ITEM","Objective 801",2)))
        assert(detailHas(addon.L("OBJECTIVE_PROGRESS")))
        q.providedItems=nil;ui:RefreshDetail();assert(not detailHas(addon.L("PROVIDED_ITEMS")) and not ui.objectiveButtons[1].shown)
        q.providedItems={{itemID=801,name="Provided source",quantity=2}}
    end
    addon.db.locale=locale;addon.QuestObjectives=objectives;f:finish()
end)
check("Provided entries require their own valid source name uint32 identity and absent-only unknown quantity before native reads",function()
    local f=objectivePresentationFixture();local q=addon.quests[9970];q.objectiveItems=nil
    local checker=issecretvalue;local restricted={};issecretvalue=function(v)return v==restricted end
    local calls=0;addon.ItemName=function()calls=calls+1;return"Should not read"end
    addon.ItemIcon=function()calls=calls+1;return 1801 end;addon.CarriedItemCount=function()calls=calls+1;return 0 end
    for _,entry in ipairs({{itemID=801},{itemID=801,name=" "},{itemID=801,name=string.rep("x",501)},
        {itemID=801,name=restricted},{itemID=4294967296,name="Invalid"},{itemID=0,name="Invalid"},
        {itemID=801,name="Invalid",quantity=0},{itemID=801,name="Invalid",quantity=false},
        {itemID=801,name="Invalid",quantity=restricted}})do
        q.providedItems={entry};ui:RefreshDetail();assert(not detailHas(addon.L("PROVIDED_ITEMS")) and calls==0)
    end
    issecretvalue=checker;f:finish()
end)
check("Provided item hydration preserves newer cards and same-card generations without promoting the old source role",function()
    local f=objectivePresentationFixture();local q=addon.quests[9970];q.objectiveItems=nil
    for _,helper in ipairs({"ItemName","CarriedItemCount","ItemIcon"})do
        for _,sameQuest in ipairs({false,true})do
            q.providedItems={{itemID=801,name="Old provided",quantity=2}}
            local original=addon[helper];local armed=true;local nestedHeight
            addon[helper]=function(id)
                if armed and id==801 then
                    armed=false
                    if sameQuest then q.providedItems={{itemID=802,name="Fresh provided"}};ui:RefreshDetail()else showDetail(9971)end
                    nestedHeight=ui.detail.height
                end
                return original(id)
            end
            showDetail(9970);assert(not armed and ui.detail.height==nestedHeight)
            if sameQuest then assert(detailHas(unknownObjective("Objective 802")))
            else assert(ui.quest==9971 and not detailHas(addon.L("PROVIDED_ITEMS")))end
            assert(not detailHas(addon.L("OBJECTIVE_ITEM","Objective 801",2)))
            addon[helper]=original
        end
    end
    f:finish()
end)
check("Provided role and source names remain validated through the final native icon binding boundary",function()
    local f=objectivePresentationFixture();local q=addon.quests[9970];q.objectiveItems=nil
    q.providedItems={{itemID=801,name="Original provided",quantity=6}};ui:RefreshDetail()
    local button=ui.objectiveButtons[1];local checker=issecretvalue;local setter=button.icon.SetTexture;local armed=false
    button.icon.SetTexture=function(self,v)if v then armed=true end;return setter(self,v)end
    issecretvalue=function(v)if armed and v==6 then armed=false;q.providedItems[1].name="Replacement provided"end;return false end
    ui:RefreshDetail();assert(not button.shown and not button.objectiveBinding)
    button.icon.SetTexture=setter;issecretvalue=checker;ui:RefreshDetail();assert(button.shown)
    local binding=button.objectiveBinding;binding.role="objective";binding.sourceField="objectiveItems"
    local items=#f.tip.items;button.scripts.OnEnter();assert(#f.tip.items==items and not ui.objectiveTooltip)
    f:finish()
end)
check("Plain provided-item rows reject mandatory source changes after hydration even when no icon is available",function()
    local f=objectivePresentationFixture();local q=addon.quests[9970];q.objectiveItems=nil;addon.ItemIcon=nil
    local names,counts=addon.ItemName,addon.CarriedItemCount
    for _,helper in ipairs({"ItemName","CarriedItemCount"})do
        for _,mutation in ipairs({"name","entry","quantity","length"})do
            q.providedItems={{itemID=801,name="Supply",quantity=2}}
            local original=addon[helper];local armed=true
            addon[helper]=function(id)
                if armed and id==801 then
                    armed=false
                    if mutation=="name"then q.providedItems[1].name=" "
                    elseif mutation=="entry"then q.providedItems[1]={itemID=802,name="Replacement"}
                    elseif mutation=="quantity"then q.providedItems[1].quantity=3
                    else q.providedItems[2]={itemID=802,name="New supplied item"}end
                end
                return original(id)
            end
            ui:RefreshDetail()
            assert(not armed and not detailHas(addon.L("PROVIDED_ITEMS")))
            assert(not detailHas(addon.L("OBJECTIVE_ITEM","Objective 801",2)))
            addon[helper]=original
        end
    end
    addon.ItemName,addon.CarriedItemCount=names,counts;f:finish()
end)
local function starterPresentationFixture()
    local f=objectivePresentationFixture();local q=addon.quests[9970]
    q.objectiveItems=nil;q.providedItems=nil
    q.start={itemID=801,name="Source starter",itemClasses={"PALADIN"},itemMinLevel=10}
    ui:RefreshDetail();return f,q
end
check("Direct quest-starting items use a distinct optional icon and tooltip without quantity or item-use actions",function()
    local f,q=starterPresentationFixture();local button=ui.objectiveButtons[1]
    local text=""..addon.L("ITEM_STARTER","Objective 801")
    assert(detailHas(text) and objectiveText(text).width==ui.detail:GetWidth()-38 and button.shown and button.icon.texture==1801)
    assert(button.objectiveBinding.role=="starter" and button.objectiveBinding.sourceField=="start" and button.objectiveBinding.id==801)
    assert(not button.objectiveBinding.quantity and not button.scripts.OnClick)
    assert(not detailHas(addon.L("OBJECTIVE_ITEM","Objective 801",1)) and detailHas(addon.L("ITEM_CARRIED",0)))
    assert(ui:SetDetailTab("sources"))
    assert(detailHas(addon.L("ITEM_CLASSES","PALADIN")) and detailHas(addon.L("ITEM_MIN_LEVEL",10)))
    assert(not detailHas(addon.L("DETAIL_OBJECTIVES")) and not detailHas(addon.L("PROVIDED_ITEMS")))
    button.scripts.OnEnter();assert(f.tip.owner==button and f.tip.items[#f.tip.items]==801)
    assert(ui.engine:State(9970).status=="UNKNOWN" and not ui.action and q.start.itemID==801)
    f:finish()
end)
check("Cold missing invalid and failed starter icon capabilities retain the original starter line and carried zero",function()
    local f,q=starterPresentationFixture();local button=ui.objectiveButtons[1]
    local text=""..addon.L("ITEM_STARTER","Objective 801")
    for _,getter in ipairs({false,function()return nil end,function()return"asset"end,function()return 0 end,function()error("cold")end})do
        addon.ItemIcon=getter or nil;ui:RefreshDetail()
        assert(detailHas(text) and objectiveText(text).width==ui.detail:GetWidth()-8 and not button.shown and detailHas(addon.L("ITEM_CARRIED",0)))
    end
    addon.ItemIcon=function()return 1801 end;local setter=button.icon.SetTexture
    button.icon.SetTexture=function(self,value)if value then return false end;return setter(self,value)end
    ui:RefreshDetail();assert(not button.shown and objectiveText(text).width==ui.detail:GetWidth()-8)
    button.icon.SetTexture=setter;ui:RefreshDetail();assert(button.shown)
    local checker=issecretvalue;local restricted={};issecretvalue=function(v)return v==restricted end
    addon.ItemIcon=function()return restricted end;ui:RefreshDetail();assert(not button.shown and detailHas(text))
    issecretvalue=checker;f:finish()
end)
check("Starter icons never promote alternate finish NPC object or oversized source identities",function()
    local f,q=starterPresentationFixture();local button=ui.objectiveButtons[1];local original=q.start
    for _,start in ipairs({{npcID=4001,name="NPC"},{objectID=5001,name="Object"},{npcID=4001,itemID=801,name="Mixed NPC"},
        {objectID=5001,itemID=801,name="Mixed object"},false})do
        q.start=start or nil;q.finish={itemID=801,name="Finish item"};ui:RefreshDetail();assert(not button.shown)
    end
    q.start=nil;q.startAlternatives={{npcID=4001,name="Alternative"}};ui:RefreshDetail();assert(not button.shown)
    q.startAlternatives=nil;q.start={itemID=9007199254740991,name="Large source ID"}
    local calls=0;addon.ItemIcon=function()calls=calls+1;return 1801 end;ui:RefreshDetail()
    assert(calls==0 and not button.shown and detailHas(""..addon.L("ITEM_STARTER","Objective "..tostring(9007199254740991))))
    q.start=original;f:finish()
end)
check("Starter source changes during name count or icon hydration invalidate the old binding on plain fallback",function()
    local f,q=starterPresentationFixture();local originalStart=q.start
    for _,helper in ipairs({"ItemName","CarriedItemCount","ItemIcon"})do
        for _,mutation in ipairs({"id","table","role","helper"})do
            q.start=originalStart;q.start.itemID=801;q.start.npcID=nil
            local getter=addon[helper];local armed=true
            addon[helper]=function(id)
                if armed and id==801 then
                    armed=false
                    if mutation=="id"then q.start.itemID=802
                    elseif mutation=="table"then q.start={itemID=802,name="Replacement"}
                    elseif mutation=="role"then q.start.npcID=4001
                    else addon[helper]=function()return nil end end
                end
                return getter(id)
            end
            ui:RefreshDetail();assert(not armed and not ui.objectiveButtons[1].shown)
            addon[helper]=getter
        end
    end
    q.start=originalStart;q.start.itemID=801;q.start.npcID=nil
    addon.ItemIcon=nil;local names=addon.ItemName
    showDetail(9971)
    addon.ItemName=function(id)q.start={itemID=802,name="Plain replacement"};return names(id)end
    showDetail(9970);assert(not ui.objectiveButtons[1].shown)
    assert(not detailHas(""..addon.L("ITEM_STARTER","Objective 801")))
    addon.ItemName=names;f:finish()
end)
check("Starter hydration and texture reentry retain the new card or same-card generation and recover on refresh",function()
    local f,q=starterPresentationFixture();local button=ui.objectiveButtons[1]
    for _,boundary in ipairs({"ItemName","CarriedItemCount","ItemIcon","texture"})do
        for _,sameQuest in ipairs({false,true})do
            q.start={itemID=801,name="Old starter"};local armed=true;local nestedHeight
            local owner=boundary=="texture"and button.icon or addon
            local key=boundary=="texture"and"SetTexture"or boundary;local getter=owner[key]
            owner[key]=function(...)
                local value=boundary=="texture"and select(2,...)or(...)
                if armed and (boundary=="texture"and value or value==801)then
                    armed=false
                    if sameQuest then q.start={itemID=802,name="Fresh starter"};ui:RefreshDetail()else showDetail(9971)end
                    nestedHeight=ui.detail.height
                end
                return getter(...)
            end
            showDetail(9970);assert(not armed and ui.detail.height==nestedHeight and not ui.rewardTextureBusy)
            if not sameQuest then assert(ui.quest==9971 and not button.shown)
            else assert(detailHas(""..addon.L("ITEM_STARTER","Objective 802")))end
            owner[key]=getter;q.start={itemID=801,name="Recovered"};showDetail(9970)
            assert(button.shown and button.objectiveBinding.id==801)
        end
    end
    f:finish()
end)
check("Starter objective provided and reward hovers remain source-distinct and stale starter leaves preserve newer owners",function()
    local f,q=starterPresentationFixture()
    q.objectiveItems={{itemID=801,name="Goal",quantity=6}};q.providedItems={{itemID=801,name="Supplied"}};ui:RefreshDetail()
    local starter,objective,provided=ui.objectiveButtons[1],ui.objectiveButtons[2],ui.objectiveButtons[3]
    assert(starter.objectiveBinding.role=="starter" and objective.objectiveBinding.role=="objective" and provided.objectiveBinding.role=="provided")
    starter.scripts.OnEnter();local oldLeave,oldEnter=starter.scripts.OnLeave,starter.scripts.OnEnter
    objective.scripts.OnEnter();local hides=f.tip.hides;oldLeave();assert(f.tip.hides==hides and f.tip.owner==objective)
    provided.scripts.OnEnter();oldLeave();assert(f.tip.owner==provided)
    ui.rewardButtons[1].scripts.OnEnter();oldLeave();assert(f.tip.owner==ui.rewardButtons[1])
    q.start={itemID=802,name="Changed"};local count=#f.tip.items;oldEnter();assert(#f.tip.items==count)
    f.tip.owner={foreign=true};f.tip.shown=true;ui:RefreshDetail();assert(f.tip.shown)
    f:finish()
end)
check("Final starter source proof rejects item replacement during restriction cleaning after native texture assignment",function()
    local f,q=starterPresentationFixture();local button=ui.objectiveButtons[1]
    local setter,checker=button.icon.SetTexture,issecretvalue;local armed=false
    button.icon.SetTexture=function(self,value)if value then armed=true end;return setter(self,value)end
    issecretvalue=function(value)if armed and value==801 then armed=false;q.start.itemID=802 end;return false end
    ui:RefreshDetail();assert(not button.shown and not button.objectiveBinding)
    button.icon.SetTexture=setter;issecretvalue=checker;ui:RefreshDetail();assert(button.shown and button.objectiveBinding.id==802)
    f:finish()
end)
check("Real starter catalogue records show separate known acquisition routes or explicit unknown without inferred sources",function()
    local f,q=starterPresentationFixture();local real={}
    assert(loadfile("Database/Catalog.lua"))("DungeonPro",real)
    local dungeons,names=addon.dungeons,addon.ItemName
    addon.dungeons=real.dungeons;addon.ItemName=function()return nil end
    for _,qid in ipairs({4903,1100,6522,7761})do
        q.start=real.quests[qid].start;showDetail(9970)
        assert(detailHas(addon.L("START_ITEM_LOCATION_UNKNOWN"))==(qid==4903))
        assert(detailHas(""..addon.L("ITEM_STARTER",q.start.name)))
        assert(ui:SetDetailTab("sources"))
        assert(detailHas(addon.L("ITEM_ACQUISITION"))==(qid~=4903))
        assert(detailHas(addon.L("START_ITEM_LOCATION_UNKNOWN"))==(qid==4903))
        assert(detailHas(""..addon.L("ITEM_STARTER",q.start.name)))
        assert(ui.engine:State(9970).status=="UNKNOWN" and not ui.action)
        if qid==1100 then
            assert(detailHas(addon.L("CONTAINER_SOURCE")) and ui.containerButtons[1].shown)
            assert(ui.containerButtons[1].title.text==q.start.containerSource.name)
        elseif qid==7761 then
            assert(detailHas(addon.L("ITEM_DROP_SOURCE",q.start.dropName,addon.L("UNKNOWN_PLACE"))))
        elseif qid==6522 then
            local rfk;for _,d in ipairs(real.dungeons)do if d.key=="rfk"then rfk=d end end
            assert(detailHas(addon.L("ITEM_DROP_SOURCE",q.start.dropName,addon.DungeonName(rfk))))
        end
    end
    addon.dungeons,addon.ItemName=dungeons,names;f:finish()
end)
check("Acquisition sections translate recycle and reject empty source placeholders without labelling NPC starters",function()
    local f,q=starterPresentationFixture();local locale=addon.db.locale
    assert(ui:SetDetailTab("sources"))
    for code in pairs(addon.locales)do
        addon.db.locale=code;q.start={itemID=801,name="Starter",dropSources={}}
        ui:RefreshDetail();assert(not detailHas(addon.L("ITEM_ACQUISITION")) and detailHas(addon.L("START_ITEM_LOCATION_UNKNOWN")))
        q.start.dropSources={{name="No identity",locationName="Zone"},{npcID=1,name=" ",locationName="Zone"}}
        ui:RefreshDetail();assert(detailHas(addon.L("START_ITEM_LOCATION_UNKNOWN")))
        q.start.dropSources={{npcID=1,name="Source",locationName="Known zone"},{npcID=2,name="Other source",locationName="Other zone"}}
        ui:RefreshDetail();assert(not detailHas(addon.L("START_ITEM_LOCATION_UNKNOWN")))
        assert(detailHas(addon.L("ITEM_DROP_SOURCE","Source","Known zone")) and detailHas(addon.L("ITEM_DROP_SOURCE","Other source","Other zone")))
        q.start={npcID=1,name="Giver"};ui:RefreshDetail()
        assert(not detailHas(addon.L("ITEM_ACQUISITION")) and not detailHas(addon.L("START_ITEM_LOCATION_UNKNOWN")))
    end
    addon.db.locale=locale;f:finish()
end)
check("Acquisition container visits and reported points reject changed source destinations before redraw",function()
    local f,q=starterPresentationFixture();local nav=addon.Navigation;local visits,maps={},{}
    addon.Navigation={Start=function(a)visits[#visits+1]=a end,Map=function(p)maps[#maps+1]=p end}
    local container={objectID=19861,name="Journal",mapID=1441,x=30.7,y=24.4,
        reportedLocations={{mapID=1441,x=30.7,y=24.4},{mapID=1441,x=30.7,y=24.5}}}
    q.start.containerSource=container;assert(ui:SetDetailTab("sources"));ui:RefreshDetail()
    local click=ui.containerButtons[1].scripts.OnClick;click();assert(#visits==1 and visits[1].place==container)
    reportToggle("container:1").scripts.OnClick();local pointClick=reportRows()[2].scripts.OnClick
    pointClick();assert(#visits==2 and visits[2].place.y==24.5)
    container.reportedLocations[2].y=25;pointClick();assert(#visits==2)
    ui:RefreshDetail();click=ui.containerButtons[1].scripts.OnClick
    container.x=31;click();assert(#visits==2)
    container.x=nil;container.y=nil;container.reportedLocations=nil;ui:RefreshDetail()
    click=ui.containerButtons[1].scripts.OnClick;click();assert(#maps==1 and maps[1]==container and not maps[1].place)
    q.start.containerSource={objectID=19861,name="Replacement",mapID=1441};click();assert(#maps==1)
    ui:RefreshDetail();assert(ui.containerButtons[1].shown)
    q.start.containerSource=nil;ui:RefreshDetail()
    assert(not ui.containerButtons[1].shown and detailHas(addon.L("START_ITEM_LOCATION_UNKNOWN")))
    addon.Navigation=nav;f:finish()
end)
check("Acquisition label hydration cannot append old routes to a replacement card or same-card generation",function()
    local f,q=starterPresentationFixture();local names=addon.GiverName
    for _,same in ipairs({false,true})do
        q.start={itemID=801,name="Old starter",dropSources={{npcID=3,name="Old drop",locationName="Old zone"}}}
        local armed=true;local nestedHeight
        addon.GiverName=function(place)
            if armed and place.npcID==3 then
                armed=false
                if same then q.start={itemID=802,name="New starter"};ui:RefreshDetail()else showDetail(9971)end
                nestedHeight=ui.detail.height
            end
            return nil
        end
        showDetail(9970)
        assert(not armed and ui.detail.height==nestedHeight and not detailHas(addon.L("ITEM_DROP_SOURCE","Old drop","Old zone")))
        if same then assert(detailHas(addon.L("START_ITEM_LOCATION_UNKNOWN")))else assert(not detailHas(addon.L("ITEM_ACQUISITION")))end
    end
    addon.GiverName=names;f:finish()
end)
check("Acquisition source-list growth during hydration rejects the older staged route and stale point callbacks",function()
    local f,q=starterPresentationFixture();local names=addon.GiverName
    assert(ui:SetDetailTab("sources"))
    q.start={itemID=801,name="Starter",dropSources={{npcID=3,name="Old drop",locationName="Zone"}}}
    local armed=true
    addon.GiverName=function(place)
        if armed and place.npcID==3 then armed=false;q.start.dropSources[2]={npcID=4,name="Added drop",locationName="Zone"}end
    end
    ui:RefreshDetail();assert(not armed and not detailHas(addon.L("ITEM_DROP_SOURCE","Old drop","Zone")))
    addon.GiverName=names
    local container={objectID=5,name="Container",mapID=1,x=1,y=2,
        reportedLocations={{mapID=1,x=1,y=2},{mapID=1,x=1,y=3}}}
    q.start={itemID=801,name="Starter",containerSource=container};ui:RefreshDetail()
    local click=ui.containerButtons[1].scripts.OnClick;local nav,calls=addon.Navigation,0
    addon.Navigation={Start=function()calls=calls+1 end}
    container.reportedLocations[3]={mapID=1,x=1,y=4};click();assert(calls==0)
    addon.Navigation=nav;f:finish()
end)
check("Open browser refits on display and UI scale events without replacing reading or quest context",function()
    local width,height,shown=screenWidth,screenHeight,ui.frame.shown
    local refresh,refreshes=ui.Refresh,0;ui.Refresh=function()refreshes=refreshes+1 end
    local quest,dungeon,engine,history,char=ui.quest,ui.dungeon,ui.engine,ui.detailHistory,addon.char
    local position=addon.db.window;local x,y=position.x,position.y
    local generation,copyRevision=ui.rewardGeneration,ui.copyRevision
    ui.frame:Show();screenWidth,screenHeight=1920,1080;ui:Fit()
    ui.detailScroll:SetVerticalScroll(19);ui.questScroll:SetVerticalScroll(23)
    assert(ui.frame.events.DISPLAY_SIZE_CHANGED and ui.frame.events.UI_SCALE_CHANGED)
    local function emit(event)
        if ui.frame.events[event]then ui.frame.scripts.OnEvent(ui.frame,event)end
    end
    assert(ui.frame.scale==1)
    screenWidth,screenHeight=800,480;emit("DISPLAY_SIZE_CHANGED")
    assert(ui.frame.scale*1100<=800*.92+.001 and ui.frame.scale*700<=480*.92+.001)
    local maxX=math.max(0,(screenWidth/ui.frame.scale-1100)/2)
    local maxY=math.max(0,(screenHeight/ui.frame.scale-700)/2)
    assert(math.abs(ui.frame.point[4])<=maxX and math.abs(ui.frame.point[5])<=maxY)
    screenWidth,screenHeight=640,360;emit("UI_SCALE_CHANGED")
    assert(ui.frame.scale*1100<=640*.92+.001 and ui.frame.scale*700<=360*.92+.001)
    assert(refreshes==0 and ui.quest==quest and ui.dungeon==dungeon and ui.engine==engine and addon.char==char)
    assert(ui.detailHistory==history and ui.rewardGeneration==generation and ui.copyRevision==copyRevision)
    assert(ui.detailScroll.verticalScroll==19 and ui.questScroll.verticalScroll==23)
    assert(addon.db.window==position and position.x==x and position.y==y)
    ui.Refresh=refresh;screenWidth,screenHeight=width,height;ui:Fit();ui.frame:SetShown(shown)
end)
check("Hidden browser ignores resize events and reopens using current geometry without event hydration",function()
    local width,height,shown=screenWidth,screenHeight,ui.frame.shown
    local getWidth,getHeight,refresh=GetScreenWidth,GetScreenHeight,ui.Refresh
    local reads,refreshes=0,0
    GetScreenWidth=function()reads=reads+1;return screenWidth end
    GetScreenHeight=function()reads=reads+1;return screenHeight end
    ui.Refresh=function()refreshes=refreshes+1 end
    ui.frame:Hide();local scale,point=ui.frame.scale,ui.frame.point
    screenWidth,screenHeight=600,400
    ui.frame.scripts.OnEvent(ui.frame,"DISPLAY_SIZE_CHANGED")
    ui.frame.scripts.OnEvent(ui.frame,"UI_SCALE_CHANGED")
    assert(not ui.frame.shown and reads==0 and refreshes==0 and ui.frame.scale==scale and ui.frame.point==point)
    ui.frame:Show();ui.frame.scripts.OnShow(ui.frame)
    assert(reads==2 and refreshes==1 and ui.frame.scale*1100<=600*.92+.001)
    reads=0;ui.frame.scripts.OnEvent(ui.frame,"UNRELATED_EVENT");assert(reads==0 and refreshes==1)
    screenWidth,screenHeight=0,0;scale=ui.frame.scale
    ui.frame.scripts.OnEvent(ui.frame,"DISPLAY_SIZE_CHANGED");assert(ui.frame.scale==scale)
    GetScreenWidth,GetScreenHeight,ui.Refresh=getWidth,getHeight,refresh
    screenWidth,screenHeight=width,height;ui:Fit();ui.frame:SetShown(shown)
end)
check("Catalogue level and quest character filters retain distinct readable modes across every locale",function()
    local locale,range,all=addon.db.locale,ui.range,ui.includeUnavailable
    ui.frame:Show()
    for code in pairs(addon.locales)do
        addon.db.locale=code;ui.range=false;ui.includeUnavailable=true;ui:Refresh()
        assert(ui.rangeButton.filterLabelKey=="ALL" and not ui.rangeButton.filterSelected)
        assert(ui.characterButton.filterLabelKey=="FILTER_QUEST_ALL" and not ui.characterButton.filterSelected)
        ui.rangeButton.scripts.OnClick(ui.rangeButton);ui.characterButton.scripts.OnClick(ui.characterButton)
        assert(ui.range and not ui.includeUnavailable and addon.char.filters.range and not addon.char.filters.includeUnavailable)
        assert(ui.rangeButton.filterLabelKey=="RANGE" and ui.rangeButton.filterSelected)
        assert(ui.characterButton.filterLabelKey=="FILTER_QUEST_MINE" and ui.characterButton.filterSelected)
        assert(ui.rangeButton.text==addon.L("FILTER_LEVEL_CURRENT")and ui.rangeButton.width==160 and ui.rangeButton.height==32 and not ui.rangeButton.filterIcon)
        local control=ui.characterButton
        assert(control.text==""and control.width==100 and control.height==32 and control.filterCaption.text==addon.L("FILTER_QUEST_MINE"))
        assert(control.filterIcon.width==26 and control.filterIcon.height==26 and control.filterIcon.shown)
        assert(#control.filterList==0)
        ui.characterButton.scripts.OnClick();assert(ui.includeUnavailable and not control.filterIcon.shown and control.filterCaption.text==addon.L("FILTER_QUEST_ALL"))
        assert(#control.filterList==0 and control.filterCaption.point[4]==8 and control.filterCaption.width==84)
    end
    addon.db.locale,ui.range,ui.includeUnavailable=locale,range,all;ui:SaveFilters();ui:Refresh()
end)
check("Readable filter controls preserve fixed dimensions without native wrapping measurements",function()
    local saved={}
    for i,control in ipairs({ui.rangeButton,ui.characterButton})do
        saved[i]=rawget(control,"GetFontString");control.GetFontString=function()error("icon controls must not measure labels")end
    end
    ui:Refresh();ui:ApplyTheme()
    for i,control in ipairs({ui.rangeButton,ui.characterButton})do control.GetFontString=saved[i];assert(control.height==32)end
end)
check("Saved filter callbacks cannot mutate a hidden or replaced planner",function()
    local range,all,frame=ui.range,ui.includeUnavailable,ui.frame
    frame:Hide();ui.rangeButton.scripts.OnClick(ui.rangeButton);ui.characterButton.scripts.OnClick(ui.characterButton)
    assert(ui.range==range and ui.includeUnavailable==all)
    frame:Show();local control=ui.rangeButton;ui.rangeButton={};control.scripts.OnClick(control);ui.rangeButton=control
    assert(ui.range==range)
end)
local function mappedDropFixture()
    local f,q=starterPresentationFixture();local real={}
    assert(loadfile("Database/Catalog.lua"))("DungeonPro",real)
    q.start=real.quests[96391].start
    q.start.dropSources={
        {npcID=6124,name="Captain Beld",locationName="Dun Morogh",zoneName="Dun Morogh",mapID=1426,x=77.8,y=62.4,
            reportedLocations={{mapID=1426,x=77.8,y=62.4},{mapID=1426,x=77.8,y=62.6}}},
        {npcID=6123,name="Dark Iron Spy",locationName="Dun Morogh",zoneName="Dun Morogh",mapID=1426,x=76.4,y=61,
            reportedLocations={{mapID=1426,x=76.4,y=61},{mapID=1426,x=76.6,y=61.8},{mapID=1426,x=76.8,y=60},
                {mapID=1426,x=77.2,y=59},{mapID=1426,x=77.4,y=61.4},{mapID=1426,x=77.6,y=59},
                {mapID=1426,x=77.8,y=62.4},{mapID=1426,x=77.8,y=62.6},{mapID=1426,x=78,y=60},{mapID=1426,x=78,y=61.2}}}}
    ui.reportedExpanded["dropSource:1"],ui.reportedExpanded["dropSource:2"]=nil,nil
    assert(ui:SetDetailTab("sources"));ui:RefreshDetail();return f,q,q.start.dropSources
end
check("Known item-drop NPC locations retain both actual sources and all twelve explicit manual visit points",function()
    local f,q,drops=mappedDropFixture();local nav=addon.Navigation;local visits,maps={},{}
    addon.Navigation={Start=function(a)visits[#visits+1]=a end,Map=function(p)maps[#maps+1]=p end}
    assert(detailHas(addon.L("ITEM_DROP_LOCATIONS")) and #visits==0 and #maps==0)
    assert(ui.dropButtons~=ui.containerButtons and ui.dropButtons~=ui.startButtons)
    for i,drop in ipairs(drops)do
        assert(not detailHas(addon.L("ITEM_DROP_SOURCE",drop.name,"Dun Morogh")),"mapped drop button owns its row without a duplicate text row")
        local row=ui.dropButtons[i];assert(row.shown and row.enabled and row.title.text==drop.name)
        row.scripts.OnClick(row,"LeftButton",false)
        assert(visits[i].kind=="visit" and visits[i].place==drop and visits[i].place.npcID==drop.npcID)
    end
    reportToggle("dropSource:1").scripts.OnClick();reportToggle("dropSource:2").scripts.OnClick()
    local rows=reportRows();assert(#rows==12 and #visits==2)
    for i,row in ipairs(rows)do
        row.scripts.OnClick(row,"LeftButton",false)
        local parent=i<=2 and drops[1]or drops[2];local index=i<=2 and i or i-2;local point=parent.reportedLocations[index]
        local a=visits[#visits];assert(a.kind=="visit" and a.place.npcID==parent.npcID and a.place.mapID==1426)
        assert(a.place.x==point.x and a.place.y==point.y)
    end
    assert(#maps==0 and not ui.giverAction and not ui.action and ui.engine:State(9970).status=="UNKNOWN")
    addon.Navigation=nav;f:finish()
end)
check("Text-only drop sources stay ordinary while map-only and reported-only sources require explicit selection",function()
    local f,q,drops=mappedDropFixture();local nav=addon.Navigation;local visits,maps={},{}
    addon.Navigation={Start=function(a)visits[#visits+1]=a end,Map=function(p)maps[#maps+1]=p end}
    q.start.dropSources={{npcID=1,name="Text only",locationName="Dungeon"},
        {npcID=2,name="Map only",locationName="Zone",mapID=1426},
        {npcID=3,name="Reported only",locationName="Zone",reportedLocations={{mapID=1426,x=1,y=2},{mapID=1426,x=2,y=3}}}}
    ui:RefreshDetail();assert(detailHas(addon.L("ITEM_DROP_SOURCE","Text only","Dungeon")))
    assert(ui.dropButtons[1].title.text=="Map only" and ui.dropButtons[1].enabled)
    assert(ui.dropButtons[2].title.text=="Reported only" and not ui.dropButtons[2].enabled and not ui.dropButtons[2].scripts.OnClick)
    ui.dropButtons[1].scripts.OnClick();assert(#maps==1 and maps[1]==q.start.dropSources[2] and not maps[1].place and #visits==0)
    reportToggle("dropSource:2").scripts.OnClick();local rows=reportRows();rows[2].scripts.OnClick()
    assert(#visits==1 and visits[1].place.npcID==3 and visits[1].place.x==2)
    q.start.dropSources={{npcID=1,name="Text only",locationName="Dungeon"}};ui:RefreshDetail()
    assert(not detailHas(addon.L("ITEM_DROP_LOCATIONS")))
    for _,row in ipairs(ui.dropButtons)do assert(not row.shown and not row.enabled and not row.scripts.OnClick)end
    assert(not detailHas(addon.L("START_ITEM_LOCATION_UNKNOWN")))
    addon.Navigation=nav;f:finish()
end)
check("Mapped drop callbacks bind source lists entries and reported coordinates without promoting NPC or mixed starters",function()
    local f,q,drops=mappedDropFixture();local nav=addon.Navigation;local calls=0
    addon.Navigation={Start=function()calls=calls+1 end,Map=function()calls=calls+1 end}
    local click=ui.dropButtons[1].scripts.OnClick;drops[1].x=78;click();assert(calls==0)
    ui:RefreshDetail();click=ui.dropButtons[1].scripts.OnClick
    drops[3]={npcID=4,name="Extra",locationName="Zone"};click();assert(calls==0)
    drops[3]=nil;ui:RefreshDetail();click=ui.dropButtons[1].scripts.OnClick
    q.start.dropSources={drops[1],drops[2]};click();assert(calls==0)
    ui:RefreshDetail();reportToggle("dropSource:1").scripts.OnClick()
    local pointClick=reportRows()[1].scripts.OnClick
    drops[1].reportedLocations[1]={mapID=1426,x=79,y=64};pointClick();assert(calls==0)
    q.start={npcID=9,name="NPC",dropSources=drops};ui:RefreshDetail();assert(not detailHas(addon.L("ITEM_DROP_LOCATIONS")))
    q.start={itemID=801,name="Mixed",npcID=9,dropSources=drops};ui:RefreshDetail();assert(not detailHas(addon.L("ITEM_DROP_LOCATIONS")))
    addon.Navigation=nav;f:finish()
end)
check("Mapped source rows translate wrap and recycle without reusing starter or container actions",function()
    local f,q,drops=mappedDropFixture();local locale=addon.db.locale
    measurement=function(fs)return fs.text=="Captain Beld"and 72 or 18 end
    for code in pairs(addon.locales)do
        addon.db.locale=code;ui:RefreshDetail()
        assert(detailHas(addon.L("ITEM_DROP_LOCATIONS")) and ui.dropButtons[1].height==108)
        assert(ui.dropButtons[2].point[3]<ui.dropButtons[1].point[3]-ui.dropButtons[1].height)
        assert(not ui.giverAction and not ui.action and ui.engine:State(9970).status=="UNKNOWN")
    end
    local stale=ui.dropButtons[1].scripts.OnClick;showDetail(9971)
    for _,row in ipairs(ui.dropButtons)do assert(not row.shown and not row.enabled and not row.scripts.OnClick)end
    assert(not detailHas(addon.L("ITEM_DROP_LOCATIONS")))
    local nav,calls=addon.Navigation,0;addon.Navigation={Start=function()calls=calls+1 end,Map=function()calls=calls+1 end}
    stale();assert(calls==0)
    addon.Navigation=nav;addon.db.locale=locale;measurement=nil;f:finish()
end)
check("Drop map and name hydration preserve replacement cards and same-card source generations",function()
    local f,q,drops=mappedDropFixture();local names,map=addon.GiverName,C_Map
    for _,helper in ipairs({"name","map"})do
        for _,same in ipairs({false,true})do
            q.start={itemID=801,name="Old starter",dropSources={drops[1],drops[2]}}
            showSources(9970)
            local armed=true;local nestedHeight
            local function replace()
                if not armed then return end;armed=false
                if same then
                    q.start={itemID=802,name="New starter",dropSources={{npcID=8,name="New mapped source",locationName="New zone",mapID=2,x=8,y=9}}}
                    ui:RefreshDetail()
                else showDetail(9971)end
                nestedHeight=ui.detail.height
            end
            if helper=="name"then addon.GiverName=function(p)if p.npcID==6124 then replace()end end
            else C_Map={GetMapInfo=function(id)if id==1426 then replace()end;return{name="Zone"}end}end
            ui:RefreshDetail()
            assert(not armed and ui.detail.height==nestedHeight)
            if same then
                assert(ui.dropButtons[1].shown and ui.dropButtons[1].title.text=="New mapped source")
                local nav,captured=addon.Navigation;addon.Navigation={Start=function(a)captured=a end}
                ui.dropButtons[1].scripts.OnClick();assert(captured.place.npcID==8 and captured.place.x==8)
                addon.Navigation=nav
            else for _,row in ipairs(ui.dropButtons)do assert(not row.shown)end end
            addon.GiverName,C_Map=names,map
        end
    end
    f:finish()
end)
check("Mapped drop visits reject changed helper namespace character engine and source role until a fresh render",function()
    local f,q,drops=mappedDropFixture();local nav=addon.Navigation;local calls=0
    addon.Navigation={Start=function()calls=calls+1 end,Map=function()calls=calls+1 end}
    local baseMap=C_Map;C_Map={GetMapInfo=function()return{name="Fixture zone"}end}
    local originalMap,originalNames,character=C_Map,addon.GiverName,addon.char
    local originalGetter=originalMap.GetMapInfo
    for _,change in ipairs({"map","getter","name","character","engine","pointlist","sourceNPCrole"})do
        q.start={itemID=801,name="Starter",dropSources={drops[1],drops[2]}};ui:RefreshDetail()
        local click=ui.dropButtons[1].scripts.OnClick;local engine=ui.engine
        if change=="map"then C_Map={GetMapInfo=originalMap and originalMap.GetMapInfo}
        elseif change=="getter"then originalMap.GetMapInfo=function()return{name="New zone"}end
        elseif change=="name"then addon.GiverName=function()return"New native name"end
        elseif change=="character"then addon.char={}
        elseif change=="engine"then ui.engine={}
        elseif change=="pointlist"then drops[1].reportedLocations[#drops[1].reportedLocations+1]={mapID=1426,x=78,y=63}
        else drops[1].objectID=6124 end
        click();assert(calls==0,change)
        if change=="pointlist"then table.remove(drops[1].reportedLocations)end
        drops[1].objectID=nil;originalMap.GetMapInfo=originalGetter;C_Map,addon.GiverName,addon.char,ui.engine=originalMap,originalNames,character,engine
    end
    ui:RefreshDetail();ui.dropButtons[1].scripts.OnClick();assert(calls==1)
    addon.Navigation=nav;C_Map=baseMap;f:finish()
end)
check("Native drop-map getter supersession and invalid optional locations cannot publish an old manual route",function()
    local f,q,drops=mappedDropFixture();local map=C_Map;local armed=true
    C_Map={GetMapInfo=function()
        if armed then armed=false;C_Map.GetMapInfo=function()return{name="New getter"}end end
        return{name="Old getter"}
    end}
    ui:RefreshDetail();assert(not armed)
    for _,row in ipairs(ui.dropButtons)do assert(not row.shown)end
    ui:RefreshDetail();assert(ui.dropButtons[1].shown)
    C_Map=map;q.start={itemID=801,name="Starter",dropSources={
        {npcID=1,name="No client map",locationName="Known source region",mapID="1426"},
        {npcID=2,name="No map",locationName="Other source",mapID=0},
        {npcID=4294967296,name="Out of native identity range",locationName="Zone",mapID=1426}}}
    ui:RefreshDetail();assert(not detailHas(addon.L("ITEM_DROP_LOCATIONS")))
    assert(detailHas(addon.L("ITEM_DROP_SOURCE","No client map","Known source region")))
    assert(not ui.giverAction and not ui.action)
    f:finish()
end)
check("Each mapped source row publication boundary preserves a newer source note layout and actual visit callback",function()
    for _,boundary in ipairs({"title","note","enabled","script","measure","height","point"})do
        local f,q=mappedDropFixture();local row=ui.dropButtons[1]
        local target=(boundary=="title"or boundary=="measure")and row.title or boundary=="note"and row.note or row
        local key=({title="SetText",note="SetText",enabled="SetEnabled",script="SetScript",measure="GetStringHeight",height="SetHeight",point="SetPoint"})[boundary]
        local original,armed=target[key],true
        local replacement={npcID=8,name="New source",locationName="New source zone",zoneName="New source zone",mapID=1426,x=8,y=9}
        local nestedHeight,nestedPoint
        target[key]=function(self,...)
            local result=original(self,...);local value=(...);local superseded=false
            local publish=boundary~="enabled"and boundary~="script"or boundary=="enabled"and value==true or boundary=="script"and select(2,...)~=nil
            if armed and publish then
                superseded=true;armed=false;q.start.dropSources={replacement};ui:RefreshDetail()
                nestedHeight,nestedPoint=row.height,row.point
            end
            if boundary=="measure"and superseded then return 900 end
            return result
        end
        ui:RefreshDetail();target[key]=original
        assert(not armed and row.title.text=="New source",boundary)
        assert(row.note.text:find("8.0, 9.0",1,true),boundary.." retained an older source note")
        assert(row.height==nestedHeight and type(row.point)=="table"and type(nestedPoint)=="table",boundary.." overwrote newer layout")
        for key,value in next,row.point do assert(rawequal(rawget(nestedPoint,key),value),boundary.." retained a different native anchor argument")end
        for key,value in next,nestedPoint do assert(rawequal(rawget(row.point,key),value),boundary.." omitted a native anchor argument")end
        if boundary=="measure"then assert(row.height==59)end
        local nav,captured=addon.Navigation;addon.Navigation={Start=function(a)captured=a end}
        row.scripts.OnClick(row,"LeftButton",false)
        assert(captured and captured.place==replacement and captured.place.npcID==8 and captured.place.x==8,boundary.." overwrote newer click")
        addon.Navigation=nav;f:finish()
    end
end)
check("Reported source point publication and layout preserve the replacement source's explicit point callback",function()
    for _,boundary in ipairs({"title","note","enabled","script","measure","height","point"})do
        local f,q=mappedDropFixture();reportToggle("dropSource:1").scripts.OnClick()
        local row=reportRows()[1]
        local target=(boundary=="title"or boundary=="measure")and row.title or boundary=="note"and row.note or row
        local key=({title="SetText",note="SetText",enabled="SetEnabled",script="SetScript",measure="GetStringHeight",height="SetHeight",point="SetPoint"})[boundary]
        local original,armed=target[key],true;local nestedHeight,nestedPoint
        target[key]=function(self,...)
            local result=original(self,...);local value=(...);local superseded=false
            local publish=boundary~="enabled"and boundary~="script"or boundary=="enabled"and value==true or boundary=="script"and select(2,...)~=nil
            if armed and publish then
                superseded=true;armed=false;q.start.dropSources={{npcID=8,name="New source",locationName="New zone",zoneName="New zone",mapID=1426,x=8,y=9,
                    reportedLocations={{mapID=1426,x=8,y=9},{mapID=1426,x=8,y=10}}}}
                ui:RefreshDetail();nestedHeight,nestedPoint=row.height,row.point
            end
            if boundary=="measure"and superseded then return 900 end
            return result
        end
        ui:RefreshDetail();target[key]=original
        assert(not armed and row.title.text:find("8.0, 9.0",1,true),boundary)
        assert(row.height==nestedHeight and type(row.point)=="table"and type(nestedPoint)=="table",boundary.." overwrote newer point layout")
        for key,value in next,row.point do assert(rawequal(rawget(nestedPoint,key),value),boundary.." retained a different native anchor argument")end
        for key,value in next,nestedPoint do assert(rawequal(rawget(row.point,key),value),boundary.." omitted a native anchor argument")end
        if boundary=="measure"then assert(row.height==59)end
        local nav,captured=addon.Navigation;addon.Navigation={Start=function(a)captured=a end}
        row.scripts.OnClick(row,"LeftButton",false)
        assert(captured and captured.place.npcID==8 and captured.place.x==8 and captured.place.y==9,boundary.." retained a stale point click")
        addon.Navigation=nav;f:finish()
    end
end)
check("Description read reentry cannot publish an older narrative over a new quest or newer same-quest card",function()
    local f,q=starterPresentationFixture();local getter=addon.Description
    for _,same in ipairs({false,true})do
        local armed,nestedHeight=true
        addon.Description=function(id)
            if armed and id==9970 then
                armed=false
                if same then ui:RefreshDetail()else showStory(9971)end
                nestedHeight=ui.detail.height
                return"Old card narrative marker"
            end
            return"Fresh card narrative marker"
        end
        showStory(9970)
        assert(not armed and ui.quest==(same and 9970 or 9971) and ui.detail.height==nestedHeight)
        assert(detailHas("Fresh card narrative marker") and not detailHas("Old card narrative marker"))
        assert(ui.detailTab == "story" and ui.detailTabButtons.story.label.text == addon.L("TAB_STORY"))
    end
    addon.Description=getter;f:finish()
end)
check("Actual quest narrative occupies Story while missing-text guidance never becomes acquired prose",function()
    local f=starterPresentationFixture();local getter,locale=addon.Description,addon.db.locale
    for code in pairs(addon.locales)do
        addon.db.locale=code;addon.Description=function()return"Actual narrative paragraph"end;showStory(9970)
        assert(ui.detailTab == "story" and detailHas("Actual narrative paragraph"))
        assert(objectiveText("Actual narrative paragraph").fontSize==14)
        addon.Description=function()return addon.L("NO_TEXT")end;ui:RefreshDetail()
        assert(detailHas(addon.L("DETAIL_STORY_UNAVAILABLE")) and not detailHas(addon.L("NO_TEXT")) and not detailHas("Actual narrative paragraph"))
    end
    for _,missing in ipairs({false,function()return nil end,function()return" "end,function()return string.rep("x",30001)end,function()error("unavailable")end})do
        addon.Description=missing or nil;ui:RefreshDetail()
        assert(detailHas(addon.L("DETAIL_STORY_UNAVAILABLE")) and not detailHas(addon.L("NO_TEXT")))
    end
    addon.Description,addon.db.locale=getter,locale;f:finish()
end)
check("Narrative publication rejects changed helper character definition and restriction-checker ownership",function()
    local f,q=starterPresentationFixture();local getter,character,checker=addon.Description,addon.char,issecretvalue
    for _,change in ipairs({"helper","character","definition","checker"})do
        addon.quests[9970]=q
        local called=false
        addon.Description=function()
            called=true
            if change=="helper"then addon.Description=function()return"Replacement narrative"end
            elseif change=="character"then addon.char={}
            elseif change=="definition"then addon.quests[9970]={id=9970,minLevel=1,requirementsKnown=false}
            else issecretvalue=function()return false end end
            return"Unowned narrative marker"
        end
        showStory(9970);assert(called and not detailHas("Unowned narrative marker"),change)
        addon.char,issecretvalue,addon.quests[9970]=character,checker,q
    end
    addon.Description=getter;f:finish()
end)
check("Narrative heading does not merge dialogue objectives log counters or hidden reward state into quest text",function()
    local f=starterPresentationFixture()
    local getter,dialogue,objectives,rewards=addon.Description,addon.DialogueObjectiveText,addon.QuestObjectives,addon.DialogueRewards
    addon.Description=function()return"Narrative only"end
    addon.DialogueObjectiveText=function()return"Dialogue objective only"end
    addon.QuestObjectives=function()return{{text="Live counter 2/6",finished=false}}end
    addon.DialogueRewards=function()return{hidden=true,items={},choices={}}end
    ui:RefreshDetail()
    assert(not detailHas("Narrative only"), "Quest does not poll or mix story prose into practical goals")
    assert(detailHas(addon.L("OBJECTIVE_DIALOGUE")) and detailHas("Dialogue objective only"))
    assert(detailHas(addon.L("OBJECTIVE_PROGRESS")) and detailHas("|cff88bfffLive counter 2/6|r"))
    assert(not detailHas(addon.L("REWARD_HIDDEN")))
    assert(ui:SetDetailTab("story"))
    assert(detailHas("Narrative only") and not detailHas("Dialogue objective only") and not detailHas("|cff88bfffLive counter 2/6|r"))
    assert(not detailHas(addon.L("REWARD_HIDDEN")))
    addon.Description=function()return addon.L("NO_TEXT")end;ui:RefreshDetail()
    assert(detailHas(addon.L("DETAIL_STORY_UNAVAILABLE")) and not detailHas(addon.L("NO_TEXT")))
    assert(ui:SetDetailTab("quest"))
    assert(detailHas("Dialogue objective only") and detailHas("|cff88bfffLive counter 2/6|r"))
    addon.Description,addon.DialogueObjectiveText,addon.QuestObjectives,addon.DialogueRewards=getter,dialogue,objectives,rewards
    f:finish()
end)
local function questLogControlFixture()
    local f,q=starterPresentationFixture();local can,open=addon.CanOpenQuestLog,addon.OpenQuestLogQuest
    f.held,f.reads,f.opens=true,0,{}
    addon.CanOpenQuestLog=function(id)f.reads=f.reads+1;return id==9970 and f.held end
    addon.OpenQuestLogQuest=function(id)f.opens[#f.opens+1]=id;return true end
    local finish=f.finish
    function f:finish()addon.CanOpenQuestLog,addon.OpenQuestLogQuest=can,open;finish(self)end
    ui.frame:Show();ui:RefreshDetail();return f,q
end
check("Held quest-log control is explicit click-only and capability omission leaves no empty layout slot",function()
    local f,q=questLogControlFixture();local control=ui.questLogButton
    assert(control and control.shown and control.enabled and control.title==control.label and control.label.text==addon.L("OPEN_QUEST_LOG"))
    assert(#f.opens==0 and not control.scripts.OnEnter)
    local reads=f.reads;ui:RefreshDetail();assert(f.reads==reads+1 and #f.opens==0)
    local history,engine=ui.detailHistory,ui.engine
    control.scripts.OnClick(control,"LeftButton",false)
    assert(#f.opens==1 and f.opens[1]==9970 and ui.quest==9970 and ui.detailHistory==history and ui.engine==engine)
    local stale=control.scripts.OnClick;f.held=false;stale();assert(#f.opens==1)
    ui:RefreshDetail();local without=ui.detail.height
    assert(not control.shown and not control.enabled and not control.scripts.OnClick)
    for _,candidate in ipairs({false,function()return nil end,function()return"true"end,function()error("unavailable")end})do
        addon.CanOpenQuestLog=candidate or nil;ui:RefreshDetail()
        assert(not control.shown and ui.detail.height==without and #f.opens==1)
    end
    f:finish()
end)
check("Quest-log capability read reentry preserves a replacement card or a newer same-card omission",function()
    local f=questLogControlFixture();local can=addon.CanOpenQuestLog
    for _,same in ipairs({false,true})do
        local armed,nestedHeight=true
        addon.CanOpenQuestLog=function(id)
            if armed and id==9970 then
                armed=false
                if same then f.held=false;ui:RefreshDetail()else showDetail(9971)end
                nestedHeight=ui.detail.height
                return true
            end
            return can(id)
        end
        f.held=true;showDetail(9970)
        assert(not armed and ui.detail.height==nestedHeight and not ui.questLogButton.shown and #f.opens==0)
    end
    addon.CanOpenQuestLog=can;f:finish()
end)
check("Captured quest-log clicks reject changed card character engine helpers and restriction ownership",function()
    local f,q=questLogControlFixture();local can,open,character,checker=addon.CanOpenQuestLog,addon.OpenQuestLogQuest,addon.char,issecretvalue
    for _,change in ipairs({"character","engine","definition","can","open","checker","quest","dungeon"})do
        showDetail(9970);local click=ui.questLogButton.scripts.OnClick;local reads=f.reads
        local engine,dungeon=ui.engine,ui.dungeon
        if change=="character"then addon.char={}
        elseif change=="engine"then ui.engine={}
        elseif change=="definition"then addon.quests[9970]={id=9970}
        elseif change=="can"then addon.CanOpenQuestLog=function()return true end
        elseif change=="open"then addon.OpenQuestLogQuest=function()error("stale opener")end
        elseif change=="checker"then issecretvalue=function()return false end
        elseif change=="quest"then ui.quest=9971
        else ui.dungeon={}end
        click();assert(#f.opens==0 and f.reads==reads,change)
        addon.char,ui.engine,addon.quests[9970],addon.CanOpenQuestLog,addon.OpenQuestLogQuest,issecretvalue,ui.quest,ui.dungeon=
            character,engine,q,can,open,checker,9970,dungeon
    end
    ui:RefreshDetail();local old=ui.questLogButton.scripts.OnClick
    ui.frame:Hide();ui.frame.scripts.OnHide();assert(not ui.questLogButton.shown and not ui.questLogButton.scripts.OnClick)
    ui.frame:Show();ui.frame.scripts.OnShow();old();assert(#f.opens==0)
    ui.questLogButton.scripts.OnClick();assert(#f.opens==1 and f.opens[1]==9970)
    f:finish()
end)
check("Quest-log label measurement and native row writes cannot resurrect a superseded control",function()
    local f=questLogControlFixture();local control=ui.questLogButton
    for _,boundary in ipairs({"text","measure","height","script","show"})do
        f.held=true;ui:RefreshDetail()
        local target=(boundary=="text"or boundary=="measure")and control.label or control
        local key=({text="SetText",measure="GetStringHeight",height="SetHeight",script="SetScript",show="Show"})[boundary]
        local original,armed=target[key],true
        target[key]=function(self,...)
            local result=original(self,...)
            if armed and (boundary~="script"or select(2,...)~=nil)then
                armed=false;f.held=false;ui:RefreshDetail()
            end
            return result
        end
        ui:RefreshDetail();target[key]=original
        assert(not armed and not control.shown and not control.enabled and not control.scripts.OnClick,boundary)
        assert(#f.opens==0)
    end
    f.held=true;ui:RefreshDetail();local original,armed=control.Hide,true
    control.Hide=function(self)original(self);if armed then armed=false;ui:RefreshDetail()end end
    ui:RefreshDetail();control.Hide=original
    assert(not armed and control.shown and control.enabled and control.scripts.OnClick)
    control.scripts.OnClick();assert(#f.opens==1)
    f:finish()
end)
check("Quest-log control wraps localized labels in detail flow and preserves same-card reading history and actions",function()
    local f,q=questLogControlFixture();local locale=addon.db.locale
    local history=ui.detailHistory;local control=ui.questLogButton
    measurement=function(fs)return fs==control.label and 54 or 18 end
    for code in pairs(addon.locales)do
        addon.db.locale=code;ui:RefreshDetail()
        assert(control.label.text==addon.L("OPEN_QUEST_LOG") and control.label.fontSize==14 and control.width==ui.detail:GetWidth()-8 and control.height==64)
        local minimum=objectiveText(addon.L("DETAIL_MIN_LEVEL",q.minLevel))
        assert(-minimum.point[3]>=-control.point[3]+control.height+8)
        assert(control.point[2]==4 and ui.detailHistory==history and not ui.action and not ui.giverAction and #f.opens==0)
    end
    local offset=math.min(21,ui.detailScroll:GetVerticalScrollRange());ui.detailScroll:SetVerticalScroll(offset)
    ui:RefreshDetail();assert(ui.detailScroll.verticalScroll==offset)
    measurement=nil;addon.db.locale=locale;f:finish()
end)
check("Explicit quest-log click rechecks live capability ownership and dispatch failures remain quiet",function()
    local f=questLogControlFixture();local can,open=addon.CanOpenQuestLog,addon.OpenQuestLogQuest
    for _,same in ipairs({false,true})do
        local armed=false
        addon.CanOpenQuestLog=function(id)
            if armed and id==9970 then
                armed=false
                if same then ui:RefreshDetail()else showDetail(9971)end
                return true
            end
            return can(id)
        end
        showDetail(9970);local click=ui.questLogButton.scripts.OnClick;armed=true;click()
        assert(not armed and #f.opens==0)
        if same then assert(ui.questLogButton.shown)else assert(not ui.questLogButton.shown)end
    end
    addon.CanOpenQuestLog=can;addon.OpenQuestLogQuest=function()error("native panel unavailable")end
    showDetail(9970);local control=ui.questLogButton;local height=ui.detail.height
    control.scripts.OnClick();assert(control.shown and ui.quest==9970 and ui.detail.height==height and #f.opens==0)
    addon.OpenQuestLogQuest=open;f:finish()
end)
local function objectObjectivesFixture()
    local f=rewardPresentationFixture();local q=addon.quests[9970]
    local old={name=addon.ItemName,icon=addon.ItemIcon,count=addon.CarriedItemCount,objectives=addon.QuestObjectives,navigation=addon.Navigation}
    f.api={name=0,icon=0,count=0,navigation=0}
    addon.ItemName=function(id)f.api.name=f.api.name+1;return"Native item "..id end
    addon.ItemIcon=function(id)f.api.icon=f.api.icon+1;return id+1000 end
    addon.CarriedItemCount=function()f.api.count=f.api.count+1;return 0 end
    addon.QuestObjectives=function()return{{text="Native objective 0/1",finished=false}}end
    addon.Navigation={Start=function()f.api.navigation=f.api.navigation+1 end,Map=function()f.api.navigation=f.api.navigation+1 end}
    q.objectiveObjects={{objectID=176544,name="Remains of Eva Sarkhoff Burned"},{objectID=176545,name="Remains of Lucien Sarkhoff Burned"}}
    local finish=f.finish
    function f:finish()
        addon.ItemName,addon.ItemIcon,addon.CarriedItemCount,addon.QuestObjectives,addon.Navigation=old.name,old.icon,old.count,old.objectives,old.navigation
        finish(self)
    end
    ui:RefreshDetail();return f,q
end
check("Recorded object tasks keep unknown and known amounts separate from native progress and quest readiness",function()
    local f,q=objectObjectivesFixture()
    q.objectiveObjects[3]={objectID=11,name="Recorded object task",quantity=2};ui:RefreshDetail()
    assert(detailHas(addon.L("OBJECTIVE_OBJECTS")) and not detailHas(addon.L("OBJECTIVE_OBJECTS_NOTICE")))
    assert(detailHas(unknownObjective("Remains of Eva Sarkhoff Burned")))
    assert(detailHas(unknownObjective("Remains of Lucien Sarkhoff Burned")))
    assert(detailHas(addon.L("OBJECTIVE_ITEM","Recorded object task",2)))
    assert(detailHas(addon.L("OBJECTIVE_PROGRESS")) and detailHas("|cff88bfffNative objective 0/1|r"))
    assert(not detailHas(addon.L("OBJECTIVE_ITEM","Remains of Eva Sarkhoff Burned",1)))
    assert(q.objectiveObjects[1].quantity==nil and f.api.name==0 and f.api.icon==0 and f.api.count==0 and f.api.navigation==0)
    assert(ui.engine:State(9970).status=="UNKNOWN" and not ui.action and not ui.giverAction)
    f:finish()
end)
check("Object tasks translate recycle and distinguish absent quantities from known amounts without empty sections",function()
    local f,q=objectObjectivesFixture();local locale=addon.db.locale
    for code in pairs(addon.locales)do
        addon.db.locale=code;q.objectiveObjects={{objectID=1,name="Burned archive",quantity=2}};ui:RefreshDetail()
        assert(detailHas(addon.L("OBJECTIVE_OBJECTS")) and detailHas(addon.L("OBJECTIVE_ITEM","Burned archive",2)))
        q.objectiveObjects[1].quantity=nil;ui:RefreshDetail()
        assert(detailHas(unknownObjective("Burned archive")) and not detailHas(addon.L("OBJECTIVE_ITEM","Burned archive",2)))
        q.objectiveObjects=nil;ui:RefreshDetail();assert(not detailHas(addon.L("OBJECTIVE_OBJECTS")))
        assert(detailHas("|cff88bfffNative objective 0/1|r"))
    end
    q.objectiveObjects={{objectID=1,name="Old object"}};ui:RefreshDetail();showDetail(9971)
    assert(not detailHas(addon.L("OBJECTIVE_OBJECTS")) and not detailHas(unknownObjective("Old object")))
    addon.db.locale=locale;f:finish()
end)
check("Malformed object tasks and present invalid quantities cannot become unknown collection goals",function()
    local f,q=objectObjectivesFixture();local checker=issecretvalue;local secret={}
    issecretvalue=function(v)return v==secret end
    for _,entry in ipairs({{npcID=1,name="Wrong role"},{itemID=1,name="Wrong role"},
        {objectID=1,npcID=1,name="Mixed role"},{objectID=1,itemID=1,name="Mixed role"},
        {objectID=0,name="Bad ID"},{objectID=-1,name="Bad ID"},{objectID=1.5,name="Bad ID"},
        {objectID=4294967296,name="Bad ID"},{objectID="1",name="Bad ID"},{objectID=secret,name="Secret ID"},
        {objectID=1},{objectID=1,name=" "},{objectID=1,name=secret}})do
        q.objectiveObjects={entry};ui:RefreshDetail();assert(not detailHas(addon.L("OBJECTIVE_OBJECTS")))
    end
    for _,quantity in ipairs({false,true,0,-1,1.5,"2",{},secret,math.huge,0/0,9007199254740992})do
        q.objectiveObjects={{objectID=1,name="Invalid amount",quantity=quantity}};ui:RefreshDetail()
        assert(not detailHas(addon.L("OBJECTIVE_OBJECTS")) and not detailHas(unknownObjective("Invalid amount")))
    end
    for _,list in ipairs({false,"invalid",{}, {false}})do q.objectiveObjects=list;ui:RefreshDetail();assert(not detailHas(addon.L("OBJECTIVE_OBJECTS")))end
    q.objectiveObjects={};for index=1,101 do q.objectiveObjects[index]={objectID=index,name="Over bound"}end
    ui:RefreshDetail();assert(not detailHas(addon.L("OBJECTIVE_OBJECTS")))
    issecretvalue=checker;f:finish()
end)
check("Object task names retain the 500 UTF-8 byte budget and identities deduplicate within their own role",function()
    local f,q=objectObjectivesFixture()
    for _,sample in ipairs({{string.rep("界",166),true},{string.rep("界",167),false},{string.rep("a",500),true},{string.rep("a",501),false}})do
        q.objectiveObjects={{objectID=4294967295,name=sample[1],quantity=9007199254740991}};ui:RefreshDetail()
        assert(detailHas(addon.L("OBJECTIVE_OBJECTS"))==sample[2])
        assert(detailHas(addon.L("OBJECTIVE_ITEM",sample[1],9007199254740991))==sample[2])
    end
    q.objectiveObjects={{objectID=1,name="First task"},{objectID=1,name="Duplicate task"}};ui:RefreshDetail()
    assert(detailHas(unknownObjective("First task")) and not detailHas(unknownObjective("Duplicate task")))
    f:finish()
end)
check("Object sanitization cannot publish an older card or newer same-card source generation",function()
    local f,q=objectObjectivesFixture();local checker=issecretvalue
    for _,same in ipairs({false,true})do
        q.objectiveObjects={{objectID=123456789,name="Old staged task",quantity=6}};local armed,nestedHeight=true
        issecretvalue=function(v)
            if armed and v==123456789 then
                armed=false
                if same then q.objectiveObjects={{objectID=8,name="Fresh task"}};ui:RefreshDetail()else showDetail(9971)end
                nestedHeight=ui.detail.height
            end
            return false
        end
        showDetail(9970);assert(not armed and ui.detail.height==nestedHeight)
        assert(not detailHas(addon.L("OBJECTIVE_ITEM","Old staged task",6)))
        if same then assert(detailHas(unknownObjective("Fresh task")))else assert(not detailHas(addon.L("OBJECTIVE_OBJECTS")))end
    end
    issecretvalue=checker;f:finish()
end)
check("Final object entry proof rejects source replacement during quantity cleaning and never reads item APIs for object IDs",function()
    local f,q=objectObjectivesFixture();local checker=issecretvalue
    q.objectiveObjects={{objectID=7,name="Old entry",quantity=6}};local armed=true
    issecretvalue=function(v)
        if armed and v==6 then armed=false;q.objectiveObjects[1]={objectID=8,name="Replacement task"}end
        return false
    end
    ui:RefreshDetail();assert(not armed and not detailHas(addon.L("OBJECTIVE_ITEM","Old entry",6)))
    issecretvalue=checker;ui:RefreshDetail();assert(detailHas(unknownObjective("Replacement task")))
    q.objectiveObjects={{objectID=777,name="Burn object"}}
    q.objectiveKills={{npcID=777,name="Defeat NPC",quantity=2}}
    q.objectiveItems={{itemID=777,name="Collect item",quantity=3}}
    f.api.name,f.api.icon,f.api.count=0,0,0;ui:RefreshDetail()
    assert(detailHas(unknownObjective("Burn object")) and detailHas(addon.L("OBJECTIVE_ITEM","Defeat NPC",2)))
    assert(detailHas(addon.L("OBJECTIVE_ITEM","Native item 777",3)) and detailHas(addon.L("ITEM_CARRIED",0)))
    assert(f.api.name==1 and f.api.icon==1 and f.api.count==1 and f.api.navigation==0)
    assert(ui.engine:State(9970).status=="UNKNOWN" and q.objectiveObjects[1].quantity==nil)
    f:finish()
end)
local function visibleStory()
    local rows={};for _,row in ipairs(ui.rows)do if row.shown and row.questTreeNode and row.questID then rows[#rows+1]=row end end
    return rows
end
local function storyCollapseFixture(actualID)
    local f=rewardPresentationFixture();local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    local q=addon.quests[9970];local record=actual.quests[actualID or 8950]
    q.storyline,q.storylineGroups=record.storyline,record.storylineGroups
    q.objectiveKills={{npcID=42,name="Visible independent goal"}}
    local oldDungeon,oldRoot,oldTree=ui.dungeon,ui.questTreeRoot,ui.questTreeDungeon
    ui.dungeon={key="middle-story",name="Story fixture",minLevel=1,maxLevel=60,quests={9970}}
    ui.questTreeRoot,ui.questTreeDungeon=nil,nil;ui:RefreshQuests();showDetail(9970)
    function f:expand()ui.questTreeRoot,ui.questTreeDungeon=9970,ui.dungeon;ui:RefreshQuests()end
    function f:collapse()ui.questTreeRoot,ui.questTreeDungeon=nil,nil;ui:RefreshQuests()end
    local finish=f.finish
    function f:finish()
        ui.dungeon,ui.questTreeRoot,ui.questTreeDungeon=oldDungeon,oldRoot,oldTree
        finish(self);ui:RefreshQuests()
    end
    return f,q
end
check("Actual grouped stories keep all24 source IDs in the middle tree without duplicating the right pane",function()
    local f,q=storyCollapseFixture(8950)
    assert(#visibleStory()==0 and not(ui.storyToggle and ui.storyToggle.shown))
    assert(detailHas(addon.L("REWARD_ITEM","Fixed reward",2)))
    local state,action=ui.engine:State(9970).status,ui.action
    f:expand();local rows=visibleStory();assert(#rows==25)
    local seen={};for _,row in ipairs(rows)do assert(not seen[row.questID]);seen[row.questID]=true end
    assert(seen[8926] and seen[8950] and seen[9970])
    assert(ui.engine:State(9970).status==state and not action)
    local click=rows[1].scripts.OnClick;f:collapse();click()
    assert(ui.quest==9970 and #visibleStory()==0,"collapsed hierarchy callbacks cannot inspect old rows")
    f:finish()
end)
check("Actual eleven-listed story traverses ancestors and keeps short and required-only trees distinct",function()
    local f,q=storyCollapseFixture(92819);local old=addon.quests[92742]
    addon.quests[92742]={id=92742,minLevel=1,requirementsKnown=false,requires={{ids={9971}}}}
    f:expand();local seen={};for _,row in ipairs(visibleStory())do seen[row.questID]=true end
    assert(seen[9971] and seen[92742] and seen[92819] and seen[9970])
    q.storyline,q.storylineGroups={9971,9970},nil;ui:RefreshQuests();assert(#visibleStory()==2)
    q.storyline,q.requires=nil,{{ids={9971}}};ui:RefreshQuests();assert(#visibleStory()==2)
    for _,row in ipairs(visibleStory())do if row.questID==9971 then assert(row.questTreeRelation=="required")end end
    addon.quests[92742]=old;f:finish()
end)
check("Middle source trees survive locale refreshes while replaced source and hidden callbacks expire",function()
    local f,q=storyCollapseFixture();local locale=addon.db.locale;f:expand()
    for code in pairs(addon.locales)do addon.db.locale=code;ui:RefreshQuests();assert(#visibleStory()==25)end
    local child=visibleStory()[1];local click=child.scripts.OnClick
    q.storylineGroups={unpack(q.storylineGroups)};ui:RefreshQuests();click();assert(ui.quest==9970)
    click=visibleStory()[1].scripts.OnClick;ui.frame:Hide();ui.frame.scripts.OnHide();click();assert(ui.quest==9970)
    ui.frame:Show();ui.frame.scripts.OnShow();assert(ui.quest==9970)
    addon.db.locale=locale;f:finish()
end)
check("Middle stories deduplicate exact IDs while prerequisites and completion materials stay independent",function()
    local f,q=storyCollapseFixture();q.storylineGroups={{9971,9971},{41,42,43,44},{9970}}
    q.requires={{ids={9971}}};q.completionQuests={{id=9971,itemID=555}}
    f:expand();showSources(9970)
    assert(#visibleStory()==6 and ui.materialButtons[1].shown)
    local count=0;for _,row in ipairs(visibleStory())do if row.questID==9971 then count=count+1;assert(row.questTreeRelation=="required")end end
    assert(count==1)
    local click=visibleStory()[1].scripts.OnClick;q.storylineGroups[2][1]=45;click();assert(ui.quest==9970)
    ui:RefreshQuests();assert(#visibleStory()==6);f:finish()
end)
check("Middle story title hydration and native setters preserve a newer source publication",function()
    for _,same in ipairs({false,true})do
        local f,q=storyCollapseFixture();local getter=addon.QuestName;local armed=true
        addon.QuestName=function(id)
            if armed and id==8926 then
                armed=false
                if same then q.storylineGroups={{9971,9970}}
                else ui.questTreeRoot,ui.questTreeDungeon,ui.quest=nil,nil,9971 end
                ui:RefreshQuests();ui:RefreshDetail()
            end
            return getter(id)
        end
        f:expand();assert(not armed and ui.quest==(same and 9970 or 9971))
        assert(#visibleStory()==(same and 2 or 0));addon.QuestName=getter;f:finish()
    end
    local f,q=storyCollapseFixture();f:expand();local row=visibleStory()[1];local setter,armed=row.title.SetText,true
    row.title.SetText=function(self,value)setter(self,value);if armed then armed=false;q.storylineGroups={{9971,9970}};ui:RefreshQuests()end end
    ui:RefreshQuests();assert(not armed and #visibleStory()==2)
    row.title.SetText=setter;f:finish()
end)
check("Middle chain expansion changes only its own reading surface and never saves a disclosure preference",function()
    local f=storyCollapseFixture();local prefs=addon.char
    ui.detailScroll:SetVerticalScroll(37);local detailHeight=ui.detail.height
    f:expand();local expanded=ui.questList.height
    assert(ui.detailScroll.verticalScroll==37 and ui.detail.height==detailHeight)
    f:collapse();assert(ui.questList.height<expanded and ui.detailScroll.verticalScroll==37)
    assert(addon.char==prefs and addon.char.storyStates==nil);f:finish()
end)
check("Middle hierarchy stale clicks cannot overwrite a newer detail reader position or selected quest",function()
    local f=storyCollapseFixture();f:expand();local click=visibleStory()[1].scripts.OnClick
    showDetail(9971);ui.detailScroll:SetVerticalScroll(7);click()
    assert(ui.quest==9971 and ui.detailScroll.verticalScroll==7)
    f:finish()
end)
check("Middle story rows wrap locale labels and reject replaced character engine and relation ownership",function()
    local f,q=storyCollapseFixture();f:expand();local locale=addon.db.locale
    measurement=function()return 64 end
    for code in pairs(addon.locales)do addon.db.locale=code;ui:RefreshQuests();for _,row in ipairs(visibleStory())do assert(row.height>=76)end end
    measurement=nil;addon.db.locale=locale;ui:RefreshQuests()
    local click=visibleStory()[1].scripts.OnClick;local character,engine,checker=addon.char,ui.engine,issecretvalue
    addon.char={};click();assert(ui.quest==9970);addon.char=character
    ui.engine={};click();assert(ui.quest==9970);ui.engine=engine
    issecretvalue=function()return false end;click();assert(ui.quest==9970);issecretvalue=checker
    q.storylineGroups[1][#q.storylineGroups[1]+1]=9971;click();assert(ui.quest==9970)
    ui:RefreshQuests();assert(#visibleStory()==26);f:finish()
end)
local function targetSearchFixture()
    local f={dungeons=addon.dungeons,quests=addon.quests,dungeonName=addon.DungeonName,cached=addon.CachedQuestName,
        questName=addon.QuestName,search=ui.search,range=ui.range,dungeon=ui.dungeon,quest=ui.quest,
        locale=addon.db.locale,reads={},cachedNames={}}
    addon.quests={
        [31001]={id=31001,name="Source target",minLevel=1,requirementsKnown=false},
        [31002]={id=31002,name="Other source",minLevel=1,requirementsKnown=false},
        [31003]={id=31003,name="Support only",minLevel=1,requirementsKnown=false}}
    addon.dungeons={
        {key="target-a",name="Alpha dungeon",minLevel=10,maxLevel=30,quests={31001,31002,31001}},
        {key="target-b",name="Beta dungeon",minLevel=10,maxLevel=30,quests={31001}},
        {key="target-c",name="Gamma dungeon",minLevel=50,maxLevel=60,quests={}}}
    addon.DungeonName=function(d)return d.name end
    addon.CachedQuestName=function(id)f.reads[#f.reads+1]=id;return f.cachedNames[id] end
    addon.QuestName=function()error("Dungeon search must not request ordinary quest title hydration")end
    ui.range=false;ui.search="";ui:RefreshDungeons()
    function f:search(value)
        ui.searchBox:SetText(value);ui.searchBox.scripts.OnTextChanged(ui.searchBox)
    end
    function f:cards()
        local result={};for _,row in ipairs(ui.cards)do if row.shown then result[#result+1]=row end end;return result
    end
    function f:finish()
        addon.dungeons,addon.quests,addon.DungeonName,addon.CachedQuestName,addon.QuestName=self.dungeons,self.quests,self.dungeonName,self.cached,self.questName
        ui.search,ui.range,ui.dungeon,ui.quest=self.search,self.range,self.dungeon,self.quest
        addon.db.locale=self.locale;ui:RefreshDungeons()
    end
    return f
end
check("Dungeon search finds only listed target source names and keeps selected quest preparation reading and actions intact",function()
    local f=targetSearchFixture()
    local selected,quest,engine,action,history,offset=ui.dungeon,ui.quest,ui.engine,ui.action,ui.detailHistory,ui.detailScroll.verticalScroll
    f:search("SOURCE TARGET");local rows=f:cards()
    assert(#rows==2 and rows[1].matchQuestID==31001 and rows[2].matchQuestID==31001)
    assert(rows[1].note.text:find(addon.L("SEARCH_QUEST_MATCH","Source target"),1,true))
    assert(rows[1].note.text:find(addon.L("CATALOG_COMPACT_META",10,30,3),1,true) and rows[2].note.text:find(addon.L("CATALOG_COMPACT_META",10,30,1),1,true))
    assert(#f.reads<=1 and (#f.reads==0 or f.reads[1]==31001),"duplicate source matches need at most one request-free positive caption read")
    addon.dungeons[2].quests={};f.reads={};f:search("Other source");assert(#f:cards()==1 and #f.reads<=1 and (#f.reads==0 or f.reads[1]==31002),"canonical matching precedes any positive localized caption read")
    f:search("Support only");assert(#f:cards()==0 and ui.catalogNotice.shown)
    assert(ui.dungeon==selected and ui.quest==quest and ui.engine==engine and ui.action==action and ui.detailHistory==history and ui.detailScroll.verticalScroll==offset)
    f:finish()
end)
check("Cached target search uses Unicode literal names without loads and memoizes only within each refresh",function()
    local f=targetSearchFixture()
    for _,pair in ipairs({{"ЗАДАНИЕ В КОПЯХ","задание в копях"},{"Épreuve","épreuve"},{"Straße","STRASSE"},{"测试[100%]","[100%]"}})do
        f.cachedNames[31001]=pair[1];f.reads={};f:search(pair[2]);local rows=f:cards()
        assert(#rows==2 and rows[1].note.text:find(addon.L("SEARCH_QUEST_MATCH",pair[1]),1,true))
        local count=0;for _,id in ipairs(f.reads)do if id==31001 then count=count+1 end end;assert(count>=1 and count<=2,"localized discovery and owned caption reads stay bounded across parents")
    end
    f:search(".*");assert(#f:cards()==0)
    f.cachedNames[31001]="Épreuve";f:search("epreuve");assert(#f:cards()==0)
    f.cachedNames[31001]="Fresh available title";f:search("Fresh available");assert(#f:cards()==2)
    f.cachedNames[31001]=nil;ui:RefreshDungeons();assert(#f:cards()==0,"no persistent title memo")
    f:finish()
end)
check("Empty and direct dungeon matches avoid their own native target reads and missing capability retains source search",function()
    local f=targetSearchFixture();f.reads={};f:search("  ");assert(#f:cards()==3 and #f.reads==0)
    f.reads={};f:search("Alpha")
    for _,id in ipairs(f.reads)do assert(id~=31002,"matching Alpha skips its own private target")end
    assert(#f:cards()==1 and not f:cards()[1].matchQuestID)
    f.cachedNames[31001]="Alpha quest elsewhere";f:search("Alpha");assert(#f:cards()==2,"dungeon matches cannot suppress another dungeon's cached quest match")
    for _,getter in ipairs({false,function()error("missing")end,function()return {} end})do
        addon.CachedQuestName=getter;f:search("Source target");assert(#f:cards()==2)
        f:search("No match");assert(#f:cards()==0)
    end
    addon.CachedQuestName=nil;f:search("Source target");assert(#f:cards()==2)
    f:finish()
end)
check("Target match cues wrap dynamically across locales and recycle without changing existing dungeon filters",function()
    local f=targetSearchFixture();local long=string.rep("Long target ",20);addon.quests[31001].name=long
    measurement=function(fs)if fs.text and fs.text:find(long,1,true)then return 108 end;return 18 end
    for locale in pairs(addon.locales)do
        addon.db.locale=locale;f:search("Long target");local rows=f:cards()
        assert(#rows==2 and rows[1].height>=144 and -rows[2].point[3]>=-rows[1].point[3]+rows[1].height)
        assert(rows[1].title.width==rows[1]:GetWidth()-112 and rows[1].note.width==rows[1]:GetWidth()-112 and rows[1].note.text:find(addon.L("SEARCH_QUEST_MATCH",long),1,true))
    end
    measurement=nil;f:search("Alpha");local row=f:cards()[1]
    assert(not row.matchQuestID and not row.note.text:find(long,1,true) and row.height==76)
    ui.range=true;f:search("Gamma");assert(#f:cards()==0)
    ui.clearSearch.scripts.OnClick();assert(ui.search=="" and ui.range==true and #f:cards()==2)
    f:finish()
end)
check("Cached-title query hydration rejects older searches and source membership replacements before row publication",function()
    for _,kind in ipairs({"query","source","membership","character","locale","helper"})do
        local f=targetSearchFixture();local armed=true;local char=addon.char;local original=addon.CachedQuestName
        addon.CachedQuestName=function(id)
            if not armed then return original(id)end
            if armed then
                armed=false
                if kind=="query"then f:search("Gamma")
                elseif kind=="source"then addon.quests[31001].name="New source match";f:search("New source match")
                elseif kind=="membership"then addon.dungeons[1].quests={31002};f:search("Other source")
                elseif kind=="character"then addon.char={};f:search("Gamma")
                elseif kind=="locale"then addon.db.locale="ruRU";f:search("Gamma")
                else addon.CachedQuestName=original;f:search("Gamma")end
            end
            return "Old cached match"
        end
        f:search("Old cached");local rows=f:cards();assert(not armed,"cached-title mutation must actually fire")
        assert(#rows==(kind=="source" and 2 or 1) and not rows[1].note.text:find("Old cached match",1,true))
        if kind=="source"then assert(rows[1].matchQuestID==31001)
        elseif kind=="membership"then assert(rows[1].matchQuestID==31002)
        else assert(rows[1].title.text=="Gamma dungeon")end
        addon.char=char;f:finish()
    end
end)
check("Native target row writes measurements and old clicks cannot overwrite or select superseded search results",function()
    for _,kind in ipairs({"setter","measure"})do
        local f=targetSearchFixture();f:search("Source target");local row=f:cards()[1];local setter=row.note.SetText;local armed=true
        local oldClick=row.scripts.OnClick
        if kind=="setter"then
            row.note.SetText=function(self,value)setter(self,value);if armed then armed=false;f:search("Gamma")end end
        else
            measurement=function(fs)if fs==row.note and armed then armed=false;f:search("Gamma")end;return 18 end
        end
        f:search("Source target");assert(#f:cards()==1 and f:cards()[1].title.text=="Gamma dungeon")
        local dungeon=ui.dungeon;oldClick();assert(ui.dungeon==dungeon)
        row.note.SetText=setter;measurement=nil
        local current=f:cards()[1].scripts.OnClick;local char=addon.char;addon.char={};current();assert(ui.dungeon==dungeon);addon.char=char
        addon.QuestName=f.questName;current();assert(ui.dungeon.key=="target-c" and ui.quest==nil)
        f:finish()
    end
end)
check("Real catalogue target source search retains exact declared dungeon membership without loading supporting titles",function()
    local f=targetSearchFixture();local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    addon.dungeons,addon.quests=actual.dungeons,actual.quests;addon.CachedQuestName=nil
    for _,id in ipairs({166,5728,1654,8950})do
        local name=actual.quests[id].name
        f:search(name);local rows=f:cards();local expected=0
        for _,d in ipairs(actual.dungeons)do
            local dungeonMatch=addon.SearchFold(d.name):find(addon.SearchFold(name),1,true)
            local targetMatch=false
            for _,target in ipairs(d.quests)do
                if addon.SearchFold(actual.quests[target].name):find(addon.SearchFold(name),1,true)then targetMatch=true end
            end
            if dungeonMatch or targetMatch then expected=expected+1 end
        end
        assert(#rows==expected and expected>0)
        for _,row in ipairs(rows)do
            assert(row.matchQuestID)
            local member=false
            for _,d in ipairs(actual.dungeons)do if d.name==row.title.text then
                for _,target in ipairs(d.quests)do if target==row.matchQuestID then member=true end end
            end end
            assert(member,"only declared target IDs explain a quest-name result")
        end
    end
    assert(#f.reads==0);f:finish()
end)
local function detailSectionY(value)
    for _,fs in ipairs(ui.details)do if fs.shown and fs.text==value then return -fs.point[3] end end
end
check("All twelve source locations remain unique below compact giver and acquisition sections",function()
    local f=rewardPresentationFixture();local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    local q=addon.quests[9970];q.startAlternatives=actual.quests[2933].startAlternatives
    local nav=addon.Navigation;local calls=0;addon.Navigation={Start=function()calls=calls+1 end,Map=function()calls=calls+1 end}
    showDetail(9970)
    assert(detailHas(addon.L("REWARD_ITEM","Fixed reward",2)),"the practical reward stays on Quest")
    assert(ui:SetDetailTab("sources"));local seen={}
    for index=1,12 do local row=startButton(index);assert(row and row.shown and row.title.text==q.startAlternatives[index].name);assert(not seen[row]);seen[row]=true end
    assert(not ui.giverButtons[3]or not ui.giverButtons[3].shown)
    assert(ui.engine:State(9970).status=="UNKNOWN" and not ui.action and calls==0)
    assert(not detailHas(addon.L("NEXT")) and ui.detailTab=="sources")
    assert(not detailHas(addon.L("REWARD_ITEM","Fixed reward",2)),"Sources does not repeat the practical reward")
    addon.Navigation=nav;f:finish()
end)
check("Middle prerequisite inspection keeps source locations and explicit selected-quest guidance distinct",function()
    local restore=multiActionFixture();local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    addon.quests[20001].startAlternatives=actual.quests[2933].startAlternatives
    local calls={};addon.Navigation={Start=function(action)calls[#calls+1]=action end,Map=function(point)calls[#calls+1]=point end}
    ui:RefreshQuests();ui:RefreshDetail();local status=ui.engine:State(20001).status
    ui.giver.scripts.OnClick();dispatchGiverMap();assert(#calls==0)
    local row=actionTreeRow(20003);assert(row and row.shown);row.scripts.OnClick(row,"LeftButton",false)
    assert(ui.quest==20003 and #calls==0)
    assert(ui:BackQuest()and ui.quest==20001);assert(ui:SetDetailTab("sources"))
    assert(ui.engine:State(20001).status==status and startButton(12).shown)
    restore()
end)
check("Practical acquisition retains container and mapped drop visit controls without automatic guidance",function()
    local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    for _,id in ipairs({1100,96391})do
        local f,q=starterPresentationFixture();q.start=actual.quests[id].start
        local nav=addon.Navigation;local visits={};addon.Navigation={Start=function(a)visits[#visits+1]=a end,Map=function(p)visits[#visits+1]=p end}
        showSources(9970);assert(not(ui.referenceToggle and ui.referenceToggle.shown) and #visits==0 and not detailHas(addon.L("NEXT")))
        if id==1100 then local row=ui.containerButtons[1];assert(row.shown);row.scripts.OnClick();assert(#visits==1 and(visits[1].place or visits[1])==q.start.containerSource)
        else assert(ui.dropButtons[1].shown and ui.dropButtons[2].shown);ui.dropButtons[2].scripts.OnClick();assert(#visits==1 and visits[1].place==q.start.dropSources[2])end
        assert(ui.engine:State(9970).status=="UNKNOWN"and not ui.action)
        addon.Navigation=nav;f:finish()
    end
end)
check("Localized compact source locations retain unknown unavailable completed truth and recycle every control",function()
    local f=rewardPresentationFixture();local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    local q=addon.quests[9970];q.startAlternatives=actual.quests[2933].startAlternatives;local locale=addon.db.locale
    assert(ui:SetDetailTab("sources"))
    for code in pairs(addon.locales)do addon.db.locale=code;ui:RefreshDetail();assert(startButton(12).shown and ui.engine:State(9970).status=="UNKNOWN"and not ui.action)end
    q.factions={"Horde"};showSources(9970,{level=60,faction="Alliance",completed=function()return false end,active=function()return false end})
    assert(ui.engine:State(9970).status=="UNAVAILABLE"and not ui.action and not hasDestination(true)and startButton(12).shown)
    q.factions=nil;showDetail(9970,{level=60,completed=function(id)return id==9970 end,active=function()return false end});assert(ui.engine:State(9970).status=="COMPLETED"and not ui.action)
    showDetail(9971);for _,pool in ipairs({ui.giverButtons,ui.startButtons})do for _,row in ipairs(pool)do assert(not row.shown)end end
    addon.db.locale=locale;f:finish()
end)
check("Long middle prerequisite titles wrap and giver hydration cannot resurrect an obsolete selected quest",function()
    local restore=multiActionFixture();local getter=addon.QuestName
    addon.QuestName=function(id)if id==20002 then return string.rep("Long actual action name ",20)end;return getter(id)end
    measurement=function(fs)if fs.text and fs.text:find("Long actual action name",1,true)then return 90 end;return 18 end
    addon.quests[20001].start={mapID=91,x=1,y=2,name="Reference giver"}
    ui:RefreshQuests();ui:RefreshDetail();local row=actionTreeRow(20002);assert(row and row.height>=90)
    local maps=C_Map;local armed=true
    C_Map={GetMapInfo=function(id)if armed and id==91 then armed=false;ui:InspectQuest(20002)end;return{name="Native reference zone"}end}
    ui:RefreshDetail();assert(not armed and ui.quest==20002 and ui.action.id==20002)
    measurement=nil;addon.QuestName=getter;C_Map=maps;restore()
end)
local function singleDestinationFixture()
    local f=rewardPresentationFixture();local real={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",real)
    local saved={quests=addon.quests,name=addon.QuestName,maps=C_Map,nav=addon.Navigation}
    local copy={};for id,q in pairs(real.quests)do copy[id]=q end
    for _,id in ipairs({65,132,135,141,142,155,166})do
        local q={};for key,value in pairs(real.quests[id])do q[key]=value end;q.requirementsKnown=true;copy[id]=q
    end
    addon.quests=copy;addon.QuestName=function(id)return copy[id]and copy[id].name or saved.name(id)end
    C_Map={GetMapInfo=function(id)return{name=id==1433 and "Redridge Mountains" or "Westfall"}end}
    f.visits={};addon.Navigation={Start=function(a)f.visits[#f.visits+1]=a end,Map=function(p)f.visits[#f.visits+1]=p end}
    f.context={level=60,faction="Alliance",class="WARRIOR",race=1,completed=function()return false end,
        active=function(id)return id==65 end,ready=function(id)return id==65 end}
    showDetail(166,f.context)
    function f:restore()
        addon.quests,addon.QuestName,C_Map,addon.Navigation=saved.quests,saved.name,saved.maps,saved.nav
        self:finish()
    end
    return f,copy
end
local function destinationLine(prefix)
    for _,fs in ipairs(ui.details)do if fs.shown and fs.text:find(prefix,1,true)==1 then return fs end end
end
check("An ancestor turn-in stays distinct from the selected quest giver until explicitly inspected",function()
    local f,quests=singleDestinationFixture()
    assert(ui.action.id==65 and ui.action.kind=="turnin" and ui.action.place==quests[65].finish and #f.visits==0)
    assert(not destinationLine("Wiley the Black — Redridge Mountains") and destinationLine("Gryan Stoutmantle — Westfall"))
    ui.giver.scripts.OnClick();dispatchGiverMap()
    assert(f.visits[1].id==166 and f.visits[1].kind=="visit" and f.visits[1].place==quests[166].start and f.visits[2]==quests[166].start)
    assert(ui.engine:State(166).status=="LOCKED")
    showDetail(65,f.context);assert(detailIncludes("Wiley the Black")and detailIncludes("Redridge Mountains")and destinationLine("Gryan Stoutmantle"))
    f:restore()
end)
check("Selected turn-in metadata translates wraps and no unrelated prerequisite destinations are hydrated",function()
    local f,quests=singleDestinationFixture();local locale=addon.db.locale
    local long=string.rep("Long Wiley destination ",15);local old=quests[65].finish.name;quests[65].finish.name=long
    measurement=function(fs)if fs.text and fs.text:find(long,1,true)then return 88 end;return 18 end
    for code in pairs(addon.locales)do addon.db.locale=code;showDetail(65,f.context);assert(detailIncludes(long)and destinationLine("Gryan Stoutmantle"))end
    measurement=nil;quests[65].finish.name=old;addon.db.locale=locale;f:restore()
    local restore=multiActionFixture();assert(not detailIncludes("Giver 20002"));restore()
end)
check("Single pickup map-only and zone-only names remain informational while nil level and completion places add no placeholder",function()
    local f=rewardPresentationFixture();local q=addon.quests[9970];local maps=C_Map
    q.requirementsKnown=true;q.start={npcID=1,name="Pickup giver",mapID=8,zoneName="Source zone"};C_Map=nil
    showDetail(9970,{level=60,completed=function()return false end,active=function()return false end})
    assert(destinationLine("Pickup giver — Source zone") and hasDestination(false) and not hasDestination(true))
    q.start.mapID=nil;ui:RefreshDetail();assert(destinationLine("Pickup giver — Source zone") and not hasDestination(false))
    q.start={};ui:RefreshDetail();assert(not detailHas(addon.L("UNKNOWN_PLACE")),"bare unknown destination is not an extra body line")
    q.start=nil;q.minLevel=80;showDetail(9970,{level=60,completed=function()return false end,active=function()return false end});assert(ui.action.kind=="level" and not detailHas(addon.L("UNKNOWN_PLACE")))
    q.minLevel=1;showDetail(9970,{level=60,completed=function()return false end,active=function()return true end,ready=function()return false end})
    assert(ui.action.kind=="complete" and not ui.action.place and not detailHas(addon.L("UNKNOWN_PLACE")))
    showDetail(9970,{level=60,completed=function()return true end,active=function()return false end})
    assert(not ui.action and not detailHas(addon.L("UNKNOWN_PLACE")))
    C_Map=maps;f:finish()
end)
check("Single destination map and name hydration reject changed endpoints helpers and source fields before publication",function()
    for _,mode in ipairs({"map","name","endpoint","coordinates","helper"})do
        local f,quests=singleDestinationFixture();showDetail(65,f.context);local getter=C_Map.GetMapInfo;local names=addon.GiverName;local armed=true
        if mode=="name"then
            addon.GiverName=function(p)
                if armed and p==quests[65].finish then armed=false;ui:InspectQuest(132)end
                return nil
            end
        else
            C_Map.GetMapInfo=function(id)
                if armed and id==1433 then
                    armed=false
                    if mode=="map"then ui:InspectQuest(132)
                    elseif mode=="endpoint"then local old=quests[65].finish;local fresh={};for k,v in pairs(old)do fresh[k]=v end;fresh.name="Fresh turn-in";quests[65].finish=fresh
                    elseif mode=="coordinates"then quests[65].finish.x=27
                    else addon.GiverName=function()return "Changed helper"end end
                end
                return getter(id)
            end
        end
        ui:RefreshDetail();assert(not armed)
        if mode=="map"or mode=="name"then assert(ui.quest==132 and ui.action.id==65)
        elseif mode=="helper"then assert(ui.action.id==65 and detailIncludes("Changed helper")and not detailIncludes("Wiley the Black"))
        else assert(not ui.action and not hasDestination(false) and not hasDestination(true))end
        C_Map.GetMapInfo=getter;addon.GiverName=names;ui:RefreshDetail()
        assert(ui.action and ui.action.id==65)
        f:restore()
    end
end)
check("Single destination hydration preserves newer same-card and replacement-card narratives and raw source ownership",function()
    for _,sameCard in ipairs({false,true})do
        local f,quests=singleDestinationFixture();showDetail(65,f.context);local getter=C_Map.GetMapInfo;local armed=true
        C_Map.GetMapInfo=function(id)
            if armed and id==1433 then
                armed=false
                if sameCard then local old=quests[65].finish;local fresh={};for k,v in pairs(old)do fresh[k]=v end;fresh.name="Current destination";quests[65].finish=fresh;ui:RefreshDetail()
                else ui:InspectQuest(132)end
            end
            return getter(id)
        end
        ui:RefreshDetail()
        assert(ui.quest==(sameCard and 65 or 132) and ui.action.id==65)
        if sameCard then assert(detailIncludes("Current destination — Redridge Mountains") and not detailIncludes("Wiley the Black — Redridge Mountains"))end
        C_Map.GetMapInfo=getter;f:restore()
    end
end)
check("Consecutive unknown action placeholders collapse to one while explicit uncertainty beside a real action stays",function()
    local f=rewardPresentationFixture();local q=addon.quests[9970]
    ui:RefreshDetail();local repeated=0;local previous
    for _,fs in ipairs(ui.details)do if fs.shown then
        if previous==addon.L("UNKNOWN")and fs.text==previous then repeated=repeated+1 end
        previous=fs.text
    end end
    assert(repeated==0 and ui.engine:State(9970).status=="UNKNOWN")
    local restore=multiActionFixture();addon.quests[20003].requirementsKnown=false;ui:Refresh()
    assert(ui.action.id==20002 and not detailIncludes(addon.L("NEXT")))
    restore();f:finish()
end)
check("Single starter-item destination hydration preserves new and same-card source identity without fabricating item actions",function()
    for _,sameCard in ipairs({false,true})do
        local f=rewardPresentationFixture();local q=addon.quests[9970];local names=addon.ItemName;local armed=true
        q.requirementsKnown=true;q.start={itemID=801,name="Old starter"}
        addon.ItemName=function()
            if armed then
                armed=false
                if sameCard then q.start={itemID=802,name="Fresh starter"};ui:RefreshDetail()else ui:InspectQuest(9971)end
            end
            return nil
        end
        showDetail(9970,{level=60,completed=function()return false end,active=function()return false end})
        assert(not armed and ui.quest==(sameCard and 9970 or 9971))
        assert(not destinationLine(addon.L("ITEM_STARTER","Old starter")))
        if sameCard then assert(destinationLine(addon.L("ITEM_STARTER","Fresh starter")) and ui.action.place==q.start)
        else assert(not ui.action)end
        addon.ItemName=names;f:finish()
    end
end)
local function eventObjectivesFixture()
    local f=objectObjectivesFixture();local q=addon.quests[9970]
    q.objectiveObjects=nil;q.objectiveEvents={{npcID=262681,name="Learn what happened to Ardin Grassman"}}
    ui:RefreshDetail();return f,q
end
local function detailOccurrences(value)
    local count=0;for _,fs in ipairs(ui.details)do if fs.shown and fs.text==value then count=count+1 end end;return count
end
check("Event credit labels share neutral objectives without becoming slain NPC names item counts portraits or navigation",function()
    local f,q=eventObjectivesFixture()
    assert(detailOccurrences(addon.L("OBJECTIVE_OBJECTS"))==1 and detailOccurrences(addon.L("OBJECTIVE_OBJECTS_NOTICE"))==0)
    assert(detailHas(unknownObjective(q.objectiveEvents[1].name)) and q.objectiveEvents[1].quantity==nil)
    assert(not detailHas(addon.L("OBJECTIVE_KILLS")) and not detailHas(addon.L("DETAIL_OBJECTIVES")))
    assert(detailHas(addon.L("OBJECTIVE_PROGRESS")) and detailHas("|cff88bfffNative objective 0/1|r"))
    assert(not q.finish and ui.engine:State(9970).status=="UNKNOWN" and not ui.action)
    assert(f.api.name==0 and f.api.icon==0 and f.api.count==0 and f.api.navigation==0)
    f:finish()
end)
check("Mixed object and event namespaces retain independent same-number facts one heading and native progress",function()
    local f,q=eventObjectivesFixture()
    q.objectiveObjects={{objectID=777,name="Object task",quantity=2}}
    q.objectiveEvents={{npcID=777,name="Event task"},{npcID=777,name="Duplicate event"}}
    q.objectiveKills={{npcID=777,name="Separate slain row",quantity=3}}
    q.objectiveItems={{itemID=777,name="Real item",quantity=4}}
    ui:RefreshDetail()
    assert(detailOccurrences(addon.L("OBJECTIVE_OBJECTS"))==1 and detailOccurrences(addon.L("OBJECTIVE_OBJECTS_NOTICE"))==0)
    assert(detailHas(addon.L("OBJECTIVE_ITEM","Object task",2)) and detailHas(unknownObjective("Event task")))
    assert(not detailHas(unknownObjective("Duplicate event")))
    assert(detailSectionY(addon.L("OBJECTIVE_ITEM","Object task",2))<detailSectionY(unknownObjective("Event task")))
    assert(detailHas(addon.L("OBJECTIVE_ITEM","Separate slain row",3)) and detailHas(addon.L("OBJECTIVE_ITEM","Native item 777",4)))
    assert(detailHas(addon.L("ITEM_CARRIED",0)) and f.api.name==1 and f.api.icon==1 and f.api.count==1 and f.api.navigation==0)
    assert(detailHas("|cff88bfffNative objective 0/1|r") and ui.engine:State(9970).status=="UNKNOWN")
    f:finish()
end)
check("Event labels validate absent-only quantities uint32 identities bounded UTF8 text and typed containers",function()
    local f,q=eventObjectivesFixture();local checker=issecretvalue;local secret={};issecretvalue=function(v)return v==secret end
    for _,entry in ipairs({{objectID=1,name="Wrong object"},{itemID=1,name="Wrong item"},{npcID=1,objectID=2,name="Mixed"},
        {npcID=1,itemID=2,name="Mixed"},{npcID=0,name="Bad"},{npcID=-1,name="Bad"},{npcID=1.5,name="Bad"},
        {npcID=4294967296,name="Bad"},{npcID="1",name="Bad"},{npcID=secret,name="Bad"},{npcID=1},
        {npcID=1,name=" "},{npcID=1,name=secret},{npcID=1,name=string.rep("x",501)},{npcID=1,name=string.rep("中",167)}})do
        q.objectiveEvents={entry};ui:RefreshDetail();assert(not detailHas(addon.L("OBJECTIVE_OBJECTS")))
    end
    for _,quantity in ipairs({false,true,0,-1,1.5,"1",{},secret,math.huge,0/0,9007199254740992})do
        q.objectiveEvents={{npcID=1,name="Invalid amount",quantity=quantity}};ui:RefreshDetail();assert(not detailHas(addon.L("OBJECTIVE_OBJECTS")))
    end
    for _,rows in ipairs({false,"bad",{}, {false}})do q.objectiveEvents=rows;ui:RefreshDetail();assert(not detailHas(addon.L("OBJECTIVE_OBJECTS")))end
    local rows={};for index=1,101 do rows[index]={npcID=index,name="Bounded event"}end
    q.objectiveEvents=rows;ui:RefreshDetail();assert(not detailHas(addon.L("OBJECTIVE_OBJECTS")))
    q.objectiveEvents={{npcID=4294967295,name=string.rep("中",166),quantity=9007199254740991}};ui:RefreshDetail()
    assert(detailHas(addon.L("OBJECTIVE_ITEM",q.objectiveEvents[1].name,9007199254740991)))
    issecretvalue=checker;f:finish()
end)
check("Event-only and mixed factual goals translate reuse one section and disappear with source or card",function()
    local f,q=eventObjectivesFixture();local locale=addon.db.locale
    for code in pairs(addon.locales)do
        addon.db.locale=code;q.objectiveObjects={};q.objectiveEvents={{npcID=1,name="Task"}};ui:RefreshDetail()
        assert(detailOccurrences(addon.L("OBJECTIVE_OBJECTS"))==1 and detailHas(unknownObjective("Task")))
        q.objectiveObjects={{objectID=1,name="Object"}};q.objectiveEvents[1].quantity=2;ui:RefreshDetail()
        assert(detailOccurrences(addon.L("OBJECTIVE_OBJECTS"))==1 and detailHas(addon.L("OBJECTIVE_ITEM","Task",2)))
        q.objectiveObjects=nil;q.objectiveEvents=nil;ui:RefreshDetail();assert(not detailHas(addon.L("OBJECTIVE_OBJECTS")))
    end
    q.objectiveEvents={{npcID=1,name="Old task"}};ui:RefreshDetail();ui:InspectQuest(9971)
    assert(not detailHas(unknownObjective("Old task")) and not detailHas(addon.L("OBJECTIVE_OBJECTS")))
    addon.db.locale=locale;f:finish()
end)
check("Event sanitizer and source member mutation cannot publish old labels across new or same-card generations",function()
    for _,sameCard in ipairs({false,true})do
        local f,q=eventObjectivesFixture();local checker=issecretvalue;local armed=true
        q.objectiveEvents={{npcID=123456789,name="Old event",quantity=6}}
        issecretvalue=function(value)
            if armed and value==123456789 then
                armed=false
                if sameCard then q.objectiveEvents={{npcID=8,name="Fresh event"}};ui:RefreshDetail()else ui:InspectQuest(9971)end
            end
            return false
        end
        ui:RefreshDetail();assert(not armed and ui.quest==(sameCard and 9970 or 9971))
        assert(not detailHas(addon.L("OBJECTIVE_ITEM","Old event",6)))
        if sameCard then assert(detailHas(unknownObjective("Fresh event")))end
        issecretvalue=checker;f:finish()
    end
    local f,q=eventObjectivesFixture();local checker=issecretvalue;local armed=true
    local entry={npcID=262681,name="Old task",quantity=6};q.objectiveEvents={entry}
    issecretvalue=function(value)if armed and value==6 then armed=false;entry.name="Changed task"end;return false end
    ui:RefreshDetail();assert(not detailHas(addon.L("OBJECTIVE_ITEM","Old task",6)))
    issecretvalue=checker;ui:RefreshDetail();assert(detailHas(addon.L("OBJECTIVE_ITEM","Changed task",6)))
    f:finish()
end)
check("Cross-source event root and list mutations invalidate object publication before either source proceeds",function()
    for _,mode in ipairs({"replace","append"})do
        local f,q=eventObjectivesFixture();local checker=issecretvalue;local armed=true
        q.objectiveObjects={{objectID=123456789,name="Old object",quantity=6}}
        issecretvalue=function(value)
            if armed and value==123456789 then
                armed=false
                if mode=="replace"then q.objectiveEvents={{npcID=8,name="New event"}}
                else q.objectiveEvents[2]={npcID=8,name="New event"}end
            end
            return false
        end
        ui:RefreshDetail();assert(not armed and not detailHas(addon.L("OBJECTIVE_ITEM","Old object",6)))
        issecretvalue=checker;ui:RefreshDetail();assert(detailHas(unknownObjective("New event")))
        assert(detailOccurrences(addon.L("OBJECTIVE_OBJECTS"))==1)
        f:finish()
    end
end)
check("Factual goal FontString setters preserve replacement event cards and independent live progress during native publication",function()
    for _,sameCard in ipairs({false,true})do
        local f,q=eventObjectivesFixture();local old=unknownObjective(q.objectiveEvents[1].name)
        local row=objectiveText(old);assert(row);local setter=row.SetText;local armed=true
        row.SetText=function(self,value)
            setter(self,value)
            if armed and value==old then
                armed=false
                if sameCard then q.objectiveEvents={{npcID=8,name="Current task"}};ui:RefreshDetail()else ui:InspectQuest(9971);expandDetail()end
            end
        end
        ui:RefreshDetail();assert(not armed and ui.quest==(sameCard and 9970 or 9971))
        assert(not detailHas(old) and detailHas("|cff88bfffNative objective 0/1|r"))
        if sameCard then assert(detailHas(unknownObjective("Current task")))end
        row.SetText=setter;f:finish()
    end
end)
check("Actual95647 event pilot uses its factual task label and has no inferred quantity or canonical NPC data",function()
    local f,q=eventObjectivesFixture();local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    q.objectiveEvents=actual.quests[95647].objectiveEvents
    assert(#q.objectiveEvents==1 and q.objectiveEvents[1].npcID==262681 and q.objectiveEvents[1].quantity==nil)
    ui:RefreshDetail();assert(detailHas(unknownObjective("Learn what happened to Ardin Grassman")))
    assert(f.api.name==0 and f.api.icon==0 and f.api.count==0 and f.api.navigation==0)
    assert(ui.engine:State(9970).status=="UNKNOWN" and not ui.action)
    f:finish()
end)
check("Quest-list text publication preserves the newer note metadata engine and actual click across native setter reentry",function()
    for _,phase in ipairs({"after","before"})do
        for _,field in ipairs({"title","note","heading"})do
            local old,new,restore=questListReentryFixture();addon.quests[24001].requirementsKnown=false
            local row=ui.rows[1];local target=(field=="title"or field=="note")and row[field]or ui[field]
            local setter=target.SetText;local armed=true;local expectedText,expectedNote,newEngine,newClick
            local function nested()
                armed=false;ui.dungeon=new;addon.char={};ui:RefreshQuests()
                expectedText,expectedNote,newEngine,newClick=target.text,row.note.text,ui.engine,row.scripts.OnClick
            end
            target.SetText=function(self,value)
                if armed and phase=="before"then nested()end
                setter(self,value)
                if armed and phase=="after"then nested()end
            end
            ui:RefreshQuests();target.SetText=setter
            assert(not armed and ui.dungeon==new and ui.engine==newEngine and row.questID==24002 and row.title.text=="Quest 24002")
            assert(target.text==expectedText and row.note.text==expectedNote and row.scripts.OnClick==newClick,field..phase)
            row.scripts.OnClick(row,"LeftButton",false);assert(ui.quest==24002,"the visible replacement row must remain inspectable")
            restore()
        end
    end
end)
check("A newer same-dungeon list generation retains ready status summary and real inspection after a native title write",function()
    local old,new,restore=questListReentryFixture();addon.quests[24001].requirementsKnown=false
    local context=addon.Context;local held=false
    addon.Context=function()return{level=60,completed=function()return false end,active=function()return held end,ready=function()return held end}end
    local row=ui.rows[1];local setter=row.title.SetText;local armed=true;local expectedNote,summary,newEngine
    row.title.SetText=function(self,value)
        setter(self,value)
        if armed then armed=false;held=true;ui:RefreshQuests();expectedNote,summary,newEngine=row.note.text,planSummary(),ui.engine end
    end
    ui:RefreshQuests();row.title.SetText=setter
    assert(not armed and ui.dungeon==old and ui.engine==newEngine and row.questID==24001)
    assert(row.note.text==expectedNote and row.note.text:find(addon.L("READY"),1,true) and planSummary()==summary)
    row.scripts.OnClick();assert(ui.quest==24001 and ui.engine:State(24001).status=="READY")
    addon.Context=context;restore()
end)
check("Quest-list layout and native row state writes stop before touching the newer pooled row",function()
    for _,mode in ipairs({"enabled","script","color","titlePoint","notePoint","height","headingPoint","viewport","contentHeight"})do
        local old,new,restore=questListReentryFixture();addon.quests[24001].requirementsKnown=false
        local row=ui.rows[1];local target,method=row,"SetEnabled"
        if mode=="script"then method="SetScript"
        elseif mode=="color"then target,method=row.bg,"SetColorTexture"
        elseif mode=="titlePoint"then target,method=row.title,"SetPoint"
        elseif mode=="notePoint"then target,method=row.note,"Hide"
        elseif mode=="height"then method="SetHeight"
        elseif mode=="headingPoint"then target,method=ui.heading,"SetText"
        elseif mode=="viewport"then target,method=ui.questScroll,"SetHeight"
        elseif mode=="contentHeight"then target,method=ui.questList,"SetHeight"end
        local original=target[method];local armed=true;local expectedNote,newClick,newHeight,newPoint
        target[method]=function(self,...)
            original(self,...)
            local shouldFire=mode~="enabled"or (...)==true
            if armed and shouldFire then
                armed=false;ui.dungeon=new;addon.char={};ui:RefreshQuests()
                expectedNote,newClick,newHeight,newPoint=row.note.text,row.scripts.OnClick,row.height,row.point
            end
        end
        ui:RefreshQuests();target[method]=original
        assert(not armed and row.questID==24002 and row.note.text==expectedNote and row.height==newHeight and row.point==newPoint,mode)
        assert(row.scripts.OnClick==newClick);row.scripts.OnClick();assert(ui.quest==24002,mode)
        restore()
    end
end)
check("Quest-list hide recycling cannot remove newly rendered longer-list rows or revive old callbacks",function()
    local old,new,restore=questListReentryFixture()
    addon.quests[24003]={id=24003,minLevel=1,requirementsKnown=true}
    old.quests={24001,24003};ui:RefreshQuests();local row=ui.rows[2]
    local hide=row.Hide;local armed=true
    old.quests={24001};new.quests={24002,24003}
    row.Hide=function(self)
        hide(self)
        if armed then armed=false;ui.dungeon=new;addon.char={};ui:RefreshQuests()end
    end
    ui:RefreshQuests();row.Hide=hide
    assert(not armed and ui.rows[1].questID==24002 and row.shown and row.questID==24003)
    row.scripts.OnClick();assert(ui.quest==24003)
    local stale=ui.rows[1].scripts.OnClick;ui.dungeon=old;ui:RefreshQuests();local selected=ui.quest;stale();assert(ui.quest==selected)
    addon.quests[24003]=nil;restore()
end)
check("A title setter closing and reopening the same window preserves the new session list and live click",function()
    local old,new,restore=questListReentryFixture();local context=addon.Context;local held=false
    addon.Context=function()return{level=60,completed=function()return false end,active=function()return held end,ready=function()return held end}end
    local row=ui.rows[1];local setter=row.title.SetText;local armed=true;local newer,newEngine
    row.title.SetText=function(self,value)
        setter(self,value)
        if armed then
            armed=false;ui.frame:Hide();ui.frame.scripts.OnHide();held=true;ui.frame:Show();ui.frame.scripts.OnShow()
            newer,newEngine=row.note.text,ui.engine
        end
    end
    ui:RefreshQuests();row.title.SetText=setter
    assert(not armed and ui.frame.shown and ui.engine==newEngine and row.note.text==newer and row.note.text:find(addon.L("READY"),1,true))
    row.scripts.OnClick();assert(ui.quest==24001)
    addon.Context=context;restore()
end)
local function statusGlyphFixture()
    local f={context=addon.Context,dungeon=ui.dungeon,quest=ui.quest,history=ui.detailHistory,all=ui.includeUnavailable,preparation=ui.preparation,
        painter=addon.PaintQuestStatus,namespace=C_Texture,atlas=methods.SetAtlas,name=addon.QuestName,calls={},active={[32001]=true,[32002]=true},ready={[32002]=true}}
    methods.SetAtlas=function(self,atlas,useAtlasSize,filterMode,resetTexCoords)
        assert((atlas=="Quest-In-Progress-Icon-yellow"or atlas=="UI-QuestIcon-TurnIn-Normal")and useAtlasSize==false and filterMode==nil and resetTexCoords==true)
        self.atlas=atlas
    end
    C_Texture={GetAtlasInfo=function(atlas)f.calls[#f.calls+1]=atlas;return{}end}
    assert(loadfile("UI/QuestStatus.lua"))("DungeonPro",addon)
    addon.Context=function()return{level=60,faction="Alliance",completed=function(id)return id==32006 end,
        active=function(id)return f.active[id]==true end,ready=function(id)return f.ready[id]==true end}end
    for id=32001,32006 do addon.quests[id]={id=id,minLevel=1,requirementsKnown=id~=32004}end
    addon.quests[32005].factions={"Horde"}
    ui.includeUnavailable=true;ui.preparation=false;ui.detailHistory={};ui.quest=nil
    ui.dungeon={key="status-glyph",name="Status glyph",coverage="partial",quests={32001,32002,32003,32004,32005,32006}}
    ui:RefreshQuests()
    function f:finish()
        addon.Context,addon.PaintQuestStatus,C_Texture,methods.SetAtlas,addon.QuestName=self.context,self.painter,self.namespace,self.atlas,self.name
        for id=32001,32006 do addon.quests[id]=nil end
        ui.dungeon,ui.quest,ui.detailHistory,ui.includeUnavailable,ui.preparation=self.dungeon,self.quest,self.history,self.all,self.preparation
        ui:Refresh()
    end
    return f
end
check("Native ACTIVE and READY glyphs decorate only quest titles while original status notes and real inspection remain",function()
    local f=statusGlyphFixture()
    for index,expected in ipairs({"Quest-In-Progress-Icon-yellow","UI-QuestIcon-TurnIn-Normal"})do
        local row=ui.rows[index]
        assert(row.statusIcon and row.statusIcon.shown and row.statusIcon.atlas==expected and not row.art)
        assert(row.statusIcon.width==16 and row.statusIcon.height==16 and row.statusInset==20)
        assert(row.title.point[2]==8+(row.chainInset or 0)+row.statusInset and row.note.point[2]==8 and row.title.width==row.statusBaseWidth-20)
        assert(row.title.fontSize==17 and row.note.fontSize==14)
        assert(row.note.text:find(addon.L(index==1 and "ACTIVE"or"READY"),1,true))
    end
    for index=3,6 do local row=ui.rows[index];assert(row.statusIcon and row.statusIcon.shown and row.statusInset==20 and row.title.point[2]==8+(row.chainInset or 0)+row.statusInset and row.title.width==row.statusBaseWidth-20 and not row.note.shown)end
    assert(#f.calls==2)
    ui.rows[2].scripts.OnClick(ui.rows[2],"LeftButton",false);assert(ui.quest==32002 and ui.engine:State(32002).status=="READY")
    f:finish()
end)
check("Quest glyphs clear on state and heading recycling and never indent note text or dungeon artwork",function()
    local f=statusGlyphFixture();local row=ui.rows[1];local width=row.statusBaseWidth
    f.active[32001]=false;ui:RefreshQuests()
    assert(row.questID==32001 and row.statusIcon.shown and row.statusInset==20 and row.title.width==width-20 and row.title.point[2]==8+(row.chainInset or 0)+row.statusInset and not row.note.shown)
    ui.preparation=true;ui:RefreshQuests();assert(ui.rows[1].heading and not ui.rows[1].statusIcon.shown and ui.rows[1].title.width==ui.rows[1]:GetWidth()-22)
    ui.preparation=false;f.active[32001]=true;ui:RefreshQuests();assert(row.statusIcon.shown and row.title.width==width-20)
    ui:RefreshDungeons();for _,card in ipairs(ui.cards)do if card.shown then assert(card.title.point[2]==76 and card.note.point[2]==76)end end
    f:finish()
end)
check("Optional glyph painter failures and missing capabilities preserve textual original-width quest rows",function()
    local f=statusGlyphFixture();local row=ui.rows[1];local actual=addon.PaintQuestStatus
    for _,painter in ipairs({false,function()return false end,function(texture)texture:Show();error("native failed")end,function()return{}end})do
        addon.PaintQuestStatus=painter;ui:RefreshQuests()
        assert(row.questID==32001 and row.enabled and row.statusInset==0 and row.title.width==row.statusBaseWidth and row.title.point[2]==8+(row.chainInset or 0) and not row.statusIcon.shown)
        row.scripts.OnClick();assert(ui.quest==32001)
    end
    addon.PaintQuestStatus=nil;ui:RefreshQuests();assert(row.statusInset==0 and not row.statusIcon.shown)
    addon.PaintQuestStatus=actual;C_Texture.GetAtlasInfo=function()return nil end;ui:RefreshQuests();assert(row.statusInset==0 and not row.statusIcon.shown)
    C_Texture.GetAtlasInfo=function()return{}end;ui:RefreshQuests();assert(row.statusInset==20 and row.statusIcon.shown)
    f:finish()
end)
check("Status title width is reduced before natural measurement and long localized titles grow without shrinking fonts",function()
    local f=statusGlyphFixture();local locale=addon.db.locale;local widths={}
    addon.QuestName=function(id)if id==32001 then return string.rep("Длинное задание ",12)end;return f.name(id)end
    measurement=function(fs)
        if fs.text and fs.text:find("Длинное задание",1,true)then widths[#widths+1]=fs.width;return fs.width==ui.rows[1].statusBaseWidth-20 and 72 or 18 end
        return 18
    end
    for code in pairs(addon.locales)do
        addon.db.locale=code;ui:RefreshQuests();local row=ui.rows[1]
        assert(row.height==84 and row.title.fontSize==17 and row.note.fontSize==14)
        assert(-ui.rows[2].point[3]>=-row.point[3]+row.height and row.note.point[2]==8)
    end
    assert(#widths>=10);measurement=nil;addon.db.locale=locale;addon.QuestName=f.name;ui:RefreshQuests();assert(ui.rows[1].height==30)
    f:finish()
end)
check("Glyph atlas getter and native setter reentry preserve newer pooled status rows and fresh callbacks",function()
    for _,mode in ipairs({"getter","setter","width"})do
        local f=statusGlyphFixture();local row=ui.rows[1];local armed=true;local original,object,method
        if mode=="getter"then object,method=C_Texture,"GetAtlasInfo"
        elseif mode=="setter"then object,method=row.statusIcon,"SetAtlas"
        else object,method=row.title,"SetWidth"end
        original=object[method]
        object[method]=function(self,...)
            local value
            if mode=="getter"then value=original(self,...)else value=original(self,...)end
            if armed then
                armed=false;ui.dungeon={key="new-glyph-list",name="New list",coverage="partial",quests={32002}};ui:RefreshQuests()
            end
            return value
        end
        ui:RefreshQuests();object[method]=original
        assert(not armed and row.questID==32002 and row.statusIcon.shown and row.statusIcon.atlas=="UI-QuestIcon-TurnIn-Normal")
        assert(row.statusInset==20 and row.title.width==row.statusBaseWidth-20 and row.title.point[2]==8+(row.chainInset or 0)+row.statusInset and row.note.point[2]==8)
        row.scripts.OnClick();assert(ui.quest==32002)
        f:finish()
    end
end)
check("Glyph caller rejects changed producer checker engine and source ownership and recovers only on fresh redraw",function()
    for _,mode in ipairs({"helper","checker","source","engine"})do
        local f=statusGlyphFixture();local painter=addon.PaintQuestStatus;local checker=issecretvalue;local armed=true
        addon.PaintQuestStatus=function(texture,status,current)
            local result=painter(texture,status,current)
            if armed then
                armed=false
                if mode=="helper"then addon.PaintQuestStatus=painter
                elseif mode=="checker"then issecretvalue=function()return false end
                elseif mode=="source"then local old=addon.quests[32001];local new={};for k,v in pairs(old)do new[k]=v end;addon.quests[32001]=new
                else ui.engine=addon.Planner.New(addon.quests,addon.Context())end
            end
            return result
        end
        ui:RefreshQuests();assert(not armed)
        local callback=ui.rows[1].scripts.OnClick;assert(callback==nil or not ui.rows[1].enabled)
        addon.PaintQuestStatus=painter;issecretvalue=checker;ui:RefreshQuests()
        assert(ui.rows[1].statusIcon.shown and ui.rows[1].title.point[2]==8+(ui.rows[1].chainInset or 0)+ui.rows[1].statusInset)
        ui.rows[1].scripts.OnClick();assert(ui.quest==32001)
        f:finish()
    end
end)
check("Status width getters and before-original setters preserve the newer compact role and indentation",function()
    for _,mode in ipairs({"getter","setterBefore"})do
        local f=statusGlyphFixture();local row=ui.rows[1];local width=row.statusBaseWidth;local armed=true
        local object,method=mode=="getter"and row or row.title,mode=="getter"and"GetWidth"or"SetWidth";local original=object[method]
        if mode=="getter"then row.title:SetWidth(width);row.statusBaseWidth=nil end
        object[method]=function(self,...)
            local value
            if mode=="getter"then value=original(self,...)end
            if armed then armed=false;ui.dungeon={key="ordinary-after-glyph",name="Ordinary",coverage="partial",quests={32003}};ui:RefreshQuests()end
            if mode~="getter"then value=original(self,...)end
            return value
        end
        ui:RefreshQuests();object[method]=original
        assert(not armed and row.questID==32003 and row.title.width==width-20 and row.statusInset==20 and row.statusIcon.shown)
        assert(row.title.point[2]==8+(row.chainInset or 0)+row.statusInset and not row.note.shown);row.scripts.OnClick();assert(ui.quest==32003)
        f:finish()
    end
end)
local function paymentFixture()
    local f=rewardPresentationFixture();local q=addon.quests[9970]
    local saved={helper=addon.QuestPayment,currency=C_CurrencyInfo,balance=GetMoney,alias=GetCoinTextureString}
    f.price={amount=300};q.requiredMoney=300
    addon.QuestPayment=function(id,current)assert(id==9970 or id==9971);assert(type(current)=="function");assert(current());return f.price end
    GetMoney=function()error("Payment must not query balance")end
    GetCoinTextureString=function()error("Payment must not use a global formatter alias")end
    C_CurrencyInfo=nil
    local finish=f.finish
    function f:finish()
        addon.QuestPayment,C_CurrencyInfo,GetMoney,GetCoinTextureString=saved.helper,saved.currency,saved.balance,saved.alias
        finish(self)
    end
    ui:RefreshDetail();return f,q
end
check("Source-listed payment displays three hundred copper as reference cost separate from rewards without readiness or balance inference",function()
    local f,q=paymentFixture();local price=addon.L("QUEST_PAYMENT",addon.L("MONEY_COPPER",300))
    assert(detailHas(price) and not detailHas(addon.L("QUEST_PAYMENT_NOTICE")))
    assert(ui:SetDetailTab("sources"))
    assert(detailHas(price) and detailHas(addon.L("QUEST_PAYMENT_NOTICE")))
    assert(ui:SetDetailTab("quest"))
    assert(detailHas(addon.L("REWARD_ITEM","Fixed reward",2)) and not detailHas(addon.L("REWARD_MONEY",price)))
    assert(not detailHas(addon.L("NEXT")) and detailSectionY(price)<detailSectionY(addon.L("DETAIL_GUARANTEED")))
    assert(q.requiredMoney==300 and ui.engine:State(9970).status=="UNKNOWN" and not ui.action and not hasDestination(false) and not hasDestination(true))
    f:finish()
end)
check("Payment localization fallback skips unknown absent zero invalid or malformed records and clears recycled cards",function()
    local f,q=paymentFixture();local locale=addon.db.locale
    for code in pairs(addon.locales)do
        addon.db.locale=code;f.price={amount=300};ui:RefreshDetail()
        assert(detailHas(addon.L("QUEST_PAYMENT",addon.L("MONEY_COPPER",300)))and not detailHas(addon.L("QUEST_PAYMENT_NOTICE")))
        for _,formatted in ipairs({false,""," ",{},string.rep("x",4097)})do
            f.price={amount=300,formatted=formatted};ui:RefreshDetail();assert(detailHas(addon.L("QUEST_PAYMENT",addon.L("MONEY_COPPER",300))))
        end
    end
    for _,record in ipairs({false,{}, {amount=0},{amount=-1},{amount=300.5},{amount="300"},{amount=301}})do
        f.price=record;ui:RefreshDetail();assert(not detailIncludes(addon.L("QUEST_PAYMENT","")) and detailHas(addon.L("REWARD_ITEM","Fixed reward",2)))
    end
    f.price=nil;ui:RefreshDetail();assert(not detailIncludes(addon.L("QUEST_PAYMENT","")))
    f.price={amount=300};q.requiredMoney=nil;ui:RefreshDetail();assert(not detailIncludes(addon.L("QUEST_PAYMENT","")))
    for _,value in ipairs({false,0,-1,1.5,"300",{},math.huge,0/0,9007199254740992})do q.requiredMoney=value;ui:RefreshDetail();assert(not detailIncludes(addon.L("QUEST_PAYMENT","")))end
    q.requiredMoney=300;ui:RefreshDetail();ui:InspectQuest(9971);assert(not detailIncludes(addon.L("QUEST_PAYMENT","")))
    addon.db.locale=locale;f:finish()
end)
check("Optional payment helper native formatting and secret or throwing failures retain truthful fallback or omit unknown data",function()
    local f,q=paymentFixture();local helper=addon.QuestPayment;local checker=issecretvalue;local secret={}
    issecretvalue=function(v)return v==secret end
    f.price={amount=300,formatted="Native 3s"};ui:RefreshDetail();assert(detailHas(addon.L("QUEST_PAYMENT","Native 3s")))
    f.price={amount=300,formatted=secret};ui:RefreshDetail();assert(detailHas(addon.L("QUEST_PAYMENT",addon.L("MONEY_COPPER",300))))
    for _,getter in ipairs({false,function()error("Unavailable")end,function()return nil end,function()return secret end})do
        addon.QuestPayment=getter;ui:RefreshDetail();assert(not detailIncludes(addon.L("QUEST_PAYMENT","")))
    end
    addon.QuestPayment=helper;f.price={amount=secret};ui:RefreshDetail();assert(not detailIncludes(addon.L("QUEST_PAYMENT","")))
    f.price={amount=300};q.requiredMoney=secret;ui:RefreshDetail();assert(not detailIncludes(addon.L("QUEST_PAYMENT","")))
    issecretvalue=checker;f:finish()
end)
check("Payment helper and localized text hydration preserve a replacement card or fresh same-card source amount",function()
    for _,mode in ipairs({"newCard","sameCard","localize","helper","source","character","formatter"})do
        local f,q=paymentFixture();local getter,localize,char=addon.QuestPayment,addon.L,addon.char;local armed=true
        f.price={amount=300,formatted="Stale pending price"}
        local function mutate()
            armed=false
            if mode=="newCard"then ui:InspectQuest(9971)
            elseif mode=="sameCard"or mode=="localize"then q.requiredMoney=500;f.price={amount=500};ui:RefreshDetail()
            elseif mode=="helper"then addon.QuestPayment=function()return nil end
            elseif mode=="source"then local fresh={};for k,v in pairs(q)do fresh[k]=v end;addon.quests[9970]=fresh
            elseif mode=="character"then addon.char={}
            else C_CurrencyInfo={GetCoinTextureString=function()return"Changed formatter"end}end
        end
        if mode=="localize"then addon.L=function(key,...)local text=localize(key,...);if armed and key=="QUEST_PAYMENT"then mutate()end;return text end
        else addon.QuestPayment=function(...)local value=getter(...);if armed then mutate()end;return value end end
        ui:RefreshDetail();assert(not armed)
        assert(not detailHas(localize("QUEST_PAYMENT","Stale pending price")))
        if mode=="sameCard"or mode=="localize"then assert(detailHas(localize("QUEST_PAYMENT",localize("MONEY_COPPER",500))))end
        addon.L,addon.char,addon.QuestPayment=localize,char,getter;addon.quests[9970]=q;C_CurrencyInfo=nil;f.price={amount=q.requiredMoney};ui.quest=9970;ui:RefreshDetail();expandDetail()
        assert(detailHas(addon.L("QUEST_PAYMENT",addon.L("MONEY_COPPER",q.requiredMoney))))
        f:finish()
    end
end)
check("Payment FontString publication cannot overwrite newer same-card amounts or replacement-card details",function()
    for _,sameCard in ipairs({false,true})do
        local f,q=paymentFixture();local old=addon.L("QUEST_PAYMENT",addon.L("MONEY_COPPER",300));local line=objectiveText(old)
        assert(line);local setter=line.SetText;local armed=true
        line.SetText=function(self,value)
            setter(self,value)
            if armed and value==old then armed=false
                if sameCard then q.requiredMoney=500;f.price={amount=500};ui:RefreshDetail()else ui:InspectQuest(9971)end
            end
        end
        ui:RefreshDetail();line.SetText=setter
        assert(not armed and not detailHas(old))
        if sameCard then assert(detailHas(addon.L("QUEST_PAYMENT",addon.L("MONEY_COPPER",500))))
        else assert(ui.quest==9971 and not detailIncludes(addon.L("QUEST_PAYMENT","")))end
        f:finish()
    end
end)
check("Actual Sparklematic quest payments use the frozen native producer copper amounts independently of reward and unknown-cost records",function()
    local f,q=paymentFixture();local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    local saved=addon.quests;local calls=0;addon.quests=actual.quests
    assert(loadfile("Core/QuestPayment.lua"))("DungeonPro",addon)
    for _,mode in ipairs({"missing","native","throw","empty","secret"})do
        local checker=issecretvalue;local secret={};issecretvalue=function(v)return v==secret end
        if mode=="missing"then C_CurrencyInfo=nil
        else C_CurrencyInfo={GetCoinTextureString=function(amount,height)
            calls=calls+1;assert(amount==300 and height==14)
            if mode=="throw"then error("cold")elseif mode=="empty"then return""elseif mode=="secret"then return secret end
            return"Native 3 silver"
        end}end
        for _,id in ipairs({2945,2951,2953})do
            assert(actual.quests[id].requiredMoney==300)
            showSources(id);local value=mode=="native"and"Native 3 silver"or addon.L("MONEY_COPPER",300)
            assert(detailHas(addon.L("QUEST_PAYMENT",value))and detailHas(addon.L("QUEST_PAYMENT_NOTICE")))
            assert(ui.engine:State(id).status=="UNKNOWN" and not ui.action)
        end
        showSources(2952);assert(actual.quests[2952].requiredMoney==nil and not detailIncludes(addon.L("QUEST_PAYMENT","")))
        issecretvalue=checker
    end
    assert(calls>0)
    addon.quests=saved;f:finish()
end)
check("Native payment formatter and locale changes cannot publish old formatted text or overwrite a new quest card",function()
    for _,mode in ipairs({"newCard","sameCard","formatter","locale"})do
        local f,q=paymentFixture();local locale=addon.db.locale;local nativeLocale=GetLocale;local armed=true
        assert(loadfile("Core/QuestPayment.lua"))("DungeonPro",addon)
        C_CurrencyInfo={GetCoinTextureString=function(amount,height)
            if armed then
                armed=false
                if mode=="newCard"then ui:InspectQuest(9971)
                elseif mode=="sameCard"then q.requiredMoney=500;ui:RefreshDetail()
                elseif mode=="formatter"then C_CurrencyInfo.GetCoinTextureString=function()return"Fresh native fee"end
                else addon.db.locale="ruRU";GetLocale=function()return"ruRU"end;ui:RefreshDetail()end
            end
            return"Native fee "..amount
        end}
        ui:RefreshDetail();assert(not armed)
        if mode=="newCard"then assert(ui.quest==9971 and not detailIncludes(addon.L("QUEST_PAYMENT","")))
        elseif mode=="formatter"then assert(not detailHas(addon.L("QUEST_PAYMENT","Native fee 300")))
        elseif mode=="sameCard"then assert(detailHas(addon.L("QUEST_PAYMENT","Native fee 500")))
        else assert(detailHas(addon.L("QUEST_PAYMENT","Native fee 300")))end
        C_CurrencyInfo=nil;GetLocale=nativeLocale;addon.db.locale=locale;ui.quest=9970;ui:RefreshDetail();expandDetail()
        assert(detailHas(addon.L("QUEST_PAYMENT",addon.L("MONEY_COPPER",q.requiredMoney))))
        f:finish()
    end
end)
local function hierarchyFixture(id)
    local f=rewardPresentationFixture();local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    local saved={quests=addon.quests,name=addon.QuestName,objectives=addon.QuestObjectives,dialogue=addon.DialogueObjectiveText,
        item=addon.ItemName,icon=addon.ItemIcon,count=addon.CarriedItemCount}
    addon.quests=actual.quests;addon.QuestName=function(other)return actual.quests[other]and actual.quests[other].name or("Quest "..other)end
    addon.ItemName,addon.ItemIcon,addon.CarriedItemCount=nil,nil,nil
    f.held=true;f.progress={{text="Current native counter 0/1",finished=false}};f.dialogue="Current dialogue objective"
    addon.QuestObjectives=function(other)if other==id and f.held then return f.progress end end
    addon.DialogueObjectiveText=function(other)if other==id then return f.dialogue end end
    f.context={level=60,faction=(actual.quests[id].factions or{})[1]or"Alliance",class=(actual.quests[id].classes or{})[1]or"WARRIOR",race=(actual.quests[id].races or{})[1]or 1,
        active=function(other)return f.held and other==id end,completed=function()return false end,ready=function()return false end}
    showDetail(id,f.context)
    function f:restore()
        addon.quests,addon.QuestName,addon.QuestObjectives,addon.DialogueObjectiveText=saved.quests,saved.name,saved.objectives,saved.dialogue
        addon.ItemName,addon.ItemIcon,addon.CarriedItemCount=saved.item,saved.icon,saved.count
        self:finish()
    end
    return f,actual.quests[id]
end
local function firstDetailPrefix(prefix)
    for _,fs in ipairs(ui.details)do if fs.shown and fs.text:find(prefix,1,true)==1 then return -fs.point[3]end end
end
check("Actual1654 accepted native progress precedes long source item goals provided tools and every reference location",function()
    local f,q=hierarchyFixture(1654)
    local giverY=detailSectionY(addon.L("DETAIL_GIVER"));local progressY=detailSectionY(addon.L("OBJECTIVE_PROGRESS"))
    local dialogueY=detailSectionY(addon.L("OBJECTIVE_DIALOGUE"));local itemsY=detailSectionY(addon.L("DETAIL_OBJECTIVES"))
    local suppliedY=detailSectionY(addon.L("PROVIDED_ITEMS"));local startY=firstDetailPrefix("")
    assert(giverY<progressY and progressY<dialogueY and dialogueY<itemsY and itemsY<suppliedY and not detailHas(addon.L("NEXT")))
    assert(progressY<ui.detailScroll:GetHeight() and detailHas("|cff88bfffCurrent native counter 0/1|r"))
    assert(q.requirementsKnown==false and ui.engine:State(1654).status=="ACTIVE" and ui.action.kind=="complete" and not ui.action.place)
    assert(not ui.materialButtons[1].shown, "Quest keeps live goals ahead of secondary acquisition details")
    assert(ui:SetDetailTab("sources"))
    assert(ui.materialButtons[1].shown and not detailHas(addon.L("OBJECTIVE_PROGRESS")))
    f:restore()
end)
check("Native-first hierarchy preserves actual source role text in all locales and omits empty unavailable live sections",function()
    local f,q=hierarchyFixture(1654);local locale=addon.db.locale
    for code in pairs(addon.locales)do
        addon.db.locale=code;ui:RefreshDetail()
        assert(detailSectionY(addon.L("OBJECTIVE_PROGRESS"))<detailSectionY(addon.L("DETAIL_OBJECTIVES")))
        assert(detailOccurrences(addon.L("OBJECTIVE_PROGRESS"))==1 and detailOccurrences(addon.L("OBJECTIVE_DIALOGUE"))==1)
        f.progress={};f.dialogue=nil;ui:RefreshDetail()
        assert(not detailHas(addon.L("OBJECTIVE_PROGRESS")) and not detailHas(addon.L("OBJECTIVE_DIALOGUE")))
        assert(detailHas(addon.L("DETAIL_OBJECTIVES")) and detailHas(addon.L("PROVIDED_ITEMS")))
        f.progress={{text="Current native counter 0/1",finished=false}};f.dialogue="Current dialogue objective"
    end
    f.held=false;f.dialogue=nil;showDetail(1654,f.context)
    assert(ui.engine:State(1654).status=="UNKNOWN" and not ui.action and not detailHas(addon.L("OBJECTIVE_PROGRESS")))
    assert(detailSectionY(addon.L("DETAIL_GIVER"))<detailSectionY(addon.L("DETAIL_OBJECTIVES")))
    addon.QuestObjectives,addon.DialogueObjectiveText=nil,nil;ui:RefreshDetail()
    assert(not detailHas(addon.L("OBJECTIVE_PROGRESS")) and not detailHas(addon.L("OBJECTIVE_DIALOGUE")))
    addon.db.locale=locale;f:restore()
end)
check("Promoted source facts remain distinct and goal-free twelve-start cards add no placeholder progress or source panels",function()
    for _,id in ipairs({92753,8991,1160})do
        local f,q=hierarchyFixture(id)
        local goal=q.objectiveEvents and"OBJECTIVE_OBJECTS"or(q.objectiveKills and"OBJECTIVE_KILLS"or"DETAIL_OBJECTIVES")
        assert(detailSectionY(addon.L("OBJECTIVE_PROGRESS"))<detailSectionY(addon.L(goal)))
        assert(not detailHas(addon.L("NEXT"))and detailSectionY(addon.L(goal)))
        assert(detailHas(addon.L("OBJECTIVE_PROGRESS")) and q.requirementsKnown==false and ui.engine:State(id).status=="ACTIVE")
        f:restore()
    end
    local f,q=hierarchyFixture(2933)
    -- This isolated goal-free case keeps the twelve sources; supplied-role coverage uses the actual catalogue separately.
    q.providedItems=nil
    f.held=false;f.dialogue=nil;showDetail(2933,f.context)
    assert(not startButton(12).shown and not detailHas(addon.L("OBJECTIVE_PROGRESS")) and not detailHas(addon.L("OBJECTIVE_DIALOGUE")))
    assert(not detailHas(addon.L("DETAIL_OBJECTIVES"))and not detailHas(addon.L("PROVIDED_ITEMS"))and not detailHas(addon.L("OBJECTIVE_OBJECTS")))
    assert(ui:SetDetailTab("sources") and startButton(12).shown)
    f:restore()
end)
check("Early native objective producer reentry cannot overwrite replacement or newer same-card live data",function()
    for _,helper in ipairs({"QuestObjectives","DialogueObjectiveText"})do
        for _,sameCard in ipairs({false,true})do
            local f,q=hierarchyFixture(1654);local original=addon[helper];local armed=true
            addon[helper]=function(id)
                local value=original(id)
                if armed and id==1654 then
                    armed=false
                    if sameCard then f.progress={{text="Fresh native counter 1/2",finished=false}};f.dialogue="Fresh dialogue";ui:RefreshDetail()
                    else ui:InspectQuest(5382)end
                end
                return value
            end
            ui:RefreshDetail();assert(not armed and ui.quest==(sameCard and 1654 or 5382))
            if sameCard then assert(detailHas("|cff88bfffFresh native counter 1/2|r")and detailHas("Fresh dialogue")and not detailHas("|cff88bfffCurrent native counter 0/1|r"))
            else assert(not detailHas("Current dialogue objective")and not detailHas("|cff88bfffCurrent native counter 0/1|r"))end
            addon[helper]=original;f:restore()
        end
    end
end)
check("Promoted native label publication preserves current card and native helper omission without duplicate sections",function()
    local f,q=hierarchyFixture(1654);local fs=objectiveText("|cff88bfffCurrent native counter 0/1|r");local setter=fs.SetText;local armed=true
    fs.SetText=function(self,value)
        setter(self,value)
        if armed and value=="|cff88bfffCurrent native counter 0/1|r"then armed=false;f.progress={};f.dialogue=nil;ui:RefreshDetail()end
    end
    ui:RefreshDetail();fs.SetText=setter
    assert(not armed and not detailHas(addon.L("OBJECTIVE_PROGRESS"))and not detailHas(addon.L("OBJECTIVE_DIALOGUE")))
    assert(detailOccurrences(addon.L("DETAIL_OBJECTIVES"))==1 and detailOccurrences(addon.L("PROVIDED_ITEMS"))==1)
    f:restore()
end)

local function emptyPreparationFixture()
    local saved={quests=addon.quests,dungeons=addon.dungeons,context=addon.Context,name=addon.QuestName,dungeon=ui.dungeon,quest=ui.quest,
        history=ui.detailHistory,search=ui.search,range=ui.range,preparation=ui.preparation,unavailable=ui.includeUnavailable,locale=addon.db.locale}
    local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    addon.quests,addon.dungeons=actual.quests,actual.dungeons
    addon.Context=function()return {level=60,faction="Alliance",class="WARRIOR",race=1,active=function()return false end,
        ready=function()return false end,completed=function()return true end}end
    addon.QuestName=function(id)return actual.quests[id]and actual.quests[id].name or tostring(id)end
    for _,d in ipairs(actual.dungeons)do if d.key=="deadmines" or d.key=="dm" then ui.dungeon=d end end
    ui.quest=nil;ui.detailHistory={};ui.search="";ui.range=false;ui.preparation=true;ui.includeUnavailable=false
    ui:Refresh()
    return function()
        addon.quests,addon.dungeons,addon.Context,addon.QuestName=saved.quests,saved.dungeons,saved.context,saved.name
        ui.dungeon,ui.quest,ui.detailHistory,ui.search,ui.range,ui.preparation,ui.includeUnavailable=
            saved.dungeon,saved.quest,saved.history,saved.search,saved.range,saved.preparation,saved.unavailable
        addon.db.locale=saved.locale;ui:Refresh()
    end
end
check("Actual completed Deadmines quests remain directly listed without a retired preparation-mode detour",function()
    local finish=emptyPreparationFixture()
    assert(#ui.currentPlan.rows==7 and #visibleRows()==7 and not ui.currentPlan.preparationEmpty)
    local notice=addon.L("PREPARATION_EMPTY",addon.L("QUESTS"));local row=ui.rows[1]
    assert(row.shown and row.enabled and row.scripts.OnClick)
    assert(not detailHas(notice) and detailHas(addon.L("OVERVIEW_PICK")) and planCoverage()==addon.L("PARTIAL"))
    assert(not detailHas(addon.L("PREPARED")) and not ui.action and ui.quest==nil and #ui.detailHistory==0)
    assert(not ui.preparation and #visibleRows()==7 and not ui.currentPlan.preparationEmpty)
    assert(detailHas(addon.L("OVERVIEW_PICK")) and not detailHas(notice) and ui.rows[1].enabled)
    local id=ui.rows[1].questID;ui.rows[1].scripts.OnClick(ui.rows[1],"LeftButton");assert(ui.quest==id)
    finish()
end)
check("Direct quest browsing localizes and preserves genuinely empty or excluded-character notices",function()
    local finish=emptyPreparationFixture()
    for code in pairs(addon.locales)do
        addon.db.locale=code;ui:Refresh();local notice=addon.L("PREPARATION_EMPTY",addon.L("QUESTS"))
        assert(#visibleRows()==7 and detailOccurrences(notice)==0 and ui.rows[1].enabled and not ui.preparation)
    end
    ui.dungeon={key="empty-guidance",name="No target data",minLevel=1,maxLevel=60,coverage="partial",quests={}}
    ui:Refresh();assert(not ui.currentPlan.preparationEmpty and planCoverage()==addon.L("EMPTY") and ui.rows[1].shown and ui.rows[1].heading=="EMPTY")
    assert(detailHas(addon.L("EMPTY")) and not detailHas(addon.L("PREPARATION_EMPTY",addon.L("QUESTS"))))
    addon.quests={[30001]={id=30001,name="Foreign faction",requirementsKnown=true,minLevel=1,factions={"Horde"}}}
    ui.dungeon={key="foreign-guidance",name="Foreign targets",minLevel=1,maxLevel=60,coverage="reviewed",quests={30001}}
    ui:Refresh();assert(#ui.currentPlan.rows==0 and not ui.currentPlan.preparationEmpty and planCoverage()==addon.L("NO_CHARACTER_QUESTS", addon.L("FILTER_QUEST_ALL")))
    ui.characterButton.scripts.OnClick(ui.characterButton,"LeftButton")
    assert(#ui.currentPlan.rows==1 and #visibleRows()==1 and not ui.currentPlan.preparationEmpty,"completed foreign history is directly inspectable in all-character view")
    finish()
end)
check("Empty preparation label reentry preserves a newer quest view and its actual clickable rows",function()
    local finish=emptyPreparationFixture();local original=ui.rows[1].title.SetText;local armed=true
    ui.rows[1].title.SetText=function(self,value)
        original(self,value)
        if armed then armed=false;ui.preparation=false;ui:Refresh()end
    end
    ui:Refresh();ui.rows[1].title.SetText=original
    assert(not ui.preparation and #visibleRows()==7 and not ui.currentPlan.preparationEmpty)
    assert(ui.rows[1].enabled and ui.rows[1].title.text==addon.QuestName(ui.rows[1].questID))
    local id=ui.rows[1].questID;ui.rows[1].scripts.OnClick(ui.rows[1],"LeftButton");assert(ui.quest==id)
    finish()
end)


check("Empty preparation overview prompt localization cannot overwrite a nested ordinary quest view",function()
    local finish=emptyPreparationFixture();local original=addon.L;local armed=true
    addon.L=function(key,...)
        local value=original(key,...)
        if key=="PREPARATION_EMPTY" and armed then armed=false;ui.preparation=false;ui:Refresh()end
        return value
    end
    ui:RefreshDetail();addon.L=original
    assert(not ui.preparation and #visibleRows()==7 and detailHas(addon.L("OVERVIEW_PICK")))
    assert(not detailHas(addon.L("PREPARATION_EMPTY",addon.L("QUESTS"))))
    finish()
end)


local function overviewStateFixture()
    local finish=emptyPreparationFixture();local dungeons={}
    for _,d in ipairs(addon.dungeons)do dungeons[d.key]=d end
    local character={level=60,faction="Alliance",class="WARRIOR",race=1,active=function()return false end,
        ready=function()return false end,completed=function()return false end}
    addon.Context=function()return character end
    ui.preparation=false;ui.includeUnavailable=false
    return finish,dungeons,character
end
check("Actual source-empty Shapers and character-excluded RFC overview prompts explain their distinct lists in every locale",function()
    local finish,dungeons=overviewStateFixture()
    for code in pairs(addon.locales)do
        addon.db.locale=code;ui.dungeon=dungeons.shapers;ui:Refresh()
        assert(#ui.dungeon.quests==0 and #ui.currentPlan.rows==0 and #visibleRows()==0)
        assert(detailOccurrences(addon.L("EMPTY"))==1 and not detailHas(addon.L("OVERVIEW_PICK")))
        assert(planCoverage()==addon.L("EMPTY") and not detailHas(addon.L("NO_CHARACTER_QUESTS", addon.L("FILTER_QUEST_ALL"))))
        ui.dungeon=dungeons.rfc;ui:Refresh()
        assert(#ui.dungeon.quests==6 and #ui.currentPlan.rows==0 and #visibleRows()==0)
        assert(detailHas(addon.L("NO_CHARACTER_QUESTS", addon.L("FILTER_QUEST_ALL"))) and not detailHas(addon.L("OVERVIEW_PICK")) and not detailHas(addon.L("EMPTY")))
        assert(planCoverage()==addon.L("NO_CHARACTER_QUESTS", addon.L("FILTER_QUEST_ALL")) and not ui.action and ui.quest==nil and #ui.detailHistory==0)
    end
    finish()
end)
check("Overview empty guidance recovers through real character toggle and preserves unknown-character and no-match selected contexts",function()
    local finish,dungeons,character=overviewStateFixture();ui.dungeon=dungeons.rfc;ui:Refresh()
    ui.characterButton.scripts.OnClick(ui.characterButton,"LeftButton")
    assert(#visibleRows()==6 and detailHas(addon.L("OVERVIEW_PICK")) and not detailHas(addon.L("NO_CHARACTER_QUESTS", addon.L("FILTER_QUEST_ALL"))))
    ui.characterButton.scripts.OnClick(ui.characterButton,"LeftButton")
    character.faction="Horde";ui:Refresh();assert(#visibleRows()==6 and detailHas(addon.L("OVERVIEW_PICK")))
    character.faction=nil;ui:Refresh();assert(#visibleRows()==6 and detailHas(addon.L("OVERVIEW_PICK")))
    local plan=ui.currentPlan;ui.search="NoMatchingDungeonOrQuestXYZ";ui:RefreshDungeons();ui:RefreshDetail()
    assert(ui.dungeon==dungeons.rfc and ui.currentPlan==plan and ui.catalogNotice.shown and detailHas(addon.L("OVERVIEW_PICK")))
    assert(not ui.action and ui.quest==nil)
    ui.dungeon=nil;ui:Refresh();assert(detailHas(addon.L("PICK")) and not detailHas(addon.L("NO_CHARACTER_QUESTS", addon.L("FILTER_QUEST_ALL"))))
    finish()
end)
check("Excluded-character overview localization and prompt setters cannot overwrite a newer usable overview",function()
    for _,stage in ipairs({"localization","setter"})do
        local finish,dungeons=overviewStateFixture();ui.dungeon=dungeons.rfc;ui:Refresh()
        local originalL=addon.L;local armed=true;local field
        local function replace()if armed then armed=false;ui.dungeon=dungeons.dm or dungeons.deadmines;ui:Refresh()end end
        local originalSet
        if stage=="localization"then
            addon.L=function(key,...)local text=originalL(key,...);if key=="NO_CHARACTER_QUESTS"then replace()end;return text end
        else
            for _,fs in ipairs(ui.details)do if fs.shown and fs.text==addon.L("NO_CHARACTER_QUESTS", addon.L("FILTER_QUEST_ALL"))then field=fs end end
            assert(field);originalSet=field.SetText
            field.SetText=function(self,value)originalSet(self,value);if value==addon.L("NO_CHARACTER_QUESTS", addon.L("FILTER_QUEST_ALL"))then replace()end end
        end
        ui:RefreshDetail();addon.L=originalL;if field then field.SetText=originalSet end
        assert(ui.dungeon~=dungeons.rfc and #visibleRows()>0 and detailHas(addon.L("OVERVIEW_PICK")))
        assert(not detailHas(addon.L("NO_CHARACTER_QUESTS", addon.L("FILTER_QUEST_ALL"))))
        finish()
    end
end)


local function heldPaymentFixture()
    local f,q=paymentFixture();local saved={helper=addon.HeldQuestPayment,progress=addon.QuestObjectives,dialogue=addon.DialogueObjectiveText}
    f.native={amount=300};f.held=true
    addon.HeldQuestPayment=function(id,current)assert(id==9970 or id==9971);assert(current());if f.held and id==9970 then return f.native end end
    addon.QuestObjectives=function()return {{text="Held native counter",finished=false}}end
    addon.DialogueObjectiveText=function()return "Separate current dialogue"end
    local finish=f.finish
    function f:finish()addon.HeldQuestPayment,addon.QuestObjectives,addon.DialogueObjectiveText=saved.helper,saved.progress,saved.dialogue;finish(self)end
    ui:RefreshDetail();return f,q
end
local function logPaymentText(amount)return addon.L("QUEST_LOG_PAYMENT",addon.L("MONEY_COPPER",amount))end
check("Held quest-log payment is a positive native line between live counters and dialogue separate from source price and rewards",function()
    local f,q=heldPaymentFixture();local title=logPaymentText(300)
    assert(detailHas(title) and detailSectionY(addon.L("OBJECTIVE_PROGRESS"))<detailSectionY(title))
    assert(detailSectionY(title)<detailSectionY(addon.L("OBJECTIVE_DIALOGUE")) and detailSectionY(title)<detailSectionY(addon.L("QUEST_PAYMENT",addon.L("MONEY_COPPER",300))))
    assert(detailOccurrences(title)==1 and detailHas(addon.L("REWARD_ITEM","Fixed reward",2)) and ui.engine:State(9970).status=="UNKNOWN")
    f.price={amount=700};q.requiredMoney=700;ui:RefreshDetail()
    assert(detailHas(title) and detailHas(addon.L("QUEST_PAYMENT",addon.L("MONEY_COPPER",700))))
    q.requiredMoney=nil;addon.QuestObjectives=nil;ui:RefreshDetail()
    assert(detailHas(title) and not detailHas(addon.L("OBJECTIVE_PROGRESS")) and not detailHas(addon.L("QUEST_PAYMENT_NOTICE")))
    assert(not ui.action and not hasDestination(false) and not hasDestination(true));f:finish()
end)
check("Held payment localizes native or plain copper fallback and omits absent zero malformed cold or unheld data",function()
    local f,q=heldPaymentFixture();local locale=addon.db.locale
    for code in pairs(addon.locales)do
        addon.db.locale=code;f.native={amount=300,formatted="Native money texture"};ui:RefreshDetail()
        assert(detailHas(addon.L("QUEST_LOG_PAYMENT","Native money texture")))
        for _,format in ipairs({false,""," ",{},string.rep("x",4097)})do
            f.native={amount=300,formatted=format};ui:RefreshDetail();assert(detailHas(logPaymentText(300)))
        end
    end
    addon.db.locale=locale
    for _,value in ipairs({false,{}, {amount=0},{amount=-1},{amount=1.5},{amount="300"},{amount=math.huge},{amount=9007199254740992}})do
        f.native=value;ui:RefreshDetail();assert(not detailHas(logPaymentText(300)) and detailHas(addon.L("QUEST_PAYMENT",addon.L("MONEY_COPPER",300))))
    end
    f.native=nil;ui:RefreshDetail();assert(not detailHas(logPaymentText(300)))
    addon.HeldQuestPayment=function()error("cold native API")end;ui:RefreshDetail();assert(not detailHas(logPaymentText(300)))
    addon.HeldQuestPayment=nil;ui:RefreshDetail();assert(not detailHas(logPaymentText(300)))
    f:finish()
end)
check("Held payment helper and fallback localization reentry reject old card DTOs and same-card newer amounts",function()
    for _,stage in ipairs({"helper-card","helper-same","fallback"})do
        local f,q=heldPaymentFixture();local getter=addon.HeldQuestPayment;local localize=addon.L;local armed=true
        if stage=="fallback"then
            addon.L=function(key,...)local text=localize(key,...);if key=="MONEY_COPPER" and armed then armed=false;f.native={amount=700};ui:RefreshDetail()end;return text end
        else
            addon.HeldQuestPayment=function(id,current)
                local dto=getter(id,current)
                if armed then armed=false
                    if stage=="helper-card"then ui:InspectQuest(9971)else f.native={amount=700};ui:RefreshDetail()end
                end
                return dto
            end
        end
        ui:RefreshDetail();addon.L=localize
        assert(not detailHas(logPaymentText(300)))
        if stage=="helper-card"then assert(ui.quest==9971)else assert(ui.quest==9970 and detailHas(logPaymentText(700)))end
        f:finish()
    end
end)
check("Held payment source helper formatter and DTO mutation after native reads cannot publish an old amount",function()
    for _,stage in ipairs({"definition","helper","formatter","dto"})do
        local f,q=heldPaymentFixture();local getter=addon.HeldQuestPayment;local source=addon.quests[9970]
        addon.HeldQuestPayment=function(id,current)
            local result=getter(id,current)
            if stage=="definition"then addon.quests[9970]={id=9970,name="Replacement",minLevel=1,requirementsKnown=false}
            elseif stage=="helper"then addon.HeldQuestPayment=function()return nil end
            elseif stage=="formatter"then C_CurrencyInfo={GetCoinTextureString=function()return"new"end}
            end
            return result
        end
        if stage=="dto"then
            local cleaner=addon.Clean;local armed=true
            addon.Clean=function(value,expected)
                local clean=cleaner(value,expected)
                if armed and value==300 and expected=="number"then armed=false;f.native.amount=700 end
                return clean
            end
            ui:RefreshDetail();addon.Clean=cleaner
        else ui:RefreshDetail()end
        assert(not detailHas(logPaymentText(300)))
        addon.quests[9970]=source;f:finish()
    end
end)
check("Held payment line setter reentry preserves a newer same-card amount and clears when inspecting another card",function()
    local f,q=heldPaymentFixture();local first
    for _,fs in ipairs(ui.details)do if fs.shown and fs.text==logPaymentText(300)then first=fs end end
    assert(first);local setter=first.SetText;local armed=true
    first.SetText=function(self,text)setter(self,text);if armed then armed=false;f.native={amount=700};ui:RefreshDetail()end end
    ui:RefreshDetail();first.SetText=setter
    assert(detailHas(logPaymentText(700)) and not detailHas(logPaymentText(300)))
    ui:InspectQuest(9971);assert(not detailHas(logPaymentText(700)))
    ui:BackQuest();expandDetail();assert(detailHas(logPaymentText(700)))
    f.held=false;ui:RefreshDetail();assert(not detailHas(logPaymentText(700)) and detailHas(addon.L("QUEST_PAYMENT",addon.L("MONEY_COPPER",300))))
    f:finish()
end)


check("Held payment restricted amounts and changing checker locale or character scopes reject prior native text without a free-cost claim",function()
    for _,stage in ipairs({"restricted","checker","locale","character"})do
        local f,q=heldPaymentFixture();local getter=addon.HeldQuestPayment;local checker=issecretvalue;local locale=addon.db.locale;local character=addon.char
        if stage=="restricted"then issecretvalue=function(value)return value==300 end
        else
            addon.HeldQuestPayment=function(id,current)
                local dto=getter(id,current)
                if stage=="checker"then issecretvalue=function()return false end
                elseif stage=="locale"then addon.db.locale=locale=="ruRU" and "enUS"or"ruRU"
                else addon.char={}end
                return dto
            end
        end
        ui:RefreshDetail();issecretvalue=checker;addon.db.locale=locale;addon.char=character
        assert(not detailHas(logPaymentText(300)) and not ui.action)
        f:finish()
    end
end)
check("Clearing a recycled held-payment line cannot erase a newer reentrant card payment",function()
    local f,q=heldPaymentFixture();local line=ui.heldPaymentDetail;assert(line)
    local hide=line.Hide;local armed=true
    line.Hide=function(self)
        hide(self)
        if armed then armed=false;f.native={amount=700};ui:RefreshDetail()end
    end
    ui:RefreshDetail();line.Hide=hide
    assert(detailHas(logPaymentText(700)) and not detailHas(logPaymentText(300)))
    f:finish()
end)


check("Held payment cleanup before-original Hide restores only a newer exact owned line without rerender",function()
    for _,available in ipairs({true,false})do
        local f,q=heldPaymentFixture();local field=ui.heldPaymentDetail;local hide=field.Hide;local armed=true;local calls=0
        local getter=addon.HeldQuestPayment
        addon.HeldQuestPayment=function(...)calls=calls+1;return getter(...)end
        field.Hide=function(self)
            if armed then armed=false;f.native=available and{amount=700}or nil;ui:RefreshDetail()end
            hide(self)
        end
        ui:RefreshDetail();field.Hide=hide
        assert(calls==1,"cleanup recovery must not trigger another detail render or payment read")
        assert(not detailHas(logPaymentText(300)))
        if available then
            assert(ui.heldPaymentDetail==field and detailHas(logPaymentText(700)))
        else assert(not ui.heldPaymentDetail and not detailHas(logPaymentText(700)))end
        f:finish()
    end
end)


local function clientWaypointFixture()
    local f=rewardPresentationFixture();local saved={provider=addon.HeldQuestWaypoint,nav=addon.Navigation,progress=addon.QuestObjectives,dialogue=addon.DialogueObjectiveText}
    local q=addon.quests[9970];q.start={npcID=10,name="Recorded start",mapID=1,x=10,y=20};q.finish={npcID=20,name="Recorded finish",mapID=2,x=30,y=40}
    f.dto={source="clientWaypoint",questID=9970,uiMapID=43,normalizedX=0.1,normalizedY=0.9,text="Native route instruction"}
    f.held=true;f.ready=false;f.reads=0;f.visits={}
    f.context={level=60,active=function(id)return f.held and id==9970 end,ready=function(id)return f.ready and id==9970 end,completed=function()return false end}
    addon.HeldQuestWaypoint=function(id,current)f.reads=f.reads+1;assert(id==9970 or id==9971);assert(current());if f.held and id==9970 then return f.dto end end
    addon.Navigation={Start=function(action)f.visits[#f.visits+1]=action end,Map=function(place)f.mapped=place end}
    addon.QuestObjectives=function(id)if id==9970 and f.held then return{{text="Native objective row",finished=false}}end end
    addon.DialogueObjectiveText=function(id)if id==9970 then return"Current dialogue objective"end end
    local finish=f.finish
    function f:finish()
        addon.HeldQuestWaypoint,addon.Navigation,addon.QuestObjectives,addon.DialogueObjectiveText=saved.provider,saved.nav,saved.progress,saved.dialogue
        finish(self)
    end
    showDetail(9970,f.context);return f,q
end
check("Game waypoint is a separate optional manual destination after native objectives without replacing planner or recorded giver",function()
    local f,q=clientWaypointFixture();local action,giver=ui.action,ui.giverAction;local button=ui.clientWaypointButton
    assert(button and button.shown and button.enabled and button.label.text==addon.L("GAME_WAYPOINT_FOLLOW"),"game waypoint needs a separate explicit follow control")
    assert(detailHas(addon.L("GAME_WAYPOINT_NOTICE"))and detailHas("Native route instruction")and #f.visits==0)
    assert(detailSectionY(addon.L("OBJECTIVE_DIALOGUE"))<detailSectionY(addon.L("GAME_WAYPOINT")))
    assert(detailSectionY(addon.L("DETAIL_GIVER"))<detailSectionY(addon.L("GAME_WAYPOINT")))
    assert(action.id==9970 and action.kind=="complete" and giver.place==q.start and ui.engine:State(9970).status=="ACTIVE")
    button.scripts.OnClick(button,"LeftButton");local visit=f.visits[1]
    assert(visit.id==9970 and visit.kind=="visit" and visit.place.mapID==43 and visit.place.x==10 and visit.place.y==90)
    assert(visit.place.name=="Native route instruction" and visit.place.npcID==nil and visit.place.objectID==nil and visit.place.itemID==nil)
    assert(ui.action==action and ui.giverAction==giver)
    f.ready=true;showDetail(9970,f.context);local nextAction=ui.action
    assert(nextAction.kind=="turnin"and nextAction.place==q.finish)
    ui.clientWaypointButton.scripts.OnClick();assert(f.visits[#f.visits].place.mapID==43 and ui.action==nextAction)
    f:finish()
end)
check("Game waypoint click reads fresh normalized coordinates once including exact zero and one boundaries",function()
    local f,q=clientWaypointFixture();local reads=f.reads
    f.dto={source="clientWaypoint",questID=9970,uiMapID=1440,normalizedX=0,normalizedY=1}
    ui.clientWaypointButton.scripts.OnClick();assert(f.reads==reads+1)
    local p=f.visits[1].place;assert(p.mapID==1440 and p.x==0 and p.y==100 and p.name==nil)
    f.dto.normalizedX=1;f.dto.normalizedY=0
    ui.clientWaypointButton.scripts.OnClick();p=f.visits[2].place;assert(p.x==100 and p.y==0)
    assert(q.start.mapID==1 and q.start.x==10 and q.finish.mapID==2)
    f:finish()
end)
check("Game waypoint omission rejects absent cold malformed nonheld or restricted DTOs and recycles without an empty section",function()
    local f,q=clientWaypointFixture();local provider=addon.HeldQuestWaypoint
    local bad={false,{}, {source="catalog",questID=9970,uiMapID=43,normalizedX=0.1,normalizedY=0.9},
        {source="clientWaypoint",questID=9971,uiMapID=43,normalizedX=0.1,normalizedY=0.9},
        {source="clientWaypoint",questID=9970,uiMapID=0,normalizedX=0,normalizedY=1},
        {source="clientWaypoint",questID=9970,uiMapID=43,normalizedX=-0.1,normalizedY=0.9},
        {source="clientWaypoint",questID=9970,uiMapID=43,normalizedX=0.1,normalizedY=1.1},
        {source="clientWaypoint",questID=9970,uiMapID=43,normalizedX="0.1",normalizedY=0.9},
        {source="clientWaypoint",questID=9970,uiMapID=43,normalizedX=0.1,normalizedY=0.9,text=false}}
    for _,dto in ipairs(bad)do f.dto=dto;ui:RefreshDetail();assert(not detailHas(addon.L("GAME_WAYPOINT"))and not ui.clientWaypointButton.shown and not ui.clientWaypointBinding)end
    f.dto=nil;ui:RefreshDetail();assert(not detailHas(addon.L("GAME_WAYPOINT")))
    addon.HeldQuestWaypoint=nil;ui:RefreshDetail();assert(not ui.clientWaypointButton.shown and detailHas(addon.QuestName(9970)))
    addon.HeldQuestWaypoint=function()error("cold API")end;ui:RefreshDetail();assert(not detailHas(addon.L("GAME_WAYPOINT")))
    addon.HeldQuestWaypoint=provider;f.dto={source="clientWaypoint",questID=9970,uiMapID=43,normalizedX=0.1,normalizedY=0.9};f.held=false
    showDetail(9970,f.context);assert(ui.engine:State(9970).status=="UNKNOWN"and not detailHas(addon.L("GAME_WAYPOINT"))and #f.visits==0)
    f:finish()
end)
check("Game waypoint captions wrap across ten locales and optional text does not become a source identity",function()
    local f,q=clientWaypointFixture();local locale=addon.db.locale
    measurement=function(fs)return fs.text==addon.L("GAME_WAYPOINT_FOLLOW")and 42 or 18 end
    for code in pairs(addon.locales)do addon.db.locale=code;f.dto.text=nil;ui:RefreshDetail()
        assert(detailOccurrences(addon.L("GAME_WAYPOINT"))==1 and detailHas(addon.L("GAME_WAYPOINT_NOTICE")))
        assert(ui.clientWaypointButton.label.text==addon.L("GAME_WAYPOINT_FOLLOW")and ui.clientWaypointButton.height>=52)
        assert(q.start.npcID==10 and q.finish.npcID==20 and ui.action.kind=="complete")
    end
    addon.db.locale=locale;f:finish()
end)
check("Stale game-waypoint clicks cannot guide after ownership loss hidden window or a fresh provider returns no position",function()
    local f,q=clientWaypointFixture();local old=ui.clientWaypointButton.scripts.OnClick
    f.dto=nil;old();assert(#f.visits==0)
    f.dto={source="clientWaypoint",questID=9970,uiMapID=43,normalizedX=0.1,normalizedY=0.9};ui:RefreshDetail();old();assert(#f.visits==0)
    old=ui.clientWaypointButton.scripts.OnClick;f.held=false;old();assert(#f.visits==0)
    f.held=true;ui.frame:Hide();old();assert(#f.visits==0);ui.frame:Show()
    ui:InspectQuest(9971);old();assert(ui.quest==9971 and #f.visits==0)
    f:finish()
end)
check("Game-waypoint preview and click providers preserve a newer card and never dispatch old coordinates after reentry",function()
    for _,click in ipairs({false,true})do
        local f,q=clientWaypointFixture();local provider=addon.HeldQuestWaypoint;local armed=true
        addon.HeldQuestWaypoint=function(id,current)
            local dto=provider(id,current)
            if armed then armed=false;ui:InspectQuest(9971)end
            return dto
        end
        if click then
            -- Publish a binding owned by the replacement helper before its one-shot click reentry.
            armed=false;ui:RefreshDetail();armed=true;ui.clientWaypointButton.scripts.OnClick()
        else ui:RefreshDetail()end
        assert(not armed and ui.quest==9971 and #f.visits==0 and not ui.clientWaypointButton.shown)
        assert(detailHas(addon.QuestName(9971))and not detailHas("Native route instruction"))
        f:finish()
    end
end)
check("Game-waypoint localization and owned text setter reentry cannot publish old route text over a new card",function()
    for _,stage in ipairs({"localize","setter-before","setter-after"})do
        local f,q=clientWaypointFixture();local localize=addon.L;local setter=methods.SetText;local armed=true
        if stage=="localize"then
            addon.L=function(key,...)local value=localize(key,...);if armed and key=="GAME_WAYPOINT_NOTICE"then armed=false;ui:InspectQuest(9971)end;return value end
        else
            methods.SetText=function(self,value)
                if stage=="setter-after"then setter(self,value)end
                if armed and value=="Native route instruction"then armed=false;ui:InspectQuest(9971)end
                if stage=="setter-before"then setter(self,value)end
            end
        end
        ui:RefreshDetail();addon.L=localize;methods.SetText=setter
        assert(not armed and ui.quest==9971 and not detailHas("Native route instruction")and not ui.clientWaypointButton.shown)
        f:finish()
    end
end)
check("Opaque waypoint button setters conservatively omit the nested optional block and recover on ordinary refresh",function()
    for _,method in ipairs({"SetText","Show","Hide"})do
        local f,q=clientWaypointFixture();local control=ui.clientWaypointButton
        local object=method=="SetText"and control.label or control;local setter=object[method];local armed=true
        object[method]=function(self,...)
            if armed then armed=false;ui:InspectQuest(9971)end
            return setter(self,...)
        end
        ui:RefreshDetail();object[method]=setter
        assert(not armed and ui.quest==9971 and not control.shown and #f.visits==0 and not ui.clientWaypointWriteBusy)
        showDetail(9970,f.context);assert(control.shown and detailHas(addon.L("GAME_WAYPOINT")))
        f:finish()
    end
end)


check("Game waypoint source sanitization rejects restricted fields and final DTO mutation without changing current actions",function()
    local f,q=clientWaypointFixture();local checker=issecretvalue
    local restricted={};f.dto.normalizedX=restricted;issecretvalue=function(value)return value==restricted end
    ui:RefreshDetail();issecretvalue=checker
    assert(not detailHas(addon.L("GAME_WAYPOINT"))and not ui.clientWaypointButton.shown and ui.action.kind=="complete")
    f.dto={source="clientWaypoint",questID=9970,uiMapID=43,normalizedX=0.1,normalizedY=0.9,text="Native route instruction"}
    local localize=addon.L;local armed=true
    addon.L=function(key,...)local text=localize(key,...);if armed and key=="GAME_WAYPOINT_NOTICE"then armed=false;f.dto.normalizedX=0.5 end;return text end
    ui:RefreshDetail();addon.L=localize
    assert(not armed and not detailHas(addon.L("GAME_WAYPOINT"))and #f.visits==0)
    ui:RefreshDetail();assert(ui.clientWaypointButton.shown)
    ui.clientWaypointButton.scripts.OnClick();assert(f.visits[1].place.x==50)
    f:finish()
end)
check("Game-waypoint clicks reject replaced helper character navigation locale and stale or reentrant engine scopes",function()
    for _,stage in ipairs({"helper","character","navigation","locale","engine-stale","engine-reentrant"})do
        local f,q=clientWaypointFixture();local callback=ui.clientWaypointButton.scripts.OnClick
        local char,nav,locale=addon.char,addon.Navigation,addon.db.locale;local method=ui.engine.Current
        if stage=="helper"then addon.HeldQuestWaypoint=function()return f.dto end
        elseif stage=="character"then addon.char={}
        elseif stage=="navigation"then addon.Navigation={Start=function()error("replacement navigation must not run")end}
        elseif stage=="locale"then addon.db.locale=locale=="ruRU"and"enUS"or"ruRU"
        elseif stage=="engine-stale"then
            local valid=true
            ui.engine.Current=function()return valid end
            ui:RefreshDetail();callback=ui.clientWaypointButton.scripts.OnClick;valid=false
        else
            local armed=false
            ui.engine.Current=function(self)if armed then armed=false;ui:InspectQuest(9971)end;return true end
            ui:RefreshDetail();callback=ui.clientWaypointButton.scripts.OnClick;armed=true
        end
        callback();assert(#f.visits==0)
        addon.char,addon.Navigation,addon.db.locale=char,nav,locale
        f:finish()
    end
end)


check("Waypoint owner predicate reads callback-capable locale before its final engine freshness check",function()
    local f,q=clientWaypointFixture();local provider=addon.HeldQuestWaypoint;local localeGetter=GetLocale;local armed,valid=false,true;local owner
    GetLocale=function()if armed then valid=false end;return"enUS"end
    ui.engine.Current=function()return valid end
    addon.HeldQuestWaypoint=function(id,current)owner=current;return provider(id,current)end
    ui:RefreshDetail();assert(owner and ui.clientWaypointButton.shown)
    armed=true;assert(owner()==false,"locale callback invalidated the same engine after its earlier freshness read")
    GetLocale=localeGetter;f:finish()
end)


check("Game waypoint preview rejects a changed typed quest identity in the same definition table after localization",function()
    local f,q=clientWaypointFixture();local localize=addon.L;local armed=true
    addon.L=function(key,...)
        local value=localize(key,...)
        if armed and key=="GAME_WAYPOINT_NOTICE"then armed=false;q.id=9971 end
        return value
    end
    ui:RefreshDetail();addon.L=localize
    assert(not armed and not ui.clientWaypointButton.shown and not ui.clientWaypointBinding and #f.visits==0)
    q.id=9970;ui:RefreshDetail();assert(ui.clientWaypointButton.shown)
    f:finish()
end)

check("Reward context precedes all twelve actual2933 source references after current goals without losing content",function()
    local f=rewardPresentationFixture();local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    local old=addon.quests[2933];addon.quests[2933]=actual.quests[2933]
    addon.DialogueRewards=function()return f.data end
    local context={level=60,faction="Alliance",class="WARRIOR",race=1,completed=function()return false end,active=function()return false end}
    local progress=addon.QuestObjectives;addon.QuestObjectives=function()return{{text="Live objective retained",finished=false}}end
    for code in pairs(addon.locales)do addon.db.locale=code;showDetail(2933,context)
        local rewardY=detailSectionY(addon.L("DETAIL_GUARANTEED"))
        assert(rewardY and not startButton(3).shown and not detailHas(addon.L("NEXT"))and detailSectionY(addon.L("OBJECTIVE_PROGRESS"))<rewardY)
        assert(detailOccurrences(addon.L("REWARD_ITEM","Fixed reward",2))==1 and detailOccurrences("Choice reward")==1)
        assert(ui:SetDetailTab("sources"))
        local shown=0;for index=1,12 do local row=startButton(index);if row.shown then shown=shown+1;assert(row.title.text==actual.quests[2933].startAlternatives[index].name)end end
        assert(shown==12)
    end
    addon.QuestObjectives=progress;addon.quests[2933]=old;f:finish()
end)
check("Reward priority retains hidden unknown empty and zero contexts while source references recycle",function()
    local f=rewardPresentationFixture();local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    local q=addon.quests[9970];q.startAlternatives=actual.quests[2933].startAlternatives
    local coin=GetCoinTextureString;GetCoinTextureString=function(amount)return"Coins "..amount end
    for _,kind in ipairs({"known","empty","hidden","unknown"})do
        f.data=kind=="known"and{source="dialogue",items={{id=701,name="Fixed reward",count=2,texture=123}},choices={},xp=0,money=300}
            or kind=="empty"and{source="dialogue",items={},choices={},xp=0,money=0}
            or kind=="hidden"and{source="dialogue",hidden=true}or nil
        showDetail(9970);assert(not startButton(3).shown)
        local key=kind=="known"and"DETAIL_GUARANTEED"or kind=="empty"and"REWARD_NO_ITEMS"or kind=="hidden"and"REWARD_HIDDEN"or"REWARD_UNAVAILABLE"
        if kind=="known"then assert(detailSectionY(addon.L(key)))else assert(not detailHas(addon.L(key)))end
        assert(detailHas(addon.L("REWARD_XP",0))==(kind=="known"or kind=="empty"))
        assert(detailHas(addon.L("REWARD_MONEY")..": Coins 300")== (kind=="known"))
        if kind~="known"then for _,row in ipairs(ui.rewardButtons or{})do assert(not row.shown)end end
        assert(ui:SetDetailTab("sources") and startButton(12).shown)
    end
    q.startAlternatives=nil;ui:RefreshDetail();for _,row in ipairs(ui.startButtons)do assert(not row.shown)end
    GetCoinTextureString=coin;f:finish()
end)
check("Reward promotion preserves narrative content and current quest reading position on ordinary refresh",function()
    local f=rewardPresentationFixture();local description=addon.Description
    addon.Description=function()return"Narrative paragraph retained after references."end
    measurement=function(fs)return fs.text=="Narrative paragraph retained after references."and 900 or 18 end
    ui:RefreshDetail();assert(detailHas(addon.L("DETAIL_GUARANTEED")))
    assert(ui:SetDetailTab("story"));ui.detailScroll:SetVerticalScroll(75)
    local function content()
        local texts={};for _,fs in ipairs(ui.details)do if fs.shown then texts[fs.text]=(texts[fs.text]or 0)+1 end end;return texts
    end
    local before=content();ui:RefreshDetail();local after=content()
    for text,count in pairs(before)do assert(after[text]==count)end;for text,count in pairs(after)do assert(before[text]==count)end
    assert(ui.detailScroll:GetVerticalScroll()==75)
    assert(ui.detailTab=="story" and not detailHas(addon.L("DETAIL_GUARANTEED")))
    assert(detailOccurrences("Narrative paragraph retained after references.")==1)
    addon.Description=description;f:finish()
end)
check("ActualBRD7848 target search explicitly opens its quest while ordinary dungeon click keeps the overview",function()
    local f=targetSearchFixture();local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    addon.dungeons,addon.quests=actual.dungeons,actual.quests
    addon.QuestName=function(id)return addon.quests[id]and addon.quests[id].name or("#"..id)end
    f:search("Attunement to the Core")
    local row;for _,card in ipairs(f:cards())do if card.matchQuestID==7848 then row=card end end
    assert(row);row.scripts.OnClick(row,"LeftButton",false)
    assert(ui.dungeon.key=="brd"and#ui.dungeon.quests==42 and ui.quest==nil)
    local inspect;for _,control in ipairs(ui.catalogInspectButtons)do if control.shown and control.questID==7848 then inspect=control end end
    assert(inspect and inspect.label.text==addon.L("BRANCH_INSPECT"))
    inspect.scripts.OnClick(inspect,"LeftButton",false)
    assert(ui.dungeon.key=="brd"and ui.quest==7848 and addon.char.selectedDungeon=="brd")
    assert(ui.engine:State(7848).status=="UNKNOWN"and not ui.action and hasDestination(false) and hasDestination(true) and ui.giver.footerLabelKey=="VISIT_GIVER")
    f:finish()
end)
check("Cached localized target inspection checks the fresh literal match without promoting support or changing filters",function()
    local f=targetSearchFixture();f.cachedNames[31001]="Задание в копях"
    addon.QuestName=function(id)return addon.quests[id]and addon.quests[id].name end
    f:search("ЗАДАНИЕ В КОПЯХ");local control=ui.catalogInspectButtons[2]
    assert(control.shown and control.questID==31001)
    local callback=control.scripts.OnClick;local dungeon,quest=ui.dungeon,ui.quest
    f.cachedNames[31001]="Different fresh title";callback();assert(ui.dungeon==dungeon and ui.quest==quest)
    f.cachedNames[31001]="Задание в копях";ui.range=true;ui:RefreshDungeons();control=ui.catalogInspectButtons[2]
    control.scripts.OnClick();assert(ui.dungeon.key=="target-b"and ui.quest==31001 and ui.range==true)
    f:search("Support only");for _,button in ipairs(ui.catalogInspectButtons)do assert(not button.shown and not button.scripts.OnClick)end
    f:finish()
end)
check("Target inspection controls clear on empty and dungeon-only queries and stale results never inspect recycled matches",function()
    local f=targetSearchFixture();f:search("Source target")
    local control=ui.catalogInspectButtons[1];local callback=control.scripts.OnClick;local dungeon,quest=ui.dungeon,ui.quest
    for _,query in ipairs({"Alpha","","No target matches"})do
        f:search(query);callback();assert(ui.dungeon==dungeon and ui.quest==quest)
        for _,button in ipairs(ui.catalogInspectButtons)do assert(not button.shown and not button.scripts.OnClick and button.questID==nil)end
    end
    f:search("Source target");callback=ui.catalogInspectButtons[1].scripts.OnClick
    addon.dungeons[1].quests={31002};callback();assert(ui.dungeon==dungeon and ui.quest==quest)
    f:finish()
end)
check("Target inspection preserves current character locale native capability and query ownership before effects",function()
    for _,kind in ipairs({"character","locale","native","getter","query","hidden"})do
        local f=targetSearchFixture();f:search("Source target")
        local callback=ui.catalogInspectButtons[1].scripts.OnClick;local character,native,locale=addon.char,C_QuestLog,addon.db.locale
        local getter=addon.CachedQuestName;local dungeon,quest=ui.dungeon,ui.quest;local shown=ui.frame.shown
        if kind=="character"then addon.char={}
        elseif kind=="locale"then addon.db.locale=locale=="ruRU"and"enUS"or"ruRU"
        elseif kind=="native"then C_QuestLog={}
        elseif kind=="getter"then addon.CachedQuestName=function()error("Old inspection must not call a replacement")end
        elseif kind=="hidden"then ui.frame.shown=false
        else ui.search="Other source"end
        callback();assert(ui.dungeon==dungeon and ui.quest==quest)
        ui.frame.shown=shown;addon.char,C_QuestLog,addon.db.locale,addon.CachedQuestName=character,native,locale,getter;f:finish()
    end
end)
check("Localized inspection labels wrap below their catalogue card without shrinking text or overlapping the next result",function()
    local f=targetSearchFixture()
    measurement=function(fs)if fs.text==addon.L("BRANCH_INSPECT")then return 62 end;return 18 end
    for code in pairs(addon.locales)do addon.db.locale=code;f:search("Source target")
        local cards=f:cards();local first,second=ui.catalogInspectButtons[1],ui.catalogInspectButtons[2]
        assert(first.shown and second.shown and first.label.fontSize==14 and first.height==72)
        assert(-first.point[3]>=-cards[1].point[3]+cards[1].height)
        assert(-cards[2].point[3]>=-first.point[3]+first.height)
    end
    measurement=nil;f:search("Source target");assert(ui.catalogInspectButtons[1].height==28)
    f:finish()
end)
local function dialoguePresentationFixture()
    local f=rewardPresentationFixture()
    local oldGetter,oldDescription=addon.DialogueText,addon.Description
    f.stage,f.text,f.valid,f.token="progress","Current progress paragraph.",true,{}
    addon.Description=function()return"Original narrative remains separate."end
    addon.DialogueText=function(id,owner)
        if id~=9970 or not f.valid then return nil end
        local token=f.token
        local dto={source="dialogue",stage=f.stage,text=f.text,current=function()return f.valid and f.token==token and owner()end}
        f.last=dto;return dto
    end
    local finish=f.finish
    function f:finish()addon.DialogueText,addon.Description=oldGetter,oldDescription;finish(self)end
    ui:RefreshDetail();return f
end
local function assertSeparateDialogueStory()
    assert(ui:SetDetailTab("story"))
    assert(detailHas("Original narrative remains separate.") and not detailHas(addon.L("DIALOGUE_PROGRESS_TEXT")) and not detailHas(addon.L("DIALOGUE_TURNIN_TEXT")))
    assert(ui:SetDetailTab("quest"))
end
check("current dialogue stage uses a distinct owned heading and keeps reward original narrative and quest state",function()
    local f=dialoguePresentationFixture()
    for _,stage in ipairs({"progress","completion"})do f.stage=stage;f.token={};ui:RefreshDetail()
        local heading=addon.L(stage=="progress"and"DIALOGUE_PROGRESS_TEXT"or"DIALOGUE_TURNIN_TEXT")
        assert(detailHas(heading)and detailHas(f.text)and not detailHas("Original narrative remains separate."))
        assert(detailSectionY(addon.L("DETAIL_GUARANTEED"))<detailSectionY(heading))
        assertSeparateDialogueStory()
        assert(ui.engine:State(9970).status=="UNKNOWN"and not ui.action)
    end
    f:finish()
end)
check("unknown closed malformed or restricted dialogue DTOs omit headings without changing source narrative",function()
    local f=dialoguePresentationFixture();local getter=addon.DialogueText;local checker=issecretvalue;local restricted={}
    for _,dto in ipairs({{}, {source="cache",stage="progress",text="Wrong",current=function()return true end},
        {source="dialogue",stage="offered",text="Wrong",current=function()return true end},
        {source="dialogue",stage="progress",text=" ",current=function()return true end},
        {source="dialogue",stage="progress",text=string.rep("x",30001),current=function()return true end},
        {source="dialogue",stage="progress",text="Wrong",current=false}})do
        addon.DialogueText=function()return dto end;ui:RefreshDetail()
        assert(not detailHas(addon.L("DIALOGUE_PROGRESS_TEXT"))and not detailHas(addon.L("DIALOGUE_TURNIN_TEXT"))and not detailHas("Original narrative remains separate."))
    end
    addon.DialogueText=function()return{source="dialogue",stage="progress",text=restricted,current=function()return true end}end
    issecretvalue=function(v)return v==restricted end;ui:RefreshDetail();issecretvalue=checker
    assert(not detailHas(addon.L("DIALOGUE_PROGRESS_TEXT")))
    addon.DialogueText=getter;f.valid=false;ui:RefreshDetail();assert(not detailHas(f.text));assertSeparateDialogueStory();f:finish()
end)
check("current dialogue wraps long prose and ten language headings without shrinking fonts or rereading source",function()
    local f=dialoguePresentationFixture();f.text=string.rep("Long narrative paragraph. ",1000)
    measurement=function(fs)return fs.text==f.text and 900 or 18 end
    for code in pairs(addon.locales)do addon.db.locale=code;ui:RefreshDetail()
        assert(detailHas(addon.L("DIALOGUE_PROGRESS_TEXT")))
        for _,fs in ipairs(ui.details)do if fs.shown and fs.text==f.text then assert(fs.fontSize==15 and fs.measuredHeight==900)end end
    end
    measurement=nil;f:finish()
end)
check("localization closing current dialogue omits only live prose and preserves the factual card",function()
    local f=dialoguePresentationFixture();local localize=addon.L;local armed=true
    addon.L=function(key,...)local value=localize(key,...);if armed and key=="DIALOGUE_PROGRESS_TEXT"then armed=false;f.valid=false end;return value end
    ui:RefreshDetail();addon.L=localize
    assert(not armed and not detailHas(f.text)and not detailHas(addon.L("DIALOGUE_PROGRESS_TEXT")))
    assert(not detailHas("Original narrative remains separate.")and detailHas(addon.L("REWARD_ITEM","Fixed reward",2)))
    assertSeparateDialogueStory()
    f:finish()
end)
check("dialogue owned native text setters preserve newer stage before and after nested refresh",function()
    for _,before in ipairs({true,false})do
        local f=dialoguePresentationFixture();local field
        for _,fs in ipairs(ui.details)do if fs.shown and fs.text==f.text then field=fs end end
        local setter,oldText,armed=field.SetText,f.text,true
        field.SetText=function(self,text)
            if not before then setter(self,text)end
            if armed and text==oldText then armed=false;f.token={};f.stage="completion";f.text="Fresh turn-in paragraph.";ui:RefreshDetail()end
            if before then setter(self,text)end
        end
        ui:RefreshDetail();field.SetText=setter
        assert(not armed and detailHas(f.text)and detailHas(addon.L("DIALOGUE_TURNIN_TEXT"))and not detailHas(oldText))
        assert(not detailHas("Original narrative remains separate."));assertSeparateDialogueStory();f:finish()
    end
end)
local function finishReferenceFixture()
    local restore=giverPortraitFixture();local q=addon.quests[26001]
    q.finish={npcID=4003,creatureDisplayID=5003,name="Finish Three",portraitSource="https://www.wowhead.com/forever/npc=4003",mapID=1,x=20,y=30}
    local f={mode=3}
    f.context={level=60,faction="Alliance",class="WARRIOR",race=1,completed=function()return false end,
        active=function(id)return id==26001 and f.mode>=2 end,ready=function(id)return id==26001 and f.mode==3 end}
    function f:refresh()showDetail(26001,self.context)end
    function f:sources()showSources(26001,self.context)end
    function f:finish()measurement=nil;restore()end
    f:refresh();return f,q
end
check("READY finish portrait is separate from native artwork and never replaces start location semantics",function()
    local f,q=finishReferenceFixture();addon.QuestPortrait=function()return{displayID=6001}end
    addon.DialoguePortrait=function()return{displayID=6002}end;f:refresh()
    assert(ui.portrait.shown and ui.portrait.texture=="display:6002")
    assert(ui:SetDetailTab("sources"))
    assert(ui.giverPortrait.shown and ui.giverPortrait.texture=="display:5003"and ui.giverPortrait.width==64 and ui.giverPortrait.height==64)
    assert(detailHas(addon.L("TURNIN_REFERENCE_PORTRAIT","Finish Three"))and not detailHas(addon.L("GIVER_REFERENCE_PORTRAIT","Reference One")))
    assert(ui.action.id==26001 and ui.action.kind=="turnin"and ui.action.place==q.finish)
    f.mode=2;f:sources();assert(ui.giverPortrait.texture=="display:5001"and detailHas(addon.L("GIVER_REFERENCE_PORTRAIT","Reference One")))
    assert(ui.action.kind=="complete"and ui.action.place==nil)
    q.finish=q.start;f.mode=3;f:sources()
    -- German turn-in portrait wording equals the ordinary finish line; test the role caption, not a substring absence.
    assert(ui.giverPortrait.texture=="display:5001"and detailHas(addon.L("GIVER_REFERENCE_PORTRAIT","Reference One")))
    q.finish={npcID=q.start.npcID,creatureDisplayID=5999,name="Reference One",portraitSource="https://www.wowhead.com/forever/npc=4001"}
    f:sources();assert(ui.giverPortrait.texture=="display:5001"and detailHas(addon.L("GIVER_REFERENCE_PORTRAIT","Reference One")))
    f:finish()
end)
check("finish reference requires a fresh single own turnin and skips alternative object item or unknown models",function()
    local f,q=finishReferenceFixture()
    for _,kind in ipairs({"foreign","multiple"})do
        f:sources();local nextAction=ui.engine.Next;local reads=0
        ui.engine.Next=function(engine,id,...)
            reads=reads+1
            if reads==1 then
                local actions=nextAction(engine,id,...)
                if kind=="foreign"then actions[1].id=26002 else actions[2]={id=26002,kind="turnin",place=q.finish}end
                return actions,false
            end
            return nextAction(engine,id,...)
        end
        ui:RefreshDetail();assert(ui.giverPortrait.texture=="display:5001"and ui.action.id==(kind=="foreign"and 26002 or 26001) and reads==2)
    end
    local original=q.finish
    for _,endpoint in ipairs({{npcID=4003,name="Unknown model"},{objectID=4003,name="Object"},{itemID=4003,name="Item"}})do
        q.finish=endpoint;f:sources();assert(ui.giverPortrait.texture=="display:5001")
        assert(detailHas(addon.L("GIVER_REFERENCE_PORTRAIT","Reference One")))
    end
    q.finish=nil;q.finishAlternatives={original,{npcID=4004,name="Other"}};f:sources()
    assert(ui.giverPortrait.texture=="display:5001"and ui.action.place==nil and not hasDestination(true))
    f:finish()
end)
check("finish source hydration and native renderer replacement reject an old reference and recover on fresh redraw",function()
    local f,q=finishReferenceFixture();local producer=addon.GiverPortrait;local old=q.finish;local armed=true
    addon.GiverPortrait=function(point)
        local result=producer(point)
        if armed and point==old then armed=false;q.finish={npcID=4004,creatureDisplayID=5004,name="Fresh Finish",portraitSource="https://www.wowhead.com/forever/npc=4004"}end
        return result
    end
    f:sources();assert(not armed and not ui.giverPortrait.shown)
    addon.GiverPortrait=producer;f:sources();assert(ui.giverPortrait.texture=="display:5004"and detailHas(addon.L("TURNIN_REFERENCE_PORTRAIT","Fresh Finish")))
    armed=true
    SetPortraitTextureFromCreatureDisplayID=function(texture,id)
        if armed then armed=false;showSources(26002,f.context)end
        texture:SetTexture("old opaque:"..id)
    end
    f:sources();assert(not armed and ui.quest==26002 and not ui.giverPortrait.shown)
    SetPortraitTextureFromCreatureDisplayID=function(texture,id)texture:SetTexture("recovered:"..id)end
    ui:RefreshDetail();assert(ui.giverPortrait.texture=="recovered:5002")
    f:finish()
end)
check("finish caption native setters before and after reentry preserve the newer source image and label",function()
    for _,before in ipairs({true,false})do
        local f=finishReferenceFixture();f:sources();local oldCaption=addon.L("TURNIN_REFERENCE_PORTRAIT","Finish Three");local field
        for _,fs in ipairs(ui.details)do if fs.shown and fs.text==oldCaption then field=fs end end
        local setter,armed=field.SetText,true
        field.SetText=function(self,text)
            if not before then setter(self,text)end
            if armed and text==oldCaption then armed=false;showSources(26002,f.context)end
            if before then setter(self,text)end
        end
        f:sources();field.SetText=setter
        assert(not armed and ui.quest==26002 and ui.giverPortrait.texture=="display:5002")
        assert(detailHas(addon.L("GIVER_REFERENCE_PORTRAIT","Reference Two"))and not detailHas(oldCaption))
        f:finish()
    end
end)
check("finish captions wrap in ten languages while one64pixel reference slot recycles by state",function()
    local f=finishReferenceFixture();local texture=ui.giverPortrait
    measurement=function(fs)return fs.text==addon.L("TURNIN_REFERENCE_PORTRAIT","Finish Three")and 64 or 18 end
    for code in pairs(addon.locales)do addon.db.locale=code;f:sources()
        assert(ui.giverPortrait==texture and texture.width==64 and texture.height==64)
        local caption=addon.L("TURNIN_REFERENCE_PORTRAIT","Finish Three");assert(detailHas(caption))
        for _,fs in ipairs(ui.details)do if fs.shown and fs.text==caption then assert(fs.fontSize==15 and fs.measuredHeight==64)end end
    end
    f.mode=1;f:sources();assert(texture.texture=="display:5001"and not detailHas(addon.L("TURNIN_REFERENCE_PORTRAIT","Finish Three")))
    f:finish()
end)

check("completion portrait has explicit priority without borrowing finish identity or changing source reference",function()
    local f,q=finishReferenceFixture();local previous=addon.DialogueTurnInPortrait;local reads=0;local valid=true
    addon.DialoguePortrait=function()return{displayID=6001}end
    addon.QuestPortrait=function()return{displayID=6002}end
    addon.DialogueTurnInPortrait=function(id,owner)
        reads=reads+1;assert(id==26001 and owner())
        return{source="dialogue",stage="completion",displayID=7001,current=function()return valid end}
    end
    f:refresh();assert(reads==1 and ui.portrait.texture=="display:7001"and not ui.giverPortrait.shown)
    assert(ui.action.kind=="turnin"and ui.action.place==q.finish and detailHas(addon.L("QUEST_PORTRAIT")))
    assert(ui:SetDetailTab("sources") and ui.giverPortrait.texture=="display:5003" and reads==1)
    addon.DialogueTurnInPortrait=previous;f:finish()
end)
check("completion hidden suppresses only native fallback and nil retains existing offer then selected priority",function()
    local f=finishReferenceFixture();local previous=addon.DialogueTurnInPortrait;local offerReads,selectedReads=0,0;local mode="hidden"
    addon.DialoguePortrait=function()offerReads=offerReads+1;return{displayID=6001}end
    addon.QuestPortrait=function()selectedReads=selectedReads+1;return{displayID=6002}end
    addon.DialogueTurnInPortrait=function()
        if mode=="hidden"then return{source="dialogue",stage="completion",hidden=true,current=function()return true end}end
    end
    f:refresh();assert(not ui.portrait.shown and not ui.giverPortrait.shown and offerReads==0 and selectedReads==0)
    assert(ui:SetDetailTab("sources") and ui.giverPortrait.shown and offerReads==0 and selectedReads==0)
    mode="nil";f:refresh();assert(ui.portrait.texture=="display:6001"and offerReads==1 and selectedReads==0)
    addon.DialoguePortrait=function()return nil end;f:refresh();assert(ui.portrait.texture=="display:6002"and selectedReads==1)
    addon.DialogueTurnInPortrait=previous;f:finish()
end)
check("current completion portrait closes during caption localization without publishing old image",function()
    local f=finishReferenceFixture();local previous=addon.DialogueTurnInPortrait;local L=addon.L;local live=true
    addon.DialogueTurnInPortrait=function()return{source="dialogue",stage="completion",displayID=7001,current=function()return live end}end
    addon.L=function(key,...)if key=="QUEST_PORTRAIT"then live=false end;return L(key,...)end
    f:refresh();assert(not ui.portrait.shown)
    addon.L=L;addon.DialogueTurnInPortrait=previous;f:finish()
end)
check("Completion portrait cannot show after its anchor write expires native dialogue proof",function()
    local f=finishReferenceFixture();local previous=addon.DialogueTurnInPortrait;local live=true
    addon.DialogueTurnInPortrait=function()return{source="dialogue",stage="completion",displayID=7001,current=function()return live end}end
    f:refresh();local texture=assert(ui.portrait);local point=texture.SetPoint;local armed=true
    texture.SetPoint=function(self,...)
        point(self,...)
        if armed then armed=false;live=false end
    end
    f:refresh();local shown=texture.shown
    assert(not detailHas(addon.L("QUEST_PORTRAIT")),"Expired native caption remained visible")
    texture.SetPoint=point;addon.DialogueTurnInPortrait=previous;f:finish()
    print("COMPLETION_PORTRAIT_AFTER_ANCHOR_SCOPE_LOSS",shown)
    assert(not shown,"Expired current completion image shown after anchor changed its proof")
end)

check("Completion portrait clearing its anchor preserves a newer card and its source image",function()
    local f=finishReferenceFixture();local previous=addon.DialogueTurnInPortrait
    addon.DialogueTurnInPortrait=function(id)if id==26001 then return{source="dialogue",stage="completion",displayID=7001,current=function()return true end}end end
    f:refresh();local texture=ui.portrait;local clear=texture.ClearAllPoints;local armed=true
    texture.ClearAllPoints=function(self,...)
        clear(self,...)
        if armed then armed=false;showSources(26002,f.context)end
    end
    f:refresh();texture.ClearAllPoints=clear
    assert(not armed and ui.quest==26002 and ui.giverPortrait.shown and ui.giverPortrait.texture=="display:5002")
    assert(detailHas(addon.L("GIVER_REFERENCE_PORTRAIT","Reference Two")))
    addon.DialogueTurnInPortrait=previous;f:finish()
end)
local function questLevelFixture(id)
    local corpus={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",corpus)
    local old=addon.quests[id];local original=corpus.quests[id];local q={}
    for key,value in pairs(original)do q[key]=value end
    addon.quests[id]=q
    local f={context={level=60,faction=(q.factions or{})[1]or"Alliance",class="WARRIOR",race=2,
        completed=function()return false end,active=function()return false end}}
    function f:refresh()showDetail(id,self.context)end
    function f:finish()measurement=nil;addon.quests[id]=old end
    f.expectedStatus=addon.Planner.New(addon.quests,f.context):State(id).status
    f:refresh();return f,q
end
check("actual quest level stays distinct from minimum level without changing status or twelve sources",function()
    for _,id in ipairs({5724,2933})do
        local f,q=questLevelFixture(id);local status=ui.engine:State(id).status
        local metadata=addon.L("DETAIL_LEVEL",q.level).." · "..addon.L("DETAIL_MIN_LEVEL",q.minLevel)
        local copies=0;for _,fs in ipairs(ui.details)do if fs.shown and fs.text:find(metadata,1,true)then copies=copies+1 end end
        assert(detailIncludes(metadata)and copies==1)
        assert(ui.engine:State(id).status==status and status==f.expectedStatus)
        if id==2933 then assert(ui:SetDetailTab("sources"));local count=0;for index=1,12 do local b=startButton(index);if b.shown then count=count+1 end end;assert(count==12)end
        f:finish()
    end
end)
check("absent zero negative invalid or restricted recorded level keeps known minimum without guessing",function()
    local f,q=questLevelFixture(5724);local checker=issecretvalue;local secretLevel={}
    issecretvalue=function(v)return v==secretLevel end
    for _,value in ipairs({0,-1,false,"16",16.5,math.huge,secretLevel})do
        q.level=value;f:refresh();assert(detailIncludes(addon.L("DETAIL_MIN_LEVEL",9))and not detailIncludes(addon.L("DETAIL_LEVEL",16)))
        assert(ui.engine:State(5724).status==f.expectedStatus)
    end
    q.level=nil;f:refresh();assert(detailIncludes(addon.L("DETAIL_MIN_LEVEL",9)))
    -- Missing minimum is outside the Planner schema; exercise only the display boundary with a read-only unknown state.
    q.level=16;q.minLevel=nil
    ui.engine={context=f.context,State=function()return{status="UNKNOWN"}end,Next=function()return{},false end}
    ui:RefreshDetail();assert(detailIncludes(addon.L("DETAIL_LEVEL",16))and not detailIncludes(addon.L("DETAIL_MIN_LEVEL",9)))
    issecretvalue=checker;f:finish()
end)
check("recorded level and minimum wrap in ten locales at the existing readable body size and recycle",function()
    local f,q=questLevelFixture(5724);local locale=addon.db.locale
    measurement=function(fs)return fs.text:find(" · ",1,true)and 54 or 18 end
    for code in pairs(addon.locales)do addon.db.locale=code;f:refresh()
        local value=addon.L("DETAIL_LEVEL",16).." · "..addon.L("DETAIL_MIN_LEVEL",9);local found=false
        for _,fs in ipairs(ui.details)do if fs.shown and fs.text:find(value,1,true)then found=true;assert(fs.fontSize==13 and fs.measuredHeight==54)end end
        assert(found)
    end
    q.level=nil;f:refresh();assert(not detailIncludes(addon.L("DETAIL_LEVEL",16)))
    addon.db.locale=locale;f:finish()
end)
check("level localization replacing a quest cannot write the old metadata over a new card",function()
    local f=questLevelFixture(5724);local q=addon.quests[5724];local L=addon.L;local armed=true
    local old=addon.quests[99001];addon.quests[99001]={id=99001,name="New metadata card",level=30,minLevel=20,requires={},requirementsKnown=false}
    addon.L=function(key,...)
        local value=L(key,...)
        if armed and key=="DETAIL_LEVEL"then armed=false;showDetail(99001,f.context)end
        return value
    end
    f:refresh();assert(not armed and ui.quest==99001 and not detailHas(L("DETAIL_LEVEL",q.level)))
    assert(detailHas(L("DETAIL_LEVEL",30).." · "..L("DETAIL_MIN_LEVEL",20)))
    addon.L=L;addon.quests[99001]=old;f:finish()
end)


check("language control shows native names and aliases without rewriting stored preferences",function()
    local old=addon.db.locale
    local names={enUS="English",ruRU="Русский",deDE="Deutsch",frFR="Français",esES="Español",itIT="Italiano",ptBR="Português",koKR="한국어",zhCN="简体中文",zhTW="繁體中文",enGB="English",esMX="Español",unsupported="English",[""]="English"}
    for code,name in pairs(names)do
        addon.db.locale=code;ui:Refresh()
        assert(ui.language.text==name and addon.db.locale==code and ui.language.width==64)
    end
    addon.db.locale=old;ui:Refresh()
end)
check("automatic language uses short localized labels without changing the menu label",function()
    local old,locale,getter=addon.db.locale,addon.L,GetLocale
    local menuLabel={}
    for code,dict in pairs(addon.locales)do if dict.LANGUAGE_AUTO_SHORT then
        GetLocale=function()return code end;addon.db.locale="auto";ui:Refresh()
        assert(ui.language.text==dict.LANGUAGE_AUTO_SHORT and addon.db.locale=="auto" and ui.language.width==64)
        menuLabel[code]=dict.LANGUAGE_AUTO
    end end
    for code,value in pairs(menuLabel)do assert(addon.locales[code].LANGUAGE_AUTO==value)end
    GetLocale=getter;addon.db.locale=old;ui:Refresh()
end)
check("language aliases retain the original radio choices and fallback cycle",function()
    local old,menu=addon.db.locale,MenuUtil
    for _,code in ipairs({"enGB","esMX","unsupported"})do
        addon.db.locale=code;MenuUtil=nil;ui:OpenLanguageMenu()
        assert(addon.db.locale=="enUS" and ui.language.text=="English")
    end
    MenuUtil=menu;addon.db.locale=old;ui:Refresh()
end)
check("short automatic label localization cannot overwrite a newer preference label",function()
    local old,localize=addon.db.locale,addon.L;local armed=true
    addon.db.locale="auto"
    addon.L=function(key,...)
        if key=="LANGUAGE_AUTO_SHORT"and armed then armed=false;addon.db.locale="ruRU";ui:Refresh()end
        return localize(key,...)
    end
    ui:Refresh();assert(addon.db.locale=="ruRU"and ui.language.text=="Русский")
    addon.L=localize;addon.db.locale=old;ui:Refresh()
end)

check("Effective menu checkmarks preserve raw aliases and unsupported preferences",function()
    local locale=addon.db.locale
    local rows,restore=languageMenuFixture()
    local cases={{"enGB","enUS"},{"esMX","esES"},{"unsupported","enUS"},{"","enUS"}}
    for _,choice in ipairs({"auto","enUS","ruRU","deDE","frFR","esES","itIT","ptBR","koKR","zhCN","zhTW"})do
        cases[#cases+1]={choice,choice}
    end
    for _,case in ipairs(cases)do
        addon.db.locale=case[1];ui:Refresh();assert(ui:OpenLanguageMenu() and #rows()==11)
        local selected=0
        for _,row in ipairs(rows())do
            if row.checked()then selected=selected+1;assert(row.data==case[2])end
        end
        assert(selected==1 and addon.db.locale==case[1])
    end
    restore();addon.db.locale=locale;ui:Refresh()
end)


check("Enter releases search focus without changing query browsing or selection",function()
    local oldSearch,oldText=ui.search,ui.searchBox:GetText()
    local function visibleCards()
        local out={}
        for _,card in ipairs(ui.cards)do
            out[#out+1]={card=card,shown=card.shown,title=card.title.text}
        end
        return out
    end
    for _,query in ipairs({"","  Quest 2  ","Крепость"})do
        ui.searchBox:SetText(query);ui.searchBox.scripts.OnTextChanged(ui.searchBox)
        ui.searchBox:SetFocus()
        local cards=visibleCards()
        local dungeon,quest,engine=ui.dungeon,ui.quest,ui.engine
        local saved,filters=addon.char.selectedDungeon,addon.char.filters
        local range,preparation,unavailable=ui.range,ui.preparation,ui.includeUnavailable
        local hint,notice,placeholder=ui.searchHint.shown,ui.catalogNotice.shown,ui.searchPlaceholder.shown
        assert(type(ui.searchBox.scripts.OnEnterPressed)=="function","Search requires explicit Enter focus release")
        ui.searchBox.scripts.OnEnterPressed(ui.searchBox)
        assert(not ui.searchBox.focused and ui.search==query and ui.searchBox:GetText()==query)
        assert(ui.dungeon==dungeon and ui.quest==quest and ui.engine==engine and addon.char.selectedDungeon==saved)
        assert(addon.char.filters==filters and ui.range==range and ui.preparation==preparation and ui.includeUnavailable==unavailable)
        assert(ui.searchHint.shown==hint and ui.catalogNotice.shown==notice and ui.searchPlaceholder.shown==placeholder)
        for i,state in ipairs(cards)do
            assert(ui.cards[i]==state.card and state.card.shown==state.shown and state.card.title.text==state.title)
        end
        ui.searchBox:SetFocus();ui.searchBox.scripts.OnEscapePressed(ui.searchBox)
        assert(not ui.searchBox.focused and ui.search==query and ui.searchBox:GetText()==query)
    end
    ui.searchBox:SetText("Quest");ui.searchBox.scripts.OnTextChanged(ui.searchBox)
    local handler=ui.searchBox.scripts.OnEnterPressed
    ui.frame:Hide();ui.frame.scripts.OnHide();ui.frame:Show();ui.frame.scripts.OnShow()
    assert(ui.searchBox.scripts.OnEnterPressed==handler and ui.search=="Quest")
    ui.searchBox:SetFocus();handler(ui.searchBox)
    assert(not ui.searchBox.focused and ui.searchBox:GetText()=="Quest")
    ui.search=oldSearch;ui.searchBox:SetText(oldText);ui:Refresh()
end)


check("language setter reentry preserves the newer locale label",function()
    local locale=addon.db.locale;local setter=ui.language.SetText;local armed=true
    addon.db.locale="enUS"
    ui.language.SetText=function(owner,value)
        if armed then armed=false;addon.db.locale="ruRU";ui:Refresh()end
        return setter(owner,value)
    end
    ui:RefreshLanguageLabel()
    assert(not armed and addon.db.locale=="ruRU" and ui.language.text=="Русский","stale English setter overwrote newer Russian label")
    ui.language.SetText=setter;addon.db.locale=locale;ui:Refresh()
end)


check("language setter recovery follows replacement setters profiles and owners",function()
    local database,owner=addon.db,ui.language;local setter,locale=owner.SetText,addon.db.locale
    for _,mode in ipairs({"setter","profile","owner"})do
        addon.db=database;ui.language=owner;owner.SetText=setter;database.locale="enUS"
        local armed,calls=true,0
        owner.SetText=function(control,value)
            if armed then
                armed=false
                if mode=="setter"then
                    owner.SetText=function(target,label)calls=calls+1;return setter(target,label)end
                elseif mode=="profile"then addon.db={locale="ruRU",window=database.window}
                else ui.language=object("Button");ui.language:SetText("new owner")end
                addon.db.locale="ruRU";ui:RefreshLanguageLabel()
            end
            return setter(control,value)
        end
        assert(ui:RefreshLanguageLabel()==false)
        assert(ui.language.text=="Русский" and addon.db.locale=="ruRU" and owner.languageLabelRepair==nil)
        if mode=="setter"then assert(calls==2)end
    end
    addon.db=database;ui.language=owner;owner.SetText=setter;database.locale=locale;ui:Refresh()
end)


check("existing header catalogue detail and input roles update on UI language font transitions",function()
    local locale,getter,creator=addon.db.locale,GetLocale,CreateFont
    local made=0
    CreateFont=function()
        made=made+1
        return{SetFont=function(self,path,size)self.fontPath,self.fontSize,self.family=path,size,nil end,
            GetFont=function(self)return self.fontPath,self.fontSize,""end,
            SetFontObject=function(self,family)self.family=family;self.fontPath=nil end,
            SetFontHeight=function(self,size)self.fontSize=size end,
            SetTextColor=function()end,SetShadowOffset=function()end}
    end
    GetLocale=function()return"enUS"end
    local row=ui:MakeRow(ui.questList,{},1,59)
    for _,code in ipairs({"enUS","ruRU","zhCN","enUS"})do
        addon.db.locale=code;ui:Refresh()
        for _,fs in ipairs({ui.title,ui.heading,ui.capacityStatus,ui.searchPlaceholder,row.title,row.note})do
            if code=="zhCN"then assert(fs.fontPath=="Fonts\\ARKai_T.ttf" and fs.fontFamily==nil)
            else assert(fs.fontPath and fs.fontPath:find("NotoSans-Regular.ttf",1,true))end
        end
        local font=ui.searchBox.fontFamily
        if code=="zhCN"then assert(font.fontPath=="Fonts\\ARKai_T.ttf" and font.family==nil)
        else assert(font.fontPath:find("NotoSans-Regular.ttf",1,true))end
        assert(ui.searchBox.fontSize==14 and row.title.fontSize==17 and row.note.fontSize==14)
    end
    local before=made;ui:Refresh();assert(made==before)
    row:Hide();addon.db.locale,GetLocale,CreateFont=locale,getter,creator;ui:Refresh()
end)

check("main title is repainted after an existing font setter clears its text",function()
    local locale,getter=addon.db.locale,GetLocale
    local asset,family=methods.SetFont,methods.SetFontObject
    local cleared=0
    methods.SetFont=function(self,...)
        local ok=asset(self,...)
        if self==ui.title then self.text="";cleared=cleared+1 end
        return ok
    end
    methods.SetFontObject=function(self,...)
        family(self,...)
        if self==ui.title then self.text="";cleared=cleared+1 end
    end
    GetLocale=function()return"enUS"end
    for _,code in ipairs({"ruRU","zhCN","enUS"})do
        local before=cleared;addon.db.locale=code;ui:Refresh()
        assert(cleared>before,"the actual theme font refresh must hit the pre-existing title")
        assert(ui.title.text==addon.L("TITLE") and ui.title.fontSize==22,"main title must be restored after font changes")
    end
    methods.SetFont,methods.SetFontObject=asset,family
    addon.db.locale,GetLocale=locale,getter;ui:Refresh()
end)


check("from-creation owned text fonts avoid a sticky direct Noto override across English Chinese and Russian",function()
    local locale,getter,creator=addon.db.locale,GetLocale,CreateFont
    local asset,inherit=methods.SetFont,methods.SetFontObject
    local direct=0
    CreateFont=function()
        return{SetFont=function(self,path,size)self.fontPath,self.fontSize,self.family=path,size,nil end,
            GetFont=function(self)return self.fontPath,self.fontSize,""end,
            SetFontObject=function(self,value)self.family=value;self.fontPath=nil end,
            SetFontHeight=function(self,size)self.fontSize=size end,SetTextColor=function()end,SetShadowOffset=function()end}
    end
    methods.SetFont=function(self,...)direct=direct+1;return asset(self,...)end
    GetLocale=function()return"enUS"end;addon.db.locale="enUS"
    local row=ui:MakeRow(ui.questList,{},1,59)
    local atCreation=direct
    assert(atCreation==0 and row.title.fontPath and row.note.fontPath)
    for _,code in ipairs({"zhCN","ruRU","enUS"})do
        addon.db.locale=code;ui:Refresh()
        assert(direct==atCreation,"ordinary FontStrings must inherit owned fonts instead of setting a local asset")
        assert(ui.title.text==addon.L("TITLE")and row.title.fontSize==17 and row.note.fontSize==14)
        if code=="zhCN"then assert(row.title.fontPath=="Fonts\\ARKai_T.ttf" and row.title.fontFamily==nil)
        else assert(row.title.fontPath and row.title.fontPath:find("NotoSans-Regular.ttf",1,true))end
    end
    row:Hide();methods.SetFont,methods.SetFontObject=asset,inherit
    addon.db.locale,GetLocale,CreateFont=locale,getter,creator;ui:Refresh()
end)


check("reading profile enlarges body and row text while measured spacing and header controls retain their geometry",function()
    local locale,quest,dungeon=addon.db.locale,ui.quest,ui.dungeon
    local row=ui:MakeRow(ui.questList,{},1,59)
    assert(row.title.fontSize==17 and row.note.fontSize==14)
    row.title:SetText("Measured wrapped title");row.note:SetText("Measured wrapped note")
    measurement=function(fs)if fs==row.title then return 36 elseif fs==row.note then return 42 end;return 18 end
    local bottom=ui:LayoutRow(row,59,0)
    assert(row.note.point[3]==-(7+36+4) and row.height==96 and bottom==100)
    measurement=nil
    for _,code in ipairs({"enUS","ruRU","zhCN","zhTW","koKR"})do
        addon.db.locale=code;showDetail(2)
        local body=0
        for _,fs in ipairs(ui.details)do if fs.shown and fs.detailStyle=="body"then body=body+1;assert(fs.fontSize==15)end end
        assert(body>0 and ui.title.fontSize==22 and ui.heading.fontSize==26 and ui.searchBox.fontSize==14)
        assert(ui.footer==nil and ui.summary==nil and ui.coverage==nil)
    end
    row:Hide();addon.db.locale,ui.quest,ui.dungeon=locale,quest,dungeon;ui:Refresh()
end)

check("reading profile preserves ten locale wrapping and short viewport scroll boundaries",function()
    local locale,description,definition,quest,dungeon=addon.db.locale,addon.Description,addon.quests[2],ui.quest,ui.dungeon
    local width,height,viewport,creator=screenWidth,screenHeight,ui.detailScroll:GetHeight(),CreateFont
    CreateFont=function()
        return{SetFont=function(self,path,size)self.fontPath,self.fontSize,self.family=path,size,nil end,
            GetFont=function(self)return self.fontPath,self.fontSize,""end,
            SetFontObject=function(self,family)self.family=family;self.fontPath=nil end,
            SetFontHeight=function(self,size)self.fontSize=size end,
            SetTextColor=function()end,SetShadowOffset=function()end}
    end
    addon.quests[2]={id=2,minLevel=1,requirementsKnown=true}
    local prose="Long measured quest narrative"
    local row=ui:MakeRow(ui.questList,{},1,59)
    row.title:SetText("Long wrapped title");row.note:SetText("Long wrapped supporting note")
    local titleHeight,noteHeight=72,90
    measurement=function(fs)
        if fs==row.title then return titleHeight elseif fs==row.note then return noteHeight
        elseif fs.text==prose then return 1200 end
        return 18
    end
    local count=0
    for code in pairs(addon.locales)do
        count=count+1;addon.db.locale=code
        local cjk=code=="zhCN"or code=="zhTW"or code=="koKR"
        titleHeight,noteHeight=cjk and 84 or 72,cjk and 96 or 90
        local bottom=ui:LayoutRow(row,59,0)
        local expected=7+titleHeight+4+noteHeight+7
        assert(row.note.point[3]==-(7+titleHeight+4)and row.height==expected and bottom==expected+4)
        addon.Description=function()return prose end;showStory(2);ui.detailScroll:SetHeight(180)
        assert(ui.detail.height>=1200 and ui.detailScroll.ScrollBar.shown and ui.detailScroll.ScrollBar.maximum>1000)
        local found=false
        for _,fs in ipairs(ui.details)do
            if fs.shown and fs.text==prose then found=true;assert(fs.fontSize==14 and fs.measuredHeight==1200)end
        end
        assert(found)
        ui.detailScroll:SetHeight(ui.detail.height);assert(not ui.detailScroll.ScrollBar.shown)
        ui.detailScroll:SetHeight(ui.detail.height-1)
        assert(ui.detailScroll.ScrollBar.shown and ui.detailScroll.ScrollBar.maximum==1)
    end
    assert(count==10)
    screenWidth,screenHeight=640,360;ui:Fit()
    assert(ui.frame.scale*700<=360*.92+.001 and ui.frame.scale*1100<=640*.92+.001)
    row:Hide();measurement=nil
    addon.db.locale,addon.Description,addon.quests[2],ui.quest,ui.dungeon=locale,description,definition,quest,dungeon
    screenWidth,screenHeight,CreateFont=width,height,creator
    ui.detailScroll:SetHeight(viewport);ui:Fit();ui:Refresh()
end)

local function sourceSearchFixture()
    local f=targetSearchFixture()
    local finish=f.finish
    f.provider,f.navigation,f.character,f.shown=addon.QuestSourceSearchTerms,addon.Navigation,addon.char,ui.frame.shown
    f.calls,f.terms,f.navigationCalls={},{},0
    addon.quests[31001].start={npcID=801,name="Recorded Priestess",zoneName="Recorded Ashenvale"}
    addon.quests[31001].finish={npcID=802,name="Recorded Turn-in",zoneName="Recorded Ashenvale"}
    addon.quests[31002].start={itemID=900,name="Unindexed starter",
        containerSource={objectID=901,name="Recorded Chest",zoneName="Recorded Hinterland"},
        dropSources={{npcID=803,name="Recorded Dropper",locationName="Recorded Cavern"}}}
    addon.QuestSourceSearchTerms=function(q)
        if q then f.calls[q.id]=(f.calls[q.id]or 0)+1 end
        local terms,current,proof=f.provider(q)
        if q then f.terms[q.id]=terms end
        return terms,current,proof
    end
    addon.Navigation={Start=function()f.navigationCalls=f.navigationCalls+1 end,Map=function()f.navigationCalls=f.navigationCalls+1 end}
    ui.frame:Show()
    function f:finish()
        addon.QuestSourceSearchTerms,addon.Navigation,addon.char=self.provider,self.navigation,self.character
        finish(self);ui.frame:SetShown(self.shown)
    end
    return f
end
check("Recorded NPC and place matches keep original quest cues precedence and effect-free per-quest memoization",function()
    local f=sourceSearchFixture()
    local quest,dungeon,engine,choice=ui.quest,ui.dungeon,ui.engine,addon.char.choices
    f:search("");assert(next(f.calls)==nil)
    f:search("Source target");assert(next(f.calls)==nil)
    f:search("RECORDED PRIESTESS");local rows=f:cards()
    assert(#rows==2 and f.calls[31001]==1 and not f.calls[31002])
    for _,row in ipairs(rows)do
        assert(row.matchQuestID==31001 and row.note.text:find(addon.L("SEARCH_NPC_MATCH","Recorded Priestess"),1,true))
        assert(row.note.text:find(addon.L("SEARCH_QUEST_MATCH","Source target"),1,true))
    end
    f:search("Recorded Chest");assert(#f:cards()==1 and f:cards()[1].matchQuestID==31002)
    assert(f:cards()[1].note.text:find(addon.L("SEARCH_PLACE_MATCH","Recorded Chest"),1,true))
    f:search("Recorded Dropper");assert(#f:cards()==1 and f:cards()[1].matchQuestID==31002)
    f:search("Recorded Turn-in");assert(#f:cards()==2 and f:cards()[1].matchQuestID==31001)
    f:search("Unindexed starter");assert(#f:cards()==0)
    assert(ui.quest==quest and ui.dungeon==dungeon and ui.engine==engine and addon.char.choices==choice and f.navigationCalls==0)
    f:finish()
end)
check("Recorded-source inspection opens only the explicit associated target and preserves ordinary card browsing",function()
    local f=sourceSearchFixture();f:search("Recorded Priestess")
    local row=f:cards()[1];addon.QuestName=f.questName;row.scripts.OnClick()
    assert(ui.dungeon.key=="target-a"and ui.quest==nil)
    f:search("Recorded Priestess");ui.catalogInspectButtons[1].scripts.OnClick()
    assert(ui.dungeon.key=="target-a"and ui.quest==31001 and f.navigationCalls==0)
    f:finish()
end)
check("Source matches reject changed source DTO helper locale character and hidden inspection callbacks",function()
    for _,mode in ipairs({"source","term","list","helper","locale","character","hidden"})do
        local f=sourceSearchFixture();f:search("Recorded Priestess")
        local click=ui.catalogInspectButtons[1].scripts.OnClick
        local quest,dungeon=ui.quest,ui.dungeon
        if mode=="source"then addon.quests[31001].start.name="Changed Priestess"
        elseif mode=="term"then f.terms[31001][1].text="Changed term"
        elseif mode=="list"then table.remove(f.terms[31001],1)
        elseif mode=="helper"then addon.QuestSourceSearchTerms=f.provider
        elseif mode=="locale"then addon.db.locale="ruRU"
        elseif mode=="character"then addon.char={}
        else ui.frame:Hide()end
        click();assert(ui.quest==quest and ui.dungeon==dungeon and f.navigationCalls==0)
        f:finish()
    end
end)
check("Source search falls back to titles for missing third capability and malformed bounded term payloads",function()
    for _,mode in ipairs({"missing","kind","oversize","sparse","text","key"})do
        local f=sourceSearchFixture()
        addon.QuestSourceSearchTerms=function()
            local terms={{text="Malformed source needle",kind="npc"}}
            if mode=="missing"then return terms,function()return true end
            elseif mode=="kind"then terms[1].kind="giver"
            elseif mode=="oversize"then terms[1].text=string.rep("x",2001)
            elseif mode=="sparse"then terms[3]=terms[1]
            elseif mode=="text"then terms[1].text={}
            else terms.invalid=true end
            return terms,function()return true end,function()return true end
        end
        f:search("Malformed source needle");assert(#f:cards()==0)
        f:search("Source target");assert(#f:cards()==2 and f:cards()[1].matchQuestID==31001)
        f:finish()
    end
end)
check("Valid empty source ownership expires when a later source checker adds an earlier matching source",function()
    local f=sourceSearchFixture();addon.quests[31001].start,addon.quests[31001].finish=nil,nil
    local provider=f.provider;local checked=0
    addon.QuestSourceSearchTerms=function(q)
        local terms,current,proof=provider(q)
        if q and q.id==31002 then
            return terms,function()
                checked=checked+1
                if checked==2 then addon.quests[31001].start={npcID=804,name="Added Source"}end
                return current()
            end,proof
        end
        return terms,current,proof
    end
    f:search("Added Source");assert(checked>=2 and #f:cards()==0)
    f:search("Added Source");assert(#f:cards()==2 and f:cards()[1].matchQuestID==31001)
    assert(f.navigationCalls==0);f:finish()
end)
check("Source hint localization and setter reentry preserve a complete newer query and handlers",function()
    for _,mode in ipairs({"localize","text","script"})do
        local f=sourceSearchFixture();f:search("Recorded Priestess")
        local row=f:cards()[1];local localize=addon.L;local setter=row.note.SetText;local script=row.SetScript;local armed=true
        if mode=="localize"then
            addon.L=function(key,...)
                local value=localize(key,...)
                if armed and key=="SEARCH_NPC_MATCH"then armed=false;f:search("Recorded Ashenvale")end
                return value
            end
        elseif mode=="text"then
            row.note.SetText=function(self,value)
                if armed then armed=false;f:search("Recorded Ashenvale")end
                return setter(self,value)
            end
        else
            row.SetScript=function(self,key,value)
                if armed and key=="OnClick"then armed=false;f:search("Recorded Ashenvale")end
                return script(self,key,value)
            end
        end
        f:search("Recorded Priestess")
        row.note.SetText,row.SetScript,addon.L=setter,script,localize
        assert(not armed and ui.search=="Recorded Ashenvale"and #f:cards()==2)
        assert(f:cards()[1].note.text:find(addon.L("SEARCH_PLACE_MATCH","Recorded Ashenvale"),1,true))
        assert(not f:cards()[1].note.text:find(addon.L("SEARCH_NPC_MATCH","Recorded Priestess"),1,true))
        addon.QuestName=f.questName;ui.catalogInspectButtons[1].scripts.OnClick();assert(ui.quest==31001 and f.navigationCalls==0)
        f:finish()
    end
end)
check("Recorded-source hints wrap in ten locales without changing filters or inferring quest readiness",function()
    local f=sourceSearchFixture();local range,preparation,include=ui.range,ui.preparation,ui.includeUnavailable
    local long=string.rep("Recorded source ",20);addon.quests[31001].start.name=long
    measurement=function(fs)if fs.text and fs.text:find(long,1,true)then return 126 end;return 18 end
    local count=0
    for code in pairs(addon.locales)do
        count=count+1;addon.db.locale=code;f:search("Recorded source")
        local rows=f:cards();assert(#rows==2 and rows[1].height>=162 and -rows[2].point[3]>=-rows[1].point[3]+rows[1].height)
        assert(rows[1].note.text:find(addon.L("SEARCH_NPC_MATCH",long),1,true))
        assert(ui.range==range and ui.preparation==preparation and ui.includeUnavailable==include and addon.quests[31001].requirementsKnown==false)
    end
    assert(count==10 and f.navigationCalls==0);measurement=nil;f:finish()
end)
check("Expired source cleanup cannot hide or clear handlers from a newer complete source query",function()
    for _,method in ipairs({"Hide","SetScript"})do
        local f=sourceSearchFixture();f:search("Recorded Priestess")
        local row=f:cards()[1];local click=ui.catalogInspectButtons[1].scripts.OnClick
        local target=method=="Hide"and row or ui.catalogInspectButtons[1]
        local original,armed=target[method],true
        target[method]=function(self,...)
            local event,callback=...
            if armed and(method=="Hide"or(event=="OnClick"and callback==nil))then
                armed=false;f:search("Recorded Ashenvale")
            end
            return original(self,...)
        end
        addon.quests[31001].start.name="Changed before expired click"
        click();target[method]=original
        assert(not armed and ui.search=="Recorded Ashenvale"and #f:cards()==2 and row.shown)
        assert(row.note.text:find(addon.L("SEARCH_PLACE_MATCH","Recorded Ashenvale"),1,true))
        assert(row.scripts.OnClick and ui.catalogInspectButtons[1].scripts.OnClick)
        addon.QuestName=f.questName;ui.catalogInspectButtons[1].scripts.OnClick()
        assert(ui.dungeon.key=="target-a"and ui.quest==31001 and f.navigationCalls==0)
        f:finish()
    end
end)

check("Source scan rejects an expired later dungeon before its name getter",function()
    local f=targetSearchFixture();local first,second=addon.dungeons[1],addon.dungeons[2];local seen={}
    addon.DungeonName=function(d)
        seen[d]=(seen[d]or 0)+1
        if d==first then addon.dungeons[2]={key="replacement",name="Replacement dungeon",minLevel=1,maxLevel=60,quests={}}end
        return d.name
    end
    f:search("nonmatching old scope");assert(not seen[second]);f:finish()
end)
check("Source scan guards changed target definitions and names before another cached read",function()
    for _,kind in ipairs({"target","definition","name","dungeon"})do
        local f=targetSearchFixture();local reads=0;local oldClick=f:cards()[1].scripts.OnClick;local dungeon,quest=ui.dungeon,ui.quest
        addon.CachedQuestName=function()
            reads=reads+1
            if reads==1 then
                if kind=="target"then addon.dungeons[1].quests[2]=31003
                elseif kind=="definition"then addon.quests[31002]={id=31002,name="Replaced",minLevel=1}
                elseif kind=="name"then addon.quests[31002].name="New source name"
                else addon.dungeons[1].name="Renamed dungeon"end
            end
        end
        f:search("unmatched native title");assert(reads==1);oldClick();assert(ui.dungeon==dungeon and ui.quest==quest);f:finish()
    end
end)
check("Source scan rejects replaced members before calling their source helper",function()
    for _,kind in ipairs({"target","definition","name"})do
        local f=sourceSearchFixture();local calls=0;local provider=f.provider
        addon.QuestSourceSearchTerms=function(q)
            calls=calls+1
            if calls==1 then
                if kind=="target"then addon.dungeons[1].quests[2]=31003
                elseif kind=="definition"then addon.quests[31002]={id=31002,name="Replacement",minLevel=1}
                else addon.quests[31002].name="Changed source name"end
            end
            return provider(q)
        end
        f:search("nonmatching source needle");assert(calls==1);f:finish()
    end
end)

check("Main close styling is optional and preserves native close tooltip geometry Escape registration and reopening",function()
    for _,mode in ipairs({"style","false","throw","missing"})do
        local fresh={};for key,value in pairs(addon)do fresh[key]=value end
        fresh.listeners={};local calls,tooltip=0,0;local close,nativeClick,nativeEnter
        fresh.Theme={}
        if mode~="missing"then fresh.Theme.StyleCloseButton=function(button)
            calls=calls+1;assert(button==close and button.scripts.OnClick==nativeClick and button.scripts.OnEnter==nativeEnter)
            assert(button.point[1]=="TOPRIGHT"and button.point[2]==-4 and button.point[3]==-4)
            if mode=="throw"then error("optional style unavailable")end
            return mode=="style"
        end end
        local create,global,specialCount=CreateFrame,_G.DungeonProWindow,#UISpecialFrames
        CreateFrame=function(kind,name,parent,template)
            local result=create(kind,name,parent,template)
            if template=="UIPanelCloseButton"then
                close=result;nativeClick=function()parent:Hide()end;nativeEnter=function()tooltip=tooltip+1 end
                result:SetScript("OnClick",nativeClick);result:SetScript("OnEnter",nativeEnter)
            end
            return result
        end
        assert(loadfile("UI/QuestHistory.lua"))("DungeonPro",fresh)
        assert(loadfile("UI/PreparationOverview.lua"))("DungeonPro", fresh)
        assert(loadfile("UI/Window.lua"))("DungeonPro",fresh);fresh.UI:Create();CreateFrame=create
        local current=fresh.UI;current.search="retained close query";current.quest=ui.quest;current.dungeon=ui.dungeon
        local selected,dungeon=current.quest,current.dungeon
        assert(calls==(mode=="missing"and 0 or 1)and close.scripts.OnClick==nativeClick and close.scripts.OnEnter==nativeEnter)
        assert(UISpecialFrames[#UISpecialFrames]=="DungeonProWindow")
        close.scripts.OnEnter();assert(tooltip==1)
        current.frame:Show();close.scripts.OnClick();assert(not current.frame.shown)
        current:Toggle();current:Refresh()
        assert(current.frame.shown and current.search=="retained close query"and current.quest==selected and current.dungeon==dungeon)
        _G.DungeonProWindow=global
        for index=#UISpecialFrames,specialCount+1,-1 do UISpecialFrames[index]=nil end
    end
end)

check("Compact overview keeps generic icons small and gives actual or legacy art the full detail width",function()
    local paint,quest,dungeon,engine=addon.PaintDungeonArt,ui.quest,ui.dungeon,ui.engine
    local data={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",data)
    local keys={drowned=true,kroldok=true,alcaz=true,blackmaw=true,shapers=true}
    local genericCount=0
    for _,d in ipairs(data.dungeons)do if keys[d.key]then
        genericCount=genericCount+1;ui.quest=nil;ui.dungeon=d
        addon.PaintDungeonArt=function(t)t:SetTexture("generic");t:Show();return true,"generic"end
        ui:RefreshDetail();assert(ui.overviewArt.width==48 and ui.overviewArt.height==48 and ui.overviewArt.point[2]==(ui.detail:GetWidth()-56)/2+4)
        local compactHeight=ui.detail.height
        addon.PaintDungeonArt=function(t)t:SetTexture(123);t:Show();return true,"art"end
        ui:RefreshDetail();assert(ui.overviewArt.width==ui.detail:GetWidth()-8 and ui.overviewArt.height==ui.detail:GetWidth()-8 and ui.overviewArt.point[2]==4 and ui.detail.height==compactHeight+ui.detail:GetWidth()-56)
        addon.PaintDungeonArt=function(t)t:SetTexture("legacy");t:Show();return true end
        ui:RefreshDetail();assert(ui.overviewArt.width==ui.detail:GetWidth()-8 and ui.detail.height==compactHeight+ui.detail:GetWidth()-56)
        addon.PaintDungeonArt=function(t)t:Hide();return false end
        ui:RefreshDetail();assert(not ui.overviewArt.shown and ui.detail.height==compactHeight-56)
    end end
    assert(genericCount==5)
    addon.PaintDungeonArt=paint;ui.quest,ui.dungeon,ui.engine=quest,dungeon,engine
end)

local function coalescedSearchFixture()
    local f=targetSearchFixture()
    local timer,refresh=C_Timer,ui.RefreshDungeons
    f.callbacks={};f.renders=0
    C_Timer={After=function(delay,callback)
        assert(delay==0.15);f.callbacks[#f.callbacks+1]=callback
    end}
    ui.RefreshDungeons=function(self)f.renders=f.renders+1;return refresh(self)end
    function f:input(value,userInput)
        ui.searchBox:SetText(value);ui.searchBox.scripts.OnTextChanged(ui.searchBox,userInput)
    end
    function f:drain()
        local callbacks=self.callbacks;self.callbacks={}
        for _,callback in ipairs(callbacks)do callback()end
    end
    local finish=f.finish
    function f:finish()
        C_Timer,ui.RefreshDungeons=timer,refresh;finish(self)
    end
    return f
end
check("User search edits coalesce to one latest query while programmatic edits remain immediate",function()
    local f=coalescedSearchFixture()
    local quest,dungeon,range=ui.quest,ui.dungeon,ui.range
    for _,query in ipairs({"S","So","Sou","Sour","Sourc","Source","Source target"})do
        f:input(query,true)
        assert(f.renders==0 and not ui.searchPlaceholder.shown and ui.clearSearch.enabled)
    end
    assert(f.renders==0 and ui.search=="Source target")
    f:drain();assert(f.renders==1 and #f:cards()==2)
    assert(ui.quest==quest and ui.dungeon==dungeon and ui.range==range)
    f:input("Other source",true);assert(f.renders==1);f:drain();assert(f.renders==2 and #f:cards()==1)
    f:input("Alpha",false);assert(f.renders==3 and #f:cards()==1)
    f:input("Beta",nil);assert(f.renders==4 and #f:cards()==1)
    f:input("",true)
    assert(f.renders==4 and ui.searchPlaceholder.shown and not ui.clearSearch.enabled)
    f:drain();assert(f.renders==5 and #f:cards()==3)
    f:finish()
end)
check("Enter flushes pending search once and clear immediately invalidates earlier callbacks",function()
    local f=coalescedSearchFixture()
    ui.searchBox:SetFocus();f:input("Other source",true)
    ui.searchBox.scripts.OnEnterPressed(ui.searchBox)
    assert(f.renders==1 and not ui.searchBox.focused and #f:cards()==1)
    f:drain();assert(f.renders==1)
    f:input("Source target",true);ui.clearSearch.scripts.OnClick()
    assert(ui.search=="" and f.renders==2 and #f:cards()==3)
    f:drain();assert(f.renders==2)
    f:finish()
end)
check("Hidden and directly refreshed search callbacks cannot publish obsolete queries",function()
    local f=coalescedSearchFixture()
    f:input("Source target",true)
    ui.frame:Hide();ui.frame.scripts.OnHide(ui.frame)
    ui.frame:Show();f:drain();assert(f.renders==0)
    local questName=addon.QuestName;addon.QuestName=f.questName
    ui.frame.scripts.OnShow(ui.frame);addon.QuestName=questName
    assert(f.renders==1 and #f:cards()==2)
    f:input("Other source",true);ui:RefreshDungeons()
    assert(f.renders==2 and #f:cards()==1);f:drain();assert(f.renders==2)
    f:input("Alpha",true);f:input("Beta",false)
    assert(f.renders==3 and ui.search=="Beta");f:drain();assert(f.renders==3 and #f:cards()==1)
    f:finish()
end)
check("Optional search schedulers fall back safely without duplicate inline or stale renders",function()
    for _,kind in ipairs({"missing","throw","inline","inlineThrow","queuedThrow"})do
        local f=coalescedSearchFixture()
        if kind=="missing"then C_Timer=nil
        elseif kind=="throw"then C_Timer={After=function()error("unavailable")end}
        elseif kind=="inline"then C_Timer={After=function(_,callback)callback()end}
        elseif kind=="inlineThrow"then C_Timer={After=function(_,callback)callback();error("completed then failed")end}
        else C_Timer={After=function(_,callback)f.callbacks[#f.callbacks+1]=callback;error("queued then failed")end}end
        f:input("Source target",true)
        assert(f.renders==1 and #f:cards()==2,kind);f:drain();assert(f.renders==1,kind)
        f:finish()
    end
end)

check("A newer user edit queued during a catalogue callback survives the earlier flush",function()
    local f=coalescedSearchFixture();local getter=addon.DungeonName;local armed=true
    addon.DungeonName=function(d)
        if armed then armed=false;f:input("Beta",true)end
        return d.name
    end
    f:input("Alpha",true);f:drain()
    assert(not armed and ui.search=="Beta"and f.renders==1 and #f.callbacks==1)
    f:drain();assert(f.renders==2 and #f:cards()==1 and f:cards()[1].title.text=="Beta dungeon")
    f:drain();assert(f.renders==2);addon.DungeonName=getter;f:finish()
end)

check("Exact quest ID search uses only direct targets and identifies same-name variants without hydration",function()
    local f=targetSearchFixture();local provider=addon.QuestSourceSearchTerms;local sourceCalls,cachedCalls=0,0
    addon.quests[31002].name="Source target";addon.dungeons[3].name="31001 numeric dungeon"
    addon.QuestSourceSearchTerms=function(...)sourceCalls=sourceCalls+1;return provider(...)end
    addon.CachedQuestName=function()cachedCalls=cachedCalls+1 end
    local quest,dungeon,range=ui.quest,ui.dungeon,ui.range
    f:search(" 31001 ");local cards=f:cards();assert(#cards==2)
    for _,row in ipairs(cards)do
        assert(row.matchQuestID==31001 and row.note.text:find("Source target (#31001)",1,true))
    end
    assert(ui.quest==quest and ui.dungeon==dungeon and ui.range==range)
    f:search("31002");assert(#f:cards()==1 and f:cards()[1].matchQuestID==31002)
    for _,query in ipairs({"3100","31003","999999"})do f:search(query);assert(#f:cards()==0)end
    assert(sourceCalls==0 and cachedCalls==2,"only the two distinct matching IDs read pure cached titles")
    f:search("31001");local inspect=ui.catalogInspectButtons[1]
    assert(inspect.shown and inspect.questID==31001)
    addon.QuestName=f.questName;inspect.scripts.OnClick()
    assert(ui.quest==31001 and ui.dungeon.key=="target-a")
    addon.QuestSourceSearchTerms=provider;f:finish()
end)
check("ID results retain level filtering while ordinary names and optional parser fallback keep literal search",function()
    local f=targetSearchFixture();local parser=addon.SearchQuestID
    addon.dungeons[3].quests={31001};ui.range=true
    f:search("31001");assert(#f:cards()==2 and ui.range)
    ui.range=false;f:search("31001");assert(#f:cards()==3)
    f:search("Source target");assert(#f:cards()==3 and not f:cards()[1].note.text:find("(#31001)",1,true))
    addon.quests[31001].name="Numeric 31001 literal";addon.SearchQuestID=nil
    f:search("31001");assert(#f:cards()==3)
    local restricted={};local checker=issecretvalue
    issecretvalue=function(value)return rawequal(value,restricted)end
    for _,bad in ipairs({-1,1.5,math.huge,9007199254740992,restricted})do
        addon.SearchQuestID=function()return bad end
        f:search("31001");assert(#f:cards()==3)
    end
    issecretvalue=checker;addon.SearchQuestID=parser;f:finish()
end)
check("Exact ID cues retain all safe-integer digits and explicit inspection bypasses title matching",function()
    local f=targetSearchFixture();local id=9007199254740991
    addon.quests[id]={id=id,name="Maximum safe ID",minLevel=1,requirementsKnown=false}
    addon.dungeons[1].quests={id};addon.dungeons[2].quests={}
    f:search("9007199254740991");local cards=f:cards()
    assert(#cards==1 and cards[1].matchQuestID==id)
    assert(cards[1].note.text:find("Maximum safe ID (#9007199254740991)",1,true))
    local inspect=ui.catalogInspectButtons[1];assert(inspect.shown and inspect.questID==id)
    addon.QuestName=f.questName;inspect.scripts.OnClick();assert(ui.quest==id)
    f:finish()
end)
check("ID parser callbacks cannot publish expired query catalogue or definition identities",function()
    for _,kind in ipairs({"query","nested","parser","target","definitionID"})do
        local f=targetSearchFixture();local parser=addon.SearchQuestID;local armed=true
        local oldClick=f:cards()[1].scripts.OnClick;local dungeon,quest=ui.dungeon,ui.quest
        addon.SearchQuestID=function(value)
            local id=parser(value)
            if armed then
                armed=false
                if kind=="query"then ui.search="Beta"
                elseif kind=="nested"then f:search("Beta")
                elseif kind=="parser"then addon.SearchQuestID=parser
                elseif kind=="target"then addon.dungeons[1].quests[1]=31002
                else addon.quests[31001].id=31002 end
            end
            return id
        end
        f:search("31001");assert(not armed)
        if kind=="nested"then assert(ui.search=="Beta"and #f:cards()==1 and f:cards()[1].title.text=="Beta dungeon")end
        oldClick();assert(ui.dungeon==dungeon and ui.quest==quest)
        addon.SearchQuestID=parser;f:finish()
    end
end)

local function searchScrollFixture()
    local f=targetSearchFixture()
    addon.dungeons={}
    for index=1,16 do
        addon.dungeons[index]={key="reading-"..index,name="Alpha Beta dungeon "..index,minLevel=1,maxLevel=60,quests={}}
    end
    f:search("")
    return f
end
check("Changed committed search starts new catalogue results at top while equivalent queries preserve reading",function()
    local f=searchScrollFixture()
    local dungeon,quest,detail=ui.dungeon,ui.quest,ui.detailScroll:GetVerticalScroll()
    ui.catalogScroll:SetVerticalScroll(300)
    f:search("Alpha")
    assert(#f:cards()==16 and ui.catalogScroll:GetVerticalScrollRange()>300)
    assert(ui.catalogScroll:GetVerticalScroll()==0,"a different search must show the beginning of its results")
    ui.catalogScroll:SetVerticalScroll(300)
    f:search("  aLPHa  ")
    assert(ui.catalogScroll:GetVerticalScroll()==300,"case and trim changes retain the same result reading")
    ui:RefreshDungeons()
    addon.db.locale="ruRU";ui:RefreshDungeons()
    assert(ui.catalogScroll:GetVerticalScroll()==300,"same-query and localization refreshes preserve reading")
    f:search("Beta");assert(ui.catalogScroll:GetVerticalScroll()==0)
    ui.catalogScroll:SetVerticalScroll(300)
    f:search("");assert(ui.catalogScroll:GetVerticalScroll()==0)
    assert(ui.dungeon==dungeon and ui.quest==quest and ui.detailScroll:GetVerticalScroll()==detail)
    f:finish()
end)
check("First catalogue render does not reset an existing initial reading offset",function()
    local f=searchScrollFixture()
    local fresh={};for key,value in pairs(addon)do fresh[key]=value end
    fresh.listeners={}
    local global,specialCount=_G.DungeonProWindow,#UISpecialFrames
    assert(loadfile("UI/QuestHistory.lua"))("DungeonPro",fresh)
    assert(loadfile("UI/PreparationOverview.lua"))("DungeonPro", fresh)
    assert(loadfile("UI/Window.lua"))("DungeonPro",fresh)
    fresh.UI:Create();fresh.UI.range=false;fresh.UI.search="Alpha"
    fresh.UI.catalogScroll:SetVerticalScroll(300)
    local writes=fresh.UI.catalogScroll.scrollWrites
    fresh.UI:RefreshDungeons()
    assert(fresh.UI.catalogScroll:GetVerticalScrollRange()>300)
    assert(fresh.UI.catalogScroll:GetVerticalScroll()==300 and fresh.UI.catalogScroll.scrollWrites==writes)
    _G.DungeonProWindow=global
    for index=#UISpecialFrames,specialCount+1,-1 do UISpecialFrames[index]=nil end
    f:finish()
end)
check("Expired and nested search renders cannot reset a newer catalogue reading position",function()
    for _,mode in ipairs({"expired","nested","layout"})do
        local f=searchScrollFixture();ui.catalogScroll:SetVerticalScroll(300)
        local provider=addon.DungeonName;local armed=true
        local height=ui.catalog.SetHeight
        local function interrupt()
            if not armed then return end
            armed=false
            if mode=="expired"then ui.search="Beta"
            else f:search("Beta");ui.catalogScroll:SetVerticalScroll(125)end
        end
        if mode=="layout"then ui.catalog.SetHeight=function(self,value)interrupt();height(self,value)end
        else addon.DungeonName=function(d)local name=provider(d);interrupt();return name end end
        f:search("Alpha");assert(not armed)
        assert(ui.catalogScroll:GetVerticalScroll()==(mode=="expired"and 300 or 125))
        ui.catalog.SetHeight=height;addon.DungeonName=provider
        f:search("Alpha");assert(ui.catalogScroll:GetVerticalScroll()==0,"aborted searches cannot commit their query key")
        f:finish()
    end
end)

local function primaryHandoffFixture(mapOnlyGiver)
    local f={navigation=addon.Navigation,hide=ui.frame.Hide,search=ui.search,quest=ui.quest,dungeon=ui.dungeon,
        definition=addon.quests[35001],context=addon.Context,character=addon.char,root=addon.UI,hidden=0}
    addon.Context=function()return{level=60,active=function()return false end,completed=function()return false end}end
    addon.quests[35001]={id=35001,minLevel=1,requirementsKnown=true,start=mapOnlyGiver and
        {mapID=1436,name="Known map-only giver"}or{mapID=1436,x=56.3,y=47.5,name="Known giver"}}
    ui.frame:Show();ui.search="retained navigation query";showDetail(35001)
    ui.frame.Hide=function(frame)
        f.hidden=f.hidden+1;f.hide(frame)
        frame.scripts.OnHide(frame)
    end
    function f:finish()
        ui.frame.Hide=self.hide;addon.Navigation=self.navigation;addon.quests[35001]=self.definition;addon.Context=self.context
        addon.char=self.character;addon.UI=self.root
        ui.search,ui.quest,ui.dungeon=self.search,self.quest,self.dungeon
        ui.frame:Show();ui:Refresh()
    end
    return f
end
check("Accepted primary navigation keeps the movable planner open and only explicit closing runs its hide lifecycle",function()
    for _,route in ipairs({"giver","giver-map"})do
        local f=primaryHandoffFixture(route=="giver-map")
        local action,giver,dungeon,quest=ui.action,ui.giverAction,ui.dungeon,ui.quest
        local history=ui.detailHistory;ui.detailOffsets={ [2]=70 };ui.detailOffsetsOwner=history
        local calls=0
        addon.Navigation={Start=function(value)
            calls=calls+1;assert(value==giver);return true
        end,Map=function(value)
            calls=calls+1;assert(value==giver.place);return true,false
        end}
        ui.giver.scripts.OnClick()
        assert(calls==1 and f.hidden==0 and ui.frame.shown,"accepted primary navigation must keep preparation open")
        assert(ui.search=="retained navigation query"and ui.dungeon==dungeon and ui.quest==quest)
        assert(ui.detailOffsets and ui.detailOffsets[2]==70 and ui.detailHistory==history,"navigation cannot clear reading state")
        ui.frame:Hide();ui.frame.scripts.OnHide(ui.frame)
        assert(ui.detailOffsets==nil and f.hidden==1,"only explicit closing runs normal OnHide cleanup")
        ui.frame:Show();ui.frame.scripts.OnShow(ui.frame)
        assert(ui.frame.shown and ui.search=="retained navigation query"and ui.dungeon==dungeon and ui.quest==quest)
        assert(calls==1,"reopening cannot start navigation again")
        f:finish()
    end
end)
check("Failed throwing unavailable and restricted primary navigation acknowledgements leave the planner open",function()
    for _,mode in ipairs({"false","nil","throw","missing","restricted"})do
        local f=primaryHandoffFixture();local calls=0;local checker=issecretvalue
        local result={restricted=true}
        local method=function()
            calls=calls+1
            if mode=="throw"then error("navigation unavailable")end
            if mode=="false"then return false elseif mode=="restricted"then return result end
        end
        if mode=="restricted"then issecretvalue=function(value)if value==result then return true end;return checker and checker(value)or false end end
        addon.Navigation=mode=="missing"and{}or{Start=method}
        ui.giver.scripts.OnClick()
        assert(calls==(mode=="missing"and 0 or 1)and f.hidden==0 and ui.frame.shown)
        issecretvalue=checker;f:finish()
    end
end)
check("Accepted primary navigation cannot hide a newer card engine owner or helper context",function()
    for _,mode in ipairs({"quest","engine","character","generation","action","place","helper","navigation","owner","current"})do
        local f=primaryHandoffFixture();local engine,generation=ui.engine,ui.rewardGeneration
        local action,place=ui.action,ui.action.place;local getter=engine.Current;local calls=0
        addon.Navigation={Start=function()
            calls=calls+1
            if mode=="quest"then showDetail(3)
            elseif mode=="engine"then ui.engine={}
            elseif mode=="character"then addon.char={}
            elseif mode=="generation"then ui.rewardGeneration={}
            elseif mode=="action"then ui.action={}
            elseif mode=="place"then action.place={mapID=1436}
            elseif mode=="helper"then addon.Navigation.Start=function()return true end
            elseif mode=="navigation"then addon.Navigation={Start=function()return true end}
            elseif mode=="owner"then addon.UI={frame=ui.frame}
            else engine.Current=function()return false end end
            return true
        end}
        ui.giver.scripts.OnClick()
        assert(calls==1 and f.hidden==0 and ui.frame.shown,"a stale accepted request cannot hide newer preparation")
        action.place=place;engine.Current=getter;ui.engine=engine;ui.rewardGeneration=generation
        f:finish()
    end
end)

local function manualLocationHandoffFixture(route)
    local f=primaryHandoffFixture();local finish=f.finish
    if route=="waypoint"then f.waypoint=clientWaypointFixture()end
    f.calls=0;f.accepted=true
    addon.Navigation={Start=function(action)
        f.calls=f.calls+1;f.visited=action
        if f.request then return f.request(action)end;return f.accepted
    end,Map=function(place)
        f.calls=f.calls+1;f.mapped=place
        if f.request then return f.request(place)end;return f.accepted
    end}
    if route=="waypoint"then
        showDetail(9970,f.waypoint.context);f.control=ui.clientWaypointButton
    else
        local q=addon.quests[35001]
        if route=="reported"then
            q.start.npcID=101
            q.start.reportedLocations={{mapID=1436,x=56.3,y=47.5},{mapID=1436,x=57,y=48}}
            showSources(35001);reportToggle("start").scripts.OnClick();f.control=reportRows()[2]
        else
            q.startAlternatives={{npcID=101,name="Explicit alternative",mapID=1436}}
            if route~="alternative-map"then q.startAlternatives[1].x=56.3;q.startAlternatives[1].y=47.5 end
            showSources(35001);f.control=startButton(1)
        end
    end
    assert(f.control and f.control.shown and f.control.scripts.OnClick and f.calls==0)
    function f:finish()
        if self.waypoint then self.waypoint:finish()end
        finish(self)
    end
    return f
end
check("Accepted reported alternative and game-waypoint visits leave preparation open without replacing the selected action",function()
    for _,route in ipairs({"reported","alternative","alternative-map","waypoint"})do
        local f=manualLocationHandoffFixture(route)
        local dungeon,quest,action=ui.dungeon,ui.quest,ui.action
        f.control.scripts.OnClick()
        assert(f.calls==1 and f.hidden==0 and ui.frame.shown)
        assert(ui.quest==quest and ui.dungeon==dungeon and ui.action==action and ui.search=="retained navigation query")
        if route=="alternative-map"then assert(f.mapped and not f.visited)
        else assert(f.visited and f.visited.kind=="visit"and f.visited.id==quest)end
        ui.frame:Hide();ui.frame.scripts.OnHide(ui.frame)
        ui.frame:Show();ui.frame.scripts.OnShow(ui.frame)
        assert(ui.quest==quest and ui.dungeon==dungeon and ui.search=="retained navigation query"and f.calls==1)
        f:finish()
    end
end)
check("Rejected or throwing manual location requests leave the preparation view open",function()
    for _,route in ipairs({"reported","alternative","alternative-map","waypoint"})do
        for _,mode in ipairs({"false","throw"})do
            local f=manualLocationHandoffFixture(route)
            f.request=function()if mode=="throw"then error("request rejected")end;return false end
            f.control.scripts.OnClick()
            assert(f.calls==1 and f.hidden==0 and ui.frame.shown)
            f:finish()
        end
    end
end)
check("Manual location acceptance cannot hide a refreshed card expired source owner or replacement navigation helper",function()
    for _,route in ipairs({"reported","alternative","alternative-map","waypoint"})do
        for _,mode in ipairs({"card","source","helper"})do
            local f=manualLocationHandoffFixture(route)
            f.request=function()
                if mode=="card"then ui:RefreshDetail()
                elseif mode=="source"then
                    if route=="waypoint"then f.waypoint.dto.text="A newer waypoint instruction"
                    else ui.reportedGeneration={}end
                else addon.Navigation[route=="alternative-map"and"Map"or"Start"]=function()return true end end
                return true
            end
            f.control.scripts.OnClick()
            assert(f.calls==1 and f.hidden==0 and ui.frame.shown)
            f:finish()
        end
    end
end)
check("A supplied invalid or expired transient navigation predicate cannot fall back to a primary action slot",function()
    for _,predicate in ipairs({false,{},function()return nil end,function()error("expired")end})do
        local f=primaryHandoffFixture();local calls=0
        addon.Navigation={Start=function()calls=calls+1;return true end}
        ui:DispatchDetail(ui.action,false,nil,predicate)
        assert(calls==0 and f.hidden==0 and ui.frame.shown)
        f:finish()
    end
    local f=primaryHandoffFixture();local owned=true;local calls=0
    addon.Navigation={Start=function()calls=calls+1;owned=false;return true end}
    ui:DispatchDetail({id=35001,kind="visit",place=addon.quests[35001].start},false,nil,function()return owned end)
    assert(calls==1 and f.hidden==0 and ui.frame.shown)
    f:finish()
end)

local function questLogHandoffFixture()
    local f=questLogControlFixture();local finish=f.finish
    f.frame,f.root,f.control,f.definition=ui.frame,addon.UI,ui.questLogButton,addon.quests[9970]
    f.hide,f.shown,f.checker=f.frame.Hide,f.frame.IsShown,issecretvalue
    f.search=ui.search;ui.search="retained quest-log query";f.hidden=0
    f.frame.Hide=function(frame)f.hidden=f.hidden+1;f.hide(frame);frame.scripts.OnHide(frame)end
    ui:RefreshDetail()
    function f:finish()
        ui.frame=self.frame;addon.UI=self.root;ui.questLogButton=self.control;addon.quests[9970]=self.definition
        self.frame.Hide,self.frame.IsShown=self.hide,self.shown;issecretvalue=self.checker
        ui.search=self.search;self.frame:Show();finish(self)
    end
    return f
end
check("Accepted explicit quest-log requests keep the planner open and preserve the intended native selection",function()
    local f=questLogHandoffFixture();local quest,dungeon=ui.quest,ui.dungeon
    local nativeSelection=65;local opens=0
    addon.OpenQuestLogQuest=function(id)opens=opens+1;nativeSelection=id;return true end
    ui:RefreshDetail();assert(opens==0 and nativeSelection==65)
    ui.questLogButton.scripts.OnClick()
    assert(opens==1 and nativeSelection==9970 and f.hidden==0 and f.frame.shown)
    assert(ui.quest==quest and ui.dungeon==dungeon and ui.search=="retained quest-log query")
    assert(f.control.shown and f.control.enabled and f.control.scripts.OnClick,"opening the log cannot expire its own preparation control")
    f.frame:Hide();f.frame.scripts.OnHide(f.frame)
    assert(not f.control.shown and not f.control.enabled and not f.control.scripts.OnClick,"explicit closing still expires the control")
    f.frame:Show();f.frame.scripts.OnShow(f.frame)
    assert(opens==1 and nativeSelection==9970 and ui.quest==quest and ui.dungeon==dungeon and ui.search=="retained quest-log query")
    f:finish()
end)
check("Expired held capability and rejected throwing or restricted quest-log acknowledgements leave preparation visible",function()
    for _,mode in ipairs({"held","false","nil","throw","restricted"})do
        local f=questLogHandoffFixture();local calls=0;local restricted={}
        addon.OpenQuestLogQuest=function()
            calls=calls+1
            if mode=="throw"then error("native quest log unavailable")end
            if mode=="false"then return false elseif mode=="restricted"then return restricted end
        end
        ui:RefreshDetail();local click=f.control.scripts.OnClick
        if mode=="held"then f.held=false end
        if mode=="restricted"then issecretvalue=function(value)if value==restricted then return true end;return f.checker and f.checker(value)or false end;ui:RefreshDetail();click=f.control.scripts.OnClick end
        click()
        assert(calls==(mode=="held"and 0 or 1)and f.hidden==0 and f.frame.shown)
        f:finish()
    end
end)
check("Quest-log dispatch cannot close a newer card owner frame button or replaced capability",function()
    for _,mode in ipairs({"same-card","quest","owner","frame","button","hide","shown","capability","opener","generation","definition","checker"})do
        local f=questLogHandoffFixture();local calls=0
        addon.OpenQuestLogQuest=function()
            calls=calls+1
            if mode=="same-card"then ui:RefreshDetail()
            elseif mode=="quest"then showDetail(9971)
            elseif mode=="owner"then addon.UI={frame=f.frame}
            elseif mode=="frame"then ui.frame=object("Frame");ui.frame:Show()
            elseif mode=="button"then ui.questLogButton=object("Button");ui.questLogButton:Show()
            elseif mode=="hide"then f.frame.Hide=function(frame)f.hide(frame)end
            elseif mode=="shown"then f.frame.IsShown=function()return true end
            elseif mode=="capability"then addon.CanOpenQuestLog=function()return true end
            elseif mode=="opener"then addon.OpenQuestLogQuest=function()return true end
            elseif mode=="generation"then ui.questLogGeneration={}
            elseif mode=="definition"then addon.quests[9970]={id=9970,minLevel=1}
            else issecretvalue=function()return false end end
            return true
        end
        ui:RefreshDetail();f.control.scripts.OnClick()
        assert(calls==1 and f.hidden==0 and f.frame.shown and ui.frame.shown)
        f:finish()
    end
end)

check("Full-width overview uses a verified painter aspect and reserves matching space through recycled generic and legacy images",function()
    local paint,quest,dungeon,engine,checker=addon.PaintDungeonArt,ui.quest,ui.dungeon,ui.engine,issecretvalue
    local target={key="full-overview",name="Overview fixture",minLevel=1,maxLevel=60,quests={}}
    local kind,aspect="generic",nil;local calls=0;local restricted={}
    issecretvalue=function(value)if value==restricted then return true end;return checker and checker(value)or false end
    addon.PaintDungeonArt=function(texture,d,mode)
        calls=calls+1;assert(d==target and mode=="overview")
        assert(texture.width==ui.detail:GetWidth()-8 and texture.height==ui.detail:GetWidth()-8 and texture.point[2]==4,"recycled compact geometry cannot reach the painter")
        texture:SetTexture("overview");texture:Show();return true,kind,aspect
    end
    ui.quest=nil;ui.dungeon=target;ui:RefreshDetail()
    local compact=ui.detail.height
    assert(ui.overviewArt.width==48 and ui.overviewArt.height==48)
    kind,aspect="art",2992/1684;ui:RefreshDetail()
    local expected=(ui.detail:GetWidth()-8)*1684/2992
    assert(ui.overviewArt.width==ui.detail:GetWidth()-8 and math.abs(ui.overviewArt.height-expected)<.000001 and ui.overviewArt.point[2]==4)
    assert(math.abs(ui.detail.height-(compact+expected-48))<.000001)
    for _,invalid in ipairs({0,-1,math.huge,0/0,restricted,false,"1.77",1e-320})do
        aspect=invalid;ui:RefreshDetail();assert(ui.overviewArt.width==ui.detail:GetWidth()-8 and ui.overviewArt.height==ui.detail:GetWidth()-8 and ui.detail.height==compact+ui.detail:GetWidth()-56)
    end
    kind,aspect="generic",2;ui:RefreshDetail()
    assert(ui.overviewArt.width==48 and ui.overviewArt.height==48 and ui.overviewArt.point[2]==(ui.detail:GetWidth()-56)/2+4 and ui.detail.height==compact)
    kind,aspect="art",2;ui:RefreshDetail()
    assert(ui.overviewArt.width==ui.detail:GetWidth()-8 and ui.overviewArt.height==(ui.detail:GetWidth()-8)/2 and ui.detail.height==compact+(ui.detail:GetWidth()-8)/2-48)
    kind=nil;ui:RefreshDetail();assert(ui.overviewArt.height==ui.detail:GetWidth()-8,"legacy helpers cannot claim a verified aspect without art classification")
    assert(calls==13)
    issecretvalue=checker;addon.PaintDungeonArt=paint;ui.quest,ui.dungeon,ui.engine=quest,dungeon,engine;ui:Refresh()
end)
check("Superseded overview painting cannot resize a newer compact overview or overwrite its layout space",function()
    local paint,quest,dungeon,engine=addon.PaintDungeonArt,ui.quest,ui.dungeon,ui.engine
    local old={key="old-wide",name="Old overview",minLevel=1,maxLevel=60,quests={}}
    local newer={key="new-compact",name="New overview",minLevel=1,maxLevel=60,quests={}}
    local armed=true;local freshHeight
    addon.PaintDungeonArt=function(texture,d,mode)
        assert(mode=="overview")
        if d==old and armed then
            armed=false;ui.dungeon=newer;ui:RefreshDetail();freshHeight=ui.detail.height
            return true,"art",2
        end
        assert(d==newer);texture:SetTexture("new generic");texture:Show();return true,"generic"
    end
    ui.quest=nil;ui.dungeon=old;ui:RefreshDetail()
    assert(not armed and ui.dungeon==newer and ui.overviewArt.texture=="new generic"and ui.overviewArt.width==48 and ui.overviewArt.height==48)
    assert(ui.overviewArt.point[2]==(ui.detail:GetWidth()-56)/2+4 and ui.detail.height==freshHeight)
    addon.PaintDungeonArt=paint;ui.quest,ui.dungeon,ui.engine=quest,dungeon,engine;ui:Refresh()
end)

check("Normal browsing ignores a saved preparation mode and exposes no Back or mode widget",function()
    local f=targetSearchFixture();local filters=addon.char.filters
    addon.QuestName=f.questName
    addon.char.filters={preparation=true,other="keep"};ui:LoadFilters();ui.quest=nil;ui.dungeon=addon.dungeons[1];ui:Refresh()
    assert(ui.back==nil and ui.preparationButton==nil and not ui.preparation)
    assert(#visibleRows()==3)
    for _,row in ipairs(visibleRows())do assert(not row.heading and (row.questID==31001 or row.questID==31002))end
    ui.preparation=true;ui:Refresh();assert(not ui.preparation and #visibleRows()==3 and addon.char.filters.preparation==true)
    assert(ui.characterButton.point[2]==548 and ui.entrance==nil and ui.language.width==64 and not ui.languageChevron)
    addon.char.filters=filters;f:finish()
end)
check("Blocked level navigation explicitly routes to a known giver without claiming the quest available",function()
    local quest,dungeon,nav=ui.quest,ui.dungeon,addon.Navigation
    addon.quests[99250]={id=99250,minLevel=80,requirementsKnown=true,start={mapID=1,x=20,y=30,name="Known giver"}}
    ui.dungeon={key="level-destination",quests={99250}};local calls={}
    addon.Navigation={Map=function(point)calls[#calls+1]=point;return true end,Start=function(action)calls[#calls+1]=action;return true end}
    showCompactDetail(99250)
    assert(ui.action.kind=="level" and ui.engine:State(99250).status=="LOCKED")
    assert(hasDestination(false) and hasDestination(true) and ui.giver.footerLabelKey=="VISIT_GIVER")
    dispatchGiverMap();ui.giver.scripts.OnClick()
    assert(calls[1]==addon.quests[99250].start and calls[2].kind=="visit" and calls[2].id==99250 and calls[2].place==calls[1])
    assert(ui.action.kind=="level" and ui.engine:State(99250).status=="LOCKED" and ui.frame.shown)
    addon.quests[99250]=nil;addon.Navigation=nav;ui.quest,ui.dungeon=quest,dungeon;ui:Refresh()
end)
check("Navigation tooltips name the destination and leave foreign tooltip ownership untouched",function()
    local previous=GameTooltip;local hidden=0;local tip={}
    function tip:SetOwner(owner,anchor)assert(anchor=="ANCHOR_RIGHT");self.owner=owner end
    function tip:IsOwned(owner)return self.owner==owner end
    function tip:SetText(value)self.text=value end
    function tip:AddLine(value)self.line=value end
    function tip:Show()self.shown=true end
    function tip:Hide()hidden=hidden+1;self.shown=false end
    GameTooltip=tip;showCompactDetail(2);ui.giver.scripts.OnEnter()
    assert(tip.shown and tip.owner==ui.giver and tip.text==addon.L(ui.giver.footerLabelKey) and tip.line:find("Giver 2",1,true))
    tip.owner={};ui.giver.scripts.OnLeave();assert(hidden==0 and tip.shown)
    ui.giver.scripts.OnEnter();ui.giver.scripts.OnLeave();assert(hidden==1 and not tip.shown)
    GameTooltip=previous
end)
check("Dungeon entrance uses only a current explicit producer point and its separate navigation adapter",function()
    local quest,dungeon,provider,nav=ui.quest,ui.dungeon,addon.Entrances,addon.Navigation
    local selected={key="entrance-fixture",name="Selected dungeon",quests={}}
    local point={mapID=1436,x=42.5,y=71.7,name="Entry hallway"};local valid=true;local calls=0
    addon.Entrances={Get=function(d)assert(d==selected);return point,function()return valid end end}
    addon.Navigation={StartEntrance=function(d,p)assert(d==selected and p==point);calls=calls+1;return true end}
    ui.quest,ui.dungeon=nil,selected;ui:RefreshDetail()
    assert(ui.entrance==nil and ui.entranceBinding and calls==0)
    ui:VisitEntrance();assert(calls==1 and ui.quest==nil and ui.frame.shown)
    valid=false;ui:VisitEntrance();assert(calls==1)
    valid=true;point.x=80;ui:VisitEntrance();assert(calls==1,"a changed point invalidates an older entrance binding")
    for _,bad in ipairs({false,{},function()return false end})do
        addon.Entrances={Get=function()return point,bad end};ui:RefreshDetail();assert(not ui.entranceBinding)
    end
    addon.Entrances={Get=function()return point end};ui:RefreshDetail();assert(not ui.entranceBinding)
    addon.Entrances={Get=function()return nil end};ui:RefreshDetail();assert(not ui.entranceBinding)
    assert(detailHas(addon.L("DUNGEON_ENTRANCE_UNKNOWN")))
    addon.Entrances,addon.Navigation=provider,nav;ui.quest,ui.dungeon=quest,dungeon;ui:Refresh()
end)
check("Real language hover previews the existing window and restores its labels without changing saved selection",function()
    local previous,locale,quest,dungeon=addon.Language,addon.db.locale,ui.quest,ui.dungeon
    addon.db.locale="enUS";ui.quest=2;ui.frame:Show();ui:Refresh()
    local range,heading,note=addon.L(ui.rangeButton.filterLabelKey),ui.heading.text,ui.rows[1].note.text
    assert(loadfile("UI/Language.lua"))("DungeonPro",addon);local language=addon.Language
    assert(language:Attach(ui.language,ui));ui.language.scripts.OnEnter()
    assert(language.session and #language.session.rows==11)
    language.session.rows[3].scripts.OnEnter()
    assert(addon.db.locale=="enUS" and ui.language.languageCaption=="Русский" and ui.language.text=="RU")
    assert(addon.L(ui.rangeButton.filterLabelKey)==addon.L(ui.range and "RANGE"or"ALL")and addon.L(ui.rangeButton.filterLabelKey)~=range)
    assert(ui.rows[1].note.text~=note)
    assert(detailHas(addon.locales.ruRU.DETAIL_GIVER) and ui.back==nil and ui.preparationButton==nil)
    assert(language:Cancel(ui)and addon.db.locale=="enUS"and addon.L(ui.rangeButton.filterLabelKey)==range and ui.heading.text==heading)
    local selections={"enUS","ruRU","deDE","frFR","esES","itIT","ptBR","koKR","zhCN","zhTW"}
    ui.language.scripts.OnEnter();local session=language.session
    for index,code in ipairs(selections)do
        local row=session.rows[index+1];row.scripts.OnEnter()
        assert(language:GetSelection()==code and addon.db.locale=="enUS")
        assert(ui.language.text==code:sub(1,2):upper() and ui.language.languageLocale==code and ui.language.width==64)
        assert(ui.language.languageIcon.texture=="Interface\\AddOns\\DungeonPro\\Media\\Icons\\Language")
        assert(addon.L(ui.rangeButton.filterLabelKey)==addon.locales[code][ui.range and "RANGE"or"ALL"])
        assert(session.rows[1].text==addon.locales[code].LANGUAGE_AUTO and row.languagePreview)
        assert(session.rows[2].languageSelected and row.languageSelected==(code=="enUS"),"checkmark follows committed English while hover previews another locale")
        assert(detailHas(addon.locales[code].DETAIL_GIVER))
    end
    session.rows[4].scripts.OnClick();assert(addon.db.locale=="deDE" and not language.session)
    addon.db.locale="enUS";ui:Refresh()
    ui.language.scripts.OnEnter();language.session.rows[3].scripts.OnEnter();ui.frame:Hide();ui.frame.scripts.OnHide()
    assert(not language.session and addon.db.locale=="enUS")
    addon.Language=previous;addon.db.locale=locale;ui.quest,ui.dungeon=quest,dungeon;ui.frame:Show();ui:Refresh()
end)
check("Quest-giver action shares its location row while Wowhead retains its compact header slot",function()
    local quest,locale,navigation=ui.quest,addon.db.locale,addon.Navigation
    local called;addon.Navigation={Start=function(action)called=action;return true end}
    showCompactDetail(3,{level=20,completed=function()return false end,active=function()return false end});local giver,source=ui.giver,ui.source
    local giverIcon,sourceIcon=giver.footerIcon,source.footerIcon
    assert(giver.width==24 and giver.height==24 and source.width==32 and source.height==32)
    assert(giver.parent==ui.detail and source.parent==ui.detail)
    assert(giver.point[1]=="TOPLEFT"and giver.point[2]==ui.detail and giver.point[3]=="TOPLEFT"and giver.point[4]==4 and giver.point[5]<0)
    assert(source.point[1]=="TOPRIGHT"and source.point[2]==ui.detail and source.point[3]=="TOPRIGHT"and source.point[4]==-4 and source.point[5]==0)
    assert(not giver.caption and source.text==""and giverIcon.width==3 and sourceIcon.height==24)
    assert(giverIcon.texture=="Interface\\Buttons\\WHITE8X8"and giver.navigationGold and #giver.footerIconParts==3)
    assert(sourceIcon.texture=="Interface\\AddOns\\DungeonPro\\Media\\Icons\\Wowhead")
    assert(sourceIcon.texCoords[1]==0 and sourceIcon.texCoords[2]==.75 and sourceIcon.texCoords[3]==0 and sourceIcon.texCoords[4]==.75)
    assert(giver.disabledMotion and source.disabledMotion)
    assert(ui.engine:State(3).status=="UNKNOWN"and not ui.action and giver.enabled and source.enabled)
    giver.scripts.OnClick();assert(called.id==3 and called.kind=="visit"and called.place==addon.quests[3].start)
    source.scripts.OnClick();assert(ui.copy.shown and ui.copy.text=="https://www.wowhead.com/forever/quest=3"and ui.frame.shown)
    ui:CloseCopyLink()
    for code in pairs(addon.locales)do addon.db.locale=code;ui:Refresh()
        assert(not giver.caption and source.text==""and giver.footerIcon==giverIcon and source.footerIcon==sourceIcon)
        assert(giverIcon.alpha==.95 and sourceIcon.alpha==.88 and not sourceIcon.desaturated)
    end
    ui.quest=nil;ui:RefreshDetail()
    assert(not giver.enabled and not source.enabled and giverIcon.alpha==.6 and sourceIcon.alpha==.3 and not giverIcon.desaturated and sourceIcon.desaturated)
    addon.Navigation,addon.db.locale=navigation,locale;ui.quest=quest;ui:Refresh()
end)
check("Icon-only footer hover localizes purpose and source instructions while press hide and zone-only states stay honest",function()
    local old,locale,quest=GameTooltip,addon.db.locale,ui.quest;local tip={}
    function tip:SetOwner(owner)self.owner=owner end
    function tip:IsOwned(owner)return self.owner==owner end
    function tip:SetText(value)self.text=value end
    function tip:AddLine(value)self.line=value end
    function tip:Show()self.shown=true end
    function tip:Hide()self.shown=false end
    GameTooltip=tip;showCompactDetail(3)
    for code in pairs(addon.locales)do addon.db.locale=code;ui:Refresh()
        ui.giver.scripts.OnEnter();assert(tip.text==addon.L("VISIT_GIVER")and tip.line:find("Giver 3",1,true)and ui.giver.footerIcon.alpha==1)
        ui.giver.scripts.OnMouseDown(ui.giver,"LeftButton");assert(ui.giver.footerIcon.alpha==.8)
        ui.giver.scripts.OnHide();assert(ui.giver.footerIcon.alpha==.95 and not ui.giver.footerPressed and not ui.giver.footerHovered)
        ui.source.scripts.OnEnter();assert(tip.text==addon.L("SOURCE")and tip.line==addon.L("COPY"))
        ui.source.scripts.OnLeave();assert(not tip.shown and ui.source.footerIcon.alpha==.88)
    end
    local point=addon.quests[3].start;local x,y=point.x,point.y;point.x,point.y=nil,nil;ui:RefreshDetail()
    ui.giver.scripts.OnEnter();assert(tip.text==addon.L("GIVER_MAP")and not tip.line:find("(",1,true))
    point.x,point.y=x,y;GameTooltip=old;addon.db.locale=locale;ui.quest=quest;ui:Refresh()
end)
check("Refreshing a footer hint clears only owned stale text and reentry cannot resume an older card",function()
    local old,quest=GameTooltip,ui.quest;local tip={hides=0}
    function tip:SetOwner(owner)self.owner=owner end
    function tip:IsOwned(owner)return self.owner==owner end
    function tip:SetText(value)self.text=value end
    function tip:AddLine(value)self.line=value end
    function tip:Show()self.shown=true end
    function tip:Hide()self.hides=self.hides+1;self.shown=false end
    GameTooltip=tip;showCompactDetail(3);ui.giver.scripts.OnEnter();assert(tip.shown)
    ui:RefreshDetail();assert(not tip.shown and not ui.navigationTooltip)
    ui.giver.scripts.OnEnter();tip.owner={};local hides=tip.hides;ui:RefreshDetail();assert(tip.shown and tip.hides==hides)
    ui.giver.scripts.OnEnter();local hide=tip.Hide;local armed=true
    tip.Hide=function(self)hide(self);if armed then armed=false;showCompactDetail(2)end end
    ui:RefreshDetail();assert(not armed and ui.quest==2 and not detailHas("Quest 3"))
    GameTooltip=old;ui.quest=quest;ui:Refresh()
end)
check("Human inspection lists actual92753 without racial labels while unknown requirements remain unknown",function()
    local finish=emptyPreparationFixture();local raceName=addon.RaceName;local reads=0
    addon.RaceName=function()reads=reads+1;error("race names are outside audience policy")end
    addon.Context=function()return{level=60,faction="Alliance",class="WARRIOR",race=1,
        active=function()return false end,completed=function()return false end}end
    local q=addon.quests[92753];local races=q.races
    assert(races and #races>0 and q.requirementsKnown==false)
    for code in pairs(addon.locales)do
        addon.db.locale=code;ui.quest=92753;ui:Refresh()
        local row;for _,candidate in ipairs(visibleRows())do if candidate.questID==92753 then row=candidate end end
        assert(row and ui.engine:State(92753).status=="UNKNOWN" and not ui.action)
        assert(not row.note.text:find(addon.L("UNAVAILABLE"),1,true))
        for _,expanded in ipairs({false,true})do
            if expanded then expandDetail()end
            for _,fs in ipairs(ui.details)do if fs.shown then
                assert(not fs.text:find(addon.L("RACE_ID",95),1,true) and not fs.text:find("High Order",1,true))
                assert(not fs.text:find(addon.L("QUEST_RACES",""),1,true))
            end end
            assert(detailIncludes(addon.L(ui.detailReferencesExpanded and "DETAIL_MIN_LEVEL"or"DETAIL_MIN_LEVEL",q.minLevel)))
        end
        assert(q.races==races and #races==4 and reads==0)
    end
    addon.RaceName=raceName;finish()
end)
check("Race-only facts never create an unavailable audience note or call native race naming",function()
    local finish=emptyPreparationFixture();local raceName=addon.RaceName
    addon.RaceName=function()error("race labels must not be read")end
    addon.quests[99094]={id=99094,name="Race-only source",races={3,4,7,95},minLevel=1,requirementsKnown=false}
    ui.dungeon={key="race-policy",name="Race policy",minLevel=1,maxLevel=60,quests={99094}}
    addon.Context=function()return{level=60,faction="Alliance",class="WARRIOR",race=1,
        active=function()return false end,completed=function()return false end}end
    ui.quest=99094;ui.includeUnavailable=false;ui:Refresh()
    assert(#visibleRows()==1 and ui.engine:State(99094).status=="UNKNOWN" and not ui.action)
    assert(ui.rows[1].note.text:find(addon.L("UNKNOWN_REQUIREMENTS"),1,true))
    assert(not ui.rows[1].note.text:find(addon.L("UNAVAILABLE"),1,true))
    addon.RaceName=raceName;finish()
end)
check("Planner owns normal top-level focus without changing another window or its strata",function()
    local f=ui.frame
    assert(f.topLevel==true)
    local before=f.raises or 0;local savedFit,savedRefresh=ui.Fit,ui.Refresh;local fit,refresh=0,0
    ui.Fit=function()fit=fit+1 end;ui.Refresh=function()refresh=refresh+1 end
    f.scripts.OnShow(f);assert(f.raises==before+1 and fit==1 and refresh==1)
    f.scripts.OnMouseDown(f,"LeftButton");assert(f.raises==before+2)
    local start=f.StartMoving;local moved=false;f.StartMoving=function()moved=true end
    f.scripts.OnDragStart(f);assert(moved and f.raises==before+3)
    f.StartMoving=start
    local foreign={Raise=function()error("foreign frame must not be raised")end}
    f.scripts.OnMouseDown(foreign,"LeftButton");assert(f.raises==before+3)
    local raise=f.Raise;f.Raise=function()error("restricted frame API")end
    f.scripts.OnShow(f);assert(fit==2 and refresh==2)
    f.Raise=false;f.scripts.OnMouseDown(f,"LeftButton");f.scripts.OnShow(f)
    assert(fit==3 and refresh==3)
    f.Raise=raise;ui.Fit,ui.Refresh=savedFit,savedRefresh
end)

check("Copy opening geometry cannot scroll a newly selected quest or replacement scroll owner",function()
    local saved={quest=ui.quest,history=ui.detailHistory,refresh=ui.RefreshDetail,scroll=ui.detailScroll,detail=ui.detail}
    for _,mode in ipairs({"quest","scroll","getter"})do
        ui.RefreshDetail=saved.refresh;ui.detailScroll=saved.scroll;showDetail(1);ui:CloseCopyLink()
        local detail,scroll=ui.detail,ui.detailScroll
        local content,viewport=detail.GetHeight,scroll.GetHeight
        local armed=false;local newer;local writes=scroll.scrollWrites
        local function change()
            if not armed then return end
            armed=false
            if mode=="quest"then showDetail(2);ui.detailScroll:SetVerticalScroll(7)
            elseif mode=="scroll"then
                newer=setmetatable({verticalScroll=7,scripts={}},getmetatable(scroll));ui.detailScroll=newer
            else scroll.GetHeight=function()return 425 end end
        end
        if mode=="scroll"then
            scroll.GetHeight=function(region)change();return viewport(region)end
        else detail.GetHeight=function(region)if armed then change();return 2000 end;return content(region)end end
        ui.RefreshDetail=function(self)saved.refresh(self);armed=true end
        assert(not ui:CopyLink(1))
        ui.RefreshDetail=saved.refresh;detail.GetHeight=content;scroll.GetHeight=viewport
        if mode=="quest"then
            assert(ui.quest==2 and ui.detailScroll.verticalScroll==7 and not ui.copy.shown and not ui.copy.focused)
        elseif mode=="scroll"then
            assert(ui.detailScroll==newer and newer.verticalScroll==7 and newer.scrollWrites==nil and not ui.copy.focused)
        else assert(scroll.scrollWrites==writes and not ui.copy.focused)end
        ui.detailScroll=scroll;ui:CloseCopyLink()
    end
    ui.RefreshDetail=saved.refresh;ui.detailScroll=saved.scroll;ui.quest,ui.detailHistory=saved.quest,saved.history;ui:Refresh()
end)
check("Current copy opening still scrolls to its drawer and focuses the same visible edit box",function()
    local quest,history=ui.quest,ui.detailHistory
    showDetail(1);ui.detailScroll:SetVerticalScroll(17)
    assert(ui:CopyLink(1) and ui.copy.focused and ui.copy.shown)
    assert(ui.copy.text=="https://www.wowhead.com/forever/quest=1")
    assert(ui.detailScroll.verticalScroll==math.max(0,ui.detail:GetHeight()-ui.detailScroll:GetHeight()))
    ui:EscapeCopyLink();assert(not ui.copy.shown and not ui.copy.focused)
    ui.quest,ui.detailHistory=quest,history;ui:Refresh()
end)
do
    local function acquisitionFixture()
        local f,q=hierarchyFixture(1221)
        local nav,locale,character,map=addon.Navigation,addon.db.locale,addon.char,C_Map
        f.held=false;f.calls={}
        addon.Navigation={Start=function(action)f.calls[#f.calls+1]=action;return true end,
            Map=function(point)f.calls[#f.calls+1]={place=point,mapOnly=true};return true end}
        function f:refresh()showSources(1221,self.context)end
        function f:close()
            addon.Navigation,addon.db.locale,addon.char,C_Map=nav,locale,character,map
            ui.frame:Show();self:restore()
        end
        f:refresh();return f,q
    end
    local function sourceRows()
        local result={}
        for _,row in ipairs(ui.objectiveContainerButtons or{})do if row.shown then result[#result+1]=row end end
        return result
    end
    check("Actual1221 objective acquisition preserves three item-object pairs and unknown tool quantities",function()
        local f,q=acquisitionFixture();local rows=sourceRows()
        assert(#rows==3 and #q.objectiveItems==4 and #q.objectiveItemSources==3 and #f.calls==0)
        assert(q.objectiveItems[1].itemID==5876 and q.objectiveItems[1].quantity==6)
        assert(not q.providedItems and not q.start.itemID and q.requirementsKnown==false)
        assert(ui.engine:State(1221).status=="UNKNOWN" and not ui.action)
        assert(detailHas(addon.L("OBJECTIVE_ITEM_SOURCES")) and detailHas(addon.L("OBJECTIVE_ITEM_SOURCES_NOTICE")))
        for i,pair in ipairs({{5880,21277},{5897,21530},{6684,68865}})do
            local source=q.objectiveItemSources[i];local point=source.containerSources[1]
            assert(source.itemID==pair[1] and point.objectID==pair[2] and q.objectiveItems[i+1].quantity==nil)
            assert(rows[i].title.text==point.name and rows[i].enabled and rows[i].note.text:find("62.3, 37.6",1,true))
            rows[i].scripts.OnClick(rows[i],"LeftButton",false)
            local action=f.calls[#f.calls]
            assert(action and action.id==1221 and action.kind=="visit" and action.place==point)
            assert(action.place.mapID==1413 and action.place.x==62.3 and action.place.y==37.6)
        end
        assert(#f.calls==3 and ui.engine:State(1221).status=="UNKNOWN" and not ui.action)
        f:close()
    end)
    check("Objective acquisition rejects malformed and restricted source payloads without hiding the ordinary goals",function()
        local modes={"wrong-object","quantity","coordinates","entry-key","point-key",
            "objectID","name","source","zoneName","mapID","x","y"}
        for _,mode in ipairs(modes)do
            local f,q=acquisitionFixture();local point=q.objectiveItemSources[1].containerSources[1]
            local checker,restricted=issecretvalue,{}
            if mode=="wrong-object"then point.objectID=21530
            elseif mode=="quantity"then q.objectiveItemSources[1].quantity=1
            elseif mode=="coordinates"then point.x=101
            else
                issecretvalue=function(value)return value==restricted end
                if mode=="entry-key"then q.objectiveItemSources[1][restricted]=true
                elseif mode=="point-key"then point[restricted]=true
                else point[mode]=restricted end
            end
            f:refresh()
            assert(#sourceRows()==0 and not detailHas(addon.L("OBJECTIVE_ITEM_SOURCES")),mode)
            assert(ui:SetDetailTab("quest"))
            assert(detailHas(addon.L("OBJECTIVE_ITEM","Blueleaf Tuber",6)),mode)
            assert(#f.calls==0 and ui.engine:State(1221).status=="UNKNOWN" and q.objectiveItems[2].quantity==nil,mode)
            issecretvalue=checker;f:close()
        end
    end)
    check("Saved objective acquisition clicks expire after source context or hidden-planner changes",function()
        for _,mode in ipairs({"list","point","entry","item","locale","character","navigation","map","hide"})do
            local f,q=acquisitionFixture();local row=sourceRows()[1];local click=row.scripts.OnClick
            if mode=="list"then q.objectiveItemSources={}
            elseif mode=="point"then q.objectiveItemSources[1].containerSources[1].x=60
            elseif mode=="entry"then q.objectiveItemSources[1].quantity=1
            elseif mode=="item"then q.objectiveItems[2].name="Changed item definition"
            elseif mode=="locale"then addon.db.locale="ruRU"
            elseif mode=="character"then addon.char={}
            elseif mode=="navigation"then addon.Navigation={Start=function()error("expired route must not dispatch")end}
            elseif mode=="map"then C_Map={}
            else ui.frame:Hide();ui.frame.scripts.OnHide(ui.frame)end
            click(row,"LeftButton",false)
            assert(#f.calls==0,mode)
            f:close()
        end
    end)
    check("Objective acquisition per-method restoration preserves newer text enabled state and exact visit callback",function()
        for _,boundary in ipairs({"title","note","enabled","script"})do
            local f,q=acquisitionFixture();local row=sourceRows()[1]
            local target=boundary=="title"and row.title or boundary=="note"and row.note or row
            local key=boundary=="enabled"and"SetEnabled"or boundary=="script"and"SetScript"or"SetText"
            local original,armed=target[key],true
            local replacement={objectID=21277,name="Newer container",zoneName="Newer region",
                source="https://www.wowhead.com/forever/object=21277/crate-with-holes",mapID=1413,x=8,y=9}
            if boundary=="enabled"then replacement.mapID,replacement.x,replacement.y=nil,nil,nil end
            local newer
            target[key]=function(self,...)
                local first,second=...
                local publish=boundary=="title"or boundary=="note"or boundary=="enabled"and first==true or
                    boundary=="script"and first=="OnClick"and second~=nil
                if armed and publish then
                    armed=false;q.objectiveItemSources[1].containerSources={replacement};f:refresh()
                    newer={title=row.title.text,note=row.note.text,enabled=row.enabled,click=row.scripts.OnClick,height=row.height,point=row.point}
                end
                return original(self,...)
            end
            f:refresh();target[key]=original
            assert(not armed and newer and row.title.text==newer.title and row.note.text==newer.note,boundary)
            assert(row.enabled==newer.enabled and row.scripts.OnClick==newer.click and row.height==newer.height and row.point==newer.point,boundary)
            if boundary=="enabled"then assert(not row.enabled and not row.scripts.OnClick)
            else
                row.scripts.OnClick(row,"LeftButton",false)
                assert(#f.calls==1 and f.calls[1].id==1221 and f.calls[1].kind=="visit" and f.calls[1].place==replacement,boundary)
            end
            assert(ui.engine:State(1221).status=="UNKNOWN" and q.objectiveItems[2].quantity==nil)
            f:close()
        end
    end)
end
check("Compact selected giver stays visible before the mandatory chain and never routes to its ancestor",function()
    local quest,dungeon,navigation=ui.quest,ui.dungeon,addon.Navigation
    local calls={};addon.Navigation={Map=function(point)calls[#calls+1]=point end,Start=function(action)calls[#calls+1]=action end}
    for id=42000,42002 do
        addon.quests[id]={id=id,minLevel=1,requirementsKnown=true,start={name="Giver "..id,mapID=1,x=20,y=30}}
        if id<42002 then addon.quests[id].requires={{ids={id+1}}}end
    end
    ui.dungeon={key="visible-giver-chain",quests={42000}};showCompactDetail(42000)
    ui.questTreeRoot,ui.questTreeDungeon=42000,ui.dungeon;ui:RefreshQuests();ui:RefreshDetail()
    local count=0;for _,row in ipairs(ui.rows)do if row.shown and row.questTreeNode and row.questID then count=count+1 end end
    assert(count==3 and not(ui.referenceToggle and ui.referenceToggle.shown) and not detailHas(addon.L("CHAIN"))and not detailHas(addon.L("NEXT")))
    assert(destinationLine("Giver 42000") and ui.action.id==42002)
    dispatchGiverMap();ui.giver.scripts.OnClick()
    assert(calls[1]==addon.quests[42000].start and calls[2].id==42000 and calls[2].kind=="visit")
    local source=addon.quests[42000].start
    for field,value in pairs({npcID=99,objectID=88,itemID=77,name="Different giver",zoneName="Different area",x=45})do
        local previous=source[field];source[field]=value
        dispatchGiverMap();ui.giver.scripts.OnClick()
        assert(#calls==2,"giver identity or location changes expire all old navigation bindings: "..field)
        source[field]=previous;ui:RefreshDetail()
    end
    for id=42000,42002 do addon.quests[id]=nil end
    addon.Navigation=navigation;ui.quest,ui.dungeon=quest,dungeon;ui:Refresh()
end)
check("Level-only cards show concise level metadata and giver location without a promoted reach-level step",function()
    local quest,dungeon,navigation=ui.quest,ui.dungeon,addon.Navigation
    addon.quests[41000]={id=41000,minLevel=80,requirementsKnown=true,start={name="Level quest giver",mapID=1455}}
    ui.dungeon={key="level-copy",quests={41000}};showCompactDetail(41000)
    assert(ui.action.kind=="level" and detailHas(addon.L("DETAIL_MIN_LEVEL",80)))
    assert(not detailHas(addon.L("NEXT")) and not detailIncludes(addon.L("level")))
    assert(detailHas(addon.L("DETAIL_GIVER")) and destinationLine("Level quest giver"))
    assert(detailHas(addon.L("GIVER_COORDINATES_UNKNOWN")) and hasDestination(false) and not hasDestination(true))
    addon.quests[41000].start.mapID=nil;ui:RefreshDetail()
    assert(detailHas(addon.L("GIVER_LOCATION_UNKNOWN")) and not hasDestination(false) and not hasDestination(true))
    addon.quests[41000]=nil;addon.Navigation=navigation;ui.quest,ui.dungeon=quest,dungeon;ui:Refresh()
end)
check("Mapped alternative giver areas remain explicit compact choices and stale choice callbacks expire",function()
    local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    -- Keep this area-only/unknown fixture independent of later precise source data.
    local unknown=actual.quests[7492].startAlternatives[2]
    actual.quests[7492].startAlternatives[2]={npcID=unknown.npcID,name=unknown.name}
    local area=actual.quests[7494].startAlternatives[1]
    actual.quests[7494].startAlternatives[1]={npcID=area.npcID,name=area.name,zoneName=area.zoneName,mapID=area.mapID}
    local quest,dungeon,navigation=ui.quest,ui.dungeon,addon.Navigation
    local first,second=addon.quests[7492],addon.quests[7494]
    addon.quests[7492],addon.quests[7494]=actual.quests[7492],actual.quests[7494]
    local mapped,started={},0
    addon.Navigation={Map=function(point)mapped[#mapped+1]=point end,Start=function()started=started+1 end}
    ui.dungeon={key="explicit-giver-choice",quests={7492,7494}};showCompactDetail(7492)
    assert(not ui.detailReferencesExpanded and not hasDestination(false) and not hasDestination(true))
    assert(not ui.giverButtons[1].shown and not ui.giverButtons[2].shown)
    assert(ui:SetDetailTab("sources"))
    assert(ui.giverButtons[1].shown and ui.giverButtons[1].enabled and ui.giverButtons[2].shown and not ui.giverButtons[2].enabled)
    local old=ui.giverButtons[1].scripts.OnClick;old()
    assert(mapped[1]==actual.quests[7492].startAlternatives[1] and started==0)
    showCompactDetail(7494);old();assert(#mapped==1)
    assert(ui:SetDetailTab("sources"))
    ui.giverButtons[1].scripts.OnClick();assert(mapped[2]==actual.quests[7494].startAlternatives[1] and started==0)
    addon.quests[7492],addon.quests[7494]=first,second;addon.Navigation=navigation;ui.quest,ui.dungeon=quest,dungeon;ui:Refresh()
end)
check("Long mandatory chains remain fully inspectable in the middle without duplicate right hierarchy",function()
    local quest,dungeon,root,treeDungeon=ui.quest,ui.dungeon,ui.questTreeRoot,ui.questTreeDungeon
    for id=41001,41009 do
        addon.quests[id]={id=id,minLevel=1,requirementsKnown=true,start={name="Chain giver",mapID=1,x=20,y=30}}
        if id<41009 then addon.quests[id].requires={{ids={id+1}}}end
    end
    ui.dungeon={key="long-mandatory",quests={41001}};showCompactDetail(41001)
    ui.questTreeRoot,ui.questTreeDungeon=41001,ui.dungeon;ui:RefreshQuests();ui:RefreshDetail()
    local shown,parent=0
    for _,row in ipairs(ui.rows)do if row.shown and row.questTreeNode and row.questID then shown=shown+1;if row.questID==41002 then parent=row end end end
    assert(shown==9 and parent and not detailHas(addon.L("CHAIN"))and not(ui.referenceToggle and ui.referenceToggle.shown))
    parent.scripts.OnClick();assert(ui.quest==41002 and destinationLine("Chain giver"))
    for id=41001,41009 do addon.quests[id]=nil end
    ui.quest,ui.dungeon,ui.questTreeRoot,ui.questTreeDungeon=quest,dungeon,root,treeDungeon;ui:Refresh()
end)
check("Shared dungeon approaches use a short header and retain both notices with their actual source",function()
    local quest,dungeon,provider,navigation,tooltip=ui.quest,ui.dungeon,addon.Entrances,addon.Navigation,GameTooltip
    local point={mapID=1,x=20,y=30,name="Dungeon approach",origin="recorded",kind="approach",scope="shared",source="https://classicdb.ch/?zone=1584"}
    addon.Entrances={Get=function()return point,function()return true end end}
    addon.Navigation={StartEntrance=function()return true end}
    ui.dungeon={key="shared-approach",name="Shared approach",minLevel=1,maxLevel=60,quests={}};ui.quest=nil;ui:RefreshDetail()
    assert(ui.entrance==nil and ui.entranceBinding)
    assert(detailHas(addon.L("DUNGEON_ENTRANCE_APPROACH")) and detailHas(addon.L("DUNGEON_ENTRANCE_SHARED")))
    local tip={}
    function tip:SetOwner(owner)self.owner=owner end
    function tip:IsOwned(owner)return self.owner==owner end
    function tip:SetText(text)self.text=text end
    function tip:AddLine(text)self.line=text end
    function tip:Show()self.shown=true end
    function tip:Hide()self.shown=false end
    local ds,search=addon.dungeons,ui.search
    addon.dungeons={ui.dungeon};ui.search="";ui:RefreshDungeons()
    GameTooltip=tip;ui.cards[1].entranceControl.scripts.OnEnter()
    addon.dungeons,ui.search=ds,search
    assert(tip.shown and tip.line:find(point.source,1,true) and tip.line:find(addon.L("DUNGEON_ENTRANCE_APPROACH"),1,true)
        and tip.line:find(addon.L("DUNGEON_ENTRANCE_SHARED"),1,true))
    GameTooltip=tooltip;addon.Entrances,addon.Navigation=provider,navigation;ui.quest,ui.dungeon=quest,dungeon;ui:Refresh()
end)
check("Catalogue entrance icons route their own nonselected dungeon and expire on recycling or hidden rows",function()
    local provider,navigation=addon.Entrances,addon.Navigation
    local f=targetSearchFixture();local calls={};local valid=true
    addon.Entrances={Get=function(d)return {mapID=1,x=20,y=30,name=d.name},function()return valid end end}
    addon.Navigation={StartEntrance=function(d,p)calls[#calls+1]={d,p};return true end}
    ui:RefreshDungeons();local row=ui.cards[2];local click=row.entranceControl.scripts.OnClick
    local selected,quest=ui.dungeon,ui.quest
    assert(ui.entrance==nil and row.entranceControl.width==28 and row.entranceControl.footerIcon.width==20)
    click();assert(#calls==1 and calls[1][1]==addon.dungeons[2] and ui.dungeon==selected and ui.quest==quest)
    valid=false;click();assert(#calls==1);valid=true
    row:Hide();click();assert(#calls==1);row:Show()
    ui.search="Gamma";ui:RefreshDungeons();click();assert(#calls==1,"recycled card cannot route its old dungeon")
    ui.cards[1].entranceControl.scripts.OnClick();assert(#calls==2 and calls[2][1]==addon.dungeons[3])
    local fresh=ui.cards[1].entranceControl.scripts.OnClick
    ui.frame:Hide();fresh();assert(#calls==2);ui.frame:Show()
    addon.Entrances,addon.Navigation=provider,navigation;f:finish()
end)
check("Warm catalogue language paint retains icon bindings without querying all entrances again",function()
    local provider,navigation=addon.Entrances,addon.Navigation
    local f=targetSearchFixture();local reads,calls=0,0
    addon.Entrances={Get=function(d)reads=reads+1;return {mapID=1,x=20,y=30},function()return true end end}
    addon.Navigation={StartEntrance=function()calls=calls+1;return true end}
    ui:RefreshDungeons();assert(reads==3)
    local control,binding,click=ui.cards[2].entranceControl,ui.cards[2].entranceBinding,ui.cards[2].entranceControl.scripts.OnClick
    for i=1,10 do assert(ui:RefreshCatalogLanguage());assert(reads==3 and ui.cards[2].entranceControl==control and ui.cards[2].entranceBinding==binding)end
    click();assert(calls==1)
    addon.Entrances,addon.Navigation=provider,navigation;f:finish()
end)
check("Catalogue reserves icon hit area before measuring wrapped titles and notes",function()
    local f=targetSearchFixture();local measured=0
    measurement=function(fs)
        for _,row in ipairs(ui.cards)do if fs==row.title or fs==row.note then
            assert(fs.width==row:GetWidth()-112,"icon width must be reserved before text wrapping")
            measured=measured+1;return 72
        end end
        return 18
    end
    ui:RefreshDungeons();assert(measured>=6 and ui.cards[1].height>=162)
    measurement=nil;f:finish()
end)
check("A reentrant entrance producer cannot erase a newer catalogue icon binding",function()
    local provider,navigation=addon.Entrances,addon.Navigation
    local f=targetSearchFixture();local armed,calls=true,0
    addon.Navigation={StartEntrance=function(d)assert(d==addon.dungeons[3]);calls=calls+1;return true end}
    addon.Entrances={Get=function()
        if armed then armed=false;ui.search="Gamma";ui:RefreshDungeons()end
        return {mapID=1,x=20,y=30},function()return true end
    end}
    ui:RefreshDungeons();assert(ui.search=="Gamma" and ui.cards[1].entranceBinding and ui.cards[1].entranceDungeon==addon.dungeons[3])
    ui.cards[1].entranceControl.scripts.OnClick();assert(calls==1)
    addon.Entrances,addon.Navigation=provider,navigation;f:finish()
end)
check("Catalogue entrance hints explain unknown routes and keep a newer tooltip published during native setters",function()
    local provider,navigation,tooltip=addon.Entrances,addon.Navigation,GameTooltip
    local f=targetSearchFixture();local armed,hidden=false,0
    addon.Entrances={Get=function(d)
        if d==addon.dungeons[3]then return nil end
        return {mapID=1,x=20,y=30,name=d.name},function()return true end
    end}
    addon.Navigation={StartEntrance=function()return true end};ui:RefreshDungeons()
    local tip={}
    function tip:SetOwner(owner)self.owner=owner end
    function tip:IsOwned(owner)return self.owner==owner end
    function tip:SetText(value)
        self.text=value
        if armed then armed=false;ui.cards[2].entranceControl.scripts.OnEnter()end
    end
    function tip:AddLine(value)self.line=value end
    function tip:Show()self.shown=true end
    function tip:Hide()hidden=hidden+1;self.shown=false end
    GameTooltip=tip
    ui.cards[3].entranceControl.scripts.OnEnter()
    assert(not ui.cards[3].entranceControl.enabled and tip.line:find(addon.L("DUNGEON_ENTRANCE_UNKNOWN"),1,true))
    ui:HideNavigationHint();hidden=0;armed=true
    ui.cards[1].entranceControl.scripts.OnEnter()
    assert(tip.owner==ui.cards[2].entranceControl and tip.shown and tip.line:find("Beta dungeon",1,true))
    assert(hidden==1,"only replacing the original tooltip may hide it; old cleanup must not hide the newer one")
    ui:HideNavigationHint();GameTooltip=tooltip;addon.Entrances,addon.Navigation=provider,navigation;f:finish()
end)
check("Late catalogue icon native enabled and alpha setters restore the newer recycled binding",function()
    for _,method in ipairs({"SetEnabled","SetAlpha","SetDesaturated"})do
        local provider,navigation=addon.Entrances,addon.Navigation
        local f=targetSearchFixture()
        addon.Entrances={Get=function(d)
            if d==addon.dungeons[3]then return nil end
            return {mapID=1,x=20,y=30},function()return true end
        end}
        addon.Navigation={StartEntrance=function()return true end};ui:RefreshDungeons()
        local control=ui.cards[1].entranceControl
        local target=method=="SetEnabled"and control or control.footerIcon
        local original,armed=target[method],true
        target[method]=function(self,value)
            if armed then armed=false;ui.search="Gamma";ui:RefreshDungeons()end
            return original(self,value)
        end
        ui:RefreshDungeons()
        assert(ui.search=="Gamma"and not control.enabled and not control.footerEnabled and not ui.cards[1].entranceBinding)
        assert(control.footerIcon.alpha==.3 and control.footerIcon.desaturated==true,"new disabled icon style owns late setters")
        target[method]=original;addon.Entrances,addon.Navigation=provider,navigation;f:finish()
    end
end)
check("The sole giver footer icon replaces both header actions and selects guide or map-only navigation",function()
    for _,mapOnly in ipairs({false,true})do
        local f=primaryHandoffFixture(mapOnly);local starts,maps=0,0
        local giver=ui.giverAction
        assert(ui.map==nil and ui.guide==nil and ui.entrance==nil,"removed toolbar actions must not exist as hidden controls")
        assert(ui.giver.enabled and ui.giver.footerIcon.shown and ui.giver.footerLabelKey==(mapOnly and "GIVER_MAP"or"VISIT_GIVER"))
        addon.Navigation={Start=function(value)assert(not mapOnly and value==giver);starts=starts+1;return true end,
            Map=function(value)assert(mapOnly and value==giver.place);maps=maps+1;return true end}
        ui.giver.scripts.OnClick()
        assert(starts==(mapOnly and 0 or 1)and maps==(mapOnly and 1 or 0)and ui.frame.shown and f.hidden==0)
        giver.place.mapID=nil
        ui.giver.scripts.OnClick();assert(starts+maps==1,"stale giver coordinates cannot reuse the icon action")
        f:finish()
    end
end)
local function inlineTreeFixture()
    local f={dungeon=ui.dungeon,quest=ui.quest,context=addon.Context,history=ui.detailHistory,root=ui.questTreeRoot,treeDungeon=ui.questTreeDungeon}
    for id=43000,43004 do addon.quests[id]={id=id,minLevel=1,requirementsKnown=true}end
    addon.quests[43000].requires={{ids={43001,43002},mode="completed"}}
    addon.quests[43000].storyline={43001,43000,43003}
    addon.Context=function()return {level=60,active=function()return false end,completed=function(id)return id==43001 end}end
    ui.dungeon={key="inline-tree",name="Inline tree",minLevel=1,maxLevel=60,quests={43000,43004}}
    ui.quest,ui.questTreeRoot,ui.questTreeDungeon=nil,nil,nil;ui.preparation=false;ui.detailHistory={};ui.frame:Show();ui:Refresh()
    function f:row(id,branch)
        for _,row in ipairs(ui.rows)do if row.shown and row.questID==id and (row.questTreeNode==branch or (not branch and row.questTreeTarget)) then return row end end
    end
    function f:anchor(id)
        for _,row in ipairs(ui.rows)do if row.shown and row.anchorQuestID==id then return row end end
        return self:row(id,false)
    end
    function f:finish()
        for id=43000,43004 do addon.quests[id]=nil end
        ui.dungeon,ui.quest,ui.detailHistory,ui.questTreeRoot,ui.questTreeDungeon=self.dungeon,self.quest,self.history,self.root,self.treeDungeon
        addon.Context=self.context;ui:Refresh()
    end
    return f
end
check("Compact inline chains preserve the root while inspecting completed parent sibling and target",function()
    local f=inlineTreeFixture();local root=f:row(43000,false)
    assert(root.height==30 and not root.note.shown and root.title.text==addon.QuestName(43000))
    root.scripts.OnClick();assert(ui.quest==43000 and ui.questTreeRoot==43000)
    local parent=f:row(43001,true);assert(parent and parent.questTreeRelation=="required"and parent.statusIcon.shown and parent.completedStrike.shown)
    assert(parent.title.textColor[1]<.7);ui:ApplyTheme();assert(parent.title.textColor[1]<.7)
    parent.scripts.OnClick();assert(ui.quest==43001 and ui.questTreeRoot==43000 and f:row(43002,true))
    f:row(43002,true).scripts.OnClick();assert(ui.quest==43002 and ui.questTreeRoot==43000)
    f:row(43000,true).scripts.OnClick();assert(ui.quest==43000 and ui.questTreeRoot==43000 and f:row(43001,true)and #ui.detailHistory>=3)
    f:anchor(43000).scripts.OnClick();assert(ui.questTreeRoot==nil and not f:row(43001,true))
    f:finish()
end)
check("Inline OR and story context remain distinct and status reasons stay available on compact-row hover",function()
    local f=inlineTreeFixture();f:anchor(43000).scripts.OnClick()
    local required,story=f:row(43002,true),f:row(43003,true)
    assert(required and story and required.questTreeRelation=="required"and story.questTreeRelation=="story")
    assert(required.note.text:find(addon.L("REQUIREMENT_NOTICE"),1,true)and story.note.text:find(addon.L("STORY_GROUP_NOTICE"),1,true))
    local headings={};for _,row in ipairs(ui.rows)do if row.shown and row.heading then headings[row.title.text]=true end end
    assert(next(headings)==nil and required.note.text:find(addon.L("REQUIREMENT_COMPLETE"),1,true))
    local previous=GameTooltip;local tip={}
    function tip:SetOwner(owner)self.owner=owner end;function tip:IsOwned(owner)return self.owner==owner end
    function tip:SetText(value)self.text=value end;function tip:AddLine(value)self.note=value end
    function tip:Show()self.shown=true end;function tip:Hide()self.shown=false end
    GameTooltip=tip;story.scripts.OnEnter();assert(tip.shown and tip.note==story.note.text and not story.note.shown)
    story.scripts.OnLeave();assert(not tip.shown);GameTooltip=previous
    local old=required.scripts.OnClick;ui.frame:Hide();old();assert(ui.quest==43000);ui.frame:Show()
    f:row(43004,false).scripts.OnClick();old();assert(ui.quest==43004 and ui.questTreeRoot==43004)
    f:finish()
end)
check("Inline source invalidation during title hydration retires old owned hierarchy without hiding a newer render",function()
    local f=inlineTreeFixture();f:anchor(43000).scripts.OnClick()
    local getter,armed=addon.QuestName,true
    addon.QuestName=function(id)
        if armed and id==43001 then armed=false;addon.quests[43000].requires=nil;addon.quests[43000].storyline={43000,43003}end
        return getter(id)
    end
    ui:RefreshQuests();assert(not armed and not f:row(43001,true),"an invalidated required branch cannot remain visibly published")
    addon.QuestName=getter;ui:RefreshQuests();assert(f:row(43003,true)and not f:row(43001,true))
    armed=true
    addon.QuestName=function(id)
        if armed and id==43003 then armed=false;ui.questTreeRoot=43004;ui:RefreshQuests()end
        return getter(id)
    end
    ui:RefreshQuests();assert(not armed and ui.questTreeRoot==43004 and f:row(43004,false).shown)
    addon.QuestName=getter;f:finish()
end)
check("Compact reward space is reserved before wrapped title measurement without revealing a second note line",function()
    local f=inlineTreeFixture();local rewards=addon.QuestListRewards;local measured=0
    addon.QuestListRewards={Paint=function()return 70 end,Clear=function()end}
    measurement=function(fs)
        for _,row in ipairs(ui.rows)do if fs==row.title and row.questID==43000 then
            assert(fs.width==row:GetWidth()-22-70-(row.navigationReserve or 0)-(row.statusInset or 0)-(row.dungeonBadgeReserve or 0)-(row.chainInset or 0)-(row.factionReserve or 0));measured=measured+1;return 54
        end end
        return 18
    end
    ui:RefreshQuests();local row=f:row(43000,false)
    assert(measured>0 and row.height==66 and not row.note.shown and row.title.fontSize==17)
    measurement=nil;addon.QuestListRewards=rewards;f:finish()
end)
check("Late expired-tree cleanup visibility and handlers cannot hide or disable a newer reused story row",function()
    for _,method in ipairs({"Hide","SetScript"})do
        local f=inlineTreeFixture();f:anchor(43000).scripts.OnClick()
        local parent=f:row(43001,true);local original=parent[method];local armed=true
        local getter,source=addon.QuestName,true
        parent[method]=function(self,...)
            if armed and not source and(method=="Hide"or ((...)=="OnClick"and select(2,...)==nil))then
                armed=false;ui:RefreshQuests()
            end
            return original(self,...)
        end
        addon.QuestName=function(id)
            if source and id==43001 then
                source=false;addon.quests[43000].requires=nil;addon.quests[43000].storyline={43000,43003,43004}
            end
            return getter(id)
        end
        ui:RefreshQuests();addon.QuestName=getter;parent[method]=original
        local newer=f:row(43000,true)
        assert(not armed and newer==parent and newer.shown and type(newer.scripts.OnClick)=="function",method)
        newer.scripts.OnClick();assert(ui.quest==43000 and ui.questTreeRoot==43000)
        f:finish()
    end
end)
check("Inline child surfaces attach to their root with rails and exact-ID dungeon badges without duplicate targets",function()
    local f=inlineTreeFixture();local names=addon.QuestName
    addon.QuestName=function(id)if id==43000 or id==43003 then return "Same visible title"end;return names(id)end
    ui.dungeon.quests={43000,43003,43004};ui:RefreshQuests();f:anchor(43000).scripts.OnClick()
    local seen={};for _,row in ipairs(ui.rows)do if row.shown then
        assert(not row.heading,"inline branches must not add large caution headings")
        if row.questID then assert(not seen[row.questID],"each exact quest ID appears once");seen[row.questID]=true
        else assert(row.questTreeAnchor and row.anchorQuestID==43000)end
        if row.questTreeNode then
            assert(row.point[2]==24 and row.width+row.point[2]==ui.questList:GetWidth()-4)
            assert(row.treeRail.shown and row.treeElbow.shown and row.height==30 and row.title.point[2]==28)
        else assert(row.point[2]==0)end
        local target=row.questID==43000 or row.questID==43003 or row.questID==43004
        assert(row.dungeonTarget==target and (row.dungeonBadge and row.dungeonBadge.shown or false)==(target and row.questTreeNode))
    end end
    assert(seen[43000]and seen[43003]and not f:row(43003,false))
    assert(f:row(43000,false).title.text=="Same visible title #43000"and f:row(43003,true).title.text=="Same visible title #43003","duplicate names retain distinct visible IDs")
    local previous=GameTooltip;local tip={}
    function tip:SetOwner(owner)self.owner=owner end;function tip:IsOwned(owner)return self.owner==owner end
    function tip:SetText(value)self.text=value end;function tip:AddLine(value)self.line=value end
    function tip:Show()self.shown=true end;function tip:Hide()self.shown=false end
    GameTooltip=tip;f:row(43003,true).scripts.OnEnter()
    assert(tip.line:find("Inline tree — "..addon.L("QUESTS"),1,true))
    f:row(43003,true).scripts.OnLeave();GameTooltip=previous;addon.QuestName=names;f:finish()
end)
check("Quest-list rebuild masks reused content until all new titles and layout have been staged",function()
    local f=inlineTreeFixture();local names=addon.QuestName
    local first,second=f:row(43000,false),f:row(43004,false)
    local setter,show=first.title.SetText,first.Show;local staged,published=false,false
    addon.QuestName=function(id)return "Fresh title "..id end
    first.title.SetText=function(self,value)
        if value=="Fresh title 43000"then staged=true;assert(not first.shown and not second.shown)end
        return setter(self,value)
    end
    first.Show=function(self)
        published=true;assert(first.title.text=="Fresh title 43000"and second.title.text=="Fresh title 43004")
        assert(first.point and second.point and first.height==30 and second.height==30)
        return show(self)
    end
    ui:RefreshQuests();assert(staged and published and first.shown and second.shown)
    first.title.SetText,first.Show=setter,show;addon.QuestName=names;f:finish()
end)
check("Dungeon membership changes during title hydration cannot publish stale target badges",function()
    local f=inlineTreeFixture();local names,armed=addon.QuestName,true
    addon.QuestName=function(id)
        if armed and id==43000 then armed=false;ui.dungeon.quests[1]=43003 end
        return names(id)
    end
    ui:RefreshQuests();assert(not armed)
    for _,row in ipairs(ui.rows)do assert(not row.shown,"unproven membership cannot publish a staged badge")end
    addon.QuestName=names;ui:RefreshQuests();assert(f:row(43003,false).dungeonTarget and f:row(43004,false).dungeonTarget)
    f:finish()
end)
check("Quest prioritizes objectives rewards and one named giver while Story remains a separate view",function()
    local f=inlineTreeFixture();local description,objectives,rewards,dialogue,log=addon.Description,addon.QuestObjectives,addon.CachedQuestRewards,addon.DialogueRewards,addon.QuestRewards
    addon.quests[43000].start={name="Named primary giver",mapID=1,x=20,y=30}
    addon.DialogueRewards,addon.QuestRewards=nil,nil
    addon.Description=function()return "Selected quest narrative"end
    addon.QuestObjectives=function()return{{text="Selected live objective",finished=false}}end
    addon.CachedQuestRewards=function()return{source="cache",items={{name="Selected reward",count=1}},choices={}}end
    f:anchor(43000).scripts.OnClick()
    assert(ui.summary==nil and ui.coverage==nil and type(ui.currentPlan.counts)=="table")
    assert(ui.questScroll.point[3]==-100 and ui.detailScroll.point[3]==-66 and ui.questScroll.height==588 and ui.detailScroll.height==622)
    assert(not ui.detailReferencesExpanded and not(ui.storyToggle and ui.storyToggle.shown))
    assert(not detailHas("Selected quest narrative"),"default Quest keeps Story separate")
    assert(detailIncludes("Selected live objective"),"default progress")
    assert(detailHas("Selected reward"),"default cached reward")
    local giverLines=0
    for _,fs in ipairs(ui.details)do if fs.shown then
        if fs.text:find("Named primary giver",1,true)then giverLines=giverLines+1 end
    end end
    assert(giverLines==1 and not(ui.referenceToggle and ui.referenceToggle.shown))
    assert(not detailHas(addon.L("NEXT"))and not detailHas(addon.L("STORY_SHORT")))
    local action=ui.action;assert(action)
    assert(not(ui.referenceToggle and ui.referenceToggle.scripts.OnClick) and not(ui.storyToggle and ui.storyToggle.shown))
    ui:RefreshDetail();assert(ui.action.id==action.id and not detailHas("Selected quest narrative"))
    assert(ui:SetDetailTab("story") and detailHas("Selected quest narrative"))
    assert(not detailIncludes("Selected live objective") and not detailHas("Selected reward"))
    assert(ui:SetDetailTab("quest") and ui.action.id==action.id and detailHas("Selected reward"))
    addon.Description,addon.QuestObjectives,addon.CachedQuestRewards,addon.DialogueRewards,addon.QuestRewards=description,objectives,rewards,dialogue,log;f:finish()
end)
check("No-dungeon PICK notice clears recycled quest decorations and reward ownership",function()
    local f=inlineTreeFixture();local context=addon.Context
    addon.Context=function()return{level=60,active=function()return false end,completed=function()return true end}end
    ui:RefreshQuests();local row=ui.rows[1]
    assert((not row.dungeonBadge or not row.dungeonBadge.shown)and row.statusIcon.shown and row.completedStrike.shown)
    local clear,clears=addon.QuestListRewards.Clear,0
    addon.QuestListRewards.Clear=function(value)if value==row then clears=clears+1 end;return clear(value)end
    ui.dungeon,ui.quest=nil,nil;ui:RefreshQuests()
    assert(ui.currentPlan==nil and row.shown and row.heading=="PICK"and row.title.text==addon.L("PICK"))
    assert((not row.dungeonBadge or not row.dungeonBadge.shown) and not row.statusIcon.shown and not row.completedStrike.shown and clears==1)
    assert(row.width==ui.questList:GetWidth()-4 and row.title.width==ui.questList:GetWidth()-22 and not row.scripts.OnClick)
    addon.QuestListRewards.Clear=clear;addon.Context=context;f:finish()
end)
check("No-dungeon PICK retires the persistent target anchor and all branch presentation flags",function()
    local f=inlineTreeFixture();f:anchor(43000).scripts.OnClick();local anchor=f:anchor(43000)
    assert(anchor==ui.rows[1]and anchor.questTreeAnchor and anchor.anchorQuestID==43000)
    ui.dungeon,ui.quest=nil,nil;ui:RefreshQuests()
    assert(anchor.heading=="PICK"and anchor.shown and not anchor.questTreeAnchor and anchor.anchorQuestID==nil)
    assert(not anchor.questTreeSelected and not anchor.questTreePath and not anchor.questTreeTarget)
    assert(not anchor.dungeonTargetLabel or not anchor.dungeonTargetLabel.shown)
    f:finish()
end)
check("Right header search reserves input and clear space while icon filters sit beside the dungeon heading",function()
    local locale=addon.db.locale
    for code in pairs(addon.locales)do
        addon.db.locale=code;ui:Refresh()
        assert(ui.subtitle==nil and ui.title.fontSize==22 and ui.heading.width==226)
        assert(ui.searchBox.point[1]=="TOPRIGHT" and ui.searchBox.point[2]==-190 and ui.searchBox.point[3]==-14)
        assert(ui.searchBox.width==330 and ui.searchBox.height==26)
        assert(ui.searchBox.textInsets[1]==28 and ui.searchBox.textInsets[2]==30)
        assert(ui.searchPlaceholder.point[2]==28 and ui.searchPlaceholder.width==ui.searchBox.width-62)
        assert(ui.clearSearch.point[1]=="RIGHT" and ui.clearSearch.point[2]==ui.searchBox and ui.clearSearch.point[4]==-3)
        assert(ui.heading.point[2]+ui.heading.width<ui.characterButton.point[2])
        assert(ui.rangeButton.point[2]==178 and ui.characterButton.point[2]==548)
        assert(ui.rangeButton.point[3]==-14 and ui.characterButton.point[3]==-66 and ui.rangeButton.height==32 and ui.characterButton.height==32)
        assert(ui.catalogScroll.point[2]+ui.catalogScroll.width+23<=ui.questScroll.point[2]-2)
        assert(ui.questScroll.point[2]+ui.questScroll.width+23<=ui.detailScroll.point[2]-2)
        assert(ui.detailScroll.point[2]+ui.detailScroll.width+23<=ui.frame:GetWidth()-2)
    end
    addon.db.locale=locale;ui:Refresh()
end)
local function developerPopupFixture()
    local f={dialogs=StaticPopupDialogs,show=StaticPopup_Show,hide=StaticPopup_Hide,shown=ui.frame.shown,calls=0}
    StaticPopupDialogs={};local box=object();local popup=object()
    function popup:GetEditBox()return box end;function box:GetParent()return popup end
    f.box,f.popup=box,popup
    StaticPopup_Hide=function(key)assert(key=="DUNGEONPRO_COPY_DEVELOPER_LINK");popup:Hide()end
    StaticPopup_Show=function(key,message,unused,data)
        assert(key=="DUNGEONPRO_COPY_DEVELOPER_LINK"and unused==nil)
        f.calls=f.calls+1;f.message,f.data,f.definition=message,data,StaticPopupDialogs[key]
        popup:Show();f.definition.OnShow(popup,data);return popup
    end
    ui.frame:Show()
    function f:finish()
        ui.developerLinkRequest=nil;StaticPopupDialogs,StaticPopup_Show,StaticPopup_Hide=self.dialogs,self.show,self.hide
        ui.frame:SetShown(self.shown)
    end
    return f
end
check("Header issue and support actions expose only verified copy links and close with Enter or Escape",function()
    local f=developerPopupFixture()
    ui.issueLink.scripts.OnClick();assert(f.calls==1 and f.box.text=="https://github.com/Antrakt92/DungeonPro/issues"and f.box.focused and f.box.highlighted)
    assert(f.message:find(addon.L("REPORT_ISSUE"),1,true)and f.message:find(addon.L("COPY"),1,true))
    local old,data=f.definition,f.data
    ui.supportLink.scripts.OnClick();assert(f.calls==2 and f.box.text=="https://ko-fi.com/antrakt92")
    old.OnShow(f.popup,data);old.EditBoxOnEscapePressed(f.box);assert(f.popup.shown and f.box.text=="https://ko-fi.com/antrakt92")
    f.definition.EditBoxOnEnterPressed(f.box);assert(not f.popup.shown)
    ui.issueLink.scripts.OnClick();f.definition.EditBoxOnEscapePressed(f.box);assert(not f.popup.shown)
    local calls=f.calls;assert(not ui:ShowDeveloperLink("https://foreign.invalid"));assert(f.calls==calls)
    ui.frame:Hide();ui.issueLink.scripts.OnClick();assert(f.calls==calls);ui.frame:Show()
    local show=StaticPopup_Show;StaticPopup_Show=nil;assert(not ui:ShowDeveloperLink("issue"));StaticPopup_Show=show
    f:finish()
end)
check("A late developer copy setter cannot overwrite a newer support popup",function()
    local f=developerPopupFixture();local setter=f.box.SetText;local armed=true
    f.box.SetText=function(self,value)
        if armed and value=="https://github.com/Antrakt92/DungeonPro/issues"then armed=false;assert(ui:ShowDeveloperLink("support"))end
        return setter(self,value)
    end
    assert(not ui:ShowDeveloperLink("issue"));assert(not armed and f.box.text=="https://ko-fi.com/antrakt92"and f.popup.shown)
    f.box.SetText=setter;f:finish()
end)
check("Retained catalogue language paint refreshes ordinary dungeon and matched quest labels through current resolvers",function()
    local f=targetSearchFixture();local preview=false
    addon.DungeonName=function(d)return(preview and "Localized "or"")..d.name end
    f.cachedNames[31001]="Cached target";f:search("31001")
    preview=true;f.cachedNames[31001]="Localized cached target"
    assert(ui:RefreshCatalogLanguage())
    for _,row in ipairs(f:cards())do
        assert(row.title.text:find("Localized ",1,true)==1 and row.note.text:find("Localized cached target",1,true))
    end
    f:finish()
end)
check("Header link tooltip stops after a native setter transfers tooltip ownership",function()
    local previous=GameTooltip;local tip={};local additions,shows=0,0;local foreign={}
    function tip:SetOwner(owner)self.owner=owner end;function tip:IsOwned(owner)return self.owner==owner end
    function tip:SetText()self.owner=foreign;self.shown=false end
    function tip:AddLine()additions=additions+1 end;function tip:Show()shows=shows+1;self.shown=true end
    function tip:Hide()self.shown=false end
    GameTooltip=tip;ui.issueLink.scripts.OnEnter()
    assert(tip.owner==foreign and not tip.shown and additions==0 and shows==0)
    ui.issueLink.scripts.OnLeave();assert(tip.owner==foreign and not tip.shown)
    GameTooltip=previous
end)
check("Filter tooltips identify current mode and next click action in all languages",function()
    local previous,locale,range,all=GameTooltip,addon.db.locale,ui.range,ui.includeUnavailable
    local tip={};function tip:SetOwner(owner)self.owner=owner;self.lines={}end
    function tip:IsOwned(owner)return self.owner==owner end
    function tip:SetText(value)self.text=value end
    function tip:AddLine(value)self.lines[#self.lines+1]=value end
    function tip:Show()self.shown=true end;function tip:Hide()self.shown=false end
    GameTooltip=tip;ui.frame:Show()
    for code in pairs(addon.locales)do
        addon.db.locale=code
        for _,value in ipairs({false,true})do
            ui.range=value;ui.includeUnavailable=value;ui:Refresh()
            for _,control in ipairs({ui.rangeButton,ui.characterButton})do
                control.scripts.OnEnter()
                assert(tip.shown and tip.owner==control and tip.text==addon.L(control.filterHeadingKey))
                assert(tip.lines[1]==addon.L(control.filterLabelKey))
                assert(tip.lines[2]==addon.L("FILTER_SWITCH",addon.L(control.filterTargetKey)))
                control.scripts.OnLeave();assert(not tip.shown)
            end
        end
    end
    GameTooltip,addon.db.locale,ui.range,ui.includeUnavailable=previous,locale,range,all;ui:Refresh()
end)
check("Filter tooltip stops when native ownership transfers or planner closes",function()
    local previous=GameTooltip;local tip={};local foreign={};local additions,shows=0,0
    function tip:SetOwner(owner)self.owner=owner end;function tip:IsOwned(owner)return self.owner==owner end
    function tip:SetText()self.owner=foreign end;function tip:AddLine()additions=additions+1 end
    function tip:Show()shows=shows+1 end;function tip:Hide()end
    GameTooltip=tip;ui.rangeButton.scripts.OnEnter()
    assert(tip.owner==foreign and additions==0 and shows==0)
    ui.frame:Hide();tip.owner=nil;ui.characterButton.scripts.OnEnter();assert(tip.owner==nil)
    ui.frame:Show();GameTooltip=previous
end)
check("Actual Toxic Soil first step selects while the exact dungeon target stays anchored at its recorded story position",function()
    local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    local saved={quests=addon.quests,name=addon.QuestName,context=addon.Context,dungeon=ui.dungeon,quest=ui.quest,
        root=ui.questTreeRoot,treeDungeon=ui.questTreeDungeon,history=ui.detailHistory,all=ui.includeUnavailable,locale=addon.db.locale}
    addon.quests=actual.quests;addon.QuestName=function(id)return actual.quests[id]and actual.quests[id].name or saved.name(id)end
    addon.Context=function()return {level=60,faction="Alliance",raceID=3,completed=function()return false end,active=function()return false end}end
    for _,d in ipairs(actual.dungeons)do for _,id in ipairs(d.quests)do if id==92753 then ui.dungeon=d end end end
    assert(ui.dungeon~=saved.dungeon)
    ui.quest,ui.questTreeRoot,ui.questTreeDungeon=nil,nil,nil;ui.includeUnavailable=true;ui.detailHistory={};ui:Refresh()
    local function row(id)for _,r in ipairs(ui.rows)do if r.shown and r.questID==id then return r end end end
    assert(not row(92753).dungeonTargetLabel or not row(92753).dungeonTargetLabel.shown)
    row(92753).scripts.OnClick()
    local anchor;local ids,order={},{}
    for _,r in ipairs(ui.rows)do if r.shown then
        if r.questTreeAnchor then anchor=r;assert(r.questID==nil and r.anchorQuestID==92753 and not r.dungeonTarget)
        elseif r.questID then assert(not ids[r.questID]);ids[r.questID]=true;if r.questTreeNode then order[#order+1]=r.questID end end
    end end
    assert(anchor and #order==11 and order[1]==92742 and order[10]==92753 and order[11]==92819)
    local first,target,later=row(92742),row(92753),row(92819)
    assert(first.enabled and first.questTreePath and first.questTreeRelation=="story")
    assert(target.questTreeTarget and target.dungeonTarget and target.dungeonTargetLabel.shown and target.dungeonTargetLabel.text==addon.L("DUNGEON_QUEST_SHORT"))
    assert(target.title.text=="Destruction in Deadmines #92753"and later.title.text=="Destruction in Deadmines #92819")
    assert(target.questTreePath and not later.questTreePath and not later.dungeonTarget and later.dungeonTargetLabel.shown and later.dungeonTargetLabel.text==addon.L("STORY_SHORT"))
    assert(row(92750).title.text:find("#92750",1,true)and row(92751).title.text:find("#92751",1,true))
    local firstY,targetY=-first.point[3],-target.point[3]
    assert(firstY>=-anchor.point[3]+anchor.height+2 and targetY>firstY)
    first.scripts.OnClick();assert(ui.quest==92742 and ui.questTreeRoot==92753 and row(92742).questTreeSelected and not row(92753).questTreeSelected)
    local stale=row(92742).scripts.OnClick
    row(92819).scripts.OnClick();assert(ui.quest==92819 and ui.questTreeRoot==92753 and row(92819).questTreeSelected and row(92753).questTreeTarget)
    row(92753).scripts.OnClick();assert(ui.quest==92753 and ui.questTreeRoot==92753 and row(92753).questTreeSelected)
    for _,r in ipairs(ui.rows)do if r.shown and r.questTreeAnchor then anchor=r end end
    anchor.scripts.OnClick();assert(ui.questTreeRoot==nil);stale();assert(ui.quest==92753)
    assert(not row(92753).dungeonTargetLabel or not row(92753).dungeonTargetLabel.shown)
    addon.quests,addon.QuestName,addon.Context=saved.quests,saved.name,saved.context
    ui.dungeon,ui.quest,ui.questTreeRoot,ui.questTreeDungeon=saved.dungeon,saved.quest,saved.root,saved.treeDungeon
    ui.detailHistory,ui.includeUnavailable,addon.db.locale=saved.history,saved.all,saved.locale;ui:Refresh()
end)
local function dungeonCardStatusFixture()
    local f={quests=addon.quests,dungeons=addon.dungeons,context=addon.Context,name=addon.DungeonName,search=ui.search,range=ui.range,
        namespace=C_Texture,atlas=methods.SetAtlas,vertex=methods.SetVertexColor,revision=1,done={[52001]=true},active={[52002]=true,[52003]=true},ready={[52003]=true}}
    addon.quests={};addon.dungeons={}
    for id=52001,52008 do addon.quests[id]={id=id,name="Status quest "..id,minLevel=1,requirementsKnown=true}end
    addon.quests[52005].minLevel=80;addon.quests[52006].requirementsKnown=false;addon.quests[52007].requires={{ids={52004}}}
    addon.quests[52008].factions={"Horde"}
    for index,id in ipairs({52001,52002,52003,52004,52005,52006,52007,52008})do
        addon.dungeons[index]={key="status-card-"..id,name="Status dungeon "..id,minLevel=10,maxLevel=30,coverage="partial",quests={id}}
    end
    addon.dungeons[9]={key="empty-status",name="Empty status dungeon",minLevel=10,maxLevel=30,coverage="partial",quests={}}
    addon.Context=function()
        local revision=f.revision
        return {level=60,faction="Alliance",current=function()return f.revision==revision end,
            completed=function(id)return f.done[id]==true end,active=function(id)return f.active[id]==true end,ready=function(id)return f.ready[id]==true end}
    end
    addon.DungeonName=function(d)return d.name end
    methods.SetAtlas=function(self,atlas)self.atlas=atlas end
    methods.SetVertexColor=function(self,...)self.vertexColor={...}end
    C_Texture={GetAtlasInfo=function()return{}end}
    ui.search="";ui.range=false;ui.frame:Show();ui:RefreshDungeons()
    function f:finish()
        addon.quests,addon.dungeons,addon.Context,addon.DungeonName=self.quests,self.dungeons,self.context,self.name
        C_Texture,methods.SetAtlas,methods.SetVertexColor=self.namespace,self.atlas,self.vertex
        ui.search,ui.range=self.search,self.range;ui:RefreshDungeons()
    end
    return f
end
check("Compact dungeon cards separate cover titles metadata entrance actions and truthful character status glyphs",function()
    local f=dungeonCardStatusFixture();local statuses={"COMPLETED","ACTIVE","READY","AVAILABLE","LOCKED","UNKNOWN","LOCKED","UNAVAILABLE","UNAVAILABLE"}
    for index,status in ipairs(statuses)do
        local row=ui.cards[index];local control=row.dungeonStatusControl;local icon=control.statusIcon
        assert(row.dungeonStatusDTO.status==status and control.shown and icon.shown and control.kind=="Frame"and not control.scripts.OnClick)
        assert(row.art.width==56 and row.art.height==60 and row.art.point[2]==8 and -row.art.point[3]==(row.height-60)/2)
        assert(row.title.point[2]==76 and row.note.point[2]==76 and row.title.width==row:GetWidth()-112 and row.note.fontSize==12)
        assert(row.height>=76 and -row.entranceControl.point[5]+row.entranceControl.height<=-control.point[5]-4)
        assert(-control.point[5]==(row.height-60)/2+32 and control.width==28 and icon.width==20)
        assert(row.note.text==addon.L("CATALOG_COMPACT_META",10,30,(index==9 or (index==8 and not ui.includeUnavailable)) and 0 or 1))
        if index>1 then assert(-row.point[3]>=-ui.cards[index-1].point[3]+ui.cards[index-1].height+8)end
    end
    assert(ui.cards[1].dungeonStatusControl.statusIcon.texture=="Interface\\RaidFrame\\ReadyCheck-Ready")
    assert(ui.cards[2].dungeonStatusControl.statusIcon.atlas=="Quest-In-Progress-Icon-yellow")
    assert(ui.cards[3].dungeonStatusControl.statusIcon.atlas=="UI-QuestIcon-TurnIn-Normal")
    assert(ui.cards[5].dungeonStatusControl.statusIcon.vertexColor[2]==.2 and not ui.cards[5].dungeonStatusControl.statusIcon.desaturated)
    assert(ui.cards[6].dungeonStatusControl.statusIcon.desaturated and ui.cards[7].dungeonStatusControl.statusIcon.desaturated)
    f:finish()
end)
check("Warm catalogue language paint reuses status snapshots without new aggregation or quest State queries",function()
    local f=dungeonCardStatusFixture();local get,new=addon.DungeonStatus.Get,addon.Planner.New;local gets,states=0,0
    addon.DungeonStatus.Get=function(...)gets=gets+1;return get(...)end
    addon.Planner.New=function(...)
        local engine=new(...);local state=engine.State
        engine.State=function(self,...)states=states+1;return state(self,...)end
        return engine
    end
    ui:RefreshDungeons();assert(gets==9 and states>=8)
    local snapshot,initialStates=ui.cards[1].dungeonStatusDTO,states
    for index=1,10 do assert(ui:RefreshCatalogLanguage());assert(ui.cards[1].dungeonStatusDTO==snapshot)end
    assert(gets==9 and states==initialStates)
    f.done[52004]=true;f.revision=f.revision+1
    assert(not ui:RefreshCatalogLanguage());ui:RefreshDungeons()
    assert(ui.cards[4].dungeonStatusDTO.status=="COMPLETED"and gets==18 and states>initialStates)
    addon.DungeonStatus.Get,addon.Planner.New=get,new;f:finish()
end)
check("Dungeon status tooltips explain listed-character scope and reject stale rows foreign owners and player changes",function()
    local f=dungeonCardStatusFixture();local previous,locale=GameTooltip,addon.db.locale;local tip={}
    function tip:SetOwner(owner)self.owner=owner;self.lines={}end;function tip:IsOwned(owner)return self.owner==owner end
    function tip:SetText(value)self.text=value end;function tip:AddLine(value)self.lines[#self.lines+1]=value end
    function tip:Show()self.shown=true end;function tip:Hide()self.shown=false end
    GameTooltip=tip
    for code in pairs(addon.locales)do
        addon.db.locale=code;ui:RefreshDungeons()
        for _,entry in ipairs({{5,"DUNGEON_STATUS_LEVEL"},{6,"DUNGEON_STATUS_UNKNOWN"},{9,"DUNGEON_STATUS_EMPTY"}})do
            local control=ui.cards[entry[1]].dungeonStatusControl;control.scripts.OnEnter()
            assert(tip.shown and tip.lines[1]==addon.L(entry[2])and tip.lines[3]==addon.L("DUNGEON_STATUS_SCOPE"))
            control.scripts.OnLeave();assert(not tip.shown)
        end
    end
    local row=ui.cards[5];local old=row.dungeonStatusControl.scripts.OnEnter
    row:Hide();old();assert(not tip.shown);row:Show()
    local char=addon.char;addon.char={};old();assert(not tip.shown);addon.char=char
    local text=tip.SetText;local foreign={}
    tip.SetText=function(self)self.owner=foreign end;old();assert(not tip.shown and tip.owner==foreign)
    tip.SetText=text;ui.search="Empty";ui:RefreshDungeons();old();assert(not tip.shown)
    GameTooltip,addon.db.locale=previous,locale;f:finish()
end)
local function compactNarrativeFixture()
    local f={description=addon.Description,quest=ui.quest,dungeon=ui.dungeon,engine=ui.engine,
        referenceQuest=ui.detailReferenceQuest,referenceDungeon=ui.detailReferenceDungeon,references=ui.detailReferencesExpanded,
        chain=ui.detailChainExpanded,narrative=ui.detailNarrativeExpanded,locale=addon.db.locale,reads=0}
    addon.quests[53001]={id=53001,level=18,minLevel=9,requirementsKnown=true,start={name="Narrative giver",mapID=1,x=20,y=30}}
    addon.quests[53002]={id=53002,level=20,minLevel=10,requirementsKnown=true}
    f.prose=string.rep("Я",300)
    addon.Description=function(id)f.reads=f.reads+1;return id==53001 and f.prose or "Different short story"end
    ui.dungeon={key="compact-narrative",name="Narrative dungeon",quests={53001,53002}}
    ui.detailReferenceQuest=nil;showCompactDetail(53001)
    function f:finish()
        addon.Description=self.description;addon.quests[53001],addon.quests[53002]=nil,nil
        ui.quest,ui.dungeon,ui.engine=self.quest,self.dungeon,self.engine
        ui.detailReferenceQuest,ui.detailReferenceDungeon=self.referenceQuest,self.referenceDungeon
        ui.detailReferencesExpanded,ui.detailChainExpanded,ui.detailNarrativeExpanded=self.references,self.chain,self.narrative
        addon.db.locale=self.locale;ui:RefreshDetail()
    end
    return f
end
check("Story preserves full UTF8 prose across all locales without reading inactive text",function()
    local f=compactNarrativeFixture()
    for code in pairs(addon.locales)do
        addon.db.locale=code
        local glyph=code=="koKR"and "한"or "Я"
        if code=="zhCN"or code=="zhTW"then glyph="汉"end
        f.prose=string.rep(glyph,300)
        local before=f.reads;ui:RefreshDetail();assert(f.reads==before,"Quest does not poll hidden story text")
        ui.detailTabButtons.story.scripts.OnClick()
        assert(f.reads==before+1 and detailHas(f.prose)and not detailHas(string.rep(glyph,240).."…"))
        assert(ui.details[1].fontSize==22 and ui.detailTabButtons.story.label.text==addon.L("TAB_STORY"))
        assert(not(ui.narrativeToggle and ui.narrativeToggle.shown))
        local old=ui.detailTabButtons.story.scripts.OnClick;old()
        assert(ui.detailTab=="story"and f.reads==before+1,"reselecting Story does not request text again")
        ui.detailTabButtons.quest.scripts.OnClick()
        assert(ui.detailTab=="quest"and not detailHas(f.prose)and f.reads==before+1)
    end
    ui:SetDetailTab("story");local stale=ui.detailTabButtons.story.scripts.OnClick
    showCompactDetail(53002);stale()
    assert(ui.quest==53002 and ui.detailTab=="quest"and not detailHas("Different short story"))
    ui:SetDetailTab("story");assert(detailHas("Different short story"))
    f:finish()
end)
check("Late Story tab hide and prose writes preserve a newer same-quest render",function()
    for _,operation in ipairs({"Hide","SetText"})do
        local f=compactNarrativeFixture();ui:SetDetailTab("story")
        local object=ui.detailTabButtons.story
        if operation=="SetText"then
            for _,line in ipairs(ui.details)do if line.shown and line.text==f.prose then object=line end end
            assert(object~=ui.detailTabButtons.story,"hook the actual visible story body")
        end
        local original,armed=object[operation],true
        object[operation]=function(self,...)
            if armed then armed=false;f.prose=string.rep("汉",300);ui:RefreshDetail()end
            return original(self,...)
        end
        ui:RefreshDetail();object[operation]=original
        assert(not armed and ui.detailTab=="story"and ui.detailTabButtons.story.shown and ui.quest==53001)
        assert(detailHas(f.prose)and not detailHas(string.rep("Я",300)),"old native tail cannot replace current prose")
        f:finish()
    end
end)
check("Compact metadata and rewards remove duplicate default prose while advanced facts stay available",function()
    local f=compactNarrativeFixture();addon.quests[53001].startAlternatives={{name="Additional giver",mapID=1,x=22,y=33}}
    local rewards,dialogue,log,coin=addon.CachedQuestRewards,addon.DialogueRewards,addon.QuestRewards,GetCoinTextureString
    addon.DialogueRewards,addon.QuestRewards=nil,nil
    addon.CachedQuestRewards=function()return{source="cache",items={},choices={},xp=123,money=456}end
    GetCoinTextureString=function(amount)assert(amount==456);return"coins"end
    ui:RefreshDetail()
    assert(detailHas(addon.L("DETAIL_LEVEL",18).." · "..addon.L("DETAIL_MIN_LEVEL",9)))
    assert(detailHas(addon.L("DETAIL_GIVER"))and not detailHas(addon.L("QUEST_GIVER")))
    assert(detailHas(addon.L("DETAIL_REWARDS"))and detailHas(addon.L("REWARD_XP",123).." · "..addon.L("REWARD_MONEY")..": coins"))
    assert(not detailHas(addon.L("REWARD_NO_ITEMS"))and not detailHas(addon.L("REWARD_PREVIEW")))
    assert(ui:SetDetailTab("sources"))
    assert(detailIncludes(addon.L("DETAIL_LEVEL",18))and detailIncludes(addon.L("DETAIL_MIN_LEVEL",9)))
    assert(startButton(1).shown and startButton(1).title.text=="Additional giver" and not detailHas(addon.L("DETAIL_REWARDS")))
    assert(ui:SetDetailTab("quest") and detailHas(addon.L("REWARD_XP",123)))
    addon.CachedQuestRewards=function()return nil end;ui:RefreshDetail()
    assert(not detailHas(addon.L("DETAIL_REWARDS"))and not detailHas(addon.L("REWARD_UNAVAILABLE")))
    assert(ui:SetDetailTab("sources"));assert(not detailHas(addon.L("REWARD_UNAVAILABLE")))
    addon.CachedQuestRewards,addon.DialogueRewards,addon.QuestRewards,GetCoinTextureString=rewards,dialogue,log,coin;f:finish()
end)
check("Level filtering occupies the global header while character filtering stays scoped to quest heading",function()
    local locale,range,all=addon.db.locale,ui.range,ui.includeUnavailable
    for code in pairs(addon.locales)do
        addon.db.locale=code;ui.range=false;ui.includeUnavailable=false;ui:Refresh()
        local level,character=ui.rangeButton,ui.characterButton
        assert(level.point[2]==178 and level.point[3]==-14 and level.width==160 and level.height==32 and not level.filterIcon)
        assert(level.text==addon.L("FILTER_LEVEL_ALL"))
        assert(ui.title.point[2]+ui.title.width<level.point[2]and level.point[2]+level.width<ui.capacityStatus.point[2])
        assert(ui.capacityStatus.point[2]==350 and ui.capacityStatus.point[3]==-22 and ui.capacityStatus.width==220)
        local searchLeft=ui.frame:GetWidth()+ui.searchBox.point[2]-ui.searchBox.width
        assert(ui.capacityStatus.point[2]+ui.capacityStatus.width<searchLeft)
        assert(ui.heading.width==226 and ui.heading.point[2]+ui.heading.width<character.point[2])
        assert(character.point[2]==548 and character.point[3]==-66 and character.width==100 and character.height==32)
        assert(character.point[2]+character.width==ui.questScroll.point[2]+ui.questScroll.width)
        assert(character.filterCaption.point[4]==38 and character.filterCaption.width==56 and character.filterCaption.fontSize==13)
        assert(character.filterCaption.text==addon.L("FILTER_QUEST_MINE")and character.filterIcon.shown and character.filterPortrait)
        assert(character.filterIcon.point[4]==4 and character.filterIcon.point[5]==-3)
        assert(#character.filterList==0)
        level.scripts.OnClick();assert(ui.range and level.text==addon.L("FILTER_LEVEL_CURRENT"))
        character.scripts.OnClick();assert(ui.includeUnavailable and character.filterCaption.text==addon.L("FILTER_QUEST_ALL")and not character.filterIcon.shown)
        assert(#character.filterList==0 and character.filterCaption.point[4]==8 and character.filterCaption.width==84)
    end
    addon.db.locale,ui.range,ui.includeUnavailable=locale,range,all;ui:SaveFilters();ui:Refresh()
end)
check("Late native filter captions and glyph visibility preserve the newest mode and locale",function()
    local locale,range,all=addon.db.locale,ui.range,ui.includeUnavailable
    for _,kind in ipairs({"levelCaption","questCaption","portrait","captionPoint","captionWidth"})do
        ui.range=false;ui.includeUnavailable=kind=="captionPoint"or kind=="captionWidth";addon.db.locale="enUS";ui:RefreshFilterControls()
        local object=kind=="levelCaption"and ui.rangeButton or kind=="questCaption"and ui.characterButton.filterCaption or
            kind=="portrait"and ui.characterButton.filterIcon or ui.characterButton.filterCaption
        local method=(kind=="levelCaption"or kind=="questCaption")and "SetText"or kind=="captionPoint"and "SetPoint"or kind=="captionWidth"and "SetWidth"or "SetShown"
        local original,armed=object[method],true
        object[method]=function(self,...)
            if armed then
                armed=false;ui.range=true;ui.includeUnavailable=not(kind=="captionPoint"or kind=="captionWidth");addon.db.locale="koKR";ui:RefreshFilterControls()
            end
            return original(self,...)
        end
        ui:RefreshFilterControls();object[method]=original
        assert(not armed and ui.range and ui.rangeButton.text==addon.L("FILTER_LEVEL_CURRENT"),kind)
        assert(ui.characterButton.filterCaption.text==addon.L(ui.includeUnavailable and "FILTER_QUEST_ALL"or"FILTER_QUEST_MINE"),kind)
        assert(ui.characterButton.filterIcon.shown==not ui.includeUnavailable,kind)
        assert(#ui.characterButton.filterList==0,kind)
        assert(ui.characterButton.filterCaption.point[4]==(ui.includeUnavailable and 8 or 38),kind)
        assert(ui.characterButton.filterCaption.width==(ui.includeUnavailable and 84 or 56),kind)
    end
    addon.db.locale,ui.range,ui.includeUnavailable=locale,range,all;ui:SaveFilters();ui:Refresh()
end)
local function questMarkerFixture()
    local f={quest=ui.quest,dungeon=ui.dungeon,name=addon.QuestName,context=addon.Context,all=ui.includeUnavailable,
        root=ui.questTreeRoot,treeDungeon=ui.questTreeDungeon,history=ui.detailHistory}
    for id=54001,54006 do addon.quests[id]={id=id,name="Marker quest "..id,minLevel=1,requirementsKnown=true}end
    addon.quests[54001].factions={"Alliance"};addon.quests[54001].requires={{ids={54005}}}
    addon.quests[54002].factions={"Horde"};addon.quests[54003].factions={"Alliance","Horde"}
    addon.quests[54004].factions={"Neutral"};addon.quests[54005].factions={"Horde"}
    addon.QuestName=function(id)return addon.quests[id]and addon.quests[id].name or f.name(id)end
    addon.Context=function()return{level=60,faction="Alliance",completed=function()return false end,active=function()return false end}end
    ui.dungeon={key="quest-markers",name="Quest markers",quests={54001,54002,54003,54004,54006}}
    ui.quest,ui.questTreeRoot,ui.questTreeDungeon=nil,nil,nil;ui.detailHistory={};ui.includeUnavailable=true;ui:Refresh()
    function f:row(id)
        for _,row in ipairs(ui.rows)do if row.shown and row.questID==id then return row end end
    end
    function f:anchor()
        for _,row in ipairs(ui.rows)do if row.shown and row.anchorQuestID==54001 then return row end end
    end
    function f:finish()
        for id=54001,54006 do addon.quests[id]=nil end
        addon.QuestName,addon.Context=self.name,self.context
        ui.quest,ui.dungeon,ui.includeUnavailable,ui.detailHistory=self.quest,self.dungeon,self.all,self.history
        ui.questTreeRoot,ui.questTreeDungeon=self.root,self.treeDungeon;ui:Refresh()
    end
    return f
end
check("Separate faction markers follow literal names while chain slots align roots and single-step disclosure controls children",function()
    local f=questMarkerFixture();local root,single=f:row(54001),f:row(54002)
    for _,entry in ipairs({{54001,"Alliance"},{54002,"Horde"}})do
        local row=f:row(entry[1]);assert(row.title.text==addon.quests[entry[1]].name and row.factionReserve==18)
        assert(row.factionIcon.shown and row.factionIcon.width==14 and row.factionIcon.height==14)
        assert(row.factionIcon.atlas=="UI-HUD-UnitFrame-Player-PVP-"..entry[2].."Icon")
        assert(row.factionIcon.point[2]==row.title and row.factionIcon.point[4]==math.min(#row.title.text*5,row.title.width)+4)
        assert(row.title.point[2]+row.title.width+18<=row:GetWidth()-14)
    end
    for _,id in ipairs({54003,54004,54006})do local row=f:row(id);assert(row.factionReserve==0 and(not row.factionIcon or not row.factionIcon.shown))end
    assert(root.chainInset==14 and single.chainInset==14 and root.title.point[2]==single.title.point[2])
    assert(root.chainExpandable and not root.chainExpanded and not single.chainExpandable)
    for _,segment in ipairs(root.chainChevron)do assert(segment.shown and segment.texture=="Interface\\Buttons\\WHITE8X8")end
    for _,segment in ipairs(single.chainChevron or {})do assert(not segment.shown)end
    root.scripts.OnClick();local anchor=f:anchor();local child=f:row(54005)
    assert(anchor.chainExpandable and anchor.chainExpanded and anchor.title.text==addon.quests[54001].name and anchor.chainChevron[1].point[4]==10)
    assert(child.chainInset==0 and not child.chainExpandable and child.factionIcon.shown)
    for _,segment in ipairs(child.chainChevron or {})do assert(not segment.shown)end
    child.scripts.OnClick();assert(ui.quest==54005 and ui.questTreeRoot==54001)
    f:anchor().scripts.OnClick();assert(ui.quest==54001 and ui.questTreeRoot==nil and not f:anchor())
    f:finish()
end)
check("Faction name measurements reject restricted widths and cap long names before reserved reward space",function()
    local f=questMarkerFixture();local row=f:row(54001);local getter=row.title.GetStringWidth
    for _,value in ipairs({-1,0/0,math.huge,"90",777})do
        local checker=issecretvalue;issecretvalue=function(v)return v==777 end
        row.title.GetStringWidth=function()return value end;ui:RefreshQuests()
        assert(row.shown and not row.factionIcon.shown and row.factionReserve==18)
        issecretvalue=checker
    end
    row.title.GetStringWidth=function()return 100000 end;ui:RefreshQuests()
    assert(row.factionIcon.shown and row.factionIcon.point[4]==row.title.width+4)
    row.title.GetStringWidth=function()return 12 end;ui:RefreshQuests()
    assert(row.factionIcon.point[4]==16)
    row.title.GetStringWidth=getter;f:finish()
end)
check("Late faction and chevron writes cannot replace newer row glyph ownership or revive PICK decorations",function()
    for _,mode in ipairs({"factionPoint","atlasRead","chevronPoint"})do
        local f=questMarkerFixture();local row=f:row(54001)
        local object=mode=="chevronPoint"and row.chainChevron[1]or row.factionIcon
        local method=mode=="atlasRead"and "GetAtlas"or "SetPoint";local original,armed=object[method],true
        object[method]=function(self,...)
            if armed then
                armed=false
                if mode=="chevronPoint"then ui.questTreeRoot,ui.questTreeDungeon=54001,ui.dungeon;ui:RefreshQuests()
                else ui.dungeon,ui.quest=nil,nil;ui:RefreshQuests()end
            end
            return original(self,...)
        end
        ui:RefreshQuests();object[method]=original
        assert(not armed,mode)
        if mode=="chevronPoint"then assert(f:anchor()and f:anchor().chainChevron[1].shown and f:anchor().chainChevron[1].point[4]==10)
        else
            assert(row.heading=="PICK"and row.shown and row.title.text==addon.L("PICK")and not row.factionIcon.shown)
            for _,segment in ipairs(row.chainChevron)do assert(not segment.shown)end
        end
        f:finish()
    end
end)
check("Detail title wraps before action slots while body width and scrolling remain independent of the quest heading",function()
    local quest,dungeon,names=ui.quest,ui.dungeon,addon.QuestName
    local seenTitle,seenBody=0,0
    addon.QuestName=function(id)if id==1 then return string.rep("Long localized title ",12)end;return names(id)end
    measurement=function(fs)
        if fs.detailStyle=="title"then seenTitle=fs.width;return 76 end
        if fs.detailStyle=="body"then seenBody=fs.width end
        return fs==ui.heading and 92 or 18
    end
    showDetail(1)
    local title=ui.details[1];local full=ui.detail:GetWidth()-8
    assert(title.shown and title.width==full-40 and seenTitle==full-40)
    assert(seenBody==full and title.point[2]+title.width<=ui.detail:GetWidth()-36)
    assert(-ui.details[2].point[3]>=82,"wrapped title consumes measured height plus its gap")
    assert(ui.giver.parent==ui.detail and ui.source.parent==ui.detail,"native scroll child carries both actions with the title")
    ui.detailScroll:SetVerticalScroll(77);ui:RefreshQuests()
    assert(ui.detailScroll.point[3]==-66 and ui.detailScroll.height==622 and ui.detailScroll.verticalScroll==77)
    assert(ui.questScroll.point[3]==-(66+92+8),"only quest rows follow the long dungeon heading")
    ui.quest=nil;ui:RefreshDetail()
    assert(ui.details[1].detailStyle=="title"and ui.details[1].width==full-40)
    assert(not ui.giver.enabled and not ui.source.enabled)
    measurement=nil;addon.QuestName=names;ui.quest,ui.dungeon=quest,dungeon;ui:Refresh()
end)
check("Empty quest panes avoid unused context planners while direct quest inspection still builds its engine",function()
    local dungeon,quest,context,new=ui.dungeon,ui.quest,addon.Context,addon.Planner.New
    local contexts,planners=0,0
    addon.Context=function(...)contexts=contexts+1;return context(...)end
    addon.Planner.New=function(...)planners=planners+1;return new(...)end
    ui.dungeon,ui.quest=nil,nil;ui:RefreshQuests()
    assert(contexts==0 and planners==0 and ui.engine==nil and ui.currentPlan==nil and ui.rows[1].heading=="PICK")
    ui.quest=1;ui:RefreshQuests();assert(contexts==1 and planners==1 and ui.engine)
    addon.Context,addon.Planner.New=context,new;ui.dungeon,ui.quest=dungeon,quest;ui:Refresh()
end)
check("Catalogue stages every card until complete source validation and retires cross-card mutations",function()
    for _,phase in ipairs({"paint","publish"})do
        local f=targetSearchFixture();local row=ui.cards[1];local armed=true
        local object,method=phase=="paint"and row.title or row,phase=="paint"and "SetText"or "Show"
        local native=object[method]
        object[method]=function(self,...)
            if armed then
                armed=false
                for _,card in ipairs(ui.cards)do assert(not card.shown,"catalogue remains hidden throughout staged paint")end
                addon.dungeons[2].quests[1]=31003
            end
            return native(self,...)
        end
        ui:RefreshDungeons();assert(not armed)
        for _,card in ipairs(ui.cards)do assert(not card.shown,"no partially validated catalogue survives source change")end
        object[method]=native;ui:RefreshDungeons();assert(#f:cards()==3)
        f:finish()
    end
end)
check("A late old catalogue publication cannot hide a newer reentrant render",function()
    local f=targetSearchFixture();local row=ui.cards[1];local native,armed=row.Show,true
    row.Show=function(self,...)
        if armed then armed=false;ui.search="Gamma";ui:RefreshDungeons()end
        return native(self,...)
    end
    ui:RefreshDungeons();assert(not armed)
    local cards=f:cards();assert(#cards==1 and cards[1].title.text=="Gamma dungeon")
    row.Show=native;f:finish()
end)
check("Matched quest inspection siblings remain staged and retire with cross-card invalidation",function()
    local f=targetSearchFixture();ui.search="Source target";ui:RefreshDungeons()
    local row=ui.cards[2];local native,armed=row.title.SetText,true
    row.title.SetText=function(self,...)
        if armed then
            armed=false
            for _,control in ipairs(ui.catalogInspectButtons)do assert(not control.shown,"inspect siblings must remain staged")end
            addon.dungeons[1].quests[1]=31003
        end
        return native(self,...)
    end
    ui:RefreshDungeons();assert(not armed)
    for _,control in ipairs(ui.catalogInspectButtons)do assert(not control.shown,"invalidated search cannot retain visible inspection siblings")end
    row.title.SetText=native;ui:RefreshDungeons()
    assert(ui.catalogInspectButtons[1].shown)
    f:finish()
end)
check("Late inspection publication cannot resurrect old siblings over a newer unmatched search",function()
    local f=targetSearchFixture();ui.search="Source target";ui:RefreshDungeons()
    local inspect=ui.catalogInspectButtons[1];local native,armed=inspect.Show,true
    inspect.Show=function(self,...)
        if armed then armed=false;ui.search="Gamma";ui:RefreshDungeons()end
        return native(self,...)
    end
    ui:RefreshDungeons();assert(not armed)
    assert(#f:cards()==1 and f:cards()[1].title.text=="Gamma dungeon")
    for _,control in ipairs(ui.catalogInspectButtons)do assert(not control.shown)end
    inspect.Show=native;f:finish()
end)
check("Clearing a native EditBox search rebuilds the catalogue only once and expires the pending edit",function()
    local f=targetSearchFixture();ui.search="Source target";ui.searchBox.text=ui.search;ui:RefreshDungeons()
    local refresh,setText=ui.RefreshDungeons,ui.searchBox.SetText
    local calls,selected,quest=0,ui.dungeon,ui.quest
    ui.RefreshDungeons=function(self,...)calls=calls+1;return refresh(self,...)end
    ui.searchBox.SetText=function(self,value)
        local prior=self:GetText();setText(self,value)
        if prior~=value then self.scripts.OnTextChanged(self,false)end
    end
    ui.pendingSearch={frame=ui.frame,query=ui.search,refresh=ui.RefreshDungeons};local pending=ui.pendingSearch
    ui.clearSearch.scripts.OnClick()
    assert(calls==1,"native SetText already renders through OnTextChanged")
    assert(ui.search==""and ui.pendingSearch==nil and #f:cards()==3 and ui.dungeon==selected and ui.quest==quest)
    assert(not ui:FlushPendingSearch(pending)and calls==1)
    ui.RefreshDungeons,ui.searchBox.SetText=refresh,setText;f:finish()
end)
check("Back after filter drift during list refresh keeps the history entry instead of a stale card", function()
    local quest, history, includeUnavailable = ui.quest, ui.detailHistory, ui.includeUnavailable
    local nativeRefresh = ui.RefreshQuests
    ui.detailHistory = {}
    showDetail(1)
    assert(ui:InspectQuest(2, true))
    assert(ui.quest == 2 and #ui.detailHistory == 1 and ui.detailHistory[1] == 1)
    assert(ui:SetDetailTab("sources"))
    ui.detailScroll:SetVerticalScroll(60)
    local drifted = false
    ui.RefreshQuests = function(self, ...)
        local result = nativeRefresh(self, ...)
        if not drifted then
            drifted = true
            self.includeUnavailable = not self.includeUnavailable
        end
        return result
    end
    local restored = ui:BackQuest()
    ui.RefreshQuests = nativeRefresh
    local staleSelection = false
    for _, row in ipairs(ui.rows) do
        if row.shown and row.questTreeSelected and (row.questID or row.anchorQuestID) == 1 then staleSelection = true end
    end
    local kept = ui.quest == 2 and ui.renderedQuest == 2
        and #ui.detailHistory == 1 and ui.detailHistory[1] == 1 and canGoBack()
        and ui.detailTab == "sources" and ui.detailScroll:GetVerticalScroll() == 60
        and ui.includeUnavailable ~= includeUnavailable and not staleSelection
    ui.includeUnavailable = includeUnavailable
    assert(drifted and restored == true and kept,
        "filter drift must not silently spend history while the card still shows the newer quest")
    ui.quest, ui.detailHistory = quest, history
    ui:RefreshDetail()
end)
-- DP-5 dungeon overview pickup steps: isolated projection fixtures, not new catalogue facts.
local function overviewFixture()
    local fixture = {}
    assert(loadfile("Core/Namespace.lua"))("DungeonPro", fixture)
    assert(loadfile("Core/Planner.lua"))("DungeonPro", fixture)
    assert(loadfile("Core/DungeonOverview.lua"))("DungeonPro", fixture)
    return fixture
end
local function overviewInput(fixture, quests, dungeon, ctx, all)
    local engine = fixture.Planner.New(quests, ctx)
    local plan = engine:Dungeon(dungeon, { includeUnavailable = all == true })
    plan.engine, plan.dungeon = engine, dungeon
    return plan, engine
end
local function overviewModel(fixture, plan, dungeon, engine, limit)
    local model, current, raw = fixture.DungeonOverview.Get(plan, dungeon, engine, nil, limit)
    assert(model and type(current) == "function" and type(raw) == "function" and current() and raw())
    return model
end
check("Overview lists pickup steps when no quest is held", function()
    local fixture = overviewFixture()
    local quests = {
        [1] = { id = 1, minLevel = 1, requirementsKnown = true },
        [2] = { id = 2, minLevel = 1, requirementsKnown = true },
    }
    local ctx = { level = 20, current = function() return true end,
        active = function() return false end, ready = function() return false end,
        completed = function() return false end }
    local dungeon = { quests = { 1, 2 }, coverage = "reviewed" }
    local plan, engine = overviewInput(fixture, quests, dungeon, ctx)
    local model = overviewModel(fixture, plan, dungeon, engine)
    assert(model.counts.AVAILABLE == 2 and model.counts.ACTIVE == 0 and model.counts.READY == 0)
    assert(#model.steps == 2 and model.remainingSteps == 0)
    assert(model.steps[1].id == 1 and model.steps[1].kind == "pickup" and model.steps[1].status == "AVAILABLE")
    assert(model.steps[2].id == 2 and model.steps[2].kind == "pickup" and model.steps[2].status == "AVAILABLE")
    assert(model.steps[1].listedTarget and model.steps[2].listedTarget)
end)
check("Overview keeps held steps first and paginates the full pickup list", function()
    local fixture = overviewFixture()
    local quests = {}
    for id = 1, 6 do quests[id] = { id = id, minLevel = 1, requirementsKnown = true } end
    quests[7] = { id = 7, minLevel = 1, requirementsKnown = true }
    quests[8] = { id = 8, minLevel = 1, requirementsKnown = true }
    quests[9] = { id = 9, minLevel = 1, requirementsKnown = true, startsInside = true }
    quests[10] = { id = 10, minLevel = 100, requirementsKnown = true }
    local ctx = { level = 60, current = function() return true end,
        active = function(id) return id == 7 or id == 8 end,
        ready = function(id) return id == 8 end,
        completed = function() return false end }
    local dungeon = { quests = { 1, 2, 3, 4, 5, 6, 9, 10, 7, 8 }, coverage = "reviewed" }
    local plan, engine = overviewInput(fixture, quests, dungeon, ctx)
    local model = overviewModel(fixture, plan, dungeon, engine)
    assert(model.counts.READY == 1 and model.counts.ACTIVE == 1)
    assert(model.counts.AVAILABLE == 7 and model.counts.LOCKED == 1)
    assert(#model.steps == 6 and model.remainingSteps == 4)
    local expected = { 8, 7, 1, 2, 3, 4 }
    local kinds = { "turnin", "complete", "pickup", "pickup", "pickup", "pickup" }
    for index, id in ipairs(expected) do
        assert(model.steps[index].id == id and model.steps[index].kind == kinds[index])
    end
    assert(model.steps[1].status == "READY" and model.steps[2].status == "ACTIVE")
    local expanded = overviewModel(fixture, plan, dungeon, engine, 12)
    assert(#expanded.steps == 10 and expanded.remainingSteps == 0)
    local full = { 8, 7, 1, 2, 3, 4, 5, 6, 9, 10 }
    for index, id in ipairs(full) do assert(expanded.steps[index].id == id) end
    assert(expanded.steps[9].kind == "inside" and expanded.steps[10].kind == "level")
end)
check("Overview keeps Mine/All steps stable and never invents UNKNOWN pickups", function()
    local fixture = overviewFixture()
    local quests = {
        [1] = { id = 1, minLevel = 1, requirementsKnown = true },
        [2] = { id = 2, minLevel = 1, requirementsKnown = true },
        [7] = { id = 7, minLevel = 1, requirementsKnown = true },
        [11] = { id = 11, minLevel = 1, requirementsKnown = true, factions = { "Horde" } },
        [12] = { id = 12, minLevel = 1, requirementsKnown = false },
    }
    local ctx = { level = 60, faction = "Alliance", current = function() return true end,
        active = function(id) return id == 7 end, ready = function() return false end,
        completed = function() return false end }
    local dungeon = { quests = { 1, 2, 7, 11, 12 }, coverage = "reviewed" }
    local minePlan, mineEngine = overviewInput(fixture, quests, dungeon, ctx, false)
    local allPlan, allEngine = overviewInput(fixture, quests, dungeon, ctx, true)
    local mine = overviewModel(fixture, minePlan, dungeon, mineEngine)
    local all = overviewModel(fixture, allPlan, dungeon, allEngine)
    assert(mine.counts.UNAVAILABLE == 0 and all.counts.UNAVAILABLE == 1)
    assert(mine.shownRoots == 4 and all.shownRoots == 5)
    assert(#mine.steps == 3 and #all.steps == 3)
    for _, model in ipairs({ mine, all }) do
        assert(model.steps[1].id == 7 and model.steps[1].kind == "complete")
        assert(model.steps[2].id == 1 and model.steps[3].id == 2)
        for _, step in ipairs(model.steps) do assert(step.id ~= 11 and step.id ~= 12) end
    end
    assert(mine.unknown and all.unknown)
end)
check("DP-3 G1 narrative fallback retires stale dialogue and story text on one pool", function()
    local oldDescription, oldDialogue = addon.Description, addon.DialogueText
    local old166, old4903 = addon.quests[166], addon.quests[4903]
    local prose = "Covered G1 prose."
    local dialogue = "Covered G1 dialogue."
    addon.quests[166] = { id = 166, minLevel = 1, requirementsKnown = true,
        start = { mapID = 1, x = 10, y = 20, name = "Covered giver" } }
    addon.quests[4903] = { id = 4903, minLevel = 1, requirementsKnown = false,
        start = { itemID = 12563, name = "Uncovered starter" } }
    addon.Description = function(id) if id == 166 then return prose end end
    addon.DialogueText = function(id)
        if id == 166 then return { source = "dialogue", stage = "progress", text = dialogue, current = function() return true end } end
    end
    local pool = ui.details
    local function countVisible(value)
        local found = 0
        for _, fs in ipairs(pool) do if fs.shown and audienceText(fs.text) == value then found = found + 1 end end
        return found
    end
    local function countContaining(value)
        local found = 0
        for _, fs in ipairs(pool) do if fs.shown and audienceText(fs.text):find(value, 1, true) then found = found + 1 end end
        return found
    end
    showDetail(166)
    assert(detailHas(dialogue), "covered Quest keeps its dialogue row")
    assert(ui.details == pool, "detail pool is reused across cards")
    showDetail(4903)
    assert(countContaining(dialogue) == 0, "uncovered Quest keeps zero covered dialogue rows")
    assert(countVisible(addon.L("DIALOGUE_PROGRESS_TEXT")) == 0 and countVisible(addon.L("DIALOGUE_TURNIN_TEXT")) == 0, "uncovered Quest keeps zero dialogue headings")
    assert(countVisible(addon.L("DETAIL_STORY_UNAVAILABLE")) == 0, "story fallback never leaks onto Quest")
    assert(countVisible(addon.L("NO_TEXT")) == 0 and countContaining(addon.L("NO_TEXT")) == 0, "raw NO_TEXT never renders on Quest")
    showStory(4903)
    assert(countVisible(addon.L("DETAIL_STORY_UNAVAILABLE")) == 1, "uncovered Story shows exactly one honest fallback row")
    assert(countContaining(prose) == 0, "covered prose never leaks onto uncovered Story")
    assert(countVisible(addon.L("NO_TEXT")) == 0 and countContaining(addon.L("NO_TEXT")) == 0, "raw NO_TEXT never renders on Story")
    showDetail(166)
    assert(detailHas(dialogue), "returning to the covered Quest restores its dialogue row")
    showStory(166)
    assert(detailHas(prose), "returning to the covered Story restores its prose row")
    assert(countVisible(addon.L("DETAIL_STORY_UNAVAILABLE")) == 0, "covered Story shows no fallback row")
    addon.Description, addon.DialogueText = oldDescription, oldDialogue
    addon.quests[166], addon.quests[4903] = old166, old4903
    showDetail(2)
end)
check("DP-3 G2 portrait caption retires with its texture without native and source doubles", function()
    local oldPortrait, oldDialoguePortrait, oldTurnInPortrait = addon.QuestPortrait, addon.DialoguePortrait, addon.DialogueTurnInPortrait
    local oldGiverPortrait = addon.GiverPortrait
    local oldRenderer = SetPortraitTextureFromCreatureDisplayID
    local old166, old4764 = addon.quests[166], addon.quests[4764]
    addon.quests[166] = { id = 166, minLevel = 1, requirementsKnown = true,
        start = { npcID = 234, name = "Portrait giver", mapID = 1, x = 10, y = 20,
            creatureDisplayID = 1690, portraitSource = "g2source" } }
    addon.quests[4764] = { id = 4764, minLevel = 1, requirementsKnown = false,
        start = { mapID = 1, x = 12, y = 22, name = "Plain giver" } }
    addon.QuestPortrait = function(id) if id == 166 then return { displayID = 1111 } end end
    addon.DialoguePortrait, addon.DialogueTurnInPortrait = nil, nil
    addon.GiverPortrait = function(point)
        if point and point.npcID == 234 then return { npcID = 234, displayID = 1690, source = "g2source", name = "Portrait giver" } end
    end
    SetPortraitTextureFromCreatureDisplayID = function(texture) texture:SetTexture("G2 portrait") end
    local pool = ui.details
    local function countVisible(value)
        local found = 0
        for _, fs in ipairs(pool) do if fs.shown and audienceText(fs.text) == value then found = found + 1 end end
        return found
    end
    showDetail(166)
    assert(ui.portrait.shown and ui.portrait.texture == "G2 portrait", "covered portrait paints its texture")
    assert(countVisible(addon.L("QUEST_PORTRAIT")) == 1, "covered portrait keeps exactly one native caption row")
    local captionRow
    for _, fs in ipairs(pool) do if fs.shown and audienceText(fs.text) == addon.L("QUEST_PORTRAIT") then captionRow = fs end end
    assert(captionRow, "caption row is a pooled detail row")
    showDetail(4764)
    assert(not ui.portrait.shown and ui.portrait.texture == nil, "uncovered card retires the texture")
    assert(countVisible(addon.L("QUEST_PORTRAIT")) == 0, "caption row retires together with its texture")
    assert(not captionRow.shown or audienceText(captionRow.text) ~= addon.L("QUEST_PORTRAIT"), "pooled caption row no longer shows the retired caption")
    showDetail(166)
    assert(ui.portrait.shown and countVisible(addon.L("QUEST_PORTRAIT")) == 1, "returning restores one native caption row")
    showSources(166)
    local sourceCaption = addon.L("GIVER_REFERENCE_PORTRAIT", "Portrait giver")
    assert(ui.giverPortrait.shown, "source portrait paints its texture on Sources")
    assert(countVisible(sourceCaption) == 1, "source portrait keeps exactly one caption row")
    assert(countVisible(addon.L("QUEST_PORTRAIT")) == 0, "native caption never doubles a source caption")
    local sourceCaptionRow
    for _, fs in ipairs(pool) do if fs.shown and audienceText(fs.text) == sourceCaption then sourceCaptionRow = fs end end
    assert(sourceCaptionRow, "source caption row is a pooled detail row")
    showSources(4764)
    assert(not ui.giverPortrait.shown and ui.giverPortrait.texture == nil, "source texture retires cross-quest")
    assert(countVisible(sourceCaption) == 0, "source caption row retires together with its texture")
    assert(not sourceCaptionRow.shown or audienceText(sourceCaptionRow.text) ~= sourceCaption, "pooled source row no longer shows the retired caption")
    showSources(166)
    assert(ui.giverPortrait.shown and countVisible(sourceCaption) == 1, "returning restores one source caption row")
    assert(countVisible(addon.L("QUEST_PORTRAIT")) == 0, "native and source captions never double on one card")
    addon.DialoguePortrait = function(id) if id == 166 then return { hidden = true } end end
    showDetail(166)
    assert(not ui.portrait.shown and countVisible(addon.L("QUEST_PORTRAIT")) == 0, "explicit hidden suppresses the selected-log fallback portrait")
    addon.QuestPortrait, addon.DialoguePortrait, addon.DialogueTurnInPortrait = oldPortrait, oldDialoguePortrait, oldTurnInPortrait
    addon.GiverPortrait = oldGiverPortrait
    SetPortraitTextureFromCreatureDisplayID = oldRenderer
    addon.quests[166], addon.quests[4764] = old166, old4764
    showDetail(2)
end)
check("DP-3 G3 fully unknown starter keeps one honest acquisition row without doubles", function()
    local old1100, old6522, old98423, old4764 = addon.quests[1100], addon.quests[6522], addon.quests[98423], addon.quests[4764]
    local oldItemName, oldCarried = addon.ItemName, addon.CarriedItemCount
    addon.quests[98423] = { id = 98423, minLevel = 1, requirementsKnown = false,
        start = { itemID = 281030, name = "Unknown treaty" } }
    addon.quests[1100] = { id = 1100, minLevel = 1, requirementsKnown = false,
        start = { itemID = 5791, name = "Journal starter",
            containerSource = { objectID = 19861, name = "Journal container", zoneName = "Container zone", mapID = 1, x = 30, y = 24 } } }
    addon.quests[6522] = { id = 6522, minLevel = 1, requirementsKnown = false,
        start = { itemID = 17008, name = "Scroll starter",
            dropSources = { { npcID = 4421, name = "Single dropper", locationName = "Single zone", mapID = 1, x = 10, y = 20 } } } }
    addon.quests[4764] = { id = 4764, minLevel = 1, requirementsKnown = false,
        start = { mapID = 1, x = 10, y = 20, name = "Objective giver" },
        objectiveItems = { { itemID = 12352, name = "Unknown clasp" } } }
    addon.ItemName, addon.CarriedItemCount = nil, nil
    local function countVisible(value)
        local found = 0
        for _, fs in ipairs(ui.details) do if fs.shown and audienceText(fs.text) == value then found = found + 1 end end
        return found
    end
    for _, view in ipairs({ showDetail, showSources }) do
        view(98423)
        assert(countVisible(addon.L("START_ITEM_LOCATION_UNKNOWN")) == 1, "fully unknown starter shows exactly one honest row")
        assert(countVisible(addon.L("ITEM_ACQUISITION")) == 0, "no acquisition heading without routes")
    end
    showSources(6522)
    local dropText = addon.L("ITEM_DROP_SOURCE", "Single dropper", "Single zone")
    local textRows = 0
    for _, fs in ipairs(ui.details) do if fs.shown and audienceText(fs.text) == dropText then textRows = textRows + 1 end end
    local dropButtons = 0
    for _, row in ipairs(ui.dropButtons) do if row.shown then dropButtons = dropButtons + 1 end end
    assert(textRows + dropButtons == 1, "one mapped drop keeps exactly one honest row, not text plus button")
    for _, row in ipairs(ui.dropButtons) do
        if row.shown then assert(not row.note.text:find("%(0%.0, 0%.0%)", 1, true), "no coordinates from thin air") end
    end
    showSources(1100)
    assert(ui.containerButtons[1].shown, "container source paints its button")
    showSources(98423)
    assert(not ui.containerButtons[1].shown and not ui.containerButtons[1].scripts.OnClick, "cross-quest container rows retire")
    for _, row in ipairs(ui.dropButtons) do assert(not row.shown, "cross-quest drop rows retire") end
    assert(countVisible(addon.L("START_ITEM_LOCATION_UNKNOWN")) == 1, "unknown card still shows exactly one row after container retirement")
    showDetail(4764)
    assert(detailHas(unknownObjective("Unknown clasp")), "unknown quantity stays unknown and never becomes one")
    assert(not detailHas(addon.L("OBJECTIVE_ITEM", "Unknown clasp", 1)), "unknown quantity never renders as carried one")
    addon.ItemName = function(id) if id == 12352 then return "Unknown clasp" end end
    addon.CarriedItemCount = function(id) if id == 12352 then return 2 end end
    ui:RefreshDetail()
    assert(detailHas(unknownObjective("Unknown clasp") .. " · " .. addon.L("ITEM_CARRIED", 2)), "carried count stays a separate honest component")
    addon.quests[1100], addon.quests[6522], addon.quests[98423], addon.quests[4764] = old1100, old6522, old98423, old4764
    addon.ItemName, addon.CarriedItemCount = oldItemName, oldCarried
    showDetail(2)
end)
check("Overview keeps held log steps and next actions under separate headers", function()
    if not addon.DungeonOverview then assert(loadfile("Core/DungeonOverview.lua"))("DungeonPro", addon) end
    local provider = assert(addon.DungeonOverview)
    local originalGet = provider.Get
    local savedDungeon, savedQuest = ui.dungeon, ui.quest
    ui.dungeon, ui.quest = addon.dungeons[1], nil
    ui:Refresh()
    local function stub(steps)
        provider.Get = function()
            return { counts = { READY = 0, ACTIVE = 1, COMPLETED = 0, UNKNOWN = 0, LOCKED = 0, AVAILABLE = 1, UNAVAILABLE = 0 },
                shownRoots = 2, unknown = false, knownPrepared = false, steps = steps, remainingSteps = 0 },
                function() return true end, function() return true end
        end
    end
    local function shownHeaders()
        local seen = {}
        for _, fs in ipairs(ui.overviewTexts or {}) do
            if fs.shown then seen[#seen + 1] = fs.text end
        end
        return seen
    end
    local function position(list, value)
        for index, text in ipairs(list) do if text == value then return index end end
    end
    local held = { id = 6, kind = "complete", status = "ACTIVE", listedTarget = true }
    local nextAction = { id = 2, kind = "pickup", status = "AVAILABLE", listedTarget = true }
    stub({ held, nextAction }); ui:RefreshDetail()
    local seen = shownHeaders()
    local heldAt, nextAt = position(seen, addon.L("OVERVIEW_KNOWN_STEPS")), position(seen, addon.L("OVERVIEW_NEXT_STEPS"))
    assert(addon.L("OVERVIEW_NEXT_STEPS") ~= "OVERVIEW_NEXT_STEPS", "next actions need their own translated header")
    assert(heldAt and nextAt and heldAt < nextAt, "held log steps keep their header before next actions")
    stub({ nextAction }); ui:RefreshDetail()
    seen = shownHeaders()
    assert(position(seen, addon.L("OVERVIEW_NEXT_STEPS")) and not position(seen, addon.L("OVERVIEW_KNOWN_STEPS")) and
        not position(seen, addon.L("OVERVIEW_NO_KNOWN_STEPS")),
        "pickup-only overviews keep NEXT without the empty hint")
    stub({}); ui:RefreshDetail()
    seen = shownHeaders()
    local emptyHint = addon.L("OVERVIEW_NO_KNOWN_STEPS")
    local emptyCount = 0
    for _, text in ipairs(seen) do if text == emptyHint then emptyCount = emptyCount + 1 end end
    assert(emptyCount == 1 and not position(seen, addon.L("OVERVIEW_KNOWN_STEPS")) and
        not position(seen, addon.L("OVERVIEW_NEXT_STEPS")), "the empty hint appears exactly once only when both groups are empty")
    local foldedEmpty = emptyHint:lower()
    assert(not foldedEmpty:find("questlog", 1, true) and not foldedEmpty:find("quest-log", 1, true)
        and not foldedEmpty:find("quest log", 1, true) and not foldedEmpty:find("journal", 1, true)
        and not emptyHint:find("журнал", 1, true) and not emptyHint:find("Questlog", 1, true)
        and not emptyHint:find("%d") and not emptyHint:find("%%", 1, true),
        "empty means no held and no next, so the hint stays neutral with no counters: " .. emptyHint)
    local savedLocale = addon.db.locale
    for _, locale in ipairs({ "enUS", "ruRU" }) do
        addon.db.locale = locale
        local hint = addon.L("OVERVIEW_NO_KNOWN_STEPS")
        local folded = hint:lower()
        assert(not folded:find("questlog", 1, true) and not folded:find("quest-log", 1, true)
            and not folded:find("quest log", 1, true) and not folded:find("journal", 1, true)
            and not hint:find("журнал", 1, true) and not hint:find("%%", 1, true),
            locale .. " empty hint covers missing held and next steps, not just the quest log: " .. hint)
    end
    addon.db.locale = savedLocale
    provider.Get = originalGet
    ui.dungeon, ui.quest = savedDungeon, savedQuest
    ui:Refresh()
end)
check("Overview hidden-tail copy stays neutral across held and pickup steps", function()
    if not addon.DungeonOverview then assert(loadfile("Core/DungeonOverview.lua"))("DungeonPro", addon) end
    local provider = assert(addon.DungeonOverview)
    local originalGet = provider.Get
    local savedDungeon, savedQuest, savedLocale = ui.dungeon, ui.quest, addon.db.locale
    ui.dungeon, ui.quest = addon.dungeons[1], nil
    ui:Refresh()
    local held = { id = 6, kind = "complete", status = "ACTIVE", listedTarget = true }
    local nextAction = { id = 2, kind = "pickup", status = "AVAILABLE", listedTarget = true }
    provider.Get = function()
        return { counts = { READY = 0, ACTIVE = 1, COMPLETED = 0, UNKNOWN = 0, LOCKED = 0, AVAILABLE = 1, UNAVAILABLE = 0 },
            shownRoots = 2, unknown = false, knownPrepared = false, steps = { held, nextAction }, remainingSteps = 3 },
            function() return true end, function() return true end
    end
    for _, locale in ipairs({ "enUS", "ruRU" }) do
        addon.db.locale = locale
        ui:RefreshDetail()
        local expected = addon.L("OVERVIEW_MORE_STEPS", 3)
        assert(expected:find("3", 1, true), locale .. " hidden-tail line must keep the %d count")
        local folded = expected:lower()
        assert(not folded:find("questlog", 1, true) and not folded:find("quest-log", 1, true)
            and not folded:find("quest log", 1, true) and not folded:find("journal", 1, true)
            and not expected:find("журнал", 1, true), locale .. " hidden tail covers pickup steps, not just the quest log: " .. expected)
        local shown = false
        for _, fs in ipairs(ui.overviewTexts or {}) do
            if fs.shown and fs.text == expected then shown = true end
        end
        assert(shown, locale .. " paginated overview must render the neutral hidden-tail line")
    end
    provider.Get = originalGet
    addon.db.locale = savedLocale
    ui.dungeon, ui.quest = savedDungeon, savedQuest
    ui:Refresh()
end)
print("Preparation UI modeled checks passed: " .. total .. " (no native layout validation)")
