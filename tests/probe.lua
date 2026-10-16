local addon, count, secret = {}, 0, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPrep", addon)
assert(loadfile("Core/Client.lua"))("DungeonPrep", addon)
addon.char = { untouched = {} }
GetBuildInfo = function() return "1.60.1", "70425", "", 16001 end
issecretvalue = function(value) return value == secret end
local function check(name, fn)
    C_QuestLog, C_Item, C_Map, C_QuestLine, TomTom = nil, nil, nil, nil, nil
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err)); count = count + 1; print("PASS " .. name)
end
local function forbidden() error("Presence probe called a capability instead of checking it") end
check("Capability report checks presence without reading rewards item names or portraits", function()
    C_QuestLog = { GetQuestLogPortraitGiver = forbidden }
    C_Item = { GetItemNameByID = forbidden, RequestLoadItemDataByID = forbidden }
    C_Map, TomTom = { SetUserWaypoint = forbidden }, { AddWaypoint = forbidden }
    GetNumQuestLogRewards, GetNumQuestLogChoices, GetQuestLogRewardMoney = forbidden, forbidden, forbidden
    local r = addon.ProbeClient()
    for _, key in ipairs({ "rewardItems", "rewardChoices", "rewardMoney", "portraits", "itemNames", "itemRequests", "nativeWaypoints", "tomtom" }) do
        assert(r.api[key] == true)
    end
    assert(addon.char.probe == r and addon.char.untouched and next(r.questLines) == nil)
    GetNumQuestLogRewards, GetNumQuestLogChoices, GetQuestLogRewardMoney = nil, nil, nil
end)
check("Unavailable optional APIs remain false instead of assumed native support", function()
    local r = addon.ProbeClient()
    assert(r.api.portraits == false and r.api.itemNames == false and r.api.nativeWaypoints == false)
end)
check("Invalid or restricted line identities never reach membership readers", function()
    for _, id in ipairs({ 0, -1, 1.5, math.huge, 0 / 0, secret, "12" }) do
        C_QuestLine = { GetQuestLineInfo = function() return { questLineID = id } end, GetQuestLineQuests = forbidden }
        assert(next(addon.ProbeClient().questLines) == nil)
    end
end)
check("Unknown membership differs from a confirmed empty line", function()
    C_QuestLine = { GetQuestLineInfo = function() return { questLineID = 12 } end }
    local unknown = addon.ProbeClient().questLines[166]
    assert(unknown.questsAvailable == false and #unknown.quests == 0)
    C_QuestLine.GetQuestLineQuests = function() return {} end
    local empty = addon.ProbeClient().questLines[166]
    assert(empty.questsAvailable == true and #empty.quests == 0 and not empty.truncated and not empty.invalidMembers)
end)
check("Membership deduplicates valid IDs and marks invalid or truncated source data", function()
    local ids = { 166, 166, 0, -1, 1.5, secret, "65", 65 }
    C_QuestLine = { GetQuestLineInfo = function() return { questLineID = 12 } end, GetQuestLineQuests = function() return ids end }
    local r = addon.ProbeClient().questLines[166]
    assert(#r.quests == 2 and r.quests[1] == 166 and r.quests[2] == 65 and r.invalidMembers and not r.truncated)
    ids = {}; for i = 1, 101 do ids[i] = i end
    r = addon.ProbeClient().questLines[166]
    assert(#r.quests == 100 and r.quests[100] == 100 and r.truncated and not r.invalidMembers)
end)
issecretvalue = nil
print("Client probe modeled checks passed: " .. count .. " (API presence is not native acceptance)")
