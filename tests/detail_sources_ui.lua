-- Actual source locations remain complete without repeated endpoint disclosures.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui = fixture.addon, fixture.addon.UI
C_Timer = { After = function() end }
UnitLevel = function() return 60 end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
ui:Toggle()
addon.db.locale = "enUS"
local quest = assert(addon.quests[971])
for _, dungeon in ipairs(addon.dungeons) do
    for _, id in ipairs(dungeon.quests) do if id == 971 then ui.dungeon = dungeon end end
end
local function render()
    ui.quest = 971; ui:Refresh()
    if not ui.detailReferencesExpanded then ui.referenceToggle.scripts.OnClick() end
end
local function toggles()
    local result = {}
    for _, row in ipairs(ui.reportedToggles) do if row:IsShown() then result[#result + 1] = row end end
    return result
end
render()
assert(#toggles() == 1, "actual q971 shows the identical giver/turn-in reported locations once")
local source = quest.start.reportedLocations
assert(#source == 5 and #quest.finish.reportedLocations == 5)
toggles()[1].scripts.OnClick()
local rows = {}
for _, row in ipairs(ui.reportedRows) do if row:IsShown() then rows[#rows + 1] = row end end
assert(#rows == 5, "deduplication preserves every recorded point")
local priorNavigation, visits = addon.Navigation, {}
addon.Navigation = { Start = function(action) visits[#visits + 1] = action.place; return true end }
for index, row in ipairs(rows) do
    row.scripts.OnClick()
    assert(visits[index].mapID == source[index].mapID and visits[index].x == source[index].x and visits[index].y == source[index].y)
end
local oldClick = rows[1].scripts.OnClick
ui.quest = 166; ui:Refresh()
oldClick()
assert(#visits == 5, "a recycled reported-point handler cannot route from another quest")
addon.Navigation = priorNavigation
local originalReports, originalNPC = quest.finish.reportedLocations, quest.finish.npcID
local changed = {}
for index, point in ipairs(originalReports) do
    changed[index] = {}; for field, value in pairs(point) do changed[index][field] = value end
end
changed[#changed].x = changed[#changed].x + 1
quest.finish.reportedLocations = changed
render()
assert(#toggles() == 2, "different recorded point lists remain distinct")
quest.finish.reportedLocations = originalReports
quest.finish.npcID = originalNPC + 1
render()
assert(#toggles() == 2, "identical coordinates never merge different NPC identities")
quest.finish.npcID = originalNPC
render()
assert(#toggles() == 1 and quest.start.reportedLocations == source and quest.finish.reportedLocations == originalReports,
    "presentation deduplication leaves both source records untouched")
print("Quest endpoint source disclosures: PASS (actual q971, five exact points, distinct sources and stale clicks)")
