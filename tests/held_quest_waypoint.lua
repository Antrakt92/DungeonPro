local total, addon, f = 0, nil, nil
local secret = {}
local modulePath = "Core/HeldQuestWaypoint.lua"
local function setup()
 f={held=true,index=7,map=1426,x=.25,y=.75,text="Current client route",locale="enUS",positionReads=0}
 addon={quests={[1654]={id=1654}},char={}}
 issecretvalue=function(value)return value==secret end
 GetLocale=function()return f.locale end
 C_QuestLog={IsOnQuest=function(id)assert(id==1654);return f.held end,GetLogIndexForQuestID=function(id)assert(id==1654);return f.index end,
 GetNextWaypoint=function(id)assert(id==1654);return f.map,secret,secret end,
 GetNextWaypointForMap=function(id,map)assert(id==1654 and map==f.map);f.positionReads=f.positionReads+1;return f.x,f.y end,
 GetNextWaypointText=function(id)assert(id==1654);return f.text end}
 C_Map={GetMapInfo=function(map)assert(map==f.map);return{mapID=map,name="Current UI map",mapType=4}end}
 local function forbidden()error("No request/selection/navigation side effects")end
 C_QuestLog.GetSelectedQuest=forbidden;C_QuestLog.SetSelectedQuest=forbidden;C_QuestLog.RequestLoadQuestByID=forbidden
 C_Map.OpenWorldMap=forbidden;C_Map.SetUserWaypoint=forbidden
 C_SuperTrack={SetSuperTrackedQuestID=forbidden};C_Timer={After=forbidden};GetMoney=forbidden
 assert(loadfile(modulePath))("DungeonPro",addon)
