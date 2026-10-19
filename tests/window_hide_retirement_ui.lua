-- A retired close cannot erase a planner view reopened by cleanup callbacks.
local total = 0
local function fixture()
    local f = assert(loadfile("tests/client_ui.lua"))("fixture")
    local a, ui = f.addon, f.addon.UI
    issecretvalue = function() return false end
    GetLocale = function() return "enUS" end
    C_Timer = { After = function() end }
    f.eventFrame.scripts.OnEvent(f.eventFrame, "ADDON_LOADED", "DungeonPro")
    ui:Toggle(); a.db.locale = "enUS"; ui.includeUnavailable = true
    local dm
    for _, dungeon in ipairs(a.dungeons) do if dungeon.key == "dm" then dm = dungeon end end
    ui.dungeon, ui.quest = assert(dm), nil; ui:Refresh(); ui.detailScroll:SetSize(400, 622)
    a.DungeonMapSnapshot = function()
        return { gameMapID = dm.instanceID, journalID = 900, baseMapID = 901, mapID = 901, artID = 902,
            layerIndex = 1, name = "Native complex", width = 256, height = 256, tileWidth = 256,
            tileHeight = 256, columns = 1, rows = 1, textures = { 11 }, shared = false,
            floors = { { mapID = 901, name = "Ground" } } }, function() return true end, function() return true end
    end
    assert(ui:OpenDungeonMap(dm) and ui.dungeonMap.shown)
    local pins, native = 0, C_Map.SetUserWaypoint
    C_Map.SetUserWaypoint = function(point) pins = pins + 1; return native(point) end
    return a, ui, function() return pins end
end

for _, phase in ipairs({ "map", "popup", "hint", "language", "shown" }) do
    local a, ui, pins = fixture()
    local armed, fired, latest = false, false, nil
    local function reopen()
        if not armed then return end
        armed, fired = false, true
        ui.frame:Show(); ui:InspectQuest(166, true); ui:SetDetailTab("sources")
        assert(ui.quest == 166 and ui.renderedQuest == 166 and ui.detailTab == "sources" and ui.frame.shown)
        assert(ui:CopyLink(166) ~= false and ui.copyQuest == 166 and ui.copy.shown)
        latest = { generation = ui.rewardGeneration, revision = ui.detailTabRevision, binding = ui.giverBinding,
            offsets = ui:HistoryOffsets(), copy = ui.copy:GetText() }
        assert(latest.binding and latest.binding.current() and ui.giver.shown)
        ui.giver.scripts.OnClick(); assert(pins() == 1, "fresh reopened actual giver must dispatch")
    end
    if phase == "map" then
        local hide = ui.dungeonMap.Hide
        ui.dungeonMap.Hide = function(self) hide(self); reopen() end
    elseif phase == "popup" then
        ui.developerLinkRequest = {}
        StaticPopup_Hide = function() reopen() end
    elseif phase == "hint" then
        local hide = ui.HideNavigationHint
        ui.HideNavigationHint = function(self, ...) local result = hide(self, ...); reopen(); return result end
    elseif phase == "language" then
        local cancel = a.Language.Cancel
        a.Language.Cancel = function(...) local result = cancel(...); reopen(); return result end
    else
        local shown = ui.frame.IsShown
        ui.frame.IsShown = function(self) local result = shown(self); reopen(); return result end
    end
    armed = true
    -- The native-shaped fixture does not deliver OnHide automatically.
    ui.frame.shown = false; ui.frame.scripts.OnHide(ui.frame)
    assert(fired and latest and ui.frame.shown and ui.quest == 166 and ui.renderedQuest == 166, phase)
    ui.giver.scripts.OnClick()
    assert(pins() == 2, phase .. ": old close disabled the visible newly rendered giver")
    assert(ui.rewardGeneration == latest.generation and ui.detailTabRevision == latest.revision and
        latest.binding.current() and ui:HistoryOffsets() == latest.offsets, phase .. ": old close reset new reading state")
    assert(ui.copyQuest == 166 and ui.copy.shown and ui.copy:GetText() == latest.copy,
        phase .. ": old close erased the newly opened real quest link")
    StaticPopup_Hide = nil
    total = total + 1
end
print("PASS five fired cleanup/getter reentries preserve actual Sources, copy link and two native waypoints")

do
    local _, ui = fixture()
    ui:CloseDungeonMap(true); ui:InspectQuest(166, true); ui:CopyLink(166)
    local text, generation = ui.copy:GetText(), ui.rewardGeneration
    ui.CloseDungeonMap = nil
    local shown, armed, fired, foreign = ui.frame.IsShown, true, false, 0
    ui.frame.IsShown = function(self)
        local visible = shown(self)
        if armed then
            armed, fired = false, true
            ui.CloseDungeonMap = function()
                foreign = foreign + 1
                ui.copy:SetText("foreign cleanup ran")
            end
        end
        return visible
    end
    ui.frame.shown = false; ui.frame.scripts.OnHide(ui.frame)
    assert(fired and foreign == 0 and ui.copy:GetText() == text and ui.rewardGeneration == generation,
        "newly inserted optional helper must not run inside an older cleanup")
    total = total + 1
end
print("PASS absent optional cleanup helper stays owned across the first visibility callback")

do
    local a, ui, pins = fixture()
    ui:CloseDungeonMap(true); ui:InspectQuest(166, true); ui:SetDetailTab("sources"); ui:CopyLink(166)
    ui.pendingSearch = "old pending input"
    ui.detailReferencesExpanded, ui.detailNarrativeExpanded, ui.detailObjectivesExpanded = true, true, true
    local generation = ui.rewardGeneration
    ui.frame.shown = false; ui.frame.scripts.OnHide(ui.frame)
    assert(not ui.frame.shown and not ui.dungeonMap.shown and ui.pendingSearch == nil)
    assert(not ui.detailReferencesExpanded and not ui.detailNarrativeExpanded and not ui.detailObjectivesExpanded)
    assert(ui.rewardGeneration ~= generation and ui.detailOffsets == nil and ui.copyQuest == nil and not ui.copy.shown)
    assert(pins() == 0, "ordinary closing never navigates")
    ui.frame:Show(); ui:Refresh(); assert(ui.frame.shown and ui.quest == 166 and ui.renderedQuest == 166)
    total = total + 1
end
print("Window hide retirement UI: PASS " .. total .. " groups; modeled native callbacks, no native-client proof")
