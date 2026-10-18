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
    local terms, snapshots, visited = {}, {}, {}
    local seen, nodes = { npc = {}, place = {} }, 0
    local function unavailable() return false end
    if type(clean) ~= "function" or type(folder) ~= "function" or not clean(quest, "table") then
        return terms, unavailable, unavailable
    end
    local function capture(object, fields, list, exact)
        local values, count = {}, 0
        for _, field in ipairs(fields) do values[field] = rawget(object, field) end
        if exact then for _ in next, object do count = count + 1 end end
        snapshots[#snapshots + 1] = { object = object, fields = fields, values = values,
            length = list and #object or nil, count = exact and count or nil }
    end
    local function capabilities()
        return addon.Clean == clean and addon.SearchFold == folder and issecretvalue == checker and
            addon.QuestSourceSearchTerms == provider
    end
    local function unchanged()
        local ok, result = pcall(function()
            if not capabilities() then return false end
            for _, snapshot in ipairs(snapshots) do
                if snapshot.length and #snapshot.object ~= snapshot.length then return false end
                if snapshot.count then
                    local count = 0; for _ in next, snapshot.object do count = count + 1; if count > snapshot.count then return false end end
                    if count ~= snapshot.count then return false end
                end
                for _, field in ipairs(snapshot.fields) do
                    if not rawequal(rawget(snapshot.object, field), snapshot.values[field]) then return false end
                end
            end
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
        if not value or #value > 2000 or not value:find("%S") or value:find("%c") or seen[kind][value] then return end
        local ok, folded = pcall(folder, value)
        if not ok or not clean(folded, "string") then return end
        seen[kind][value] = true
        local term = { text = value, kind = kind }
        terms[#terms + 1] = term
        capture(term, { "text", "kind" }, nil, true)
    end
    local fields = { "npcID", "objectID", "itemID", "mapID", "name", "zoneName", "locationName",
        "dropNPCID", "dropName", "dropSources", "containerSource", "reportedLocations" }
    local visit
    local function list(value, starter)
        value = clean(value, "table")
        if not value then return end
        local indexes = {}
        for index = 1, math.min(#value, 100) do indexes[#indexes + 1] = index end
        capture(value, indexes, true)
        for _, index in ipairs(indexes) do
            if nodes >= 1024 or #terms >= 1024 then break end
            visit(rawget(value, index), starter)
        end
    end
    visit = function(place, starter)
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
        if npc then add(rawget(place, "name"), "npc")
        elseif object then add(rawget(place, "name"), "place") end
        if npc or object or map then
            add(rawget(place, "zoneName"), "place")
            add(rawget(place, "locationName"), "place")
            -- A source may name its area only on its reported position records.
            list(rawget(place, "reportedLocations"), false)
        end
        if starter and item then
            if positive(rawget(place, "dropNPCID"), 4294967295) then add(rawget(place, "dropName"), "npc") end
            visit(rawget(place, "containerSource"), false)
            list(rawget(place, "dropSources"), false)
        end
    end
    capture(quest, { "start", "finish", "startAlternatives", "finishAlternatives" })
    visit(rawget(quest, "start"), true)
    visit(rawget(quest, "finish"), true)
    list(rawget(quest, "startAlternatives"), true)
    list(rawget(quest, "finishAlternatives"), true)
    local indexes = {}
    for index = 1, #terms do indexes[index] = index end
    capture(terms, indexes, true, true)
    if not current() then return {}, unavailable, unavailable end
    return terms, current, unchanged
end
