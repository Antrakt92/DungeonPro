-- Controlled artwork fixtures verify geometry and ownership, not native map coverage.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
if not a.DungeonMapUI then assert(loadfile("UI/DungeonMap.lua"))("DungeonPro",a)end
for name,method in pairs(a.DungeonMapUI)do ui[name]=method end
C_Timer={After=function()end};issecretvalue=function()return false end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();a.db.locale="enUS";ui.detailScroll:SetSize(400,622)
local dungeon=a.dungeons[1];ui.dungeon=dungeon
local calls,checks,valid=0,0,true
local function dto(id,count)
 local model={gameMapID=dungeon.instanceID,journalID=900,baseMapID=901,mapID=id or 901,artID=902,layerIndex=1,
 name="Native complex",width=513,height=257,tileWidth=256,tileHeight=256,columns=3,rows=2,
 textures={11,12,13,14,15,16},shared=true,floors={{mapID=901,name="Ground"},{mapID=903,name="Upper"}}}
 if count==1 then model.width=256;model.height=256;model.columns=1;model.rows=1;model.textures={71}end
 return model
end
local nextModel
local function provider(d,id,owner)
 calls=calls+1;assert(d==dungeon and owner())
 local model=nextModel or dto(id)
 local function proof()checks=checks+1;return valid end
 return model,proof,function()return valid end
end
a.DungeonMapSnapshot=provider
local total=0
local function test(name,fn)
 valid=true;nextModel=nil;ui:CloseDungeonMap(true);ui.dungeon=dungeon;ui.frame:Show();ui.detailScroll:SetSize(400,622)
 fn();total=total+1;print("PASS "..name)
end
local function open()assert(ui:OpenDungeonMap(dungeon));return ui.dungeonMap end

