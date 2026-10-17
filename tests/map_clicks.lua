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
local function cardFor(dungeon)
    for _, result in ipairs(ui.catalogLanguageView.results) do
        if result.dungeon == dungeon then return result.row end
    end
    error("dungeon card missing")
end
assert(ui.entrance == nil and ui.entranceBinding.point.origin == "recorded", "entrance action has moved out of the toolbar")
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
cardFor(ui.dungeon).entranceControl.scripts.OnClick()
assert(WorldMapFrame.mapID == 1455 and markerAt(27.5, 48))
addon.Navigation.Stop()
ui:InspectQuest(96394)
assert(ui.map.enabled)
ui.map.scripts.OnClick()
assert(WorldMapFrame.mapID == 1455 and markerAt(32.8, 48.6))
local expected = {}
for _, key in ipairs({ "rfc", "wc", "dm", "sfk", "bfd", "stocks", "gnom", "rfk", "sm", "rfd", "ulda", "zf",
    "mara", "st", "brd", "lbrs", "ubrs", "dire", "scholo", "strat", "thanes", "lordaeron", "excavation", "dalaran" }) do
    expected[key] = true
end
local routes, unknown = 0, 0
local selectedDungeon, selectedQuest = ui.dungeon, ui.quest
local catalogGeneration = ui.catalogGeneration
ui.language.scripts.OnEnter()
assert(addon.Language.session).rows[2].scripts.OnEnter()
assert(ui.catalogGeneration == catalogGeneration, "language preview retains the card route owners")
for _, dungeon in ipairs(addon.dungeons) do
    addon.Navigation.Stop()
    local row = cardFor(dungeon)
    local control = assert(row.entranceControl)
    if expected[dungeon.key] then
        routes = routes + 1
        local entry = assert(dungeon.entrance)
        assert(control.enabled and row.entranceBinding.dungeon == dungeon, dungeon.key .. ": entrance action belongs to its card")
        control.scripts.OnClick()
        assert(WorldMapFrame.mapID == entry.mapID and markerAt(entry.x, entry.y), dungeon.key .. ": click renders its own recorded point")
    else
        unknown = unknown + 1
        assert(not control.enabled and not row.entranceBinding, "unknown entrance cannot reuse the previous dungeon's destination")
    end
    assert(ui.dungeon == selectedDungeon and ui.quest == selectedQuest, "card entrance icon does not replace the selected quest")
end
assert(routes == 24 and unknown == 5)
addon.Language:Cancel(ui)
print("Actual catalogue entrance clicks: PASS (24 recorded routes, 5 unknown)")
print("Actual entrance and quest-giver click composition: PASS")
