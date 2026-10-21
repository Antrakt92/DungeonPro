-- Actual TOC and planner controls with controlled native artwork, not coverage proof.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
-- Controlled component opt-in; not native map availability.
a.experimentalDungeonMaps=true
local calls,effects,total=0,0,0
local game,journal,base,upper,group=389,910001,920001,920002,930001
local oldInfo=C_Map.GetMapInfo
local function forbidden()effects=effects+1;error("viewing a map cannot navigate or change native selection")end
local function observed(value)calls=calls+1;return value end
Enum={UIMapType={Dungeon=4,Micro=5}}
C_EncounterJournal={GetInstanceForGameMap=function(id)return observed(id==game and journal or nil)end}
EJ_GetInstanceInfo=function(id)
 assert(id==journal);observed(true)
 return "Controlled complex",nil,nil,nil,nil,nil,base,nil,nil,game
end
local infos={[base]={mapID=base,mapType=4,name="Controlled ground"},[upper]={mapID=upper,mapType=5,name="Controlled upper"}}
local layers={{layerWidth=513,layerHeight=257,tileWidth=256,tileHeight=256}}
local textures={950001,950002,950003,950004,950005,950006}
local members={{mapID=base,name="Controlled ground",relativeHeightIndex=0},{mapID=upper,name="Controlled upper",relativeHeightIndex=1}}
C_Map.GetMapInfo=function(id)if infos[id]then return observed(infos[id])end;return oldInfo(id)end
C_Map.MapHasArt=function(id)assert(infos[id]);return observed(true)end
C_Map.GetMapArtID=function(id)assert(infos[id]);return observed(940001)end
C_Map.GetMapArtLayers=function(id)assert(infos[id]);return observed(layers)end
C_Map.GetMapArtLayerTextures=function(id,index)assert(infos[id]and index==1);return observed(textures)end
C_Map.GetMapGroupID=function(id)assert(infos[id]);return observed(group)end
C_Map.GetMapGroupMembersInfo=function(id)assert(id==group);return observed(members)end
EJ_SelectInstance,EJ_SelectTier,OpenWorldMap,LoadAddOn=forbidden,forbidden,forbidden,forbidden
C_Map.OpenWorldMap,C_Map.SetUserWaypoint=forbidden,forbidden
C_Timer={After=function()end};issecretvalue=function()return false end;GetLocale=function()return"enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();a.db.locale="enUS";ui.includeUnavailable=true
a.Navigation={Start=forbidden,Map=forbidden}
local dungeon
for _,d in ipairs(a.dungeons)do if d.instanceID==game then dungeon=d;break end end
assert(dungeon and calls==0,"load and ordinary browsing must not query native dungeon maps")
local function overview()
 ui:CloseDungeonMap(true);ui.dungeon,ui.quest=dungeon,nil;ui:Refresh();ui.detailScroll:SetSize(400,622)
 assert(not ui.overviewMapControl.shown and not ui.overviewMapControl.enabled and ui.overviewMapControl.scripts.OnClick==nil)
end
local function open()
 overview();assert(ui:OpenDungeonMap(dungeon));assert(ui.dungeonMap and ui.dungeonMap.shown)
 assert(ui.dungeonMapState.model and ui.dungeonMapState.model.gameMapID==game)
 return ui.dungeonMap
end
local function test(name,fn)fn();assert(effects==0);total=total+1;print("PASS "..name)end
test("Manual component API invokes the native adapter while compact browsing stays inert",function()
 overview();local before=calls;ui:RefreshDetail();assert(calls==before)
 local quest,history,engine,filter=ui.quest,ui.detailHistory,ui.engine,ui.includeUnavailable
 assert(ui:OpenDungeonMap(dungeon));local b=ui.dungeonMap
 assert(b.shown and not ui.detailScroll.shown and calls>before and #b.tiles==6)
 assert(ui.quest==quest and ui.detailHistory==history and ui.engine==engine and ui.includeUnavailable==filter)
 before=calls;b.back.scripts.OnClick();assert(not b.shown and ui.detailScroll.shown and calls==before)
end)
test("Native floor controls retain the exact selected dungeon and return without navigation",function()
 local b=open();b.next.scripts.OnClick()
 assert(ui.dungeon==dungeon and ui.quest==nil and ui.dungeonMapState.model.mapID==upper)
 assert(b.floor.text=="Controlled upper" and b.previous.enabled and not b.next.enabled)
 b.previous.scripts.OnClick();assert(ui.dungeonMapState.model.mapID==base)
 b.back.scripts.OnClick();assert(ui.detailScroll.shown)
end)
test("Selecting an actual quest retires the manual overlay without a default overview action",function()
 local b=open();local before=calls
 assert(ui:InspectQuest(dungeon.quests[1],true))
 assert(not b.shown and ui.detailScroll.shown and not ui.overviewMapControl.shown)
 assert(ui.overviewMapControl.scripts.OnClick==nil and calls==before,"compact view has no retained overview map action")
end)
test("Changing dungeon retires a native view without fetching replacement artwork",function()
 local b=open();local nextDungeon
 for _,d in ipairs(a.dungeons)do if d~=dungeon then nextDungeon=d;break end end
 local before=calls;ui.dungeon,ui.quest=nextDungeon,nil;ui:Refresh()
 assert(not b.shown and ui.detailScroll.shown and calls==before)
end)
test("Normal language commit closes the old native view",function()
 local b=open();local before=calls
 ui.language.scripts.OnEnter();assert(a.Language:Commit(assert(a.Language.session),"ruRU"))
 assert(not b.shown and ui.detailScroll.shown and calls==before)
 assert(ui.overviewMapControl.scripts.OnClick==nil and not ui.overviewMapControl.shown)
 ui.language.scripts.OnEnter();assert(a.Language:Commit(assert(a.Language.session),"enUS"))
end)
test("Window hide clears map callbacks and pooled artwork",function()
 local b=open();local before=calls
 ui.frame:Hide();ui.frame.scripts.OnHide(ui.frame)
 assert(not b.shown and not b.scripts.OnUpdate and ui.dungeonMapState==nil and calls==before)
 for _,tile in ipairs(b.tiles)do assert(not tile.shown and tile.texture==nil)end
 ui.frame:Show()
end)
test("Unavailable native capability keeps explicit retry and back usable",function()
 overview();local join=C_EncounterJournal.GetInstanceForGameMap;C_EncounterJournal.GetInstanceForGameMap=nil
 ui:OpenDungeonMap(dungeon);local b=ui.dungeonMap
 assert(b.shown and b.retry.shown and not b.scripts.OnUpdate and b.message.text==a.L("DUNGEON_MAP_UNAVAILABLE"))
 C_EncounterJournal.GetInstanceForGameMap=join;b.retry.scripts.OnClick()
 assert(ui.dungeonMapState.model and b.shown);b.back.scripts.OnClick();assert(ui.detailScroll.shown)
end)
print("Dungeon map integration: PASS "..total.." groups (controlled artwork; no native coverage claim)")
