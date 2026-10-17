local objects, requests, mapCalls, waypoints, total = {}, 0, 0, {}, 0
local methods = {}
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:SetParent(parent) self.parent = parent end
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
function methods:SetTexture(value) self.texture = value; return true end
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
    "EnableMouse", "SetMovable", "RegisterForDrag", "RegisterForClicks", "StartMoving", "StopMovingOrSizing", "SetBackdrop",
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
-- The existing data integration cases intentionally inspect the expanded reference view.
local expandedReferenceFixture, expandingReference = true, false
local detailRefresh = addon.UI.RefreshDetail
addon.UI.RefreshDetail = function(self, ...)
    local requested = self.quest
    local result = detailRefresh(self, ...)
    local toggle = self.referenceToggle
    if expandedReferenceFixture and not expandingReference and self.quest == requested and self.frame and self.frame:IsShown() and
        toggle and toggle:IsShown() and self.detailReferencesExpanded ~= true then
        expandingReference = true
        local ok, message = pcall(toggle.scripts.OnClick)
        expandingReference = false
        assert(ok, message)
    end
    return result
end
local function expandKnownChain()
    local ui = addon.UI
    if ui.storyToggle and ui.storyToggle:IsShown() and ui.detailChainExpanded ~= true then ui.storyToggle.scripts.OnClick() end
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
    expandKnownChain()
    assert(addon.quests[166].requirementsKnown == false)
    assert(addon.UI.engine:State(166).status == "UNKNOWN" and not addon.UI.action and not addon.UI.guide.enabled)
    assert(#addon.UI.chainButtons == 7, "uncertain acceptance still retains source narrative")
    C_QuestLog.IsQuestFlaggedCompleted = completed; addon.UI:Refresh()
end)
check("Default compact quest card retains the real next step and explicit giver action", function()
    local ui = addon.UI
    expandedReferenceFixture = false
    ui:InspectQuest(373); ui:InspectQuest(166)
    assert(ui.detailReferencesExpanded == false and ui.detailChainExpanded == false)
    assert(ui.referenceToggle:IsShown() and ui.giver.enabled and ui.giverAction.place == addon.quests[166].start)
    assert(ui.engine:State(166).status == "UNKNOWN" and not ui.action)
    withKnownDefias(function()
        ui:Refresh()
        assert(ui.detailReferencesExpanded == false and ui.detailChainExpanded == false)
        assert(ui.action.id == 65 and ui.guide.enabled and ui.giver.enabled)
        assert(ui.giverAction.place == addon.quests[166].start and ui.quest == 166)
    end)
    expandedReferenceFixture = true; ui:Refresh()
end)
check("Known graph fixture guides to the initial Defias step", function()
    withKnownDefias(function()
        addon.UI.quest = 166; addon.UI:Refresh()
        expandKnownChain()
        assert(addon.UI.action.id == 65 and addon.UI.guide.enabled)
        assert(#addon.UI.chainButtons == 7)
    end)
    assert(addon.UI.engine:State(166).status == "UNKNOWN" and not addon.UI.action)
end)
check("Storyline renders separately without inventing dependency readiness", function()
    addon.UI.quest = 92753; addon.UI:RefreshDetail()
    assert(not addon.UI.action and not addon.UI.guide.enabled)
    local ui = addon.UI
    assert(ui.storyToggle and ui.storyToggle:IsShown())
    assert(ui.storyToggle.label.text == "+ " .. addon.L("STORY_SOURCE_QUESTS", 11))
    local compact, current = 0, false
    for _, row in ipairs(ui.chainButtons) do if row:IsShown() then compact=compact+1;current=current or row.label.text:find("(#92753)",1,true)~=nil end end
    assert(compact<=2 and current, "collapsed narrative keeps only the current quest and nearest known prior")
    ui.storyToggle.scripts.OnClick()
    local visible = 0
    for _, row in ipairs(ui.chainButtons) do if row:IsShown() then visible = visible + 1 end end
    assert(visible == 11 and not ui.action and not ui.guide.enabled)
end)
check("Quest title hydration is requested only once per ID", function()
    local before = requests
    for i = 1, 5 do addon.UI:Refresh() end
    assert(requests == before)
end)
check("Native map and waypoint use the resolved ancestor from the known graph fixture", function()
    withKnownDefias(function()
        addon.UI.quest = 166; addon.UI:Refresh()
        local quest, dungeon = addon.UI.quest, addon.UI.dungeon
        addon.UI.guide.scripts.OnClick()
        assert(#waypoints == 1 and waypoints[1].mapID == 1436)
        assert(math.abs(waypoints[1].x - 0.563) < 0.0001 and mapCalls == 1)
        assert(addon.UI.frame:IsShown() and addon.UI.quest == quest and addon.UI.dungeon == dungeon,
            "accepted guidance must keep the inspected planner open")
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
check("Navigation probe has a distinct normalized command without toggling or saving quest data", function()
    local getter, originalPrint, toggle, clientProbe = addon.Navigation.ProbeGeometry, print, addon.UI.Toggle, addon.ProbeClient
    local output, calls, toggles, questReads = {}, 0, 0, 0
    local saved, frames, beforeMaps, beforeRequests = addon.char.probe, #objects, mapCalls, requests
    addon.Navigation.ProbeGeometry = function()
        calls = calls + 1
        return { status = "known", frames = {
            hud = { status = "known", shown = true, visible = false, strata = "MEDIUM", level = 4,
                scale = 0.75, left = -2.5, bottom = 9, width = 354, height = 104, questText = "DO_NOT_PRINT" },
            planner = { status = "unknown" }, worldMap = { status = "known" },
            player = { name = "DO_NOT_PRINT" } } }
    end
    print = function(line) output[#output + 1] = line end
    addon.UI.Toggle = function() toggles = toggles + 1 end
    addon.ProbeClient = function() questReads = questReads + 1 end
    SlashCmdList.DUNGEONPRO("  PrObE\t NAV  ")
    addon.Navigation.ProbeGeometry, print, addon.UI.Toggle, addon.ProbeClient = getter, originalPrint, toggle, clientProbe
    assert(calls == 1 and toggles == 0 and questReads == 0 and addon.char.probe == saved)
    assert(#objects == frames and mapCalls == beforeMaps and requests == beforeRequests)
    assert(#output == 3 and output[1]:find("hud", 1, true) and output[2]:find("planner", 1, true) and output[3]:find("worldMap", 1, true))
    assert(output[1]:find("shown=true", 1, true) and output[1]:find("visible=false", 1, true))
    assert(output[1]:find("MEDIUM", 1, true) and output[1]:find("uiUnit", 1, true))
    for _, line in ipairs(output) do assert(#line <= 240 and not line:find("DO_NOT_PRINT", 1, true)) end
end)
check("Navigation probe formatting rejects restricted malformed and extreme values", function()
    local getter, originalPrint, checker = addon.Navigation.ProbeGeometry, print, issecretvalue
    local restricted, output = {}, {}
    issecretvalue = function(value) return rawequal(value, restricted) end
    addon.Navigation.ProbeGeometry = function()
        return { status = "known", frames = { hud = { status = "known", shown = restricted, visible = false,
            strata = "DO_NOT_PRINT", level = 0 / 0, scale = -1, left = math.huge, bottom = 1e300, width = -1, height = restricted } } }
    end
    print = function(line) output[#output + 1] = line end
    SlashCmdList.DUNGEONPRO("probe nav")
    addon.Navigation.ProbeGeometry, print, issecretvalue = getter, originalPrint, checker
    assert(#output == 3 and output[1]:find("shown=unknown", 1, true) and output[1]:find("visible=false", 1, true))
    for _, line in ipairs(output) do
        assert(#line <= 240 and not line:find("DO_NOT_PRINT", 1, true) and not line:find("nan", 1, true) and not line:find("inf", 1, true))
    end
end)
check("Unavailable or failing navigation probes print unknown without opening the browser", function()
    local getter, originalPrint, toggle = addon.Navigation.ProbeGeometry, print, addon.UI.Toggle
    local output, toggles, saved = {}, 0, addon.char.probe
    print = function(line) output[#output + 1] = line end
    addon.UI.Toggle = function() toggles = toggles + 1 end
    addon.Navigation.ProbeGeometry = nil
    SlashCmdList.DUNGEONPRO("probe nav")
    addon.Navigation.ProbeGeometry = function() error("unavailable") end
    SlashCmdList.DUNGEONPRO("probe nav")
    addon.Navigation.ProbeGeometry, print, addon.UI.Toggle = getter, originalPrint, toggle
    assert(toggles == 0 and addon.char.probe == saved and #output == 2)
    for _, line in ipairs(output) do assert(line:find("unknown", 1, true)) end
end)
check("Close and reopen preserve selection", function()
    SlashCmdList.DUNGEONPRO(""); assert(not addon.UI.frame:IsShown())
    SlashCmdList.DUNGEONPRO(""); assert(addon.UI.frame:IsShown() and addon.UI.quest == 166)
end)
check("Quest-data events pass success to bounded delayed title recovery", function()
    expandKnownChain()
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
    assert(ui.frame:IsShown() and ui.quest == 166 and mapCalls == before + 1, "accepted alternative map requests leave preparation open")
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
    assert(ui.frame:IsShown() and ui.quest == 166 and mapCalls == beforeMaps + 1, "map-only turn-in visits leave preparation open")
    ui.finishButtons[2].scripts.OnClick()
    assert(#waypoints == beforePins + 1 and waypoints[#waypoints].mapID == 1)
    assert(waypoints[#waypoints].x == 0.1 and waypoints[#waypoints].y == 0.2)
    assert(ui.action == action and ui.engine:State(166).status == status)
    assert(ui.frame:IsShown() and ui.quest == 166 and #waypoints == beforePins + 1, "located turn-in visits leave preparation open")
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
    eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
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
    assert(ui.frame:IsShown() and ui.quest == q.id and #waypoints == before + 1, "reported visits leave preparation open")
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
    stale(); assert(#waypoints == before + 1, "old refresh callback cannot restart navigation")
    addon.Navigation.Stop(); assert(clears == 1 and pin == nil)
    pin = { uiMapID = 1454, position = { x = 0.8, y = 0.9 } }
    local manual = pin
    ui.reportedRows[3].scripts.OnClick()
    assert(pin == manual and #waypoints == before + 1, "manual native pin survives candidate visit")
    assert(ui.frame:IsShown() and ui.quest == q.id and pin == manual and #waypoints == before + 1, "manual pins and preparation both remain unchanged")
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
    assert(ui.frame:IsShown() and ui.quest == 1100 and #waypoints == before + 1, "container visits leave preparation open")
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
    assert(ui.frame:IsShown() and ui.quest == 5730 and #waypoints == before + 1, "giver visits leave preparation open")
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
    assert(ui.frame:IsShown() and ui.quest == 166 and #waypoints == before + 1, "prerequisite guidance leaves preparation open")
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
check("Inventory updates refresh actual starter counts and hidden reopen reads current possession", function()
    local ui, previous, history = addon.UI, addon.UI.quest, addon.UI.detailHistory
    local item = C_Item
    local count, reads = 0, 0
    C_Item = { GetItemCount = function(id, bank, uses, reagent, account)
        assert(id == 2874 and bank == false and uses == false and reagent == false and account == false)
        reads = reads + 1; return count
    end }
    local function shown(value)
        for _, line in ipairs(ui.details) do if line.shown and line.text == addon.L("ITEM_CARRIED", value) then return true end end
        return false
    end
    assert(eventFrame.events.BAG_UPDATE_DELAYED)
    ui:InspectQuest(373); ui:Refresh()
    assert(shown(0) and ui.engine:State(373).status == "UNKNOWN" and not ui.action)
    local before, pins = reads, #waypoints
    count = 2; eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
    assert(reads > before and shown(2) and not shown(0) and #waypoints == pins)
    assert(ui.engine:State(373).status == "UNKNOWN" and not ui.action)
    ui.frame:Hide(); count = 4
    eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
    ui:Toggle()
    assert(ui.frame:IsShown() and shown(4) and not shown(2))
    count = nil; eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
    assert(not shown(4) and not ui.action and #waypoints == pins)
    C_Item = item; ui.quest, ui.detailHistory = previous, history; ui:Refresh()
end)
check("Quest-log capacity refreshes from real client adapters without counting headers or granting readiness", function()
    local ui = addon.UI
    local entries, maximum = C_QuestLog.GetNumQuestLogEntries, C_QuestLog.GetMaxNumQuestsCanAccept
    local count, capacity = 0, 40
    C_QuestLog.GetNumQuestLogEntries = function() return 100, count end
    C_QuestLog.GetMaxNumQuestsCanAccept = function() return capacity end
    ui:Refresh()
    assert(ui.capacityStatus.shown and ui.capacityStatus.text == addon.L("QUEST_LOG_CAPACITY", 0, 40))
    local pins, actions = #waypoints, ui.action
    count = 7; eventFrame.scripts.OnEvent(eventFrame, "QUEST_ACCEPTED", 999999)
    assert(ui.capacityStatus.text == addon.L("QUEST_LOG_CAPACITY", 7, 40) and #waypoints == pins)
    assert(ui.action == actions or not ui.action)
    ui.frame:Hide(); count, capacity = 9, 50; ui:Toggle()
    assert(ui.capacityStatus.text == addon.L("QUEST_LOG_CAPACITY", 9, 50))
    C_QuestLog.GetMaxNumQuestsCanAccept = function() error("temporarily unavailable") end
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
    assert(not ui.capacityStatus.shown and ui.capacityStatus.text == "")
    C_QuestLog.GetNumQuestLogEntries, C_QuestLog.GetMaxNumQuestsCanAccept = entries, maximum
    ui:Refresh()
end)
check("Actual cached rewards expose native item icons and current-source-only hover tooltips", function()
    local keys = { "HaveQuestRewardData", "GetNumQuestLogRewards", "GetNumQuestLogChoices", "GetQuestLogRewardInfo",
        "GetQuestLogChoiceInfo", "GetQuestLogRewardMoney", "GetQuestLogRewardXP", "GameTooltip" }
    local saved = {}; for _, key in ipairs(keys) do saved[key] = _G[key] end
    local ui, previous, history = addon.UI, addon.UI.quest, addon.UI.detailHistory
    local loaded, reads, hides = true, 0, 0
    HaveQuestRewardData = function(id) return id == 373 and loaded end
    GetNumQuestLogRewards = function(id) assert(id == 373); return 1 end
    GetNumQuestLogChoices = function(id) assert(id == 373); return 0 end
    GetQuestLogRewardInfo = function(index, id)
        assert(index == 1 and id == 373); return "Cached native item", 123, 2, 1, true, 7001
    end
    GameTooltip = {
        SetOwner = function(self, owner, anchor) assert(anchor == "ANCHOR_RIGHT"); self.owner = owner end,
        IsOwned = function(self, owner) return self.owner == owner end,
        SetItemByID = function(self, id) assert(id == 7001); reads = reads + 1; self.item = id; return true end,
        Hide = function(self) hides = hides + 1; self.owner = nil end,
        Show = function() error("Native item accessor owns tooltip visibility") end,
    }
    ui:InspectQuest(373); ui:Refresh()
    local button = assert(ui.rewardButtons[1])
    assert(button.shown and button.icon.texture == 123 and button.rewardBinding.id == 7001)
    assert(ui.engine:State(373).status == "UNKNOWN" and not ui.action)
    button.scripts.OnEnter(); assert(reads == 1 and GameTooltip.owner == button)
    button.scripts.OnLeave(); assert(hides == 1)
    loaded = false; button.scripts.OnEnter()
    assert(reads == 1, "A stale row must not open a tooltip after its native source becomes cold")
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
    assert(not button.shown and not button.scripts.OnEnter and button.icon.texture == nil)
    assert(ui.engine:State(373).status == "UNKNOWN" and not ui.action)
    for _, key in ipairs(keys) do _G[key] = saved[key] end
    ui.quest, ui.detailHistory = previous, history; ui:Refresh()
end)
check("All-character inspection explains actual paladin race and level limits without authorizing pickup", function()
    local ui = addon.UI
    local previous, history, all = ui.quest, ui.detailHistory, ui.includeUnavailable
    local classes, creatures = LOCALIZED_CLASS_NAMES_MALE, C_CreatureInfo
    LOCALIZED_CLASS_NAMES_MALE = { PALADIN = "Native Paladin" }
    C_CreatureInfo = { GetRaceInfo = function(id)
        return { raceID = id, raceName = id == 1 and "Native Human" or "Native Dwarf" }
    end }
    local function shown(value)
        for _, line in ipairs(ui.details) do
            if line.shown then
                local text = line.text:gsub("|A:[^|]+|a ", "")
                if text:find(value, 1, true) then return true end
            end
        end
        return false
    end
    local pins = #waypoints
    ui.includeUnavailable = true; ui:InspectQuest(7647); ui:Refresh()
    assert(shown(addon.L("QUEST_LEVEL", 60) .. " · " .. addon.L("QUEST_MIN_LEVEL", 60)))
    assert(shown(addon.L("QUEST_CLASSES", "Native Paladin")))
    assert(shown(addon.L("QUEST_RACES", "Native Human, Native Dwarf")))
    assert(ui.engine:State(7647).status == "UNAVAILABLE" and not ui.action and #waypoints == pins)
    LOCALIZED_CLASS_NAMES_MALE, C_CreatureInfo = classes, creatures
    ui.quest, ui.detailHistory, ui.includeUnavailable = previous, history, all; ui:Refresh()
    assert(not shown(addon.L("QUEST_CLASSES", "Native Paladin")))
end)
check("The rl alias invokes native reload only on command and preserves other addon handlers", function()
    local saved, calls, others = ReloadUI, 0, 0
    assert(SLASH_DUNGEONPRORELOAD1 == "/rl" and type(SlashCmdList.DUNGEONPRORELOAD) == "function")
    local other = function() others = others + 1 end
    SlashCmdList.OTHERRELOAD = other
    ReloadUI = function(...) assert(select("#", ...) == 0); calls = calls + 1 end
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
    assert(calls == 0)
    local shown = addon.UI.frame:IsShown()
    SlashCmdList.DUNGEONPRORELOAD("ignored like reload")
    assert(calls == 1 and addon.UI.frame:IsShown() == shown and others == 0)
    assert(SlashCmdList.OTHERRELOAD == other)
    ReloadUI = function() calls = calls + 10 end
    SlashCmdList.DUNGEONPRORELOAD(""); assert(calls == 11)
    ReloadUI = nil; SlashCmdList.DUNGEONPRORELOAD(""); assert(calls == 11)
    SlashCmdList.OTHERRELOAD = nil; ReloadUI = saved
end)
check("Sourced objective quantities and current carried counts remain separate from quest readiness", function()
    local ui, previous, history = addon.UI, addon.UI.quest, addon.UI.detailHistory
    local item, count = C_Item, 0
    C_Item = {
        GetItemNameByID = function(id) if id == 6443 then return "Native Deviate Hide" end end,
        GetItemCount = function(id, bank, uses, reagent, account)
            assert(id == 6443 and bank == false and uses == false and reagent == false and account == false)
            return count
        end,
    }
    local function shown(value)
        for _, line in ipairs(ui.details) do if line.shown and line.text == value then return true end end
        return false
    end
    local pins = #waypoints
    ui:InspectQuest(1486); ui:Refresh()
    assert(shown(addon.L("OBJECTIVE_ITEMS")) and shown(addon.L("OBJECTIVE_ITEM", "Native Deviate Hide", 20)))
    assert(shown(addon.L("ITEM_CARRIED", 0)) and shown(addon.L("OBJECTIVE_ITEMS_NOTICE")))
    for _, value in ipairs({ 20, 25 }) do
        count = value; eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
        assert(shown(addon.L("ITEM_CARRIED", value)) and not shown(addon.L("ITEM_CARRIED", 0)))
        assert(ui.engine:State(1486).status == "UNKNOWN" and not ui.action and #waypoints == pins)
    end
    count = nil; eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
    assert(shown(addon.L("OBJECTIVE_ITEM", "Native Deviate Hide", 20)) and not shown(addon.L("ITEM_CARRIED", 25)))
    C_Item = item; ui.quest, ui.detailHistory = previous, history; ui:Refresh()
end)
check("Native minimap arrival initializes the launcher and commands persist only its own preferences", function()
    local native, cursor, prefs = Minimap, GetCursorPosition, addon.db.minimap
    Minimap = create("Frame"); Minimap:SetWidth(198)
    Minimap.GetEffectiveScale = function() return 1 end
    Minimap.GetCenter = function() return 500, 400 end
    GetCursorPosition = function() return 600, 400 end
    local saved, pins = copy(addon.char), #waypoints
    eventFrame.scripts.OnEvent(eventFrame, "PLAYER_ENTERING_WORLD")
    local button = assert(addon.Minimap.button)
    assert(button:IsShown() and button.point[2] == Minimap and addon.db.minimap)
    local shown = addon.UI.frame:IsShown()
    button.scripts.OnMouseDown(button, "LeftButton"); button.scripts.OnClick(button, "LeftButton")
    assert(addon.UI.frame:IsShown() ~= shown)
    button.scripts.OnMouseDown(button, "LeftButton"); button.scripts.OnDragStart(button, "LeftButton")
    assert(button.scripts.OnUpdate); button.scripts.OnUpdate(button)
    button.scripts.OnDragStop(button)
    assert(button.scripts.OnUpdate == nil and addon.db.minimap.angle == 0)
    local dragged = addon.UI.frame:IsShown()
    button.scripts.OnClick(button, "LeftButton"); assert(addon.UI.frame:IsShown() == dragged)
    button.scripts.OnMouseDown(button, "LeftButton"); button.scripts.OnClick(button, "LeftButton")
    assert(addon.UI.frame:IsShown() ~= dragged)
    SlashCmdList.DUNGEONPRO("  MiNiMaP  "); assert(not button:IsShown() and addon.db.minimap.hide == true)
    SlashCmdList.DUNGEONPRO("minimap"); assert(button:IsShown() and addon.db.minimap.hide == false)
    SlashCmdList.DUNGEONPRO(" MINIMAP\t RESET ")
    assert(button:IsShown() and addon.db.minimap.angle == 225 and addon.db.minimap.hide == false)
    assert(#waypoints == pins and addon.char.selectedDungeon == saved.selectedDungeon)
    Minimap, GetCursorPosition, addon.db.minimap = native, cursor, prefs
    assert(addon.Minimap:Initialize() == false and not button:IsShown())
    if addon.UI.frame:IsShown() ~= shown then addon.UI:Toggle() end
end)
check("An actual sourced objective with unknown quantity shows possession without inventing a goal or readiness", function()
    local ui, previous, history = addon.UI, addon.UI.quest, addon.UI.detailHistory
    local item, level, all = C_Item, UnitLevel, ui.includeUnavailable
    local count = 0
    UnitLevel = function() return 60 end
    C_Item = {
        GetItemNameByID = function(id) if id == 9316 then return "Native Prismatic Card" end end,
        GetItemCount = function(id, bank, uses, reagent, account)
            assert(id == 9316 and bank == false and uses == false and reagent == false and account == false)
            return count
        end,
    }
    local function shown(value)
        for _, line in ipairs(ui.details) do if line.shown and line.text == value then return true end end
        return false
    end
    local q, pins = addon.quests[2930], #waypoints
    assert(q.objectiveItems[1].itemID == 9316 and q.objectiveItems[1].quantity == nil)
    ui.includeUnavailable = true; ui:InspectQuest(2930); ui:Refresh()
    assert(shown(addon.L("OBJECTIVE_ITEM_UNKNOWN", "Native Prismatic Card")))
    assert(shown(addon.L("ITEM_CARRIED", 0)) and not shown(addon.L("OBJECTIVE_ITEM", "Native Prismatic Card", 1)))
    count = 3; eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
    assert(shown(addon.L("ITEM_CARRIED", 3)) and not shown(addon.L("ITEM_CARRIED", 0)))
    assert(shown(addon.L("OBJECTIVE_ITEM_UNKNOWN", "Native Prismatic Card")))
    assert(ui.engine:State(2930).status == "UNKNOWN" and not ui.action and #waypoints == pins)
    count = nil; eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
    assert(not shown(addon.L("ITEM_CARRIED", 3)) and shown(addon.L("OBJECTIVE_ITEM_UNKNOWN", "Native Prismatic Card")))
    C_Item, UnitLevel, ui.includeUnavailable = item, level, all
    ui.quest, ui.detailHistory = previous, history; ui:Refresh()
end)

local function actualKillReentryFixture()
    local ui=addon.UI
    issecretvalue=function()return false end;GetLocale=function()return"enUS"end
    UnitGUID=function(unit)if unit=="player"then return"Player-KillReentry"end end
    UnitLevel=function()return 60 end;UnitFactionGroup=function()return"Alliance"end
    UnitClass=function()return"Mage","MAGE",8 end;UnitRace=function()return"Dwarf","Dwarf",3 end
    C_QuestLog={IsQuestFlaggedCompleted=function()return false end,IsOnQuest=function()return false end,
        ReadyForTurnIn=function()return false end,GetTitleForQuestID=function(id)return addon.quests[id]and addon.quests[id].name end,GetQuestObjectives=function()return nil end}
    C_Item={GetItemCount=function()return 0 end,GetItemNameByID=function(id)assert(id==274289);return"Dwarven Heirloom"end,
        GetItemIconByID=function()return 134400 end,IsItemDataCachedByID=function()return true end}
    GetQuestID=function()return 0 end;GetQuestLogQuestText=nil;SetPortraitTextureFromCreatureDisplayID=nil
    addon.char.texts={};addon.DialogueRewardEvent("PLAYER_ENTERING_WORLD");addon.OfferEvent("PLAYER_ENTERING_WORLD")
    for _,d in ipairs(addon.dungeons)do if d.key=="thanes"then ui.dungeon=d end end
    ui.quest=96395;ui:Refresh()
    return ui,addon.L("OBJECTIVE_ITEM_UNKNOWN",addon.quests[96395].objectiveKills[1].name)
end
local function visibleDetail(ui,value)
    for _,fs in ipairs(ui.details)do if fs.shown and fs.text==value then return true end end
    return false
end
check("Actual Hall kill label setter before and after reentry preserves the newer quest card and item goal",function()
    for _,before in ipairs({true,false})do
        local ui,goal=actualKillReentryFixture();local original=methods.SetText;local armed=true;local currentEngine
        methods.SetText=function(self,value)
            if not before then original(self,value)end
            if armed and value==goal then armed=false;ui.quest=96403;ui:Refresh();currentEngine=ui.engine end
            if before then original(self,value)end
        end
        ui:RefreshDetail();methods.SetText=original
        assert(not armed and ui.quest==96403 and ui.engine==currentEngine)
        assert(not visibleDetail(ui,goal)and visibleDetail(ui,addon.QuestName(96403)))
        assert(visibleDetail(ui,addon.L("OBJECTIVE_ITEM","Dwarven Heirloom",8)))
        assert(ui.engine:State(96403).status=="UNKNOWN" and not ui.action and not ui.guide.enabled)
    end
end)
check("Actual kill-row localization cannot publish old headings or labels over a newer Hall card",function()
    for _,key in ipairs({"OBJECTIVE_KILLS","OBJECTIVE_KILLS_NOTICE","OBJECTIVE_ITEM_UNKNOWN"})do
        local ui,goal=actualKillReentryFixture();local original=addon.L;local armed=true
        addon.L=function(code,...)
            local text=original(code,...)
            if code==key and armed then armed=false;ui.quest=96403;ui:Refresh()end
            return text
        end
        ui:RefreshDetail();addon.L=original
        assert(not armed and ui.quest==96403 and not visibleDetail(ui,goal))
        assert(visibleDetail(ui,addon.L("OBJECTIVE_ITEM","Dwarven Heirloom",8)))
        assert(not visibleDetail(ui,addon.L("OBJECTIVE_KILLS")))
    end
end)
check("Same-card kill-source replacement during native text publication preserves the fresh generation and quantity",function()
    local ui,goal=actualKillReentryFixture();local source=addon.quests[96395].objectiveKills;local original=methods.SetText;local armed=true
    methods.SetText=function(self,value)
        if armed and value==goal then
            armed=false;addon.quests[96395].objectiveKills={{npcID=source[1].npcID,name="Fresh recorded kill target",quantity=3}};ui:RefreshDetail()
        end
        return original(self,value)
    end
    ui:RefreshDetail();methods.SetText=original
    assert(not armed and ui.quest==96395 and not visibleDetail(ui,goal))
    assert(visibleDetail(ui,addon.L("OBJECTIVE_ITEM","Fresh recorded kill target",3)))
    addon.quests[96395].objectiveKills=source;ui:RefreshDetail()
end)


check("Kill-row recovery revalidates raw newer-card ownership after its current-result secret checker reenters a third card",function()
    local ui,goal=actualKillReentryFixture();local setter=methods.SetText;local checker=issecretvalue
    local armed,third,recoveryValue,inThirdRender=true,false,nil,false
    issecretvalue=function(value)
        if value==true and not third then
            for _,field in ipairs(ui.details)do if field.detailTextRepair then third=true;ui.quest=96394;inThirdRender=true;ui:Refresh();inThirdRender=false;break end end
        end
        return false
    end
    methods.SetText=function(self,value)
        if armed and value==goal then armed=false;ui.quest=96403;ui:Refresh()end
        if self.detailTextRepair and third and not inThirdRender then recoveryValue=value end
        return setter(self,value)
    end
    ui:Refresh();methods.SetText=setter;issecretvalue=checker
    assert(not armed and third and ui.quest==96394)
    assert(recoveryValue==nil,"recovery cannot write after the predicate sanitizer replaces its newer card")
    assert(not visibleDetail(ui,goal)and not visibleDetail(ui,addon.L("OBJECTIVE_ITEMS_NOTICE")))
    assert(visibleDetail(ui,addon.QuestName(96394))and ui.engine:State(96394).status=="UNKNOWN")
end)


check("Actual native title hydration after a completed replacement-card render cannot overwrite its title",function()
    local ui=actualKillReentryFixture();local getter=C_QuestLog.GetTitleForQuestID;local armed=true
    C_QuestLog.GetTitleForQuestID=function(id)
        local name=getter(id)
        if armed and id==96395 then armed=false;ui.quest=96403;ui:Refresh()end
        return name
    end
    ui:RefreshDetail()
    assert(not armed and ui.quest==96403)
    assert(not visibleDetail(ui,addon.quests[96395].name)and visibleDetail(ui,addon.quests[96403].name))
    assert(visibleDetail(ui,addon.L("OBJECTIVE_ITEM","Dwarven Heirloom",8)))
end)
check("Same-card native title reentry preserves the newer generation's title and unchanged source fallback",function()
    local ui=actualKillReentryFixture();local armed=true;local fresh="Fresh native Hall title";local old="Old native Hall title"
    C_QuestLog.GetTitleForQuestID=function(id)
        if id~=96395 then return addon.quests[id]and addon.quests[id].name end
        if armed then armed=false;ui:RefreshDetail();return old end
        return fresh
    end
    ui:RefreshDetail()
    assert(not armed and ui.quest==96395 and visibleDetail(ui,fresh)and not visibleDetail(ui,old))
    C_QuestLog.GetTitleForQuestID=function()return nil end;ui:RefreshDetail()
    assert(visibleDetail(ui,addon.quests[96395].name)and not visibleDetail(ui,fresh))
end)
check("Owned native title SetText before and after replacement reentry preserves the new card and content",function()
    for _,before in ipairs({true,false})do
        local ui=actualKillReentryFixture();local title=addon.quests[96395].name;local setter=methods.SetText;local armed=true
        methods.SetText=function(self,value)
            if not before then setter(self,value)end
            if armed and value==title then armed=false;ui.quest=96403;ui:Refresh()end
            if before then setter(self,value)end
        end
        ui:RefreshDetail();methods.SetText=setter
        assert(not armed and ui.quest==96403 and not visibleDetail(ui,title)and visibleDetail(ui,addon.quests[96403].name))
        assert(visibleDetail(ui,addon.L("OBJECTIVE_ITEM","Dwarven Heirloom",8)))
    end
end)

check("Real quest events expose only the matching visible progress or turn-in dialogue without replacing saved quest prose", function()
    assert(type(addon.DialogueTextEvent) == "function" and type(addon.DialogueText) == "function")
    local keys = { "GetQuestID", "UnitGUID", "QuestFrame", "QuestFrameProgressPanel", "QuestFrameRewardPanel", "GetProgressText", "GetRewardText" }
    local saved = {}; for _, key in ipairs(keys) do saved[key] = _G[key] end
    local texts, oldText = addon.char.texts, addon.char.texts[65]
    local progressReads, completionReads = 0, 0
    GetQuestID = function(...) assert(select("#", ...) == 0); return 65 end
    UnitGUID = function(unit) assert(unit == "player"); return "Player-dialogue-events" end
    local historyBefore = addon.Context().completed(65)
    QuestFrame, QuestFrameProgressPanel, QuestFrameRewardPanel = create("Frame"), create("Frame"), create("Frame")
    GetProgressText = function(...) assert(select("#", ...) == 0); progressReads = progressReads + 1; return "Bring the requested materials." end
    GetRewardText = function(...) assert(select("#", ...) == 0); completionReads = completionReads + 1; return "Thank you for your help." end
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_PROGRESS")
    assert(progressReads == 0 and completionReads == 0, "Events must capture metadata without reading prose")
    QuestFrame:Show(); QuestFrameProgressPanel:Show()
    local progress = assert(addon.DialogueText(65), "Registered progress event did not reach the current-dialogue adapter")
    assert(progress.stage == "progress" and progress.text == "Bring the requested materials." and progressReads == 1 and completionReads == 0)
    assert(progress.current() and progress.current() and progressReads == 1, "Scope validation must not reread prose")
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_COMPLETE")
    assert(not progress.current() and completionReads == 0)
    QuestFrameProgressPanel:Hide(); QuestFrameRewardPanel:Show()
    local completion = assert(addon.DialogueText(65))
    assert(completion.stage == "completion" and completion.text == "Thank you for your help." and completionReads == 1)
    assert(addon.char.texts == texts and texts[65] == oldText, "Dialogue stages must not overwrite saved original quest text")
    assert(historyBefore ~= true and addon.Context().completed(65) == historyBefore, "The reward panel is not a completed-history fact")
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_FINISHED")
    assert(not completion.current() and addon.DialogueText(65) == nil)
    for _, key in ipairs(keys) do _G[key] = saved[key] end
    addon.DialogueTextEvent("PLAYER_LEAVING_WORLD")
end)

check("Completion events expose matching visible portraits without NPC log or prose requirements",function()
    assert(type(addon.DialogueTurnInPortrait)=="function","completion portrait provider is unavailable")
    addon.UI.frame:Hide()
    local qid=98423;assert(addon.quests[qid].start.itemID==281030)
    local portraitReads,proseReads,selectedReads,effects=0,0,0,0
    local texts=addon.char.texts;local savedText=texts[qid];local character=addon.char
    GetQuestID=function(...)assert(select("#",...)==0);return qid end
    UnitGUID=function(unit)if unit=="player"then return "Player-completion-events"end;assert(unit=="npc");return nil end
    C_QuestLog.GetSelectedQuest=function()selectedReads=selectedReads+1;return 65 end
    C_QuestLog.GetLogIndexForQuestID=function()selectedReads=selectedReads+1;return nil end
    C_QuestLog.IsOnQuest=function()return false end
    HaveQuestRewardData=function()error("no reward-loaded gate is supported for this dialogue accessor")end
    GetRewardText=nil
    GetProgressText=function()proseReads=proseReads+1;error("portrait must not read progress text")end
    GetQuestText=function()proseReads=proseReads+1;error("portrait must not read original text")end
    AcceptQuest=function()effects=effects+1 end;SelectQuestLogEntry=function()effects=effects+1 end
    addon.Navigation={Start=function()effects=effects+1 end,Map=function()effects=effects+1 end,Stop=function()end}
    QuestFrame,QuestFrameRewardPanel,QuestFrameProgressPanel=create("Frame"),create("Frame"),create("Frame")
    local display=9876
    GetQuestPortraitTurnIn=function(...)assert(select("#",...)==0);portraitReads=portraitReads+1;return display,"ignored synthetic portrait prose","Completion speaker"end
    local function event(name)eventFrame.scripts.OnEvent(eventFrame,name)end
    event("QUEST_COMPLETE")
    assert(addon.DialogueTurnInPortrait(qid)==nil and portraitReads==0,"pending not-yet-shown stage is not readable")
    QuestFrame:Show();QuestFrameRewardPanel:Show()
    local result=assert(addon.DialogueTurnInPortrait(qid,function()return true end))
    assert(result.source=="dialogue"and result.stage=="completion"and result.displayID==9876 and result.name=="Completion speaker")
    assert(result.npcID==nil and result.portraitSource==nil and result.hidden==nil)
    local reads=portraitReads;assert(result.current()and result.current()and portraitReads==reads)
    assert(addon.DialogueTurnInPortrait(96393)==nil and portraitReads==reads,"another catalogue ID cannot read this conversation")
    assert(addon.DialogueTurnInPortrait(qid,function()return false end)==nil)
    assert(result.current(),"a false caller must not erase otherwise valid conversation ownership")
    assert(selectedReads==0 and proseReads==0 and effects==0 and addon.char==character and character.texts==texts and texts[qid]==savedText)
    local state=addon.Context();assert(state.active(qid)==false and state.completed(qid)~=true)
    QuestFrameRewardPanel:Hide();assert(not result.current()and addon.DialogueTurnInPortrait(qid)==nil)
    QuestFrameRewardPanel:Show();assert(addon.DialogueTurnInPortrait(qid)==nil,"a closed observed stage cannot revive without its own event")
    event("QUEST_COMPLETE");assert(addon.DialogueTurnInPortrait(qid).displayID==9876)
    event("QUEST_PROGRESS");QuestFrameRewardPanel:Hide();QuestFrameProgressPanel:Show()
    reads=portraitReads;assert(addon.DialogueTurnInPortrait(qid)==nil and portraitReads==reads)
    QuestFrameProgressPanel:Hide();QuestFrameRewardPanel:Show();event("QUEST_COMPLETE")
    display=0;result=assert(addon.DialogueTurnInPortrait(qid));assert(result.hidden==true and result.displayID==nil and result.current())
    display=-1;assert(addon.DialogueTurnInPortrait(qid)==nil,"negative display is unavailable, not an invented hidden sentinel")
    GetQuestPortraitTurnIn=nil;assert(addon.DialogueTurnInPortrait(qid)==nil)
    event("QUEST_FINISHED");assert(not result.current()and addon.DialogueTurnInPortrait(qid)==nil)
    assert(selectedReads==0 and proseReads==0 and effects==0 and addon.char==character and character.texts==texts and texts[qid]==savedText)
end)

check("Completion portrait ownership expires on leaving the world",function()
    local id=96395;GetQuestID=function()return id end
    QuestFrame:Show();QuestFrameRewardPanel:Show();QuestFrameProgressPanel:Hide()
    GetRewardText=function()error("fresh portrait must remain independent of completion prose")end
    local reads=0;GetQuestPortraitTurnIn=function()reads=reads+1;return 6543,nil,nil end
    eventFrame.scripts.OnEvent(eventFrame,"QUEST_COMPLETE")
    local result=assert(addon.DialogueTurnInPortrait(id));assert(result.displayID==6543 and reads==1)
    assert(result.current()and reads==1)
    eventFrame.scripts.OnEvent(eventFrame,"PLAYER_LEAVING_WORLD")
    assert(not result.current()and addon.DialogueTurnInPortrait(id)==nil)
end)

check("Actual level-one Defias giver click couples source UI navigation and owned planner layer intent",function()
    local q=assert(addon.quests[166]);assert(q.level==22 and q.minLevel==14 and q.requirementsKnown==false)
    local navigation=addon.Navigation;assert(loadfile("UI/Navigation.lua"))("DungeonPro",addon)
    local globals={"UnitLevel","UnitFactionGroup","UnitClass","UnitRace","GetLocale","C_QuestLog","C_Map",
        "UiMapPoint","CreateVector2D","GetPlayerFacing","TomTom","InCombatLockdown"};local saved={}
    for _,key in ipairs(globals)do saved[key]=_G[key]end
    local ui=addon.UI;local quest,dungeon,locale=ui.quest,ui.dungeon,addon.db.locale
    local highest,strataSetter,levelSetter=ui.frame.GetHighestFrameLevel,methods.SetFrameStrata,methods.SetFrameLevel
    UnitLevel=function()return 1 end;UnitFactionGroup=function()return "Alliance"end
    UnitClass=function()return "Mage","MAGE",8 end;UnitRace=function()return "Dwarf","Dwarf",3 end
    GetLocale=function()return "enUS"end;addon.db.locale="enUS";InCombatLockdown=function()return false end
    C_QuestLog={IsQuestFlaggedCompleted=function()return false end,IsOnQuest=function()return false end,
        ReadyForTurnIn=function()return false end,GetTitleForQuestID=function()return nil end,
        GetNumQuestLogEntries=function()return 0,0 end}
    local opened,pin,sets=0,nil,0
    C_Map={GetMapInfo=function()return{name="Westfall"}end,GetBestMapForUnit=function()return 1436 end,
        GetPlayerMapPosition=function()return{GetXY=function()return .5,.5 end}end,
        GetWorldPosFromMapPos=function(_,p)return 0,{x=p.y*1000,y=p.x*1000}end,
        OpenWorldMap=function(id)assert(id==1436);opened=opened+1 end,
        CanSetUserWaypointOnMap=function()return true end,GetUserWaypoint=function()return pin end,
        SetUserWaypoint=function(value)sets=sets+1;pin=value;return true end,ClearUserWaypoint=function()pin=nil end}
    UiMapPoint={CreateFromCoordinates=function(id,x,y)return{uiMapID=id,position={x=x,y=y}}end}
    CreateVector2D=function(x,y)return{x=x,y=y}end;GetPlayerFacing=function()return 0 end;TomTom=nil
    ui.frame.GetHighestFrameLevel=function(_,allChildren)assert(allChildren==true);return 40 end
    methods.SetFrameStrata=function(self,value)self.layerStrata=value end
    methods.SetFrameLevel=function(self,value)self.layerLevel=value end
    for _,d in ipairs(addon.dungeons)do if d.key=="dm"then ui.dungeon=d end end
    ui.frame:Show();ui.quest=166;ui:Refresh()
    local context=addon.Context()
    assert(context.level==1 and context.faction=="Alliance"and context.class=="MAGE"and context.race==3)
    assert(ui.engine:State(166).status=="LOCKED"and not ui.guide.enabled and ui.giver.enabled and ui.giverHasCoordinates)
    assert(ui.giverAction.id==166 and ui.giverAction.kind=="visit"and ui.giverAction.place==q.start)
    assert(q.start.npcID==234 and q.start.mapID==1436 and q.start.x==56.3 and q.start.y==47.5)
    local start=addon.Navigation.Start;local started,result=0,nil
    addon.Navigation.Start=function(action)started=started+1;assert(action==ui.giverAction);result=start(action);return result end
    ui.giver.scripts.OnClick();addon.Navigation.Start=start
    local guide
    for _,object in ipairs(objects)do if object.arrow and object.scripts.OnUpdate and object.shown then guide=object end end
    assert(started==1 and result==true and opened==1 and sets==1 and guide and guide.arrow.shown)
    assert(guide.layerStrata=="DIALOG"and guide.layerLevel==41)
    assert(pin and pin.uiMapID==1436 and math.abs(pin.position.x-.563)<1e-12 and math.abs(pin.position.y-.475)<1e-12)
    addon.Navigation.Stop();assert(not guide.shown and pin==nil)
    addon.Navigation=navigation
    for _,key in ipairs(globals)do _G[key]=saved[key]end
    ui.frame.GetHighestFrameLevel,methods.SetFrameStrata,methods.SetFrameLevel=highest,strataSetter,levelSetter
    ui.quest,ui.dungeon,addon.db.locale=quest,dungeon,locale
end)

check("Navigation probe prints only the shown world-map ID in decimal and keeps the other two diagnostic lines unchanged",function()
    local getter,originalPrint,toggle,probe=addon.Navigation.ProbeGeometry,print,addon.UI.Toggle,addon.ProbeClient
    local saved,beforeFrames,beforeMaps,beforeRequests=addon.char.probe,#objects,mapCalls,requests
    local toggles,questReads=0,0
    local expectedHud="Dungeon Pro nav/hud: shown=true visible=false strata=MEDIUM level=4 scale=0.750 uiUnit=(-2.50,9.00,354.00,104.00)"
    addon.UI.Toggle=function()toggles=toggles+1 end;addon.ProbeClient=function()questReads=questReads+1 end
    for _,sample in ipairs({{id=1,text="1"},{id=1436,text="1436"},{id=9007199254740991,text="9007199254740991"}})do
        local output={}
        addon.Navigation.ProbeGeometry=function()return{status="known",frames={
            hud={status="known",shown=true,visible=false,strata="MEDIUM",level=4,scale=.75,left=-2.5,bottom=9,width=354,height=104,
                displayedMapID=777,questText="DO_NOT_PRINT"},
            planner={status="unknown",displayedMapID=888},
            worldMap={status="known",shown=true,visible=false,displayedMapID=sample.id,questText="DO_NOT_PRINT"},
            player={name="DO_NOT_PRINT",mapID=999}}}end
        print=function(line)output[#output+1]=line end
        SlashCmdList.DUNGEONPRO("probe nav")
        assert(#output==3 and output[1]==expectedHud and output[2]=="Dungeon Pro nav/planner: unknown")
        assert(output[3]:sub(-#(" mapID="..sample.text))==" mapID="..sample.text)
        for _,line in ipairs(output)do assert(#line<=240 and not line:find("DO_NOT_PRINT",1,true))end
    end
    addon.Navigation.ProbeGeometry,print,addon.UI.Toggle,addon.ProbeClient=getter,originalPrint,toggle,probe
    assert(toggles==0 and questReads==0 and addon.char.probe==saved and #objects==beforeFrames and mapCalls==beforeMaps and requests==beforeRequests)
end)
check("Navigation probe rejects malformed restricted hidden and unknown displayed-map IDs without extra output",function()
    local getter,originalPrint,checker=addon.Navigation.ProbeGeometry,print,issecretvalue
    local restricted={};issecretvalue=function(value)return rawequal(value,restricted)end
    local cases={{},{value=0},{value=-1},{value=1.5},{value=9007199254740992},{value=math.huge},{value=0/0},
        {value="1436"},{value=true},{value={}},{value=restricted},
        {value=1436,shown=false},{value=1436,shown=restricted},{value=1436,status="unknown"},{value=1436,missing=true}}
    for _,case in ipairs(cases)do
        local output={}
        addon.Navigation.ProbeGeometry=function()return{status="known",frames={worldMap=not case.missing and{
            status=case.status or"known",shown=case.shown==nil and true or case.shown,displayedMapID=case.value}}}end
        print=function(line)output[#output+1]=line end
        SlashCmdList.DUNGEONPRO("probe nav")
        assert(#output==3 and output[1]=="Dungeon Pro nav/hud: unknown"and output[2]=="Dungeon Pro nav/planner: unknown")
        assert(output[3]:sub(-#" mapID=unknown")==" mapID=unknown")
        for _,line in ipairs(output)do assert(#line<=240 and not line:find("nan",1,true)and not line:find("inf",1,true))end
    end
    addon.Navigation.ProbeGeometry,print,issecretvalue=getter,originalPrint,checker
end)

check("Actual startup recovers a late minimap and its launcher opens the planner while respecting current hide preferences", function()
    local native, timer, prefs = Minimap, C_Timer, addon.db.minimap
    local queue = {}
    C_Timer = { After = function(delay, fn)
        if delay == 0.25 then queue[#queue + 1] = fn else timer.After(delay, fn) end
    end }
    Minimap = create("Frame"); Minimap:SetWidth(0)
    local legacy = { hide = true, angle = 180, other = "preserve" }
    addon.db.minimap = legacy
    local quest, dungeon, pins = addon.UI.quest, addon.UI.dungeon, #waypoints
    eventFrame.scripts.OnEvent(eventFrame, "PLAYER_ENTERING_WORLD")
    local button = assert(addon.Minimap.button)
    assert(not button:IsShown() and #queue == 1)
    Minimap:SetWidth(198)
    table.remove(queue, 1)()
    assert(button:IsShown() and button.point[2] == Minimap and #queue == 0)
    assert(legacy.launcherVersion == 1 and legacy.hide == false and legacy.angle == 180 and legacy.other == "preserve")
    local shown = addon.UI.frame:IsShown()
    button.scripts.OnMouseDown(button, "LeftButton"); button.scripts.OnClick(button, "LeftButton")
    assert(addon.UI.frame:IsShown() ~= shown and addon.UI.quest == quest and addon.UI.dungeon == dungeon and #waypoints == pins)
    SlashCmdList.DUNGEONPRO("minimap")
    assert(not button:IsShown() and legacy.hide == true and legacy.launcherVersion == 1)
    eventFrame.scripts.OnEvent(eventFrame, "PLAYER_ENTERING_WORLD")
    assert(not button:IsShown() and legacy.hide == true and #queue == 0)
    if addon.UI.frame:IsShown() ~= shown then addon.UI:Toggle() end
    Minimap, C_Timer, addon.db.minimap = native, timer, prefs
    addon.Minimap:Initialize()
end)

print("Client/UI modeled checks passed: " .. total .. " (no pixel or native-client validation)")
