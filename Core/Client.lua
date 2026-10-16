local _, addon = ...
local requested, requestedItems = {}, {}
local offerGeneration, currentOffers = {}, nil
local dialogueGeneration, dialogueReward = {}, nil

local function dialogueInteger(value, minimum, maximum)
    value = addon.Clean(value, "number")
    if value and value >= minimum and value % 1 == 0 and (not maximum or value <= maximum) then return value end
end

local function dialogueScope()
    local id = dialogueInteger(addon.Read(GetQuestID, "number"), 1)
    local player = addon.Read(UnitGUID, "string", "player")
    local locale = addon.Read(GetLocale, "string")
    if not id or not addon.quests[id] or not player or player == "" or #player > 256 or
        not locale or locale == "" or #locale > 32 then return nil end
    return id, player, locale
end

local function clearDialogueReward()
    dialogueGeneration, dialogueReward = {}, nil
end

local function currentDialogueReward(snapshot)
    if snapshot ~= dialogueReward or snapshot.generation ~= dialogueGeneration then return false end
    local id, player, locale = dialogueScope()
    local current = snapshot == dialogueReward and snapshot.generation == dialogueGeneration and
        id == snapshot.id and player == snapshot.player and locale == snapshot.locale
    if not current and snapshot == dialogueReward then clearDialogueReward() end
    return current
end

local function liveDialogueReward(snapshot)
    -- A matching native quest ID can outlive its closed detail window.
    local shown = addon.Read(function() return QuestFrame:IsShown() end, "boolean") == true and
        addon.Read(function() return QuestFrameDetailPanel:IsShown() end, "boolean") == true
    if shown and currentDialogueReward(snapshot) then return true end
    if dialogueReward == snapshot then clearDialogueReward() end
end

function addon.DialogueRewardEvent(event)
    event = addon.Clean(event, "string")
    if event == "QUEST_DETAIL" then
        clearDialogueReward()
        local generation = dialogueGeneration
        local id, player, locale = dialogueScope()
        if not id or generation ~= dialogueGeneration then return end
        local snapshot = { id = id, player = player, locale = locale, generation = generation }
        dialogueReward = snapshot
        currentDialogueReward(snapshot)
    elseif event == "QUEST_FINISHED" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" or
        event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" or
        event == "GOSSIP_SHOW" or event == "GOSSIP_CLOSED" or event == "GOSSIP_OPTIONS_REFRESHED" or
        event == "QUEST_GREETING" or event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_ENTERING_WORLD" or
        event == "PLAYER_LOGOUT" then
        clearDialogueReward()
    end
end

function addon.DialogueRewards(id)
    id = dialogueInteger(id, 1)
    local snapshot = dialogueReward
    if not id or not snapshot or snapshot.id ~= id or not currentDialogueReward(snapshot) then return nil end
    local function live()
        return liveDialogueReward(snapshot)
    end
    if not live() then return nil end
    local visible = addon.Read(C_QuestLog and C_QuestLog.ShouldShowQuestRewards, "boolean", id)
    if not live() then return nil end
    if visible == nil then return nil end
    if not visible then return { hidden = true, source = "dialogue" } end
    local rewards = dialogueInteger(addon.Read(GetNumQuestRewards, "number"), 0, 100)
    if not live() then return nil end
    local choices = dialogueInteger(addon.Read(GetNumQuestChoices, "number"), 0, 100)
    if not rewards or not choices or not live() then return nil end
    local function items(kind, count)
        if count > 0 and type(GetQuestItemInfo) ~= "function" then return nil end
        local result = {}
        for i = 1, count do
            local ok, name, texture, amount, quality, usable, itemID = pcall(GetQuestItemInfo, kind, i)
            if not ok or not live() then return nil end
            if type(issecretvalue) == "function" then
                local fields = { name, texture, amount, quality, usable, itemID }
                for j = 1, 6 do
                    local readable, secret = pcall(issecretvalue, fields[j])
                    if not readable or secret ~= false then return nil end
                end
            end
            name = addon.Clean(name, "string")
            amount, itemID = dialogueInteger(amount, 1), dialogueInteger(itemID, 1)
            if not name or name == "" or #name > 30000 or not amount or not itemID then return nil end
            local row = { id = itemID, name = name, count = amount }
            local icon = addon.Clean(texture, "string")
            if icon and icon ~= "" and #icon <= 1024 then row.texture = icon
            else row.texture = dialogueInteger(texture, 1) end
            row.quality = dialogueInteger(quality, 0)
            row.usable = addon.Clean(usable, "boolean")
            result[i] = row
        end
        return result
    end
    local fixed = items("reward", rewards)
    if not fixed then return nil end
    local choice = items("choice", choices)
    if not choice then return nil end
    local money = dialogueInteger(addon.Read(GetRewardMoney, "number"), 0)
    if not live() then return nil end
    local xp = dialogueInteger(addon.Read(GetRewardXP, "number"), 0)
    if not live() then return nil end
    return { items = fixed, choices = choice, money = money, xp = xp, source = "dialogue" }
