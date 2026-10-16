local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPrep", addon)
assert(loadfile("Core/Client.lua"))("DungeonPrep", addon)
local selected, logIndex, fixedCount, choiceCount, money = 65, 1, 1, 1, 12345
local fixed, choice = {}, {}
local secret = {}
local function reset()
    selected, logIndex, fixedCount, choiceCount, money = 65, 1, 1, 1, 12345
    fixed = { "Reward", 123, 2, 3, false, 7001 }
    choice = { "Choice", "Interface\\Icons\\Choice", 1, 4, true, 8001 }
    issecretvalue = function(v) return v == secret end
    C_QuestLog = {
        GetSelectedQuest = function(...) assert(select("#", ...) == 0); return selected end,
        GetLogIndexForQuestID = function(id) assert(id == 65); return logIndex end,
        SetSelectedQuest = function() error("selection writes forbidden") end,
    }
    GetNumQuestLogRewards = function(...) assert(select("#", ...) == 0); return fixedCount end
    GetNumQuestLogChoices = function(...) assert(select("#", ...) == 0); return choiceCount end
    GetQuestLogRewardMoney = function(...) assert(select("#", ...) == 0); return money end
    GetQuestLogRewardInfo = function(index, ...) assert(index == 1 and select("#", ...) == 0); return unpack(fixed, 1, 6) end
    GetQuestLogChoiceInfo = function(index, ...) assert(index == 1 and select("#", ...) == 0); return unpack(choice, 1, 6) end
end
local function check(name, fn)
    reset()
    local ok, err = pcall(fn)
    if not ok then error(name .. ": " .. tostring(err), 0) end
    total = total + 1; print("PASS " .. name)
