local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon = fixture.addon
local canvas = CreateFrame("Frame"); canvas:SetSize(1000, 500)
WorldMapFrame = CreateFrame("Frame")
function WorldMapFrame:GetMapID() return self.mapID end
function WorldMapFrame:GetCanvas() return canvas end
function WorldMapFrame:GetCanvasScale() return 1 end
C_Map.OpenWorldMap = function(id) WorldMapFrame.mapID = id; WorldMapFrame:Show() end
C_EncounterJournal = { GetInstanceForGameMap = function() return nil end,
    GetDungeonEntrancesForMap = function() return {} end }
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
SlashCmdList.DUNGEONPRO("")
local ui = addon.UI
for _, d in ipairs(addon.dungeons) do if d.key == "thanes" then ui.dungeon = d end end
ui.quest = nil; ui:Refresh()
assert(ui.entrance.enabled and ui.entranceBinding.point.origin == "recorded")
local notice
for _, line in ipairs(ui.details) do if line.shown and line.text == addon.L("DUNGEON_ENTRANCE_RECORDED") then notice = true end end
assert(notice, "recorded entrance provenance is visible in the actual overview")
local function markerAt(x, y)
    for _, object in ipairs(fixture.objects) do
        if object.icon and object.parent == canvas and object.shown then
            assert(object.point and object.point[1] == "CENTER" and object.point[2] == canvas)
            assert(math.abs(object.point[4] - x * 10) < 1e-8 and math.abs(object.point[5] + y * 5) < 1e-8)
            return true
        end
    end
    error("destination marker missing")
end
ui.entrance.scripts.OnClick()
assert(WorldMapFrame.mapID == 1455 and markerAt(27.5, 48))
addon.Navigation.Stop()
ui:InspectQuest(96394)
assert(ui.map.enabled)
ui.map.scripts.OnClick()
assert(WorldMapFrame.mapID == 1455 and markerAt(32.8, 48.6))
print("Actual entrance and quest-giver click composition: PASS")
