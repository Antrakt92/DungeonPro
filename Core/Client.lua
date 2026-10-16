local _, addon = ...
local requested = {}

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
    if not requested[id] and C_QuestLog and type(C_QuestLog.RequestLoadQuestByID) == "function" then
        requested[id] = true
        pcall(C_QuestLog.RequestLoadQuestByID, id)
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
    local data = addon.char and addon.char.texts and addon.char.texts[id]
    if type(data) == "table" and data.locale == GetLocale() and type(data.text) == "string" then return data.text end
    return addon.L("NO_TEXT")
end

function addon.CaptureQuestText()
    local id = addon.Read(GetQuestID, "number")
    local text = addon.Read(GetQuestText, "string")
    if id and addon.quests[id] and text and #text <= 30000 then
        addon.char.texts[id] = { text = text, locale = GetLocale() }
    end
end

function addon.RestoreDB()
    local db = type(DungeonPrepDB) == "table" and DungeonPrepDB or {}
    local char = type(DungeonPrepCharDB) == "table" and DungeonPrepCharDB or {}
    if db.schema and (type(db.schema) ~= "number" or db.schema > 1) then return false end
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
