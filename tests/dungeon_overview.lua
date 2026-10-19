local addon = {}
issecretvalue = function() return false end
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Planner.lua"))("DungeonPro", addon)
assert(loadfile("Database/Catalog.lua"))("DungeonPro", addon)
assert(loadfile("Core/DungeonOverview.lua"))("DungeonPro", addon)
local Overview, P, total = addon.DungeonOverview, addon.Planner, 0
local function check(name, fn)
    fn(); total = total + 1; print("PASS " .. name)
end
local function context(active, ready, done)
    return { level = 60, faction = "Alliance", class = "MAGE", current = function() return true end,
        active = function(id) return active and active[id] or false end,
        ready = function(id) return ready and ready[id] or false end,
        completed = function(id) return done and done[id] or false end }
end
local dm
for _, dungeon in ipairs(addon.dungeons) do if dungeon.key == "dm" then dm = dungeon end end
assert(dm)
local function input(dungeon, quests, ctx, all)
    local engine = P.New(quests or addon.quests, ctx or context())
    local plan = engine:Dungeon(dungeon, { includeUnavailable = all == true })
    plan.engine, plan.dungeon = engine, dungeon
    return plan, engine
end
local function get(plan, dungeon, engine, owner)
    local model, current, raw = Overview.Get(plan, dungeon, engine, owner)
    assert(model and type(current) == "function" and type(raw) == "function" and current() and raw())
    return model, current, raw
end
local function controlled(count, status)
    local quests, ids, active, ready, done = {}, {}, {}, {}, {}
    for id = 1, count do
        ids[id] = id; quests[id] = { id = id, minLevel = 1, requirementsKnown = true }
        active[id] = status == "ACTIVE" or status == "READY"
        ready[id] = status == "READY"; done[id] = status == "COMPLETED"
    end
    local dungeon = { quests = ids, coverage = "reviewed" }
    local plan, engine = input(dungeon, quests, context(active, ready, done))
    return plan, dungeon, engine
end

check("Actual Deadmines UNKNOWN targets share one known held or READY step", function()
    for _, ready in ipairs({ false, true }) do
        local plan, engine = input(dm, nil, context({ [155] = true }, ready and { [155] = true } or nil))
        local model = get(plan, dm, engine)
        assert(engine.states[166].status == "UNKNOWN" and engine.states[214].status == "UNKNOWN")
        local found = 0
        for _, step in ipairs(model.steps) do
            if step.id == 155 then
                found = found + 1; assert(step.kind == (ready and "turnin" or "complete"))
                assert(step.status == (ready and "READY" or "ACTIVE") and step.place == nil and step.rootTargetID == nil)
            end
        end
        assert(found == 1 and model.unknown and not model.knownPrepared and model.counts.UNKNOWN > 0)
        assert(model.counts.ACTIVE == 0 and model.counts.READY == 0, "support step cannot become an extra dungeon target")
    end
    local plan, engine = input(dm, nil, context(nil, nil, { [155] = true }))
    local model = get(plan, dm, engine)
    for _, step in ipairs(model.steps) do assert(step.id ~= 155) end
end)

check("Mine and All counts preserve primary membership and held class-mismatch evidence", function()
    local mine, e1 = input(dm); local all, e2 = input(dm, nil, nil, true)
    local m1, m2 = get(mine, dm, e1), get(all, dm, e2)
    assert(m1.shownRoots == 7 and m2.shownRoots == 9 and m2.counts.UNAVAILABLE == 2)
    local held, e3 = input(dm, nil, context({ [1654] = true }, { [1654] = true }))
    local model = get(held, dm, e3)
    assert(model.shownRoots == 8 and model.counts.READY == 1)
    local found = false
    for _, step in ipairs(model.steps) do if step.id == 1654 then found = true; assert(step.kind == "turnin") end end
    assert(found)
end)

