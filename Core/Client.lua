local _, addon = ...
local requested, requestedItems = {}, {}
local offerGeneration, currentOffers = {}, nil
local dialogueGeneration, dialogueReward = {}, nil

local function dialogueInteger(value, minimum, maximum)
    value = addon.Clean(value, "number")
    if value and value >= minimum and value % 1 == 0 and (not maximum or value <= maximum) then return value end
end

function addon.GiverName(place)
    place = addon.Clean(place, "table")
    if not place then return nil end
    local function sourceIdentity()
        local id = dialogueInteger(rawget(place, "npcID"), 1)
        local name = rawget(place, "name")
        if type(issecretvalue) == "function" then
            local ok, secret = pcall(issecretvalue, name)
            if not ok or secret ~= false then return nil end
        end
        if name ~= nil then
            name = addon.Clean(name, "string")
            if not name or #name > 1024 or not name:find("%S") then return nil end
        end
        return id, name
    end
    local wanted, sourceName = sourceIdentity()
    if not wanted then return nil end
    local function scope()
        local guid = addon.Read(UnitGUID, "string", "npc")
        local locale = addon.Read(GetLocale, "string")
        if not guid or #guid > 256 or not guid:find("%S") or
            not locale or #locale > 32 or not locale:find("%S") then return nil end
        local id = dialogueInteger(addon.Read(function()
            return C_CreatureInfo.GetCreatureID(guid)
        end, "number"), 1)
        return guid, id, locale
    end
    local guid, id, locale = scope()
    if not guid or id ~= wanted then return nil end
    local name = addon.Read(UnitName, "string", "npc")
    if not name or #name > 1024 or not name:find("%S") then return nil end
    local afterGUID, afterID, afterLocale = scope()
    local afterWanted, afterName = sourceIdentity()
    if afterGUID ~= guid or afterID ~= wanted or afterLocale ~= locale or
        afterWanted ~= wanted or afterName ~= sourceName then return nil end
    return name
end

local function restrictionNameScope()
    local getter, checker = GetLocale, issecretvalue
    local locale = addon.Read(getter, "string")
    if not locale or #locale > 32 or not locale:find("%S") or
        GetLocale ~= getter or issecretvalue ~= checker then return nil end
    return function()
        if GetLocale ~= getter or issecretvalue ~= checker then return false end
        local current = addon.Read(getter, "string")
        return current == locale and GetLocale == getter and issecretvalue == checker
    end
end

function addon.ClassName(token)
    token = addon.Clean(token, "string")
    if not token or #token > 100 or not token:match("^[A-Z]+$") then return nil end
    local scope = restrictionNameScope()
    if not scope then return nil end
    local source = addon.Clean(LOCALIZED_CLASS_NAMES_MALE, "table")
    local getter = addon.Clean(LocalizedClassList, "function")
    local map = source
    if not map then map = addon.Read(getter, "table", false) end
    if not scope() or addon.Clean(LOCALIZED_CLASS_NAMES_MALE, "table") ~= source or
        addon.Clean(LocalizedClassList, "function") ~= getter or not map then return nil end
    local name = addon.Clean(rawget(map, token), "string")
    if not name or #name > 500 or not name:find("%S") then return nil end
    if not scope() or addon.Clean(LOCALIZED_CLASS_NAMES_MALE, "table") ~= source or
        addon.Clean(LocalizedClassList, "function") ~= getter or
        addon.Clean(rawget(map, token), "string") ~= name then return nil end
    return name
end

function addon.RaceName(id)
    id = dialogueInteger(id, 1)
    if not id then return nil end
    local scope = restrictionNameScope()
    if not scope then return nil end
    local library = addon.Clean(C_CreatureInfo, "table")
    local getter = library and addon.Clean(rawget(library, "GetRaceInfo"), "function")
    if not getter then return nil end
    local info = addon.Read(getter, "table", id)
    if not scope() or addon.Clean(C_CreatureInfo, "table") ~= library or
        addon.Clean(rawget(library, "GetRaceInfo"), "function") ~= getter or not info then return nil end
    local returnedID = dialogueInteger(rawget(info, "raceID"), 1)
    local name = addon.Clean(rawget(info, "raceName"), "string")
    if returnedID ~= id or not name or #name > 500 or not name:find("%S") then return nil end
    if not scope() or addon.Clean(C_CreatureInfo, "table") ~= library or
        addon.Clean(rawget(library, "GetRaceInfo"), "function") ~= getter then return nil end
    return name
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

