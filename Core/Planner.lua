local _, addon = ...
local Planner = {}
addon.Planner = Planner

local function contains(list, value)
    for _, entry in ipairs(list) do if entry == value then return true end end
    return false
end

function Planner.Eligible(q, context)
    for _, rule in ipairs({ { "factions", "faction" }, { "classes", "class" }, { "races", "race" } }) do
        if q[rule[1]] then
            local value = context[rule[2]]
            if value == nil then return nil, rule[2] end
            if not contains(q[rule[1]], value) then return false, rule[2] end
        end
    end
    return true
end

function Planner.New(quests, context)
    local engine = { quests = quests, context = context, states = {}, visiting = {} }

    function engine:State(id)
        if self.states[id] then return self.states[id] end
        local function save(status, reason)
            local result = { status = status, reason = reason, id = id }
            self.states[id] = result
            return result
        end
        local q = self.quests[id]
        if not q then return save("UNKNOWN", "missing") end
        local done = self.context.completed(id)
        if done == true then return save("COMPLETED") end
        local active = self.context.active(id)
        if active == true then
            return save(self.context.ready and self.context.ready(id) == true and "READY" or "ACTIVE")
        end
        local eligible, restriction = Planner.Eligible(q, self.context)
        if eligible == false then return save("UNAVAILABLE", restriction) end
        if eligible == nil or done == nil or active == nil then return save("UNKNOWN", "character") end
        if not self.context.level then return save("UNKNOWN", "level") end
        if self.context.level < q.minLevel then return save("LOCKED", "level") end
        if q.requirementsKnown ~= true then return save("UNKNOWN", "requirements") end
        if self.visiting[id] then return save("UNKNOWN", "cycle") end
        self.visiting[id] = true
        local blocked, unknown = false, false
        for _, group in ipairs(q.requires or {}) do
            local satisfied, uncertain = false, false
            for _, parent in ipairs(group.ids) do
                local state = self:State(parent)
                if state.status == "COMPLETED" or (group.mode == "active" and
                    (state.status == "ACTIVE" or state.status == "READY")) then satisfied = true end
                if state.status == "UNKNOWN" then uncertain = true end
            end
            if not satisfied then
                blocked = true
                if uncertain then unknown = true end
            end
        end
        self.visiting[id] = nil
        if unknown then return save("UNKNOWN", "requirements") end
        if blocked then return save("LOCKED", "requirements") end
        return save("AVAILABLE")
    end

    -- Each group is an OR; groups together are AND. Resolve all the way to an
    -- actionable ancestor, rather than sending players to another locked quest.
    function engine:Next(id, path)
        path = path or {}
        if path[id] then return {}, true end
        local state, q = self:State(id), self.quests[id]
        -- A known AND/OR graph may still contain a safe branch even when a
        -- different prerequisite has unknown requirements.
        if state.status == "UNKNOWN" and not (q and q.requirementsKnown == true and
            state.reason == "requirements") then return {}, true end
        if state.status == "COMPLETED" or state.status == "UNAVAILABLE" then return {}, false end
        if state.status == "ACTIVE" or state.status == "READY" then
            return { { id = id, kind = state.status == "READY" and "turnin" or "complete", place = q.finish } }, false
        end
        if state.status == "AVAILABLE" then
            return { { id = id, kind = q.startsInside and "inside" or "pickup", place = q.start } }, false
        end
        if state.reason == "level" then return { { id = id, kind = "level", level = q.minLevel } }, false end
        path[id] = true
        local actions, uncertain, seen = {}, false, {}
        for _, group in ipairs(q.requires or {}) do
            local satisfied = false
            for _, parent in ipairs(group.ids) do
                local ps = self:State(parent).status
                if ps == "COMPLETED" or (group.mode == "active" and (ps == "ACTIVE" or ps == "READY")) then
                    satisfied = true
                end
            end
            if not satisfied then
                local best, bestUnknown, bestScore
                for _, parent in ipairs(group.ids) do
                    local candidates, missing = self:Next(parent, path)
                    local score = missing and 10000 or 0
                    if #candidates == 0 then score = score + 5000 end
                    for _, action in ipairs(candidates) do score = score + (action.kind == "level" and 100 or 1) end
                    if not bestScore or score < bestScore then best, bestUnknown, bestScore = candidates, missing, score end
                end
                if bestUnknown or not best or #best == 0 then uncertain = true end
                for _, action in ipairs(best or {}) do
                    local key = action.id .. ":" .. action.kind
                    if not seen[key] then actions[#actions + 1], seen[key] = action, true end
                end
            end
        end
        path[id] = nil
        return actions, uncertain
    end

    function engine:Dungeon(dungeon)
        local result = { rows = {}, actions = {}, counts = {}, unknown = dungeon.coverage ~= "reviewed", ready = true }
        local seen = {}
        for _, id in ipairs(dungeon.quests) do
            local q = self.quests[id]
            local eligible = q and Planner.Eligible(q, self.context)
            if eligible ~= false then
                local state = self:State(id)
                result.rows[#result.rows + 1] = { id = id, state = state }
                result.counts[state.status] = (result.counts[state.status] or 0) + 1
                if state.status ~= "COMPLETED" and state.status ~= "ACTIVE" and state.status ~= "READY" and
                    not (q and q.startsInside and state.status == "AVAILABLE") then
                    result.ready = false
                end
                local actions, uncertain = self:Next(id)
                if uncertain or state.status == "UNKNOWN" then result.unknown = true end
                for _, action in ipairs(actions) do
                    local key = action.id .. ":" .. action.kind
                    if not seen[key] then result.actions[#result.actions + 1], seen[key] = action, true end
                end
            end
        end
        if result.unknown or #result.rows == 0 then result.ready = false end
        return result
    end
    return engine
end
