local methods, measurement = {}, nil
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:GetWidth() return self.width or 340 end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:SetPoint(...) self.point = { ... } end
function methods:GetPoint() return unpack(self.point) end
function methods:ClearAllPoints() self.point = nil end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:SetText(value) self.text = value end
function methods:SetTexture(value) self.texture = value end
function methods:GetText() return self.text or "" end
function methods:SetEnabled(value) self.enabled = value end
function methods:GetStringHeight() if measurement then return measurement(self) end; return 18 end
function methods:SetScale(value) self.scale = value end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:SetClampedToScreen(value) self.clamped = value end
function methods:IsShown() return self.shown end
function methods:Hide() self.shown = false end
function methods:Show() self.shown = true end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
for _, name in ipairs({ "SetFont", "SetJustifyH", "SetTextColor", "SetAllPoints", "SetColorTexture",
    "SetHighlightTexture", "SetFrameStrata", "EnableMouse", "SetMovable", "RegisterForDrag",
    "StartMoving", "StopMovingOrSizing", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "SetAutoFocus", "SetScrollChild" }) do methods[name] = function() end end
local function object(_, name)
    local frame = setmetatable({ scripts = {}, name = name }, { __index = methods })
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
    assert(row.title.text == "Quest 3" and row.note.text:find("Not enough information", 1, true))
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
    for id in pairs(addon.quests) do done[id] = true end
    ui.preparationButton.scripts.OnClick()
    assert(#visibleRows() == 0 and ui.coverage.text == addon.L("PREPARED"))
    for _, row in ipairs(ui.rows) do assert(not row.shown) end
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
    assert(first.note.text:find(addon.L("UNKNOWN"), 1, true))
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
print("Preparation UI modeled checks passed: " .. total .. " (no native layout validation)")
