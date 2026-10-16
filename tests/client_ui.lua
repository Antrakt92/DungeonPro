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
C_Timer = { After = function(_, fn) fn() end }
CreateVector2D = function(x, y) return { x = x, y = y } end
C_Map = { GetMapInfo = function() return { name = "Westfall" } end,
    GetBestMapForUnit = function() return 1436 end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.5 end } end,
    GetWorldPosFromMapPos = function(_, p) return 0, { x = p.y * 1000, y = p.x * 1000 } end,
    OpenWorldMap = function(id) assert(id > 0); mapCalls = mapCalls + 1 end,
    CanSetUserWaypointOnMap = function() return true end,
    SetUserWaypoint = function(p) waypoints[#waypoints + 1] = p end }
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
    C_Map.GetUserWaypoint = function() return { uiMapID = 1436, position = { x = 0.2, y = 0.3 } } end
    C_Map.ClearUserWaypoint = function() cleared = cleared + 1 end
    addon.Navigation.Start({ id = 65, place = addon.quests[65].start })
    addon.Navigation.Stop(); assert(cleared == 0)
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
    local callbacks, calls = {}, 0
    C_Timer = { After = function(delay, fn)
        if delay == 2 then callbacks[#callbacks + 1] = fn else fn() end
    end }
    C_QuestLog.RequestLoadQuestByID = function(id) assert(id == 65); calls = calls + 1 end
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_DATA_LOAD_RESULT", 65, false)
    assert(#callbacks == 1 and calls == 0)
    callbacks[1](); assert(calls == 1)
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_DATA_LOAD_RESULT", 65, true)
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_DATA_LOAD_RESULT", 65, false)
    assert(#callbacks == 1 and calls == 1)
    C_Timer, C_QuestLog.RequestLoadQuestByID = savedTimer, savedRequest
end)
print("Client/UI modeled checks passed: " .. total .. " (no pixel or native-client validation)")
