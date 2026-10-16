local _, addon = ...
local requested = {}

function addon.QuestDataResult(id, success)
    id = addon.Clean(id, "number")
    success = addon.Clean(success, "boolean")
    local request = id and requested[id]
    if not request or not request.pending or success == nil then return end
    request.pending = false
    if success or request.attempts >= 3 then request.finished = true; return end
    request.waiting = true
    local function retry()
        if requested[id] ~= request then return end
        request.waiting = false
        addon.Notify()
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(2, retry)
    else request.waiting = false end
end

function addon.Context()
    local quest = C_QuestLog or {}
    local function unitPart(fn, index, expected)
        if type(fn) ~= "function" then return nil end
        local values = { pcall(fn, "player") }
        if not values[1] then return nil end
        return addon.Clean(values[index + 1], expected)
    end
    return {
        level = addon.Read(UnitLevel, "number", "player"),
        faction = addon.Read(UnitFactionGroup, "string", "player"),
        class = unitPart(UnitClass, 2, "string"), race = unitPart(UnitRace, 3, "number"),
        completed = function(id) return addon.Read(quest.IsQuestFlaggedCompleted, "boolean", id) end,
        active = function(id) return addon.Read(quest.IsOnQuest, "boolean", id) end,
        ready = function(id) return addon.Read(quest.ReadyForTurnIn or quest.IsComplete, "boolean", id) end,
    }
end

function addon.QuestName(id)
    local title = addon.Read(C_QuestLog and C_QuestLog.GetTitleForQuestID, "string", id)
    if title and title ~= "" then return title end
    local request = requested[id]
    if (not request or not (request.pending or request.waiting or request.finished)) and
        C_QuestLog and type(C_QuestLog.RequestLoadQuestByID) == "function" then
        request = request or { attempts = 0 }
        requested[id] = request
        request.attempts, request.pending = request.attempts + 1, true
        local ok = pcall(C_QuestLog.RequestLoadQuestByID, id)
        if not ok then addon.QuestDataResult(id, false)
        elseif request.pending and C_Timer and type(C_Timer.After) == "function" then
            local attempt = request.attempts
            -- A missing result event must not leave this ID pending forever.
            C_Timer.After(10, function()
                if requested[id] == request and request.pending and request.attempts == attempt then
                    addon.QuestDataResult(id, false)
                end
            end)
        end
    end
    return (addon.quests[id] or {}).name or ("#" .. id)
end

function addon.DungeonName(d)
    if not d.instanceID then return d.name end
    local name = addon.Read(GetRealZoneText, "string", d.instanceID)
    return name and name ~= "" and name or d.name
end

function addon.DungeonArt(d)
    local journalID = d.instanceID and addon.Read(C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap, "number", d.instanceID)
    if journalID and type(EJ_GetInstanceInfo) == "function" then
        local values = { pcall(EJ_GetInstanceInfo, journalID) }
        local texture = values[1] and addon.Clean(values[7], "number")
        if texture then return texture end
    end
    return "Interface\\Icons\\INV_Misc_Map_01"
end

function addon.Description(id)
    id = addon.Clean(id, "number")
    if not id or id < 1 or id % 1 ~= 0 then return addon.L("NO_TEXT") end
    local locale = addon.Read(GetLocale, "string")
    local index = addon.Read(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, "number", id)
    local selectedID = addon.Read(C_QuestLog and C_QuestLog.GetSelectedQuest, "number")
    -- Vanilla's reader uses the current selection; never change it to fetch text.
    if selectedID == id and index and index >= 1 and index % 1 == 0 then
        local text = addon.Read(GetQuestLogQuestText, "string")
        if text and text ~= "" and #text <= 30000 then
            if locale and addon.char and type(addon.char.texts) == "table" then
                addon.char.texts[id] = { text = text, locale = locale }
            end
            return text
        end
    end
    local data = addon.char and addon.char.texts and addon.char.texts[id]
    if type(data) == "table" and locale and addon.Clean(data.locale, "string") == locale then
        local text = addon.Clean(data.text, "string")
        if text and text ~= "" and #text <= 30000 then return text end
    end
    return addon.L("NO_TEXT")
end

function addon.QuestObjectives(id)
    id = addon.Clean(id, "number")
    if not id or id < 1 or id % 1 ~= 0 then return nil end
    local objectives = addon.Read(C_QuestLog and C_QuestLog.GetQuestObjectives, "table", id)
    if not objectives or #objectives > 100 then return nil end
    local result = {}
    for i = 1, #objectives do
        local row = addon.Clean(objectives[i], "table")
        if not row then return nil end
        local text = addon.Clean(row.text, "string")
        local kind = addon.Clean(row.type, "string")
        local finished = addon.Clean(row.finished, "boolean")
        local fulfilled = addon.Clean(row.numFulfilled, "number")
        local required = addon.Clean(row.numRequired, "number")
        if not text or #text > 30000 or not kind or #kind > 200 or finished == nil
            or not fulfilled or fulfilled < 0 or not required or required < 0 then return nil end
        result[i] = { text = text, type = kind, finished = finished,
            numFulfilled = fulfilled, numRequired = required,
            objectiveType = addon.Clean(row.objectiveType, "number") }
    end
    return result
end

