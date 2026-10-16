local addon, count, secret = {}, 0, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
addon.char = { untouched = {} }
GetBuildInfo = function() return "1.60.1", "70425", "", 16001 end
issecretvalue = function(value) return value == secret end
local offerCapabilities = {
    { "GetObjectiveText", "offerObjectiveText" }, { "GetQuestID", "offerQuestID" },
    { "GetNumQuestRewards", "offerRewardItems" }, { "GetNumQuestChoices", "offerRewardChoices" },
    { "GetQuestItemInfo", "offerRewardInfo" }, { "GetRewardMoney", "offerRewardMoney" },
    { "GetRewardXP", "offerRewardXP" },
}
local forbiddenCalls = 0
local function check(name, fn)
    C_QuestLog, C_Item, C_Map, C_QuestLine, TomTom = nil, nil, nil, nil, nil
    QuestFrame, QuestFrameDetailPanel, GetQuestText, UnitGUID, GetLocale = nil, nil, nil, nil, nil
    for _, capability in ipairs(offerCapabilities) do _G[capability[1]] = nil end
    forbiddenCalls = 0
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err))
    assert(forbiddenCalls == 0, name .. ": a swallowed call read native content or panel state")
    count = count + 1; print("PASS " .. name)
end
local function forbidden()
    forbiddenCalls = forbiddenCalls + 1
    error("Presence probe called a capability instead of checking it")
end
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
check("Dialogue capabilities and panels are presence-only without content identity or visibility reads", function()
    for _, capability in ipairs(offerCapabilities) do _G[capability[1]] = forbidden end
    C_QuestLog = { ShouldShowQuestRewards = forbidden }
    UnitGUID, GetLocale, GetQuestText = forbidden, forbidden, forbidden
    QuestFrame, QuestFrameDetailPanel = { IsShown = forbidden }, { IsShown = forbidden }
    local r = addon.ProbeClient()
    for _, capability in ipairs(offerCapabilities) do assert(r.api[capability[2]] == true, capability[2]) end
    assert(r.api.offerRewardVisibility == true)
    assert(r.frames.questFrame == true and r.frames.questDetailPanel == true)
    assert(next(r.questLines) == nil and r.player == nil and r.questID == nil and r.text == nil)
    assert(addon.char.probe == r)
end)
check("Each missing offered capability is reported independently as false", function()
    local allKeys = { "offerRewardVisibility" }
    for _, capability in ipairs(offerCapabilities) do allKeys[#allKeys + 1] = capability[2] end
    for _, capability in ipairs(offerCapabilities) do
        _G[capability[1]] = forbidden
        local r = addon.ProbeClient()
        for _, key in ipairs(allKeys) do assert(r.api[key] == (key == capability[2]), key) end
        assert(r.frames.questFrame == false and r.frames.questDetailPanel == false)
        _G[capability[1]] = nil
    end
    C_QuestLog = { ShouldShowQuestRewards = forbidden }
    local r = addon.ProbeClient()
    for _, key in ipairs(allKeys) do assert(r.api[key] == (key == "offerRewardVisibility"), key) end
end)
check("Nonfunction offered globals and nonpanel values cannot imply capability support", function()
    for _, capability in ipairs(offerCapabilities) do _G[capability[1]] = {} end
    C_QuestLog = { ShouldShowQuestRewards = false }
    for _, value in ipairs({ false, 1, "QuestFrame", forbidden, secret }) do
        QuestFrame, QuestFrameDetailPanel = value, value
        local r = addon.ProbeClient()
        for _, capability in ipairs(offerCapabilities) do assert(r.api[capability[2]] == false) end
        assert(r.api.offerRewardVisibility == false)
        assert(r.frames.questFrame == false and r.frames.questDetailPanel == false)
    end
end)
check("Panel object presence does not inspect members or infer that a dialogue is open", function()
    local unreadable = setmetatable({}, { __index = forbidden })
    QuestFrame, QuestFrameDetailPanel = unreadable, {}
    local r = addon.ProbeClient()
    assert(r.frames.questFrame and r.frames.questDetailPanel)
    assert(r.api.offerQuestID == false and r.api.offerRewardVisibility == false)
    QuestFrame = nil
    local later = addon.ProbeClient()
    assert(later.frames.questFrame == false and later.frames.questDetailPanel == true)
    assert(r.frames.questFrame == true)
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
