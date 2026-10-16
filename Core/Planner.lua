local _, addon = ...
local Planner = {}
addon.Planner = Planner

local function contains(list, value)
    for _, entry in ipairs(list) do if entry == value then return true end end
    return false
end

local function prerequisiteSatisfied(state, mode)
    return state.completedHistory == true or (mode == "active" and
        (state.status == "ACTIVE" or state.status == "READY"))
end

function Planner.Eligible(q, context)
    local unknown
    for _, rule in ipairs({ { "factions", "faction" }, { "classes", "class" }, { "races", "race" } }) do
        if q[rule[1]] then
            local value = context[rule[2]]
            if value == nil then unknown = unknown or rule[2]
            elseif not contains(q[rule[1]], value) then return false, rule[2] end
        end
    end
    if unknown then return nil, unknown end
    return true
end

function Planner.New(quests, context, choices)
    local engine = { quests = quests, context = context, choices = choices, states = {}, visiting = {} }

    function engine:State(id)
        if self.states[id] then return self.states[id] end
        local completedHistory = false
        local function save(status, reason)
            local result = { status = status, reason = reason, id = id, completedHistory = completedHistory }
            self.states[id] = result
            return result
        end
        local q = self.quests[id]
        if not q then return save("UNKNOWN", "missing") end
        local done = self.context.completed(id)
        -- Past completion can satisfy a prerequisite while a new run remains active.
        completedHistory = done == true
        local active = self.context.active(id)
        if active == true then
            return save(self.context.ready and self.context.ready(id) == true and "READY" or "ACTIVE")
        end
        if done == true then return save("COMPLETED") end
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
                if prerequisiteSatisfied(state, group.mode) then satisfied = true end
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
            -- The turn-in NPC is not an objective location for an unfinished quest.
            return { { id = id, kind = state.status == "READY" and "turnin" or "complete",
                place = state.status == "READY" and q.finish or nil } }, false
        end
        if state.status == "AVAILABLE" then
            return { { id = id, kind = q.startsInside and "inside" or "pickup", place = q.start } }, false
        end
        if state.reason == "level" then return { { id = id, kind = "level", level = q.minLevel } }, false end
        path[id] = true
        local actions, uncertain, seen = {}, false, {}
        for groupIndex, group in ipairs(q.requires or {}) do
            local satisfied = false
            for _, parent in ipairs(group.ids) do
                if prerequisiteSatisfied(self:State(parent), group.mode) then
                    satisfied = true
                end
            end
            if not satisfied then
                local best, bestUnknown, bestScore
                local selected = type(self.choices) == "table" and self.choices[id]
                selected = type(selected) == "table" and addon.Clean(selected[groupIndex], "number") or nil
                if selected and (not contains(group.ids, selected) or self:State(selected).status == "UNAVAILABLE") then
                    selected = nil
                end
                for _, parent in ipairs(group.ids) do
                    if (not selected or parent == selected) and self:State(parent).status ~= "UNAVAILABLE" then
                        local candidates, missing = self:Next(parent, path)
                        local score = missing and 10000 or 0
                        if #candidates == 0 then score = score + 5000 end
                        for _, action in ipairs(candidates) do score = score + (action.kind == "level" and 100 or 1) end
                        if not bestScore or score < bestScore then best, bestUnknown, bestScore = candidates, missing, score end
                    end
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

    -- Material sources are informational completion links, never acceptance gates.
    function engine:CompletionSteps(id)
        id = addon.Clean(id, "number")
        if not id or id < 1 or id % 1 ~= 0 then return {} end
        local q = self.quests[id]
        local related = q and addon.Clean(q.completionQuests, "table")
        local result, seen = {}, {}
        if not related then return result end
        for i = 1, math.min(#related, 100) do
            local entry = addon.Clean(related[i], "table")
            local other = entry and addon.Clean(entry.id, "number")
            local itemID = entry and addon.Clean(entry.itemID, "number")
            if other and other > 0 and other % 1 == 0 and other ~= id and not seen[other] and
                itemID and itemID > 0 and itemID % 1 == 0 then
                seen[other] = true
                local actions, unknown = self:Next(other)
                result[#result + 1] = { id = other, itemID = itemID, state = self:State(other),
                    actions = actions, unknown = unknown }
            end
        end
        return result
    end

    function engine:Dungeon(dungeon, options)
        local result = { rows = {}, actions = {}, counts = {}, unknown = dungeon.coverage ~= "reviewed", ready = true }
        local seen, relevant = {}, 0
        for _, id in ipairs(dungeon.quests) do
            local q = self.quests[id]
            local eligible = q and Planner.Eligible(q, self.context)
            local state = self:State(id)
            -- Current log evidence outweighs stale catalog restrictions; past history does not.
            local relevantToCharacter = eligible ~= false or state.status == "ACTIVE" or state.status == "READY"
            if relevantToCharacter or (options and options.includeUnavailable == true) then
                result.rows[#result.rows + 1] = { id = id, state = state }
                result.counts[state.status] = (result.counts[state.status] or 0) + 1
                -- Inspection of another character's quests does not add work
                -- or uncertainty to this character's preparation result.
                if relevantToCharacter then
                    relevant = relevant + 1
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
        end
        if result.unknown or relevant == 0 then result.ready = false end
        return result
    end
    return engine
end
