local addon, total, secret = {}, 0, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
assert(loadfile("Core/Planner.lua"))("DungeonPro", addon)
local count, calls
local function reset()
    count, calls = 3, 0
    addon.quests = {
        [65] = { id = 65, minLevel = 1, requirementsKnown = false, start = { itemID = 5791 } },
        [66] = { id = 66, minLevel = 1, requirementsKnown = false,
            completionQuests = { { id = 67, itemID = 7083 } } },
        [67] = { id = 67, minLevel = 1, requirementsKnown = false },
    }
    issecretvalue = function(value) return value == secret end
    C_Item = { GetItemCount = function(id, bank, uses, reagent, account, ...)
        assert((id == 5791 or id == 7083) and bank == false and uses == false and reagent == false and account == false)
        assert(select("#", ...) == 0); calls = calls + 1; return count
    end, RequestLoadItemDataByID = function() error("item requests forbidden") end }
    C_QuestLog = { SetSelectedQuest = function() error("selection forbidden") end,
        RequestLoadQuestByID = function() error("quest requests forbidden") end }
    C_Timer = { After = function() error("timers forbidden") end }
    GetItemCount = function() error("unverified global fallback forbidden") end
end
local function check(name, callback)
    reset(); local ok, err = pcall(callback)
    assert(ok, name .. ": " .. tostring(err)); total = total + 1; print("PASS " .. name)
end
check("Starter and material item counts use five exact explicit arguments and preserve zero", function()
    assert(addon.CarriedItemCount(5791) == 3 and addon.CarriedItemCount(7083) == 3 and calls == 2)
    count = 0; assert(addon.CarriedItemCount(5791) == 0 and calls == 3)
    assert(addon.db == nil and addon.char == nil)
end)
check("Unknown and malformed IDs never reach native count or global fallback", function()
    for _, id in ipairs({ 1, 65, 0, -1, 5791.5, false, "5791", math.huge, 0 / 0, secret }) do
        assert(addon.CarriedItemCount(id) == nil and calls == 0)
    end
    assert(addon.CarriedItemCount(nil) == nil)
    addon.quests[65].start = { npcID = 5791 }; assert(addon.CarriedItemCount(5791) == nil)
end)
check("Missing malformed and throwing native capabilities remain unknown", function()
    for _, value in ipairs({ false, 7, secret, "missing" }) do
        C_Item = value; assert(addon.CarriedItemCount(5791) == nil)
    end
    C_Item = nil; assert(addon.CarriedItemCount(5791) == nil)
    C_Item = {}; assert(addon.CarriedItemCount(5791) == nil)
    C_Item.GetItemCount = function() error("unavailable") end
    assert(addon.CarriedItemCount(5791) == nil)
end)
check("Only finite nonnegative integer native counts may become display data", function()
    for _, value in ipairs({ false, "0", {}, secret, -1, 1.5, math.huge, -math.huge, 0 / 0 }) do
        count = value; assert(addon.CarriedItemCount(5791) == nil)
    end
    count = nil; assert(addon.CarriedItemCount(5791) == nil)
    count = 1000000; assert(addon.CarriedItemCount(5791) == 1000000)
    issecretvalue = function() error("restricted checker") end
    assert(addon.CarriedItemCount(5791) == nil)
end)
check("Library getter and restriction-checker replacement during reads rejects older results", function()
    C_Item.GetItemCount = function() C_Item = { GetItemCount = function() return 99 end }; return 3 end
    assert(addon.CarriedItemCount(5791) == nil)
    reset(); C_Item.GetItemCount = function() C_Item.GetItemCount = function() return 99 end; return 3 end
    assert(addon.CarriedItemCount(5791) == nil)
    reset(); C_Item.GetItemCount = function() issecretvalue = function() return false end; return 3 end
    assert(addon.CarriedItemCount(5791) == nil)
end)
check("Catalogue replacement or removed item links cannot publish stale ownership information", function()
    C_Item.GetItemCount = function() addon.quests = {}; return 3 end
    assert(addon.CarriedItemCount(5791) == nil)
    reset(); C_Item.GetItemCount = function() addon.quests[65].start.itemID = 1; return 3 end
    assert(addon.CarriedItemCount(5791) == nil)
    reset(); C_Item.GetItemCount = function() addon.quests[66].completionQuests = {}; return 3 end
    assert(addon.CarriedItemCount(7083) == nil)
end)
check("Related item scan is bounded and restricted entries never authorize native reads", function()
    addon.quests[65].start = secret
    addon.quests[66].completionQuests = { secret, { itemID = secret } }
    assert(addon.CarriedItemCount(5791) == nil and addon.CarriedItemCount(7083) == nil and calls == 0)
    local links = {}
    for index = 1, 100 do links[index] = { itemID = index == 100 and 7083 or 1 } end
    addon.quests[66].completionQuests = links
    assert(addon.CarriedItemCount(7083) == 3)
    links[100].itemID = 1; links[101] = { itemID = 7083 }
    assert(addon.CarriedItemCount(7083) == nil)
end)
check("Counts reread live data without changing quest state actions or catalogue facts", function()
    local context = { level = 60, active = function() return false end, completed = function() return false end }
    local dungeon = { coverage = "reviewed", quests = { 65, 66 } }
    local before = addon.Planner.New(addon.quests, context)
    assert(before:State(65).status == "UNKNOWN" and not before:Dungeon(dungeon).ready)
    for _, value in ipairs({ 0, 1, 7, 2 }) do
        count = value; assert(addon.CarriedItemCount(5791) == value)
        local after = addon.Planner.New(addon.quests, context)
        local actions, unknown = after:Next(65)
        assert(after:State(65).status == "UNKNOWN" and #actions == 0 and unknown and not after:Dungeon(dungeon).ready)
    end
    assert(calls == 4 and addon.quests[65].start.itemID == 5791 and addon.quests[65].requirementsKnown == false)
end)
issecretvalue = nil
print("Carried item count checks passed: " .. total .. " (native client unverified)")
