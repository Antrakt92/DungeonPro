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
function methods:SetText(value) self.text = value end
function methods:SetTexture(value) self.texture = value; return true end
function methods:GetText() return self.text or "" end
function methods:SetEnabled(value) self.enabled = value end
function methods:GetStringHeight() if measurement then return measurement(self) end; return 18 end
function methods:SetScale(value) self.scale = value end
function methods:SetVerticalScroll(value) self.verticalScroll = value; self.scrollWrites = (self.scrollWrites or 0) + 1 end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:SetClampedToScreen(value) self.clamped = value end
function methods:IsShown() return self.shown end
function methods:Hide() self.shown = false end
function methods:Show() self.shown = true end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
for _, name in ipairs({ "SetFont", "SetJustifyH", "SetTextColor", "SetAllPoints", "SetColorTexture",
    "SetHighlightTexture", "SetFrameStrata", "EnableMouse", "SetMovable", "RegisterForDrag",
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
local addon, done = {}, { [7] = true }
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
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
assert(loadfile("UI/Window.lua"))("DungeonPro", addon)
local ui, total = addon.UI, 0
local function check(name, fn)
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err))
    total = total + 1; print("PASS " .. name)
end
local function visibleRows()
    local result = {}
    for _, row in ipairs(ui.rows) do if row.shown and not row.heading then result[#result + 1] = row end end
    return result
end
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
    assert(ui.characterButton.text == addon.L("MY_CHARACTER"))
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
    ui.preparationButton.scripts.OnClick()
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
    ui:Refresh()
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
    visibleRows()[2].scripts.OnClick()
    assert(ui.quest == 2 and ui.action.id == 2 and ui.action.place.x == 12 and ui.guide.enabled)
end)
check("Unknown quests remain visible without an invented action", function()
    local row = visibleRows()[6]
    assert(row.title.text == "Quest 3" and row.note.text:find(addon.L("UNKNOWN_REQUIREMENTS"), 1, true))
    row.scripts.OnClick()
    assert(ui.quest == 3 and not ui.action and not ui.map.enabled and not ui.guide.enabled)
end)
check("Quest progress removes a shared prerequisite from preparation", function()
    done[1] = true; ui:Refresh()
    assert(#visibleRows() == 6 and visibleRows()[1].title.text == "Quest 2")
    local unlocked = false
    for _, row in ipairs(visibleRows()) do
        assert(row.title.text ~= "Quest 1")
        if row.title.text == "Quest 101" then unlocked = true end
    end
    assert(unlocked)
end)
check("Returning to target view clears recycled preparation labels", function()
    ui.preparationButton.scripts.OnClick()
    assert(#visibleRows() == 7)
    assert(visibleRows()[1].title.text == "Quest 100")
    assert(visibleRows()[1].note.text:find("Preparation needed", 1, true))
    for _, row in ipairs(visibleRows()) do assert(not row.heading and row.enabled and row.scripts.OnClick) end
end)
check("Inside classification uses quest metadata instead of quest names", function()
    local original = addon.QuestName
    addon.QuestName = function() return "An outside-sounding name" end
    ui.preparationButton.scripts.OnClick()
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
    ui.preparationButton.scripts.OnClick()
end)
check("Locked target with an unavailable prerequisite stays visible", function()
    local oldContext = addon.Context
    addon.Context = function() local c = oldContext(); c.faction = "Alliance"; return c end
    addon.quests[200] = { id = 200, minLevel = 1, requirementsKnown = true, requires = { { ids = { 201 } } } }
    addon.quests[201] = { id = 201, minLevel = 1, requirementsKnown = true, factions = { "Horde" } }
    local ids = ui.dungeon.quests
    ids[#ids + 1] = 200
    ui.preparation = true; ui:Refresh()
    local found = false
    for _, row in ipairs(visibleRows()) do
        if row.title.text == "Quest 200" then found = true; row.scripts.OnClick() end
    end
    assert(found and ui.quest == 200 and not ui.action and not ui.guide.enabled)
    ids[#ids] = nil; addon.quests[200], addon.quests[201] = nil, nil
    addon.Context = oldContext; ui.preparation = false; ui.quest = nil; ui:Refresh()
end)
local function detailHas(value)
    for _, fs in ipairs(ui.details) do if fs.shown and fs.text == value then return true end end
    return false
end
local function showDetail(id, context)
    ui.quest = id; ui.engine = addon.Planner.New(addon.quests, context or addon.Context()); ui:RefreshDetail()
end
check("Unknown quests allow an explicit location visit without claiming availability", function()
    local started, mapped = {}, {}
    addon.Navigation = { Start = function(action) started[#started + 1] = action end,
        Map = function(place) mapped[#mapped + 1] = place end }
    showDetail(3)
    assert(ui.engine:State(3).status == "UNKNOWN" and not ui.action and not ui.guide.enabled)
    assert(ui.giver.enabled and detailHas(addon.L("LOCATION_ONLY")) and #started == 0 and #mapped == 0)
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
    assert(prerequisite.id == 2 and ui.giverAction.id == 100 and detailHas(addon.L("LOCATION_ONLY")))
    ui.giver.scripts.OnClick()
    assert(started[1].id == 100 and started[1].kind == "visit" and ui.action == prerequisite)
    ui.guide.scripts.OnClick()
    assert(started[2] == prerequisite and started[2].id == 2)
    addon.quests[100].start = originalStart
end)
check("Map-only quest givers open their known zone and missing givers disable visits", function()
    local originalStart, mapped, started = addon.quests[2].start, {}, 0
    addon.Navigation = { Map = function(place) mapped[#mapped + 1] = place end,
        Start = function() started = started + 1 end }
    addon.quests[2].start = { mapID = 1436, name = "Known zone only" }
    showDetail(2)
    assert(ui.giver.enabled and ui.giver.text == addon.L("GIVER_MAP"))
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
    assert(not detailHas(addon.L("REASON_requirements")) and not ui.action and not ui.guide.enabled)
end)
check("Level reason shows required and current levels without inventing a missing level", function()
    showDetail(5)
    assert(detailHas(addon.L("REASON_level_current", 30, 20)))
    local context = addon.Context(); context.level = nil
    showDetail(5, context)
    assert(ui.engine:State(5).status == "UNKNOWN")
    assert(detailHas(addon.L("REASON_level", 30)) and detailHas(addon.L("REASON_levelUnknown")))
    assert(not detailHas(addon.L("REASON_level_current", 30, 20)) and not ui.action)
end)
check("Missing catalogue records display an honest reason instead of a selection prompt", function()
    showDetail(999)
    assert(detailHas(addon.L("REASON_missing")) and not ui.action and not ui.guide.enabled)
end)
check("Character history and each restriction have specific detail reasons", function()
    local context = addon.Context()
    context.completed = function() return nil end
    showDetail(2, context)
    assert(detailHas(addon.L("REASON_character")) and not ui.action)
    for _, rule in ipairs({ { "factions", "faction", "Horde", "Alliance" },
        { "classes", "class", "WARRIOR", "MAGE" }, { "races", "race", 1, 3 } }) do
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
    assert(ui.characterButton.text == addon.L("ALL_CHARACTERS") and #visibleRows() == 8)
    local function selectRestricted()
        for _, row in ipairs(visibleRows()) do
            if row.title.text == "Quest 300" then
                row.scripts.OnClick()
                assert(detailHas(addon.L("REASON_faction")) and not ui.action and not ui.guide.enabled)
                return true
            end
        end
        return false
    end
    assert(selectRestricted())
    ui.preparationButton.scripts.OnClick()
    local heading
    for _, row in ipairs(ui.rows) do
        if row.shown and row.heading == "PREP_unavailable" then heading = row end
    end
    assert(heading and not heading.enabled and not heading.scripts.OnClick and selectRestricted())
    ui:LoadFilters()
    assert(ui.includeUnavailable and ui.preparation and addon.char.filters == filters and filters.other == "preserve")
    ui.characterButton.scripts.OnClick()
    for _, row in ipairs(visibleRows()) do assert(row.title.text ~= "Quest 300") end
    ui.preparationButton.scripts.OnClick()
    for _, row in ipairs(visibleRows()) do assert(row.enabled and not row.heading and row.scripts.OnClick) end
    ids[#ids] = nil; addon.quests[300] = nil
    addon.Context = originalContext; ui.quest = nil; ui:Refresh()
end)
check("Level and preparation toggles persist without replacing unrelated filters", function()
    local filters = addon.char.filters
    ui.rangeButton.scripts.OnClick()
    assert(filters.range == true)
    ui.range = false; ui:LoadFilters(); assert(ui.range)
    ui.rangeButton.scripts.OnClick()
    assert(filters.range == false and filters.preparation == false and filters.includeUnavailable == false)
    assert(addon.char.filters == filters and filters.other == "preserve")
end)
check("Filtered-out quests are distinguished from missing dungeon data", function()
    local originalContext, originalDungeon = addon.Context, ui.dungeon
    addon.Context = function() local c = originalContext(); c.faction = "Alliance"; return c end
    addon.quests[301] = { id = 301, minLevel = 1, requirementsKnown = true, factions = { "Horde" } }
    ui.dungeon = { name = "Faction fixture", coverage = "reviewed", quests = { 301 } }
    ui:Refresh()
    assert(#visibleRows() == 0 and ui.coverage.text == addon.L("NO_CHARACTER_QUESTS"))
    ui.characterButton.scripts.OnClick()
    assert(#visibleRows() == 1 and visibleRows()[1].title.text == "Quest 301")
    assert(ui.coverage.text ~= addon.L("NO_CHARACTER_QUESTS") and ui.coverage.text ~= addon.L("EMPTY"))
    ui.characterButton.scripts.OnClick()
    ui.dungeon.quests = {}; ui:Refresh()
    assert(#visibleRows() == 0 and ui.coverage.text == addon.L("EMPTY"))
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
    assert(first.height >= 108 and -first.note.point[3] >= 7 + 72)
    assert(-visibleRows()[2].point[3] >= first.height + 4)
    assert(ui.cards[1].height >= 108 and ui.catalog.height >= ui.cards[1].height)
    ui.preparation = true; ui:Refresh()
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
    showDetail(100)
    assert(ui.chainButtons[1].height == 78)
    assert(ui.chainButtons[1].point[3] - ui.chainButtons[2].point[3] >= 81)
    addon.QuestName, addon.DungeonName, addon.quests[2].start.name = questName, dungeonName, giver
    measurement = nil; ui.preparation = false; ui:Refresh(); showDetail(100)
    assert(visibleRows()[1] == first and first.height == 59 and ui.cards[1].height == 64)
    assert(first.note.point[3] == -29 and ui.chainButtons[1].height == 34)
end)
check("Invalid and restricted text measurements reuse clean geometry safely", function()
    ui.preparation = false; ui:Refresh(); showDetail(100)
    local height, chainHeight = visibleRows()[1].height, ui.chainButtons[1].height
    for _, value in ipairs({ math.huge, -1, 0 / 0, 777 }) do
        measurement = function() return value end
        issecretvalue = function(v) return type(v) == "number" and v == 777 end
        ui:Refresh(); showDetail(100)
        assert(visibleRows()[1].height == height and ui.chainButtons[1].height == chainHeight)
        assert(ui.questList.height < math.huge and ui.detail.height < math.huge)
    end
    measurement = function() error("height unavailable") end
    ui:Refresh(); showDetail(100)
    assert(visibleRows()[1].height == height and ui.chainButtons[1].height == chainHeight)
    measurement, issecretvalue = nil, nil
end)
check("OR alternatives support explicit persisted choices, automatic reset and safe stale fallback", function()
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
    ui.preparation, ui.quest = false, 400; ui:Refresh()
    local function option(parent)
        for _, b in ipairs(ui.branchButtons) do
            if b.shown and b.questID == 400 and b.groupIndex == 1 and b.parentID == parent then return b end
        end
        error("Missing branch option")
    end
    assert(ui.action.id == 401 and option(nil).label.text == addon.L("BRANCH_SELECTED", addon.L("BRANCH_AUTO")))
    assert(not option(403).enabled and not option(403).scripts.OnClick)
    assert(not ui:ChooseBranch(400, 1, 403) and not ui:ChooseBranch(400, 1, 999))
    assert(not ui:ChooseBranch(math.huge, 1, 401) and choices[400][1] == nil)
    option(402).scripts.OnClick()
    assert(ui.action.id == 402 and choices[400][1] == 402)
    assert(addon.char.choices == choices and choices[999].retain and choices[400][2] == 777)
    ui:Refresh(); assert(ui.action.id == 402)
    option(404).scripts.OnClick()
    assert(choices[400][1] == 404 and not ui.action and not ui.guide.enabled)
    option(nil).scripts.OnClick()
    assert(choices[400][1] == nil and ui.action.id == 401)
    option(402).scripts.OnClick()
    addon.quests[400].requires[1].ids = { 401, 403, 404 }
    ui:Refresh()
    assert(ui.action.id == 401 and choices[400][1] == 402)
    assert(option(nil).label.text == addon.L("BRANCH_SELECTED", addon.L("BRANCH_AUTO")))
    ui.quest = 2; ui:RefreshDetail()
    for _, b in ipairs(ui.branchButtons) do assert(not b.shown) end
    for _, id in ipairs({ 400, 401, 402, 403, 404 }) do addon.quests[id] = nil end
    addon.Context, addon.char.choices, ui.dungeon = originalContext, originalChoices, originalDungeon
    ui.quest = nil; ui:Refresh()
end)
check("Completed preparation keeps the prepared result instead of empty data warning", function()
    local context = addon.Context
    addon.Context = function()
        local value = context()
        value.active = function() return false end
        return value
    end
    for id in pairs(addon.quests) do done[id] = true end
    ui.preparationButton.scripts.OnClick()
    assert(#visibleRows() == 0 and ui.coverage.text == addon.L("PREPARED"))
    for _, row in ipairs(ui.rows) do assert(not row.shown) end
    addon.Context = context
end)
check("Completion history cannot hide the current held quest from preparation progress", function()
    assert(done[6] == true)
    ui:Refresh()
    assert(ui.engine:State(6).status == "ACTIVE" and ui.engine:State(6).completedHistory == true)
    local rows = visibleRows()
    assert(#rows == 1 and rows[1].title.text == "Quest 6")
    assert(rows[1].note.text:find(addon.L("complete"), 1, true))
    assert(ui.coverage.text == addon.L("PREPARED"), "held repeat work does not revoke preparation")
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
    ui.quest = 2; ui:RefreshDetail()
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
    assert(detailHas(addon.L("REWARD_ITEMS")) and detailHas(addon.L("REWARD_CHOICES")))
    assert(detailHas(addon.L("REWARD_ITEM", "Reward token", 3)))
    assert(detailHas(addon.L("REWARD_ITEM", "Choice blade", 1)) and detailHas(addon.L("REWARD_ITEM", "Choice robe", 2)))
    assert(not detailHas(addon.L("REWARD_NO_ITEMS")) and not detailHas(addon.L("REWARD_UNAVAILABLE")))
    assert(detailHas(addon.L("REWARD_MONEY") .. ": Native coin texture") and moneyCalls == 1)
end)
check("Known zero item rewards differ from unavailable reward data", function()
    local moneyCalls = 0
    GetCoinTextureString = function() moneyCalls = moneyCalls + 1; error("zero must not be formatted") end
    addon.QuestRewards = function() return { items = {}, choices = {}, money = 0 } end
    showDetail(2)
    assert(detailHas(addon.L("REWARD_NO_ITEMS")) and not detailHas(addon.L("REWARD_UNAVAILABLE")))
    assert(not detailHas(addon.L("REWARD_ITEMS")) and not detailHas(addon.L("REWARD_CHOICES")))
    assert(not detailHas(addon.L("REWARD_MONEY_UNKNOWN")) and moneyCalls == 0)
    addon.QuestRewards = function() return nil end
    showDetail(2)
    assert(detailHas(addon.L("REWARD_UNAVAILABLE")) and not detailHas(addon.L("REWARD_NO_ITEMS")))
    addon.QuestRewards = nil; showDetail(2)
    assert(detailHas(addon.L("REWARD_UNAVAILABLE")))
end)
check("Reward redraw clears another quest's items and money text", function()
    addon.QuestRewards = function(id)
        if id == 2 then return { items = {}, choices = { { id = 103, name = "Only selected quest robe", count = 1 } }, money = 99 } end
        return nil
    end
    GetCoinTextureString = function() return "Selected coin texture" end
    showDetail(2)
    assert(detailHas(addon.L("REWARD_CHOICES")) and not detailHas(addon.L("REWARD_ITEMS")))
    assert(not detailHas(addon.L("REWARD_NO_ITEMS")))
    showDetail(3)
    assert(detailHas(addon.L("REWARD_UNAVAILABLE")))
    assert(not detailHas(addon.L("REWARD_ITEM", "Only selected quest robe", 1)))
    assert(not detailHas(addon.L("REWARD_MONEY") .. ": Selected coin texture"))
end)
check("Unavailable money formatter never produces a guessed currency value", function()
    addon.QuestRewards = function() return { items = {}, choices = {}, money = 100 } end
    GetCoinTextureString = nil; showDetail(2)
    assert(detailHas(addon.L("REWARD_MONEY_UNKNOWN")))
    addon.QuestRewards = function() error("reward API unavailable") end
    showDetail(2)
    assert(detailHas(addon.L("REWARD_UNAVAILABLE")) and not detailHas(addon.L("REWARD_MONEY_UNKNOWN")))
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
    assert(#cards() == 0 and ui.catalogNotice.shown and ui.catalogNotice.text == addon.L("NO_DUNGEONS"))
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
    showDetail(800)
    assert(ui.engine:State(800).status == "AVAILABLE" and ui.action.id == 800)
    assert(detailHas(addon.L("MATERIAL_QUESTS")) and detailHas(addon.L("MATERIAL_NOTICE")))
    assert(detailHas(addon.L("REPEATABLE")))
    local first, second = ui.materialButtons[1], ui.materialButtons[2]
    assert(first.shown and first.questID == 801 and first.itemID == 701)
    assert(first.note.text:find(addon.L("MATERIAL_ITEM", 701), 1, true))
    assert(first.note.text:find(addon.L("UNKNOWN_REQUIREMENTS"), 1, true))
    assert(second.shown and second.note.text:find(addon.L("COMPLETED"), 1, true))
    first.scripts.OnClick()
    assert(ui.quest == 801 and not ui.action and not ui.guide.enabled)
    assert(not detailHas(addon.L("MATERIAL_QUESTS")) and not detailHas(addon.L("MATERIAL_NOTICE")))
    assert(not detailHas(addon.L("REPEATABLE")) and not first.shown and not second.shown)
    showDetail(800)
    assert(ui.materialButtons[1] == first and first.shown and ui.action.id == 800)
end)
check("Material rows wrap, clear on redraw and tolerate an older planner", function()
    measurement = function(fs)
        if fs.text == "Quest 801" then return 72 end
        if fs.text and fs.text:find(addon.L("MATERIAL_ITEM", 701), 1, true) then return 36 end
        return 18
    end
    showDetail(800)
    local first, second = ui.materialButtons[1], ui.materialButtons[2]
    assert(first.height >= 7 + 72 + 4 + 36 + 7)
    assert(first.point[3] - second.point[3] >= first.height + 4)
    measurement = nil; showDetail(800)
    assert(first.height == 59)
    ui.engine.CompletionSteps = nil; ui:RefreshDetail()
    assert(not first.shown and not second.shown and not detailHas(addon.L("MATERIAL_QUESTS")))
    addon.quests[800].repeatable = "true"; showDetail(800)
    assert(not detailHas(addon.L("REPEATABLE")))
    addon.quests[800], addon.quests[801], addon.quests[802], done[802] = nil, nil, nil, nil
    showDetail(2)
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
    local following
    for _, fs in ipairs(ui.details) do
        if fs.shown and fs.text:find(addon.L("START"), 1, true) then following = -fs.point[3] end
    end
    assert(following and following >= portraitBottom + 8)
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
    assert(detailHas(addon.L("START") .. ": " .. addon.L("ITEM_STARTER", "Localized scroll")))
    assert(detailHas(addon.L("ITEM_DROP_SOURCE", "Charlga", "Razorfen Kraul")))
    assert(not ui.giver.enabled and not ui.giverAction and not ui.guide.enabled)
    assert(ui.engine:State(2).status == "AVAILABLE" and ui.action.kind == "pickup")
    addon.ItemName = nil; showDetail(2, { level = 20, completed = function() return false end, active = function() return false end })
    assert(detailHas(addon.L("START") .. ": " .. addon.L("ITEM_STARTER", "Small Scroll")))
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
    showDetail(900)
    assert(ui.materialButtons[1].note.text:find("Localized material", 1, true))
    assert(not ui.materialButtons[1].note.text:find(addon.L("MATERIAL_ITEM", 7083), 1, true))
    addon.ItemName = function() return nil end; showDetail(900)
    assert(ui.materialButtons[1].note.text:find(addon.L("MATERIAL_ITEM", 7083), 1, true))
    addon.ItemName = nil; addon.quests[900], addon.quests[901] = nil, nil
end)
check("Multiple item drop sources remain distinct without an invented interior pickup", function()
    local start = addon.quests[2].start
    addon.quests[2].start = { itemID = 7666, name = "Shattered Necklace", dropSources = {
        { npcID = 4852, name = "Stonevault Oracle", locationName = "Uldaman" },
        { npcID = 4845, name = "Shadowforge Ruffian", locationName = "Badlands" },
    } }
    showDetail(2)
    assert(detailHas(addon.L("ITEM_DROP_SOURCE", "Stonevault Oracle", "Uldaman")))
    assert(detailHas(addon.L("ITEM_DROP_SOURCE", "Shadowforge Ruffian", "Badlands")))
    assert(not ui.giver.enabled and not ui.guide.enabled and not addon.quests[2].startsInside)
    showDetail(3)
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
    showDetail(2861)
    assert(detailHas(addon.L("START_ALTERNATIVES")))
    assert(ui.engine:State(2861).status == "UNKNOWN" and ui.action == nil)
    assert(not ui.giver.enabled and not ui.guide.enabled and #visited == 0 and #mapped == 0)
    assert(ui.startButtons[1].title.text == "Anastasia" and ui.startButtons[1].height > 59)
    assert(ui.startButtons[2].title.text == "Bottle" and ui.startButtons[2].note.text == "Known zone")
    assert(not ui.startButtons[2].enabled and not ui.startButtons[2].scripts.OnClick)
    ui.startButtons[1].scripts.OnClick()
    assert(#visited == 1 and visited[1].kind == "visit" and visited[1].place.npcID == 4568)
    ui.startButtons[3].scripts.OnClick()
    assert(#mapped == 1 and mapped[1].npcID == 5144 and mapped[1].mapID == 2 and mapped[1].place == nil)
    assert(ui.engine:State(2861).status == "UNKNOWN" and ui.action == nil)
    assert(not addon.quests[2861].classes and not addon.quests[2861].start)
    measurement = nil
    showDetail(2)
    for _, row in ipairs(ui.startButtons) do
        assert(not row.shown and not row.enabled and not row.scripts.OnClick)
    end
    assert(not detailHas(addon.L("START_ALTERNATIVES")))
    addon.quests[2861].startAlternatives = { { npcID = 10, name = "Short" }, { objectID = 11, name = "Other" } }
    showDetail(2861)
    assert(ui.startButtons[1].title.text == "Short" and ui.startButtons[1].height == 59)
    assert(not ui.startButtons[3].shown and not ui.startButtons[3].scripts.OnClick)
    addon.quests[2861].requirementsKnown = true
    addon.quests[2861].requires = { { ids = { 1 } } }
    addon.quests[2861].startAlternatives[1] = { npcID = 10, name = "Known", mapID = 3, x = 40, y = 50 }
    showDetail(2861, { level = 20, completed = function() return false end, active = function() return false end })
    local prerequisite = ui.action
    assert(ui.engine:State(2861).status == "LOCKED" and prerequisite.id == 1)
    ui.startButtons[1].scripts.OnClick()
    assert(ui.action == prerequisite and visited[#visited].place.npcID == 10)
    assert(ui.engine:State(2861).status == "LOCKED")
    addon.quests[2861] = nil
end)
check("Known source zones display without inventing a client map or navigation", function()
    local start, finish, maps = addon.quests[2].start, addon.quests[2].finish, C_Map
    addon.quests[2].start = { npcID = 1, name = "Olvek", zoneName = "Alterac Mountains" }
    addon.quests[2].finish = { npcID = 2, name = "Other", zoneName = "Known finish" }
    showDetail(2)
    assert(detailHas(addon.L("START") .. ": Olvek — Alterac Mountains"))
    assert(detailHas(addon.L("ENDING") .. ": Other — Known finish"))
    assert(not ui.giver.enabled and not ui.guide.enabled and not ui.map.enabled)
    addon.quests[2].start.mapID = 1
    C_Map = { GetMapInfo = function() return { name = "Native zone" } end }
    showDetail(2)
    assert(detailHas(addon.L("START") .. ": Olvek — Native zone"))
    assert(ui.giver.enabled and not ui.giverHasCoordinates)
    addon.quests[2].start, addon.quests[2].finish, C_Map = start, finish, maps
end)
check("Narrative groups show shared bullets without expanding acceptance prerequisites", function()
    addon.quests[910] = { id = 910, minLevel = 1, requirementsKnown = false,
        storylineGroups = { { 911, 912 }, { 910 } } }
    addon.quests[911] = { id = 911, minLevel = 1, requirementsKnown = true, requires = { { ids = { 1 } } } }
    addon.quests[912] = { id = 912, minLevel = 1, requirementsKnown = true, factions = { "Horde" } }
    local context = { level = 20, faction = "Alliance", completed = function() return false end,
        active = function() return false end }
    showDetail(910, context)
    assert(ui.engine:State(910).status == "UNKNOWN" and ui.action == nil)
    assert(detailHas(addon.L("STORY_GROUP_NOTICE")))
    assert(detailHas(addon.L("STORY_GROUP", 1)) and detailHas(addon.L("STORY_GROUP", 2)))
    local labels = {}
    for _, b in ipairs(ui.chainButtons) do if b.shown then labels[#labels + 1] = b.label.text end end
    assert(#labels == 3, "an unlisted acceptance prerequisite must not enter the narrative groups")
    assert(labels[1]:find("• Quest 911", 1, true) and labels[2]:find("• Quest 912", 1, true))
    assert(not labels[1]:find("1. ", 1, true) and not labels[2]:find("2. ", 1, true))
    assert(ui.engine:State(912).status == "UNAVAILABLE")
    ui.chainButtons[2].scripts.OnClick()
    assert(ui.quest == 912 and ui.engine:State(912).status == "UNAVAILABLE" and ui.action == nil)
    assert(not detailHas(addon.L("STORY_GROUP_NOTICE")))
    addon.quests[910], addon.quests[911], addon.quests[912] = nil, nil, nil
end)
check("Narrative group rows wrap, recycle, and preserve ordinary ordered story labels", function()
    addon.quests[910] = { id = 910, minLevel = 1, requirementsKnown = false,
        storylineGroups = { { 911, 910 } } }
    addon.quests[911] = { id = 911, minLevel = 1, requirementsKnown = false }
    measurement = function(fs) if fs.text and fs.text:find("Quest 911", 1, true) then return 72 end; return 18 end
    showDetail(910)
    assert(ui.chainButtons[1].height == 78)
    assert(-ui.chainButtons[2].point[3] >= -ui.chainButtons[1].point[3] + 78)
    measurement = nil
    addon.quests[910].storylineGroups = nil
    addon.quests[910].storyline = { 910 }
    showDetail(910)
    assert(ui.chainButtons[1].height == 34 and ui.chainButtons[1].label.text:find("1. Quest 910", 1, true))
    assert(not ui.chainButtons[2].shown and not detailHas(addon.L("STORY_GROUP", 1)))
    addon.quests[910], addon.quests[911] = nil, nil
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
    showDetail(3801)
    assert(detailHas(addon.L("POSSIBLE_TURNINS")))
    assert(ui.engine:State(3801).status == "UNKNOWN" and ui.action == nil and not started and not mapped)
    assert(ui.finishButtons[1].height > 59 and ui.finishButtons[2].title.text == "Other Franclorn")
    assert(ui.finishButtons[3].note.text == "Known zone" and not ui.finishButtons[3].enabled)
    ui.finishButtons[1].scripts.OnClick()
    assert(started.id == 3801 and started.kind == "visit" and started.place.npcID == 8888)
    ui.finishButtons[2].scripts.OnClick()
    assert(mapped == addon.quests[3801].finishAlternatives[2] and not mapped.place)
    assert(ui.engine:State(3801).status == "UNKNOWN" and ui.action == nil)
    addon.quests[3801].requirementsKnown = true
    addon.quests[3801].requires = { { ids = { 1 } } }
    local context = { level = 20, completed = function() return false end, active = function() return false end }
    showDetail(3801, context)
    local nextAction = ui.action
    assert(nextAction.id == 1 and ui.engine:State(3801).status == "LOCKED")
    ui.finishButtons[1].scripts.OnClick()
    assert(ui.action == nextAction and ui.engine:State(3801).status == "LOCKED")
    measurement = nil
    showDetail(2)
    for _, b in ipairs(ui.finishButtons) do assert(not b.shown and not b.enabled and not b.scripts.OnClick) end
    assert(not detailHas(addon.L("POSSIBLE_TURNINS")))
    addon.quests[3801].finishAlternatives = { { npcID = 1, name = "Short" }, { objectID = 2, name = "Other" } }
    showDetail(3801, context)
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
    showDetail(920, context)
    assert(detailHas(addon.L("ITEM_CLASSES", "Localized warrior, Localized paladin")))
    assert(detailHas(addon.L("ITEM_MIN_LEVEL", 54)) and detailHas(addon.L("ITEM_REQUIREMENTS_NOTICE")))
    assert(addon.Planner.Eligible(addon.quests[920], context) == true)
    assert(ui.engine:State(920).status == "UNKNOWN" and ui.action == nil)
    local actions, uncertain = ui.engine:Next(920)
    assert(#actions == 0 and uncertain)
    addon.quests[920].requirementsKnown = true
    showDetail(920, context)
    assert(ui.engine:State(920).status == "AVAILABLE" and ui.action.kind == "pickup" and ui.action.id == 920)
    context.class, context.level = "WARRIOR", 60
    showDetail(920, context)
    assert(ui.engine:State(920).status == "AVAILABLE" and ui.action.kind == "pickup")
    addon.quests[920].classes = { "MAGE" }
    showDetail(920, context)
    assert(ui.engine:State(920).status == "UNAVAILABLE" and ui.action == nil)
    showDetail(2)
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
    showDetail(920)
    assert(detailHas(addon.L("ITEM_CLASSES", "First locale, PALADIN")))
    showDetail(920)
    assert(detailHas(addon.L("ITEM_CLASSES", "Second locale, PALADIN")))
    LocalizedClassList = function() error("native unavailable") end
    showDetail(920)
    assert(detailHas(addon.L("ITEM_CLASSES", "WARRIOR, PALADIN")))
    LOCALIZED_CLASS_NAMES_MALE = setmetatable({}, { __index = function() error("restricted lookup") end })
    showDetail(920)
    assert(detailHas(addon.L("ITEM_CLASSES", "WARRIOR, PALADIN")))
    addon.quests[920].start.itemID = nil
    showDetail(920)
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
    assert(detailHas(addon.L("REWARD_DIALOGUE")) and detailHas(addon.L("REWARD_XP", 1234)))
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
    assert(detailHas(addon.L("REWARD_HIDDEN")))
    assert(not detailHas(addon.L("REWARD_NO_ITEMS")) and not detailHas(addon.L("REWARD_UNAVAILABLE")))
    addon.DialogueRewards = function() return { source = "dialogue", items = {}, choices = {}, xp = 0 } end
    showDetail(2)
    assert(detailHas(addon.L("REWARD_NO_ITEMS")) and detailHas(addon.L("REWARD_XP", 0)))
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
    assert(summaryIndex < progressIndex and progressText and detailHas(addon.L("REWARD_HIDDEN")))
    assert(ui.engine:State(2).status == previousState and (ui.action and ui.action.kind) == previousKind)
    showDetail(1)
    assert(not detailHas(addon.L("OBJECTIVE_DIALOGUE")) and not detailHas(addon.L("OBJECTIVE_PROGRESS")))
    assert(not detailHas("Bring the sealed report to its recipient."))
    showDetail(2)
    assert(detailHas(addon.L("OBJECTIVE_DIALOGUE")) and calls == 3)
    open = false; ui:Refresh()
    assert(not detailHas(addon.L("OBJECTIVE_DIALOGUE")) and not detailHas("Bring the sealed report to its recipient."))
    assert(detailHas(addon.L("OBJECTIVE_PROGRESS")) and detailHas(addon.L("REWARD_HIDDEN")))
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
check("Catalogue labels distinguish listed targets from character eligibility and retain selection", function()
    local dungeons, context = addon.dungeons, addon.Context
    local search, range, includeUnavailable = ui.search, ui.range, ui.includeUnavailable
    local selected, quest = ui.dungeon, ui.quest
    local factions = addon.quests[2].factions
    addon.quests[2].factions = { "Horde" }
    addon.Context = function() return { level = 20, faction = "Alliance" } end
    local listed = { key = "listed", name = "Listed dungeon", minLevel = 10, maxLevel = 30, quests = { 1, 2 } }
    local empty = { key = "empty", name = "Empty dungeon", minLevel = 40, maxLevel = 50, quests = {} }
    addon.dungeons = { listed, empty }
    ui.search, ui.range, ui.includeUnavailable, ui.dungeon, ui.quest = "", false, false, listed, 2
    measurement = function(fs) return fs.text and fs.text:find("\n", 1, true) and 36 or 18 end
    ui:RefreshDungeons()
    local card = ui.cards[1]
    assert(card.note.text == addon.L("CATALOG_LEVELS", 10, 30) .. "\n" .. addon.L("CATALOG_QUESTS", 2))
    assert(card.height == 72 and ui.cards[2].point[3] == -76, "two metadata lines must fit cumulative geometry")
    assert(addon.Planner.Eligible(addon.quests[2], addon.Context()) == false)
    ui.includeUnavailable = true; ui:RefreshDungeons()
    assert(card.note.text:find(addon.L("CATALOG_QUESTS", 2), 1, true), "listed count is independent of character filtering")
    ui.search = "Empty"; ui:RefreshDungeons()
    assert(ui.cards[1] == card and card.title.text == "Empty dungeon")
    assert(card.note.text == addon.L("CATALOG_LEVELS", 40, 50) .. "\n" .. addon.L("CATALOG_QUESTS", 0))
    assert(not ui.cards[2].shown and ui.dungeon == listed and ui.quest == 2)
    ui.search = "no such dungeon"; ui:RefreshDungeons()
    assert(ui.catalogNotice.shown and not card.shown and ui.dungeon == listed and ui.quest == 2)
    measurement = nil
    addon.quests[2].factions, addon.dungeons, addon.Context = factions, dungeons, context
    ui.search, ui.range, ui.includeUnavailable, ui.dungeon, ui.quest = search, range, includeUnavailable, selected, quest
    ui:Refresh()
end)
check("Prerequisite groups expose AND and OR structure and distinguish acceptance from completion", function()
    local context = { level = 20, faction = "Alliance", active = function(id) return id == 971 end,
        completed = function(id) return id == 972 end }
    addon.quests[970] = { id = 970, minLevel = 1, requirementsKnown = true,
        requires = { { ids = { 971 } }, { ids = { 972, 973 }, mode = "active" } } }
    addon.quests[971] = { id = 971, minLevel = 1, requirementsKnown = true }
    addon.quests[972] = { id = 972, minLevel = 1, requirementsKnown = true }
    addon.quests[973] = { id = 973, minLevel = 1, requirementsKnown = true, factions = { "Horde" } }
    measurement = function(fs) return fs.text == "Quest 971" and 72 or 18 end
    showDetail(970, context)
    assert(detailHas(addon.L("REQUIREMENT_GROUPS")) and detailHas(addon.L("REQUIREMENT_NOTICE")))
    assert(detailHas(addon.L("REQUIREMENT_GROUP", 1)) and detailHas(addon.L("REQUIREMENT_GROUP", 2)))
    assert(detailHas(addon.L("REQUIREMENT_COMPLETE")) and detailHas(addon.L("REQUIREMENT_ACTIVE")))
    assert(ui.engine:State(970).status == "LOCKED" and ui.action.id == 971 and ui.action.kind == "complete")
    local row = ui.requirementButtons[1]
    assert(row.shown and row.questID == 971 and row.title.text == "Quest 971" and row.height == 108)
    assert(row.note.text:find(addon.L("ACTIVE"), 1, true))
    local unavailable
    for _, b in ipairs(ui.branchButtons) do if b.shown and b.parentID == 973 then unavailable = b end end
    assert(unavailable and not unavailable.enabled and not unavailable.scripts.OnClick)
    row.scripts.OnClick()
    assert(ui.quest == 971 and ui.engine:State(971).status == "ACTIVE")
    assert(not row.shown and not row.enabled and not row.scripts.OnClick)
    showDetail(970, context)
    assert(ui.requirementButtons[1] == row and row.shown)
    addon.quests[970].requirementsKnown = false
    addon.quests[970].requires = { { ids = { 974 } } }
    showDetail(970, context)
    assert(ui.engine:State(970).status == "UNKNOWN" and ui.action == nil)
    assert(row.questID == 974 and row.height == 59 and row.note.text:find(addon.L("UNKNOWN"), 1, true))
    row.scripts.OnClick()
    assert(ui.quest == 974 and detailHas(addon.L("REASON_missing")))
    assert(not detailHas(addon.L("REQUIREMENT_GROUPS")) and not row.shown and not row.scripts.OnClick)
    for _, id in ipairs({ 970, 971, 972, 973 }) do addon.quests[id] = nil end
    measurement = nil
    showDetail(2)
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
    assert(not ui.back.enabled and ui.back.text == addon.L("DETAIL_BACK"))
    local singleton = ui.requirementButtons[1]
    singleton.scripts.OnClick()
    assert(ui.quest == 981 and #ui.detailHistory == 1 and ui.detailHistory[1] == 980 and ui.back.enabled)
    assert(not singleton.shown and not singleton.scripts.OnClick)
    ui.back.scripts.OnClick()
    assert(ui.quest == 980 and #ui.detailHistory == 0 and not ui.back.enabled)
    ui.chainButtons[1].scripts.OnClick()
    assert(ui.quest == 981 and #ui.detailHistory == 1)
    ui:BackQuest()
    local material = ui.materialButtons[1]
    material.scripts.OnClick()
    assert(ui.quest == 984 and #ui.detailHistory == 1 and not material.scripts.OnClick)
    ui:BackQuest()
    ui.rows[2].scripts.OnClick()
    assert(ui.quest == 981 and #ui.detailHistory == 1)
    ui:BackQuest()
    ui:Refresh(); ui:RefreshDetail(); ui:InspectQuest(980)
    assert(#ui.detailHistory == 0)
    assert(ui:ChooseBranch(980, 2, 982) and #ui.detailHistory == 0 and ui.quest == 980)
    ui:InspectQuest(981)
    assert(#ui.detailHistory == 1)
    ui.cards[2].scripts.OnClick()
    assert(ui.dungeon == other and ui.quest == nil and #ui.detailHistory == 0 and not ui.back.enabled)
    for _, row in ipairs(ui.rows) do if not row.shown then assert(not row.scripts.OnClick) end end
    assert(addon.char.detailHistory == nil and addon.db.detailHistory == nil)
    for _, id in ipairs({ 980, 981, 982, 983, 984 }) do addon.quests[id] = nil end
    addon.char.choices, addon.char.selectedDungeon = choices, selectedDungeon
    addon.dungeons, ui.dungeon, ui.quest, ui.preparation, ui.detailHistory = dungeons, selected, quest, preparation, {}
    ui:Refresh()
end)
check("Back history caps clean IDs at twenty and supports unknown cards without repushing", function()
    local quest, history = ui.quest, ui.detailHistory
    ui.quest, ui.detailHistory = 2000, {}
    for id = 2001, 2025 do assert(ui:InspectQuest(id)) end
    assert(#ui.detailHistory == 20 and ui.detailHistory[1] == 2005 and ui.detailHistory[20] == 2024)
    ui:InspectQuest(2025); ui:RefreshDetail()
    assert(#ui.detailHistory == 20 and detailHas(addon.L("REASON_missing")))
    for _, id in ipairs({ 0, -1, 1.5, math.huge, "2026", false }) do assert(not ui:InspectQuest(id)) end
    assert(ui.quest == 2025 and #ui.detailHistory == 20)
    for expected = 2024, 2005, -1 do assert(ui:BackQuest() and ui.quest == expected) end
    assert(#ui.detailHistory == 0 and not ui.back.enabled and not ui:BackQuest())
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
    assert(ui:BackQuest() and ui.quest == 1 and scroll.verticalScroll == 0)
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
    assert(ui.requirementButtons[1].note.text:find(addon.L("ACTIVE") .. " — " .. marker, 1, true))
    local branchMarked, chainMarked = false, 0
    for _, b in ipairs(ui.branchButtons) do
        if b.shown and b.parentID == 992 then branchMarked = b.label.text:find(addon.L("READY") .. " — " .. marker, 1, true) end
        if b.shown and b.parentID == 993 then assert(not b.label.text:find(marker, 1, true)) end
    end
    for _, b in ipairs(ui.chainButtons) do if b.shown and b.label.text:find(marker, 1, true) then chainMarked = chainMarked + 1 end end
    assert(branchMarked and chainMarked == 2 and ui.materialButtons[1].note.text:find(marker, 1, true))
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
    for _, fs in ipairs(ui.details) do if fs.shown and fs.text:find(value, 1, true) then return true end end
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
    assert(detailIncludes(addon.L("START") .. ": Native 101") and detailIncludes("Catalog finish"))
    assert(ui.action.place == start and start.name == "Catalog start" and finish.name == "Catalog finish")
    ui.preparation = true; ui:Refresh()
    local marked = false
    for _, row in ipairs(visibleRows()) do if row.questID == 2 or row.title.text == "Quest 2" then
        marked = row.note.text:find("Native 101", 1, true) ~= nil
    end end
    assert(marked, "preparation uses same fresh giver name")
    current = 102; ui:RefreshDetail()
    assert(detailIncludes("Catalog start") and detailIncludes(addon.L("ENDING") .. ": Native 102"))
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
        assert(detailIncludes(addon.L("START") .. ": Catalog fallback"))
    end
    addon.GiverName = function() error("unavailable") end; showDetail(2)
    assert(detailIncludes(addon.L("START") .. ": Catalog fallback"))
    addon.GiverName = nil; showDetail(2); assert(detailIncludes("Catalog fallback"))
    addon.quests[2].start.name = nil; showDetail(2)
    assert(detailIncludes(addon.L("START") .. ": " .. addon.L("UNKNOWN_PLACE")))
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
    showDetail(2)
    assert(ui.startButtons[1].title.text == native and ui.finishButtons[1].title.text == native)
    assert(ui.startButtons[2].title.text == "Catalog object" and ui.finishButtons[2].title.text == "Catalog object")
    assert(npc.name == "Catalog alternative" and ui.startButtons[1].enabled)
    current = nil; ui:RefreshDetail()
    assert(ui.startButtons[1].title.text == "Catalog alternative")
    assert(ui.finishButtons[1].title.text == "Catalog alternative")
    addon.quests[2].startAlternatives, addon.quests[2].finishAlternatives = nil, nil
    addon.quests[2].start = { itemID = 999, name = "Catalog item", dropNPCID = 101, dropName = "Catalog drop",
        dropSources = { { npcID = 101, name = "Catalog multi drop", locationName = "Source zone" } } }
    addon.ItemName = function(id) assert(id == 999); return "Native item" end
    current = 101; native = "Native drop"; showDetail(2)
    assert(detailIncludes(addon.L("ITEM_STARTER", "Native item")))
    assert(detailIncludes(addon.L("ITEM_DROP_SOURCE", native, "Source zone")))
    assert(not ui.startButtons[1].shown and not ui.finishButtons[1].shown)
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
    showDetail(9920)
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
    showDetail(9920); reportToggle("start").scripts.OnClick()
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
    showDetail(9920)
    assert(not reportToggle("start") and not reportToggle("finish"))
    assert(reportToggle("startAlternative:1") and reportToggle("startAlternative:2") and reportToggle("finishAlternative:1"))
    reportToggle("startAlternative:2").scripts.OnClick()
    assert(#reportRows() == 2 and reportRows()[1].destination.mapID == 3)
    assert(not ui.reportedExpanded["startAlternative:1"] and not ui.reportedExpanded["finishAlternative:1"])
    ui.startButtons[1].scripts.OnClick()
    assert(actions[1].place == a and actions[1].place.x == 10, "ordinary location visit retains actual primary")
    reportRows()[2].scripts.OnClick()
    assert(actions[2].place.npcID == 101 and actions[2].place.x == 51 and actions[2].place.mapID == 3)
    assert(not ui.action and addon.quests[9920].start == a)
    addon.Navigation = nav; endReports()
end)
check("Same-card refresh and language preserve expansion and scroll while Back resets card session", function()
    reportedFixture()
    local locale, history, nav = addon.db.locale, ui.detailHistory, addon.Navigation
    local calls = 0; addon.Navigation = { Start = function() calls = calls + 1 end }; ui.detailHistory = {}
    showDetail(9920); reportToggle("start").scripts.OnClick()
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
    assert(ui.detailScroll.verticalScroll == 0 and calls == 0)
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
    showDetail(9920); reportToggle("start").scripts.OnClick()
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
    showDetail(9920); reportToggle("start").scripts.OnClick(); assert(#reportRows() == 100)
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
    showDetail(9920); reportToggle("start").scripts.OnClick()
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
    showDetail(9930, context)
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
    showDetail(9930, context)
    assert(ui.action.id == 9931 and ui.action.place == addon.quests[9931].start and not ui.giverAction)
    local action = ui.action
    ui.containerButtons[1].scripts.OnClick()
    assert(ui.action == action and ui.action.id == 9931)
    container.x, container.y, container.reportedLocations = nil, nil, nil
    showDetail(9930, context)
    staleReport(); assert(#visits == 3)
    row.scripts.OnClick()
    assert(#maps == 1 and maps[1] == container and maps[1].mapID == 1441 and not maps[1].place)
    local staleMap = row.scripts.OnClick
    container.mapID = nil
    container.name = "Container with unknown map"
    measurement = nil; showDetail(9930, context)
    assert(row.shown and not row.enabled and not row.scripts.OnClick and row.height == 59)
    assert(detailHas(addon.L("CONTAINER_SOURCE")) and row.note.text == "Thousand Needles")
    staleMap(); assert(#maps == 1)
    showDetail(2)
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
    showDetail(9932)
    local startClick, finishClick = ui.startButtons[1].scripts.OnClick, ui.finishButtons[1].scripts.OnClick
    ui:RefreshDetail(); startClick(); finishClick(); assert(calls == 0)
    ui.startButtons[1].scripts.OnClick(); ui.finishButtons[1].scripts.OnClick(); assert(calls == 2)
    startClick, finishClick = ui.startButtons[1].scripts.OnClick, ui.finishButtons[1].scripts.OnClick
    showDetail(2); startClick(); finishClick(); assert(calls == 2)
    addon.quests[9932], addon.Navigation = nil, nav
end)
check("Unverified inactive quests identify missing requirements in rows and details without an action", function()
    local selected, context, preparation = ui.quest, addon.Context, ui.preparation
    addon.Context = function() return { level = 20, completed = function() return false end,
        active = function() return false end } end
    ui.quest, ui.preparation = 3, false; ui:Refresh()
    local expected = "|cffb4aacd" .. addon.L("UNKNOWN_REQUIREMENTS") .. "|r"
    assert(detailHas(expected) and ui.engine:State(3).status == "UNKNOWN")
    assert(ui.engine:State(3).reason == "requirements" and not ui.action and not ui.guide.enabled and not ui.map.enabled)
    local found
    for _, row in ipairs(visibleRows()) do if row.title.text == "Quest 3" then found = row.note.text end end
    assert(found == expected)
    ui.preparation = true; ui:Refresh()
    for _, row in ipairs(visibleRows()) do
        if row.title.text == "Quest 3" then assert(row.note.text == expected) end
        if row.title.text == "Quest 1" then assert(row.note.text:find(addon.L("pickup"), 1, true)) end
    end
    addon.Context, ui.quest, ui.preparation = context, selected, preparation; ui:Refresh()
end)
check("Requirement wording does not replace other unknown reasons or explicit storyline titles", function()
    showDetail(3, { level = 20, active = function() return false end, completed = function() return nil end })
    assert(ui.engine:State(3).reason == "character")
    assert(detailHas("|cffb4aacd" .. addon.L("UNKNOWN") .. "|r") and not ui.action)
    for _, reason in ipairs({ "character", "missing", "cycle", "level" }) do
        ui.quest = 3
        ui.engine = { context = {}, State = function() return { status = "UNKNOWN", reason = reason } end,
            Next = function() return {}, true end }
        ui:RefreshDetail()
        assert(detailHas("|cffb4aacd" .. addon.L("UNKNOWN") .. "|r"))
        assert(not detailHas("|cffb4aacd" .. addon.L("UNKNOWN_REQUIREMENTS") .. "|r") and not ui.action)
    end
    local story = addon.quests[3].storyline
    addon.quests[3].storyline = { 3 }
    showDetail(3, { level = 20, active = function() return false end, completed = function() return false end })
    assert(ui.chainButtons[1].shown and ui.chainButtons[1].label.text == "|cffb4aacd1. Quest 3|r")
    addon.quests[3].storyline = story; showDetail(2)
end)
check("Requirement label is translated in every locale and held or completed evidence keeps its status", function()
    local locale, count = addon.db.locale, 0
    for key, strings in pairs(addon.locales) do
        assert(type(strings.UNKNOWN_REQUIREMENTS) == "string" and strings.UNKNOWN_REQUIREMENTS ~= "")
        assert(strings.UNKNOWN_REQUIREMENTS ~= strings.UNKNOWN)
        addon.db.locale = key
        showDetail(3, { level = 20, active = function() return false end, completed = function() return false end })
        assert(detailHas("|cffb4aacd" .. strings.UNKNOWN_REQUIREMENTS .. "|r")); count = count + 1
    end
    assert(count == 10); addon.db.locale = locale
    local context = addon.Context()
    context.completed = function() return true end
    context.active = function() return true end
    for _, ready in ipairs({ false, true }) do
        context.ready = function() return ready end
        showDetail(3, context)
        local status, color = ready and "READY" or "ACTIVE", ready and "ffe066" or "88bfff"
        assert(detailHas("|cff" .. color .. addon.L(status) .. " — " .. addon.L("COMPLETED_BEFORE") .. "|r"))
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
        ready, ui.quest, ui.preparation = turnin, 9950, true; ui:Refresh()
        local state = ui.engine:State(9950)
        local plan = ui.engine:Dungeon(ui.dungeon)
        assert(state.status == "UNKNOWN" and state.reason == "requirements")
        assert(plan.unknown and not plan.ready and ui.coverage.text == addon.L("PARTIAL"))
        assert(#plan.actions == 1 and plan.actions[1].id == 9951)
        assert(plan.actions[1].kind == (turnin and "turnin" or "complete"))
        assert(ui.action and ui.action.id == 9951 and ui.action.kind == plan.actions[1].kind)
        assert(ui.guide.enabled == turnin and ui.map.enabled == turnin)
        assert(detailHas("|cffb4aacd" .. addon.L("UNKNOWN_REQUIREMENTS") .. "|r"))
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
    assert(detailHas(addon.L("REWARD_PREVIEW")) and not detailHas(addon.L("REWARD_UNAVAILABLE")))
    assert(detailHas(addon.L("REWARD_ITEM", "Cached fixed item", 2)))
    assert(detailHas(addon.L("REWARD_ITEM", "Cached choice item", 1)))
    assert(detailHas(addon.L("REWARD_XP", 123)) and detailHas(addon.L("REWARD_MONEY") .. ": coin:500"))
    assert(dialogue == 1 and log == 1 and cached == 1)
    assert(ui.engine:State(9950).status == "UNKNOWN" and not ui.action and not ui.guide.enabled and not ui.giverAction)
    assert(addon.quests[9950].requirementsKnown == false)
    GetCoinTextureString = formatter; endCachedRewards()
end)
check("Dialogue including explicit hide wins before selected log and cached reward sources", function()
    local context = cachedRewardFixture(); local logReads, cacheReads = 0, 0
    addon.CachedQuestRewards = function() cacheReads = cacheReads + 1; return { source = "cache", items = {}, choices = {}, xp = 111 } end
    addon.QuestRewards = function() logReads = logReads + 1; return { items = {}, choices = {}, xp = 222 } end
    addon.DialogueRewards = function() return { source = "dialogue", hidden = true } end
    showDetail(9950, context)
    assert(detailHas(addon.L("REWARD_HIDDEN")) and not detailHas(addon.L("REWARD_PREVIEW")))
    assert(logReads == 0 and cacheReads == 0 and not detailHas(addon.L("REWARD_NO_ITEMS")))
    addon.DialogueRewards = function() return { source = "dialogue", items = {}, choices = {}, xp = 333 } end
    ui:RefreshDetail(); assert(detailHas(addon.L("REWARD_XP", 333)) and cacheReads == 0 and logReads == 0)
    addon.DialogueRewards = function() return nil end
    ui:RefreshDetail(); assert(detailHas(addon.L("REWARD_XP", 222)) and logReads == 1 and cacheReads == 0)
    assert(not detailHas(addon.L("REWARD_PREVIEW")))
    addon.DialogueRewards = function() error("offer unavailable") end
    addon.QuestRewards = function() logReads = logReads + 1; error("log unavailable") end
    ui:RefreshDetail(); assert(detailHas(addon.L("REWARD_XP", 111)) and cacheReads == 1)
    assert(detailHas(addon.L("REWARD_PREVIEW")))
    endCachedRewards()
end)
check("Missing throwing invalid and restricted cache producers stay unknown instead of empty rewards", function()
    local context = cachedRewardFixture(); local restricted = {}
    addon.DialogueRewards, addon.QuestRewards = nil, nil
    issecretvalue = function(value) return value == restricted end
    for _, value in ipairs({ false, true, 0, "bad", restricted, {}, { source = "cache", items = false, choices = {} } }) do
        addon.CachedQuestRewards = function() return value end; showDetail(9950, context)
        assert(detailHas(addon.L("REWARD_UNAVAILABLE")) and not detailHas(addon.L("REWARD_NO_ITEMS")))
    end
    addon.CachedQuestRewards = function() error("cache unavailable") end; ui:RefreshDetail()
    assert(detailHas(addon.L("REWARD_UNAVAILABLE")))
    addon.CachedQuestRewards = nil; ui:RefreshDetail(); assert(detailHas(addon.L("REWARD_UNAVAILABLE")))
    issecretvalue = nil; endCachedRewards()
end)
check("Cached preview refreshes the same card and clears recycled reward fields on another card", function()
    local context = cachedRewardFixture(); local name, xp, reads = "First cached item", 10, 0
    addon.CachedQuestRewards = function(id)
        reads = reads + 1
        if id == 9950 then return { source = "cache", items = { { name = name, count = 1 } }, choices = {}, xp = xp } end
    end
    showDetail(9950, context); ui.detailScroll:SetVerticalScroll(83)
    assert(detailHas(addon.L("REWARD_ITEM", name, 1)))
    name, xp = "Updated cached item", 20; ui:RefreshDetail()
    assert(reads == 2 and ui.detailScroll.verticalScroll == 83)
    assert(detailHas(addon.L("REWARD_ITEM", name, 1)) and detailHas(addon.L("REWARD_XP", 20)))
    assert(not detailHas(addon.L("REWARD_ITEM", "First cached item", 1)) and not detailHas(addon.L("REWARD_XP", 10)))
    showDetail(9951, context)
    assert(not detailHas(addon.L("REWARD_PREVIEW")) and detailHas(addon.L("REWARD_UNAVAILABLE")))
    assert(not detailHas(addon.L("REWARD_ITEM", name, 1)) and not detailHas(addon.L("REWARD_XP", 20)))
    assert(not ui.action and ui.engine:State(9951).status == "UNKNOWN")
    endCachedRewards()
end)
check("Confirmed empty cached rewards preserve real zero experience and all preview translations", function()
    local context = cachedRewardFixture()
    addon.CachedQuestRewards = function() return { source = "cache", items = {}, choices = {}, xp = 0, money = 0 } end
    showDetail(9950, context)
    assert(detailHas(addon.L("REWARD_PREVIEW")) and detailHas(addon.L("REWARD_NO_ITEMS")))
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
    local row = ui.materialButtons[1]
    assert(row.shown and row.note.text:find(addon.L("ITEM_CARRIED", 3), 1, true))
    assert(ui.engine:State(9960).status == "UNKNOWN" and not ui.action and not ui.guide.enabled and visits == 0)
    counts[80001], counts[80002] = 2, 0; ui:RefreshDetail()
    assert(detailHas(addon.L("ITEM_CARRIED", 2)) and not detailHas(addon.L("ITEM_CARRIED", 0)))
    assert(row.note.text:find(addon.L("ITEM_CARRIED", 0), 1, true) and not row.note.text:find(addon.L("ITEM_CARRIED", 3), 1, true))
    counts[80001], counts[80002] = nil, nil; ui:RefreshDetail()
    assert(not detailHas(addon.L("ITEM_CARRIED", 2)) and not row.note.text:find(addon.L("ITEM_CARRIED", 0), 1, true))
    assert(ui.engine:State(9960).status == "UNKNOWN" and not ui.action and visits == 0)
    assert(#calls == 6)
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
check("Quest log capacity is informational and preserves the development notice", function()
    local producer, navigation = addon.QuestLogCapacity, addon.Navigation
    local count, capacity, reads, visits = 0, 20, 0, 0
    addon.QuestLogCapacity = function() reads = reads + 1; return { count = count, capacity = capacity } end
    addon.Navigation = { Start = function() visits = visits + 1 end, Map = function() visits = visits + 1 end }
    showDetail(2); ui:Refresh()
    assert(ui.capacityStatus.shown and ui.capacityStatus.text == addon.L("QUEST_LOG_CAPACITY", 0, 20))
    assert(ui.footer.text == addon.L("DEVELOPMENT"))
    local status, action, quest = ui.engine:State(2).status, ui.action and ui.action.kind, ui.quest
    count = 23; ui:Refresh()
    assert(ui.capacityStatus.text == addon.L("QUEST_LOG_CAPACITY", 23, 20))
    assert(ui.engine:State(2).status == status and (ui.action and ui.action.kind) == action and ui.quest == quest and visits == 0)
    count = 5; ui:Refresh()
    assert(ui.capacityStatus.text == addon.L("QUEST_LOG_CAPACITY", 5, 20) and reads >= 3)
    ui.frame:Hide(); count = 8
    ui:Toggle()
    ui.frame.scripts.OnShow(ui.frame)
    assert(ui.capacityStatus.text == addon.L("QUEST_LOG_CAPACITY", 8, 20) and ui.footer.text == addon.L("DEVELOPMENT"))
    addon.QuestLogCapacity, addon.Navigation = producer, navigation
    ui:Refresh()
end)
check("Missing invalid or restricted capacity clears the reused status instead of claiming zero", function()
    local producer, checker = addon.QuestLogCapacity, issecretvalue
    addon.QuestLogCapacity = function() return { count = 2, capacity = 20 } end; ui:Refresh()
    assert(ui.capacityStatus.shown)
    local function omitted()
        ui:Refresh()
        assert(not ui.capacityStatus.shown and ui.capacityStatus.text == "" and ui.footer.text == addon.L("DEVELOPMENT"))
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
check("Capacity formats safely in all locales without changing the base footer", function()
    local producer, locale = addon.QuestLogCapacity, addon.db.locale
    addon.QuestLogCapacity = function() return { count = 1e20, capacity = 20 } end
    local dictionaries = 0
    for code, strings in pairs(addon.locales) do
        addon.db.locale = code; ui:Refresh()
        assert(ui.capacityStatus.shown and ui.capacityStatus.text == string.format(strings.QUEST_LOG_CAPACITY, 1e20, 20))
        assert(ui.capacityStatus.text:find("100000000000000000000", 1, true))
        assert(ui.footer.text == strings.DEVELOPMENT)
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
    measurement = function(fs) return fs.width == 304 and fs.text == addon.L("REWARD_ITEM", "Fixed reward", 2) and 72 or 18 end
    ui:RefreshDetail()
    assert(detailHas(addon.L("REWARD_ITEM", "Fixed reward", 2)) and detailHas(addon.L("REWARD_ITEM", "Choice reward", 1)))
    local first, second = ui.rewardButtons[1], ui.rewardButtons[2]
    assert(first.shown and first.icon.texture == 123 and first.width == 24 and first.height == 24)
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
    assert(decorated.width == 304 and decorated.point[2] == 34)
    for _, texture in ipairs({ 0, -1, "", false, {} }) do
        f.data.items[1].texture, f.data.choices[1].texture = texture, nil
        ui:RefreshDetail()
        assert(not first.shown and decorated.width == 334 and decorated.point[2] == 4)
        assert(detailHas(addon.L("REWARD_ITEM", "Fixed reward", 2)))
    end
    f.data.items[1].texture = nil; ui:RefreshDetail(); assert(not first.shown)
    f.data.items[1].texture = 123
    first.icon.SetTexture = function() return false end; ui:RefreshDetail(); assert(not first.shown and decorated.width == 334)
    first.icon.SetTexture = function() error("Texture unavailable") end; ui:RefreshDetail(); assert(not first.shown and decorated.width == 334)
    first.icon.SetTexture = false; ui:RefreshDetail(); assert(not first.shown and decorated.width == 334)
    first.icon.SetTexture = methods.SetTexture
    issecretvalue = function(value) return value == 123 end; ui:RefreshDetail(); assert(not first.shown)
    issecretvalue = f.oldSecret
    f.data = nil; ui:RefreshDetail()
    assert(not first.shown and not first.scripts.OnEnter and first.icon.texture == nil)
    for _, fs in ipairs(ui.details) do if fs.shown then assert(fs.width == 334 and fs.point[2] == 4) end end
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
        if mode > 1 then assert(detailHas(addon.L("REWARD_ITEM", "New reward", 1))) end
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
check("All-character inspection explains recorded quest classes races and minimum level", function()
    local oldContext, className, raceName = addon.Context, addon.ClassName, addon.RaceName
    local dungeon, include, quest = ui.dungeon, ui.includeUnavailable, ui.quest
    addon.Context = function() return { level = 60, class = "WARRIOR", race = 1,
        completed = function() return false end, active = function() return false end } end
    addon.quests[9980] = { id = 9980, minLevel = 40, requirementsKnown = true, classes = { "MAGE" }, races = { 95 } }
    ui.dungeon = { key = "restrictions", name = "Restrictions", minLevel = 1, maxLevel = 60, coverage = "partial", quests = { 9980 } }
    addon.ClassName = function(token) assert(token == "MAGE"); return "Native mage" end
    addon.RaceName = function(id) assert(id == 95); return "Native new race" end
    ui.includeUnavailable, ui.quest = true, 9980; ui:Refresh()
    assert(ui.engine:State(9980).status == "UNAVAILABLE" and not ui.action and not ui.guide.enabled)
    assert(detailHas(addon.L("QUEST_MIN_LEVEL", 40)))
    assert(detailHas(addon.L("QUEST_CLASSES", "Native mage")) and detailHas(addon.L("QUEST_RACES", "Native new race")))
    local found = false
    for _, row in ipairs(visibleRows()) do if row.title.text == "Quest 9980" then found = true end end
    assert(found)
    addon.ClassName, addon.RaceName = nil, nil; ui:RefreshDetail()
    assert(detailHas(addon.L("QUEST_CLASSES", "MAGE")) and detailHas(addon.L("QUEST_RACES", addon.L("RACE_ID", 95))))
    assert(not detailHas(addon.L("QUEST_RACES", "Native new race")) and ui.engine:State(9980).status == "UNAVAILABLE" and not ui.action)
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
    assert(classReads == 1 and raceReads == 2)
    assert(detailHas(addon.L("QUEST_CLASSES", "MAGE")))
    assert(detailHas(addon.L("QUEST_RACES", addon.L("RACE_ID", 95) .. ", " .. addon.L("RACE_ID", 1))))
    assert(ui.engine:State(9981).status == "ACTIVE")
    local many = {}; for i = 1, 101 do many[i] = i end
    addon.quests[9981].races = many; raceReads = 0; addon.RaceName = function() raceReads = raceReads + 1; return nil end
    ui:RefreshDetail(); assert(raceReads == 100)
    for _, minimum in ipairs({ 0, -1, 1.5, "35", math.huge, restricted }) do
        addon.quests[9981].minLevel = minimum; ui:RefreshDetail()
        assert(not detailHas(addon.L("QUEST_MIN_LEVEL", 35)))
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
        assert(detailHas(addon.L("QUEST_MIN_LEVEL", 50)))
        assert(detailHas(addon.L("QUEST_CLASSES", "Client class")))
        assert(detailHas(addon.L("QUEST_RACES", addon.L("RACE_ID", 95))))
        assert(ui.engine:State(9982).status == "UNKNOWN" and not ui.action)
        dictionaries = dictionaries + 1
    end
    assert(dictionaries == 10)
    addon.db.locale = locale; showDetail(2)
    assert(not detailHas(addon.L("QUEST_MIN_LEVEL", 50)) and not detailHas(addon.L("QUEST_CLASSES", "Client class")))
    assert(not detailHas(addon.L("QUEST_RACES", addon.L("RACE_ID", 95))))
    addon.ClassName, addon.RaceName = className, raceName; addon.quests[9982] = nil
end)
check("Restriction name reentry cannot append old labels after quest or generation changes", function()
    local className, raceName = addon.ClassName, addon.RaceName
    for _, helper in ipairs({ "ClassName", "RaceName" }) do
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
            assert(not detailHas(addon.L("QUEST_CLASSES", "Stale outer restriction")))
            assert(not detailHas(addon.L("QUEST_RACES", "Stale outer restriction")))
            if sameQuest then
                assert(detailHas(addon.L("QUEST_CLASSES", "Current class")) and detailHas(addon.L("QUEST_RACES", "Current race")))
            else
                assert(not detailHas(addon.L("QUEST_CLASSES", "Current class")) and not detailHas(addon.L("QUEST_RACES", "Current race")))
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
    assert(detailHas(addon.L("OBJECTIVE_ITEMS")) and detailHas(addon.L("OBJECTIVE_ITEMS_NOTICE")))
    assert(detailHas(addon.L("OBJECTIVE_ITEM", "Native feather", 2)) and detailHas(addon.L("OBJECTIVE_ITEM", "#81002", 3)))
    assert(detailHas(addon.L("ITEM_CARRIED", 0)) and detailHas(addon.L("ITEM_CARRIED", 8)))
    assert(detailHas(addon.L("OBJECTIVE_PROGRESS")))
    assert(ui.engine:State(9985).status == "UNKNOWN" and not ui.action and not ui.guide.enabled)
    addon.ItemName = function() return nil end; addon.CarriedItemCount = function() return nil end; ui:RefreshDetail()
    assert(detailHas(addon.L("OBJECTIVE_ITEM", "Source feather", 2)))
    assert(not detailHas(addon.L("ITEM_CARRIED", 0)) and not detailHas(addon.L("ITEM_CARRIED", 8)))
    addon.ItemName, addon.CarriedItemCount, addon.QuestObjectives = itemName, count, objectives
    addon.quests[9985] = nil; showDetail(2)
    assert(not detailHas(addon.L("OBJECTIVE_ITEMS")) and not detailHas(addon.L("OBJECTIVE_ITEMS_NOTICE")))
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
    assert(not detailHas(addon.L("OBJECTIVE_ITEMS")) and not detailHas(addon.L("OBJECTIVE_ITEMS_NOTICE")))
    addon.quests[9986].objectiveItems = {}; ui:RefreshDetail(); assert(not detailHas(addon.L("OBJECTIVE_ITEMS")))
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
        assert(detailHas(addon.L("OBJECTIVE_ITEMS")) and detailHas(addon.L("OBJECTIVE_ITEMS_NOTICE")))
        assert(detailHas(addon.L("OBJECTIVE_ITEM", "Client feather", 2)))
        assert(ui.engine:State(9987).status == "UNKNOWN" and not ui.action)
        dictionaries = dictionaries + 1
    end
    assert(dictionaries == 10)
    addon.db.locale = locale; addon.quests[9987].objectiveItems = nil; ui:RefreshDetail()
    assert(not detailHas(addon.L("OBJECTIVE_ITEMS")) and not detailHas(addon.L("OBJECTIVE_ITEM", "Client feather", 2)))
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
            assert(detailHas(addon.L("OBJECTIVE_ITEMS")) == sameQuest)
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
    local long = "Long description for overflow"
    addon.Description = function() return long end
    measurement = function(fs) return fs.text == long and 700 or 18 end
    showDetail(2); assert(ui.detailScroll.ScrollBar.shown)
    addon.Description = function() return "Short description" end
    ui:RefreshDetail()
    assert(ui.detail:GetHeight() <= ui.detailScroll:GetHeight() and not ui.detailScroll.ScrollBar.shown)
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
print("Preparation UI modeled checks passed: " .. total .. " (no native layout validation)")
