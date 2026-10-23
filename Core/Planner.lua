local _, addon = ...
local Planner = {}
addon.Planner = Planner

local function contextCurrent(context)
    -- A non-table context carries no current predicate; fail closed as
    -- expired so public Eligible and engine Current never throw on it.
    if type(context) ~= "table" then return false end
    local fn = context.current
    if type(issecretvalue) == "function" then
        local ok, restricted = pcall(issecretvalue, fn)
        if not ok or restricted ~= false then return false end
    end
    if fn == nil then return true end
    return addon.Read(fn, "boolean") == true
end

local function contains(list, value)
    for _, entry in ipairs(list) do if entry == value then return true end end
    return false
end

local function finiteNumber(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function prerequisiteSatisfied(state, mode)
    return state.completedHistory == true or (mode == "active" and
        (state.status == "ACTIVE" or state.status == "READY"))
end

-- Root membership is independent of readiness, level, and prerequisite progress.
function Planner.RelevantToCharacter(eligible, status)
    return eligible ~= false or status == "ACTIVE" or status == "READY"
end

function Planner.Eligible(q, context)
    -- A non-table context fails closed as unknown character, never a throw
    -- or a fail-open eligibility: contextCurrent also guards, but this entry
    -- indexes context directly below, so the contract is stated here too.
    if type(context) ~= "table" then return nil, "character" end
    if not contextCurrent(context) then return nil, "character" end
    -- A non-table quest entry is unknown requirements, never a throw.
    if type(q) ~= "table" then return nil, "requirements" end
    local unknown
    for _, rule in ipairs({ { "factions", "faction" }, { "classes", "class" } }) do
        local list = q[rule[1]]
        if list ~= nil then
            -- Malformed audience data is unknown requirements, never a throw or an exclusion.
            if type(list) ~= "table" then return nil, "requirements" end
            local value = context[rule[2]]
            if value == nil then unknown = unknown or rule[2]
            elseif not contains(list, value) then return false, rule[2] end
        end
    end
    if unknown then return nil, unknown end
    return true
end

function Planner.New(quests, context, choices)
    -- A hostile or missing context fails closed through the expired-context
    -- path so States return UNKNOWN/character instead of throwing.
    if type(context) ~= "table" then context = { current = function() return false end } end
    local engine = { quests = quests, context = context, choices = choices, states = {}, visiting = {} }

    function engine:Current()
        if self.invalid then return false end
        if contextCurrent(self.context) then return true end
        self.invalid, self.states, self.visiting = true, {}, {}
        return false
    end

    function engine:State(id)
        -- A non-numeric ID cannot index the state cache; fail closed as
        -- missing without throwing, mirroring CompletionSteps below.
        id = addon.Clean(id, "number")
        if not id then return { status = "UNKNOWN", reason = "missing", id = nil, completedHistory = false } end
        local completedHistory = false
        local function save(status, reason)
            if not self:Current() then status, reason, completedHistory = "UNKNOWN", "character", false end
            local result = { status = status, reason = reason, id = id, completedHistory = completedHistory }
            self.states[id] = result
            return result
        end
        if not self:Current() then return save("UNKNOWN", "character") end
        -- A non-table quest catalogue fails closed as missing, never a throw.
        if type(self.quests) ~= "table" then return save("UNKNOWN", "missing") end
        if self.states[id] then return self.states[id] end
        local q = self.quests[id]
        if not q then return save("UNKNOWN", "missing") end
        -- A partial table context missing the log probes fails closed as
        -- unknown character instead of throwing, mirroring the non-table
        -- context path above (ready alone stays optional).
        if type(self.context.completed) ~= "function" or type(self.context.active) ~= "function" then
            return save("UNKNOWN", "character")
        end
        -- A truthy non-function ready would throw at the active branch below;
        -- fail closed as unknown character. Nil/false stay optional (ACTIVE path).
        if self.context.ready and type(self.context.ready) ~= "function" then
            return save("UNKNOWN", "character")
        end
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
        if eligible == nil then
            if restriction == "requirements" then return save("UNKNOWN", "requirements") end
            return save("UNKNOWN", "character")
        end
        if done == nil or active == nil then return save("UNKNOWN", "character") end
        if not finiteNumber(self.context.level) then return save("UNKNOWN", "level") end
        if q.minLevel ~= nil then
            -- A malformed minimum level is unknown requirements, never a compare throw.
            if not finiteNumber(q.minLevel) then return save("UNKNOWN", "requirements") end
            if self.context.level < q.minLevel then return save("LOCKED", "level") end
        end
        if q.requirementsKnown ~= true then return save("UNKNOWN", "requirements") end
        if self.visiting[id] then return save("UNKNOWN", "cycle") end
        self.visiting[id] = true
        local blocked, unknown = false, false
        if q.requires ~= nil and type(q.requires) ~= "table" then
            self.visiting[id] = nil
            return save("UNKNOWN", "requirements")
        end
        for _, group in ipairs(q.requires or {}) do
            if type(group) ~= "table" or type(group.ids) ~= "table" then
                self.visiting[id] = nil
                return save("UNKNOWN", "requirements")
            end
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
        -- Share only cycle-free subresults inside this one synchronous request.
        -- A new call always resolves fresh choices and produces fresh actions.
        -- A non-numeric ID cannot index memo/path caches; fail closed as
        -- unknown without throwing, mirroring State above.
        id = addon.Clean(id, "number")
        if not id then return {}, true end
        local memo = {}
        local function resolve(id, path)
            if path[id] then return {}, true, true end
            local cached = memo[id]
            if cached then
                if not self:Current() then return {}, true end
                return cached.actions, cached.unknown, false
            end
            local cyclic = false
            local function publish(actions, unknown)
                if not self:Current() then return {}, true, cyclic end
                if not cyclic then memo[id] = { actions = actions, unknown = unknown } end
                return actions, unknown, cyclic
            end
            local state = self:State(id)
            -- A non-table catalogue fails closed as unknown, never a throw.
            local q = type(self.quests) == "table" and self.quests[id] or nil
            -- A non-table quest entry carries no places or groups; treat it as absent.
            if type(q) ~= "table" then q = nil end
            -- Known groups can expose safe work while the quest's full conditions
            -- remain unknown. An unknown leaf never authorizes pickup.
            if state.status == "UNKNOWN" and not (q and state.reason == "requirements" and
                type(q.requires) == "table" and #q.requires > 0) then return {}, true, false end
            if state.status == "COMPLETED" or state.status == "UNAVAILABLE" then return {}, false, false end
            if state.status == "ACTIVE" or state.status == "READY" then
                -- The turn-in NPC is not an objective location for an unfinished quest.
                return publish({ { id = id, kind = state.status == "READY" and "turnin" or "complete",
                    place = state.status == "READY" and q and q.finish or nil } }, false)
            end
            if state.status == "AVAILABLE" then
                -- The catalogue can mutate between State and this re-read; a
                -- missing entry fails closed as unknown, never a throw.
                if not q then return publish({}, true) end
                return publish({ { id = id, kind = q.startsInside and "inside" or "pickup", place = q.start } }, false)
            end
            if state.reason == "level" then
                if not q then return publish({}, true) end
                return publish({ { id = id, kind = "level", level = q.minLevel } }, false)
            end
            -- Any later traversal needs the entry; a vanished entry fails closed.
            if not q then return publish({}, true) end
            path[id] = true
            local actions, uncertain, seen = {}, state.status == "UNKNOWN" and q.requirementsKnown ~= true, {}
            if q.requires ~= nil and type(q.requires) ~= "table" then path[id] = nil; return publish({}, true) end
            for groupIndex, group in ipairs(q.requires or {}) do
                if type(group) ~= "table" or type(group.ids) ~= "table" then path[id] = nil; return publish({}, true) end
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
                            local candidates, missing, cycle = resolve(parent, path)
                            cyclic = cyclic or cycle == true
                            local score = missing and 10000 or 0
                            if #candidates == 0 then score = score + 5000 end
                            for _, action in ipairs(candidates) do score = score + (action.kind == "level" and 100 or 1) end
                            if not bestScore or score < bestScore then best, bestUnknown, bestScore = candidates, missing, score end
                        end
                    end
                    -- An empty OR group is known to be unsatisfiable, not unknown evidence.
                    if bestUnknown or ((not best or #best == 0) and #group.ids > 0) then uncertain = true end
                    for _, action in ipairs(best or {}) do
                        local key = action.id .. ":" .. action.kind
                        if not seen[key] then actions[#actions + 1], seen[key] = action, true end
                    end
                end
            end
            path[id] = nil
            return publish(actions, uncertain)
        end
        local actions, unknown = resolve(id, type(path) == "table" and path or {})
        return actions, unknown
    end

    -- Material sources are informational completion links, never acceptance gates.
    function engine:CompletionSteps(id)
        id = addon.Clean(id, "number")
        if not id or id < 1 or id > 4294967295 or id % 1 ~= 0 then return {} end
        -- A non-table catalogue fails closed as empty, never a throw.
        if type(self.quests) ~= "table" then return {} end
        local q = self.quests[id]
        -- A non-table quest entry carries no completion links; treat it as absent.
        if type(q) ~= "table" then return {} end
        local related = addon.Clean(q.completionQuests, "table")
        local result, seen = {}, {}
        if not related then return result end
        for i = 1, math.min(#related, 100) do
            local entry = addon.Clean(related[i], "table")
            local other = entry and addon.Clean(entry.id, "number")
            local itemID = entry and addon.Clean(entry.itemID, "number")
            if other and other > 0 and other <= 4294967295 and other % 1 == 0 and other ~= id and not seen[other] and
                itemID and itemID > 0 and itemID <= 4294967295 and itemID % 1 == 0 then
                seen[other] = true
                local actions, unknown = self:Next(other)
                result[#result + 1] = { id = other, itemID = itemID, state = self:State(other),
                    actions = actions, unknown = unknown }
            end
        end
        if not self:Current() then
            for _, entry in ipairs(result) do
                entry.actions, entry.unknown, entry.state = {}, true, self:State(entry.id)
            end
        end
        return result
    end

    function engine:Dungeon(dungeon, options)
        if type(dungeon) ~= "table" or type(dungeon.quests) ~= "table" then
            return { rows = {}, actions = {}, counts = {}, unknown = true, ready = false }
        end
        -- A sparse quest list would silently drop entries under ipairs while
        -- leaving ready possibly true (fail-open). Count the sequence keys
        -- like DungeonStatus so a malformed/hand-edited catalogue entry fails
        -- closed instead. Dense arrays pass through unchanged.
        local listed, dense = 0, #dungeon.quests
        for key in pairs(dungeon.quests) do
            if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then dense = -1 break end
            listed = listed + 1
        end
        if listed ~= dense then
            return { rows = {}, actions = {}, counts = {}, unknown = true, ready = false }
        end
        -- Non-table options carry no includeUnavailable flag; treat them as absent.
        if options ~= nil and type(options) ~= "table" then options = nil end
        local result = { rows = {}, actions = {}, counts = {}, unknown = dungeon.coverage ~= "reviewed", ready = true }
        local seen, relevant = {}, 0
        for _, id in ipairs(dungeon.quests) do
            -- A non-table catalogue fails closed per quest, never a throw.
            local q = type(self.quests) == "table" and self.quests[id] or nil
            -- A non-table quest entry carries no places; treat it as absent.
            if type(q) ~= "table" then q = nil end
            local eligible = q and Planner.Eligible(q, self.context)
            local state = self:State(id)
            -- Current log evidence outweighs stale catalog restrictions; past history does not.
            local relevantToCharacter = Planner.RelevantToCharacter(eligible, state.status)
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
        if not self:Current() then
            result = { rows = {}, actions = {}, counts = {}, unknown = true, ready = false }
            for _, id in ipairs(dungeon.quests) do
                result.rows[#result.rows + 1] = { id = id, state = self:State(id) }
            end
            result.counts.UNKNOWN = #result.rows
        end
        return result
    end
    return engine
end
