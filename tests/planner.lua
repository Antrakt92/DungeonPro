local addon = {}
assert(loadfile("Core/Namespace.lua"))("DungeonPrep", addon)
assert(loadfile("Core/Planner.lua"))("DungeonPrep", addon)
assert(loadfile("Database/Catalog.lua"))("DungeonPrep", addon)
local P, passed = addon.Planner, 0
local function check(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name .. ": " .. tostring(err), 0) end
    passed = passed + 1
    print("PASS " .. name)
end
local function eq(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function ctx(done, active)
    done, active = done or {}, active or {}
    return { level = 20, faction = "Alliance", class = "MAGE", race = 3,
        completed = function(id) return done[id] or false end,
        active = function(id) return active[id] or false end, ready = function() return false end }
end
local function q(id, parents, extra)
    local result = { id = id, minLevel = 1, requirementsKnown = true, requires = parents }
    for k, v in pairs(extra or {}) do result[k] = v end
    return result
end
check("VanCleef resolves to the actual beginning, not the locked penultimate quest", function()
    local engine = P.New(addon.quests, ctx())
    eq(engine:State(166).status, "LOCKED")
    local actions, unknown = engine:Next(166)
    eq(#actions, 1); eq(actions[1].id, 65); eq(actions[1].kind, "pickup"); eq(unknown, false)
end)
check("Chain resumes after completed steps", function()
    local actions = P.New(addon.quests, ctx({ [65] = true, [132] = true })):Next(166)
    eq(actions[1].id, 135)
end)
check("Active prerequisite must be finished before the child can be picked up", function()
    local engine = P.New(addon.quests, ctx({}, { [65] = true }))
    local actions = engine:Next(166)
    eq(actions[1].id, 65); eq(actions[1].kind, "complete")
end)
check("Ready prerequisite directs to turn-in", function()
    local c = ctx({}, { [65] = true }); c.ready = function() return true end
    local actions = P.New(addon.quests, c):Next(166)
    eq(actions[1].kind, "turnin")
end)
check("Unfinished objectives do not guide to the turn-in NPC", function()
    local place = { mapID = 1436, x = 56.3, y = 47.5 }
    local quests = { [1] = q(1, nil, { finish = place }) }
    local c = ctx({}, { [1] = true })
    local actions = P.New(quests, c):Next(1)
    eq(actions[1].kind, "complete"); eq(actions[1].place, nil)
    c.ready = function() return true end
    actions = P.New(quests, c):Next(1)
    eq(actions[1].kind, "turnin"); eq(actions[1].place, place)
end)
check("Missing requirements evidence is never available", function()
    eq(P.New(addon.quests, ctx()):State(92753).status, "UNKNOWN")
end)
check("Wailing Caverns source expansion stays partial and retains narrative steps", function()
    local dungeon
    for _, d in ipairs(addon.dungeons) do if d.key == "wc" then dungeon = d end end
    assert(dungeon and #dungeon.quests == 7)
    local c = ctx(); c.faction, c.race = "Horde", 2
    local e = P.New(addon.quests, c)
    local plan = e:Dungeon(dungeon)
    eq(plan.ready, false); eq(plan.unknown, true)
    eq(e:State(914).status, "UNKNOWN")
    eq(addon.quests[914].storyline[1], 1489)
    eq(addon.quests[914].storyline[2], 1490)
    eq(addon.quests[914].requires[1].ids[1], 1490)
    eq(addon.quests[1489].requires[1].ids[1], 880)
    local partial = ctx({ [870] = true, [877] = true, [880] = true, [1489] = true, [1490] = true })
    partial.faction, partial.race = "Horde", 2
    eq(P.New(addon.quests, partial):State(914).status, "UNKNOWN")
    local actions, unknown = P.New(addon.quests, partial):Next(914)
    eq(#actions, 0); eq(unknown, true)
    c.active = function(id) return id == 914 end
    eq(P.New(addon.quests, c):State(914).status, "ACTIVE")
end)
check("Story order is not silently treated as prerequisite evidence", function()
    local engine = P.New(addon.quests, ctx({ [92752] = true }))
    local actions, unknown = engine:Next(92753)
    eq(#actions, 0); eq(unknown, true)
end)
check("Quest already in log overrides incomplete catalogue requirements", function()
    eq(P.New(addon.quests, ctx({}, { [92753] = true })):State(92753).status, "ACTIVE")
end)
check("Faction restrictions remove quests from the dungeon totals", function()
    local d = { quests = { 5728 }, coverage = "reviewed" }
    eq(#P.New(addon.quests, ctx()):Dungeon(d).rows, 0)
end)
check("Current active and ready dungeon targets survive stale catalog character exclusions", function()
    for _, restriction in ipairs({ { factions = { "Horde" } }, { classes = { "WARRIOR" } }, { races = { 1 } } }) do
        for _, ready in ipairs({ false, true }) do
            local finish = { npcID = 123, mapID = 1, x = 10, y = 20 }
            restriction.requirementsKnown, restriction.finish = false, finish
            local quests = { [1] = q(1, nil, restriction), [2] = q(2, nil, { classes = { "WARRIOR" } }),
                [3] = q(3, nil, { factions = { "Horde" } }), [4] = q(4) }
            local c = ctx({ [3] = true }, { [1] = true, [4] = true })
            c.ready = function(id) return id == 1 and ready end
            local engine = P.New(quests, c)
            eq(P.Eligible(quests[1], c), false)
            eq(engine:State(1).status, ready and "READY" or "ACTIVE")
            local dungeon = { quests = { 1, 2, 3 }, coverage = "reviewed" }
            local plan = engine:Dungeon(dungeon)
            eq(#plan.rows, 1); eq(plan.rows[1].id, 1)
            eq(plan.counts[ready and "READY" or "ACTIVE"], 1)
            eq(#plan.actions, 1); eq(plan.actions[1].id, 1)
            eq(plan.actions[1].kind, ready and "turnin" or "complete")
            eq(plan.actions[1].place, ready and finish or nil)
            eq(plan.ready, true); eq(plan.unknown, false)
            local inspection = engine:Dungeon(dungeon, { includeUnavailable = true })
            eq(#inspection.rows, 3); eq(#inspection.actions, 1)
            eq(inspection.actions[1].id, 1); eq(inspection.ready, plan.ready); eq(inspection.unknown, plan.unknown)
            eq(quests[1].requirementsKnown, false)
        end
    end
end)
check("Completed history unknown activity and readiness alone never override character exclusions", function()
    local quests = { [1] = q(1, nil, { factions = { "Horde" } }),
        [2] = q(2, nil, { classes = { "WARRIOR" } }), [3] = q(3, nil, { races = { 1 } }) }
    local c = ctx({ [1] = true })
    c.active = function(id) if id == 3 then return false end end
    c.ready = function() return true end
    local engine = P.New(quests, c)
    eq(engine:State(1).status, "COMPLETED")
    eq(engine:State(2).status, "UNAVAILABLE"); eq(engine:State(3).status, "UNAVAILABLE")
    local dungeon = { quests = { 1, 2, 3 }, coverage = "reviewed" }
    for _, options in ipairs({ {}, { includeUnavailable = true } }) do
        local plan = engine:Dungeon(dungeon, options)
        eq(#plan.rows, options.includeUnavailable and 3 or 0)
        eq(#plan.actions, 0); eq(plan.ready, false); eq(plan.unknown, false)
    end
end)
check("All-character inspection retains unavailable rows without changing readiness", function()
    local quests = { [1] = q(1), [2] = q(2, nil, { factions = { "Horde" }, requirementsKnown = false }) }
    local e = P.New(quests, ctx({}, { [1] = true }))
    local d = { quests = { 1, 2 }, coverage = "reviewed" }
    local filtered = e:Dungeon(d)
    local all = e:Dungeon(d, { includeUnavailable = true })
    eq(#filtered.rows, 1); eq(#all.rows, 2)
    eq(all.rows[2].state.status, "UNAVAILABLE")
    eq(all.ready, true); eq(all.unknown, false)
    eq(#all.actions, #filtered.actions)
    eq(e:Dungeon({ quests = { 2 }, coverage = "reviewed" }, { includeUnavailable = true }).ready, false)
end)
check("Forever race IDs are not truncated to a classic eight-bit mask", function()
    local c = ctx(); c.race = 95
    eq(P.Eligible(addon.quests[96393], c), true)
    c.race = 1; eq(P.Eligible(addon.quests[96393], c), false)
end)
check("A known class exclusion wins even when faction information is missing", function()
    local c = ctx(); c.faction = nil
    local quest = q(1, nil, { factions = { "Horde" }, classes = { "WARLOCK" } })
    local eligible, reason = P.Eligible(quest, c)
    eq(eligible, false); eq(reason, "class")
    local e = P.New({ [1] = quest }, c)
    eq(e:State(1).status, "UNAVAILABLE")
    local d = { coverage = "reviewed", quests = { 1 } }
    eq(#e:Dungeon(d).rows, 0)
    eq(e:Dungeon(d, { includeUnavailable = true }).rows[1].state.reason, "class")
end)
check("A known race exclusion wins over unknown class and faction", function()
    local c = ctx(); c.faction, c.class = nil, nil
    local eligible, reason = P.Eligible(q(1, nil, {
        factions = { "Alliance" }, classes = { "MAGE" }, races = { 1 },
    }), c)
    eq(eligible, false); eq(reason, "race")
end)
check("Unknown restrictions remain unknown when all known restrictions match", function()
    local c = ctx(); c.faction = nil
    local eligible, reason = P.Eligible(q(1, nil, {
        factions = { "Alliance" }, classes = { "MAGE" }, races = { 3 },
    }), c)
    eq(eligible, nil); eq(reason, "faction")
end)
check("Shared dungeon class quests preserve current faction race and class gates", function()
    local c = ctx(); c.faction, c.class, c.race = "Horde", "PALADIN", 6
    local e = P.New(addon.quests, c)
    eq(e:State(95036).status, "UNKNOWN")
    eq(e:State(1654).status, "UNAVAILABLE")
    c.class = "MAGE"; eq(P.New(addon.quests, c):State(95036).status, "UNAVAILABLE")
    c.class, c.race = "PALADIN", 2; eq(P.New(addon.quests, c):State(95036).status, "UNAVAILABLE")
    c.class = "WARLOCK"; eq(P.New(addon.quests, c):State(1740).status, "UNKNOWN")
    c.faction = "Alliance"; eq(P.New(addon.quests, c):State(1740).status, "UNKNOWN")
    eq(addon.quests[1654].level, 22)
    local found = {}
    for _, d in ipairs(addon.dungeons) do
        if d.key == "dm" or d.key == "sfk" or d.key == "bfd" then
            for _, id in ipairs(d.quests) do if id == 1654 then found[d.key] = true end end
        end
    end
    assert(found.dm and found.sfk and found.bfd)
end)
check("OR branches choose an actionable alternative", function()
    local quests = { [1] = q(1, nil, { minLevel = 60 }), [2] = q(2), [3] = q(3, { { ids = { 1, 2 } } }) }
    local actions, unknown = P.New(quests, ctx()):Next(3)
    eq(actions[1].id, 2); eq(unknown, false)
end)
check("Explicit OR preference chooses its branch without changing availability", function()
    local quests = { [1] = q(1), [2] = q(2), [3] = q(3, { { ids = { 1, 2 } } }) }
    local choices = { [3] = { [1] = 2 } }
    local e = P.New(quests, ctx(), choices)
    eq(e:Next(3)[1].id, 2); eq(e:State(3).status, "LOCKED")
    choices[3][1] = nil; eq(e:Next(3)[1].id, 1)
    choices[3][1] = 999; eq(e:Next(3)[1].id, 1)
end)
check("Unavailable or malformed preferences fall back safely", function()
    local quests = { [1] = q(1), [2] = q(2, nil, { factions = { "Horde" } }),
        [3] = q(3, { { ids = { 1, 2 } } }) }
    for _, choice in ipairs({ 2, "2", false, {}, math.huge }) do
        local actions, unknown = P.New(quests, ctx(), { [3] = { choice } }):Next(3)
        eq(actions[1].id, 1); eq(unknown, false)
    end
    eq(P.New(quests, ctx(), true):Next(3)[1].id, 1)
end)
check("An unknown preferred branch remains unknown and cannot grant pickup", function()
    local quests = { [1] = q(1), [2] = q(2, nil, { requirementsKnown = false }),
        [3] = q(3, { { ids = { 1, 2 } } }) }
    local e = P.New(quests, ctx(), { [3] = { 2 } })
    local actions, unknown = e:Next(3)
    eq(#actions, 0); eq(unknown, true); eq(e:State(3).status, "UNKNOWN")
end)
check("Unavailable OR alternatives cannot hide useful partially-known work", function()
    local quests = { [1] = q(1, nil, { factions = { "Horde" } }),
        [2] = q(2, { { ids = { 4 } }, { ids = { 5 } } }),
        [3] = q(3, { { ids = { 1, 2 } } }), [4] = q(4),
        [5] = q(5, nil, { requirementsKnown = false }) }
    local actions, unknown = P.New(quests, ctx()):Next(3)
    eq(#actions, 1); eq(actions[1].id, 4); eq(unknown, true)
end)
check("AND groups collect both branches and deduplicate common ancestors", function()
    local quests = { [1] = q(1), [2] = q(2, { { ids = { 1 } } }), [3] = q(3, { { ids = { 1 } } }),
        [4] = q(4, { { ids = { 2 } }, { ids = { 3 } } }) }
    local actions = P.New(quests, ctx()):Next(4)
    eq(#actions, 1); eq(actions[1].id, 1)
end)
check("Accept-only prerequisites are distinct from completed prerequisites", function()
    local quests = { [1] = q(1), [2] = q(2, { { ids = { 1 }, mode = "active" } }) }
    eq(P.New(quests, ctx({}, { [1] = true })):State(2).status, "AVAILABLE")
end)
check("Missing parent fails closed", function()
    local e = P.New({ [2] = q(2, { { ids = { 999 } } }) }, ctx())
    eq(e:State(2).status, "UNKNOWN")
    local actions, unknown = e:Next(2); eq(#actions, 0); eq(unknown, true)
end)
check("Cycles terminate without availability", function()
    local e = P.New({ [1] = q(1, { { ids = { 2 } } }), [2] = q(2, { { ids = { 1 } } }) }, ctx())
    eq(e:State(1).status, "UNKNOWN")
end)
check("Unknown character API results do not become false history", function()
    local c = ctx(); c.completed = function() return nil end
    eq(P.New(addon.quests, c):State(65).status, "UNKNOWN")
end)
check("Partial dungeon coverage never grants ready", function()
    local c = ctx({ [65] = true })
    eq(P.New(addon.quests, c):Dungeon({ quests = { 65 }, coverage = "partial" }).ready, false)
end)
check("Prepared means held quests, not necessarily completed quests", function()
    local c = ctx({}, { [65] = true })
    eq(P.New(addon.quests, c):Dungeon({ quests = { 65 }, coverage = "reviewed" }).ready, true)
end)
check("Inside-only pickups do not require leaving the dungeon to prepare", function()
    local e = P.New({ [1] = q(1, nil, { startsInside = true }) }, ctx())
    local d = e:Dungeon({ quests = { 1 }, coverage = "reviewed" })
    eq(d.ready, true); eq(d.actions[1].kind, "inside")
end)
check("Inside quest still needs its outside prerequisite before preparation", function()
    local e = P.New({ [1] = q(1), [2] = q(2, { { ids = { 1 } } }, { startsInside = true }) }, ctx())
    local d = e:Dungeon({ quests = { 2 }, coverage = "reviewed" })
    eq(d.ready, false); eq(d.actions[1].id, 1); eq(d.actions[1].kind, "pickup")
end)
check("Returning the Lost Satchel requires the outside Ragefire chain", function()
    local c = ctx(); c.faction, c.race = "Horde", 2
    local d = P.New(addon.quests, c):Dungeon({ quests = { 5724 }, coverage = "reviewed" })
    eq(d.ready, false); eq(d.actions[1].id, 5722)
end)
check("Unknown OR alternative does not hide a safe known next step", function()
    local e = P.New({ [1] = q(1, nil, { requirementsKnown = false }), [2] = q(2),
        [3] = q(3, { { ids = { 1, 2 } } }) }, ctx())
    eq(e:State(3).status, "UNKNOWN")
    local actions, unknown = e:Next(3)
    eq(#actions, 1); eq(actions[1].id, 2); eq(unknown, false)
end)
check("Unknown AND requirement retains known work and uncertainty", function()
    local e = P.New({ [1] = q(1, nil, { requirementsKnown = false }), [2] = q(2),
        [3] = q(3, { { ids = { 1 } }, { ids = { 2 } } }) }, ctx())
    local actions, unknown = e:Next(3)
    eq(#actions, 1); eq(actions[1].id, 2); eq(unknown, true)
end)
check("Completion material quests never change acceptance availability or main actions", function()
    for _, pair in ipairs({ { 95036, 95042, 272448 }, { 1654, 1442, 7083 } }) do
        local main, related, itemID = unpack(pair)
        local quests = { [main] = q(main), [related] = q(related) }
        local c = ctx()
        local before = P.New(quests, c)
        local initial = before:Dungeon({ quests = { main }, coverage = "reviewed" })
        quests[main].completionQuests = { { id = related, itemID = itemID } }
        local e = P.New(quests, c)
        local steps = e:CompletionSteps(main)
        eq(#steps, 1); eq(steps[1].id, related); eq(steps[1].itemID, itemID)
        eq(steps[1].state.status, "AVAILABLE"); eq(steps[1].actions[1].id, related)
        eq(steps[1].actions[1].kind, "pickup"); eq(steps[1].unknown, false)
        eq(e:State(main).status, before:State(main).status)
        eq(e:Next(main)[1].id, main)
        local after = e:Dungeon({ quests = { main }, coverage = "reviewed" })
        eq(after.ready, initial.ready); eq(after.unknown, initial.unknown)
        eq(#after.actions, #initial.actions); eq(after.actions[1].id, main)
    end
end)
check("Completion quest status does not prove item ownership or main quest turn-in readiness", function()
    local quests = { [1] = q(1, nil, { completionQuests = { { id = 2, itemID = 7083 } } }), [2] = q(2) }
    local c = ctx({ [2] = true }, { [1] = true })
    local e = P.New(quests, c)
    local step = e:CompletionSteps(1)[1]
    eq(step.state.status, "COMPLETED"); eq(#step.actions, 0); eq(step.unknown, false)
    eq(step.owned, nil); eq(step.itemOwned, nil)
    eq(e:State(1).status, "ACTIVE"); eq(e:Next(1)[1].kind, "complete")
    eq(e:Dungeon({ quests = { 1 }, coverage = "reviewed" }).ready, true)
end)
check("Unavailable and unknown completion sources remain honest informational rows", function()
    local quests = { [1] = q(1, nil, { completionQuests = {
        { id = 2, itemID = 7083 }, { id = 3, itemID = 272448 },
    } }), [2] = q(2, nil, { factions = { "Horde" } }), [3] = q(3, nil, { requirementsKnown = false }) }
    local e = P.New(quests, ctx())
    local steps = e:CompletionSteps(1)
    eq(#steps, 2)
    eq(steps[1].state.status, "UNAVAILABLE"); eq(#steps[1].actions, 0); eq(steps[1].unknown, false)
    eq(steps[2].state.status, "UNKNOWN"); eq(#steps[2].actions, 0); eq(steps[2].unknown, true)
    eq(e:State(1).status, "AVAILABLE"); eq(e:Next(1)[1].id, 1)
end)
check("Completion sources reuse recursive Next results for active ready and locked quests", function()
    local place = { mapID = 1456, x = 70.4, y = 29.6 }
    local quests = { [1] = q(1, nil, { completionQuests = { { id = 2, itemID = 7083 } } }),
        [2] = q(2, { { ids = { 3 } } }), [3] = q(3, nil, { finish = place }) }
    local c = ctx({}, { [3] = true })
    local step = P.New(quests, c):CompletionSteps(1)[1]
    eq(step.state.status, "LOCKED"); eq(step.actions[1].id, 3); eq(step.actions[1].kind, "complete")
    c.ready = function() return true end
    step = P.New(quests, c):CompletionSteps(1)[1]
    eq(step.actions[1].id, 3); eq(step.actions[1].kind, "turnin"); eq(step.actions[1].place, place)
end)
check("Completion links are one-level distinct and cannot recursively traverse material cycles", function()
    local quests = {
        [1] = q(1, nil, { completionQuests = { { id = 2, itemID = 7083 }, { id = 2, itemID = 7083 } } }),
        [2] = q(2, nil, { completionQuests = { { id = 1, itemID = 272448 }, { id = 3, itemID = 123 } } }),
        [3] = q(3),
    }
    local e = P.New(quests, ctx())
    local steps = e:CompletionSteps(1)
    eq(#steps, 1); eq(steps[1].id, 2); eq(e.states[3], nil)
    eq(e:State(1).status, "AVAILABLE"); eq(e:State(2).status, "AVAILABLE")
    eq(#e:CompletionSteps(99), 0); eq(#e:CompletionSteps(0), 0)
end)
check("Runtime completion links bound malformed or excessive input without mutating catalogue", function()
    local quests = { [1] = q(1, nil, { completionQuests = {} }) }
    for i = 2, 102 do
        quests[i] = q(i)
        quests[1].completionQuests[#quests[1].completionQuests + 1] = { id = i, itemID = 7000 + i }
    end
    local e = P.New(quests, ctx())
    local steps = e:CompletionSteps(1)
    eq(#steps, 100); eq(steps[100].id, 101); eq(#quests[1].completionQuests, 101)
    steps[1].itemID = 99; eq(e:CompletionSteps(1)[1].itemID, 7002)
    quests[1].completionQuests = { false, { id = 1, itemID = 7 }, { id = "2", itemID = 7 },
        { id = 2, itemID = 0 }, { id = 3, itemID = 7003 } }
    steps = e:CompletionSteps(1)
    eq(#steps, 1); eq(steps[1].id, 3)
end)
check("Future schema is preserved", function()
    GetLocale = function() return "enUS" end
    assert(loadfile("Core/Client.lua"))("DungeonPrep", addon)
    DungeonPrepDB = { schema = 99, sentinel = {} }
    local previous = DungeonPrepDB
    eq(addon.RestoreDB(), false); eq(DungeonPrepDB, previous); eq(DungeonPrepDB.schema, 99)
end)
check("Class API exceptions become unknown restrictions", function()
    UnitClass = function() error("blocked") end
    UnitRace = function() return "Dwarf", "Dwarf", 3 end
    UnitLevel = function() return 20 end
    UnitFactionGroup = function() return "Alliance" end
    local c = addon.Context()
    eq(c.class, nil); eq(c.race, 3)
end)
check("Secret and nonfinite values cannot authorize decisions", function()
    local secret = {}; issecretvalue = function(v) return v == secret end
    eq(addon.Clean(secret, "table"), nil); eq(addon.Clean(0 / 0, "number"), nil)
    eq(addon.Clean(math.huge, "number"), nil); eq(addon.Clean(false, "boolean"), false)
end)
print("Planner checks passed: " .. passed)
