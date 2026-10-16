local methods = {}
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:GetWidth() return self.width or 340 end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:SetPoint(...) self.point = { ... } end
function methods:GetPoint() return unpack(self.point) end
function methods:ClearAllPoints() self.point = nil end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:SetText(value) self.text = value end
function methods:SetEnabled(value) self.enabled = value end
function methods:GetStringHeight() return 18 end
function methods:SetScale(value) self.scale = value end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:SetClampedToScreen(value) self.clamped = value end
function methods:IsShown() return self.shown end
function methods:Hide() self.shown = false end
function methods:Show() self.shown = true end
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
addon.char = {}
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
    for _, row in ipairs(ui.rows) do if row.shown then result[#result + 1] = row end end
    return result
end
ui:Create(); ui.frame:Show(); ui.dungeon = addon.dungeons[1]; ui:Refresh()
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
check("Inside pickup, level gates and active completion remain distinct", function()
    local rows = visibleRows()
    assert(rows[3].note.text:find("Pick up inside the dungeon", 1, true))
    assert(rows[4].note.text:find("Reach level 30", 1, true))
    assert(rows[5].note.text:find("Finish this quest", 1, true))
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
end)
check("Completed preparation keeps the prepared result instead of empty data warning", function()
    for id in pairs(addon.quests) do done[id] = true end
    ui.preparationButton.scripts.OnClick()
    assert(#visibleRows() == 0 and ui.coverage.text == addon.L("PREPARED"))
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
print("Preparation UI modeled checks passed: " .. total .. " (no native layout validation)")