end

function addon.DialogueObjectiveText(id)
    id = dialogueInteger(id, 1)
    local snapshot = dialogueReward
    if not id or not snapshot or snapshot.id ~= id or not currentDialogueReward(snapshot) or
        not liveDialogueReward(snapshot) then return nil end
    -- Offered summary text is separate from accepted quest objective counters.
    local text = addon.Read(GetObjectiveText, "string")
    if not liveDialogueReward(snapshot) then return nil end
    if text and text ~= "" and #text <= 30000 then return text end
end

function addon.DialoguePortrait(id)
    id = dialogueInteger(id, 1)
    local snapshot = dialogueReward
    if not id or not snapshot or snapshot.id ~= id or not currentDialogueReward(snapshot) or
        not liveDialogueReward(snapshot) then return nil end
    local display = addon.Read(GetQuestPortraitGiver, "number")
    if not liveDialogueReward(snapshot) then return nil end
    if display == 0 or display == -1 then return { hidden = true, source = "dialogue" } end
    display = dialogueInteger(display, 1)
    if display then return { displayID = display, source = "dialogue" } end
end

function addon.ClearOffers()
    offerGeneration, currentOffers = {}, nil
end

local function offerScope()
    local now = addon.Read(GetTime, "number")
    local player = addon.Read(UnitGUID, "string", "player")
    local npc = addon.Read(UnitGUID, "string", "npc")
    if not now or now < 0 or not player or player == "" or #player > 256 or
        not npc or npc == "" or #npc > 256 then return nil end
    return now, player, npc
end

function addon.CaptureOffers()
    addon.ClearOffers()
    local generation = offerGeneration
    local now, player, npc = offerScope()
    if not now then return end
    local rows = addon.Read(function() return C_GossipInfo and C_GossipInfo.GetAvailableQuests() end, "table")
    if not rows then return end
    local ok, ids = pcall(function()
        local found, count, maximum = {}, 0, 0
        for key, row in pairs(rows) do
            key = addon.Clean(key, "number")
            row = addon.Clean(row, "table")
            if not key or key < 1 or key > 100 or key % 1 ~= 0 or not row then return nil end
            count, maximum = count + 1, math.max(maximum, key)
            if count > 100 then return nil end
            local id = addon.Clean(row.questID, "number")
            if not id or id < 1 or id % 1 ~= 0 then return nil end
            if addon.quests[id] then found[id] = true end
        end
        if count ~= maximum then return nil end
        return found
    end)
    if not ok or not ids then return end
    local after, afterPlayer, afterNPC = offerScope()
    if generation ~= offerGeneration or not after or after < now or after - now >= 30 or
        afterPlayer ~= player or afterNPC ~= npc then return end
    local snapshot = { ids = ids, time = now, player = player, npc = npc, generation = generation }
    currentOffers = snapshot
    local scheduling, scheduled = true, true
    local function expire()
        if scheduling or not scheduled or currentOffers ~= snapshot or offerGeneration ~= generation then return end
        local clock = addon.Read(GetTime, "number")
        if currentOffers ~= snapshot or offerGeneration ~= generation then return end
        -- Unverifiable time invalidates evidence; it does not prove the dialogue stayed current.
        if clock and clock >= snapshot.time and clock - snapshot.time < 30 then return end
        addon.ClearOffers()
        addon.Notify()
    end
    scheduled = C_Timer and type(C_Timer.After) == "function" and pcall(C_Timer.After, 30, expire) or false
    scheduling = false
