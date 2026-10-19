local _, addon = ...
local fold = addon.searchCaseFold

-- Match canonical decimal IDs without accepting rounded integers or Lua numeric syntax.
function addon.SearchQuestID(value)
    value = addon.Clean(value, "string")
    if not value or #value > 16384 then return nil end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if #value > 16 or not value:match("^[1-9][0-9]*$") then return nil end
    if #value == 16 and value > "9007199254740991" then return nil end
    return tonumber(value)
end

-- Only search keys are folded. Display strings and their UTF-8 byte sequences stay intact.
function addon.SearchFold(value)
    value = addon.Clean(value, "string")
    if not value or #value > 16384 then return nil end
    local result, i, bytes = {}, 1, 0
    while i <= #value do
        local start, byte = i, value:byte(i)
        local size = byte < 128 and 1 or byte >= 194 and byte <= 223 and 2 or
            byte >= 224 and byte <= 239 and 3 or byte >= 240 and byte <= 244 and 4
        if not size or i + size - 1 > #value then return nil end
        local point = byte % (size == 1 and 128 or 2 ^ (7 - size))
        for offset = 1, size - 1 do
            local nextByte = value:byte(i + offset)
            if nextByte < 128 or nextByte > 191 then return nil end
            if offset == 1 and ((byte == 224 and nextByte < 160) or (byte == 237 and nextByte > 159) or
                (byte == 240 and nextByte < 144) or (byte == 244 and nextByte > 143)) then return nil end
            point = point * 64 + nextByte - 128
        end
        i = i + size
        local folded = fold[point] or value:sub(start, i - 1)
        bytes = bytes + #folded
        if bytes > 16384 then return nil end
        result[#result + 1] = folded
    end
    return table.concat(result)
end

-- Static names only: 100 entries per list, 1024 visited places/terms, 2000 bytes per term.
-- The callback-free final proof owns captured snapshots, not newly read raw values.
-- Callers display/fold validated terms; snapshot errors fail closed.
function addon.QuestSourceSearchTerms(quest)
    local clean, folder, checker = addon.Clean, addon.SearchFold, issecretvalue
    local provider = addon.QuestSourceSearchTerms
    local sourceName = addon.SourceName
    local areaName = addon.SourceAreaName
    local terms, snapshots, visited, sources, aliases, areas = {}, {}, {}, {}, {}, {}
    local seen, nodes = { npc = {}, place = {}, objective = {} }, 0
    local function unavailable() return false end
    if type(clean) ~= "function" or type(folder) ~= "function" then
        return terms, unavailable, unavailable
    end
    local function capture(object, fields, list, exact, bound)
        local values, count = {}, 0
        for _, field in ipairs(fields) do values[field] = rawget(object, field) end
        if exact then for _ in next, object do count = count + 1; if bound and count >= bound then break end end end
        snapshots[#snapshots + 1] = { object = object, fields = fields, values = values,
            length = list and #object or nil, count = exact and count or nil, bound = bound }
    end
    -- Hold the parent slot first; authorize each table before structural reads.
    local goalInput = {}
    local function ordinaryGoal(value)
        if type(checker) == "function" then
            local ok, restricted = pcall(checker, value)
            if not ok or restricted ~= false then return false end
        end
        return addon.Clean == clean and addon.SearchFold == folder and issecretvalue == checker and
            addon.QuestSourceSearchTerms == provider and addon.SourceName == sourceName and addon.SourceAreaName == areaName
    end
    local goalCaptured = pcall(function()
        capture(quest, { "objectiveKills" })
        local value = rawget(quest, "objectiveKills")
        goalInput.value = value
        if not ordinaryGoal(quest) or not ordinaryGoal(value) or
            not rawequal(rawget(quest, "objectiveKills"), value) then error("expired goal input") end
        if type(value) ~= "table" then return end
        local length, indexes = #value, {}
        for index = 1, math.min(length, 100) do indexes[index] = index end
        capture(value, indexes, true, true, 102)
        goalInput.length, goalInput.count, goalInput.entries = length, snapshots[#snapshots].count, {}
        for _, index in ipairs(indexes) do
            local entry = rawget(value, index)
            local held = { entry = entry }
            goalInput.entries[index] = held
            if not ordinaryGoal(entry) or not rawequal(rawget(value, index), entry) or
                not rawequal(rawget(quest, "objectiveKills"), value) then error("expired goal member") end
            if type(entry) == "table" then
                capture(entry, { "npcID", "name", "objectID", "itemID", "dropNPCID" })
                held.values = snapshots[#snapshots].values
            end
        end
    end)
    if not goalCaptured or not clean(quest, "table") then return terms, unavailable, unavailable end
    local function capabilities()
        return addon.Clean == clean and addon.SearchFold == folder and issecretvalue == checker and
            addon.QuestSourceSearchTerms == provider and addon.SourceName == sourceName and addon.SourceAreaName == areaName
    end
    local function unchanged()
        local ok, result = pcall(function()
            if not capabilities() then return false end
            for _, snapshot in ipairs(snapshots) do
                if snapshot.length and #snapshot.object ~= snapshot.length then return false end
                if snapshot.count then
                    local count = 0
                    for _ in next, snapshot.object do
                        count = count + 1
                        if count > snapshot.count then return false end
                        if snapshot.bound and count >= snapshot.bound then break end
                    end
                    if count ~= snapshot.count then return false end
                end
                for _, field in ipairs(snapshot.fields) do
                    if not rawequal(rawget(snapshot.object, field), snapshot.values[field]) then return false end
                end
            end
            for _, alias in ipairs(aliases) do if alias.raw() ~= true then return false end end
            return capabilities()
        end)
        return ok and result == true
    end
    local function current()
        local ok, result = pcall(function()
            if not capabilities() then return false end
            if type(checker) == "function" then
                for _, snapshot in ipairs(snapshots) do
                    local readable, restricted = pcall(checker, snapshot.object)
                    if not readable or restricted ~= false then return false end
                    for _, field in ipairs(snapshot.fields) do
                        readable, restricted = pcall(checker, rawget(snapshot.object, field))
                        if not readable or restricted ~= false then return false end
                    end
                end
            end
            for _, alias in ipairs(aliases) do if alias.current() ~= true then return false end end
            return unchanged()
        end)
        return ok and result == true
    end
    local function positive(value, maximum)
        value = clean(value, "number")
        return value and value > 0 and value <= maximum and value % 1 == 0 and value
    end
    local function add(value, kind)
        if #terms >= 1024 then return end
        value = clean(value, "string")
        if not value or #value > 2000 or not value:find("%S") or value:find("%c") then return end
        if seen[kind][value] then return value end
        local ok, folded = pcall(folder, value)
        if not ok or not clean(folded, "string") then return end
        seen[kind][value] = true
        local term = { text = value, kind = kind }
        terms[#terms + 1] = term
        capture(term, { "text", "kind" }, nil, true)
        return value
    end
    local fields = { "npcID", "objectID", "itemID", "mapID", "name", "zoneName", "locationName",
        "dropNPCID", "dropName", "dropSources", "containerSource", "reportedLocations" }
    local visit
    local function list(value, starter, objectOnly)
        value = clean(value, "table")
        if not value then return end
        local indexes = {}
        for index = 1, math.min(#value, 100) do indexes[#indexes + 1] = index end
        capture(value, indexes, true)
        for _, index in ipairs(indexes) do
            if nodes >= 1024 or #terms >= 1024 then break end
            visit(rawget(value, index), starter, objectOnly)
        end
    end
    visit = function(place, starter, objectOnly)
        place = clean(place, "table")
        if not place or visited[place] or nodes >= 1024 or #terms >= 1024 then return end
        visited[place], nodes = true, nodes + 1
        capture(place, fields)
        -- Optional identities are compared only after their readability is known.
        if type(checker) == "function" then
            for _, field in ipairs(fields) do
                local ok, restricted = pcall(checker, rawget(place, field))
                if not ok or restricted ~= false then return end
            end
        end
        local rawNPC, rawObject, rawItem = rawget(place, "npcID"), rawget(place, "objectID"), rawget(place, "itemID")
        local function absent(value)
            if type(checker) == "function" then
                local ok, restricted = pcall(checker, value)
                if not ok or restricted ~= false then return false end
            end
            return value == nil
        end
        local npc = positive(rawNPC, 4294967295) and absent(rawObject) and absent(rawItem)
        local object = positive(rawObject, 4294967295) and absent(rawNPC) and absent(rawItem)
        local item = positive(rawItem, 4294967295) and absent(rawNPC) and absent(rawObject)
        local map = positive(rawget(place, "mapID"), 9007199254740991)
        if objectOnly and not object then return end
        if npc then add(rawget(place, "name"), "npc")
        elseif object then add(rawget(place, "name"), "place") end
        if npc or object then sources[#sources + 1] = { place = place, kind = npc and "npc" or "place" } end
        if npc or object or map then
            local zone = add(rawget(place, "zoneName"), "place")
            local location = add(rawget(place, "locationName"), "place")
            if zone then areas[#areas + 1] = zone end
            if location then areas[#areas + 1] = location end
            -- A source may name its area only on its reported position records.
            if not objectOnly then list(rawget(place, "reportedLocations"), false) end
        end
        if starter and item then
            if positive(rawget(place, "dropNPCID"), 4294967295) then add(rawget(place, "dropName"), "npc") end
            visit(rawget(place, "containerSource"), false)
            list(rawget(place, "dropSources"), false)
        end
    end
    capture(quest, { "start", "finish", "startAlternatives", "finishAlternatives", "objectiveItems", "objectiveItemSources" })
    visit(rawget(quest, "start"), true)
    visit(rawget(quest, "finish"), true)
    list(rawget(quest, "startAlternatives"), true)
    list(rawget(quest, "finishAlternatives"), true)
    local function objectiveSources()
        local items = clean(rawget(quest, "objectiveItems"), "table")
        local sources = clean(rawget(quest, "objectiveItemSources"), "table")
        if not items or not sources or #items > 100 or #sources > 100 then return end
        local function indexes(value)
            local result = {}; for index = 1, #value do result[index] = index end
            capture(value, result, true)
            return result
        end
        local bound, seenItems, routes = {}, {}, {}
        for _, index in ipairs(indexes(items)) do
            local entry = clean(rawget(items, index), "table")
            if entry then
                capture(entry, { "itemID" })
                local id = positive(rawget(entry, "itemID"), 9007199254740991)
                if id then bound[id] = bound[id] == nil end
            end
        end
        for _, index in ipairs(indexes(sources)) do
            local entry = clean(rawget(sources, index), "table")
            if not entry then return end
            capture(entry, { "itemID", "containerSources" })
            local id = positive(rawget(entry, "itemID"), 9007199254740991)
            local containers = clean(rawget(entry, "containerSources"), "table")
            if not id or not bound[id] or seenItems[id] or not containers then return end
            seenItems[id], routes[#routes + 1] = true, containers
        end
        -- Search only the typed object labels tied to this quest's listed items.
        -- Coordinates and source URLs remain the responsibility of their consumers.
        for _, containers in ipairs(routes) do list(containers, false, true) end
    end
    objectiveSources()
    -- Preserve every canonical term first; reviewed aliases share the remaining budget.
    if type(sourceName) == "function" then
        local memo = { npc = {}, place = {} }
        for _, source in ipairs(sources) do
            if #terms >= 1024 then break end
            local id = positive(rawget(source.place, source.kind == "npc" and "npcID" or "objectID"), 4294967295)
            local canonical = clean(rawget(source.place, "name"), "string")
            local bucket = id and memo[source.kind][id]
            local cached = canonical and bucket and bucket[canonical]
            if not cached then
                local ok, name, proof, raw = pcall(sourceName, source.place)
                if ok and type(proof) == "function" and type(raw) == "function" then
                    cached = { name = name, current = proof, raw = raw }
                    aliases[#aliases + 1] = cached
                    if id and canonical then
                        bucket = bucket or {}; memo[source.kind][id] = bucket; bucket[canonical] = cached
                    end
                end
            end
            -- Every physical source remains in the snapshots even when its label shares a lookup.
            if cached and cached.name ~= nil then add(cached.name, source.kind) end
        end
    end
    if type(areaName) == "function" then
        local memo = {}
        for _, area in ipairs(areas) do
            if #terms >= 1024 then break end
            local canonical = clean(area,"string")
            if canonical and not memo[canonical] then
                local ok, name, proof, raw = pcall(areaName,canonical)
                if ok and type(proof) == "function" and type(raw) == "function" then
                    memo[canonical] = true
                    aliases[#aliases + 1] = { current = proof, raw = raw }
                    if name ~= nil then add(name,"place") end
                end
            end
        end
    end
    -- Existing source and area terms keep their full order and budget.
    -- Goals add name-only matches in the remaining slots; they never supply routes.
    local function objectiveTargets()
        local list = clean(goalInput.value, "table")
        if not list or goalInput.length > 100 or goalInput.count ~= goalInput.length then return end
        local goals, ids = {}, {}
        for index = 1, goalInput.length do
            local held = goalInput.entries[index]
            local entry = held and clean(held.entry, "table")
            local values = entry and held.values
            if not values then return end
            local id = positive(values.npcID, 4294967295)
            local name = clean(values.name, "string")
            if not id or ids[id] or not name or #name > 2000 or not name:find("%S") or name:find("%c") then return end
            for _, field in ipairs({ "objectID", "itemID", "dropNPCID" }) do
                if type(checker) == "function" then
                    local ok, restricted = pcall(checker, values[field])
                    if not ok or restricted ~= false then return end
                end
                if values[field] ~= nil then return end
            end
            local ok, folded = pcall(folder, name)
            if not ok or not clean(folded, "string") then return end
            ids[id] = true
            goals[#goals + 1] = { entry = entry, id = id, name = name }
        end
        local emitted = {}
        for _, goal in ipairs(goals) do
            if #terms >= 1024 or nodes >= 1024 then break end
            nodes = nodes + 1
            if add(goal.name, "objective") then emitted[#emitted + 1] = goal end
        end
        if type(sourceName) ~= "function" then return end
        local memo = {}
        for _, goal in ipairs(emitted) do
            if #terms >= 1024 then break end
            local bucket = memo[goal.id]
            local cached = bucket and bucket[goal.name]
            if not cached then
                local ok, name, proof, raw = pcall(sourceName, goal.entry)
                if ok and type(proof) == "function" and type(raw) == "function" then
                    cached = { name = name, current = proof, raw = raw }
                    aliases[#aliases + 1] = cached
                    bucket = bucket or {}; memo[goal.id] = bucket; bucket[goal.name] = cached
                end
            end
            if cached then add(cached.name, "objective") end
        end
    end
    objectiveTargets()
    local indexes = {}
    for index = 1, #terms do indexes[index] = index end
    capture(terms, indexes, true, true)
    if not current() then return {}, unavailable, unavailable end
    return terms, current, unchanged
end
