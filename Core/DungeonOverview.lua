local _, addon = ...
local Overview = {}
addon.DungeonOverview = Overview

-- Project a completed, caller-owned plan; never resolve prerequisites a second time.
function Overview.Get(plan, dungeon, engine, ownerCurrent, stepLimit)
    local clean, read, checker, provider = addon.Clean, addon.Read, issecretvalue, Overview.Get
    if type(clean) ~= "function" or type(read) ~= "function" then return nil end
    local snapshots, arrays = {}, {}
    local function capabilities()
        return addon.DungeonOverview == Overview and Overview.Get == provider and
            addon.Clean == clean and addon.Read == read and issecretvalue == checker
    end
    local function ordinary(value)
        if type(checker) == "function" then
            local ok, safe = pcall(function() return checker(value) == false end)
            if not ok or not safe then return false end
        end
        return capabilities()
    end
    local function object(value)
        if not ordinary(value) or type(value) ~= "table" then error("invalid overview object") end
        return value
    end
    local function fields(value, keys)
        object(value)
        local held = {}
        for _, key in ipairs(keys) do held[key] = rawget(value, key) end
        snapshots[#snapshots + 1] = { value, keys, held }
        for _, key in ipairs(keys) do
            if not ordinary(held[key]) then error("restricted overview field") end
        end
        return held
    end
    local function number(value)
        if not ordinary(value) then error("restricted overview identifier") end
        value = clean(value, "number")
        if not value or value <= 0 or value % 1 ~= 0 or value > 4294967295 then error("invalid overview identifier") end
        return value
    end
    local function sequence(value, limit)
        object(value)
        local length = #value
        if length > limit then error("overview sequence limit") end
        local keys, count, held = {}, 0, {}
        for key in next, value do
            count = count + 1
            if count > limit or not ordinary(key) or type(key) ~= "number" or key % 1 ~= 0 or
                key < 1 or key > length then error("invalid overview sequence") end
        end
        if count ~= length then error("sparse overview sequence") end
        for index = 1, length do keys[index], held[index] = index, rawget(value, index) end
        snapshots[#snapshots + 1] = { value, keys, held }
        arrays[#arrays + 1] = { value, length, limit }
        return held, length
    end
    local function rawCurrent()
        local ok, same = pcall(function()
            if not capabilities() then return false end
            for _, snapshot in ipairs(snapshots) do
                for _, key in ipairs(snapshot[2]) do
                    if not rawequal(rawget(snapshot[1], key), snapshot[3][key]) then return false end
                end
            end
            for _, array in ipairs(arrays) do
                if #array[1] ~= array[2] then return false end
                local count = 0
                for _ in next, array[1] do
                    count = count + 1
                    if count > array[3] then return false end
                end
                if count ~= array[2] then return false end
            end
            return true
        end)
        return ok and same == true
    end
    local currentGetter
    local function current()
        if not rawCurrent() or read(currentGetter, "boolean", engine) ~= true then return false end
        return rawCurrent()
    end
    local result
    local ok = pcall(function()
        if not ordinary(stepLimit) then error("restricted overview limit") end
        local limit = stepLimit == nil and 6 or clean(stepLimit,"number")
        if not limit or limit % 1 ~= 0 or limit < 6 or limit > 1024 then error("invalid overview limit") end
        -- Ordinary classification precedes structural reads; snapshots precede later callbacks.
        local input = fields(plan, { "engine", "dungeon", "rows", "actions", "unknown", "ready" })
        local source = fields(dungeon, { "quests" })
        local state = fields(engine, { "Current", "states", "context", "quests", "invalid" })
        currentGetter = state.Current
        if not ordinary(currentGetter) or type(currentGetter) ~= "function" or input.engine ~= engine or
            input.dungeon ~= dungeon or not ordinary(input.unknown) or type(input.unknown) ~= "boolean" or
            not ordinary(input.ready) or type(input.ready) ~= "boolean" then error("invalid overview scope") end
        object(state.states)
        fields(state.context, { "current" })
        local roots, rootCount = sequence(source.quests, 100)
        local rootIDs = {}
        for index = 1, rootCount do
            local id = number(roots[index])
            if rootIDs[id] then error("duplicate overview root") end
            rootIDs[id] = true
        end
        local rows, rowCount = sequence(input.rows, 100)
        local actions, actionCount = sequence(input.actions, 1024)
        local statusKeys = { "ACTIVE", "READY", "COMPLETED", "UNKNOWN", "LOCKED", "AVAILABLE", "UNAVAILABLE" }
        local statuses, counts = {}, {}
        for _, status in ipairs(statusKeys) do statuses[status], counts[status] = true, 0 end
        local cached = {}
        local function cachedState(id)
            if cached[id] then return cached[id] end
            local lookup = fields(state.states, { id })
            local entry = fields(lookup[id], { "id", "status" })
            if number(entry.id) ~= id or not ordinary(entry.status) or type(entry.status) ~= "string" or
                not statuses[entry.status] then error("invalid cached overview state") end
            cached[id] = { object = lookup[id], status = entry.status }
            return cached[id]
        end
        local seenRows = {}
        for index = 1, rowCount do
            local row = fields(rows[index], { "id", "state" })
            local id = number(row.id)
            if not rootIDs[id] or seenRows[id] then error("invalid overview row membership") end
            local cachedRow = cachedState(id)
            if not ordinary(row.state) or row.state ~= cachedRow.object then error("foreign overview row state") end
            seenRows[id] = true
            counts[cachedRow.status] = counts[cachedRow.status] + 1
        end
        local kinds = { complete = true, turnin = true, pickup = true, inside = true, level = true }
        local seenSteps, steps, stepCount = {}, {}, 0
        local readySteps, activeSteps = {}, {}
        for index = 1, actionCount do
            local action = fields(actions[index], { "id", "kind" })
            local id = number(action.id)
            if not ordinary(action.kind) or type(action.kind) ~= "string" or not kinds[action.kind] then error("invalid overview action") end
            local status = cachedState(id).status
            if not seenSteps[id] and ((action.kind == "complete" and status == "ACTIVE") or
                (action.kind == "turnin" and status == "READY")) then
                seenSteps[id], stepCount = true, stepCount + 1
                local group = status == "READY" and readySteps or activeSteps
                if #group < limit then group[#group + 1] = { id = id, kind = action.kind, status = status, listedTarget = rootIDs[id] == true } end
            end
        end
        for _, group in ipairs({ readySteps, activeSteps }) do
            for _, step in ipairs(group) do if #steps < limit then steps[#steps + 1] = step end end
        end
        result = { counts = counts, shownRoots = rowCount, unknown = input.unknown,
            knownPrepared = input.ready and not input.unknown, steps = steps, remainingSteps = stepCount - #steps }
        fields(result, { "counts", "shownRoots", "unknown", "knownPrepared", "steps", "remainingSteps" })
        fields(counts, statusKeys)
        sequence(steps, limit)
        for _, step in ipairs(steps) do fields(step, { "id", "kind", "status", "listedTarget" }) end
        if ownerCurrent ~= nil and (not ordinary(ownerCurrent) or type(ownerCurrent) ~= "function" or
            read(ownerCurrent, "boolean") ~= true) then error("expired overview owner") end
        if not current() then error("expired overview plan") end
    end)
    if not ok or not result then return nil end
    return result, current, rawCurrent
end
