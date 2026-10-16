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
    "SetHighlightTexture", "SetTexture", "SetFrameStrata", "EnableMouse", "SetMovable", "RegisterForDrag",
    "StartMoving", "StopMovingOrSizing", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "SetAutoFocus", "SetScrollChild" }) do methods[name] = function() end end
local function object()
    return setmetatable({ scripts = {} }, { __index = methods })
end
function methods:CreateTexture() return object() end
function methods:CreateFontString() return object() end
CreateFrame = object
UIParent, UISpecialFrames = object(), {}
local screenWidth, screenHeight = 1920, 480
GetScreenWidth = function() return screenWidth end
GetScreenHeight = function() return screenHeight end
GetLocale = function() return "enUS" end
local addon, done = {}, { [7] = true }
assert(loadfile("Core/Namespace.lua"))("DungeonPrep", addon)
assert(loadfile("Locales/Strings.lua"))("DungeonPrep", addon)
assert(loadfile("Core/Planner.lua"))("DungeonPrep", addon)
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
assert(loadfile("UI/Window.lua"))("DungeonPrep", addon)
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
print("Preparation UI modeled checks passed: " .. total .. " (no native layout validation)")
