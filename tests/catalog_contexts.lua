local addon = {}
assert(loadfile("Core/Namespace.lua"))("DungeonPrep", addon)
assert(loadfile("Core/Planner.lua"))("DungeonPrep", addon)
assert(loadfile("Database/Catalog.lua"))("DungeonPrep", addon)
local classes = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN",
    "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }
local races, seen = { 1 }, { [1] = true }
for _, q in pairs(addon.quests) do
    for _, race in ipairs(q.races or {}) do
        if not seen[race] then races[#races + 1], seen[race] = race, true end
    end
end
table.sort(races)
local contexts, states, plans = 0, 0, 0
for _, faction in ipairs({ "Alliance", "Horde" }) do
    for _, class in ipairs(classes) do
        for _, race in ipairs(races) do
            for _, level in ipairs({ 1, 20, 60 }) do
                for _, mode in ipairs({ "new", "unknown", "active", "ready", "completed" }) do
                    local context = { level = level, faction = faction, class = class, race = race,
                        completed = function() if mode ~= "unknown" then return mode == "completed" end end,
                        active = function() if mode ~= "unknown" then return mode == "active" or mode == "ready" end end,
                        ready = function() return mode == "ready" end }
                    local engine = addon.Planner.New(addon.quests, context)
                    contexts = contexts + 1
                    for id, q in pairs(addon.quests) do
                        local state = engine:State(id)
                        assert(q.requirementsKnown == true or state.status ~= "AVAILABLE",
                            "Incomplete requirements authorized pickup: " .. id)
                        if mode == "unknown" then
                            assert(state.status == "UNKNOWN" or state.status == "UNAVAILABLE",
                                "Unknown history authorized progress: " .. id)
                        end
                        states = states + 1
                    end
                    for _, dungeon in ipairs(addon.dungeons) do
                        local normal = engine:Dungeon(dungeon)
                        local inspect = engine:Dungeon(dungeon, { includeUnavailable = true })
                        if dungeon.coverage ~= "reviewed" then
                            assert(normal.unknown and not normal.ready, "Incomplete dungeon authorized readiness: " .. dungeon.key)
                        end
                        assert(normal.ready == inspect.ready and normal.unknown == inspect.unknown,
                            "Inspection changed preparation: " .. dungeon.key)
                        local actions = {}
                        for _, action in ipairs(normal.actions) do
                            assert(addon.quests[action.id], "Unknown preparation quest")
                            local key = action.id .. ":" .. action.kind
                            assert(not actions[key], "Duplicate preparation action")
                            actions[key] = true
                        end
                        assert(#normal.actions == #inspect.actions, "Inspection added character preparation work")
                        for _, action in ipairs(inspect.actions) do
                            assert(actions[action.id .. ":" .. action.kind], "Inspection changed preparation actions")
                        end
                        plans = plans + 2
                    end
                end
            end
        end
    end
end
print("Catalogue context checks passed: " .. contexts .. " contexts, " .. states .. " quest states, " .. plans .. " dungeon plans")