function addon.QuestLogCapacity()
    local quest = addon.Clean(C_QuestLog, "table")
    local entries = quest and addon.Clean(quest.GetNumQuestLogEntries, "function")
    if not entries then return nil end
    local maximum = quest.GetMaxNumQuestsCanAccept
    local getter = addon.Clean(maximum, "function")
    local constants, limits, fallback
    if type(maximum) ~= "nil" and not getter then return nil end
    if not getter then
        constants = addon.Clean(Constants, "table")
        limits = constants and addon.Clean(constants.QuestLogConsts, "table")
        fallback = limits and dialogueInteger(limits.MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT, 1)
        if not fallback then return nil end
    end
    local checker = issecretvalue
    local function current()
        if addon.Clean(C_QuestLog, "table") ~= quest or
            addon.Clean(quest.GetNumQuestLogEntries, "function") ~= entries or
            addon.Clean(quest.GetMaxNumQuestsCanAccept, "function") ~= getter or
            (not getter and type(quest.GetMaxNumQuestsCanAccept) ~= "nil") or issecretvalue ~= checker then return false end
        if not getter then
            return addon.Clean(Constants, "table") == constants and
                addon.Clean(constants.QuestLogConsts, "table") == limits and
                addon.Clean(limits.MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT, "number") == fallback
        end
        return true
    end
    if not current() then return nil end
    local ok, _, count = pcall(entries)
    if not ok then return nil end
    count = dialogueInteger(count, 0)
    if not count or not current() then return nil end
    local capacity = getter and dialogueInteger(addon.Read(getter, "number"), 1) or fallback
    if not capacity or not current() then return nil end
    return { count = count, capacity = capacity }
end

