-- Native responses are controlled observations, not a claim of Forever map coverage.
local a={};assert(loadfile("Core/Namespace.lua"))("DungeonPro",a)
assert(loadfile("Database/Catalog.lua"))("DungeonPro",a)
local catalogue=a.dungeons;local dungeon=assert(catalogue[1]);local game=assert(dungeon.instanceID)
local journal,base,floor=810001,820001,820002
local state,calls,effects,checks,total= nil,0,0,0,0
local function forbidden()effects=effects+1;error("inspection has no native actions")end
EJ_SelectInstance,EJ_SelectTier,EJ_SetDifficulty,OpenWorldMap,LoadAddOn=forbidden,forbidden,forbidden,forbidden,forbidden
C_AddOns={LoadAddOn=forbidden};C_SuperTrack={SetSuperTrackedUserWaypoint=forbidden}
local function copy(value)
 if type(value)~="table"then return value end
 local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result
end
local function observed(value)calls=calls+1;return copy(value)end
local function setup()
 a.dungeons=catalogue;a.db={locale="enUS"};a.char={};a.Language=nil
 issecretvalue=function(value)checks=checks+1;return value=="restricted"end
 GetLocale=function()return "enUS"end;Enum={UIMapType={Dungeon=4,Micro=5}}
 state={reverse=game,hasArt=true,art=830001,
  info={[base]={mapID=base,mapType=4,name="Native complex"},[floor]={mapID=floor,mapType=5,name="Native lower floor"}},
  layers={{layerWidth=1024,layerHeight=512,tileWidth=256,tileHeight=256},
   {layerWidth=513,layerHeight=257,tileWidth=256,tileHeight=256}},
  tiles={840001,840002,840003,840004,840005,840006},
  members={{mapID=floor,name="Native lower floor",relativeHeightIndex=-1},
   {mapID=base,name="Native complex",relativeHeightIndex=0}}}
 C_EncounterJournal={GetInstanceForGameMap=function(id)assert(id==game);return observed(journal)end}
 EJ_GetInstanceInfo=function(id)
  assert(id==journal);calls=calls+1
  return "Native journal",nil,nil,nil,nil,nil,base,nil,nil,state.reverse
 end
 C_Map={GetMapInfo=function(id)return observed(state.info[id])end,
  MapHasArt=function()return observed(state.hasArt)end,GetMapArtID=function()return observed(state.art)end,
  GetMapArtLayers=function()return observed(state.layers)end,
  GetMapArtLayerTextures=function(_,layer)assert(layer==2 or #state.layers==1);return observed(state.tiles)end,
  GetMapGroupID=function(id)assert(id==base);return observed(850001)end,
  GetMapGroupMembersInfo=function(id)assert(id==850001);return observed(state.members)end,
  SetUserWaypoint=forbidden,ClearUserWaypoint=forbidden}
end
setup();local loading=calls;assert(loadfile("Core/DungeonMap.lua"))("DungeonPro",a)
assert(calls==loading and effects==0,"loading never queries native data")
local function capture(request,owner)return a.DungeonMapSnapshot(dungeon,request,owner)end
local function test(name,fn)
 setup();fn();assert(effects==0);total=total+1;print("PASS "..name)
end

test("Explicit native chain yields detached row-major art and native-order floors",function()
 local model,current,raw=capture()
 assert(model and current()and raw())
 assert(model.gameMapID==game and model.journalID==journal and model.mapID==base and model.baseMapID==base)
 assert(model.layerIndex==2 and model.width==513 and model.height==257 and model.tileWidth==256 and model.tileHeight==256)
 assert(model.rows==2 and model.columns==3 and #model.textures==6 and model.textures[4]==840004)
 assert(model.floors[1].mapID==floor and model.floors[1].relativeHeightIndex==-1 and model.floors[2].mapID==base)
 assert(model.textures~=state.tiles and model.floors~=state.members)
 assert(current(),"equivalent fresh native tables preserve observations")
 local reads,checked=calls,checks;assert(raw()and calls==reads and checks==checked)
end)

test("Only exact native floor membership authorizes a requested map",function()
 local model,current=capture(floor);assert(model and current()and model.mapID==floor and model.baseMapID==base)
 assert(capture(820099)==nil)
 state.members[1].mapID=820099;assert(capture(floor)==nil)
end)

test("Optional groups may be absent without inventing floor metadata",function()
 C_Map.GetMapGroupID=nil;C_Map.GetMapGroupMembersInfo=nil
 local model,current=capture();assert(model and current()and #model.floors==0 and model.mapID==base)
 assert(capture(floor)==nil)
end)

test("Unavailable or wrong-namespace native identities never fall back to catalogue art",function()
 local cases={
  function()C_EncounterJournal=nil end,
  function()EJ_GetInstanceInfo=nil end,
  function()C_EncounterJournal.GetInstanceForGameMap=function()return nil end end,
  function()state.reverse=base end,
  function()state.info[base].mapType=3 end,
  function()state.hasArt=false end,
  function()state.art=0 end,
  function()state.info[base].mapID=journal end,
 }
 for _,mutate in ipairs(cases)do setup();mutate();assert(capture()==nil)end
end)

test("Malformed advertised groups retire rather than quietly choosing a different map",function()
 for _,mutate in ipairs({
  function()state.members[2]=nil end,
  function()state.members[1].mapID=base end,
  function()state.members[1].name=" "end,
  function()state.members[1].relativeHeightIndex=0/0 end,
  function()state.info[floor].mapType=3 end,
 })do setup();mutate();assert(capture()==nil)end
end)

test("Native artwork bounds reject malformed or incomplete texture grids",function()
 for _,mutate in ipairs({
  function()state.layers[1].layerWidth=0 end,
  function()state.layers[1].layerWidth=1.5 end,
  function()state.layers[1].layerHeight=math.huge end,
  function()state.layers[1].tileWidth="restricted"end,
  function()state.layers[1].layerWidth=65537 end,
  function()state.tiles[6]=nil end,
  function()state.tiles[4]=false end,
  function()state.tiles[7]=840007 end,
  function()state.layers[3]=state.layers[1];state.layers[2]=nil end,
 })do setup();mutate();assert(capture()==nil)end
end)

test("The maximum supported tile count remains usable",function()
 state.layers={{layerWidth=4096,layerHeight=4096,tileWidth=256,tileHeight=256}}
 state.tiles={};for i=1,256 do state.tiles[i]=840000+i end
 local model,current=capture();assert(model and current()and #model.textures==256 and model.rows==16 and model.columns==16)
 state.tiles[257]=840257;assert(capture()==nil)
end)

test("Native phase and locale changes expire dynamic proof, not callback-free metadata proof",function()
 local model,current,raw=capture();assert(model and current()and raw())
 state.art=830002;assert(raw()and not current())
 state.art=830001;assert(current())
 GetLocale=function()return "zhCN"end;assert(not raw()and not current())
end)

test("Returned models own every rendering field and array",function()
 for _,mutate in ipairs({
  function(model)model.width=1 end,
  function(model)model.textures[1]=1 end,
  function(model)model.floors[1].mapID=base end,
  function(model)model.extra=true end,
  function(model)setmetatable(model.textures,{})end,
 })do setup();local model,current,raw=capture();assert(model and current());mutate(model);assert(not raw()and not current())end
end)

test("Shared GameMaps are visibly native complexes, never silently distinct wings",function()
 local list={};for i,d in ipairs(catalogue)do list[i]=d end
 list[#list+1]={key="controlled-shared",name="Controlled wing",instanceID=game};a.dungeons=list
 local model,current,raw=capture();assert(model and model.shared and current())
 list[#list].instanceID=game+1;assert(not raw())
end)

test("Caller intent is consulted only while building the detached observation",function()
 local alive,owners=true,0
 local model,current,raw=capture(nil,function()owners=owners+1;return alive end)
 assert(model and owners>0);local before=owners;alive=false
 assert(current()and raw()and owners==before)
 assert(capture(nil,function()return false end)==nil)
end)

print("Dungeon map: PASS ("..total.." controlled native contract groups; live coverage remains unverified)")
