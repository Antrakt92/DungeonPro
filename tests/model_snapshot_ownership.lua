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
check("Tree retained proofs own every validated array length", function()
    local cases = {
        { "requires", function(list) return { requires = list } end, { ids = { 2 } }, { ids = { 4 } } },
        { "members", function(list) return { requires = { { ids = list } } } end, 2, 4 },
        { "storyline", function(list) return { storyline = list } end, 2, 4 },
        { "story groups", function(list) return { storylineGroups = list } end, { 2 }, { 4 } },
        { "story members", function(list) return { storylineGroups = { list } } end, 2, 4 },
    }
    for _, case in ipairs(cases) do
        for _, late in ipairs({ false, true }) do
            -- Allocated slots make # change deterministically without touching the old sentinel.
            local list = { case[3], nil, nil, nil }
            local quests = { [1] = case[2](list), [2] = {}, [4] = {} }
            local engine, mutate = { quests = quests }, false
            function engine:Current() return true end
            function engine:State() return { status = "AVAILABLE", reason = "array-tail" } end
            issecretvalue = function(value)
                if mutate and value == "array-tail" then list[4] = case[4] end
                return false
            end
            local tree = assert(addon.QuestTree.Build(quests, engine, 1))
            assert(#list == 1 and tree.current())
            list[1] = case[3]; assert(tree.current(), "unchanged dense source must remain current")
            if late then mutate = true else list[4] = case[4] end
            assert(not tree.current(), case[1] .. " sparse bound drift survived")
            mutate = false
            assert(#list == 4 and addon.QuestTree.Build(quests, engine, 1) == nil)
        end
    end
end)
check("Aggregate retained proofs own prerequisite and restriction array bounds", function()
    for _, kind in ipairs({ "groups", "members", "factions", "classes" }) do
        for _, late in ipairs({ false, true }) do
            local restriction = kind == "factions" or kind == "classes"
            local first = kind == "groups" and { ids = { 2 } } or kind == "factions" and "Alliance" or kind == "classes" and "MAGE" or 2
            local list
            if restriction then
                list = assert(loadstring("return {true," .. string.rep("nil,", 255) .. "}"))()
                list[1] = first
            else list = { first, nil, nil, nil } end
            local definition = { minLevel = 1, requirementsKnown = true }
            if restriction then definition[kind] = list
            else definition.requires = kind == "groups" and list or { { ids = list } } end
            local quests = { [1] = definition, [2] = {}, [4] = {} }
            local state = { status = "AVAILABLE", reason = "aggregate-array-tail" }
            local engine, mutate = { quests = quests, context = { level = 60, faction = "Alliance", class = "MAGE" } }, false
            function engine:Current() return true end
            function engine:State() return state end
            local function extend() list[restriction and 256 or 4] = restriction and first or kind == "groups" and { ids = { 4 } } or 4 end
            issecretvalue = function(value)
                if mutate and value == "aggregate-array-tail" then extend() end
                return false
            end
            local dungeon = { quests = { 1 } }
            local dto, current = addon.DungeonStatus.Get(dungeon, engine)
            assert(dto and #list == 1 and current())
            list[1] = first; assert(current(), "unchanged source must remain current")
            if late then mutate = true else extend() end
            assert(not current(), kind .. " array bound drift survived")
            mutate = false
            assert(#list == (restriction and 256 or 4) and addon.DungeonStatus.Get(dungeon, engine) == nil)
        end
    end
end)
print("Model snapshot ownership: " .. total .. " checks passed")