function addon.CarriedItemCount(id)
    id = dialogueInteger(id, 1)
    local item = addon.Clean(C_Item, "table")
    local getter = item and addon.Clean(item.GetItemCount, "function")
    local quests = addon.Clean(addon.quests, "table")
    local checker = issecretvalue
    if not id or not getter or not quests then return nil end
    local function linked()
        for _, value in next, quests do
            local quest = addon.Clean(value, "table")
            local start = quest and addon.Clean(quest.start, "table")
            if start and addon.Clean(start.itemID, "number") == id then return true end
            local objectives = quest and addon.Clean(quest.objectiveItems, "table")
            if objectives and #objectives >= 1 and #objectives <= 100 then
                for index = 1, #objectives do
                    local entry = addon.Clean(objectives[index], "table")
                    if entry then
                        local itemID = dialogueInteger(rawget(entry, "itemID"), 1, 9007199254740991)
                        local quantity = rawget(entry, "quantity")
                        local readable = true
                        if type(issecretvalue) == "function" then
                            local ok, restricted = pcall(issecretvalue, quantity)
                            readable = ok and addon.Clean(restricted, "boolean") == false
                        end
                        if readable and itemID == id and (type(quantity) == "nil" or
                            dialogueInteger(quantity, 1, 9007199254740991)) then return true end
                    end
                end
            end
            local related = quest and addon.Clean(quest.completionQuests, "table")
            if related then
                for index = 1, math.min(#related, 100) do
                    local entry = addon.Clean(related[index], "table")
                    if entry and addon.Clean(entry.itemID, "number") == id then return true end
                end
            end
        end
        return false
    end
    local function current()
        return addon.Clean(C_Item, "table") == item and addon.Clean(item.GetItemCount, "function") == getter and
            addon.Clean(addon.quests, "table") == quests and issecretvalue == checker
    end
    if not linked() or not current() then return nil end
    local count = addon.Read(getter, "number", id, false, false, false, false)
    if not count or count < 0 or count % 1 ~= 0 or not current() or not linked() or not current() then return nil end
    return count
end

function addon.ItemName(id)
    id = addon.Clean(id, "number")
    if not id or id < 1 or id % 1 ~= 0 then return nil end
    local item = addon.Clean(C_Item, "table")
    local scope = restrictionNameScope()
    if not item or not scope then return nil end
    local nameGetter = addon.Clean(item.GetItemNameByID, "function")
    local cacheGetter = addon.Clean(item.IsItemDataCachedByID, "function")
    local loader = addon.Clean(item.RequestLoadItemDataByID, "function")
    local function current()
        return scope() and addon.Clean(C_Item, "table") == item and
            addon.Clean(item.GetItemNameByID, "function") == nameGetter and
            addon.Clean(item.IsItemDataCachedByID, "function") == cacheGetter and
            addon.Clean(item.RequestLoadItemDataByID, "function") == loader
    end
    local name = addon.Read(nameGetter, "string", id)
    if not current() then return nil end
    local request = requestedItems[id]
    if name and name ~= "" and #name <= 1024 then
        if request then request.pending, request.waiting, request.finished = false, false, true end
        return name
    end
    local cached = addon.Read(cacheGetter, "boolean", id)
    if not current() or cached ~= false or not loader then return nil end
    request = requestedItems[id]
    if request and (request.pending or request.waiting or request.finished) then return nil end
    request = request or { attempts = 0 }
    requestedItems[id] = request
    request.attempts, request.pending = request.attempts + 1, true
    local ok = pcall(loader, id)
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
    if not name or name == "" then return d.name end
    local wing = addon.Clean(d.wing, "string")
    if wing == "lower" or wing == "upper" then
        return addon.L("DUNGEON_WING_" .. wing, name)
    end
    return name
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
    local checker = issecretvalue
    d = addon.Clean(d, "table") or {}
    local art = addon.Clean(d.art, "table")
    local fileID = art and artInteger(art.fileID)
    local artMap = art and artInteger(art.gameMapID)
    local mapID = artInteger(d.instanceID)
    local generic = "Interface\\Icons\\INV_Misc_Map_01"
    local function current()
        return issecretvalue == checker and addon.Clean(d.art, "table") == art and
            artInteger(d.instanceID) == mapID and (not art or
                (artInteger(art.fileID) == fileID and artInteger(art.gameMapID) == artMap))
    end
    if not current() then return generic end
    if fileID and artMap and (not mapID or mapID == artMap) then return fileID end
    local journal = addon.Clean(C_EncounterJournal, "table")
    local lookup = journal and addon.Clean(journal.GetInstanceForGameMap, "function")
    local info = addon.Clean(EJ_GetInstanceInfo, "function")
    local function journalCurrent()
        return current() and addon.Clean(C_EncounterJournal, "table") == journal and
            (not journal or addon.Clean(journal.GetInstanceForGameMap, "function") == lookup) and
            addon.Clean(EJ_GetInstanceInfo, "function") == info
    end
    local journalID = mapID and artInteger(addon.Read(lookup, "number", mapID))
    if not journalCurrent() then return generic end
    if journalID and info then
        local values = { pcall(info, journalID) }
        local texture = values[1] and artInteger(values[7])
        if not journalCurrent() then return generic end
        if texture then return texture end
    end
    local image = mapID and lfgDungeonArt(mapID)
    return current() and image or generic
end

local dungeonArtPaints = setmetatable({}, { __mode = "k" })
function addon.PaintDungeonArt(texture, dungeon)
    local token = {}
    dungeonArtPaints[texture] = token
    local image = addon.DungeonArt(dungeon)
    local function current() return dungeonArtPaints[texture] == token end
    if not current() then return false end
    local function paint(value)
        local ok, accepted = pcall(texture.SetTexture, texture, value)
        return ok and addon.Clean(accepted, "boolean") == true
    end
    local accepted = paint(image)
    if not current() then return false end
    local generic = "Interface\\Icons\\INV_Misc_Map_01"
    if not accepted and image ~= generic then
        accepted = paint(generic)
        image = generic
        if not current() then return false end
    end
    if not accepted then
        pcall(texture.SetTexture, texture, nil)
        if current() then texture:Hide() end
        return false
    end
    if type(texture.SetTexCoord) == "function" then
        local inset = type(image) == "number" and 0.18 or 0
        pcall(texture.SetTexCoord, texture, inset, 1 - inset, inset, 1 - inset)
        if not current() then return false end
    end
    texture:Show()
    return current()
end

local function selectedLogReadScope(id)
    local quest = addon.Clean(C_QuestLog, "table")
    if not quest then return nil end
    local selected = addon.Clean(quest.GetSelectedQuest, "function")
    local logIndex = addon.Clean(quest.GetLogIndexForQuestID, "function")
    local localeGetter, checker = addon.Clean(GetLocale, "function"), issecretvalue
    local character = addon.Clean(addon.char, "table")
    local locale = addon.Read(localeGetter, "string")
    local index = dialogueInteger(addon.Read(logIndex, "number", id), 1)
    local function unchanged()
        return addon.Clean(C_QuestLog, "table") == quest and
            addon.Clean(quest.GetSelectedQuest, "function") == selected and
            addon.Clean(quest.GetLogIndexForQuestID, "function") == logIndex and
            addon.Clean(GetLocale, "function") == localeGetter and issecretvalue == checker and
            addon.Clean(addon.char, "table") == character
    end
    local function current()
        if not index or not unchanged() then return false end
        local selectedID = addon.Read(selected, "number")
        local currentIndex = dialogueInteger(addon.Read(logIndex, "number", id), 1)
        local currentLocale = addon.Read(localeGetter, "string")
        return selectedID == id and currentIndex == index and currentLocale == locale and unchanged()
    end
    if not current() then return nil end
    return current, locale
end

function addon.Description(id)
    id = dialogueInteger(id, 1)
    if not id then return addon.L("NO_TEXT") end
    local character = addon.Clean(addon.char, "table")
    local texts = character and addon.Clean(character.texts, "table")
    local getter = addon.Clean(GetQuestLogQuestText, "function")
    local scope, locale = selectedLogReadScope(id)
    local function owned()
        return addon.Clean(addon.char, "table") == character and
            (not character or addon.Clean(character.texts, "table") == texts) and
            addon.Clean(GetQuestLogQuestText, "function") == getter
    end
    -- The text reader uses the current selection; never change it to fetch text.
    if scope and owned() and scope() then
        local text = addon.Read(getter, "string")
        if text and text ~= "" and #text <= 30000 and scope() and owned() then
            if locale and texts then texts[id] = { text = text, locale = locale } end
            return text
        end
    end
    local localeGetter, checker = addon.Clean(GetLocale, "function"), issecretvalue
    locale = addon.Read(localeGetter, "string")
    character = addon.Clean(addon.char, "table")
    texts = character and addon.Clean(character.texts, "table")
    local data = texts and addon.Clean(texts[id], "table")
    if data and locale and addon.Clean(data.locale, "string") == locale then
        local text = addon.Clean(data.text, "string")
        if text and text ~= "" and #text <= 30000 and
            addon.Read(localeGetter, "string") == locale and addon.Clean(GetLocale, "function") == localeGetter and
            issecretvalue == checker and addon.Clean(addon.char, "table") == character and
            addon.Clean(character.texts, "table") == texts and addon.Clean(texts[id], "table") == data then return text end
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
    local scope = selectedLogReadScope(id)
    if not scope then return nil end
    local api = { rewards = addon.Clean(GetNumQuestLogRewards, "function"),
        choices = addon.Clean(GetNumQuestLogChoices, "function"),
        fixed = addon.Clean(GetQuestLogRewardInfo, "function"), choice = addon.Clean(GetQuestLogChoiceInfo, "function"),
        money = addon.Clean(GetQuestLogRewardMoney, "function") }
    local function selected()
        return scope() and addon.Clean(GetNumQuestLogRewards, "function") == api.rewards and
            addon.Clean(GetNumQuestLogChoices, "function") == api.choices and
            addon.Clean(GetQuestLogRewardInfo, "function") == api.fixed and
            addon.Clean(GetQuestLogChoiceInfo, "function") == api.choice and
            addon.Clean(GetQuestLogRewardMoney, "function") == api.money
    end
    -- Selected-log reward readers use the current selection and take no quest ID.
    if not selected() then return nil end
    local rewards = integer(addon.Read(api.rewards, "number"), 0, 100)
    if not selected() then return nil end
    local choices = integer(addon.Read(api.choices, "number"), 0, 100)
    if not rewards or not choices or not selected() then return nil end
    local function items(count, getter)
        if count > 0 and type(getter) ~= "function" then return nil end
        local result = {}
        for i = 1, count do
            local ok, name, texture, amount, quality, usable, itemID = pcall(getter, i)
            if not ok or not selected() then return nil end
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
    local fixed = items(rewards, api.fixed)
    if not fixed or not selected() then return nil end
    local choice = items(choices, api.choice)
    if not fixed or not choice then return nil end
    local money = addon.Read(api.money, "number")
    if money and money < 0 then money = nil end
    if not selected() then return nil end
    return { items = fixed, choices = choice, money = money }
end

function addon.CachedQuestRewards(id)
    id = dialogueInteger(id, 1)
    local catalog = id and addon.quests[id]
    if not catalog then return nil end
    local api = { loaded = HaveQuestRewardData, locale = GetLocale, rewards = GetNumQuestLogRewards,
        choices = GetNumQuestLogChoices, fixed = GetQuestLogRewardInfo, choice = GetQuestLogChoiceInfo,
        money = GetQuestLogRewardMoney, xp = GetQuestLogRewardXP, secret = issecretvalue }
    local function unchanged()
        return addon.quests[id] == catalog and api.loaded == HaveQuestRewardData and api.locale == GetLocale and
            api.rewards == GetNumQuestLogRewards and api.choices == GetNumQuestLogChoices and
            api.fixed == GetQuestLogRewardInfo and api.choice == GetQuestLogChoiceInfo and
            api.money == GetQuestLogRewardMoney and api.xp == GetQuestLogRewardXP and api.secret == issecretvalue
    end
    local locale = addon.Read(api.locale, "string")
    if not locale or #locale > 32 or not locale:find("%S") or not unchanged() then return nil end
    local function loaded()
        if not unchanged() or addon.Read(api.loaded, "boolean", id) ~= true then return false end
        return addon.Read(api.locale, "string") == locale and unchanged()
    end
    if not loaded() then return nil end
    local rewards = dialogueInteger(addon.Read(api.rewards, "number", id), 0, 100)
    local choices = dialogueInteger(addon.Read(api.choices, "number", id), 0, 100)
    if not rewards or not choices or not unchanged() then return nil end
    local function items(count, getter)
        if count > 0 and type(getter) ~= "function" then return nil end
        local result = {}
        for index = 1, count do
            local ok, name, texture, amount, quality, usable, itemID = pcall(getter, index, id)
            if not ok then return nil end
            if type(api.secret) == "function" then
                local fields = { name, texture, amount, quality, usable, itemID }
                for field = 1, 6 do
                    local readable, secret = pcall(api.secret, fields[field])
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
            row.quality, row.usable = dialogueInteger(quality, 0), addon.Clean(usable, "boolean")
            result[index] = row
            if not unchanged() then return nil end
        end
        return result
    end
    local fixed, choice = items(rewards, api.fixed), items(choices, api.choice)
    if not fixed or not choice then return nil end
    local function scalar(getter)
        if getter == nil then return nil, true end
        if type(getter) ~= "function" then return nil, false end
        local ok, value = pcall(getter, id)
        if not ok then return nil, false end
        value = addon.Clean(value, "number")
        if value and value < 0 then value = nil end
        return value, true
    end
    local money, moneyOK = scalar(api.money)
    local xp, xpOK = scalar(api.xp)
    if not moneyOK or not xpOK or not loaded() then return nil end
    return { source = "cache", items = fixed, choices = choice, money = money, xp = xp }
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
        { "rewardCache", HaveQuestRewardData }, { "rewardXP", GetQuestLogRewardXP },
        { "npcNames", UnitName }, { "creatureIDs", C_CreatureInfo and C_CreatureInfo.GetCreatureID },
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
