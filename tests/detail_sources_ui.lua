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
    assert(ui:SetDetailTab("sources"))
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

-- F-B DETAIL-ITEM-STARTER-STRICTNESS: malformed/secret alternatives never claim
-- a detail item starter (the shared classifier returns nil for them while the
-- lenient emptiness check alone says absent). Well-formed choices keep
-- GIVER_CHOICES_REQUIRED and a lone starter keeps its acquisition key.
do
 local qItem = assert(addon.quests[98423])
 assert(qItem.startAlternatives == nil, "catalogue item starter carries no alternatives")
 local savedStart, savedAlternatives = qItem.start, qItem.startAlternatives
 local savedDungeon, savedQuest = ui.dungeon, ui.quest
 local function renderItem()
  for _, dungeon in ipairs(addon.dungeons) do
   for _, id in ipairs(dungeon.quests) do if id == 98423 then ui.dungeon = dungeon end end
  end
  ui.quest = 98423; ui:Refresh()
  assert(ui:SetDetailTab("quest"))
 end
 renderItem()
 assert(ui.giverUnavailableKey == "START_ITEM_LOCATION_UNKNOWN", "lone item starter keeps its acquisition key")
 qItem.startAlternatives = 5
 renderItem()
 assert(ui.giverUnavailableKey == "GIVER_LOCATION_UNKNOWN", "malformed alternatives claim no item starter and no choices")
 qItem.startAlternatives = { { npcID = 5678 } }
 renderItem()
 -- Well-formed alternatives on a valid item start are recorded but not
 -- rendered as choice buttons (that branch serves start-less records), so the
 -- card keeps the honest location warning instead of an item claim.
 assert(ui.giverUnavailableKey == "GIVER_LOCATION_UNKNOWN", "well-formed alternatives keep the location warning, never an item starter")
 do
  local secretAlt = {}
  local savedChecker = issecretvalue
  qItem.startAlternatives = secretAlt
  issecretvalue = function(value) return value == secretAlt end
  renderItem()
  assert(ui.giverUnavailableKey == "GIVER_LOCATION_UNKNOWN", "secret alternatives claim no item starter and no choices")
  issecretvalue = savedChecker
 end
 qItem.start, qItem.startAlternatives = savedStart, savedAlternatives
 ui.dungeon, ui.quest = savedDungeon, savedQuest; ui:Refresh()
 assert(ui:SetDetailTab("sources"))
end
-- F-D DETAIL-EMPTY-FALLBACK: with the shared helpers absent, the detail uses
-- its documented local verdicts (a Clean empty table still counts as absent,
-- so an item starter with empty alternatives keeps its acquisition key);
-- restoring the helpers recovers the shared verdict. Both helpers are nil-ed
-- together because the classifier delegates emptiness to its sibling.
do
 local qItem = assert(addon.quests[98423])
 local savedAlternatives = qItem.startAlternatives
 local questSources = addon.QuestNavigation
 local savedEmpty, savedKind = questSources.IsEmptyAlternatives, questSources.PickupStartKind
 qItem.startAlternatives = {}
 ui.quest = 98423; ui:Refresh()
 assert(ui:SetDetailTab("quest"))
 assert(ui.giverUnavailableKey == "START_ITEM_LOCATION_UNKNOWN", "shared helpers present keep the item starter for empty alternatives")
 questSources.IsEmptyAlternatives, questSources.PickupStartKind = nil, nil
 ui:RefreshDetail()
 assert(ui.giverUnavailableKey == "START_ITEM_LOCATION_UNKNOWN", "missing helpers fall back to absent for empty alternatives, never choices")
 questSources.IsEmptyAlternatives, questSources.PickupStartKind = savedEmpty, savedKind
 ui:RefreshDetail()
 assert(ui.giverUnavailableKey == "START_ITEM_LOCATION_UNKNOWN", "restored helpers recover the shared verdict")
 qItem.startAlternatives = savedAlternatives
end
print("Detail item-starter strictness checks passed (malformed/secret alternatives claim no item starter)")
-- The right quest card has no entrance action; that belongs to dungeon cards.
-- Its redraws must not query unrelated entrance metadata or retain overview state.
local entrances, entranceReads = addon.Entrances, 0
addon.Entrances = { Get = function(...)
    entranceReads = entranceReads + 1
    return entrances.Get(...)
end }
ui.quest = nil; ui:RefreshDetail()
assert(entranceReads == 1, "overview still resolves its entrance facts")
entranceReads = 0
ui.quest = 971; ui:RefreshDetail(); ui:RefreshDetail()
assert(entranceReads == 0 and ui.entranceBinding == nil,
    "quest-only redraws cannot repeatedly scan unrelated dungeon entrance sources")
addon.Entrances = entrances
print("Quest detail avoids unrelated entrance work: PASS")
