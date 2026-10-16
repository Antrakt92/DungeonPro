local objects, requests, mapCalls, waypoints, total = {}, 0, 0, {}, 0
local methods = {}
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:SetVerticalScroll(value) self.verticalScroll = value; self.scrollWrites = (self.scrollWrites or 0) + 1 end
function methods:GetWidth() return self.width or 340 end
function methods:GetHeight() return self.height or 100 end
function methods:SetPoint(...) self.point = { ... } end
function methods:GetPoint() return unpack(self.point or { "CENTER", nil, "CENTER", 0, 0 }) end
function methods:ClearAllPoints() self.point = nil end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:SetText(value) self.text = value end
function methods:GetText() return self.text or "" end
function methods:GetStringHeight() return 18 end
function methods:SetEnabled(value) self.enabled = value end
function methods:IsShown() return self.shown end
function methods:Show()
    local changed = not self.shown; self.shown = true
    if changed and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide() self.shown = false end
function methods:SetShown(shown) if shown then self:Show() else self:Hide() end end
function methods:SetTexture(value) self.texture = value end
function methods:SetRotation(value) assert(type(value) == "number"); self.rotation = value end
local function create(kind, name)
    local frame = { kind = kind, name = name, scripts = {}, events = {}, shown = false }
    setmetatable(frame, { __index = methods }); objects[#objects + 1] = frame
    if name then _G[name] = frame end
    return frame
end
function methods:CreateFontString() return create("FontString") end
function methods:CreateTexture() return create("Texture") end
for _, name in ipairs({ "SetAllPoints", "SetFont", "SetJustifyH", "SetTextColor", "SetColorTexture", "SetHighlightTexture",
    "SetAutoFocus", "SetFocus", "ClearFocus", "HighlightText", "SetScrollChild", "SetScale", "SetFrameStrata",
    "EnableMouse", "SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetBackdrop",
    "SetBackdropColor", "SetBackdropBorderColor" }) do methods[name] = function() end end
CreateFrame = create
GetLocale = function() return "ruRU" end
GetBuildInfo = function() return "1.60.1", "70425", "", 16001 end
WOW_PROJECT_ID = 18
UnitLevel = function() return 20 end
UnitClass = function() return "Mage", "MAGE", 8 end
UnitRace = function() return "Dwarf", "Dwarf", 3 end
UnitFactionGroup = function() return "Alliance" end
GetRealZoneText = function() return nil end
GetScreenWidth = function() return 1920 end
GetPlayerFacing = function() return 0 end
GetQuestID = function() return 65 end
GetQuestText = function() return "An offered quest description" end
UIParent, UISpecialFrames, SlashCmdList = create("Frame"), {}, {}
STANDARD_TEXT_FONT = "Fonts\\ARIALN.TTF"
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, IsOnQuest = function() return false end,
    ReadyForTurnIn = function() return false end, GetTitleForQuestID = function() return nil end,
    RequestLoadQuestByID = function() requests = requests + 1 end }
