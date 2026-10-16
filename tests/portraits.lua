local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local secret, selected, index, display, name, calls, writes = {}, nil, nil, nil, nil, 0, 0
local function reset()
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
check("Player sentinel zero restricted and malformed display IDs produce no portrait", function()
    for _, value in ipairs({ -1, 0, -22, 1.5, false, "12345", math.huge, 0 / 0, secret }) do
        display = value; assert(addon.QuestPortrait(95036) == nil)
    end
    display = nil; assert(addon.QuestPortrait(95036) == nil)
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
issecretvalue = nil
print("Quest portrait adapter modeled checks passed: " .. total .. " (native client unverified)")
