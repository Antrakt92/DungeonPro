local addon, total, secret = {}, 0, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Planner.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local function reset()
    issecretvalue = function(value) return value == secret end
    addon.char = {}
    UnitGUID = function() error("planning must not read player GUID") end
    UnitLevel = function(unit) assert(unit == "player"); return 40 end
    UnitFactionGroup = function() return "Alliance" end
    UnitClass = function() return "Mage", "MAGE" end
    UnitRace = function() return "Dwarf", "Dwarf", 3 end
    C_QuestLog = {
        IsQuestFlaggedCompleted = function() return false end,
        IsOnQuest = function() return false end,
        ReadyForTurnIn = function() return false end,
    }
end
local function check(name, fn)
    reset(); fn(); total = total + 1; print("PASS " .. name)
end
local function quest(id, fields)
    local q = { id = id, minLevel = 1, requirementsKnown = true, start = { npcID = id } }
    for key, value in pairs(fields or {}) do q[key] = value end
    return q
end
check("A captured context loses old character evidence permanently after its root changes", function()
    local old = addon.char
    local c = addon.Context()
    assert(c.level == 40 and c.class == "MAGE" and c.race == 3 and c.faction == "Alliance")
    addon.char = {}
    assert(c.completed(1) == nil and c.active(1) == nil and c.ready(1) == nil)
    assert(c.level == nil and c.class == nil and c.race == nil and c.faction == nil)
    addon.char = old
    assert(c.current() == false and c.completed(1) == nil, "old contexts cannot revive")
    assert(addon.Context().current() == true, "a new context recovers independently")
end)
check("Quest namespaces getters and checker drift cannot publish old booleans", function()
    for _, mode in ipairs({ "namespace", "getter", "character", "checker" }) do
        reset()
        C_QuestLog.IsOnQuest = function()
            if mode == "namespace" then C_QuestLog = {}
            elseif mode == "getter" then C_QuestLog.IsOnQuest = function() return false end
            elseif mode == "character" then addon.char = {}
            else issecretvalue = function() return false end end
            return true
        end
        local c = addon.Context()
        assert(c.active(1) == nil and not c.current(), mode)
    end
end)
check("Character snapshot construction cannot mix facts from changed native readers", function()
    for mode = 1, 3 do
        reset()
        if mode == 3 then
            UnitRace = function() addon.char = {}; return "Dwarf", "Dwarf", 3 end
        else
            UnitLevel = function()
                if mode == 1 then addon.char = {}
                else UnitRace = function() return "Human", "Human", 1 end end
                return 40
            end
        end
        local c = addon.Context()
        assert(c.level == nil and c.class == nil and c.race == nil and not c.current())
        assert(c.completed(1) == nil)
    end
end)
check("Malformed namespaces and restricted facts stay quiet without authorizing progress", function()
    for _, value in ipairs({ true, 1, "quest service", secret }) do
        reset(); C_QuestLog = value
        local c = addon.Context()
        assert(c.completed(1) == nil and c.active(1) == nil and c.ready(1) == nil)
    end
    reset(); UnitLevel = function() return secret end
    UnitClass = function() return "Restricted", secret end
    UnitRace = function() return "Restricted", "Restricted", secret end
    local c = addon.Context()
    assert(c.level == nil and c.class == nil and c.race == nil and c.completed(1) == false)
end)
check("Explicit clean quest reads preserve the ready fallback and stable pre-DB context", function()
    addon.char = nil
    C_QuestLog.ReadyForTurnIn = nil
    C_QuestLog.IsComplete = function(id, ...) assert(id == 7 and select("#", ...) == 0); return true end
    local c = addon.Context()
    assert(c.current() and c.ready(7) == true and c.completed(7) == false and c.active(7) == false)
    for _, id in ipairs({ secret, false, 0, -1, 1.5, "7", math.huge, 0/0 }) do
        assert(c.ready(id) == nil)
    end
end)
check("Planning discards cached completion and restrictions after context invalidation", function()
    C_QuestLog.IsQuestFlaggedCompleted = function() return true end
    local c = addon.Context()
    local q = quest(1, { factions = { "Horde" } })
    local engine = addon.Planner.New({ [1] = q }, c)
    assert(engine:State(1).status == "COMPLETED")
    addon.char = {}
    local state = engine:State(1)
    assert(state.status == "UNKNOWN" and state.reason == "character" and state.completedHistory == false)
    local eligible, why = addon.Planner.Eligible(q, c)
    assert(eligible == nil and why == "character")
end)
check("An active read cannot survive character replacement inside the ready reader", function()
    C_QuestLog.IsOnQuest = function() return true end
    C_QuestLog.ReadyForTurnIn = function() addon.char = {}; return true end
    local engine = addon.Planner.New({ [1] = quest(1) }, addon.Context())
    local state = engine:State(1)
    assert(state.status == "UNKNOWN" and state.completedHistory == false)
    local actions, unknown = engine:Next(1)
    assert(#actions == 0 and unknown)
end)
local function scopedGraph()
    local valid = true
    local c = { level = 40, completed = function() return false end, active = function() return false end,
        current = function() return valid end }
    local graph = { [1] = quest(1), [2] = quest(2), [3] = quest(3, { requires = { { ids = {1} }, { ids = {2} } } }) }
    return addon.Planner.New(graph, c), function() valid = false end
end
check("A later prerequisite cannot leave accumulated actions from an invalid context", function()
    local engine, invalidate = scopedGraph()
    local native = engine.Next
    engine.Next = function(self, id, path)
        if id == 2 then invalidate(); return {}, true end
        return native(self, id, path)
    end
    local actions, unknown = engine:Next(3)
    assert(#actions == 0 and unknown)
end)
check("Dungeon invalidation cannot retain earlier completed counts actions or readiness", function()
    C_QuestLog.IsQuestFlaggedCompleted = function(id) return id == 1 end
    C_QuestLog.IsOnQuest = function(id) if id == 2 then addon.char = {} end; return false end
    local engine = addon.Planner.New({ [1] = quest(1), [2] = quest(2) }, addon.Context())
    local result = engine:Dungeon({ quests = { 1, 2 }, coverage = "reviewed" })
    assert(result.unknown and not result.ready and #result.actions == 0 and #result.rows == 2)
    assert(result.counts.COMPLETED == nil and result.counts.UNKNOWN == 2)
    for _, row in ipairs(result.rows) do assert(row.state.status == "UNKNOWN" and not row.state.completedHistory) end
end)
check("Completion links remain inspectable while invalidated actions and evidence are removed", function()
    local engine, invalidate = scopedGraph()
    engine.quests[3].completionQuests = { { id = 1, itemID = 11 }, { id = 2, itemID = 12 } }
    local native = engine.Next
    engine.Next = function(self, id, path)
        if id == 2 then invalidate(); return {}, true end
        return native(self, id, path)
    end
    local links = engine:CompletionSteps(3)
    assert(#links == 2)
    for _, link in ipairs(links) do assert(#link.actions == 0 and link.unknown and link.state.status == "UNKNOWN") end
end)
check("Optional validity adapters fail closed while absent adapters preserve legacy planning", function()
    local c = { level = 40, completed = function() return false end, active = function() return false end }
    assert(addon.Planner.New({ [1] = quest(1) }, c):State(1).status == "AVAILABLE")
    for _, value in ipairs({ false, true, secret, function() error("scope failed") end,
        function() return nil end, function() return secret end, function() return "true" end }) do
        c.current = value
        local state = addon.Planner.New({ [1] = quest(1) }, c):State(1)
        assert(state.status == "UNKNOWN" and state.completedHistory == false)
    end
end)
print("Character context modeled checks passed: " .. total .. " (no native character validation)")
