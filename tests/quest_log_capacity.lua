local addon, total, secret = {}, 0, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local shown, count, capacity, reads
local function reset()
    shown, count, capacity, reads = 12, 7, 40, 0
    issecretvalue = function(value) return value == secret end
    C_QuestLog = {
        GetNumQuestLogEntries = function(...) assert(select("#", ...) == 0); reads = reads + 1; return shown, count end,
        GetMaxNumQuestsCanAccept = function(...) assert(select("#", ...) == 0); return capacity end,
        GetMaxNumQuests = function() error("hidden-inclusive capacity forbidden") end,
        SetSelectedQuest = function() error("selection forbidden") end,
        RequestLoadQuestByID = function() error("request forbidden") end,
    }
    Constants = { QuestLogConsts = { MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT = 25 } }
    MAX_QUESTLOG_QUESTS = 999
    C_Timer = { After = function() error("timers forbidden") end }
end
local function check(name, callback)
    reset(); local ok, err = pcall(callback)
    assert(ok, name .. ": " .. tostring(err)); total = total + 1; print("PASS " .. name)
end
check("Standard occupancy uses second tuple and standard getter with no arguments", function()
    local result = addon.QuestLogCapacity()
    assert(result.count == 7 and result.capacity == 40 and reads == 1)
    assert(addon.db == nil and addon.char == nil)
end)
check("Empty logs collapsed headers and over-cap counts remain truthful", function()
    count = 0; local result = addon.QuestLogCapacity(); assert(result.count == 0 and result.capacity == 40)
    shown, count = 1, 7; result = addon.QuestLogCapacity(); assert(result.count == 7)
    shown, count = 100, 41; result = addon.QuestLogCapacity(); assert(result.count == 41 and result.capacity == 40)
    shown = secret; result = addon.QuestLogCapacity(); assert(result.count == 41)
    shown = nil; assert(addon.QuestLogCapacity().count == 41)
end)
check("Only an absent standard getter permits the exact native constant fallback", function()
    C_QuestLog.GetMaxNumQuestsCanAccept = nil
    assert(addon.QuestLogCapacity().capacity == 25)
    Constants.QuestLogConsts.MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT = 60
    assert(addon.QuestLogCapacity().capacity == 60)
    Constants = nil; assert(addon.QuestLogCapacity() == nil)
    assert(MAX_QUESTLOG_QUESTS == 999)
end)
check("Present throwing malformed or restricted standard getter never falls through to constants", function()
    for _, value in ipairs({ false, 40, "missing", secret }) do
        C_QuestLog.GetMaxNumQuestsCanAccept = value; assert(addon.QuestLogCapacity() == nil)
    end
    C_QuestLog.GetMaxNumQuestsCanAccept = function() error("unavailable") end
    assert(addon.QuestLogCapacity() == nil)
    C_QuestLog.GetMaxNumQuestsCanAccept = function() return nil end
    assert(addon.QuestLogCapacity() == nil)
end)
check("Missing entry API and unknown counts never become an empty log", function()
    C_QuestLog = nil; assert(addon.QuestLogCapacity() == nil)
    C_QuestLog = {}; assert(addon.QuestLogCapacity() == nil)
    reset(); C_QuestLog.GetNumQuestLogEntries = function() error("unavailable") end
    assert(addon.QuestLogCapacity() == nil)
    reset(); count = nil; assert(addon.QuestLogCapacity() == nil)
end)
check("Used count and capacity reject restricted fractional negative and nonfinite values", function()
    for _, value in ipairs({ false, "7", secret, -1, 1.5, math.huge, -math.huge, 0 / 0 }) do
        reset(); count = value; assert(addon.QuestLogCapacity() == nil)
        reset(); capacity = value; assert(addon.QuestLogCapacity() == nil)
    end
    reset(); capacity = 0; assert(addon.QuestLogCapacity() == nil)
    reset(); capacity = nil; assert(addon.QuestLogCapacity() == nil)
    reset(); issecretvalue = function() error("restricted checker") end
    assert(addon.QuestLogCapacity() == nil)
end)
check("Native constant fallback rejects malformed nested libraries and values", function()
    C_QuestLog.GetMaxNumQuestsCanAccept = nil
    for _, value in ipairs({ false, "40", secret, 0, -1, 1.5, math.huge, 0 / 0 }) do
        Constants.QuestLogConsts.MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT = value
        assert(addon.QuestLogCapacity() == nil)
    end
    Constants.QuestLogConsts = nil; assert(addon.QuestLogCapacity() == nil)
    Constants = false; assert(addon.QuestLogCapacity() == nil)
end)
check("Namespace and getter identity changes discard mixed snapshots", function()
    C_QuestLog.GetNumQuestLogEntries = function() C_QuestLog = {}; return 12, 7 end
    assert(addon.QuestLogCapacity() == nil)
    reset(); C_QuestLog.GetNumQuestLogEntries = function()
        C_QuestLog.GetMaxNumQuestsCanAccept = function() return 60 end; return 12, 7
    end
    assert(addon.QuestLogCapacity() == nil)
    reset(); C_QuestLog.GetMaxNumQuestsCanAccept = function()
        C_QuestLog.GetNumQuestLogEntries = function() return 1, 1 end; return 40
    end
    assert(addon.QuestLogCapacity() == nil)
    reset(); C_QuestLog.GetNumQuestLogEntries = function()
        issecretvalue = function() return false end; return 12, 7
    end
    assert(addon.QuestLogCapacity() == nil)
end)
check("Fallback native tables and capacity changes during count reads invalidate snapshot", function()
    for mode = 1, 4 do
        reset(); C_QuestLog.GetMaxNumQuestsCanAccept = nil
        C_QuestLog.GetNumQuestLogEntries = function()
            if mode == 1 then Constants = { QuestLogConsts = { MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT = 25 } }
            elseif mode == 2 then Constants.QuestLogConsts = { MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT = 25 }
            elseif mode == 3 then Constants.QuestLogConsts.MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT = 26
            else C_QuestLog.GetMaxNumQuestsCanAccept = function() return 40 end end
            return 12, 7
        end
        assert(addon.QuestLogCapacity() == nil)
    end
end)
check("Fresh detached snapshots do not cache capacity or alter quest policy", function()
    addon.quests = { [65] = { id = 65, minLevel = 1, requirementsKnown = false } }
    assert(loadfile("Core/Planner.lua"))("DungeonPro", addon)
    local context = { level = 60, active = function() return false end, completed = function() return false end }
    local first = addon.QuestLogCapacity(); first.count = 900
    count, capacity = 0, 60
    local next = addon.QuestLogCapacity(); assert(next.count == 0 and next.capacity == 60 and reads == 2)
    local engine = addon.Planner.New(addon.quests, context)
    local actions, uncertain = engine:Next(65)
    assert(engine:State(65).status == "UNKNOWN" and #actions == 0 and uncertain)
    assert(addon.quests[65].requirementsKnown == false)
end)
issecretvalue = nil
print("Quest log capacity checks passed: " .. total .. " (native client unverified)")