local delayed = {}
C_Timer = { After = function(delay, fn)
    if delay < 1 then fn() else delayed[#delayed + 1] = { delay, fn } end
end }
CreateVector2D = function(x, y) return { x = x, y = y } end
C_Map = { GetMapInfo = function() return { name = "Westfall" } end,
    GetBestMapForUnit = function() return 1436 end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.5 end } end,
    GetWorldPosFromMapPos = function(_, p) return 0, { x = p.y * 1000, y = p.x * 1000 } end,
    OpenWorldMap = function(id) assert(id > 0); mapCalls = mapCalls + 1 end,
    CanSetUserWaypointOnMap = function() return true end,
    GetUserWaypoint = function() return nil end,
    SetUserWaypoint = function(p) waypoints[#waypoints + 1] = p; return true end }
UiMapPoint = { CreateFromCoordinates = function(mapID, x, y) return { mapID = mapID, x = x, y = y } end }
local addon = {}
for line in io.lines("DungeonPro.toc") do
    if line:match("%.lua$") then assert(loadfile((line:gsub("\\", "/"))))("DungeonPro", addon) end
end
local function check(name, fn)
    local ok, err = pcall(fn); assert(ok, name .. ": " .. tostring(err)); total = total + 1; print("PASS " .. name)
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k, v in pairs(value) do result[k] = copy(v) end; return result
end
-- Scope complete acceptance to a detached graph model; production data stays partial.
local function withKnownDefias(fn)
    local actual, fixture = addon.quests, {}
    for id, record in pairs(actual) do fixture[id] = record end
    local ids = { 65, 132, 135, 141, 142, 155, 166 }
    for index, id in ipairs(ids) do
        local record = assert(actual[id]); assert(record.requirementsKnown == false)
        local groups = record.requires or {}; assert(#groups == (index == 1 and 0 or 1))
        if index > 1 then assert(#groups[1].ids == 1 and groups[1].ids[1] == ids[index - 1] and groups[1].mode == nil) end
        fixture[id] = copy(record); fixture[id].requirementsKnown = true
        assert(fixture[id] ~= record and (not record.start or fixture[id].start ~= record.start))
    end
    addon.quests = fixture
    local ok, err = pcall(fn)
    addon.quests = actual
    addon.UI:Refresh()
    for _, id in ipairs(ids) do assert(actual[id].requirementsKnown == false) end
    assert(ok, err)
end
local eventFrame = objects[#objects]
check("Addon initializes on the matching Forever client", function()
    eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "DungeonPro")
    assert(SlashCmdList.DUNGEONPRO and addon.db and addon.char)
    assert(SLASH_DUNGEONPRO1 == "/DP" and SLASH_DUNGEONPRO2 == "/DungeonPro")
end)
check("Window opens and filters without requiring cached quest titles", function()
    SlashCmdList.DUNGEONPRO("")
    assert(addon.UI.frame:IsShown()); assert(#addon.UI.cards == 29)
    for _, d in ipairs(addon.dungeons) do if d.key == "dm" then addon.UI.dungeon = d end end
    addon.UI:Refresh(); assert(#addon.UI.rows == 7)
end)
check("Actual Defias data stays uncertain even after every known parent is completed", function()
    local completed = C_QuestLog.IsQuestFlaggedCompleted
    C_QuestLog.IsQuestFlaggedCompleted = function(id) return id ~= 166 end
    addon.UI.quest = 166; addon.UI:Refresh()
    assert(addon.quests[166].requirementsKnown == false)
    assert(addon.UI.engine:State(166).status == "UNKNOWN" and not addon.UI.action and not addon.UI.guide.enabled)
    assert(#addon.UI.chainButtons == 7, "uncertain acceptance still retains source narrative")
    C_QuestLog.IsQuestFlaggedCompleted = completed; addon.UI:Refresh()
end)
check("Known graph fixture guides to the initial Defias step", function()
    withKnownDefias(function()
        addon.UI.quest = 166; addon.UI:Refresh()
        assert(addon.UI.action.id == 65 and addon.UI.guide.enabled)
        assert(#addon.UI.chainButtons == 7)
    end)
    assert(addon.UI.engine:State(166).status == "UNKNOWN" and not addon.UI.action)
end)
check("Storyline renders separately without inventing dependency readiness", function()
    addon.UI.quest = 92753; addon.UI:RefreshDetail()
    assert(not addon.UI.action and not addon.UI.guide.enabled)
    assert(#addon.UI.chainButtons == 11)
end)
check("Quest title hydration is requested only once per ID", function()
    local before = requests
    for i = 1, 5 do addon.UI:Refresh() end
    assert(requests == before)
end)
check("Native map and waypoint use the resolved ancestor from the known graph fixture", function()
    withKnownDefias(function()
        addon.UI.quest = 166; addon.UI:Refresh()
        addon.UI.guide.scripts.OnClick()
        assert(#waypoints == 1 and waypoints[1].mapID == 1436)
        assert(math.abs(waypoints[1].x - 0.563) < 0.0001 and mapCalls == 1)
    end)
end)
check("Guidance updates both coordinate components", function()
    for _, f in ipairs(objects) do if f.scripts.OnUpdate and f.shown then f.scripts.OnUpdate(f, 0.2) end end
end)
check("Invalid coordinates are rejected", function()
    assert(not addon.Navigation.Start({ id = 65, place = { mapID = 1, x = 101, y = 20 } }))
end)
check("TomTom receives coordinates from the resolved nested place", function()
    local captured
    TomTom = { AddWaypoint = function(_, map, x, y) captured = { map, x, y } end }
    addon.Navigation.Start({ id = 65, place = addon.quests[65].start })
    assert(captured[1] == 1436 and math.abs(captured[2] - 0.563) < 0.0001)
end)
check("Replacing or clearing guidance removes only its own TomTom waypoint", function()
    local removed, counter = {}, 0
    TomTom = { AddWaypoint = function() counter = counter + 1; return counter end,
        RemoveWaypoint = function(_, uid) removed[#removed + 1] = uid end }
    addon.Navigation.Start({ id = 65, place = addon.quests[65].start })
    addon.Navigation.Start({ id = 132, place = addon.quests[132].start })
    assert(#removed == 1 and removed[1] == 1)
    addon.Navigation.Stop(); assert(#removed == 2 and removed[2] == 2)
    addon.Navigation.Stop(); assert(#removed == 2)
end)
check("Clearing guidance preserves a native waypoint moved by the player", function()
    TomTom = nil
    local cleared = 0
    local previousGet, previousClear = C_Map.GetUserWaypoint, C_Map.ClearUserWaypoint
    C_Map.GetUserWaypoint = function() return { uiMapID = 1436, position = { x = 0.2, y = 0.3 } } end
    C_Map.ClearUserWaypoint = function() cleared = cleared + 1 end
    addon.Navigation.Start({ id = 65, place = addon.quests[65].start })
    addon.Navigation.Stop(); assert(cleared == 0)
    C_Map.GetUserWaypoint, C_Map.ClearUserWaypoint = previousGet, previousClear
end)
check("Offered text is captured without altering another quest's text", function()
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_DETAIL")
    assert(addon.Description(65) == "An offered quest description")
    assert(addon.Description(132) ~= "An offered quest description")
end)
check("Native storyline probe is optional and tolerates missing APIs", function()
    SlashCmdList.DUNGEONPRO("probe")
    assert(addon.char.probe.interface == 16001 and next(addon.char.probe.questLines) == nil)
    assert(addon.char.probe.api.lines == false and addon.char.probe.api.logText == false)
end)
check("Close and reopen preserve selection", function()
    SlashCmdList.DUNGEONPRO(""); assert(not addon.UI.frame:IsShown())
    SlashCmdList.DUNGEONPRO(""); assert(addon.UI.frame:IsShown() and addon.UI.quest == 166)
end)
check("Quest-data events pass success to bounded delayed title recovery", function()
    local savedTimer, savedRequest = C_Timer, C_QuestLog.RequestLoadQuestByID
    local callbacks, watchdogs, calls = {}, {}, 0
    C_Timer = { After = function(delay, fn)
        if delay == 2 then callbacks[#callbacks + 1] = fn
        elseif delay == 10 then watchdogs[#watchdogs + 1] = fn else fn() end
    end }
    C_QuestLog.RequestLoadQuestByID = function(id) assert(id == 65); calls = calls + 1 end
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_DATA_LOAD_RESULT", 65, false)
    assert(#callbacks == 1 and calls == 0)
    callbacks[1](); assert(calls == 1)
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_DATA_LOAD_RESULT", 65, true)
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_DATA_LOAD_RESULT", 65, false)
    assert(#watchdogs == 1)
    watchdogs[1]()
    assert(#callbacks == 1 and calls == 1)
    C_Timer, C_QuestLog.RequestLoadQuestByID = savedTimer, savedRequest
end)
check("Unrelated quest events preserve the guide and matching events release it", function()
    local saved, removed, serial = TomTom, {}, 0
    TomTom = { AddWaypoint = function() serial = serial + 1; return serial end,
        RemoveWaypoint = function(_, uid) removed[#removed + 1] = uid end }
    addon.Navigation.Start({ id = 65, place = addon.quests[65].start })
    for _, event in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED" }) do
        eventFrame.scripts.OnEvent(eventFrame, event, 132)
        assert(#removed == 0)
    end
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_ACCEPTED", nil); assert(#removed == 0)
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_ACCEPTED", 65); assert(removed[1] == 1)
    addon.Navigation.Start({ id = 65, place = addon.quests[65].start })
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_REMOVED", 65); assert(removed[2] == 2)
    addon.Navigation.Start({ id = 65, place = addon.quests[65].start })
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_TURNED_IN", 65); assert(removed[3] == 3)
    assert(#removed == 3)
    TomTom = saved
end)
check("Native item-data results route ID and success to the bounded item producer", function()
    assert(eventFrame.events.ITEM_DATA_LOAD_RESULT)
    local original, calls = addon.ItemDataResult, {}
    addon.ItemDataResult = function(id, success) calls[#calls + 1] = { id, success } end
    eventFrame.scripts.OnEvent(eventFrame, "ITEM_DATA_LOAD_RESULT", 7083, true)
    eventFrame.scripts.OnEvent(eventFrame, "ITEM_DATA_LOAD_RESULT", 272448, false)
    assert(#calls == 2 and calls[1][1] == 7083 and calls[1][2] == true)
    assert(calls[2][1] == 272448 and calls[2][2] == false)
    addon.ItemDataResult = original
end)
check("Alternative map-only starters pass a direct place to the actual navigation adapter", function()
    local q, ui = addon.quests[166], addon.UI
    local start, alternatives = q.start, q.startAlternatives
    q.start = nil
    q.startAlternatives = { { npcID = 234, name = "Map-only giver", mapID = 1436 },
        { objectID = 123, name = "Unknown object" } }
    ui.quest = 166; ui:Refresh()
    local before = mapCalls
    assert(ui.startButtons[1].enabled and not ui.startButtons[2].enabled)
    ui.startButtons[1].scripts.OnClick()
    assert(mapCalls == before + 1)
    q.start, q.startAlternatives = start, alternatives; ui:Refresh()
end)
check("Alternative turn-in rows reach actual map and waypoint adapters without changing preparation", function()
    local q, ui = addon.quests[166], addon.UI
    local finish, alternatives = q.finish, q.finishAlternatives
    q.finish = nil
    q.finishAlternatives = { { npcID = 234, name = "Map-only turn-in", mapID = 1 },
        { npcID = 235, name = "Located turn-in", mapID = 1, x = 10, y = 20 } }
    ui.quest = 166; ui:Refresh()
    local beforeMaps, beforePins = mapCalls, #waypoints
    local action, status = ui.action, ui.engine:State(166).status
    ui.finishButtons[1].scripts.OnClick()
    assert(mapCalls == beforeMaps + 1 and ui.action == action and ui.engine:State(166).status == status)
    ui.finishButtons[2].scripts.OnClick()
    assert(#waypoints == beforePins + 1 and waypoints[#waypoints].mapID == 1)
    assert(waypoints[#waypoints].x == 0.1 and waypoints[#waypoints].y == 0.2)
    assert(ui.action == action and ui.engine:State(166).status == status)
    addon.Navigation.Stop()
    q.finish, q.finishAlternatives = finish, alternatives; ui:Refresh()
end)
check("Broken refresh scheduler falls back once and never sticks or recursively notifies", function()
    local timer, notify = C_Timer, addon.Notify
    for _, broken in ipairs({ {}, { After = true }, { After = function() error("scheduler failed") end },
        { After = function(_, fn) fn() end } }) do
        local calls = 0
        C_Timer = broken
        addon.Notify = function()
            calls = calls + 1
            if calls < 5 then eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE") end
        end
        eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
        assert(calls == 1, "immediate fallback must not recursively notify")
        eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
        assert(calls == 2, "a failed timer must not leave refresh pending")
    end
    local callbacks, calls = {}, 0
    C_Timer = { After = function(_, fn) callbacks[#callbacks + 1] = fn end }
    addon.Notify = function() calls = calls + 1 end
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
    eventFrame.scripts.OnEvent(eventFrame, "PLAYER_LEVEL_UP")
    assert(#callbacks == 1 and calls == 0)
    callbacks[1](); assert(calls == 1)
    local stale
    C_Timer = { After = function(_, fn) stale = fn; error("queued then failed") end }
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
    assert(calls == 2)
    callbacks = {}
    C_Timer = { After = function(_, fn) callbacks[#callbacks + 1] = fn end }
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
    stale(); assert(calls == 2)
    callbacks[1](); assert(calls == 3)
    C_Timer, addon.Notify = timer, notify
end)
check("A quest event during an asynchronous refresh queues the next character-state render", function()
    local timer, notify, isOnQuest = C_Timer, addon.Notify, C_QuestLog.IsOnQuest
    local callbacks, calls, active = {}, 0, false
    C_Timer = { After = function(_, fn) callbacks[#callbacks + 1] = fn end }
    C_QuestLog.IsOnQuest = function(id) return id == 166 and active end
    addon.UI.quest = 166
    addon.Notify = function()
        calls = calls + 1
        notify()
        if calls == 1 then
            active = true
            eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
        end
    end
    for _ = 1, 1000 do eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE") end
    assert(#callbacks == 1 and calls == 0)
    callbacks[1]()
    assert(addon.UI.engine:State(166).status ~= "ACTIVE")
    assert(#callbacks == 2, "a state-changing event inside async Notify must schedule a later render")
    callbacks[2]()
    assert(calls == 2 and addon.UI.engine:State(166).status == "ACTIVE")
    C_Timer, addon.Notify, C_QuestLog.IsOnQuest = timer, notify, isOnQuest
end)
check("Current gossip offers add a translated marker without changing unknown quest state or actions", function()
    local oldGossip, oldGUID, oldTime = C_GossipInfo, UnitGUID, GetTime
    UnitGUID = function(unit) return unit == "player" and "Player-offers" or "Creature-offers" end
    local now = 100
    GetTime = function() return now end
    C_GossipInfo = { GetAvailableQuests = function() return { { questID = 92753 } } end,
        SelectAvailableQuest = function() error("selection forbidden") end }
    local ui, q = addon.UI, addon.quests[92753]
    ui.quest = 92753; ui:Refresh()
    local status, requirements = ui.engine:State(92753).status, q.requirementsKnown
    local function marker()
        for _, fs in ipairs(ui.details) do if fs.shown and fs.text == addon.L("OFFERED_NOW") then return true end end
        return false
    end
    assert(status == "UNKNOWN" and not marker() and not ui.action)
    assert(eventFrame.events.GOSSIP_SHOW and eventFrame.events.GOSSIP_CLOSED)
    eventFrame.scripts.OnEvent(eventFrame, "GOSSIP_SHOW")
    assert(marker() and ui.engine:State(92753).status == status and not ui.action)
    assert(q.requirementsKnown == requirements and addon.db.offers == nil and addon.char.offers == nil)
    ui.quest = 166; ui:RefreshDetail(); assert(not marker())
    ui.quest = 92753; ui:RefreshDetail(); assert(marker())
    local expiry = delayed[#delayed]
    assert(expiry[1] == 30, "offer expiry must schedule one delayed refresh")
    now = 130; expiry[2](); assert(not marker(), "expiry must remove the visible marker without another event")
    eventFrame.scripts.OnEvent(eventFrame, "GOSSIP_SHOW"); assert(marker())
    eventFrame.scripts.OnEvent(eventFrame, "GOSSIP_CLOSED", true); assert(not marker())
    C_GossipInfo, UnitGUID, GetTime = oldGossip, oldGUID, oldTime
end)
check("Gossip transition and world quest events clear the actual UI marker while data-load events preserve it", function()
    local oldGossip, oldGUID, oldTime = C_GossipInfo, UnitGUID, GetTime
    UnitGUID = function(unit) return unit == "player" and "Player-offers" or "Creature-offers" end
    GetTime = function() return 100 end
    C_GossipInfo = { GetAvailableQuests = function() return { { questID = 92753 } } end }
    addon.UI.quest = 92753
    for _, event in ipairs({ "QUEST_DETAIL", "QUEST_GREETING", "QUEST_FINISHED", "QUEST_PROGRESS", "QUEST_COMPLETE",
        "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "PLAYER_ENTERING_WORLD",
        "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT" }) do
        assert(eventFrame.events[event], event .. " is not registered")
        eventFrame.scripts.OnEvent(eventFrame, "GOSSIP_SHOW"); assert(addon.CurrentOffer(92753))
        eventFrame.scripts.OnEvent(eventFrame, event, 92753); assert(not addon.CurrentOffer(92753), event)
    end
    eventFrame.scripts.OnEvent(eventFrame, "GOSSIP_SHOW")
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_DATA_LOAD_RESULT", 92753, true)
    eventFrame.scripts.OnEvent(eventFrame, "ITEM_DATA_LOAD_RESULT", 7083, true)
    assert(addon.CurrentOffer(92753))
    eventFrame.scripts.OnEvent(eventFrame, "GOSSIP_CLOSED")
    C_GossipInfo, UnitGUID, GetTime = oldGossip, oldGUID, oldTime
end)
check("Native dialogue events render offered rewards and item refreshes without selected-log fallback", function()
    local saved, keys = {}, { "GetQuestID", "UnitGUID", "QuestFrame", "QuestFrameDetailPanel",
        "GetNumQuestRewards", "GetNumQuestChoices", "GetQuestItemInfo", "GetRewardMoney", "GetRewardXP",
        "GetNumQuestLogRewards", "GetNumQuestLogChoices", "GetQuestLogRewardInfo", "GetQuestLogChoiceInfo",
        "GetQuestLogRewardMoney", "AcceptQuest", "CompleteQuest", "GetQuestReward", "SelectAvailableQuest",
        "SelectGossipAvailableQuest", "CloseQuest" }
    for _, key in ipairs(keys) do saved[key] = _G[key] end
    local predicate, selection, selectedRewards = C_QuestLog.ShouldShowQuestRewards,
        C_QuestLog.SetSelectedQuest, addon.QuestRewards
    local previousQuest, forbiddenCalls, fallbackCalls = addon.UI.quest, 0, 0
    local function forbidden()
        forbiddenCalls = forbiddenCalls + 1
        error("dialogue rendering must not mutate the client or read selected-log rewards")
    end
    for i = 10, #keys do _G[keys[i]] = forbidden end
    C_QuestLog.SetSelectedQuest = forbidden
    addon.QuestRewards = function(...)
        fallbackCalls = fallbackCalls + 1
        return selectedRewards(...)
    end
    local allowed, rewardName, amount, xp = true, "Native fixed reward", 2, 730
    GetQuestID = function() return 65 end
    UnitGUID = function(unit) return unit == "player" and "Player-dialogue-integration" or nil end
    QuestFrame, QuestFrameDetailPanel = { IsShown = function() return true end },
        { IsShown = function() return true end }
    C_QuestLog.ShouldShowQuestRewards = function(id) assert(id == 65); return allowed end
    GetNumQuestRewards = function(...) assert(select("#", ...) == 0); return 1 end
    GetNumQuestChoices = function(...) assert(select("#", ...) == 0); return 1 end
    GetQuestItemInfo = function(kind, index, ...)
        assert(index == 1 and select("#", ...) == 0)
        if kind == "reward" then return rewardName, 123, amount, 3, false, 7001 end
        assert(kind == "choice"); return "Native choice reward", 124, 4, 4, true, 8001
    end
    GetRewardMoney = function() return 0 end
    GetRewardXP = function() return xp end
    local function shown(text)
        for _, fs in ipairs(addon.UI.details) do if fs.shown and fs.text == text then return true end end
        return false
    end
    local function event(name)
        assert(eventFrame.events[name], name .. " must be registered")
        eventFrame.scripts.OnEvent(eventFrame, name)
    end
    event("QUEST_FINISHED")
    addon.UI.quest = 65; addon.UI:Refresh()
    assert(shown(addon.L("REWARD_UNAVAILABLE")) and not shown(addon.L("REWARD_DIALOGUE")))
    fallbackCalls = 0
    event("QUEST_DETAIL")
    assert(shown(addon.L("REWARD_DIALOGUE")) and shown(addon.L("REWARD_ITEMS")))
    assert(shown(addon.L("REWARD_ITEM", rewardName, 2)))
    assert(shown(addon.L("REWARD_CHOICES")) and shown(addon.L("REWARD_ITEM", "Native choice reward", 4)))
    assert(shown(addon.L("REWARD_XP", 730)) and fallbackCalls == 0 and forbiddenCalls == 0)
    rewardName, amount, xp = "Hydrated native reward", 3, 810
    event("QUEST_ITEM_UPDATE")
    assert(shown(addon.L("REWARD_ITEM", rewardName, 3)) and shown(addon.L("REWARD_XP", 810)))
    assert(not shown(addon.L("REWARD_ITEM", "Native fixed reward", 2)) and not shown(addon.L("REWARD_XP", 730)))
    allowed = false; event("QUEST_ITEM_UPDATE")
    assert(shown(addon.L("REWARD_DIALOGUE")) and shown(addon.L("REWARD_HIDDEN")))
    assert(not shown(addon.L("REWARD_NO_ITEMS")) and not shown(addon.L("REWARD_UNAVAILABLE")))
    assert(not shown(addon.L("REWARD_ITEM", rewardName, 3)) and not shown(addon.L("REWARD_XP", 810)))
    assert(fallbackCalls == 0 and forbiddenCalls == 0, "hidden rewards must not fall back to selected-log data")
    allowed = true; event("QUEST_FINISHED")
    assert(shown(addon.L("REWARD_UNAVAILABLE")) and not shown(addon.L("REWARD_DIALOGUE")))
    assert(not shown(addon.L("REWARD_HIDDEN")) and not shown(addon.L("REWARD_ITEM", rewardName, 3)))
    assert(forbiddenCalls == 0)
    for _, key in ipairs(keys) do _G[key] = saved[key] end
    C_QuestLog.ShouldShowQuestRewards, C_QuestLog.SetSelectedQuest = predicate, selection
    addon.QuestRewards, addon.UI.quest = selectedRewards, previousQuest
    addon.UI:Refresh()
end)
check("Real dialogue events keep objective prose separate and clear it on every ownership transition", function()
    local keys = { "GetQuestID", "UnitGUID", "QuestFrame", "QuestFrameDetailPanel", "GetObjectiveText", "GetQuestText" }
    local saved = {}; for _, key in ipairs(keys) do saved[key] = _G[key] end
    local priorQuest, predicate, progress, selected = addon.UI.quest, C_QuestLog.ShouldShowQuestRewards,
        C_QuestLog.GetQuestObjectives, C_QuestLog.GetSelectedQuest
    local id, text, panel, calls = 65, "Current offer objective only", true, 0
    GetQuestID = function() return id end
    UnitGUID = function(unit) return unit == "player" and "Player-objective-integration" or nil end
    QuestFrame = { IsShown = function() return true end }
    QuestFrameDetailPanel = { IsShown = function() return panel end }
    GetObjectiveText = function(...) assert(select("#", ...) == 0); calls = calls + 1; return text end
    GetQuestText = function() return "Separate offered description" end
    C_QuestLog.ShouldShowQuestRewards = function() return false end
    C_QuestLog.GetSelectedQuest = function() return 166 end
    C_QuestLog.GetQuestObjectives = function() return {} end
    local function shown(value)
        for _, fs in ipairs(addon.UI.details) do if fs.shown and fs.text == value then return true end end
        return false
    end
    local function event(name)
        assert(eventFrame.events[name], name .. " must be registered")
        eventFrame.scripts.OnEvent(eventFrame, name, id)
    end
    addon.UI.quest = id; event("QUEST_FINISHED"); addon.UI:Refresh()
    local status, action = addon.UI.engine:State(id).status, addon.UI.action
    assert(not shown(text) and calls == 0)
    event("QUEST_DETAIL")
    assert(shown(text) and shown(addon.L("OBJECTIVE_DIALOGUE")) and shown(addon.L("REWARD_HIDDEN")))
    assert(not shown(addon.L("OBJECTIVE_PROGRESS")))
    assert(addon.UI.engine:State(id).status == status)
    assert((not action and not addon.UI.action) or (action and addon.UI.action.id == action.id))
    assert(addon.char.texts[id].text == "Separate offered description", "summary must not overwrite cached description")
    for _, transition in ipairs({ "QUEST_FINISHED", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_ACCEPTED",
        "QUEST_REMOVED", "QUEST_TURNED_IN", "GOSSIP_SHOW", "GOSSIP_CLOSED", "GOSSIP_OPTIONS_REFRESHED",
        "QUEST_GREETING", "PLAYER_LEAVING_WORLD", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT" }) do
        event("QUEST_DETAIL"); assert(shown(text))
        event(transition)
        assert(not shown(text) and not shown(addon.L("OBJECTIVE_DIALOGUE")), transition .. " retained summary")
    end
    event("QUEST_DETAIL"); local before = calls
    addon.UI.quest = 166; addon.UI:RefreshDetail()
    assert(not shown(text) and calls == before, "another selected card must not read current offer text")
    addon.UI.quest = 65; addon.UI:RefreshDetail(); assert(shown(text))
    panel = false; addon.UI:Refresh(); assert(not shown(text))
    panel = true; addon.UI:Refresh(); assert(not shown(text), "raw ID match must not revive closed ownership")
    event("QUEST_DETAIL"); assert(shown(text))
    text = "Fresh objective after item event"; event("QUEST_ITEM_UPDATE"); assert(shown(text))
    event("QUEST_FINISHED")
    for _, key in ipairs(keys) do _G[key] = saved[key] end
    C_QuestLog.ShouldShowQuestRewards, C_QuestLog.GetQuestObjectives, C_QuestLog.GetSelectedQuest = predicate, progress, selected
    addon.UI.quest = priorQuest; addon.UI:Refresh()
end)
check("Offered portraits render only current display IDs and native hide values suppress log fallback", function()
    local keys = { "GetQuestID", "UnitGUID", "QuestFrame", "QuestFrameDetailPanel", "GetQuestPortraitGiver",
        "SetPortraitTextureFromCreatureDisplayID" }
    local saved = {}; for _, key in ipairs(keys) do saved[key] = _G[key] end
    local previousQuest, logPortrait = addon.UI.quest, addon.QuestPortrait
    local display, panel, fallbackCalls, rendered, reads = 42, true, 0, nil, 0
    GetQuestID = function() return 65 end
    UnitGUID = function(unit) return unit == "player" and "Player-portrait-integration" or nil end
    QuestFrame = { IsShown = function() return true end }
    QuestFrameDetailPanel = { IsShown = function() return panel end }
    GetQuestPortraitGiver = function(...)
        assert(select("#", ...) == 0); reads = reads + 1
        return display, "Ignored portrait text", "Ignored portrait name", 555, 777
    end
    SetPortraitTextureFromCreatureDisplayID = function(texture, id)
        assert(id == 42 or id == 99); rendered = id; texture:SetTexture("display:" .. id)
    end
    addon.QuestPortrait = function() fallbackCalls = fallbackCalls + 1; return { displayID = 99 } end
    local function event(name) eventFrame.scripts.OnEvent(eventFrame, name) end
    event("QUEST_FINISHED"); addon.UI.quest = 65; addon.UI:Refresh()
    assert(rendered == 99 and addon.UI.portrait:IsShown())
    fallbackCalls = 0; event("QUEST_DETAIL")
    assert(rendered == 42 and reads > 0 and addon.UI.portrait:IsShown() and fallbackCalls == 0)
    for _, hidden in ipairs({ 0, -1 }) do
        display = hidden; event("QUEST_ITEM_UPDATE")
        assert(not addon.UI.portrait:IsShown() and addon.UI.portrait.texture == nil)
        assert(fallbackCalls == 0, "explicit current-dialogue omission must not revive selected-log portrait")
    end
    display = 42; event("QUEST_ITEM_UPDATE"); assert(addon.UI.portrait:IsShown())
    panel = false; rendered = nil; addon.UI:Refresh()
    assert(rendered == 99 and fallbackCalls > 0, "closed current dialogue may use valid independent log data")
    panel = true; rendered = nil; addon.UI:Refresh()
    assert(rendered == 99, "raw matching ID must not revive the closed dialogue portrait")
    event("QUEST_DETAIL"); assert(rendered == 42)
    local before = reads; addon.UI:InspectQuest(166)
    assert(reads == before and rendered == 99, "another inspected card must not read current dialogue portrait")
    event("QUEST_FINISHED")
    for _, key in ipairs(keys) do _G[key] = saved[key] end
    addon.QuestPortrait, addon.UI.quest, addon.UI.detailHistory = logPortrait, previousQuest, {}
    addon.UI:Refresh()
end)
check("Client hydration and quest events preserve scroll until the inspected quest changes", function()
    local ui, previous, history = addon.UI, addon.UI.quest, addon.UI.detailHistory
    ui.detailHistory = {}
    ui.quest = 166; ui:Refresh()
    local scroll = ui.detailScroll
    scroll:SetVerticalScroll(240)
    local writes = scroll.scrollWrites
    for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_DATA_LOAD_RESULT", "ITEM_DATA_LOAD_RESULT", "QUEST_ITEM_UPDATE" }) do
        eventFrame.scripts.OnEvent(eventFrame, event, 166, true)
        assert(ui.quest == 166 and scroll.verticalScroll == 240 and scroll.scrollWrites == writes, event)
    end
    ui:InspectQuest(65)
    assert(scroll.verticalScroll == 0)
    scroll:SetVerticalScroll(120)
    ui.back.scripts.OnClick()
    assert(ui.quest == 166 and scroll.verticalScroll == 0)
    ui.quest, ui.detailHistory = previous, history
    ui:Refresh()
end)
check("Gossip refresh localizes only the actual matching NPC and closing restores catalogue fallback", function()
    local saved, keys = {}, { "UnitGUID", "UnitName", "C_CreatureInfo" }
    for _, key in ipairs(keys) do saved[key] = _G[key] end
    local ui, previousQuest, previousDungeon, preparation = addon.UI, addon.UI.quest, addon.UI.dungeon, addon.UI.preparation
    local q, originalName = addon.quests[65], addon.quests[65].start.name
    local guid, id, name = nil, 234, "Nom localisé du PNJ (fixture)"
    UnitGUID = function(unit) if unit == "npc" then return guid end; return "Player-npc-name-integration" end
    C_CreatureInfo = { GetCreatureID = function(value) assert(value == guid and value ~= nil); return id end }
    UnitName = function(unit) assert(unit == "npc"); return name end
    local function shown(value)
        for _, fs in ipairs(ui.details) do
            if fs.shown and type(fs.text) == "string" and fs.text:find(value, 1, true) then return true end
        end
        return false
    end
    local function event(value) eventFrame.scripts.OnEvent(eventFrame, value) end
    for _, dungeon in ipairs(addon.dungeons) do if dungeon.key == "dm" then ui.dungeon = dungeon end end
    ui.quest, ui.preparation = 65, true; ui:Refresh()
    assert(shown(addon.L("START") .. ": " .. originalName) and not shown(name))
    local state, nativeNameInAction = ui.engine:State(65).status, false
    guid = "Creature-npc-name-integration"; event("GOSSIP_SHOW")
    assert(shown(name) and not shown(addon.L("START") .. ": " .. originalName))
    assert(state == "UNKNOWN" and not ui.action)
    -- A separate pickup-model scope verifies localized preparation rows without
    -- converting the real NPC's partial acceptance record into an available quest.
    withKnownDefias(function()
        ui:Refresh()
        for _, row in ipairs(ui.rows) do
            if row.shown and row.note.text:find(name, 1, true) then nativeNameInAction = true end
        end
        assert(nativeNameInAction and ui.engine:State(65).status == "AVAILABLE")
    end)
    assert(ui.engine:State(65).status == state and not ui.action)
    id = 266; name = "Other matching finish NPC (fixture)"; event("QUEST_GREETING")
    assert(shown(addon.L("START") .. ": " .. originalName) and shown(name))
    guid = nil; event("GOSSIP_CLOSED")
    assert(shown(addon.L("START") .. ": " .. originalName) and not shown(name))
    assert(q.start.name == originalName and addon.db.npcNames == nil and addon.char.npcNames == nil)
    for _, key in ipairs(keys) do _G[key] = saved[key] end
    ui.quest, ui.dungeon, ui.preparation = previousQuest, previousDungeon, preparation
    ui:Refresh()
end)
check("Reported giver clicks route the chosen sourced point through native navigation without altering the primary", function()
    local ui, previous, history = addon.UI, addon.UI.quest, addon.UI.detailHistory
    local get, clear, oldTomTom = C_Map.GetUserWaypoint, C_Map.ClearUserWaypoint, TomTom
    addon.Navigation.Stop(); TomTom = nil
    local pin, clears = nil, 0
    C_Map.GetUserWaypoint = function() return pin end
    C_Map.ClearUserWaypoint = function() clears = clears + 1; pin = nil end
    local set = C_Map.SetUserWaypoint
    C_Map.SetUserWaypoint = function(p)
        pin = { uiMapID = p.mapID, position = { x = p.x, y = p.y } }
        waypoints[#waypoints + 1] = p; return true
    end
    local q = addon.quests[8927]
    assert(q.start.npcID == 16012 and #q.start.reportedLocations == 4)
    local before, maps, primaryX = #waypoints, mapCalls, q.start.x
    ui:InspectQuest(q.id)
    local toggle
    for _, row in ipairs(ui.reportedToggles) do if row.shown and row.locationKey == "start" then toggle = row end end
    assert(toggle and #waypoints == before)
    toggle.scripts.OnClick()
    local row = ui.reportedRows[2]
    local point, stale = q.start.reportedLocations[2], row.scripts.OnClick
    assert(row.shown and row.destination ~= point)
    row.scripts.OnClick()
    assert(#waypoints == before + 1 and mapCalls == maps + 1)
    local actual = waypoints[#waypoints]
    assert(actual.mapID == point.mapID and actual.x == point.x / 100 and actual.y == point.y / 100)
    assert(q.start.x == primaryX and ui.giverAction.place == q.start)
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
    stale(); assert(#waypoints == before + 1, "old refresh callback cannot restart navigation")
    addon.Navigation.Stop(); assert(clears == 1 and pin == nil)
    pin = { uiMapID = 1454, position = { x = 0.8, y = 0.9 } }
    local manual = pin
    ui.reportedRows[3].scripts.OnClick()
    assert(pin == manual and #waypoints == before + 1, "manual native pin survives candidate visit")
    addon.Navigation.Stop(); assert(pin == manual and clears == 1)
    C_Map.GetUserWaypoint, C_Map.ClearUserWaypoint, C_Map.SetUserWaypoint, TomTom = get, clear, set, oldTomTom
    ui.quest, ui.detailHistory = previous, history; ui:Refresh()
end)
check("The sourced journal container guides independently of the item-started quest and its readiness", function()
    local ui, previous, history = addon.UI, addon.UI.quest, addon.UI.detailHistory
    local q = addon.quests[1100]
    assert(q.start.itemID == 5791 and not q.start.objectID and q.requirementsKnown == false)
    assert(addon.quests[3374].start.itemID == 10589)
    local container, before = q.start.containerSource, #waypoints
    ui:InspectQuest(1100)
    assert(container.objectID == 19861 and container.mapID == 1441)
    assert(ui.containerButtons[1].shown and ui.containerButtons[1].enabled)
    assert(ui.giverAction == nil and #waypoints == before)
    local status = ui.engine:State(1100).status
    ui.containerButtons[1].scripts.OnClick()
    assert(#waypoints == before + 1)
    local actual = waypoints[#waypoints]
    assert(actual.mapID == 1441 and actual.x == 0.307 and actual.y == 0.244)
    assert(q.start.itemID == 5791 and q.start.mapID == nil and ui.engine:State(1100).status == status)
    addon.Navigation.Stop()
    ui.quest, ui.detailHistory = previous, history; ui:Refresh()
end)
check("Hidden Enemies starter visits Neeru while preserving the separate Thrall turn-in", function()
    local ui, previous, history = addon.UI, addon.UI.quest, addon.UI.detailHistory
    local q, before = addon.quests[5730], #waypoints
    assert(q.start.npcID == 3216 and q.finish.npcID == 4949 and q.requirementsKnown == false)
    assert(addon.quests[5761].start.npcID == 3216 and #q.start.reportedLocations == 6)
    ui:InspectQuest(5730)
    assert(ui.engine:State(5730).status == "UNAVAILABLE" and not ui.action and #waypoints == before)
    assert(ui.giverAction.place == q.start and ui.giver.enabled)
    ui.giver.scripts.OnClick()
    local actual = waypoints[#waypoints]
    assert(#waypoints == before + 1 and actual.mapID == 1454)
    assert(actual.x == 0.494 and actual.y == 0.504)
    assert(q.finish.npcID == 4949 and ui.engine:State(5730).status == "UNAVAILABLE")
    addon.Navigation.Stop()
    ui.quest, ui.detailHistory = previous, history; ui:Refresh()
end)
check("Actual partial Defias chain keeps held prerequisite work without claiming the final pickup", function()
    local ui, previous, history = addon.UI, addon.UI.quest, addon.UI.detailHistory
    local active, ready = C_QuestLog.IsOnQuest, C_QuestLog.ReadyForTurnIn
    C_QuestLog.IsOnQuest = function(id) return id == 65 end
    local canTurnIn = false
    C_QuestLog.ReadyForTurnIn = function(id) return id == 65 and canTurnIn end
    ui:InspectQuest(166); ui:Refresh()
    local actions, unknown = ui.engine:Next(166)
    assert(ui.engine:State(166).status == "UNKNOWN" and unknown and #actions == 1)
    assert(ui.action.id == 65 and ui.action.kind == "complete" and ui.action.place == nil and not ui.guide.enabled)
    canTurnIn = true; eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
    assert(ui.action.id == 65 and ui.action.kind == "turnin" and ui.guide.enabled)
    assert(ui.engine:State(166).status == "UNKNOWN" and addon.quests[166].requirementsKnown == false)
    local before, place = #waypoints, addon.quests[65].finish
    ui.guide.scripts.OnClick()
    local actual = waypoints[#waypoints]
    assert(#waypoints == before + 1 and actual.mapID == place.mapID)
    assert(actual.x == place.x / 100 and actual.y == place.y / 100)
    addon.Navigation.Stop()
    C_QuestLog.IsOnQuest, C_QuestLog.ReadyForTurnIn = active, ready
    ui.quest, ui.detailHistory = previous, history; ui:Refresh()
end)
check("Deadmines includes the VanCleef letter even though its quest leads outside the dungeon", function()
    local ui, previous, dungeon, preparation = addon.UI, addon.UI.quest, addon.UI.dungeon, addon.UI.preparation
    for _, entry in ipairs(addon.dungeons) do if entry.key == "dm" then ui.dungeon = entry end end
    ui.preparation = false; ui:Refresh()
    local letter
    for _, row in ipairs(ui.rows) do
        if row.shown and row.title.text == addon.QuestName(373) then letter = row end
    end
    assert(letter and letter.enabled)
    local before = #waypoints
    letter.scripts.OnClick()
    assert(ui.quest == 373 and addon.quests[373].start.itemID == 2874)
    assert(addon.quests[373].start.dungeonKey == "dm" and addon.quests[373].start.dropNPCID == 639)
    assert(ui.engine:State(373).status == "UNKNOWN" and not ui.action and #waypoints == before)
    assert(addon.quests[373].startsInside == nil, "item drop does not prove where the item must be used")
    ui.quest, ui.dungeon, ui.preparation = previous, dungeon, preparation; ui:Refresh()
end)
check("An unaccepted quest can preview only its explicitly loaded client rewards without gaining availability", function()
    local keys = { "HaveQuestRewardData", "GetNumQuestLogRewards", "GetNumQuestLogChoices", "GetQuestLogRewardInfo",
        "GetQuestLogChoiceInfo", "GetQuestLogRewardMoney", "GetQuestLogRewardXP" }
    local saved = {}; for _, key in ipairs(keys) do saved[key] = _G[key] end
    local ui, previous, history = addon.UI, addon.UI.quest, addon.UI.detailHistory
    local loaded = true
    HaveQuestRewardData = function(id) return id == 373 and loaded end
    GetNumQuestLogRewards = function(id) assert(id == 373); return 1 end
    GetNumQuestLogChoices = function(id) assert(id == 373); return 0 end
    GetQuestLogRewardInfo = function(index, id) assert(index == 1 and id == 373); return "Loaded letter reward", 123, 2, 1, true, 7001 end
    GetQuestLogRewardMoney = function(id) assert(id == 373); return 0 end
    GetQuestLogRewardXP = function(id) assert(id == 373); return 90 end
    local function shown(text)
        for _, fs in ipairs(ui.details) do if fs.shown and fs.text == text then return true end end
        return false
    end
    local before = #waypoints
    ui:InspectQuest(373); ui:Refresh()
    assert(shown(addon.L("REWARD_PREVIEW")) and shown(addon.L("REWARD_ITEM", "Loaded letter reward", 2)))
    assert(shown(addon.L("REWARD_XP", 90)) and ui.engine:State(373).status == "UNKNOWN")
    assert(not ui.action and #waypoints == before and addon.quests[373].requirementsKnown == false)
    loaded = false; eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
    assert(not shown(addon.L("REWARD_PREVIEW")) and shown(addon.L("REWARD_UNAVAILABLE")))
    assert(not shown(addon.L("REWARD_ITEM", "Loaded letter reward", 2)))
    for _, key in ipairs(keys) do _G[key] = saved[key] end
    ui.quest, ui.detailHistory = previous, history; ui:Refresh()
end)
check("Shared Blackrock map names retain separate wing cards search and selection", function()
    local ui = addon.UI
    local native, locale, search, range = GetRealZoneText, addon.db.locale, ui.search, ui.range
    local dungeon, quest, history, selected = ui.dungeon, ui.quest, ui.detailHistory, addon.char.selectedDungeon
    GetRealZoneText = function(id) if id == 229 then return "Native Spire" end end
    addon.db.locale, ui.search, ui.range = "enUS", "", false
    ui:RefreshDungeons()
    local lower, upper
    for _, card in ipairs(ui.cards) do
        if card.shown and card.title.text == addon.L("DUNGEON_WING_lower", "Native Spire") then lower = card end
        if card.shown and card.title.text == addon.L("DUNGEON_WING_upper", "Native Spire") then upper = card end
    end
    assert(lower and upper and lower ~= upper and lower.title.text ~= upper.title.text)
    lower.scripts.OnClick(); assert(ui.dungeon.key == "lbrs" and ui.dungeon.wing == "lower")
    upper.scripts.OnClick(); assert(ui.dungeon.key == "ubrs" and ui.dungeon.wing == "upper")
    ui.search = "upper wing"; ui:RefreshDungeons()
    local count = 0
    for _, card in ipairs(ui.cards) do if card.shown then count = count + 1; assert(card.title.text == addon.L("DUNGEON_WING_upper", "Native Spire")) end end
    assert(count == 1)
    GetRealZoneText, addon.db.locale, ui.search, ui.range = native, locale, search, range
    ui.dungeon, ui.quest, ui.detailHistory, addon.char.selectedDungeon = dungeon, quest, history, selected
    ui:Refresh()
end)
print("Client/UI modeled checks passed: " .. total .. " (no pixel or native-client validation)")
