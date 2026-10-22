local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local secret, selected, index, display, name, calls, writes = {}, nil, nil, nil, nil, 0, 0
local function reset()
    GetLocale = function() return "enUS" end
    selected, index, display, name, calls, writes = 95036, 7, 12345, "Native Portrait", 0, 0
    issecretvalue = function(v) return v == secret end
    C_QuestLog = {
        GetSelectedQuest = function() return selected end,
        GetLogIndexForQuestID = function(id) assert(id == 95036); return index end,
        GetQuestLogPortraitGiver = function(logIndex, ...)
            calls = calls + 1
            assert(logIndex == 7 and select("#", ...) == 0, "expected explicit log index, not quest ID")
            return display, "Portrait narrative", name, 888, 999
        end,
        SetSelectedQuest = function() writes = writes + 1; error("selection writes forbidden") end,
    }
end
local function check(label, fn)
    reset()
    local ok, err = pcall(fn)
    if not ok then error(label .. ": " .. tostring(err), 0) end
    assert(writes == 0, "quest selection changed")
    total = total + 1; print("PASS " .. label)
end
check("Portrait uses explicit log index and exact first and third tuple fields", function()
    local p = addon.QuestPortrait(95036)
    assert(calls == 1 and p.displayID == 12345 and p.name == "Native Portrait")
    assert(p.id == nil and p.npcID == nil and p.questID == nil and p.mount == nil and p.text == nil)
end)
check("Another selected quest and missing APIs never read an unrelated portrait", function()
    selected = 95042; assert(addon.QuestPortrait(95036) == nil and calls == 0)
    reset(); C_QuestLog.GetQuestLogPortraitGiver = nil; assert(addon.QuestPortrait(95036) == nil)
    C_QuestLog = nil; assert(addon.QuestPortrait(95036) == nil)
end)
check("Invalid quest IDs and absent or invalid log indexes never reach the reader", function()
    for _, value in ipairs({ 0, -1, 1.5, "95036", math.huge, 0 / 0, secret }) do
        assert(addon.QuestPortrait(value) == nil and calls == 0)
    end
    assert(addon.QuestPortrait(nil) == nil)
    for _, value in ipairs({ 0, -1, 1.5, "7", math.huge, 0 / 0, secret }) do
        index = value; assert(addon.QuestPortrait(95036) == nil and calls == 0)
    end
    index = nil; assert(addon.QuestPortrait(95036) == nil and calls == 0)
end)
check("Negative restricted and malformed display IDs produce no portrait", function()
    for _, value in ipairs({ -1, -22, 1.5, false, "12345", math.huge, 0 / 0, secret }) do
        display = value; assert(addon.QuestPortrait(95036) == nil)
    end
    display = nil; assert(addon.QuestPortrait(95036) == nil)
end)
check("Precision-collapsed and over-wide display IDs are unknown while uint32 max stays valid", function()
    display = 4294967295
    local p = addon.QuestPortrait(95036)
    assert(p and p.displayID == 4294967295, "uint32 max display stays accepted")
    display = 4294967296; assert(addon.QuestPortrait(95036) == nil)
    display = 9007199254740992; assert(addon.QuestPortrait(95036) == nil)
    display = 9007199254740993; assert(addon.QuestPortrait(95036) == nil)
end)
check("Native zero portrait is an explicit hidden instruction", function()
    display = 0
    local p = addon.QuestPortrait(95036)
    assert(calls == 1 and p.hidden == true and p.displayID == nil and p.name == nil and p.source == nil)
end)
check("Missing tuple and native selection index or portrait errors remain unknown", function()
    C_QuestLog.GetQuestLogPortraitGiver = function() end
    assert(addon.QuestPortrait(95036) == nil)
    reset(); C_QuestLog.GetQuestLogPortraitGiver = function() error("portrait unavailable") end
    assert(addon.QuestPortrait(95036) == nil)
    reset(); C_QuestLog.GetSelectedQuest = function() error("selection unavailable") end
    assert(addon.QuestPortrait(95036) == nil and calls == 0)
    reset(); C_QuestLog.GetLogIndexForQuestID = function() error("log unavailable") end
    assert(addon.QuestPortrait(95036) == nil and calls == 0)
end)
check("Optional restricted or oversized name is omitted without rejecting a clean display", function()
    for _, value in ipairs({ secret, false, 55, "", string.rep("N", 1025) }) do
        name = value
        local p = addon.QuestPortrait(95036)
        assert(p.displayID == 12345 and p.name == nil)
    end
    name = nil; assert(addon.QuestPortrait(95036).name == nil)
    name = string.rep("N", 1024); assert(addon.QuestPortrait(95036).name == name)
end)
check("Unused secret text mount and model scene fields are never inspected or returned", function()
    C_QuestLog.GetQuestLogPortraitGiver = function(logIndex)
        assert(logIndex == 7)
        return 12345, secret, "Native Name", secret, secret
    end
    local p = addon.QuestPortrait(95036)
    assert(p.displayID == 12345 and p.name == "Native Name")
end)
check("Selection and log-index changes during the read invalidate the result", function()
    C_QuestLog.GetQuestLogPortraitGiver = function() selected = 95042; return 12345, "", "Other" end
    assert(addon.QuestPortrait(95036) == nil)
    reset(); C_QuestLog.GetQuestLogPortraitGiver = function() index = 8; return 12345, "", "Reordered" end
    assert(addon.QuestPortrait(95036) == nil)
    reset(); C_QuestLog.GetQuestLogPortraitGiver = function() index = nil; return 12345, "", "Removed" end
    assert(addon.QuestPortrait(95036) == nil)
end)
check("Restricted selection and changed ownership never recover from prior results", function()
    assert(addon.QuestPortrait(95036))
    selected = secret; assert(addon.QuestPortrait(95036) == nil)
    selected = 95042; assert(addon.QuestPortrait(95036) == nil)
end)
check("Fresh localized portrait names do not mutate or reuse earlier snapshots", function()
    local old = addon.QuestPortrait(95036)
    display, name = 54321, "Портрет из журнала"
    GetLocale = function() return "ruRU" end
    local fresh = addon.QuestPortrait(95036)
    assert(old.displayID == 12345 and old.name == "Native Portrait")
    assert(fresh.displayID == 54321 and fresh.name == "Портрет из журнала")
    fresh.name = "Changed"; assert(addon.QuestPortrait(95036).name == "Портрет из журнала")
end)
check("A replaced quest-log namespace cannot publish the previous selection portrait", function()
    C_QuestLog.GetQuestLogPortraitGiver = function(logIndex)
        assert(logIndex == 7)
        C_QuestLog = { GetSelectedQuest = function() return 95042 end,
            GetLogIndexForQuestID = function() return 8 end }
        return 12345, "", "Previous portrait"
    end
    assert(addon.QuestPortrait(95036) == nil)
end)
check("Portrait hydration rejects same-ID getter locale character and checker changes", function()
    local character, localeGetter = addon.char, GetLocale
    for _, mutation in ipairs({ "getter", "selectedGetter", "indexGetter", "locale", "localeGetter", "character", "checker" }) do
        reset()
        local locale = "enUS"
        GetLocale = function() return locale end
        addon.char = {}
        C_QuestLog.GetQuestLogPortraitGiver = function()
            if mutation == "getter" then C_QuestLog.GetQuestLogPortraitGiver = function() return 54321 end
            elseif mutation == "selectedGetter" then C_QuestLog.GetSelectedQuest = function() return 95036 end
            elseif mutation == "indexGetter" then C_QuestLog.GetLogIndexForQuestID = function() return 7 end
            elseif mutation == "locale" then locale = "ruRU"
            elseif mutation == "localeGetter" then GetLocale = function() return "enUS" end
            elseif mutation == "character" then addon.char = {}
            else issecretvalue = function(value) return value == secret end end
            return 12345, "", "Old ownership"
        end
        assert(addon.QuestPortrait(95036) == nil, mutation)
    end
    addon.char, GetLocale = character, localeGetter
end)
check("Malformed portrait namespaces never reach a selected reader", function()
    for _, namespace in ipairs({ false, true, 1, "namespace", secret }) do
        C_QuestLog = namespace
        assert(addon.QuestPortrait(95036) == nil and calls == 0)
    end
end)
check("Oversized item IDs never reach the native name getter", function()
    local calls = 0
    C_Item = { GetItemNameByID = function(id) calls = calls + 1; return "Native Item" end,
        IsItemDataCachedByID = function() return true end,
        RequestLoadItemDataByID = function() end }
    assert(addon.ItemName(4294967295) == "Native Item" and calls == 1)
    for _, id in ipairs({ 4294967296, 2 ^ 40 }) do
        calls = 0
        assert(addon.ItemName(id) == nil and calls == 0, "huge item ID reached the native name getter")
    end
end)
check("Oversized carried item IDs never reach the native bag count", function()
    local calls = 0
    addon.quests = { [1] = { objectiveItems = { { itemID = 4294967295 } } },
        [2] = { objectiveItems = { { itemID = 2 ^ 40 } } } }
    C_Item = { GetItemCount = function(id) calls = calls + 1; return 3 end }
    assert(addon.CarriedItemCount(4294967295) == 3 and calls == 1)
    calls = 0
    assert(addon.CarriedItemCount(2 ^ 40) == nil and calls == 0, "huge item ID reached the native bag count")
end)
check("Oversized selected-log reward item IDs fail the snapshot closed", function()
    C_QuestLog = { GetSelectedQuest = function() return 65 end,
        GetLogIndexForQuestID = function(id) assert(id == 65); return 1 end }
    GetNumQuestLogRewards = function() return 1 end
    GetNumQuestLogChoices = function() return 0 end
    GetQuestLogRewardMoney = function() return 0 end
    GetQuestLogChoiceInfo = function() error("no choices expected") end
    GetQuestLogRewardInfo = function(index) return "Reward", 123, 1, 2, true, 2 ^ 40 end
    assert(addon.QuestRewards(65) == nil)
    GetQuestLogRewardInfo = function(index) return "Reward", 123, 1, 2, true, 4294967295 end
    local r = addon.QuestRewards(65)
    assert(r and r.items[1].id == 4294967295)
end)
check("Oversized cached reward item IDs fail the snapshot closed", function()
    addon.quests = { [65] = { id = 65 } }
    HaveQuestRewardData = function(id) assert(id == 65); return true end
    GetNumQuestLogRewards = function(id) assert(id == 65); return 1 end
    GetNumQuestLogChoices = function(id) assert(id == 65); return 0 end
    GetQuestLogRewardInfo = function(index, id) return "Reward", 123, 1, 2, true, 2 ^ 40 end
    GetQuestLogChoiceInfo = nil
    assert(addon.CachedQuestRewards(65) == nil)
    GetQuestLogRewardInfo = function(index, id) return "Reward", 123, 1, 2, true, 4294967295 end
    local r = addon.CachedQuestRewards(65)
    assert(r and r.items[1].id == 4294967295)
end)
issecretvalue = nil
print("Quest portrait adapter modeled checks passed: " .. total .. " (native client unverified)")
