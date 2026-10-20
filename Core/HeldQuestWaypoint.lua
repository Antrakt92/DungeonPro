local _, addon = ...
local function waypoint(id, ownerCurrent)
    local checker, rawQuest, rawMap, localeGetter = issecretvalue, C_QuestLog, C_Map, GetLocale
    local function clean(value, kind)
        if type(checker) == "function" then
            local ok, secret = pcall(checker, value)
            if not ok or secret ~= false then return nil end
        end
        if type(value) == kind then
            if kind == "number" and (value ~= value or value == math.huge or value == -math.huge) then return nil end
            return value
        end
    end
    local function integer(value)
        value = clean(value, "number")
        if value and value > 0 and value <= 9007199254740991 and value % 1 == 0 then return value end
    end
    local function mapInteger(value)
        value = clean(value, "number")
        if value and value > 0 and value <= 4294967295 and value % 1 == 0 then return value end
    end
    local function read(fn, kind, ...)
        if not clean(fn, "function") then return nil end
        local ok, value = pcall(fn, ...)
        if ok then return clean(value, kind) end
    end
    id = integer(id)
    local catalog, character = clean(addon.quests, "table"), clean(addon.char, "table")
    local definition = id and catalog and clean(rawget(catalog, id), "table")
    local quest, maps = clean(rawQuest, "table"), clean(rawMap, "table")
    local held = quest and clean(rawget(quest, "IsOnQuest"), "function")
    local indexGetter = quest and clean(rawget(quest, "GetLogIndexForQuestID"), "function")
    local nextGetter = quest and clean(rawget(quest, "GetNextWaypoint"), "function")
    local positionGetter = quest and clean(rawget(quest, "GetNextWaypointForMap"), "function")
    local rawTextGetter = quest and rawget(quest, "GetNextWaypointText")
    local textGetter = clean(rawTextGetter, "function")
    local mapGetter = maps and clean(rawget(maps, "GetMapInfo"), "function")
    local scope = clean(ownerCurrent, "function")
    if not id or not catalog or not character or not definition or integer(rawget(definition, "id")) ~= id or
        not quest or not maps or not held or not indexGetter or not nextGetter or not positionGetter or not mapGetter or
        not clean(localeGetter, "function") or (type(ownerCurrent) ~= "nil" and not scope) then return nil end
    local acceptedInfo, acceptedMap
    local function identities()
        local ok, same = pcall(function()
            return addon.HeldQuestWaypoint == waypoint and addon.quests == catalog and rawget(catalog, id) == definition and
                rawget(definition, "id") == id and addon.char == character and issecretvalue == checker and
                C_QuestLog == rawQuest and C_Map == rawMap and GetLocale == localeGetter and
                rawget(quest, "IsOnQuest") == held and rawget(quest, "GetLogIndexForQuestID") == indexGetter and
                rawget(quest, "GetNextWaypoint") == nextGetter and rawget(quest, "GetNextWaypointForMap") == positionGetter and
                rawget(quest, "GetNextWaypointText") == rawTextGetter and rawget(maps, "GetMapInfo") == mapGetter and
                (not acceptedInfo or rawget(acceptedInfo, "mapID") == acceptedMap)
        end)
        return ok and same == true
    end
    if not identities() or read(held, "boolean", id) ~= true or not identities() then return nil end
    local index = integer(read(indexGetter, "number", id))
    local locale = read(localeGetter, "string")
    if not index or not locale or #locale > 64 or not locale:find("%S") or not identities() then return nil end
    local function current()
        if not identities() or (scope and read(scope, "boolean") ~= true) or not identities() then return false end
        if read(held, "boolean", id) ~= true or not identities() then return false end
        if integer(read(indexGetter, "number", id)) ~= index or not identities() then return false end
        if read(localeGetter, "string") ~= locale or not identities() then return false end
        if read(held, "boolean", id) ~= true or not identities() then return false end
        -- Native ownership reads may have invalidated the caller since its first check.
        if scope and read(scope, "boolean") ~= true then return false end
        return identities()
    end
    if not current() then return nil end
    -- Direct waypoint coordinates are deliberately ignored; only map candidate is used.
    local mapID = mapInteger(read(nextGetter, "number", id))
    if not mapID or not current() then return nil end
    local info = read(mapGetter, "table", mapID)
    if not info or not current() then return nil end
    local infoID = mapInteger(rawget(info, "mapID"))
    if infoID ~= mapID or not current() then return nil end
    acceptedInfo, acceptedMap = info, mapID
    local ok, rawX, rawY = pcall(positionGetter, id, mapID)
    if not ok then return nil end
    local x, y = clean(rawX, "number"), clean(rawY, "number")
    if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 or not current() then return nil end
    local text = textGetter and read(textGetter, "string", id)
    if text and (#text > 1024 or not text:find("%S")) then text = nil end
    if not current() then return nil end
    if integer(read(nextGetter, "number", id)) ~= mapID or not current() then return nil end
    local freshInfoID = mapInteger(rawget(info, "mapID"))
    if freshInfoID ~= mapID or not current() then return nil end
    return { source = "clientWaypoint", questID = id, uiMapID = mapID, normalizedX = x, normalizedY = y, text = text }
end
addon.HeldQuestWaypoint = waypoint
