local objects, requests, mapCalls, waypoints, total = {}, 0, 0, {}, 0
local methods = {}
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
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
for line in io.lines("DungeonPrep.toc") do
    if line:match("%.lua$") then assert(loadfile((line:gsub("\\", "/"))))("DungeonPrep", addon) end
end
local function check(name, fn)
    local ok, err = pcall(fn); assert(ok, name .. ": " .. tostring(err)); total = total + 1; print("PASS " .. name)
end
local eventFrame = objects[#objects]
check("Addon initializes on the matching Forever client", function()
    eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "DungeonPrep")
    assert(SlashCmdList.DUNGEONPREP and addon.db and addon.char)
end)
check("Window opens and filters without requiring cached quest titles", function()
    SlashCmdList.DUNGEONPREP("")
    assert(addon.UI.frame:IsShown()); assert(#addon.UI.cards == 29)
    for _, d in ipairs(addon.dungeons) do if d.key == "dm" then addon.UI.dungeon = d end end
    addon.UI:Refresh(); assert(#addon.UI.rows == 6)
end)
check("Quest detail guides to the initial Defias step", function()
    addon.UI.quest = 166; addon.UI:RefreshDetail()
    assert(addon.UI.action.id == 65 and addon.UI.guide.enabled)
    assert(#addon.UI.chainButtons == 7)
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
check("Native map and waypoint use the resolved ancestor coordinates", function()
    addon.UI.quest = 166; addon.UI:RefreshDetail()
    addon.UI.guide.scripts.OnClick()
    assert(#waypoints == 1 and waypoints[1].mapID == 1436)
    assert(math.abs(waypoints[1].x - 0.563) < 0.0001 and mapCalls == 1)
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
    SlashCmdList.DUNGEONPREP("probe")
    assert(addon.char.probe.interface == 16001 and next(addon.char.probe.questLines) == nil)
    assert(addon.char.probe.api.lines == false and addon.char.probe.api.logText == false)
end)
check("Close and reopen preserve selection", function()
    SlashCmdList.DUNGEONPREP(""); assert(not addon.UI.frame:IsShown())
    SlashCmdList.DUNGEONPREP(""); assert(addon.UI.frame:IsShown() and addon.UI.quest == 166)
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
print("Client/UI modeled checks passed: " .. total .. " (no pixel or native-client validation)")
