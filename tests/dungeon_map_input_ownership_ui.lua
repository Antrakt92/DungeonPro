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

local function open() ui.dungeon=dungeon;ui.frame:Show();assert(ui:OpenDungeonMap(dungeon));return ui.dungeonMap end
local b=open();local floor=b.next.scripts.OnClick;local back=b.back.scripts.OnClick
floor();assert(ui.dungeonMapState.model.mapID==903)
local latest=ui.dungeonMapState;local before=calls;floor();back()
assert(calls==before and ui.dungeonMapState==latest and b.shown)
b.previous.scripts.OnClick();assert(ui.dungeonMapState.model.mapID==901)
local oldNext,oldBack=b.next.scripts.OnClick,b.back.scripts.OnClick
ui:CloseDungeonMap(true);open();latest=ui.dungeonMapState;before=calls
oldNext();oldBack();assert(calls==before and ui.dungeonMapState==latest and b.shown)
local savedLocale=a.db.locale;local obsolete=b.next.scripts.OnClick
a.db.locale='ruRU';before=calls;obsolete();assert(calls==before);ui:SyncDungeonMapContext();assert(not b.shown)
a.db.locale=savedLocale;open()
local savedDungeon=ui.dungeon;obsolete=b.next.scripts.OnClick;ui.dungeon=a.dungeons[2];before=calls
obsolete();assert(calls==before);ui:SyncDungeonMapContext();assert(not b.shown);ui.dungeon=savedDungeon;open()
assert(b.scripts.OnMouseWheel==nil,'map intentionally exposes no wheel action')
print('PASS current/retired floor, Back, close/reopen, locale, dungeon, absent custom wheel controls')
-- The action proof is an explicit callback dependency; it changes the consumed public dispatcher.
local original=ui.OpenDungeonMap;local foreign,fired=0,false
local state=ui.dungeonMapState;local proof=state.proof
state.proof=function()
 if not fired then fired=true;ui.OpenDungeonMap=function()foreign=foreign+1;return true end end
 return proof()
end
b.next.scripts.OnClick();ui.OpenDungeonMap=original
assert(fired,'proof mutation must fire')
assert(foreign==0,'floor input must not dispatch a substituted OpenDungeonMap after its proof callback')
print('PASS consumed dispatcher mutation retired')

-- Restoring capability permits an ordinary new action from the same physical control.
b.next.scripts.OnClick();assert(ui.dungeonMapState.model.mapID==903)
ui:CloseDungeonMap(true);local savedProvider=a.DungeonMapSnapshot
a.DungeonMapSnapshot=function() return nil end
assert(not ui:OpenDungeonMap(dungeon));b=ui.dungeonMap;assert(b.retry.shown)
local shown=ui.frame.IsShown;foreign=0;fired=false
ui.frame.IsShown=function(self)
 if not fired then fired=true;ui.OpenDungeonMap=function()foreign=foreign+1 end end
 return shown(self)
end
b.retry.scripts.OnClick();ui.frame.IsShown=shown;ui.OpenDungeonMap=original
assert(fired and foreign==0,'Retry cannot invoke a dispatcher substituted by the visibility callback')
a.DungeonMapSnapshot=savedProvider;open();b=ui.dungeonMap
local close=ui.CloseDungeonMap;local retainedBack=b.back.scripts.OnClick;foreign=0
ui.CloseDungeonMap=function()foreign=foreign+1 end
retainedBack();ui.CloseDungeonMap=close
assert(foreign==0 and b.shown,'Back must not call a substituted close capability')
b.back.scripts.OnClick();assert(not b.shown and ui.detailScroll.shown)
open();b.next.scripts.OnClick();assert(ui.dungeonMapState.model.mapID==903)
print('PASS fresh floor after restore, Retry callback substitution, Back close substitution and ordinary Back/reopen')

-- Unrelated Open capability does not block Back, even if native art proof expired.
state=ui.dungeonMapState;state.proof=function()error('Back must not read expired art')end
ui.OpenDungeonMap=function()error('Back must not consume Open')end
b.back.scripts.OnClick();ui.OpenDungeonMap=original
assert(not b.shown and ui.detailScroll.shown)
open();b=ui.dungeonMap;local closeMethod=ui.CloseDungeonMap;foreign=0
ui.CloseDungeonMap=function()foreign=foreign+1 end
b.scripts.OnUpdate(b,.5);ui.CloseDungeonMap=closeMethod
assert(foreign==0 and b.shown,'input ownership must not introduce foreign OnUpdate cleanup')
ui:CloseDungeonMap(true);open();b.next.scripts.OnClick();assert(ui.dungeonMapState.model.mapID==903)
print('PASS Back ignores unrelated Open/expired art; update behavior unchanged; restored controls remain usable')
