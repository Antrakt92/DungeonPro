-- Controlled artwork DTOs verify retirement, not native map coverage or assets.
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;GetLocale=function()return"enUS"end;C_Timer={After=function()end}
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
u.detailScroll:SetSize(400,622);local dungeon=a.dungeons[1];u.dungeon=dungeon
local weak=setmetatable({},{__mode="v"});local label,small="large",false;local calls,proofCalls=0,{}
a.DungeonMapSnapshot=function(d,id,owner)
 assert(d==dungeon and owner());calls=calls+1
 local model={gameMapID=d.instanceID,journalID=900,baseMapID=901,mapID=id or 901,artID=902,layerIndex=1,
  name="Controlled native complex",width=513,height=257,tileWidth=256,tileHeight=256,columns=3,rows=2,
  textures={11,12,13,14,15,16},shared=true,floors={{mapID=901,name="Ground"},{mapID=903,name="Upper"}}}
 if small then model.width,model.height,model.columns,model.rows=256,256,1,1;model.textures={71};model.shared=false;model.floors={}end
 local token={model=model};local key=label
 weak[key]=model;weak[key.."-proof"]=token
 local function proof()proofCalls[key]=(proofCalls[key]or 0)+1;return token.model==model end
 return model,proof,proof
end
local function gc()collectgarbage("collect");collectgarbage("collect")end
local function open(key,isSmall,id)
 label,small=key,isSmall;assert(u:OpenDungeonMap(dungeon,id));assert(u.dungeonMapState.current());gc();assert(weak[key]and weak[key.."-proof"])
 return u.dungeonMap
end
local overlay=open("large",false);local tiles=overlay.tiles;local registry=tiles[6].questListWrites
local stale=registry.SetSize.current;local state=u.dungeonMapState
assert(state.current());overlay:Hide();gc();assert(weak.large and state.current(),"hidden warm overlay retains its current DTO until explicit retirement")
overlay:Show()
open("small",true);gc()
assert(not weak.large and not weak["large-proof"],"superseded large artwork DTO and producer proof must collect")
assert(weak.small and weak["small-proof"]and u.dungeonMapState.current(),"current artwork remains owned")
assert(overlay.tiles==tiles and tiles[6].questListWrites==registry,"native widgets and pooled repair registries retain identity")
local reads=proofCalls.large;assert(stale()==false and proofCalls.large==reads,"retired raw binding must reject before old producer calls")
local current=u.dungeonMapState;local count=calls
assert(not u:OpenDungeonMap(a.dungeons[2])and u.dungeonMapState==current and calls==count,"foreign requests do not retire a valid map")
local exposed=u.dungeonMapState.model
u:CloseDungeonMap(true);assert(exposed.textures[1]==71 and exposed.width==256,"retirement does not mutate externally retained DTO values");exposed=nil;gc()
assert(u.dungeonMapState==nil and not overlay:IsShown()and u.detailScroll:IsShown())
assert(not weak.small and not weak["small-proof"],"explicit close releases its last DTO and producer proof")
print("PASS large-to-small and close release DTO/proof snapshots while warm current state and pooled bindings survive")
-- A superseded floor has its own lifetime even when both floors use every tile.
open("ground",false);local oldNext=overlay.next.scripts.OnClick;label="upper";oldNext();gc()
assert(not weak.ground and weak.upper and u.dungeonMapState.model.mapID==903)
u:CloseDungeonMap(true);gc();assert(not weak.upper)
print("PASS explicit floor changes retire old models")
-- Native setter tails still repair to the newest view using the same registry.
open("tail-base",false);local tile=tiles[6];local show=tile.Show;local fired=false
local beforeRegistry=tile.questListWrites
 tile.Show=function(self)
 if not fired then fired=true;open("tail-new",true)end
 return show(self)
end
label,small="tail-old",false;assert(not u:OpenDungeonMap(dungeon));tile.Show=show;gc()
assert(fired and u.dungeonMapState.model.textures[1]==71 and overlay:IsShown()and not tile:IsShown()and tile.texture==nil)
assert(tile.questListWrites==beforeRegistry and not weak["tail-old"]and weak["tail-new"])
print("PASS late native tile Show repairs newest intent without retaining the retired DTO")
-- Close publishes its new physical intent before any native callback can open another map.
local hide=overlay.Hide;fired=false
 overlay.Hide=function(self)
 if not fired then fired=true;open("close-new",false)end
 return hide(self)
end
u:CloseDungeonMap(true);overlay.Hide=hide;gc()
assert(fired and overlay:IsShown()and u.dungeonMapState.current()and weak["close-new"]and not weak["tail-new"])
print("PASS a close callback cannot release or hide its newer replacement")
-- Accepted context retirement releases snapshots; native hiding invokes the normal close lifecycle.
u.detailTab="sources";u:SyncDungeonMapContext();gc()
assert(u.dungeonMapState==nil and not weak["close-new"])
for _,mode in ipairs({"quest","dungeon","locale","helper"})do
 open("drift-"..mode,false);local old=u.dungeonMapState;local before=proofCalls["drift-"..mode]
 local quest,selected,locale,clean=u.quest,u.dungeon,a.db.locale,a.Clean
 if mode=="quest"then u.quest=166 elseif mode=="dungeon"then u.dungeon=a.dungeons[2]
 elseif mode=="locale"then a.db.locale="zhTW"else a.Clean=function(...)return clean(...)end end
 assert(old.current()==false and proofCalls["drift-"..mode]==before,"context drift rejects before producer calls")
 u:SyncDungeonMapContext();gc();assert(u.dungeonMapState==nil and not weak["drift-"..mode])
 u.quest,u.dungeon,a.db.locale,a.Clean=quest,selected,locale,clean
end
open("frame-hide",false);u.frame:Hide();assert(u.frame.scripts.OnHide);u.frame.scripts.OnHide(u.frame);gc()
assert(u.dungeonMapState==nil and not weak["frame-hide"]and not weak["frame-hide-proof"])
print("PASS detail-tab and whole-frame hiding retire owned artwork")
