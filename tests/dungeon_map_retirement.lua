-- Controlled native observations exercise ownership without asserting client map coverage.
local a={};assert(loadfile("Core/Namespace.lua"))("DungeonPro",a)
assert(loadfile("Database/Catalog.lua"))("DungeonPro",a)
local catalogue=a.dungeons
local dungeon=assert(catalogue[1]);local game=assert(dungeon.instanceID)
local total,nativeCalls,effects=0,0,0
local journal,base,floor,foreign,group=910001,920001,920002,920003,930001
local state,hook,locale,ownerAlive,persistence
local function forbidden()effects=effects+1;error("map inspection cannot change native selection, guidance or UI")end
CreateFrame,OpenWorldMap,ShowUIPanel,LoadAddOn,EJ_SelectInstance,EJ_SelectTier=forbidden,forbidden,forbidden,forbidden,forbidden,forbidden
C_AddOns={LoadAddOn=forbidden};C_SuperTrack={SetSuperTrackedQuestID=forbidden,SetSuperTrackedUserWaypoint=forbidden}
local function observed(name,value)
 nativeCalls=nativeCalls+1
 if hook then hook(name)end
 return value
end
local function setup()
 a.dungeons=catalogue;locale="enUS";ownerAlive=true;hook=nil
 persistence={locale="enUS"};a.db=persistence;DungeonProDB=persistence;DungeonProCharDB=persistence
 issecretvalue=function()return false end;GetLocale=function()return locale end
 Enum={UIMapType={Dungeon=4,Micro=5,Zone=3}}
 state={game=game,joinGame=game,journal=journal,base=base,art=940001,group=group,hasArt=true,
  info={[base]={mapID=base,mapType=4,name="Controlled dungeon"},
   [floor]={mapID=floor,mapType=5,name="Controlled floor"},
   [foreign]={mapID=foreign,mapType=4,name="Unrelated map"}},
  layers={{layerWidth=513,layerHeight=257,tileWidth=256,tileHeight=256}},
  textures={950001,950002,950003,950004,950005,950006},
  members={{mapID=base,name="Controlled dungeon",relativeHeightIndex=0},
   {mapID=floor,name="Controlled floor",relativeHeightIndex=1}}}
 C_EncounterJournal={GetInstanceForGameMap=function(id)
  assert(id==state.joinGame,"join input must use GameMap identity")
  return observed("join",state.journal)
 end}
 EJ_GetInstanceInfo=function(id)
  assert(id==journal,"journal lookup must use explicit native journal identity")
  observed("journal",true)
  return "Controlled complex",nil,nil,nil,nil,nil,state.base,nil,nil,state.game
 end
 C_Map={GetMapInfo=function(id)return observed("info",state.info[id])end,
  MapHasArt=function(id)assert(state.info[id]);return observed("hasArt",state.hasArt)end,
  GetMapArtID=function(id)assert(state.info[id]);return observed("art",state.art)end,
  GetMapArtLayers=function(id)assert(state.info[id]);return observed("layers",state.layers)end,
  GetMapArtLayerTextures=function(id,index)assert(state.info[id]and index==1);return observed("textures",state.textures)end,
  GetMapGroupID=function(id)assert(state.info[id]);return observed("group",id~=foreign and state.group or nil)end,
  GetMapGroupMembersInfo=function(id)assert(id==group);return observed("members",state.members)end,
  SetUserWaypoint=forbidden,ClearUserWaypoint=forbidden,SetMapByID=forbidden}
end
setup();local before=nativeCalls
assert(loadfile("Core/DungeonMap.lua"))("DungeonPro",a)
assert(nativeCalls==before and effects==0,"loading a capability adapter must remain inert")
local function capture(request,owner)
 return a.DungeonMapSnapshot(dungeon,request,owner or function()return ownerAlive end)
end
local function test(name,fn)
 setup();fn();assert(effects==0)
 assert(a.db==persistence and DungeonProDB==persistence and DungeonProCharDB==persistence and persistence.locale=="enUS")
 for key in pairs(persistence)do assert(key=="locale","map inspection never persists native observations")end
 total=total+1;print("PASS "..name)
end

