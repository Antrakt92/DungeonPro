-- Search the actual container sources shown for Blueleaf Tubers, not native item names.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui = fixture.addon, fixture.addon.UI
C_Timer = { After = function() end }
GetLocale = function() return "enUS" end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
ui:Toggle()
ui.dungeon, ui.quest, ui.includeUnavailable, ui.range = nil, nil, true, false
local quest = assert(addon.quests[1221])
assert(#quest.objectiveItemSources == 3)
for _, row in ipairs(quest.objectiveItemSources) do
    for _, place in ipairs(row.containerSources) do
        ui.search = place.name; ui:RefreshDungeons()
        local count = 0
        for _, card in ipairs(ui.cards) do if card:IsShown() then
            count = count + 1
            assert(card.matchQuestID == 1221 and card.title.text == "Razorfen Kraul")
            assert(card.note.text:find(place.name, 1, true), "source object cue remains visible")
        end end
        assert(count == 1, "recorded object source finds exactly RFK/1221: " .. place.name)
    end
end
local function has(terms, text)
    for _, term in ipairs(terms) do if term.text == text then return true end end
    return false
end
local function sourceQuest()
    return { start = { npcID = 1, name = "Endpoint" },
        objectiveItems = { { itemID = 5880, name = "Do not index item names" } },
        objectiveItemSources = { { itemID = 5880, containerSources = {
            { objectID = 21277, name = "Recorded cache", zoneName = "Known area", mapID = 1413 }
        } } } }
end
for _, mutate in ipairs({
    function(q) q.objectiveItemSources[1].itemID = 1 end,
    function(q) q.objectiveItems = {} end,
    function(q) q.objectiveItems[2] = { itemID = 5880 } end,
    function(q) q.objectiveItems[2] = { itemID = 5880 }; q.objectiveItems[3] = { itemID = 5880 } end,
    function(q) q.objectiveItemSources[2] = q.objectiveItemSources[1] end,
    function(q) local p=q.objectiveItemSources[1].containerSources[1];p.objectID=nil;p.npcID=21277 end,
    function(q) q.objectiveItemSources[1].containerSources[1].npcID = 1 end,
}) do
    local q = sourceQuest(); mutate(q)
    local terms, current = addon.QuestSourceSearchTerms(q)
    assert(current() and has(terms, "Endpoint") and not has(terms, "Recorded cache"), "invalid binding cannot create source terms")
end
for _, mutate in ipairs({
    function(q) q.objectiveItems[1].itemID = 1 end,
    function(q) q.objectiveItemSources[1].itemID = 1 end,
    function(q) q.objectiveItemSources[1].containerSources = {} end,
    function(q) q.objectiveItemSources[1].containerSources[1].name = "Changed" end,
    function(q) q.objectiveItemSources[1].containerSources[1].objectID = 9 end,
    function(q) q.objectiveItems = {} end,
    function(q) q.objectiveItemSources = {} end,
}) do
    local q = sourceQuest()
    local terms, current, unchanged = addon.QuestSourceSearchTerms(q)
    assert(current() and has(terms, "Recorded cache")); mutate(q)
    assert(not current() and not unchanged(), "source bindings retire when their consulted inputs change")
end
local q = sourceQuest()
q.objectiveItemSources[1].containerSources[1].reportedLocations = { { mapID = 1, zoneName = "Unrelated nested place" } }
q.objectiveItemSources[1].containerSources[1].containerSource = { objectID = 1, name = "Unrelated nested object" }
local terms, current = addon.QuestSourceSearchTerms(q)
assert(current() and has(terms, "Recorded cache") and not has(terms, "Do not index item names"))
assert(not has(terms, "Unrelated nested place") and not has(terms, "Unrelated nested object"), "container sources are leaves")
q = sourceQuest()
for index = 2, 101 do q.objectiveItemSources[1].containerSources[index] = { objectID = index, name = "Source " .. index } end
terms, current = addon.QuestSourceSearchTerms(q)
assert(current() and not has(terms, "Source 101"), "source traversal keeps its per-list bound")
for _, field in ipairs({ "objectiveItems", "objectiveItemSources" }) do
    q = sourceQuest()
    for index = 2, 101 do q[field][index] = { itemID = index } end
    terms, current = addon.QuestSourceSearchTerms(q)
    assert(current() and has(terms, "Endpoint") and not has(terms, "Recorded cache"), "oversized role lists stay bounded")
end
q = sourceQuest()
local reads, itemName = 0, addon.ItemName
addon.ItemName = function() reads = reads + 1; error("Search must not hydrate native item names") end
terms, current = addon.QuestSourceSearchTerms(q)
addon.ItemName = itemName
assert(current() and has(terms, "Recorded cache") and reads == 0)
print("Objective source search: PASS (three actual UI queries, role binding, identity, mutations, leaf scope and bounds)")