end

function addon.CurrentOffer(id)
    id = addon.Clean(id, "number")
    if not id or id < 1 or id % 1 ~= 0 or not addon.quests[id] then return nil end
    local snapshot = currentOffers
    if not snapshot then return nil end
    local now, player, npc = offerScope()
    if snapshot ~= currentOffers or snapshot.generation ~= offerGeneration then return nil end
    -- Dialogue evidence expires even when no close event reaches the addon.
    if not now or now < snapshot.time or now - snapshot.time >= 30 or
        player ~= snapshot.player or npc ~= snapshot.npc then addon.ClearOffers(); return nil end
    if snapshot.ids[id] then return { offeredNow = true, source = "gossip" } end
    return nil
end

function addon.OfferEvent(event)
    if event == "GOSSIP_SHOW" then addon.CaptureOffers()
    elseif event == "GOSSIP_OPTIONS_REFRESHED" then
        if currentOffers then addon.CaptureOffers() end
    else addon.ClearOffers() end
end

function addon.QuestDataResult(id, success)
    id = addon.Clean(id, "number")
    success = addon.Clean(success, "boolean")
    local request = id and requested[id]
    if not request or not request.pending or success == nil then return end
    request.pending = false
    if success or request.attempts >= 3 then request.finished = true; return end
    request.waiting = true
    local attempt = request.attempts
    local function retry()
        if requested[id] ~= request or not request.waiting or request.attempts ~= attempt then return end
        request.waiting = false
        addon.Notify()
    end
    if not C_Timer or type(C_Timer.After) ~= "function" or not pcall(C_Timer.After, 2, retry) then
        request.waiting = false
    end
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
        elseif request.pending then
            local attempt = request.attempts
            -- A missing result event must not leave this ID pending forever.
            local function timeout()
                if requested[id] == request and request.pending and request.attempts == attempt then
                    addon.QuestDataResult(id, false)
                end
            end
            if not C_Timer or type(C_Timer.After) ~= "function" or not pcall(C_Timer.After, 10, timeout) then
                addon.QuestDataResult(id, false)
            end
        end
    end
    return (addon.quests[id] or {}).name or ("#" .. id)
end

function addon.ItemDataResult(id, success)
    id = addon.Clean(id, "number")
    success = addon.Clean(success, "boolean")
    if not id or id < 1 or id % 1 ~= 0 then return end
    local request = requestedItems[id]
    if not request or not request.pending or success == nil then return end
    request.pending = false
    if success or request.attempts >= 3 then request.finished = true; return end
    request.waiting = true
    local attempt = request.attempts
    local function retry()
        if requestedItems[id] ~= request or not request.waiting or request.attempts ~= attempt then return end
        request.waiting = false
        addon.Notify()
    end
    if not C_Timer or type(C_Timer.After) ~= "function" or not pcall(C_Timer.After, 2, retry) then
        request.waiting = false
    end
end

function addon.ItemName(id)
    id = addon.Clean(id, "number")
    if not id or id < 1 or id % 1 ~= 0 then return nil end
    local item = C_Item or {}
    local name = addon.Read(item.GetItemNameByID, "string", id)
    local request = requestedItems[id]
    if name and name ~= "" and #name <= 1024 then
        if request then request.pending, request.waiting, request.finished = false, false, true end
        return name
    end
    if addon.Read(item.IsItemDataCachedByID, "boolean", id) ~= false or
        type(item.RequestLoadItemDataByID) ~= "function" then return nil end
    if request and (request.pending or request.waiting or request.finished) then return nil end
    request = request or { attempts = 0 }
    requestedItems[id] = request
    request.attempts, request.pending = request.attempts + 1, true
    local ok = pcall(item.RequestLoadItemDataByID, id)
    if not ok then addon.ItemDataResult(id, false)
    elseif request.pending then
        local attempt = request.attempts
        local function timeout()
            if requestedItems[id] == request and request.pending and request.attempts == attempt then
                addon.ItemDataResult(id, false)
            end
        end
        if not C_Timer or type(C_Timer.After) ~= "function" or not pcall(C_Timer.After, 10, timeout) then
            addon.ItemDataResult(id, false)
        end
    end
    return nil
