-- Reported source areas must be searchable even when the endpoint has no zone label.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui = fixture.addon, fixture.addon.UI
C_Timer = { After = function() end }
GetLocale = function() return "enUS" end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
ui:Toggle()
ui.dungeon, ui.quest, ui.includeUnavailable, ui.range = nil, nil, true, false
local originalDungeons = addon.dungeons
local function has(terms, text)
    for _, term in ipairs(terms) do if term.kind == "place" and term.text == text then return true end end
    return false
end
for _, case in ipairs({ { 914, "Thunder Bluff" }, { 959, "The Barrens" }, { 962, "Thunder Bluff" } }) do
    local id, area = unpack(case)
    local quest = assert(addon.quests[id])
    assert(quest.start.zoneName == nil and quest.start.reportedLocations[1].zoneName == area)
    local parent
    for _, dungeon in ipairs(originalDungeons) do
        for _, target in ipairs(dungeon.quests) do if target == id then parent = dungeon; break end end
        if parent then break end
    end
    assert(parent, "actual quest remains a listed dungeon target")
    local dungeon = {}; for key, value in pairs(parent) do dungeon[key] = value end
    dungeon.quests = { id }; addon.dungeons = { dungeon }
    local terms, current = addon.QuestSourceSearchTerms(quest)
    assert(current() and has(terms, area), "reported area is indexed for actual quest " .. id)
    ui.search = area; ui:RefreshDungeons()
    local count = 0
    for _, card in ipairs(ui.cards) do if card:IsShown() then
        count = count + 1
        assert(card.matchQuestID == id and card.note.text:find(area, 1, true), "search preserves exact quest and area cue")
    end end
    assert(count == 1, "reported area finds the quest's dungeon exactly once")
end
addon.dungeons = originalDungeons
local function endpoint()
    return { start = { npcID = 1, reportedLocations = { { mapID = 1456, zoneName = "Thunder Bluff" } } } }
end
for _, mutate in ipairs({
    function(q) q.start.reportedLocations = {} end,
    function(q) q.start.reportedLocations[1] = {} end,
    function(q) q.start.reportedLocations[1].zoneName = "Other" end,
    function(q) q.start.reportedLocations[1].mapID = 0 end,
    function(q) q.start.reportedLocations[2] = { mapID = 1456, zoneName = "New" } end,
}) do
    local q = endpoint()
    local terms, current, unchanged = addon.QuestSourceSearchTerms(q)
    assert(current() and has(terms, "Thunder Bluff")); mutate(q)
    assert(not current() and not unchanged(), "revised reported positions retire previous search proof")
end
for _, bad in ipairs({ false, 0, -1, 1.5, math.huge, "1456" }) do
    local q = endpoint(); q.start.reportedLocations[1].mapID = bad
    local terms = addon.QuestSourceSearchTerms(q)
    assert(not has(terms, "Thunder Bluff"), "invalid map cannot create an untyped source area")
end
local q = endpoint()
for index = 2, 101 do q.start.reportedLocations[index] = { mapID = 1456, zoneName = "Area " .. index } end
local terms, current = addon.QuestSourceSearchTerms(q)
assert(current() and #terms == 100 and not has(terms, "Area 101"), "reported positions obey existing per-list bound")
q = endpoint(); q.start.reportedLocations[1].reportedLocations = q.start.reportedLocations
terms, current = addon.QuestSourceSearchTerms(q)
assert(current() and #terms == 1, "cyclic source locations terminate without duplicate terms")
print("Reported source-place search: PASS (three actual quests, UI matches, mutation, malformed maps, bounds and cycles)")