end
check("Selected active quest maps exact native item tuples and optional money", function()
    local r = addon.QuestRewards(65)
    assert(#r.items == 1 and #r.choices == 1 and r.money == 12345)
    assert(r.items[1].id == 7001 and r.items[1].name == "Reward" and r.items[1].count == 2)
    assert(r.items[1].texture == 123 and r.items[1].quality == 3 and r.items[1].usable == false)
    assert(r.choices[1].id == 8001 and r.choices[1].texture == "Interface\\Icons\\Choice")
    assert(r.choices[1].quality == 4 and r.choices[1].usable == true and r.xp == nil)
end)
check("Missing API and another selected quest never return unrelated rewards", function()
    C_QuestLog = nil; assert(addon.QuestRewards(65) == nil)
    reset(); selected = 66; assert(addon.QuestRewards(65) == nil)
    GetNumQuestLogRewards = function() error("must not inspect other quest rewards") end
    assert(addon.QuestRewards(65) == nil)
end)
check("Only clean positive integer quest IDs and active log indexes qualify", function()
    for _, id in ipairs({ 0, -1, 65.5, math.huge, 0 / 0, "65", secret }) do
        assert(addon.QuestRewards(id) == nil)
    end
    for _, value in ipairs({ 0, -1, 1.5, math.huge, 0 / 0, secret }) do
        logIndex = value; assert(addon.QuestRewards(65) == nil)
    end
    logIndex = nil; assert(addon.QuestRewards(65) == nil)
end)
check("Known zero counts are valid even when item getters are missing", function()
    fixedCount, choiceCount = 0, 0
    GetQuestLogRewardInfo, GetQuestLogChoiceInfo, GetQuestLogRewardMoney = nil, nil, nil
    local r = addon.QuestRewards(65)
    assert(r and #r.items == 0 and #r.choices == 0 and r.money == nil)
end)
check("Unknown fractional negative and excessive counts do not become empty rewards", function()
    for _, value in ipairs({ -1, 0.5, 101, math.huge, 0 / 0, secret }) do
        fixedCount = value; assert(addon.QuestRewards(65) == nil)
        fixedCount, choiceCount = 0, value; assert(addon.QuestRewards(65) == nil)
    end
    fixedCount, choiceCount = 0, nil; assert(addon.QuestRewards(65) == nil)
    reset(); GetNumQuestLogRewards = nil; assert(addon.QuestRewards(65) == nil)
end)
check("Bounded item loops include the hundredth record and reject a later uncached row", function()
    fixedCount, choiceCount = 100, 0
    GetQuestLogRewardInfo = function(index)
        return "Reward " .. index, 123, 1, 2, true, 7000 + index
    end
    local r = addon.QuestRewards(65)
    assert(#r.items == 100 and r.items[100].id == 7100 and #r.choices == 0)
    GetQuestLogRewardInfo = function(index)
        if index == 100 then return nil end
        return "Reward " .. index, 123, 1, 2, true, 7000 + index
    end
    assert(addon.QuestRewards(65) == nil)
end)
check("Count and item getter errors fail the entire snapshot", function()
    GetNumQuestLogRewards = function() error("unavailable") end
    assert(addon.QuestRewards(65) == nil)
    reset(); GetQuestLogRewardInfo = function() error("uncached") end
    assert(addon.QuestRewards(65) == nil)
    reset(); GetQuestLogChoiceInfo = nil; assert(addon.QuestRewards(65) == nil)
end)
check("Every secret tuple field fails closed without partial item arrays", function()
    for field = 1, 6 do
        reset(); fixed[field] = secret; assert(addon.QuestRewards(65) == nil)
        reset(); choice[field] = secret; assert(addon.QuestRewards(65) == nil)
    end
    reset(); issecretvalue = function() error("restricted checker") end
    assert(addon.QuestRewards(65) == nil)
end)
check("Uncached names and invalid item IDs or stack counts fail closed", function()
    for _, value in ipairs({ "", false, 99 }) do
        reset(); fixed[1] = value; assert(addon.QuestRewards(65) == nil)
    end
    reset(); fixed[1] = nil; assert(addon.QuestRewards(65) == nil)
    for _, field in ipairs({ 3, 6 }) do
        for _, value in ipairs({ 0, -1, 0.5, math.huge, 0 / 0, "42" }) do
            reset(); fixed[field] = value; assert(addon.QuestRewards(65) == nil)
        end
    end
end)
check("Missing optional fields remain absent and false usability is preserved", function()
    fixed[2], fixed[4], fixed[5] = nil, nil, nil
    local r = addon.QuestRewards(65)
    assert(r.items[1].texture == nil and r.items[1].quality == nil and r.items[1].usable == nil)
    assert(r.choices[1].usable == true)
end)
check("Unknown restricted negative and failed money remain absent while zero is real", function()
    for _, value in ipairs({ -1, math.huge, 0 / 0, secret }) do
        money = value; assert(addon.QuestRewards(65).money == nil)
    end
    money = 0; assert(addon.QuestRewards(65).money == 0)
    GetQuestLogRewardMoney = function() error("money unavailable") end
    assert(addon.QuestRewards(65).money == nil)
end)
check("Rewards are fresh across changes and locale switches with detached snapshots", function()
    local old = addon.QuestRewards(65)
    fixed = { "Награда", 456, 3, 2, true, 7002 }
    GetLocale = function() return "ruRU" end
    local fresh = addon.QuestRewards(65)
    assert(fresh.items[1].name == "Награда" and fresh.items[1].id == 7002)
    assert(old.items[1].name == "Reward" and old.items[1].id == 7001)
    fresh.items[1].name = "Changed"; assert(addon.QuestRewards(65).items[1].name == "Награда")
end)
check("Selection changes during reads invalidate the snapshot without rewrites", function()
    GetQuestLogRewardInfo = function() selected = 66; return unpack(fixed, 1, 6) end
    assert(addon.QuestRewards(65) == nil)
    reset(); GetQuestLogRewardMoney = function() selected = 66; return 25 end
    assert(addon.QuestRewards(65) == nil)
end)
issecretvalue = nil
print("Quest reward adapter modeled checks passed: " .. total .. " (native client unverified)")