end

function addon.DungeonName(d)
    if not d.instanceID then return d.name end
    local name = addon.Read(GetRealZoneText, "string", d.instanceID)
    return name and name ~= "" and name or d.name
end

local dungeonArtCache, dungeonArtReading
local function artInteger(value)
    value = addon.Clean(value, "number")
    return value and value > 0 and value % 1 == 0 and value or nil
end
local function lfgDungeonArt(mapID)
    local enumerate, info = GetLFDChoiceOrder, GetLFGDungeonInfo
    if type(enumerate) ~= "function" or type(info) ~= "function" or dungeonArtReading then return nil end
    if dungeonArtCache and dungeonArtCache.enumerate == enumerate and dungeonArtCache.info == info then
        return dungeonArtCache.images[mapID] or nil
    end
    dungeonArtReading = true
    local ok, images = pcall(function()
        local list = addon.Read(enumerate, "table")
        if not list then return {} end
        -- Validate the whole dense sequence before reading any native dungeon IDs.
        local count, last = 0, 0
        for key in next, list do
            count = count + 1
            key = artInteger(key)
            if count > 500 or not key or key > 500 then return {} end
            if key > last then last = key end
        end
        if last ~= count then return {} end
        local ids, seen = {}, {}
        for i = 1, count do
            local id = addon.Clean(rawget(list, i), "number")
            if not id or id % 1 ~= 0 then return {} end
            -- Nonpositive entries represent headings, not image sources.
            if id > 0 and not seen[id] then ids[#ids + 1], seen[id] = id, true end
        end
        local found = {}
        for _, id in ipairs(ids) do
            local values = { pcall(info, id) }
            if not values[1] then return {} end
            local instanceID = artInteger(values[23])
            local texture = artInteger(values[12]) or addon.Clean(values[12], "string")
            if type(texture) == "string" and (texture == "" or #texture > 1024) then texture = nil end
            if instanceID and texture then
                if found[instanceID] == nil then found[instanceID] = texture
                elseif found[instanceID] ~= texture then found[instanceID] = false end
            end
        end
        return found
    end)
    dungeonArtReading = nil
    -- Native callbacks may replace capabilities while a scan is in progress.
    if GetLFDChoiceOrder ~= enumerate or GetLFGDungeonInfo ~= info then return nil end
    dungeonArtCache = { enumerate = enumerate, info = info, images = ok and images or {} }
    return dungeonArtCache.images[mapID] or nil
end

function addon.DungeonArt(d)
    local mapID = artInteger(d.instanceID)
    local journalID = mapID and artInteger(addon.Read(C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap, "number", mapID))
    if journalID and type(EJ_GetInstanceInfo) == "function" then
        local values = { pcall(EJ_GetInstanceInfo, journalID) }
        local texture = values[1] and artInteger(values[7])
        if texture then return texture end
    end
    return (mapID and lfgDungeonArt(mapID)) or "Interface\\Icons\\INV_Misc_Map_01"
end

function addon.Description(id)
    id = addon.Clean(id, "number")
    if not id or id < 1 or id % 1 ~= 0 then return addon.L("NO_TEXT") end
    local locale = addon.Read(GetLocale, "string")
    local index = addon.Read(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, "number", id)
    local selectedID = addon.Read(C_QuestLog and C_QuestLog.GetSelectedQuest, "number")
    -- The text reader uses the current selection; never change it to fetch text.
    if selectedID == id and index and index >= 1 and index % 1 == 0 then
        local text = addon.Read(GetQuestLogQuestText, "string")
        if text and text ~= "" and #text <= 30000 and
            addon.Read(C_QuestLog and C_QuestLog.GetSelectedQuest, "number") == id and
            addon.Read(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, "number", id) == index and
            addon.Read(GetLocale, "string") == locale then
            if locale and addon.char and type(addon.char.texts) == "table" then
                addon.char.texts[id] = { text = text, locale = locale }
            end
            return text
        end
    end
    locale = addon.Read(GetLocale, "string")
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
    -- Selected-log reward readers use the current selection and take no quest ID.
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
    if not id or id < 1 or id % 1 ~= 0 or not addon.quests[id] then return end
    local locale = addon.Read(GetLocale, "string")
    local text = addon.Read(GetQuestText, "string")
    if text and text ~= "" and #text <= 30000 and locale and
        addon.Read(GetQuestID, "number") == id and addon.Read(GetLocale, "string") == locale and
        addon.char and type(addon.char.texts) == "table" then
        addon.char.texts[id] = { text = text, locale = locale }
    end
end

function addon.RestoreDB()
    local db, char = DungeonProDB, DungeonProCharDB
    if type(db) == "nil" then db = DungeonPrepDB end
    if type(char) == "nil" then char = DungeonPrepCharDB end
    if type(db) ~= "nil" and not addon.Clean(db, "table") then return false end
    if type(char) ~= "nil" and not addon.Clean(char, "table") then return false end
    db, char = db or {}, char or {}
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
    DungeonProDB, DungeonProCharDB = db, char
    return true
end

function addon.ProbeClient()
    local build, _, _, interface = GetBuildInfo()
    local line = C_QuestLine or {}
    -- Object presence does not establish that a dialogue is open or readable.
    local function panelPresent(frame)
        return addon.Clean(frame, "table") ~= nil or addon.Clean(frame, "userdata") ~= nil
    end
    local result = { build = build, interface = interface, api = {}, questLines = {},
        frames = { questFrame = panelPresent(QuestFrame), questDetailPanel = panelPresent(QuestFrameDetailPanel) } }
    for _, entry in ipairs({ { "titles", C_QuestLog and C_QuestLog.GetTitleForQuestID },
        { "objectives", C_QuestLog and C_QuestLog.GetQuestObjectives }, { "lines", line.GetQuestLineInfo },
        { "lineQuests", line.GetQuestLineQuests }, { "offerText", GetQuestText }, { "logText", GetQuestLogQuestText },
        { "offerObjectiveText", GetObjectiveText }, { "offerQuestID", GetQuestID },
        { "offerPortrait", GetQuestPortraitGiver },
        { "offerRewardItems", GetNumQuestRewards }, { "offerRewardChoices", GetNumQuestChoices },
        { "offerRewardInfo", GetQuestItemInfo }, { "offerRewardMoney", GetRewardMoney },
        { "offerRewardXP", GetRewardXP }, { "offerRewardVisibility", C_QuestLog and C_QuestLog.ShouldShowQuestRewards },
        { "rewardItems", GetNumQuestLogRewards }, { "rewardChoices", GetNumQuestLogChoices },
        { "rewardMoney", GetQuestLogRewardMoney }, { "portraits", C_QuestLog and C_QuestLog.GetQuestLogPortraitGiver },
        { "itemNames", C_Item and C_Item.GetItemNameByID }, { "itemRequests", C_Item and C_Item.RequestLoadItemDataByID },
        { "nativeWaypoints", C_Map and C_Map.SetUserWaypoint }, { "tomtom", TomTom and TomTom.AddWaypoint } }) do
        result.api[entry[1]] = type(entry[2]) == "function"
    end
    for _, id in ipairs({ 166, 5728, 96393, 92753 }) do
        local info = addon.Read(line.GetQuestLineInfo, "table", id, nil, false)
        local lineID = info and addon.Clean(info.questLineID, "number")
        if lineID and lineID > 0 and lineID % 1 == 0 then
            local ids = addon.Read(line.GetQuestLineQuests, "table", lineID)
            local clean, seen, invalid = {}, {}, false
            for i = 1, math.min(100, ids and #ids or 0) do
                local qid = addon.Clean(ids[i], "number")
                if qid and qid > 0 and qid % 1 == 0 then
                    if not seen[qid] then clean[#clean + 1] = qid; seen[qid] = true end
                else invalid = true end
            end
            result.questLines[id] = { lineID = lineID, quests = clean, questsAvailable = ids ~= nil,
                truncated = ids ~= nil and #ids > 100, invalidMembers = invalid }
        end
    end
    addon.char.probe = result
    print("Dungeon Pro: client probe saved. No quest text or character identity exported.")
    return result
end
