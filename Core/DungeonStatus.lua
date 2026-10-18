local _, addon = ...
local Status = {}
addon.DungeonStatus = Status

-- This describes the character's eligible listed quests, never every quest
-- available in the game. Optional inspection filters do not affect the result.
function Status.Get(dungeon, engine)
    local clean, read, checker, getterOwner = addon.Clean, addon.Read, issecretvalue, Status.Get
    dungeon, engine = clean(dungeon, "table"), clean(engine, "table")
    local quests = engine and clean(rawget(engine, "quests"), "table")
    local context = engine and clean(rawget(engine, "context"), "table")
    local cache = engine and clean(rawget(engine, "states"), "table")
    local planner = clean(addon.Planner, "table")
    local eligible = planner and clean(rawget(planner, "Eligible"), "function")
    local getter = engine and clean(rawget(engine, "State"), "function")
    local fresh = engine and clean(rawget(engine, "Current"), "function")
    local ids = dungeon and clean(rawget(dungeon, "quests"), "table")
    if not dungeon or not engine or not quests or not context or not eligible or not getter or not fresh or not ids then return nil, "input" end
    local fieldObjects, fieldKeys, fieldValues, fieldCount = {}, {}, {}, 0
    local building = true
    local function keep(object, key)
        if fieldCount >= 4000 then return nil, false end
        local value = rawget(object, key)
        if type(checker) == "function" and read(checker, "boolean", value) ~= false then return nil, false end
        fieldCount = fieldCount + 1
        fieldObjects[fieldCount], fieldKeys[fieldCount], fieldValues[fieldCount] = object, key, value
        return value, true
    end
    local function same(value, previous)
        if type(checker) == "function" and read(checker, "boolean", value) ~= false then return false end
        return value == previous
    end
    local function current()
        if addon.DungeonStatus ~= Status or Status.Get ~= getterOwner or addon.Clean ~= clean or addon.Read ~= read or issecretvalue ~= checker or
            not same(addon.Planner, planner) or not same(rawget(planner, "Eligible"), eligible) or
            not same(rawget(engine, "State"), getter) or not same(rawget(engine, "Current"), fresh) or
            not same(rawget(engine, "quests"), quests) or not same(rawget(engine, "context"), context) or
            not same(rawget(engine, "states"), cache) then return false end
        if read(fresh, "boolean", engine) ~= true then return false end
        if addon.DungeonStatus ~= Status or Status.Get ~= getterOwner or addon.Clean ~= clean or addon.Read ~= read or issecretvalue ~= checker or
            not same(addon.Planner, planner) or not same(rawget(planner, "Eligible"), eligible) or
            not same(rawget(engine, "State"), getter) or not same(rawget(engine, "Current"), fresh) or
            not same(rawget(engine, "quests"), quests) or not same(rawget(engine, "context"), context) or
            not same(rawget(engine, "states"), cache) then return false end
        if not building then
            for index = 1, fieldCount do
                if not same(rawget(fieldObjects[index], fieldKeys[index]), fieldValues[index]) then return false end
            end
        end
        if not rawequal(rawget(addon, "DungeonStatus"), Status) or not rawequal(rawget(Status, "Get"), getterOwner) or not rawequal(rawget(addon, "Clean"), clean) or
            not rawequal(rawget(addon, "Read"), read) or not rawequal(rawget(_G, "issecretvalue"), checker) or
            not rawequal(rawget(addon, "Planner"), planner) or not rawequal(rawget(planner, "Eligible"), eligible) or
            not rawequal(rawget(engine, "State"), getter) or not rawequal(rawget(engine, "Current"), fresh) or
            not rawequal(rawget(engine, "quests"), quests) or not rawequal(rawget(engine, "context"), context) or
            not rawequal(rawget(engine, "states"), cache) then return false end
        if not building then
            for index = 1, fieldCount do
                if not rawequal(rawget(fieldObjects[index], fieldKeys[index]), fieldValues[index]) then return false end
            end
        end
        return true
    end
    for _, key in ipairs({ "quests", "coverage" }) do local _, ok = keep(dungeon, key); if not ok then return nil, "source" end end
    for _, key in ipairs({ "level", "faction", "class", "current", "completed", "active", "ready" }) do
        local _, ok = keep(context, key); if not ok then return nil, "context" end
    end
    local count = 0
    for key in pairs(ids) do
        key = clean(key, "number")
        if not key or key % 1 ~= 0 or key < 1 or key > 200 then return nil, "source" end
        count = count + 1
    end
    if count > 200 or count ~= #ids then return nil, "source" end
    keep(ids, count + 1)
    local result = { listed = 0, eligible = 0, excluded = 0, completed = 0, unfinished = 0, counts = {},
        partial = clean(rawget(dungeon, "coverage"), "string") ~= "reviewed", allLevelBlocked = false }
    local seen, levelBlocked = {}, 0
    local sourceSeen, definitions, sourceCount = {}, {}, 0
    local function captureDefinitions(first)
        local pending, queued, nextIndex = { first }, { [first] = true }, 1
        while nextIndex <= #pending do
            local questID = pending[nextIndex]; nextIndex = nextIndex + 1
            if not sourceSeen[questID] then
                sourceCount = sourceCount + 1
                if sourceCount > 200 then return false end
                sourceSeen[questID] = true
                local definition, readable = keep(quests, questID)
                definition = clean(definition, "table")
                if not readable then return false end
                definitions[questID] = definition
                if definition then
                    for _, field in ipairs({ "minLevel", "requirementsKnown", "requires", "factions", "classes" }) do
                        local value, valid = keep(definition, field)
                        if not valid then return false end
                        if (field == "factions" or field == "classes") and value ~= nil then
                            local list = clean(value, "table")
                            if not list or #list > 100 then return false end
                            for item = 1, #list + 1 do local _, allowed = keep(list, item); if not allowed then return false end end
                        elseif field == "requires" and value ~= nil then
                            local groups = clean(value, "table")
                            if not groups or #groups > 100 then return false end
                            for groupIndex = 1, #groups + 1 do
                                local group, allowed = keep(groups, groupIndex)
                                if not allowed then return false end
                                if groupIndex <= #groups then
                                    group = clean(group, "table")
                                    if not group then return false end
                                    local _, modeAllowed = keep(group, "mode")
                                    local members, membersAllowed = keep(group, "ids")
                                    members = clean(members, "table")
                                    if not modeAllowed or not membersAllowed or not members or #members > 100 then return false end
                                    for member = 1, #members + 1 do
                                        local parent, memberAllowed = keep(members, member)
                                        if not memberAllowed then return false end
                                        if member <= #members then
                                            parent = clean(parent, "number")
                                            if not parent or parent < 1 or parent > 9007199254740991 or parent % 1 ~= 0 then return false end
                                            if not sourceSeen[parent] and not queued[parent] then
                                                if #pending >= 200 then return false end
                                                queued[parent] = true; pending[#pending + 1] = parent
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return true
    end
    for index = 1, count do
        local questID, ok = keep(ids, index)
        questID = clean(questID, "number")
        if not ok or not questID or questID < 1 or questID > 9007199254740991 or questID % 1 ~= 0 then return nil, "source" end
        if not seen[questID] then
            seen[questID] = true
            result.listed = result.listed + 1
            if not captureDefinitions(questID) then return nil, "source" end
            local definition = definitions[questID]
            if not current() then return nil, "expired" end
            local state = read(getter, "table", engine, questID)
            if not state or not current() then return nil, "expired" end
            if cache then
                local cached, readable = keep(cache, questID)
                if not readable or cached ~= state then return nil, "state" end
            end
            for _, key in ipairs({ "status", "reason", "completedHistory" }) do
                local _, valid = keep(state, key); if not valid then return nil, "state" end
            end
            local kind, reason = clean(rawget(state, "status"), "string"), clean(rawget(state, "reason"), "string")
            local completed = clean(rawget(state, "completedHistory"), "boolean") == true
            local relevant = definition and read(eligible, "boolean", definition, context)
            if not current() then return nil, "expired" end
            local live = kind == "ACTIVE" or kind == "READY"
            if not live and (relevant == false or kind == "UNAVAILABLE") then result.excluded = result.excluded + 1
            else
                if not live and (relevant ~= true or (kind == "COMPLETED" and not completed)) then kind, reason = "UNKNOWN", "character" end
                if kind ~= "COMPLETED" and kind ~= "READY" and kind ~= "AVAILABLE" and kind ~= "ACTIVE" and
                    kind ~= "UNKNOWN" and kind ~= "LOCKED" then kind, reason = "UNKNOWN", "state" end
                result.eligible = result.eligible + 1
                result.counts[kind] = (result.counts[kind] or 0) + 1
                if kind == "COMPLETED" then result.completed = result.completed + 1
                else
                    result.unfinished = result.unfinished + 1
                    if kind == "LOCKED" and reason == "level" then levelBlocked = levelBlocked + 1 end
                end
            end
        end
    end
    -- The DTO stays private during construction. Validate the complete source
    -- once before publication, then retain that complete proof for every caller.
    building = false
    if not current() then return nil, "expired" end
    result.status = "UNAVAILABLE"
    if result.eligible > 0 then
        if result.completed == result.eligible then result.status = "COMPLETED"
        else
            for _, kind in ipairs({ "READY", "AVAILABLE", "ACTIVE", "UNKNOWN", "LOCKED" }) do
                if result.counts[kind] then result.status = kind; break end
            end
        end
    end
    result.allLevelBlocked = result.unfinished > 0 and levelBlocked == result.unfinished
    if result.status == "LOCKED" and result.allLevelBlocked then result.reason = "level" end
    return result, current
end