end
local function check(name,fn)setup();local ok,err=pcall(fn);assert(ok,name..": "..tostring(err));total=total+1;print("PASS "..name)end
check("Explicit known held quest returns only detached normalized client route data",function()
 local dto=assert(addon.HeldQuestWaypoint(1654));assert(dto.source=="clientWaypoint"and dto.questID==1654 and dto.uiMapID==1426 and dto.normalizedX==.25 and dto.normalizedY==.75 and dto.text==f.text)
 assert(dto.npcID==nil and dto.itemID==nil and dto.place==nil and dto.mapID==nil)
 dto.normalizedX=99;assert(addon.HeldQuestWaypoint(1654).normalizedX==.25 and f.positionReads==2)
end)
check("ForMap coordinates alone define units and preserve exact normalized boundaries",function()
 for _,xy in ipairs({{0,1},{1,0},{.01,.99}})do f.x,f.y=xy[1],xy[2];local dto=assert(addon.HeldQuestWaypoint(1654));assert(dto.normalizedX==xy[1]and dto.normalizedY==xy[2])end
 C_QuestLog.GetNextWaypointForMap=nil;assert(addon.HeldQuestWaypoint(1654)==nil)
end)
check("Map identity uses mapInfo mapID not uiMapID name or guessed map aliases",function()
 for _,info in ipairs({{uiMapID=1426,name="Fake"},{mapID=7},{mapID=1426.5},{mapID=secret},{name="Current UI map"}})do C_Map.GetMapInfo=function()return info end;assert(addon.HeldQuestWaypoint(1654)==nil)end
end)
check("Invalid map identity coordinates and native cold results remain unknown",function()
 for _,value in ipairs({0,-1,1.5,math.huge,0/0,9007199254740992,secret,false,"1426"})do setup();f.map=value;assert(addon.HeldQuestWaypoint(1654)==nil)end
 for _,value in ipairs({-0.001,1.001,math.huge,0/0,secret,false,".5"})do
  for _,axis in ipairs({"x","y"})do setup();f[axis]=value;assert(addon.HeldQuestWaypoint(1654)==nil)end
 end
 setup();f.map=nil;assert(addon.HeldQuestWaypoint(1654)==nil and f.positionReads==0)
 setup();f.y=nil;assert(addon.HeldQuestWaypoint(1654)==nil)
end)
check("Unheld unknown index and preDB or unknown catalogue never authorize waypoint reads",function()
 for _,mode in ipairs({"held","index","character","definition","id"})do
  setup();if mode=="held"then f.held=false elseif mode=="index"then f.index=0 elseif mode=="character"then addon.char=nil elseif mode=="definition"then addon.quests[1654]=nil else addon.quests[1654].id=1655 end
  assert(addon.HeldQuestWaypoint(1654)==nil and f.positionReads==0)
 end
end)
check("Missing malformed or throwing mandatory APIs stay optional",function()
 for _,key in ipairs({"IsOnQuest","GetLogIndexForQuestID","GetNextWaypoint","GetNextWaypointForMap"})do
  for _,bad in ipairs({false,12,function()error("unavailable")end})do setup();C_QuestLog[key]=bad;assert(addon.HeldQuestWaypoint(1654)==nil)end
 end
 for _,bad in ipairs({false,secret,17})do setup();C_QuestLog=bad;assert(addon.HeldQuestWaypoint(1654)==nil)end
 setup();C_Map.GetMapInfo=function()error("cold map")end;assert(addon.HeldQuestWaypoint(1654)==nil)
end)
check("Optional missing restricted blank or throwing text does not discard a known route",function()
 for _,value in ipairs({secret,false,"", " ",string.rep("x",1025)})do setup();f.text=value;local dto=assert(addon.HeldQuestWaypoint(1654));assert(dto.text==nil)end
 setup();C_QuestLog.GetNextWaypointText=nil;assert(addon.HeldQuestWaypoint(1654).text==nil)
 setup();C_QuestLog.GetNextWaypointText=function()error("cold text")end;assert(addon.HeldQuestWaypoint(1654).text==nil)
end)
check("Dependent reads cannot mix new character definitions map route or native capabilities",function()
 for _,mode in ipairs({"char","catalog","definition","map","questNS","mapNS","positionGetter","textGetter","checker","locale"})do
  setup();local get=C_QuestLog.GetNextWaypointForMap
  C_QuestLog.GetNextWaypointForMap=function(...)
   local x,y=get(...)
   if mode=="char"then addon.char={}elseif mode=="catalog"then addon.quests={[1654]=addon.quests[1654]}elseif mode=="definition"then addon.quests[1654]={id=1654}
   elseif mode=="map"then f.map=1427 elseif mode=="questNS"then local n={};for k,v in pairs(C_QuestLog)do n[k]=v end;C_QuestLog=n
   elseif mode=="mapNS"then C_Map={GetMapInfo=C_Map.GetMapInfo}elseif mode=="positionGetter"then C_QuestLog.GetNextWaypointForMap=get
   elseif mode=="textGetter"then C_QuestLog.GetNextWaypointText=nil elseif mode=="checker"then issecretvalue=function()return false end else f.locale="ruRU"end
   return x,y
  end
  assert(addon.HeldQuestWaypoint(1654)==nil,mode)
 end
end)
check("Final index and locale reads cannot publish after held evidence is lost",function()
 for _,mode in ipairs({"index","locale"})do
  setup();local original=mode=="index"and C_QuestLog.GetLogIndexForQuestID or GetLocale;local n=0
  local function getter(...)
   local value=original(...)
   if f.positionReads>0 then n=n+1;if n==4 then f.held=false end end
   return value
  end
  if mode=="index"then C_QuestLog.GetLogIndexForQuestID=getter else GetLocale=getter end
  assert(addon.HeldQuestWaypoint(1654)==nil,mode)
 end
end)
check("Owner callback and final sanitizer cannot replace source or map identity",function()
 assert(addon.HeldQuestWaypoint(1654,function()return false end)==nil)
 setup();local info={mapID=1426};C_Map.GetMapInfo=function()return info end
 local cleaner=issecretvalue;issecretvalue=function(value)if f.positionReads>0 and value==1426 then info.mapID=1427 end;return cleaner(value)end
 assert(addon.HeldQuestWaypoint(1654)==nil)
 setup();assert(addon.HeldQuestWaypoint(1654,function()if f.positionReads>0 then addon.char={}end;return true end)==nil)
end)
check("A final locale read cannot publish after caller ownership expires",function()
 local nextGetter=C_QuestLog.GetNextWaypoint;local reads,lateLocale,live=0,0,true
 C_QuestLog.GetNextWaypoint=function(...)reads=reads+1;return nextGetter(...)end
 GetLocale=function()
  if reads==2 then lateLocale=lateLocale+1;if lateLocale==2 then live=false end end
  return "enUS"
 end
 local dto=addon.HeldQuestWaypoint(1654,function()return live end)
 assert(reads==2 and lateLocale==2 and live==false)
 assert(dto==nil,"final locale callback expired caller after earlier check")
end)
print("Held quest waypoint modeled checks passed: "..total.."; no native-game validation")