test("Disjoint native namespaces preserve the exact selected catalogue GameMap",function()
 local model,current,raw=capture()
 assert(model and current()and raw())
 assert(model.gameMapID==game and model.journalID==journal and model.baseMapID==base and model.mapID==base)
 assert(model.width==513 and model.height==257 and model.columns==3 and model.rows==2 and #model.textures==6)
 assert(model.textures[6]==950006 and #model.floors==2)
end)

test("The seventh UiMap cannot substitute for the tenth GameMap self-check",function()
 state.game=base;assert(capture()==nil)
 setup();state.base=game;assert(capture()==nil)
 setup();state.base=journal;assert(capture()==nil)
end)

test("An overworld base or a matching name outside the exact floor group is unavailable",function()
 local model,current,raw=capture(floor);assert(model and model.mapID==floor and model.baseMapID==base and current()and raw())
 state.info[base].mapType=3;assert(capture()==nil)
 setup();state.info[foreign].name=state.info[base].name;assert(capture(foreign)==nil)
 setup();state.members[2].mapID=foreign;assert(capture(floor)==nil)
end)

test("Missing optional floor providers authorize only the verified base",function()
 C_Map.GetMapGroupID=nil;C_Map.GetMapGroupMembersInfo=nil
 local model=assert(capture());assert(model.mapID==base and #model.floors<=1)
 if #model.floors==1 then assert(model.floors[1].mapID==base)end
 assert(capture(floor)==nil)
end)

test("Malformed advertised floor identities cannot fall back to a different map",function()
 state.members[2].mapID=base;assert(capture()==nil)
 setup();state.members[2].mapID="920002";assert(capture()==nil)
 setup();state.group=0;assert(capture(floor)==nil)
end)

test("Malformed native art dimensions and restricted identities never authorize arithmetic",function()
 for _,value in ipairs({0,-1,1.5,"513",math.huge,false})do
  setup();state.layers[1].layerWidth=value;assert(capture()==nil)
 end
 setup();state.layers[1].layerWidth=0/0;assert(capture()==nil)
 setup();state.layers[1].layerWidth=65537;state.layers[1].layerHeight=65537;assert(capture()==nil,"more than256 tiles is unavailable")
 setup();state.textures[6]=0;assert(capture()==nil)
 setup();state.textures[7]=950007;assert(capture()==nil,"extra advertised tiles cannot be silently cropped")
 setup();state.textures[6]=nil;assert(capture()==nil,"missing art tiles cannot be invented")
 setup();issecretvalue=function(value)return value==950006 end;assert(capture()==nil)
 setup();issecretvalue=function(value)return value==base end;assert(capture()==nil)
end)

test("Retained native proof expires across map-art and floor membership phase changes",function()
 for _,mutate in ipairs({
  function()state.art=state.art+1 end,
  function()state.game=game+1 end,
  function()state.base=foreign end,
  function()state.info[base].mapType=3 end,
  function()state.hasArt=false end,
  function()state.layers[1].layerWidth=514 end,
  function()state.textures[6]=950099 end,
  function()state.members[2].relativeHeightIndex=2 end,
 })do
  setup();local model,current=capture();assert(model and current());mutate();assert(not current())
 end
end)

test("Raw proof owns every exposed rendering array and field without calling providers",function()
 for _,mutate in ipairs({
  function(m)m.mapID=foreign end,function(m)m.artID=m.artID+1 end,
  function(m)m.width=m.width+1 end,function(m)m.layerIndex=2 end,
  function(m)m.shared=not m.shared end,function(m)m.columns=m.columns+1 end,
  function(m)m.textures[1]=950099 end,function(m)m.textures={unpack(m.textures)}end,
  function(m)m.floors[1].name="Replacement floor"end,
  function(m)m.floors[1]={mapID=base,name="Controlled dungeon",relativeHeightIndex=0}end,
  function(m)m.floors={unpack(m.floors)}end,
  function(m)setmetatable(m,{__index=function()return "Injected caption"end})end,
 })do
  setup();local model,current,raw=capture();assert(model and raw());local reads=nativeCalls
  mutate(model);assert(not raw()and nativeCalls==reads,"model mutation must retire without native reads")
 end
end)

test("Provider replacement and catalogue identity retire the callback-free proof",function()
 for _,mutate in ipairs({
  function()C_Map.GetMapInfo=function()error("retired provider must not run")end end,
  function()C_Map={}end,
  function()C_EncounterJournal.GetInstanceForGameMap=function()error("retired join must not run")end end,
  function()EJ_GetInstanceInfo=function()error("retired journal must not run")end end,
  function()a.dungeons={}end,
 })do
  setup();local model,current,raw=capture();assert(model and raw());local reads=nativeCalls
  mutate();assert(not raw()and nativeCalls==reads)
 end
end)

test("Retained proofs never call the initial caller owner",function()
 local ownerCalls=0
 local model,current,raw=capture(nil,function()ownerCalls=ownerCalls+1;return ownerAlive end)
 assert(model and ownerCalls>0);local count=ownerCalls;ownerAlive=false
 assert(current()and raw()and ownerCalls==count,"caller intent is composed outside retained native proof")
end)

test("Shared complex presentation retires if catalogue membership changes",function()
 local list={};for i,d in ipairs(catalogue)do list[i]=d end;a.dungeons=list
 local model,current,raw=capture();assert(model and current()and raw())
 list[#list+1]={key="controlled-shared-definition",instanceID=game,name="Controlled wing"}
 assert(not raw()and not current(),"shared-map cue cannot keep a stale single-dungeon interpretation")
end)

test("Initial owner reentry cannot publish a stale catalogue or helper snapshot",function()
 local fired=false;local reads=nativeCalls
 assert(capture(nil,function()
  if nativeCalls>reads and not fired then fired=true;a.dungeons={}end
  return true
 end)==nil and fired)
 setup();fired=false
 hook=function(name)if name=="textures"and not fired then fired=true;ownerAlive=false end end
 assert(capture()==nil and fired)
end)

test("A native getter cannot mutate exposed model ownership during a freshness proof",function()
 local model,current,raw=capture();assert(model and current())
 local fired=false
 hook=function(name)if name=="textures"and not fired then fired=true;model.textures[1]=950099 end end
 assert(not current()and fired and not raw())
end)

test("Callback-bearing initial sanitization cannot rebind the caller's catalogue GameMap",function()
 local clean=a.Clean;local fired=false
 a.Clean=function(value,kind)
  if value==dungeon and kind=="table"and not fired then
   fired=true;dungeon.instanceID=game+1;state.game=game+1;state.joinGame=game+1
  end
  return clean(value,kind)
 end
 local model=capture();a.Clean=clean;dungeon.instanceID=game
 assert(fired and model==nil,"a different GameMap captured during initial sanitization is not the caller's map request")
 setup();fired=false
 local other=assert(catalogue[2]);local original=other.instanceID
 a.Clean=function(value,kind)
  if value==dungeon and kind=="table"and not fired then fired=true;other.instanceID=game end
  return clean(value,kind)
 end
 model=capture();a.Clean=clean;other.instanceID=original
 assert(fired and model==nil,"shared-complex membership also belongs to the original catalogue request")
end)

assert(effects==0)
print("Dungeon map retirement: PASS ("..total.." independent controlled ownership groups; native coverage unproven)")
