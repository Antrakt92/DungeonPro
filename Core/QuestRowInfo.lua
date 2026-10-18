local _, addon = ...
local Info = {}
addon.QuestRowInfo = Info

function Info.Get(quests, questID)
    local clean, read, checker, getter = addon.Clean, addon.Read, issecretvalue, Info.Get
    local function id(value)
        value = clean(value, "number")
        return value and value > 0 and value <= 9007199254740991 and value % 1 == 0 and value or nil
    end
    if not clean(quests, "table") or not id(questID) then return nil end
    local definition = clean(rawget(quests, questID), "table")
    if not definition then return nil end
    local fields, lengths, unknown = {}, {}, false
    local function keep(object, key)
        local value = rawget(object, key)
        if type(checker) == "function" and read(checker, "boolean", value) ~= false then unknown = true; return nil end
        fields[#fields + 1] = { object = object, key = key, value = value }
        return value
    end
    local function list(object, key)
        local value = keep(object, key)
        if value == nil then return nil, true end
        value = clean(value, "table")
        if not value then return nil, false end
        local length = #value
        lengths[#lengths + 1] = { object = value, length = length }
        if length > 100 then return nil, false end
        keep(value, length + 1)
        return value, true
    end
    local factions, factionValid = list(definition, "factions")
    local faction
    for index = 1, factions and #factions or 0 do
        local value = clean(keep(factions, index), "string")
        if value ~= "Alliance" and value ~= "Horde" then factionValid = false
        elseif faction and faction ~= value then factionValid = false
        else faction = value end
    end
    if not factionValid then faction = nil end

    local edges, found, valid = 0, false, true
    local function member(value)
        edges = edges + 1
        if edges > 320 then valid = false; return false end
        value = id(value)
        if not value then valid = false; return false end
        local source = keep(quests, value)
        if source ~= nil and not clean(source, "table") then valid = false
        elseif value ~= questID then found = true end
        return true
    end
    local requirements, requirementsValid = list(definition, "requires")
    if not requirementsValid then valid = false end
    for index = 1, requirements and #requirements or 0 do
        local group = clean(keep(requirements, index), "table")
        if not group then valid = false; break end
        local mode = keep(group, "mode")
        if mode ~= nil and mode ~= "completed" and mode ~= "active" then valid = false end
        local ids, idsValid = list(group, "ids")
        if not idsValid or not ids or #ids == 0 then valid = false; break end
        for other = 1, #ids do if not member(keep(ids, other)) then break end end
        if edges > 320 then break end
    end
    local ordered, orderedValid = list(definition, "storyline")
    local groups, groupsValid = list(definition, "storylineGroups")
    if not orderedValid or not groupsValid or (ordered and groups) then valid = false end
    for index = 1, ordered and #ordered or 0 do
        if edges > 320 or not member(keep(ordered, index)) then break end
    end
    for index = 1, groups and #groups or 0 do
        if edges > 320 then break end
        local group, groupValid = list(groups, index)
        if not group or not groupValid then valid = false; break end
        for other = 1, #group do if not member(keep(group, other)) then break end end
    end
    local function current()
        if addon.QuestRowInfo ~= Info or Info.Get ~= getter or addon.Clean ~= clean or addon.Read ~= read or issecretvalue ~= checker or unknown then return false end
        if clean(rawget(quests, questID), "table") ~= definition then return false end
        for _, field in ipairs(fields) do
            local value = rawget(field.object, field.key)
            if type(checker) == "function" and read(checker, "boolean", value) ~= false then return false end
            if value ~= field.value then return false end
        end
        for _, length in ipairs(lengths) do if #length.object ~= length.length then return false end end
        if not rawequal(rawget(addon, "QuestRowInfo"), Info) or not rawequal(rawget(Info, "Get"), getter) or
            not rawequal(rawget(addon, "Clean"), clean) or not rawequal(rawget(addon, "Read"), read) or
            not rawequal(rawget(_G, "issecretvalue"), checker) or not rawequal(rawget(quests, questID), definition) then return false end
        for _, field in ipairs(fields) do
            if not rawequal(rawget(field.object, field.key), field.value) then return false end
        end
        for _, length in ipairs(lengths) do if #length.object ~= length.length then return false end end
        return true
    end
    if not current() then return nil end
    return { faction = faction, chain = valid and found and true or false }, current
end
