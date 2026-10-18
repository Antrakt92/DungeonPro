local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Planner.lua"))("DungeonPro", addon)
assert(loadfile("Core/QuestTree.lua"))("DungeonPro", addon)
assert(loadfile("Core/QuestRowInfo.lua"))("DungeonPro", addon)
assert(loadfile("Core/DungeonStatus.lua"))("DungeonPro", addon)
local function check(name, callback)
    issecretvalue = function() return false end
    local ok, message = pcall(callback)
    assert(ok, name .. ": " .. tostring(message))
    total = total + 1; print("PASS " .. name)
end
check("Tree proof rejects earlier source mutation caused by its final state sanitizer", function()
    local quests = { [1] = { requires = { { ids = { 2 } } } }, [2] = {}, [3] = {} }
    local engine = { quests = quests }
    function engine:Current() return true end
    function engine:State(id) return { status = "AVAILABLE", reason = id == 1 and "root-last-reason" or "child-reason", completedHistory = false } end
    local tree
    local mutate = false
    local checker = function(value)
        if mutate and value == "root-last-reason" then quests[1].requires[1].ids[1] = 3 end
        return false
    end
    -- Build against the same capability identity used by the retained proof.
    issecretvalue = checker
    tree = assert(addon.QuestTree.Build(quests, engine, 1))
    mutate = true
    assert(not tree.current(), "late sanitizer mutation left an obsolete route current")
end)
check("Row metadata proof rejects an earlier faction mutation from its final source sanitizer", function()
    local quests = { [1] = { factions = { "Alliance" }, storyline = { 1, 2 } }, [2] = {} }
    local mutate = false
    issecretvalue = function(value)
        if mutate and value == quests[2] then quests[1].factions[1] = "Horde" end
        return false
    end
    local info, current = addon.QuestRowInfo.Get(quests, 1)
    assert(info and info.faction == "Alliance" and info.chain)
    mutate = true
    assert(not current(), "late sanitizer mutation left obsolete faction metadata current")
end)
check("Dungeon status proof rejects earlier definition mutation from its state sanitizer", function()
    local definition = { minLevel = 1, requirementsKnown = true }
    local state = { status = "AVAILABLE", reason = "aggregate-last-reason", completedHistory = false }
    local engine = { quests = { [1] = definition }, context = { level = 20 }, states = { [1] = state } }
    function engine:Current() return true end
    function engine:State() return state end
    local mutate = false
    issecretvalue = function(value)
        if mutate and value == "aggregate-last-reason" then definition.minLevel = 60 end
        return false
    end
    local status, current = addon.DungeonStatus.Get({ quests = { 1 } }, engine)
    assert(status and status.status == "AVAILABLE")
    mutate = true
    assert(not current(), "late sanitizer mutation left obsolete aggregate status current")
end)
check("Retained graph and aggregate proofs expire when their own provider changes", function()
    local quests = { [1] = { minLevel = 1, requirementsKnown = true } }
    local engine = addon.Planner.New(quests, { level = 20,
        completed = function() return false end, active = function() return false end })
    local tree = assert(addon.QuestTree.Build(quests, engine, 1))
    local dto, current = addon.DungeonStatus.Get({ quests = { 1 } }, engine)
    assert(dto and current())
    local build, get = addon.QuestTree.Build, addon.DungeonStatus.Get
    addon.QuestTree.Build = function() error("replacement must not run") end
    addon.DungeonStatus.Get = function() error("replacement must not run") end
    assert(not tree.current() and not current(), "old model proof survived its replaced provider")
    addon.QuestTree.Build, addon.DungeonStatus.Get = build, get
end)
print("Model snapshot ownership: " .. total .. " checks passed")