function addon.QuestRewards(id)
    local function integer(value, minimum, maximum)
        value = addon.Clean(value, "number")
        if value and value >= minimum and value % 1 == 0 and (not maximum or value <= maximum) then return value end
    end
    id = integer(id, 1)
    if not id then return nil end
    local quest = C_QuestLog or {}
    local function selected()
        return addon.Read(quest.GetSelectedQuest, "number") == id and
            integer(addon.Read(quest.GetLogIndexForQuestID, "number", id), 1) ~= nil
    end
    -- Vanilla reward readers use the current selection and take no quest ID.
    if not selected() then return nil end
    local rewards = integer(addon.Read(GetNumQuestLogRewards, "number"), 0, 100)
    local choices = integer(addon.Read(GetNumQuestLogChoices, "number"), 0, 100)
    if not rewards or not choices then return nil end
    local function items(count, getter)
        if count > 0 and type(getter) ~= "function" then return nil end
        local result = {}
        for i = 1, count do
            local ok, name, texture, amount, quality, usable, itemID = pcall(getter, i)
            if not ok then return nil end
            if type(issecretvalue) == "function" then
                local fields = { name, texture, amount, quality, usable, itemID }
                for j = 1, 6 do
                    local readable, secret = pcall(issecretvalue, fields[j])
                    if not readable or secret ~= false then return nil end
                end
            end
            name = addon.Clean(name, "string")
            amount, itemID = integer(amount, 1), integer(itemID, 1)
            if not name or name == "" or #name > 30000 or not amount or not itemID then return nil end
            local row = { id = itemID, name = name, count = amount }
            local icon = addon.Clean(texture, "string")
            if icon and icon ~= "" and #icon <= 1024 then row.texture = icon
            else row.texture = integer(texture, 1) end
            row.quality = integer(quality, 0)
            row.usable = addon.Clean(usable, "boolean")
            result[i] = row
        end
        return result
    end
    local fixed, choice = items(rewards, GetQuestLogRewardInfo), items(choices, GetQuestLogChoiceInfo)
    if not fixed or not choice then return nil end
    local money = addon.Read(GetQuestLogRewardMoney, "number")
    if money and money < 0 then money = nil end
    if not selected() then return nil end
    return { items = fixed, choices = choice, money = money }
end

function addon.QuestPortrait(id)
    local function positiveInteger(value)
        value = addon.Clean(value, "number")
        if value and value > 0 and value % 1 == 0 then return value end
    end
    id = positiveInteger(id)
    if not id then return nil end
    local quest = C_QuestLog or {}
    if addon.Read(quest.GetSelectedQuest, "number") ~= id then return nil end
    local index = positiveInteger(addon.Read(quest.GetLogIndexForQuestID, "number", id))
    if not index or type(quest.GetQuestLogPortraitGiver) ~= "function" then return nil end
    -- The optional argument is a log index, and the portrait is not an NPC ID.
    local ok, displayID, _, name = pcall(quest.GetQuestLogPortraitGiver, index)
    displayID = positiveInteger(displayID)
    if not ok or not displayID then return nil end
    if addon.Read(quest.GetSelectedQuest, "number") ~= id or
        positiveInteger(addon.Read(quest.GetLogIndexForQuestID, "number", id)) ~= index then return nil end
    local result = { displayID = displayID }
    name = addon.Clean(name, "string")
    if name and name ~= "" and #name <= 1024 then result.name = name end
    return result
end

function addon.CaptureQuestText()
    local id = addon.Read(GetQuestID, "number")
    local text = addon.Read(GetQuestText, "string")
    local locale = addon.Read(GetLocale, "string")
    if id and addon.quests[id] and text and text ~= "" and #text <= 30000 and locale and
        addon.char and type(addon.char.texts) == "table" then
        addon.char.texts[id] = { text = text, locale = locale }
    end
end

function addon.RestoreDB()
    local db = type(DungeonPrepDB) == "table" and DungeonPrepDB or {}
    local char = type(DungeonPrepCharDB) == "table" and DungeonPrepCharDB or {}
    if type(db.schema) ~= "nil" then
        local schema = addon.Clean(db.schema, "number")
        if not schema or schema < 1 or schema % 1 ~= 0 or schema > 1 then return false end
    end
    db.schema = 1
    db.locale = type(db.locale) == "string" and db.locale or "auto"
    if type(db.window) ~= "table" then db.window = {} end
    if type(char.texts) ~= "table" then char.texts = {} end
    if type(char.filters) ~= "table" then char.filters = {} end
    addon.db, addon.char = db, char
    DungeonPrepDB, DungeonPrepCharDB = db, char
    return true
end

function addon.ProbeClient()
    local build, _, _, interface = GetBuildInfo()
    local line = C_QuestLine or {}
    local result = { build = build, interface = interface, api = {}, questLines = {} }
    for _, entry in ipairs({ { "titles", C_QuestLog and C_QuestLog.GetTitleForQuestID },
        { "objectives", C_QuestLog and C_QuestLog.GetQuestObjectives }, { "lines", line.GetQuestLineInfo },
        { "lineQuests", line.GetQuestLineQuests }, { "offerText", GetQuestText }, { "logText", GetQuestLogQuestText } }) do
        result.api[entry[1]] = type(entry[2]) == "function"
    end
    for _, id in ipairs({ 166, 5728, 96393, 92753 }) do
        local info = addon.Read(line.GetQuestLineInfo, "table", id, nil, false)
        local lineID = info and addon.Clean(info.questLineID, "number")
        if lineID then
            local ids = addon.Read(line.GetQuestLineQuests, "table", lineID)
            local clean = {}
            for i = 1, math.min(100, ids and #ids or 0) do
                local qid = addon.Clean(ids[i], "number")
                if qid then clean[#clean + 1] = qid end
            end
            result.questLines[id] = { lineID = lineID, quests = clean }
        end
    end
    addon.char.probe = result
    print("DungeonPrep: client probe saved. No quest text or character identity exported.")
    return result
end