check("Readiness is the existing plan result, never absence of work or UNKNOWN-count shorthand", function()
    local plan, dungeon, engine = controlled(1, "COMPLETED")
    local model = get(plan, dungeon, engine)
    assert(model.knownPrepared and not model.unknown and #model.steps == 0)
    dungeon.coverage = "partial"; plan, engine = input(dungeon, engine.quests, context(nil, nil, { [1] = true }))
    model = get(plan, dungeon, engine)
    assert(model.counts.UNKNOWN == 0 and model.unknown and not model.knownPrepared)
    local unknown, source, e = controlled(1)
    e.quests[1].requirementsKnown = false; unknown, e = input(source, e.quests)
    model = get(unknown, source, e)
    assert(#model.steps == 0 and model.counts.UNKNOWN == 1 and not model.knownPrepared)
    local empty, d0, e0 = controlled(0)
    model = get(empty, d0, e0); assert(model.shownRoots == 0 and not model.knownPrepared)
end)

check("Stable deduplication and six-step cap preserve exact remaining work", function()
    local plan, dungeon, engine = controlled(9, "READY")
    table.insert(plan.actions, 2, plan.actions[1])
    local model = get(plan, dungeon, engine)
    assert(#model.steps == 6 and model.remainingSteps == 3 and model.shownRoots == 9 and model.counts.READY == 9)
    for index, step in ipairs(model.steps) do assert(step.id == index and step.kind == "turnin") end
end)

check("Projection never invokes State Next Dungeon or native APIs", function()
    local plan, dungeon, engine = controlled(2, "ACTIVE")
    engine.State = function() error("extra State call") end
    engine.Next = function() error("extra Next call") end
    engine.Dungeon = function() error("extra Dungeon call") end
    C_QuestLog = setmetatable({}, { __index = function() error("native hydration") end })
    local model = get(plan, dungeon, engine)
    assert(model.counts.ACTIVE == 2 and #model.steps == 2)
end)

check("Consumed source input and detached output mutations retire both proofs", function()
    for _, mutate in ipairs({
        function(p) p.unknown = not p.unknown end,
        function(p) p.ready = not p.ready end,
        function(p) p.rows[1].id = 2 end,
        function(p) p.rows[1].state = {} end,
        function(p) p.actions[1].kind = "turnin" end,
        function(_, _, e) e.states[1].status = "READY" end,
        function(_, d) d.quests[1] = 2 end,
        function(_, _, e) e.context = {} end,
        function(_, _, e) e.context.current = function() return true end end,
        function(_, _, _, m) m.counts.ACTIVE = 999 end,
        function(_, _, _, m) m.steps[1].id = 999 end,
        function(_, _, _, m) m.steps[7] = {} end,
    }) do
        local plan, dungeon, engine = controlled(2, "ACTIVE")
        local model, current, raw = get(plan, dungeon, engine)
        mutate(plan, dungeon, engine, model); assert(not current() and not raw())
    end
end)

check("Unconsumed artwork definitions action coordinates and quantities remain outside this projection", function()
    local plan, dungeon, engine = controlled(1, "ACTIVE")
    local _, current, raw = get(plan, dungeon, engine)
    plan.counts = {}; plan.actions[1].place = { x = 8 }; plan.actions[1].quantity = 999
    engine.quests[1].requires = { { ids = { 300 } } }; dungeon.art = 123
    assert(current() and raw(), "upstream list owner, not the projector, owns graph and artwork")
end)

check("Malformed membership dense shapes limits and unsafe states never publish partial models", function()
    for _, mutate in ipairs({
        function(p) p.engine = {} end,
        function(p) p.dungeon = {} end,
        function(p) p.rows[2] = p.rows[1] end,
        function(p) p.rows[1].id = 999 end,
        function(p) p.rows.extra = p.rows[1] end,
        function(p) p.actions[3] = p.actions[1] end,
        function(p) p.actions[1].id = 0 / 0 end,
        function(p) p.actions[1].kind = "invented" end,
        function(p) p.unknown = 1 end,
        function(_, _, e) e.states[1].status = "invented" end,
        function(p) for i = 1, 1025 do p.actions[i] = p.actions[1] end end,
        function(_, d) for i = 1, 101 do d.quests[i] = i end end,
    }) do
        local plan, dungeon, engine = controlled(1, "ACTIVE")
        mutate(plan, dungeon, engine); assert(Overview.Get(plan, dungeon, engine) == nil)
    end
end)

check("Owner is construction-only and engine context remains a dynamic freshness gate", function()
    local plan, dungeon, engine = controlled(1, "ACTIVE")
    local calls, alive = 0, true
    local _, current, raw = get(plan, dungeon, engine, function() calls = calls + 1; return alive end)
    assert(calls == 1); alive = false; assert(current() and raw() and calls == 1)
    engine.context.current = function() return false end
    assert(not current())
    assert(Overview.Get(plan, dungeon, engine, function() return false end) == nil)
end)

check("Fired sanitizer owner and engine callbacks cannot rebind consumed snapshots", function()
    for _, phase in ipairs({ "clean", "owner", "engine" }) do
        local plan, dungeon, engine = controlled(1, "ACTIVE")
        local clean, fired = addon.Clean, false
        local function mutate() if not fired then fired = true; plan.unknown = not plan.unknown end end
        local owner
        if phase == "clean" then addon.Clean = function(value, kind) if value == 1 and kind == "number" then mutate() end; return clean(value, kind) end
        elseif phase == "owner" then owner = function() mutate(); return true end
        else engine.Current = function() mutate(); return true end end
        assert(Overview.Get(plan, dungeon, engine, owner) == nil and fired)
        addon.Clean = clean
    end
end)

check("Restricted root list and row values fail before protected structural consumption", function()
    for _, phase in ipairs({ "root", "list", "row" }) do
        local plan, dungeon, engine = controlled(1, "ACTIVE")
        local target = phase == "root" and plan or phase == "list" and plan.rows or plan.rows[1]
        local fired, unsafe, saved = false, false, issecretvalue
        local get, iterate = rawget, next
        issecretvalue = function(value) if value == target then fired = true; return true end; return false end
        rawget = function(value, key) if value == target then unsafe = true; error("restricted field read") end; return get(value, key) end
        next = function(value, key) if value == target then unsafe = true; error("restricted iteration") end; return iterate(value, key) end
        local result = Overview.Get(plan, dungeon, engine)
        issecretvalue, rawget, next = saved, get, iterate
        assert(result == nil and fired and not unsafe, "restricted input cannot be structurally consumed inside pcall")
    end
end)

check("Raw proof stays callback-free and helper replacement retires captured capability", function()
    local plan, dungeon, engine = controlled(1, "ACTIVE")
    local _, current, raw = get(plan, dungeon, engine)
    local read = addon.Read; addon.Read = function() error("changed helper must never run") end
    assert(not current() and not raw()); addon.Read = read
    local armed = false
    engine.context.current = function() assert(not armed, "raw proof invoked context"); return true end
    local _, _, proof = get(plan, dungeon, engine)
    armed = true
    assert(proof())
end)
print("Dungeon overview projection: PASS " .. total .. " groups; no additional planning or native reads")