test("load and ordinary context checks never query artwork",function()
 local before=calls;ui:SyncDungeonMapContext();assert(calls==before)
end)
test("native tile grid aspect fits and partial final edges crop",function()
 local before=calls;local b=open();assert(calls==before+1 and b.shown and not ui.detailScroll.shown)
 assert(b.title.text=="Native complex"and b.shared.text==a.L("DUNGEON_MAP_SHARED"))
 assert(#b.tiles==6 and b.tiles[6].texture==16)
 local scale=b.tiles[1].width/256
 assert(math.abs(b.tiles[3].width-scale)<.00001 and math.abs(b.tiles[6].height-scale)<.00001)
 assert(b.tiles[3].texCoords[2]==1/256 and b.tiles[6].texCoords[4]==1/256)
 local first,last=b.tiles[1],b.tiles[6]
 assert(first.point[4]>=12 and last.point[4]+last.width<=388.0001)
 assert(-first.point[5]>=0 and -last.point[5]+last.height<=610.0001)
end)
test("floor controls request exact native members and back preserves planner state",function()
 local quest,engine,history=ui.quest,ui.engine,ui.detailHistory
 local b=open();assert(not b.previous.enabled and b.next.enabled)
 b.next.scripts.OnClick();assert(ui.dungeonMapState.model.mapID==903 and b.floor.text=="Upper")
 assert(b.previous.enabled and not b.next.enabled)
 b.back.scripts.OnClick();assert(not b.shown and ui.detailScroll.shown)
 assert(ui.quest==quest and ui.engine==engine and ui.detailHistory==history)
end)
test("smaller artwork retires every excess tile",function()
 local b=open();nextModel=dto(nil,1);assert(ui:OpenDungeonMap(dungeon))
 assert(b.tiles[1].texture==71 and b.tiles[1].shown)
 for i=2,6 do assert(not b.tiles[i].shown and b.tiles[i].texture==nil)end
end)
test("unavailable is explicit retry only",function()
 local saved=a.DungeonMapSnapshot;a.DungeonMapSnapshot=function()calls=calls+1 end
 local before=calls;assert(not ui:OpenDungeonMap(dungeon));local b=ui.dungeonMap
 assert(b.shown and b.retry.shown and b.message.text==a.L("DUNGEON_MAP_UNAVAILABLE"))
 assert(b.scripts.OnUpdate==nil and calls==before+1)
 a.DungeonMapSnapshot=saved;ui:SyncDungeonMapContext();assert(not b.shown)
 open()
end)
test("invalid geometry cannot display invented artwork",function()
 nextModel=dto();nextModel.width=0
 assert(not ui:OpenDungeonMap(dungeon));local b=ui.dungeonMap
 assert(b.message.shown)
 for _,tile in ipairs(b.tiles)do assert(not tile.shown)end
end)
test("valid visible freshness is bounded and stale view closes",function()
 local b=open();local before=checks
 b.scripts.OnUpdate(b,.2);b.scripts.OnUpdate(b,.2);assert(checks==before)
 b.scripts.OnUpdate(b,.1);assert(checks==before+1)
 valid=false;b.scripts.OnUpdate(b,.5);assert(not b.shown and ui.detailScroll.shown)
end)
test("selection language and character changes retire retained floor actions",function()
 for _,which in ipairs({"quest","locale","char"})do
  local b=open();local click=b.next.scripts.OnClick;local before=calls
  local oldQuest,oldLocale,oldChar=ui.quest,a.db.locale,a.char
  if which=="quest"then ui.quest=777 elseif which=="locale"then a.db.locale="zhCN"else a.char={}end
  click();assert(calls==before);ui:SyncDungeonMapContext();assert(not b.shown)
  ui.quest,a.db.locale,a.char=oldQuest,oldLocale,oldChar
 end
end)
test("late native tile Show cannot revive an old larger view",function()
 local b=open();local tile=b.tiles[6];local original=tile.Show;local fired=false
 tile.Show=function(self)
  if not fired then fired=true;nextModel=dto(nil,1);assert(ui:OpenDungeonMap(dungeon))end
  original(self)
 end
 assert(not ui:OpenDungeonMap(dungeon));tile.Show=original
 assert(fired and b.shown and b.tiles[1].texture==71 and not tile.shown and tile.texture==nil)
end)
test("late native overlay Show cannot overwrite explicit back",function()
 local b=open();local original=b.Show;local fired=false
 b.Show=function(self)if not fired then fired=true;ui:CloseDungeonMap()end;original(self)end
 assert(not ui:OpenDungeonMap(dungeon));b.Show=original
 assert(fired and not b.shown and ui.detailScroll.shown)
end)
test("optional floor absence shows base art without invented floor controls",function()
 nextModel=dto();nextModel.floors={};local b=open()
 assert(not b.previous.shown and not b.next.shown and not b.floor.shown and b.tiles[1].shown)
end)
test("thirty-two native floors stay a bounded previous-next selector",function()
 nextModel=dto();nextModel.floors={}
 for i=1,32 do nextModel.floors[i]={mapID=900+i,name="Native floor "..i}end
 local b=open();assert(b.floor.text=="Native floor 1" and b.next.enabled and not b.previous.enabled)
 assert(#b.tiles==6)
end)
test("all locale captions refresh without changing source or navigation",function()
 local saved=a.db.locale;local callsBefore=calls
 for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","itIT","koKR","zhCN","zhTW"})do
  a.db.locale=locale;local b=open()
  assert(b.back.label.text==a.L("DUNGEON_MAP_BACK")and b.next.label.text==a.L("DUNGEON_MAP_NEXT"))
 end
 assert(calls==callsBefore+10);a.db.locale=saved
end)
test("native dimension getter cannot overwrite a newer map intent",function()
 local original=ui.detailScroll.GetWidth;local fired=false
 ui.detailScroll.GetWidth=function(self)
  if not fired then fired=true;nextModel=dto(nil,1);assert(ui:OpenDungeonMap(dungeon))end
  return original(self)
 end
 assert(not ui:OpenDungeonMap(dungeon));ui.detailScroll.GetWidth=original
 assert(fired and ui.dungeonMapState.model.textures[1]==71 and ui.dungeonMap.shown)
end)
test("freshness callback may open a newer map without old retirement closing it",function()
 open();local old=ui.dungeonMapState;local original=old.proof;local fired=false
 old.proof=function()
  if not fired then fired=true;nextModel=dto(nil,1);assert(ui:OpenDungeonMap(dungeon));return false end
  return original()
 end
 ui.dungeonMap.scripts.OnUpdate(ui.dungeonMap,.5)
 assert(fired and ui.dungeonMapState~=old and ui.dungeonMap.shown and ui.dungeonMap.tiles[1].texture==71)
end)
test("foreign dungeon requests preserve the current selected map",function()
 local b=open();local state=ui.dungeonMapState;local before=calls
 assert(not ui:OpenDungeonMap({instanceID=dungeon.instanceID}))
 assert(ui.dungeonMapState==state and b.shown and calls==before)
end)
test("passive synchronization uses only raw proof and retires stale artwork",function()
 local b=open();local beforeCalls,beforeChecks=calls,checks
 valid=false;ui:SyncDungeonMapContext()
 assert(not b.shown and ui.detailScroll.shown and calls==beforeCalls and checks==beforeChecks)
end)
test("visible freshness retires a changed context without an explicit redraw",function()
 local b=open();local previous=ui.quest;ui.quest=999
 b.scripts.OnUpdate(b,.5);assert(not b.shown and ui.detailScroll.shown)
 ui.quest=previous
end)
test("wrapped native title and floor reserve their measured height",function()
 local b=open();local originalTitle,originalFloor=b.title.GetStringHeight,b.floor.GetStringHeight
 b.title.GetStringHeight=function()return 64 end;b.floor.GetStringHeight=function()return 54 end
 open();local top=-b.tiles[1].point[5]
 assert(top>=44+64+8+18+8+54+6+36)
 b.title.GetStringHeight,b.floor.GetStringHeight=originalTitle,originalFloor
end)
test("initial Clean cannot rebind the requested selected GameMap",function()
 local original,id=a.Clean,dungeon.instanceID;local fired=false;local before=calls
 a.Clean=function(value,kind)
  if not fired and value==dungeon and kind=="table" then fired=true;dungeon.instanceID=id+700000 end
  return original(value,kind)
 end
 local accepted=ui:OpenDungeonMap(dungeon)
 a.Clean=original;dungeon.instanceID=id
 assert(fired and not accepted and calls==before,"initial request must retire before rebound provider invocation")
end)
test("localizer cannot rebind the selected GameMap before provider invocation",function()
 local original,id=a.L,dungeon.instanceID;local fired=false;local before=calls
 a.L=function(key,...)
  if not fired and key=="DUNGEON_MAP_BACK" then fired=true;dungeon.instanceID=id+700000 end
  return original(key,...)
 end
 local accepted=ui:OpenDungeonMap(dungeon)
 a.L=original;dungeon.instanceID=id
 assert(fired and not accepted and calls==before,"staging callback must retire original GameMap request")
end)
test("detail tab switch retires map and retained floor callback",function()
 local previous=ui.detailTab;ui.detailTab="quest";local b=open();local click=b.next.scripts.OnClick;local before=calls
 ui.detailTab="sources";ui:SyncDungeonMapContext();click()
 assert(not b.shown and ui.detailScroll.shown and calls==before,"detail tab change must retire overlay")
 ui.detailTab=previous
end)
test("Back closes an expired native snapshot without dynamic or raw model reads",function()
 local b=open();local state=ui.dungeonMapState;local reads=0
 state.proof=function()reads=reads+1;return false end
 state.raw=function()reads=reads+1;return false end
 b.back.scripts.OnClick()
 assert(reads==0 and not b.shown and ui.detailScroll.shown,"Back must escape without querying an expired snapshot")
end)
test("retained Back cannot close a newer view",function()
 local b=open();local previous=b.back.scripts.OnClick;nextModel=dto(nil,1);open()
 local state=ui.dungeonMapState;previous()
 assert(ui.dungeonMapState==state and b.shown and b.tiles[1].texture==71)
end)
test("overlong native title and floor names fall back instead of painting",function()
 local b=open()
 nextModel=dto();nextModel.name=("t"):rep(501)
 nextModel.floors={{mapID=901,name=("f"):rep(501)},{mapID=903,name="Upper"}}
 b=open()
 assert(b.title.text==a.L("DUNGEON_MAP_OPEN"),"overlong map title falls back to the open caption")
 assert(not b.title.text:find(("t"):rep(100),1,true),"overlong map title stays unpainted")
 assert(b.floor.text==a.L("DUNGEON_MAP_FLOOR",1),"overlong floor name falls back to the numbered caption")
 assert(not b.floor.text:find(("f"):rep(100),1,true),"overlong floor name stays unpainted")
 nextModel=dto();nextModel.name=("t"):rep(500)
 nextModel.floors={{mapID=901,name=("f"):rep(500)},{mapID=903,name="Upper"}}
 b=open()
 assert(b.title.text==("t"):rep(500),"500-char map title keeps its native place")
 assert(b.floor.text==("f"):rep(500),"500-char floor name keeps its native place")
end)
print("Dungeon map UI modeled groups passed: "..total)
