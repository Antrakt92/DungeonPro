local _, addon = ...

-- Search follows recorded links only; related steps never become dungeon targets.
function addon.QuestSearchRelations(dungeon, rootTargetID, ownerCurrent)
    local clean, read, checker, api = addon.Clean, addon.Read, issecretvalue, addon.QuestSearchRelations
    local definitions, catalogue = addon.quests, addon.dungeons
    if type(clean) ~= "function" or type(read) ~= "function" then return nil end
    local held, modelHeld = {}, {}
    local function capabilities()
        return addon.Clean == clean and addon.Read == read and issecretvalue == checker and
            addon.QuestSearchRelations == api and addon.quests == definitions and addon.dungeons == catalogue
    end
    local function capture(object, fields, exact, target)
        local values = {}
        for _, field in ipairs(fields) do values[field] = rawget(object, field) end
        local count = 0
        if exact then
            -- Keep bounded overflow evidence even when an invalid array is rejected.
            for _ in next, object do
                count = count + 1
                if count == 102 then break end
            end
        end
        local record = { object = object, fields = fields, values = values,
            count = exact and count or nil, meta = getmetatable(object) }
        target = target or held
        target[#target + 1] = record
        return values
    end
    local function unchanged(records)
        for _, record in ipairs(records) do
            if getmetatable(record.object) ~= record.meta or
                (record.length and #record.object ~= record.length) then return false end
            if record.count then
                local count = 0
                for _ in next, record.object do
                    count = count + 1
                    if count > record.count then return false end
                    if count == 102 then break end
                end
                if count ~= record.count then return false end
            end
            for _, field in ipairs(record.fields) do
                if not rawequal(rawget(record.object, field), record.values[field]) then return false end
            end
        end
        return true
    end
    local function rawCurrent()
        local ok, same = pcall(function()
            return capabilities() and unchanged(held) and unchanged(modelHeld)
        end)
        return ok and same == true
    end
    local function readable(record)
        -- Construction has no effects: check each new snapshot locally, then
        -- prove the entire captured graph after all callbacks before exposure.
        if type(checker) == "function" then
            if read(checker, "boolean", record.object) ~= false then return false end
            for _, field in ipairs(record.fields) do
                if read(checker, "boolean", record.values[field]) ~= false then return false end
            end
        end
        return capabilities()
    end
    local function current()
        local ok, same = pcall(function()
            if not rawCurrent() then return false end
            if type(checker) == "function" then
                for _, record in ipairs(held) do
                    if read(checker, "boolean", record.object) ~= false then return false end
                    for _, field in ipairs(record.fields) do
                        if read(checker, "boolean", rawget(record.object, field)) ~= false then return false end
                    end
                end
            end
            return rawCurrent()
        end)
        return ok and same == true
    end
    local function positive(value)
        value = clean(value, "number")
        if not capabilities() then error("expired") end
        return value and value > 0 and value <= 9007199254740991 and value % 1 == 0 and value or nil
    end
    local function array(object, nonempty)
        local count = #object
        local fields = {}
        for i = 1, math.min(count, 100) do fields[i] = i end
        local values = capture(object, fields, true)
        held[#held].length = count
        if not readable(held[#held]) or not clean(object, "table") or not capabilities() or
            count > 100 or held[#held].count ~= count or (nonempty and count == 0) then error("array") end
        local actual = 0
        for key in next, object do
            local id = positive(key)
            if not id or id > count then error("array") end
        end
        for _ in next, object do actual = actual + 1 end
        if actual ~= count then error("shape") end
        return values, count
    end
    local model, invalid, owner
    local ok = pcall(function()
        -- Hold source fields before their cleaners or caller predicates can reenter.
        local selected = capture(dungeon, { "quests", "key", "name" })
        if not readable(held[#held]) or not clean(dungeon, "table") or not clean(definitions, "table") or
            not clean(catalogue, "table") or not capabilities() then error("input") end
        local root = positive(rootTargetID)
        if not root then error("root") end
        local targets, count = array(selected.quests, true)
        local matches = 0
        for i = 1, count do
            local id = positive(targets[i])
            if not id then error("target") end
            if id == root then matches = matches + 1 end
        end
        if matches ~= 1 then error("membership") end
        local dungeonList, dc = array(catalogue, true)
        local member = 0
        for i = 1, dc do
            if rawequal(dungeonList[i], dungeon) then member = member + 1 end
        end
        if member ~= 1 then error("catalogue") end
        local nodes, seen, visiting, questSources, edges, consulted = {}, {}, {}, {}, 0, 0
        local function quest(id, isRoot)
            if questSources[id] then return questSources[id] end
            consulted = consulted + 1
            if consulted > 80 then error("nodes") end
            local slot = capture(definitions, { id })
            if not readable(held[#held]) then error("source") end
            local value = slot[id]
            if value == nil then
                questSources[id] = { missing = true }
                return questSources[id]
            end
            local fields = { "id", "name", "requires" }
            if isRoot then
                fields[#fields + 1] = "storyline"
                fields[#fields + 1] = "storylineGroups"
            end
            local source = capture(value, fields)
            if not readable(held[#held]) or not clean(value, "table") or not capabilities() or
                positive(source.id) ~= id then error("definition") end
            local name = clean(source.name, "string")
            if not capabilities() or not name or #name > 1024 or not name:find("%S") or name:find("%c") then error("name") end
            questSources[id] = source
            return source
        end
        local function edge()
            edges = edges + 1
            if edges > 320 then error("edges") end
        end
        local visit
        visit = function(id, depth, isRoot)
            if depth > 50 then error("depth") end
            if visiting[id] then error("cycle") end
            if seen[id] then return end
            visiting[id] = true
            local source = quest(id, isRoot)
            if not source.missing and source.requires ~= nil then
                local groups, size = array(source.requires)
                for index = 1, size do
                    local group = capture(groups[index], { "mode", "ids" })
                    if not readable(held[#held]) or not clean(groups[index], "table") or
                        not capabilities() then error("group") end
                    local mode = group.mode
                    if mode ~= nil then
                        mode = clean(mode, "string")
                        if not capabilities() or (mode ~= "active" and mode ~= "completed") then error("mode") end
                    end
                    local ids, length = array(group.ids, true)
                    for other = 1, length do
                        local parent = positive(ids[other])
                        if not parent then error("parent") end
                        edge()
                        visit(parent, depth + 1, false)
                    end
                end
            end
            visiting[id], seen[id] = nil, true
            if id ~= root and not source.missing then
                nodes[#nodes + 1] = { rootTargetID = root, questID = id, relation = "related" }
            end
        end
        visit(root, 0, true)
        local source = questSources[root]
        if not source or source.missing then error("missing root") end
        if source.storyline ~= nil and source.storylineGroups ~= nil then error("story") end
        local function story(value)
            local ids, length = array(value)
            for index = 1, length do
                local id = positive(ids[index])
                if not id then error("story id") end
                edge()
                visit(id, 1, false)
            end
        end
        if source.storyline ~= nil then story(source.storyline) end
        if source.storylineGroups ~= nil then
            local groups, size = array(source.storylineGroups)
            for index = 1, size do story(groups[index]) end
        end
        model = { rootTargetID = root, nodes = nodes }
        capture(model, { "rootTargetID", "nodes" }, true, modelHeld)
        local indexes = {}
        for index = 1, #nodes do
            indexes[index] = index
            capture(nodes[index], { "rootTargetID", "questID", "relation" }, true, modelHeld)
        end
        capture(nodes, indexes, true, modelHeld)
        if type(checker) == "function" and read(checker, "boolean", ownerCurrent) ~= false then error("owner") end
        owner = clean(ownerCurrent, "function")
        if ownerCurrent ~= nil and not owner then error("owner") end
        if not current() or (owner and read(owner, "boolean") ~= true) or not current() then error("expired") end
    end)
    if not ok then
        model = nil
        modelHeld = {}
        local usable, unchangedInvalid = pcall(function()
            if not current() then return false end
            -- A readable invalid graph still carries a negative ownership proof.
            if type(checker) == "function" and read(checker, "boolean", ownerCurrent) ~= false then return false end
            owner = clean(ownerCurrent, "function")
            if ownerCurrent ~= nil and not owner then return false end
            if owner and read(owner, "boolean") ~= true then return false end
            return current()
        end)
        if not usable or unchangedInvalid ~= true then return nil end
        invalid = true
    end
    owner = nil
    return invalid and nil or model, current, rawCurrent
end
