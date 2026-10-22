local _, addon = ...
local requested, requestedItems = {}, {}
local carriedRelations = setmetatable({}, { __mode = "k" })
local contextGeneration = {}
local retryRefreshPending, retryRefreshing
local offerGeneration, currentOffers = {}, nil
local dialogueGeneration, dialogueReward = {}, nil
local textCaptureGeneration = {}
local nameLoads = setmetatable({}, { __mode = "k" })

local function dialogueInteger(value, minimum, maximum)
    value = addon.Clean(value, "number")
    if value and value >= minimum and value % 1 == 0 and (not maximum or value <= maximum) then return value end
end

function addon.GiverName(place)
    place = addon.Clean(place, "table")
    if not place then return nil end
    local function sourceIdentity()
        local id = dialogueInteger(rawget(place, "npcID"), 1, 4294967295)
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
        end, "number"), 1, 9007199254740991)
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

function addon.GiverPortrait(place)
    local checker = issecretvalue
    place = addon.Clean(place, "table")
    if not place or issecretvalue ~= checker then return nil end
    local function snapshot()
        for _, field in ipairs({ "objectID", "itemID", "dropNPCID" }) do
            local value = rawget(place, field)
            if type(checker) == "function" then
                local ok, restricted = pcall(checker, value)
                if not ok or restricted ~= false or issecretvalue ~= checker then return nil end
            end
            if value ~= nil then return nil end
        end
        local npc = dialogueInteger(rawget(place, "npcID"), 1, 4294967295)
        local display = dialogueInteger(rawget(place, "creatureDisplayID"), 1, 4294967295)
        local source = addon.Clean(rawget(place, "portraitSource"), "string")
        if not npc or not display or not source or #source > 2048 then return nil end
        local prefix = "https://www.wowhead.com/forever/npc=" .. npc
        if source:sub(1, #prefix) ~= prefix then return nil end
        local suffix = source:sub(#prefix + 1)
        if suffix ~= "" and not suffix:match("^/[^%s/?#]+$") then return nil end
        local name = addon.Clean(rawget(place, "name"), "string")
        if name and (#name > 1024 or not name:find("%S")) then name = nil end
        if issecretvalue ~= checker then return nil end
        return npc, display, source, name
    end
    local npc, display, source, name = snapshot()
    if not npc then return nil end
    local currentNPC, currentDisplay, currentSource, currentName = snapshot()
    if npc == currentNPC and display == currentDisplay and source == currentSource and name == currentName then
        return { npcID = npc, displayID = display, source = source, name = name }
    end
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
    id = dialogueInteger(id, 1, 9007199254740991)
    if not id then return nil end
    local scope = restrictionNameScope()
    if not scope then return nil end
    local library = addon.Clean(C_CreatureInfo, "table")
    local getter = library and addon.Clean(rawget(library, "GetRaceInfo"), "function")
    if not getter then return nil end
    local info = addon.Read(getter, "table", id)
    if not scope() or addon.Clean(C_CreatureInfo, "table") ~= library or
        addon.Clean(rawget(library, "GetRaceInfo"), "function") ~= getter or not info then return nil end
    local returnedID = dialogueInteger(rawget(info, "raceID"), 1, 9007199254740991)
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
    local catalogue = addon.Clean(addon.quests, "table")
    local definition = id and catalogue and addon.Clean(rawget(catalogue, id), "table")
    if not definition or not player or player == "" or #player > 256 or
        not locale or locale == "" or #locale > 32 then return nil end
    return id, player, locale
end

local function clearDialogueReward()
    dialogueGeneration, dialogueReward = {}, nil
end

local function currentDialogueReward(snapshot)
    local function owned()
        local ok, same = pcall(function()
            return snapshot == dialogueReward and snapshot.generation == dialogueGeneration and
                addon.char == snapshot.character and addon.quests == snapshot.catalogue and
                rawget(snapshot.catalogue, snapshot.id) == snapshot.definition and
                GetQuestID == snapshot.idGetter and UnitGUID == snapshot.playerGetter and GetLocale == snapshot.localeGetter and
                issecretvalue == snapshot.checker and addon.Clean == snapshot.clean and addon.Read == snapshot.read and
                QuestFrame == snapshot.frame and QuestFrameDetailPanel == snapshot.panel and
                snapshot.frame.IsShown == snapshot.frameShown and snapshot.panel.IsShown == snapshot.panelShown
        end)
        return ok and same == true
    end
    if not owned() then
        if dialogueReward == snapshot then clearDialogueReward() end
        return false
    end
    local id, player, locale = dialogueScope()
    local current = owned() and
        id == snapshot.id and player == snapshot.player and locale == snapshot.locale
    if not current and snapshot == dialogueReward then clearDialogueReward() end
    return current
end

local function liveDialogueReward(snapshot)
    -- A matching native quest ID can outlive its closed detail window.
    if not currentDialogueReward(snapshot) then return false end
    local shown = addon.Read(snapshot.frameShown, "boolean", snapshot.frame)
    local detail = addon.Read(snapshot.panelShown, "boolean", snapshot.panel)
    if not currentDialogueReward(snapshot) then return false end
    if shown == true and detail == true then snapshot.observedVisible = true; return true end
    -- Native handlers may show these panels after the event reaches the addon.
    if (shown == nil or detail == nil or snapshot.observedVisible) and dialogueReward == snapshot then clearDialogueReward() end
    return false
end

function addon.DialogueRewardEvent(event)
    event = addon.Clean(event, "string")
    if event == "QUEST_DETAIL" then
        clearDialogueReward()
        local generation = dialogueGeneration
        local snapshot = { generation = generation, character = addon.char, catalogue = addon.Clean(addon.quests, "table"),
            idGetter = GetQuestID, playerGetter = UnitGUID, localeGetter = GetLocale, checker = issecretvalue,
            clean = addon.Clean, read = addon.Read, frame = QuestFrame, panel = QuestFrameDetailPanel }
        snapshot.frameShown = addon.Read(function() return snapshot.frame.IsShown end, "function")
        snapshot.panelShown = addon.Read(function() return snapshot.panel.IsShown end, "function")
        local id, player, locale = dialogueScope()
        if not id or not snapshot.catalogue or generation ~= dialogueGeneration then return end
        snapshot.id, snapshot.player, snapshot.locale = id, player, locale
        snapshot.definition = addon.Clean(rawget(snapshot.catalogue, id), "table")
        if not snapshot.definition then return end
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
    local quest = addon.Clean(C_QuestLog, "table")
    local api = { quest = C_QuestLog, visible = quest and rawget(quest, "ShouldShowQuestRewards"),
        rewards = GetNumQuestRewards, choices = GetNumQuestChoices, items = GetQuestItemInfo,
        money = GetRewardMoney, xp = GetRewardXP }
    local function capabilities()
        local ok, same = pcall(function()
            return C_QuestLog == api.quest and (not quest or rawget(quest, "ShouldShowQuestRewards") == api.visible) and
                GetNumQuestRewards == api.rewards and GetNumQuestChoices == api.choices and GetQuestItemInfo == api.items and
                GetRewardMoney == api.money and GetRewardXP == api.xp
        end)
        return ok and same == true
    end
    local function live()
        return capabilities() and liveDialogueReward(snapshot) and capabilities()
    end
    if not live() then return nil end
    local visible = addon.Read(api.visible, "boolean", id)
    if not live() then return nil end
    if visible == nil then return nil end
    if not visible then return { hidden = true, source = "dialogue" } end
    local rewards = dialogueInteger(addon.Read(api.rewards, "number"), 0, 100)
    if not live() then return nil end
    local choices = dialogueInteger(addon.Read(api.choices, "number"), 0, 100)
    if not rewards or not choices or not live() then return nil end
    local function items(kind, count)
        if count > 0 and type(api.items) ~= "function" then return nil end
        local result = {}
        for i = 1, count do
            local ok, name, texture, amount, quality, usable, itemID = pcall(api.items, kind, i)
            if not ok or not live() then return nil end
            if type(issecretvalue) == "function" then
                local fields = { name, texture, amount, quality, usable, itemID }
                for j = 1, 6 do
                    local readable, secret = pcall(issecretvalue, fields[j])
                    if not readable or secret ~= false then return nil end
                end
            end
            name = addon.Clean(name, "string")
            amount, itemID = dialogueInteger(amount, 1, 9007199254740991), dialogueInteger(itemID, 1, 4294967295)
            if not name or name == "" or #name > 30000 or not amount or not itemID then return nil end
            local row = { id = itemID, name = name, count = amount }
            local icon = addon.Clean(texture, "string")
            if icon and icon ~= "" and #icon <= 1024 then row.texture = icon
            else row.texture = dialogueInteger(texture, 1, 9007199254740991) end
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
    local money = dialogueInteger(addon.Read(api.money, "number"), 0, 9007199254740991)
    if not live() then return nil end
    local xp = dialogueInteger(addon.Read(api.xp, "number"), 0, 9007199254740991)
    if not live() then return nil end
    return { items = fixed, choices = choice, money = money, xp = xp, source = "dialogue" }
end

function addon.DialogueObjectiveText(id)
    id = dialogueInteger(id, 1)
    local snapshot = dialogueReward
    local getter, provider = addon.Clean(GetObjectiveText, "function"), addon.DialogueObjectiveText
    local function capability()
        local ok, same = pcall(function() return GetObjectiveText == getter and addon.DialogueObjectiveText == provider end)
        return ok and same == true
    end
    local function live()
        return capability() and liveDialogueReward(snapshot) and capability()
    end
    if not id or not snapshot or snapshot.id ~= id or not currentDialogueReward(snapshot) or
        not getter or not live() then return nil end
    -- Offered summary text is separate from accepted quest objective counters.
    local text = addon.Read(getter, "string")
    if not live() then return nil end
    if text and text ~= "" and #text <= 30000 then return text end
end

function addon.DialoguePortrait(id)
    id = dialogueInteger(id, 1)
    local snapshot = dialogueReward
    local getter, provider = addon.Clean(GetQuestPortraitGiver, "function"), addon.DialoguePortrait
    local function capability()
        local ok, same = pcall(function() return GetQuestPortraitGiver == getter and addon.DialoguePortrait == provider end)
        return ok and same == true
    end
    local function live()
        return capability() and liveDialogueReward(snapshot) and capability()
    end
    if not id or not snapshot or snapshot.id ~= id or not currentDialogueReward(snapshot) or
        not getter or not live() then return nil end
    local display = addon.Read(getter, "number")
    if not live() then return nil end
    if display == 0 or display == -1 then return { hidden = true, source = "dialogue" } end
    display = dialogueInteger(display, 1, 4294967295)
    if display and live() then return { displayID = display, source = "dialogue" } end
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
        addon.Notify("data")
    end
    scheduled = C_Timer and type(C_Timer.After) == "function" and pcall(C_Timer.After, 30, expire) or false
    scheduling = false
end

function addon.CurrentOffer(id)
    id = addon.Clean(id, "number")
    local catalogue = addon.Clean(addon.quests, "table")
    if not id or id < 1 or id % 1 ~= 0 or not catalogue or not rawget(catalogue, id) then return nil end
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

local function refreshRetries()
    if retryRefreshPending or retryRefreshing then return end
    local token, inline = {}, true
    retryRefreshPending = token
    local function run()
        if retryRefreshPending ~= token then return end
        retryRefreshPending, retryRefreshing = nil, inline
        local ok, message = pcall(addon.Notify, "data")
        retryRefreshing = nil
        if not ok then error(message) end
    end
    local after = C_Timer and addon.Clean(C_Timer.After, "function")
    local ok, result
    if after then ok, result = pcall(after, .1, run) end
    if ok and addon.Clean(result, "boolean") ~= false then inline = false
    else run() end
end

local function dataResult(requests, id, success)
    local request = id and requests[id]
    if not request or not request.pending or success == nil then return end
    request.pending = false
    if success or request.attempts >= 3 then request.finished = true; return end
    request.waiting = true
    local attempt = request.attempts
    local function retry()
        if requests[id] ~= request or not request.waiting or request.attempts ~= attempt then return end
        request.waiting = false
        refreshRetries()
    end
    if not C_Timer or type(C_Timer.After) ~= "function" or not pcall(C_Timer.After, 2, retry) then
        request.waiting = false
    end
end

function addon.QuestDataResult(id, success)
    id = addon.Clean(id, "number")
    success = addon.Clean(success, "boolean")
    dataResult(requested, id, success)
end

function addon.InvalidateContext()
    contextGeneration = {}
    return true
end

function addon.Context()
    local generation = contextGeneration
    local result, checker = {}, issecretvalue
    local function characterRoot()
        local value = addon.char
        if type(issecretvalue) == "function" then
            local ok, restricted = pcall(issecretvalue, value)
            if not ok or restricted ~= false then return nil, false end
        end
        if value == nil then return nil, true end
        value = addon.Clean(value, "table")
        return value, value ~= nil
    end
    local character, readable = characterRoot()
    local quest = addon.Clean(C_QuestLog, "table")
    local level, faction = addon.Clean(UnitLevel, "function"), addon.Clean(UnitFactionGroup, "function")
    local class, race = addon.Clean(UnitClass, "function"), addon.Clean(UnitRace, "function")
    local completed = quest and addon.Clean(quest.IsQuestFlaggedCompleted, "function")
    local active = quest and addon.Clean(quest.IsOnQuest, "function")
    local ready = quest and addon.Clean(quest.ReadyForTurnIn, "function")
    local complete = quest and addon.Clean(quest.IsComplete, "function")
    local valid = readable
    local function forget()
        result.level, result.faction, result.class, result.race = nil, nil, nil, nil
        return false
    end
    local function current()
        if not valid then return forget() end
        local root, known = characterRoot()
        valid = generation == contextGeneration and known and root == character and issecretvalue == checker and addon.Clean(C_QuestLog, "table") == quest and
            addon.Clean(UnitLevel, "function") == level and addon.Clean(UnitFactionGroup, "function") == faction and
            addon.Clean(UnitClass, "function") == class and addon.Clean(UnitRace, "function") == race and
            (not quest or (addon.Clean(quest.IsQuestFlaggedCompleted, "function") == completed and
                addon.Clean(quest.IsOnQuest, "function") == active and addon.Clean(quest.ReadyForTurnIn, "function") == ready and
                addon.Clean(quest.IsComplete, "function") == complete))
        valid = valid and generation == contextGeneration
        if not valid then return forget() end
        return true
    end
    local function unitPart(fn, index, expected)
        if not current() or not fn then return nil end
        local values = { pcall(fn, "player") }
        if not current() or not values[1] then return nil end
        return addon.Clean(values[index + 1], expected)
    end
    local function evidence(fn, id)
        -- Cap IDs at 2^53 so huge doubles cannot wrap into another valid quest ID in native readers.
        id = dialogueInteger(id, 1, 9007199254740991)
        if not id or not current() then return nil end
        local value = addon.Read(fn, "boolean", id)
        if current() then return value end
    end
    result.current = current
    result.level = unitPart(level, 1, "number")
    result.faction = unitPart(faction, 1, "string")
    result.class, result.race = unitPart(class, 2, "string"), unitPart(race, 3, "number")
    result.completed = function(id) return evidence(completed, id) end
    result.active = function(id) return evidence(active, id) end
    result.ready = function(id) return evidence(ready or complete, id) end
    current()
    return result
end

local function nameLocaleScope()
    local function normalize(value)
        if value == "enGB" then value = "enUS" elseif value == "esMX" then value = "esES" end
        if value == "enUS" or value == "ruRU" or value == "deDE" or value == "frFR" or value == "esES" or
            value == "itIT" or value == "ptBR" or value == "koKR" or value == "zhCN" or value == "zhTW" then return value end
    end
    local checker, gameGetter = issecretvalue, GetLocale
    local database, language = addon.Clean(addon.db, "table"), addon.Clean(addon.Language, "table")
    local previewGetter = language and addon.Clean(rawget(language, "GetSelection"), "function")
    local choice = database and addon.Clean(rawget(database, "locale"), "string")
    local preview = addon.Read(previewGetter, "string", language)
    local game = addon.Read(gameGetter, "string")
    local selected = preview or choice or "auto"
    local locale = normalize(selected == "auto" and game or selected) or "enUS"
    local function current()
        if issecretvalue ~= checker or GetLocale ~= gameGetter or addon.db ~= database or addon.Language ~= language then return false end
        if database and addon.Clean(rawget(database, "locale"), "string") ~= choice then return false end
        if language and addon.Clean(rawget(language, "GetSelection"), "function") ~= previewGetter then return false end
        if addon.Read(previewGetter, "string", language) ~= preview or addon.Read(gameGetter, "string") ~= game then return false end
        return (not database or addon.Clean(rawget(database, "locale"), "string") == choice) and
            addon.Read(previewGetter, "string", language) == preview and
            issecretvalue == checker and GetLocale == gameGetter and addon.db == database and addon.Language == language and
            (not language or rawget(language, "GetSelection") == previewGetter)
    end
    if current() then return locale, normalize(game), current end
end

local function nameDictionary(locale, ownerCurrent)
    local clean, read, checker = addon.Clean, addon.Read, issecretvalue
    locale, ownerCurrent = clean(locale, "string"), clean(ownerCurrent, "function")
    local root = clean(addon.nameTranslations, "table")
    if not root or not locale or not ownerCurrent then return nil end
    local existing = clean(rawget(root, locale), "table")
    if existing then
        if read(ownerCurrent, "boolean") == true and addon.Clean == clean and addon.Read == read and issecretvalue == checker and
            rawequal(rawget(addon, "GetNameTranslations"), nameDictionary) and
            rawequal(rawget(addon, "nameTranslations"), root) and rawequal(rawget(root, locale), existing) then return existing end
        return nil
    end
    local factories = clean(addon.nameTranslationFactories, "table")
    local loaders = factories and clean(rawget(factories, "loaders"), "table")
    local loader = loaders and clean(rawget(loaders, locale), "function")
    if not loader or not rawequal(rawget(factories, "root"), root) then return nil end
    local loading = nameLoads[root]
    if not loading then loading = {}; nameLoads[root] = loading end
    if loading[locale] then return nil end
    local token = {}; loading[locale] = token
    local function current()
        if read(ownerCurrent, "boolean") ~= true then return false end
        return rawequal(rawget(addon, "GetNameTranslations"), nameDictionary) and addon.Clean == clean and addon.Read == read and
            issecretvalue == checker and rawequal(rawget(addon, "nameTranslations"), root) and
            rawequal(rawget(root, locale), nil) and rawequal(rawget(addon, "nameTranslationFactories"), factories) and
            rawequal(rawget(factories, "root"), root) and rawequal(rawget(factories, "loaders"), loaders) and
            rawequal(rawget(loaders, locale), loader) and loading[locale] == token
    end
    local dictionary
    if current() then dictionary = read(loader, "table") end
    local quests = dictionary and clean(rawget(dictionary, "quests"), "table")
    local dungeons = dictionary and clean(rawget(dictionary, "dungeons"), "table")
    local valid = quests and dungeons and current() and
        rawequal(rawget(dictionary, "quests"), quests) and rawequal(rawget(dictionary, "dungeons"), dungeons)
    if valid then
        rawset(root, locale, dictionary)
        rawset(loaders, locale, nil)
    end
    if loading[locale] == token then loading[locale] = nil end
    return valid and dictionary or nil
end
addon.GetNameTranslations = nameDictionary

local function translatedName(kind, key, definition, current, locale)
    if not definition or not current then return nil end
    if kind == "quests" and dialogueInteger(rawget(definition, "id"), 1, 9007199254740991) ~= key then return nil end
    local root = addon.Clean(addon.nameTranslations, "table")
    local dictionary = root and addon.Clean(rawget(root, locale), "table")
    if not dictionary and locale ~= "enUS" then dictionary = nameDictionary(locale, current) end
    local entries = dictionary and addon.Clean(rawget(dictionary, kind), "table")
    local entry = entries and addon.Clean(rawget(entries, key), "table")
    local source = addon.Clean(rawget(definition, "name"), "string")
    local original = entry and addon.Clean(rawget(entry, "source"), "string")
    local name = entry and addon.Clean(rawget(entry, "name"), "string")
    if not source or #source > 1024 or not source:find("%S") or source ~= original or
        not name or #name > 1024 or not name:find("%S") then return nil end
    local function fresh()
        if not current() then return false end
        local same = addon.Clean(addon.nameTranslations, "table") == root and addon.Clean(rawget(root, locale), "table") == dictionary and
            addon.Clean(rawget(dictionary, kind), "table") == entries and addon.Clean(rawget(entries, key), "table") == entry and
            addon.Clean(rawget(entry, "source"), "string") == source and addon.Clean(rawget(entry, "name"), "string") == name and
            addon.Clean(rawget(definition, "name"), "string") == source
        return same and current()
    end
    if fresh() then return name, fresh end
end

function addon.SourceName(place, ownerCurrent)
    local clean, read, checker = addon.Clean, addon.Read, issecretvalue
    local api, dictionaryGetter = addon.SourceName, addon.GetNameTranslations
    local fields = { "npcID", "objectID", "itemID", "dropNPCID", "name" }
    local ok, values = pcall(function()
        local snapshot = {}; for _, field in ipairs(fields) do snapshot[field] = rawget(place, field) end
        return snapshot
    end)
    if not ok then return nil end
    local function sourceCurrent()
        local valid, same = pcall(function()
            if addon.SourceName ~= api or addon.GetNameTranslations ~= dictionaryGetter or addon.Clean ~= clean or
                addon.Read ~= read or issecretvalue ~= checker then return false end
            for _, field in ipairs(fields) do
                if not rawequal(rawget(place, field), values[field]) then return false end
            end
            return true
        end)
        return valid and same == true
    end
    if not clean(place,"table") or not sourceCurrent() then return nil end
    for _, field in ipairs(fields) do
        if type(checker) == "function" and read(checker,"boolean",values[field]) ~= false then return nil end
        if not sourceCurrent() then return nil end
    end
    local npc, object = clean(values.npcID,"number"), clean(values.objectID,"number")
    if not sourceCurrent() or values.itemID ~= nil or values.dropNPCID ~= nil or
        (values.npcID ~= nil and values.objectID ~= nil) then return nil end
    local id, kind = npc or object, npc and "npcs" or "objects"
    if not id or id <= 0 or id > 4294967295 or id % 1 ~= 0 then return nil end
    local name, owner = clean(values.name,"string"), clean(ownerCurrent,"function")
    if not name or #name > 1024 or not name:find("%S") or name:find("%c") or
        (ownerCurrent ~= nil and not owner) or not sourceCurrent() then return nil end
    local locale, _, localeCurrent = nameLocaleScope()
    if not localeCurrent then return nil end
    local function current()
        if owner and read(owner,"boolean") ~= true then return false end
        return localeCurrent() and sourceCurrent()
    end
    if not current() then return nil end
    -- Resolve a lazy dictionary before owning its entry, including an absent entry.
    if locale ~= "enUS" then
        local root = clean(addon.nameTranslations,"table")
        if root and not clean(rawget(root,locale),"table") then nameDictionary(locale,current) end
    end
    if not current() then return nil end
    local database, language, gameGetter = addon.db, addon.Language, GetLocale
    local choice = type(database) == "table" and rawget(database,"locale")
    local selection = type(language) == "table" and rawget(language,"GetSelection")
    local session = type(language) == "table" and rawget(language,"session")
    local preview = type(session) == "table" and rawget(session,"preview")
    local captured, dictionary = pcall(function()
        local root = addon.nameTranslations
        local localized = type(root) == "table" and rawget(root,locale)
        local entries = type(localized) == "table" and rawget(localized,kind)
        local entry = type(entries) == "table" and rawget(entries,id)
        return { root=root, localized=localized, entries=entries, entry=entry,
            source=type(entry) == "table" and rawget(entry,"source"), name=type(entry) == "table" and rawget(entry,"name") }
    end)
    if not captured then return nil end
    local function rawCurrent()
        local valid, same = pcall(function()
            return sourceCurrent() and addon.db == database and addon.Language == language and GetLocale == gameGetter and
                (type(database) ~= "table" or rawequal(rawget(database,"locale"),choice)) and
                (type(language) ~= "table" or rawequal(rawget(language,"GetSelection"),selection)) and
                (type(language) ~= "table" or rawequal(rawget(language,"session"),session)) and
                (type(session) ~= "table" or rawequal(rawget(session,"preview"),preview)) and
                rawequal(addon.nameTranslations,dictionary.root) and
                (type(dictionary.root) ~= "table" or rawequal(rawget(dictionary.root,locale),dictionary.localized)) and
                (type(dictionary.localized) ~= "table" or rawequal(rawget(dictionary.localized,kind),dictionary.entries)) and
                (type(dictionary.entries) ~= "table" or rawequal(rawget(dictionary.entries,id),dictionary.entry)) and
                (type(dictionary.entry) ~= "table" or (rawequal(rawget(dictionary.entry,"source"),dictionary.source) and
                    rawequal(rawget(dictionary.entry,"name"),dictionary.name)))
        end)
        return valid and same == true
    end
    -- Retained proof excludes the caller owner; UI scopes compose it with their own ownership.
    local function proof() return localeCurrent() and rawCurrent() end
    local result
    if locale == "enUS" then result = name
    elseif type(dictionary.localized) == "table" then
        result = translatedName(kind,id,place,function() return current() and rawCurrent() end,locale)
    end
    if not proof() or (owner and read(owner,"boolean") ~= true) or not rawCurrent() then return nil, proof, rawCurrent end
    if result and locale ~= "enUS" and (dictionary.source ~= name or dictionary.name ~= result) then return nil end
    -- A valid missing label also owns its absence until the dictionary or locale changes.
    return result, proof, rawCurrent
end

-- Bulk browsing reads an existing native title or a reviewed locale label;
-- neither route starts quest hydration.
function addon.CachedQuestName(id)
    local checker = issecretvalue
    id = dialogueInteger(id, 1, 9007199254740991)
    local character = addon.Clean(addon.char, "table")
    local catalogue = addon.Clean(addon.quests, "table")
    local definition = id and catalogue and addon.Clean(rawget(catalogue, id), "table")
    local locale, clientLocale, localeCurrent = nameLocaleScope()
    local function sourceCurrent()
        return localeCurrent and localeCurrent() and addon.char == character and addon.quests == catalogue and
            catalogue and rawget(catalogue, id) == definition and definition and
            dialogueInteger(rawget(definition, "id"), 1, 9007199254740991) == id
    end
    local translated, translationCurrent
    if id and definition and sourceCurrent() then
        translated, translationCurrent = translatedName("quests", id, definition, sourceCurrent, locale)
        if locale ~= "enUS" and translated and translationCurrent and translationCurrent() then return translated end
        if locale ~= clientLocale then return translated end
    end
    local quest = addon.Clean(C_QuestLog, "table")
    local getter = quest and addon.Clean(rawget(quest, "GetTitleForQuestID"), "function")
    local playerGetter, localeGetter = addon.Clean(UnitGUID, "function"), GetLocale
    local scope = restrictionNameScope()
    local player = addon.Read(playerGetter, "string", "player")
    if not id or not character or not definition or not getter or not scope or
        not player or #player > 256 or not player:find("%S") or
        dialogueInteger(rawget(definition, "id"), 1, 9007199254740991) ~= id then return translationCurrent and translationCurrent() and translated or nil end
    local function current()
        local currentPlayer = addon.Read(playerGetter, "string", "player")
        if not scope() or currentPlayer ~= player or not sourceCurrent() then return false end
        -- Finish with raw comparisons so sanitizer callbacks cannot replace ownership.
        local ok, same = pcall(function()
            return issecretvalue == checker and addon.char == character and addon.quests == catalogue and
                rawget(catalogue, id) == definition and rawget(definition, "id") == id and
                C_QuestLog == quest and rawget(quest, "GetTitleForQuestID") == getter and
                UnitGUID == playerGetter and GetLocale == localeGetter
        end)
        return ok and same == true
    end
    if not current() then return nil end
    local title = addon.Read(getter, "string", id)
    if not title or #title > 1024 or not title:find("%S") or not current() then return translationCurrent and translationCurrent() and translated or nil end
    return title
end

function addon.QuestName(id)
    id = dialogueInteger(id, 1, 9007199254740991)
    if not id then return "#?" end
    local bundled, bundleCurrent
    local function fallback()
        if bundled and bundleCurrent and bundleCurrent() then return bundled end
        local quests = addon.Clean(addon.quests, "table")
        local definition = quests and addon.Clean(rawget(quests, id), "table")
        local name = definition and addon.Clean(rawget(definition, "name"), "string")
        return name and #name <= 1024 and name:find("%S") and name or ("#" .. id)
    end
    local catalogue = addon.Clean(addon.quests, "table")
    local definition = catalogue and addon.Clean(rawget(catalogue, id), "table")
    -- Hydration requests address catalogue IDs only; uncatalogued IDs stay a local fallback.
    if not definition then return fallback() end
    local locale, clientLocale, localeCurrent = nameLocaleScope()
    local function sourceCurrent()
        return localeCurrent and localeCurrent() and addon.quests == catalogue and catalogue and rawget(catalogue, id) == definition
    end
    bundled, bundleCurrent = translatedName("quests", id, definition, sourceCurrent, locale)
    if locale ~= "enUS" and bundled and bundleCurrent and bundleCurrent() then return bundled end
    if locale ~= clientLocale then
        return fallback()
    end
    local quest = addon.Clean(C_QuestLog, "table")
    local scope = restrictionNameScope()
    if not quest or not scope then return fallback() end
    local getter, loader = addon.Clean(rawget(quest, "GetTitleForQuestID"), "function"),
        addon.Clean(rawget(quest, "RequestLoadQuestByID"), "function")
    local function current()
        return sourceCurrent() and scope() and addon.Clean(C_QuestLog, "table") == quest and
            addon.Clean(rawget(quest, "GetTitleForQuestID"), "function") == getter and
            addon.Clean(rawget(quest, "RequestLoadQuestByID"), "function") == loader
    end
    local title = addon.Read(getter, "string", id)
    if not current() then return fallback() end
    if title and #title <= 1024 and title:find("%S") then return title end
    local request = requested[id]
    if (not request or not (request.pending or request.waiting or request.finished)) and loader then
        request = request or { attempts = 0 }
        requested[id] = request
        request.attempts, request.pending = request.attempts + 1, true
        local ok = pcall(loader, id)
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
    return fallback()
end

function addon.ItemDataResult(id, success)
    id = addon.Clean(id, "number")
    success = addon.Clean(success, "boolean")
    if not id or id < 1 or id % 1 ~= 0 then return end
    dataResult(requestedItems, id, success)
end

-- This explicit action opens native UI and selects a held quest; capability reads never do.
local function questLogOpener(id)
    local checker = issecretvalue
    id = dialogueInteger(id, 1, 9007199254740991)
    local character = addon.Clean(addon.char, "table")
    local catalogue = addon.Clean(addon.quests, "table")
    local definition = id and catalogue and addon.Clean(rawget(catalogue, id), "table")
    local quest = addon.Clean(C_QuestLog, "table")
    local held = quest and addon.Clean(quest.IsOnQuest, "function")
    local logIndex = quest and addon.Clean(quest.GetLogIndexForQuestID, "function")
    local opener = addon.Clean(QuestMapFrame_OpenToQuestDetails, "function")
    if not id or not character or not definition or not held or not logIndex or not opener or
        dialogueInteger(rawget(definition, "id"), 1, 9007199254740991) ~= id then return nil end
    local function current()
        -- No sanitizer/native callbacks after these final raw ownership comparisons.
        local ok, same = pcall(function()
            return issecretvalue == checker and addon.char == character and addon.quests == catalogue and
                rawget(catalogue, id) == definition and rawget(definition, "id") == id and
                C_QuestLog == quest and quest.IsOnQuest == held and quest.GetLogIndexForQuestID == logIndex and
                QuestMapFrame_OpenToQuestDetails == opener
        end)
        return ok and same == true
    end
    if not current() then return nil end
    local active = addon.Read(held, "boolean", id)
    if not current() or active ~= true then return nil end
    local index = dialogueInteger(addon.Read(logIndex, "number", id), 1, 9007199254740991)
    if not current() or not index then return nil end
    return opener, id
end

function addon.CanOpenQuestLog(id)
    return questLogOpener(id) ~= nil
end

function addon.OpenQuestLogQuest(id)
    local opener, questID = questLogOpener(id)
    if not opener then return false end
    -- A successful call only confirms dispatch, not native panel visibility.
    local ok = pcall(opener, questID)
    return ok
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
        fallback = limits and dialogueInteger(limits.MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT, 1, 1000000)
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
    count = dialogueInteger(count, 0, 1000000)
    if not count or not current() then return nil end
    local capacity = getter and dialogueInteger(addon.Read(getter, "number"), 1, 1000000) or fallback
    if not capacity or not current() then return nil end
    return { count = count, capacity = capacity }
end

function addon.CarriedItemCount(id)
    id = dialogueInteger(id, 1, 4294967295)
    local item = addon.Clean(C_Item, "table")
    local getter = item and addon.Clean(item.GetItemCount, "function")
    local quests = addon.Clean(addon.quests, "table")
    local checker = issecretvalue
    if not id or not getter or not quests then return nil end
    local function relation(ownerKey, quest, field, entries, index, entry, quantity, name)
        return function()
            local ok, valid = pcall(function()
                if C_Item ~= item or rawget(item, "GetItemCount") ~= getter or addon.quests ~= quests or
                    issecretvalue ~= checker or rawget(quests, ownerKey) ~= quest or rawget(quest, field) ~= entries or
                    (index and rawget(entries, index) or entries) ~= entry or rawget(entry, "itemID") ~= id then return false end
                if (field == "objectiveItems" or field == "providedItems") and rawget(entry, "quantity") ~= quantity then return false end
                if (field == "objectiveItems" or field == "providedItems") and (#entries < 1 or #entries > 100) then return false end
                if field == "providedItems" then
                    if rawget(entry, "name") ~= name then return false end
                    for key in next, entry do
                        if key ~= "itemID" and key ~= "name" and key ~= "quantity" then return false end
                    end
                end
                return true
            end)
            return ok and valid == true
        end
    end
    local function inQuest(ownerKey, value)
        local quest = addon.Clean(value, "table")
        local start = quest and addon.Clean(quest.start, "table")
        if start and addon.Clean(start.itemID, "number") == id then
            local candidate = relation(ownerKey, quest, "start", start, nil, start)
            if candidate() then return candidate end
        end
        for _, field in ipairs({ "objectiveItems", "providedItems" }) do
            local entries = quest and addon.Clean(quest[field], "table")
            if entries and #entries >= 1 and #entries <= 100 then
                for index = 1, #entries do
                    local entry = addon.Clean(entries[index], "table")
                    if entry then
                        local provided = field == "providedItems"
                        local itemID = dialogueInteger(rawget(entry, "itemID"), 1, provided and 4294967295 or 9007199254740991)
                        local name = provided and addon.Clean(rawget(entry, "name"), "string") or nil
                        local named = not provided or name and #name <= 500 and name:find("%S")
                        local quantity = rawget(entry, "quantity")
                        local readable = true
                        if type(issecretvalue) == "function" then
                            local ok, restricted = pcall(issecretvalue, quantity)
                            readable = ok and addon.Clean(restricted, "boolean") == false
                        end
                        if named and readable and itemID == id and (type(quantity) == "nil" or
                            dialogueInteger(quantity, 1, 9007199254740991)) then
                            local candidate = relation(ownerKey, quest, field, entries, index, entry, quantity, name)
                            if candidate() then return candidate end
                        end
                    end
                end
            end
        end
        local related = quest and addon.Clean(quest.completionQuests, "table")
        if related then
            for index = 1, math.min(#related, 100) do
                local entry = addon.Clean(related[index], "table")
                if entry and addon.Clean(entry.itemID, "number") == id then
                    local candidate = relation(ownerKey, quest, "completionQuests", related, index, entry)
                    if candidate() then return candidate end
                end
            end
        end
    end
    local relations = carriedRelations[quests]
    if not relations then relations = {}; carriedRelations[quests] = relations end
    local function linked()
        -- Reuse a positive source location, never a carried count. Revalidate
        -- every role field and fall back to the catalogue if that source moved.
        local saved = relations[id]
        if saved and rawget(quests, saved.key) == saved.quest then
            local candidate = inQuest(saved.key, saved.quest)
            if candidate then return candidate end
        end
        relations[id] = nil
        for ownerKey, value in next, quests do
            local candidate = inQuest(ownerKey, value)
            if candidate then
                relations[id] = { key = ownerKey, quest = value }
                return candidate
            end
        end
        return false
    end
    local function current()
        return addon.Clean(C_Item, "table") == item and addon.Clean(item.GetItemCount, "function") == getter and
            addon.Clean(addon.quests, "table") == quests and issecretvalue == checker
    end
    local before = linked()
    if not before or not current() or not before() then return nil end
    local count = addon.Read(getter, "number", id, false, false, false, false)
    local after = linked()
    if not count or count < 0 or count > 9007199254740991 or count % 1 ~= 0 or not after or not current() or not after() then return nil end
    return count
end

function addon.ItemIcon(id)
    local checker = issecretvalue
    id = dialogueInteger(id, 1, 4294967295)
    local item = addon.Clean(C_Item, "table")
    local getter = item and addon.Clean(rawget(item, "GetItemIconByID"), "function")
    if not id or not item or not getter or issecretvalue ~= checker then return nil end
    local function current()
        if issecretvalue ~= checker or addon.Clean(C_Item, "table") ~= item or
            addon.Clean(rawget(item, "GetItemIconByID"), "function") ~= getter then return false end
        -- Sanitization can reenter; finish with identities that invoke no helpers.
        local ok, same = pcall(function()
            if C_Item ~= item or rawget(item, "GetItemIconByID") ~= getter or issecretvalue ~= checker then return false end
            return true
        end)
        return ok and same == true
    end
    if not current() then return nil end
    local icon = dialogueInteger(addon.Read(getter, "number", id), 1, 4294967295)
    if current() then return icon end
end

function addon.ItemName(id, ownerCurrent)
    id = addon.Clean(id, "number")
    if not id or id < 1 or id > 4294967295 or id % 1 ~= 0 then return nil end
    local item = addon.Clean(C_Item, "table")
    local scope = restrictionNameScope()
    local owner = addon.Clean(ownerCurrent, "function")
    if not item or not scope or (ownerCurrent ~= nil and not owner) then return nil end
    local nameGetter = addon.Clean(item.GetItemNameByID, "function")
    local cacheGetter = addon.Clean(item.IsItemDataCachedByID, "function")
    local loader = addon.Clean(item.RequestLoadItemDataByID, "function")
    local function capabilities()
        return scope() and addon.Clean(C_Item, "table") == item and
            addon.Clean(item.GetItemNameByID, "function") == nameGetter and
            addon.Clean(item.IsItemDataCachedByID, "function") == cacheGetter and
            addon.Clean(item.RequestLoadItemDataByID, "function") == loader
    end
    local function current()
        if not capabilities() then return false end
        if not owner then return true end
        return addon.Read(owner, "boolean") == true and capabilities()
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
    local scarletClean, scarletRead, scarletChecker, scarletProvider = addon.Clean, addon.Read, issecretvalue, addon.DungeonName
    local database, language, gameGetter, dictionaries = addon.db, addon.Language, GetLocale, addon.locales
    local fields, values, snapshots = { "key", "name", "wing", "activityID", "complexKey", "instanceID" }, {}, {}
    local function capture(t, key)
        local value = type(t) == "table" and rawget(t, key) or nil
        snapshots[#snapshots + 1] = { t, key, value }
        return value
    end
    for _, field in ipairs(fields) do values[field] = capture(d, field) end
    local choice, previewGetter = capture(database, "locale"), capture(language, "GetSelection")
    for _, locale in ipairs({ "enUS", "ruRU", "deDE", "frFR", "esES", "itIT", "ptBR", "koKR", "zhCN", "zhTW" }) do
        local dictionary = capture(dictionaries, locale)
        for _, wing in ipairs({ "graveyard", "library", "armory", "cathedral" }) do capture(dictionary, "DUNGEON_SCARLET_" .. wing) end
    end
    local function helpersCurrent()
        return addon.Clean == scarletClean and addon.Read == scarletRead and issecretvalue == scarletChecker and addon.DungeonName == scarletProvider
    end
    local function sourceCurrent()
        local ok, valid = pcall(function()
            if not helpersCurrent() or addon.db ~= database or addon.Language ~= language or GetLocale ~= gameGetter or addon.locales ~= dictionaries then return false end
            for _, item in ipairs(snapshots) do
                local current = type(item[1]) == "table" and rawget(item[1], item[2]) or nil
                if not rawequal(current, item[3]) then return false end
            end
            return true
        end)
        return ok and valid == true
    end
    -- Check the raw dispatch key without invoking a mutable read adapter.
    if type(scarletChecker) == "function" then
        local ok, secret = pcall(scarletChecker, values.key)
        if not helpersCurrent() or not ok or secret ~= false then return "" end
    end
    local scarletKey = values.key
    if scarletKey == "sm_graveyard" or scarletKey == "sm_library" or scarletKey == "sm_armory" or scarletKey == "sm_cathedral" then
        local function sanitized(value, kind)
            if not sourceCurrent() then return nil end
            local ok, result = pcall(scarletClean, value, kind)
            if not sourceCurrent() or not ok then return nil end
            return result
        end
        local function external(fn, kind, ...)
            if not sourceCurrent() then return nil end
            fn = sanitized(fn, "function")
            if not fn or not sourceCurrent() then return nil end
            local ok, result = pcall(fn, ...)
            if not sourceCurrent() or not ok then return nil end
            return sanitized(result, kind)
        end
        if not sourceCurrent() then return "" end
        for _, field in ipairs(fields) do
            if type(scarletChecker) == "function" then
                local ok, secret = pcall(scarletChecker, values[field])
                if not sourceCurrent() or not ok or secret ~= false then return "" end
            end
        end
        local wing = sanitized(values.wing, "string")
        local activity = sanitized(values.activityID, "number")
        local complex = sanitized(values.complexKey, "string")
        local instance = sanitized(values.instanceID, "number")
        local source = sanitized(values.name, "string")
        if not sourceCurrent() then return "" end
        if not source or #source > 1024 or not source:find("%S") then source = "" end
        local expected = { graveyard = 805, library = 829, armory = 827, cathedral = 828 }
        if not wing or scarletKey ~= "sm_" .. wing or expected[wing] ~= activity or complex ~= "sm" or instance ~= 189 then return source end
        local selected = sanitized(choice, "string")
        local preview = external(previewGetter, "string", language)
        local game = external(gameGetter, "string")
        if not sourceCurrent() then return "" end
        selected = preview or selected or "auto"
        local locale = selected == "auto" and game or selected
        if locale == "enGB" then locale = "enUS" elseif locale == "esMX" then locale = "esES" end
        if locale ~= "enUS" and locale ~= "ruRU" and locale ~= "deDE" and locale ~= "frFR" and locale ~= "esES" and
            locale ~= "itIT" and locale ~= "ptBR" and locale ~= "koKR" and locale ~= "zhCN" and locale ~= "zhTW" then locale = "enUS" end
        local root = sanitized(dictionaries, "table")
        local dictionary = root and sanitized(rawget(root, locale), "table")
        local label = dictionary and sanitized(rawget(dictionary, "DUNGEON_SCARLET_" .. wing), "string")
        if not sourceCurrent() then return "" end
        local nextPreview = external(previewGetter, "string", language)
        local nextGame = external(gameGetter, "string")
        if not sourceCurrent() or nextPreview ~= preview or nextGame ~= game then return "" end
        if label and #label <= 1024 and label:find("%S") then return label end
        return source
    end
    d = addon.Clean(d, "table") or {}
    local bundled, bundleCurrent
    local function fallback()
        if bundled and bundleCurrent and bundleCurrent() then return bundled end
        return addon.Clean(d.name, "string") or ""
    end
    local function identity()
        local instanceID = rawget(d, "instanceID")
        if type(issecretvalue) == "function" then
            local ok, restricted = pcall(issecretvalue, instanceID)
            if not ok or restricted ~= false then return nil end
        end
        if instanceID ~= nil then return dialogueInteger(instanceID, 1) end
        -- Artwork maps may localize labels; they never become navigation or instance identities.
        local art = addon.Clean(d.art, "table")
        local fileID = art and dialogueInteger(art.fileID, 1)
        local mapID = art and dialogueInteger(art.gameMapID, 1)
        if fileID and mapID then return mapID, art, fileID end
    end
    local mapID, art, fileID = identity()
    local key = addon.Clean(rawget(d, "key"), "string")
    if not mapID and not key then return fallback() end
    local locale, clientLocale, localeCurrent = nameLocaleScope()
    local function sourceCurrent()
        return localeCurrent and localeCurrent() and addon.Clean(rawget(d, "key"), "string") == key
    end
    if key then bundled, bundleCurrent = translatedName("dungeons", key, d, sourceCurrent, locale) end
    if locale ~= "enUS" and bundled and bundleCurrent and bundleCurrent() then return bundled end
    if locale ~= clientLocale then return fallback() end
    local source = addon.Clean(d.name, "string")
    if not mapID then return fallback() end
    local wing = addon.Clean(d.wing, "string")
    local getter, localize = addon.Clean(GetRealZoneText, "function"), addon.Clean(addon.L, "function")
    local database = addon.Clean(addon.db, "table")
    local choice = database and addon.Clean(database.locale, "string")
    local scope = restrictionNameScope()
    local function current()
        if not sourceCurrent() or not scope or not scope() then return false end
        local currentMap, currentArt, currentFile = identity()
        return addon.Clean(GetRealZoneText, "function") == getter and
            currentMap == mapID and currentArt == art and currentFile == fileID and addon.Clean(d.name, "string") == source and
            addon.Clean(d.wing, "string") == wing and addon.Clean(addon.L, "function") == localize and
            addon.Clean(addon.db, "table") == database and
            (not database or addon.Clean(database.locale, "string") == choice)
    end
    if not getter or not current() then return fallback() end
    local name = addon.Read(getter, "string", mapID)
    if not current() or not name or #name > 1024 or not name:find("%S") then return fallback() end
    if wing == "lower" or wing == "upper" then
        name = addon.Read(localize, "string", "DUNGEON_WING_" .. wing, name)
        if not current() or not name then return fallback() end
    end
    return name
end

function addon.SourceAreaName(name, ownerCurrent)
    local clean, read, checker = addon.Clean, addon.Read, issecretvalue
    local api, dictionaryGetter = addon.SourceAreaName, addon.GetNameTranslations
    name = clean(name, "string")
    if not name or #name > 1024 or not name:find("%S") or name:find("%c") then return nil end
    if ownerCurrent ~= nil and not clean(ownerCurrent, "function") then return nil end
    local roots = clean(addon.dungeons, "table")
    local locale, _, localeCurrent = nameLocaleScope()
    if not roots or not localeCurrent then return nil end
    local count = #roots
    if count > 100 then return nil end
    local snapshots, match, key, ambiguous = {}, nil, nil, false
    -- Snapshot source records before any callback-bearing field validation.
    for index = 1, count do
        local d = rawget(roots, index)
        local ok, snapshot = pcall(function()
            return { d = d, name = rawget(d, "name"), key = rawget(d, "key") }
        end)
        if not ok then return nil end
        snapshots[index] = snapshot
    end
    local worldRoot = addon.sourceAreaNames
    local worldEntry = type(worldRoot) == "table" and rawget(worldRoot,name)
    local worldName = type(worldEntry) == "table" and rawget(worldEntry,"name")
    for index = 1, count do
        local snapshot = snapshots[index]
        local d = clean(snapshot.d, "table")
        if not d then return nil end
        local source = clean(snapshot.name, "string")
        local candidateKey = clean(snapshot.key, "string")
        if source == name then
            if match or not candidateKey then ambiguous = true end
            match, key = d, candidateKey
        end
    end
    local kind = "dungeons"
    if not match and not ambiguous then
        kind = "areas"
        if clean(worldEntry,"table") and clean(worldName,"string") == name then match, key = worldEntry, name end
    end
    local function rawSourceCurrent()
        local ok, same = pcall(function()
            if addon.Clean ~= clean or addon.Read ~= read or issecretvalue ~= checker or
                addon.SourceAreaName ~= api or addon.GetNameTranslations ~= dictionaryGetter or
                addon.dungeons ~= roots or #roots ~= count then return false end
            for index = 1, count do
                local s = snapshots[index]
                if not rawequal(rawget(roots, index), s.d) or not rawequal(rawget(s.d, "name"), s.name) or
                    not rawequal(rawget(s.d, "key"), s.key) then return false end
            end
            return rawequal(addon.sourceAreaNames,worldRoot) and
                (type(worldRoot) ~= "table" or rawequal(rawget(worldRoot,name),worldEntry)) and
                (type(worldEntry) ~= "table" or rawequal(rawget(worldEntry,"name"),worldName))
        end)
        return ok and same == true
    end
    local function current()
        if ownerCurrent and read(ownerCurrent, "boolean") ~= true then return false end
        return localeCurrent() and rawSourceCurrent()
    end
    if not current() then return nil end
    if match and not ambiguous and locale ~= "enUS" then
        local root = clean(addon.nameTranslations,"table")
        if root and not clean(rawget(root,locale),"table") then nameDictionary(locale,current) end
    end
    if not current() then return nil end
    local database, language, localeGetter = addon.db, addon.Language, GetLocale
    local choice = type(database) == "table" and rawget(database, "locale")
    local selection = type(language) == "table" and rawget(language, "GetSelection")
    local session = type(language) == "table" and rawget(language,"session")
    local preview = type(session) == "table" and rawget(session,"preview")
    local dictionaryRoot = addon.nameTranslations
    local dictionary = type(dictionaryRoot) == "table" and rawget(dictionaryRoot, locale)
    local entries = type(dictionary) == "table" and rawget(dictionary, kind)
    local entry = type(entries) == "table" and rawget(entries, key or name)
    local original = type(entry) == "table" and rawget(entry, "source")
    local translated = type(entry) == "table" and rawget(entry, "name")
    local function rawCurrent()
        local ok, same = pcall(function()
        return rawSourceCurrent() and addon.db == database and addon.Language == language and GetLocale == localeGetter and
            (type(database) ~= "table" or rawequal(rawget(database, "locale"), choice)) and
            (type(language) ~= "table" or rawequal(rawget(language, "GetSelection"), selection)) and
            (type(language) ~= "table" or rawequal(rawget(language,"session"),session)) and
            (type(session) ~= "table" or rawequal(rawget(session,"preview"),preview)) and
            rawequal(addon.nameTranslations, dictionaryRoot) and
            (type(dictionaryRoot) ~= "table" or rawequal(rawget(dictionaryRoot, locale), dictionary)) and
            (type(dictionary) ~= "table" or rawequal(rawget(dictionary, kind), entries)) and
            (type(entries) ~= "table" or rawequal(rawget(entries, key or name), entry)) and
            (type(entry) ~= "table" or (rawequal(rawget(entry, "source"), original) and
                rawequal(rawget(entry, "name"), translated)))
        end)
        return ok and same == true
    end
    -- Retained proofs exclude the caller owner and include valid missing labels.
    local function proof() return localeCurrent() and rawCurrent() end
    local result
    if match and not ambiguous then
        if locale == "enUS" then result = name
        elseif type(dictionary) == "table" then
            result = translatedName(kind,key,match,function() return current() and rawCurrent() end,locale)
        end
    end
    if not proof() or (ownerCurrent and read(ownerCurrent,"boolean") ~= true) or not rawCurrent() then return nil, proof, rawCurrent end
    if result and locale ~= "enUS" and (original ~= name or translated ~= result) then return nil end
    return result, proof, rawCurrent
end

local function selectedLogReadScope(id)
    local quest = addon.Clean(C_QuestLog, "table")
    if not quest then return nil end
    local selected = addon.Clean(quest.GetSelectedQuest, "function")
    local logIndex = addon.Clean(quest.GetLogIndexForQuestID, "function")
    local localeGetter, checker = addon.Clean(GetLocale, "function"), issecretvalue
    local character = addon.Clean(addon.char, "table")
    local locale = addon.Read(localeGetter, "string")
    if not locale or #locale > 32 or not locale:find("%S") then return nil end
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
    return current, locale, index
end

function addon.Description(id)
    -- Cap IDs at 2^53 so huge IDs fall back without native reads or texts writes.
    id = dialogueInteger(id, 1, 9007199254740991)
    if not id then return addon.L("NO_TEXT") end
    local generation, clean, read, checker, provider = textCaptureGeneration, addon.Clean, addon.Read, issecretvalue, addon.Description
    local character = addon.Clean(addon.char, "table")
    local texts = character and addon.Clean(character.texts, "table")
    local getter = addon.Clean(GetQuestLogQuestText, "function")
    local scope, locale = selectedLogReadScope(id)
    local function owned()
        local valid = textCaptureGeneration == generation and addon.Clean(addon.char, "table") == character and
            (not character or addon.Clean(character.texts, "table") == texts) and
            addon.Clean(GetQuestLogQuestText, "function") == getter
        if not valid then return false end
        local ok, same = pcall(function()
            return textCaptureGeneration == generation and addon.Clean == clean and addon.Read == read and
                issecretvalue == checker and addon.Description == provider and rawget(addon, "char") == character and
                (not character or rawget(character, "texts") == texts) and GetQuestLogQuestText == getter
        end)
        return ok and same == true
    end
    -- The text reader uses the current selection; never change it to fetch text.
    if scope and owned() and scope() then
        local text = addon.Read(getter, "string")
        if text and #text <= 30000 and text:find("%S") and scope() and owned() then
            if locale and texts then texts[id] = { text = text, locale = locale } end
            return text
        end
    end
    local localeGetter, checker = addon.Clean(GetLocale, "function"), issecretvalue
    locale = addon.Read(localeGetter, "string")
    character = addon.Clean(addon.char, "table")
    texts = character and addon.Clean(character.texts, "table")
    local data = texts and addon.Clean(texts[id], "table")
    if data and locale and #locale <= 32 and locale:find("%S") and addon.Clean(data.locale, "string") == locale then
        local text = addon.Clean(data.text, "string")
        if text and #text <= 30000 and text:find("%S") and
            addon.Read(localeGetter, "string") == locale and addon.Clean(GetLocale, "function") == localeGetter and
            issecretvalue == checker and addon.Clean(addon.char, "table") == character and
            addon.Clean(character.texts, "table") == texts and addon.Clean(texts[id], "table") == data then
            local ok, same = pcall(function()
                return addon.Clean == clean and addon.Read == read and addon.Description == provider and
                    issecretvalue == checker and GetLocale == localeGetter and rawequal(rawget(addon, "char"), character) and
                    rawequal(rawget(character, "texts"), texts) and rawequal(rawget(texts, id), data) and
                    rawequal(rawget(data, "text"), text) and rawequal(rawget(data, "locale"), locale)
            end)
            if ok and same == true then return text end
        end
    end
    return addon.L("NO_TEXT")
end

function addon.QuestObjectives(id)
    -- Cap IDs at 2^53 so huge IDs never reach the native objective reader.
    id = dialogueInteger(id, 1, 9007199254740991)
    if not id then return nil end
    local quest = addon.Clean(C_QuestLog, "table")
    local getter = quest and addon.Clean(quest.GetQuestObjectives, "function")
    if not getter then return nil end
    local character, scope = addon.Clean(addon.char, "table"), restrictionNameScope()
    local function current()
        return scope and scope() and addon.Clean(C_QuestLog, "table") == quest and
            addon.Clean(quest.GetQuestObjectives, "function") == getter and addon.Clean(addon.char, "table") == character
    end
    if not current() then return nil end
    local objectives = addon.Read(getter, "table", id)
    if not current() or not objectives or #objectives > 100 then return nil end
    local result = {}
    for i = 1, #objectives do
        local row = addon.Clean(objectives[i], "table")
        if not row then return nil end
        local text = addon.Clean(row.text, "string")
        local kind = addon.Clean(row.type, "string")
        local finished = addon.Clean(row.finished, "boolean")
        local fulfilled = dialogueInteger(row.numFulfilled, 0, 9007199254740991)
        local required = dialogueInteger(row.numRequired, 0, 9007199254740991)
        if not text or #text > 30000 or not kind or #kind > 200 or finished == nil
            or not fulfilled or not required then return nil end
        result[i] = { text = text, type = kind, finished = finished,
            numFulfilled = fulfilled, numRequired = required,
            objectiveType = addon.Clean(row.objectiveType, "number") }
    end
    return current() and result or nil
end

function addon.QuestRewards(id)
    local function integer(value, minimum, maximum)
        value = addon.Clean(value, "number")
        if value and value >= minimum and value % 1 == 0 and (not maximum or value <= maximum) then return value end
    end
    id = integer(id, 1, 9007199254740991)
    if not id then return nil end
    local scope, _, scopeIndex = selectedLogReadScope(id)
    if not scope then return nil end
    local xpQuest, xpGetter, xpLoaded, xpChecker = C_QuestLog, GetQuestLogRewardXP, HaveQuestRewardData, issecretvalue
    local xpLibrary = addon.Clean(xpQuest, "table")
    local xpVisible = xpLibrary and rawget(xpLibrary, "ShouldShowQuestRewards")
    local xpLocaleGetter, xpCharacter = GetLocale, addon.char
    local rawBase = { selected = xpLibrary and rawget(xpLibrary, "GetSelectedQuest"),
        index = xpLibrary and rawget(xpLibrary, "GetLogIndexForQuestID"), rewards = GetNumQuestLogRewards,
        choices = GetNumQuestLogChoices, fixed = GetQuestLogRewardInfo, choice = GetQuestLogChoiceInfo, money = GetQuestLogRewardMoney }
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
            amount, itemID = integer(amount, 1, 9007199254740991), integer(itemID, 1, 4294967295)
            if not name or name == "" or #name > 30000 or not amount or not itemID then return nil end
            local row = { id = itemID, name = name, count = amount }
            local icon = addon.Clean(texture, "string")
            if icon and icon ~= "" and #icon <= 1024 then row.texture = icon
            else row.texture = integer(texture, 1, 9007199254740991) end
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
    local money = integer(addon.Read(api.money, "number"), 0, 9007199254740991)
    if not selected() then return nil end
    local xp
    local xpFunction = addon.Clean(xpGetter, "function")
    local loadedFunction = addon.Clean(xpLoaded, "function")
    local visibleFunction = addon.Clean(xpVisible, "function")
    local xpLocale = xpFunction and loadedFunction and visibleFunction and addon.Read(xpLocaleGetter, "string")
    local function xpIdentities()
        local ok, same = pcall(function()
            return C_QuestLog == xpQuest and rawget(xpLibrary, "ShouldShowQuestRewards") == xpVisible and
                GetQuestLogRewardXP == xpGetter and HaveQuestRewardData == xpLoaded and
                GetLocale == xpLocaleGetter and addon.char == xpCharacter and issecretvalue == xpChecker
        end)
        return ok and same == true
    end
    local function xpCurrent()
        if not xpIdentities() or not selected() then return false end
        if addon.Read(loadedFunction, "boolean", id) ~= true or not xpIdentities() then return false end
        if addon.Read(visibleFunction, "boolean", id) ~= true or not xpIdentities() then return false end
        if addon.Read(xpLocaleGetter, "string") ~= xpLocale or not selected() then return false end
        return xpIdentities()
    end
    if xpFunction and loadedFunction and visibleFunction and
        xpLocale and #xpLocale <= 32 and xpLocale:find("%S") and xpCurrent() then
        -- The first return is total XP. Explicit ID does not change selection.
        local value = integer(addon.Read(xpFunction, "number", id), 0, 9007199254740991)
        if xpCurrent() then xp = value end
    end
    if xp ~= nil and not xpCurrent() then xp = nil end
    if not selected() then return nil end
    if xp ~= nil then
        -- Selection reads above may have made optional reward data cold or hidden.
        if addon.Read(loadedFunction, "boolean", id) ~= true or
            addon.Read(visibleFunction, "boolean", id) ~= true or not xpIdentities() then xp = nil end
        -- Optional native reads may change selection without replacing their functions.
        local finalIndex = dialogueInteger(addon.Read(rawBase.index, "number", id), 1)
        local finalSelected = addon.Read(rawBase.selected, "number")
        if finalIndex ~= scopeIndex or finalSelected ~= id then return nil end
        local ok, owned, xpOwned = pcall(function()
            return C_QuestLog == xpQuest and addon.char == xpCharacter and GetLocale == xpLocaleGetter and issecretvalue == xpChecker and
                rawget(xpLibrary, "GetSelectedQuest") == rawBase.selected and rawget(xpLibrary, "GetLogIndexForQuestID") == rawBase.index and
                GetNumQuestLogRewards == rawBase.rewards and GetNumQuestLogChoices == rawBase.choices and
                GetQuestLogRewardInfo == rawBase.fixed and GetQuestLogChoiceInfo == rawBase.choice and GetQuestLogRewardMoney == rawBase.money,
                GetQuestLogRewardXP == xpGetter and HaveQuestRewardData == xpLoaded and
                rawget(xpLibrary, "ShouldShowQuestRewards") == xpVisible
        end)
        if not ok or owned ~= true then return nil end
        if xpOwned ~= true then xp = nil end
    end
    return { items = fixed, choices = choice, money = money, xp = xp }
end

function addon.CachedQuestRewards(id)
    local clean, read, generation = addon.Clean, addon.Read, contextGeneration
    local character, database = addon.char, addon.db
    -- Cap IDs at 2^53 so huge doubles cannot wrap into another valid quest ID in native readers.
    id = dialogueInteger(id, 1, 9007199254740991)
    local catalogue = clean(addon.quests, "table")
    local catalog = id and catalogue and clean(rawget(catalogue, id), "table")
    if not catalog or dialogueInteger(rawget(catalog, "id"), 1, 9007199254740991) ~= id then return nil end
    local api = { loaded = HaveQuestRewardData, locale = GetLocale, rewards = GetNumQuestLogRewards,
        choices = GetNumQuestLogChoices, fixed = GetQuestLogRewardInfo, choice = GetQuestLogChoiceInfo,
        money = GetQuestLogRewardMoney, xp = GetQuestLogRewardXP, secret = issecretvalue }
    local function unchanged()
        local ok, same = pcall(function()
            return contextGeneration == generation and addon.char == character and addon.db == database and
                addon.Clean == clean and addon.Read == read and addon.quests == catalogue and
                rawget(catalogue, id) == catalog and rawget(catalog, "id") == id and
                api.loaded == HaveQuestRewardData and api.locale == GetLocale and
                api.rewards == GetNumQuestLogRewards and api.choices == GetNumQuestLogChoices and
                api.fixed == GetQuestLogRewardInfo and api.choice == GetQuestLogChoiceInfo and
                api.money == GetQuestLogRewardMoney and api.xp == GetQuestLogRewardXP and api.secret == issecretvalue
        end)
        return ok and same == true
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
            amount, itemID = dialogueInteger(amount, 1, 9007199254740991), dialogueInteger(itemID, 1, 4294967295)
            if not name or name == "" or #name > 30000 or not amount or not itemID then return nil end
            local row = { id = itemID, name = name, count = amount }
            local icon = addon.Clean(texture, "string")
            if icon and icon ~= "" and #icon <= 1024 then row.texture = icon
            else row.texture = dialogueInteger(texture, 1, 9007199254740991) end
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
        -- Cap display integers at 2^53 so huge or fractional doubles stay a nil field, not a wrapped value.
        if value and (value < 0 or value % 1 ~= 0 or value > 9007199254740991) then value = nil end
        return value, true
    end
    local money, moneyOK = scalar(api.money)
    local xp, xpOK = scalar(api.xp)
    if not moneyOK or not xpOK or not loaded() then return nil end
    return { source = "cache", items = fixed, choices = choice, money = money, xp = xp }
end

-- Explicit preload is separate from the cache reader and requires a live caller scope.
function addon.RequestQuestRewardData(id, ownerCurrent)
    local clean, read, checker = addon.Clean, addon.Read, issecretvalue
    id = dialogueInteger(id, 1, 9007199254740991)
    ownerCurrent = clean(ownerCurrent, "function")
    local catalogue = clean(addon.quests, "table")
    local definition = id and catalogue and clean(rawget(catalogue, id), "table")
    local task = clean(C_TaskQuest, "table")
    local loader = task and clean(rawget(task, "RequestPreloadRewardData"), "function")
    local loaded, localeGetter, character, database = clean(HaveQuestRewardData, "function"), GetLocale, addon.char, addon.db
    local getter = addon.RequestQuestRewardData
    if not definition or dialogueInteger(rawget(definition, "id"), 1, 9007199254740991) ~= id or
        not ownerCurrent or not loader or not loaded then return false end
    local locale = read(localeGetter, "string")
    local function same()
        local ok, valid = pcall(function() return addon.Clean == clean and addon.Read == read and issecretvalue == checker and
            addon.RequestQuestRewardData == getter and addon.quests == catalogue and rawget(catalogue, id) == definition and
            dialogueInteger(rawget(definition, "id"), 1, 9007199254740991) == id and
            addon.char == character and addon.db == database and C_TaskQuest == task and
            rawget(task, "RequestPreloadRewardData") == loader and HaveQuestRewardData == loaded and GetLocale == localeGetter end)
        return ok and valid == true
    end
    local function current()
        if not same() or read(ownerCurrent, "boolean") ~= true or not same() then return false end
        return read(localeGetter, "string") == locale and same()
    end
    if not locale or #locale > 32 or not locale:find("%S") or not current() or
        read(loaded, "boolean", id) ~= false or not current() then return false end
    local ok, result = pcall(loader, id)
    return ok and (type(checker) ~= "function" or read(checker, "boolean", result) == false) and
        clean(result, "boolean") ~= false and current()
end

-- Reward IDs can be loaded before their item names and textures are cached.
function addon.RequestQuestRewardItems(id, ownerCurrent)
    local clean, read, checker = addon.Clean, addon.Read, issecretvalue
    id = dialogueInteger(id, 1, 9007199254740991)
    local owner = clean(ownerCurrent, "function")
    local catalogue = clean(addon.quests, "table")
    local definition = id and catalogue and clean(rawget(catalogue, id), "table")
    local character, database, provider = addon.char, addon.db, addon.RequestQuestRewardItems
    local api = { loaded = HaveQuestRewardData, locale = GetLocale, rewards = GetNumQuestLogRewards,
        choices = GetNumQuestLogChoices, fixed = GetQuestLogRewardInfo, choice = GetQuestLogChoiceInfo,
        itemName = addon.ItemName }
    if not owner or not definition or dialogueInteger(rawget(definition, "id"), 1, 9007199254740991) ~= id or
        not clean(api.itemName, "function") then return false end
    local locale = read(api.locale, "string")
    local function identities()
        local ok, same = pcall(function()
            return addon.Clean == clean and addon.Read == read and issecretvalue == checker and
                addon.RequestQuestRewardItems == provider and addon.ItemName == api.itemName and
                addon.quests == catalogue and rawget(catalogue, id) == definition and rawequal(rawget(definition, "id"), id) and
                addon.char == character and addon.db == database and HaveQuestRewardData == api.loaded and GetLocale == api.locale and
                GetNumQuestLogRewards == api.rewards and GetNumQuestLogChoices == api.choices and
                GetQuestLogRewardInfo == api.fixed and GetQuestLogChoiceInfo == api.choice
        end)
        return ok and same == true
    end
    local function current()
        return identities() and read(owner, "boolean") == true and identities() and
            read(api.locale, "string") == locale and read(api.loaded, "boolean", id) == true and
            read(owner, "boolean") == true and identities()
    end
    if not locale or #locale > 32 or not locale:find("%S") or not current() then return false end
    local fixed = dialogueInteger(read(api.rewards, "number", id), 0, 100)
    local choices = dialogueInteger(read(api.choices, "number", id), 0, 100)
    if not fixed or not choices or not current() then return false end
    local ids, seen = {}, {}
    for _, group in ipairs({{count=fixed,getter=api.fixed},{count=choices,getter=api.choice}}) do
        if group.count > 0 and not clean(group.getter, "function") then return false end
        for index = 1, group.count do
            local ok, _, _, _, _, _, itemID = pcall(group.getter, index, id)
            itemID = dialogueInteger(itemID, 1, 4294967295)
            if not ok or not itemID or not current() then return false end
            if not seen[itemID] then seen[itemID] = true; ids[#ids + 1] = itemID end
        end
    end
    for _, itemID in ipairs(ids) do
        if not current() then return false end
        pcall(api.itemName, itemID, current)
        if not current() then return false end
    end
    return current()
end

function addon.QuestPortrait(id)
    -- Cap IDs at 2^53 so huge IDs never reach the native portrait reader.
    id = dialogueInteger(id, 1, 9007199254740991)
    if not id then return nil end
    local quest = addon.Clean(C_QuestLog, "table")
    local getter = quest and addon.Clean(rawget(quest, "GetQuestLogPortraitGiver"), "function")
    if not getter then return nil end
    local scope, _, index = selectedLogReadScope(id)
    local function owned()
        return addon.Clean(C_QuestLog, "table") == quest and
            addon.Clean(rawget(quest, "GetQuestLogPortraitGiver"), "function") == getter
    end
    local function current() return owned() and scope and scope() and owned() end
    if not current() then return nil end
    -- The optional argument is a log index, and the portrait is not an NPC ID.
    local ok, displayID, _, name = pcall(getter, index)
    if not ok then return nil end
    -- A native zero is an explicit "no portrait" instruction, not unknown.
    if addon.Clean(displayID, "number") == 0 then
        if current() then return { hidden = true } end
        return nil
    end
    displayID = dialogueInteger(displayID, 1, 4294967295)
    if not displayID then return nil end
    local result = { displayID = displayID }
    name = addon.Clean(name, "string")
    if name and name ~= "" and #name <= 1024 then result.name = name end
    if current() then return result end
end

function addon.CaptureQuestText()
    local generation = {}
    textCaptureGeneration = generation
    local clean, read, capture = addon.Clean, addon.Read, addon.CaptureQuestText
    local character, quests = addon.Clean(addon.char, "table"), addon.Clean(addon.quests, "table")
    local texts = character and addon.Clean(rawget(character, "texts"), "table")
    local idGetter, localeGetter, textGetter = addon.Clean(GetQuestID, "function"),
        addon.Clean(GetLocale, "function"), addon.Clean(GetQuestText, "function")
    local checker = issecretvalue
    if not texts or not quests or not idGetter or not localeGetter or not textGetter then return end
    local id = dialogueInteger(addon.Read(idGetter, "number"), 1)
    local definition = id and addon.Clean(rawget(quests, id), "table")
    local locale = addon.Read(localeGetter, "string")
    if not definition or not locale or #locale > 32 or not locale:find("%S") then return end
    local function owned()
        local valid = textCaptureGeneration == generation and issecretvalue == checker and
            addon.Clean(addon.char, "table") == character and addon.Clean(rawget(character, "texts"), "table") == texts and
            addon.Clean(addon.quests, "table") == quests and addon.Clean(rawget(quests, id), "table") == definition and
            addon.Clean(GetQuestID, "function") == idGetter and addon.Clean(GetLocale, "function") == localeGetter and
            addon.Clean(GetQuestText, "function") == textGetter
        if not valid then return false end
        -- Sanitizers may capture newer text or replace an earlier destination.
        local ok, same = pcall(function()
            return textCaptureGeneration == generation and issecretvalue == checker and
                addon.Clean == clean and addon.Read == read and addon.CaptureQuestText == capture and
                rawget(addon, "char") == character and rawget(character, "texts") == texts and
                rawget(addon, "quests") == quests and rawget(quests, id) == definition and
                GetQuestID == idGetter and GetLocale == localeGetter and GetQuestText == textGetter
        end)
        return ok and same == true
    end
    local function current()
        if not owned() then return false end
        local currentID, currentLocale = addon.Read(idGetter, "number"), addon.Read(localeGetter, "string")
        return currentID == id and currentLocale == locale and owned()
    end
    if not current() then return end
    local text = addon.Read(textGetter, "string")
    if text and #text <= 30000 and text:find("%S") and current() then texts[id] = { text = text, locale = locale } end
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
    local locale = addon.Clean(db.locale, "string")
    local supported = { auto = true, enUS = true, enGB = true, ruRU = true, deDE = true, frFR = true,
        esES = true, esMX = true, itIT = true, ptBR = true, koKR = true, zhCN = true, zhTW = true }
    db.locale = supported[locale or ""] and locale or "auto"
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
