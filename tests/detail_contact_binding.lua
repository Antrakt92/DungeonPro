-- Direct informational contact bindings never infer a turn-in action.
local function fixture()
 local a={}
 issecretvalue=function()return false end
 GetLocale=function()error("contact source must not read locale")end
 assert(loadfile("Core/Namespace.lua"))("DungeonPro",a)
 assert(loadfile("UI/QuestNavigation.lua"))("DungeonPro",a)
 local u=a.QuestNavigation;a.UI=u
 assert(type(u.DetailContactBinding)=="function","new contact binding helper missing")
 local q={id=994001,name="Selected contact",
  start={npcID=101,name="Pickup",mapID=1453,x=10,y=20,reportedLocations={{mapID=1453,x=10,y=20},{mapID=1453,x=11,y=21}}},
  finish={objectID=102,name="Finish",mapID=1455,x=30,y=40}}
 local other={id=994002,name="Other",start={npcID=201,name="Other giver",mapID=1453,x=12,y=22}}
 a.quests={[q.id]=q,[other.id]=other};a.char={selectedDungeon="example"}
 u.frame={IsShown=function()return true end};u.quest=q.id;u.dungeon={key="example"};u.engine={quests=a.quests,context={}}
 function u.engine:Current()return true end
 u.rewardGeneration={};u.detailNavigationRevision={};u.detailTabRevision={};u.layoutRevision={};u.sourceControlsLease={}
 u.questTreeRoot=other.id
 local calls={}
 a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={point=action.place,action=action,purpose=purpose};return true end,
 Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}
 u.DispatchDetail=function()error("shared Dispatcher must never run")end
 return a,u,q,other,calls
end
local function bind(u,q,field,owner)return assert(u:DetailContactBinding(q,field,owner or function()return true end))end
do
 local a,u,q,other,calls=fixture();local selected=u.quest;local root=u.questTreeRoot
 local s,f=bind(u,q,"start"),bind(u,q,"finish")
 assert(s.endpoint==q.start and f.endpoint==q.finish and s.action.kind=="visit"and f.action.kind=="visit")
 assert(s.purpose=="quest-start"and f.purpose==nil and not s.mapOnly and not f.mapOnly)
 assert(s.dispatch()and calls[#calls].point==q.start and calls[#calls].purpose=="quest-start")
 assert(f.dispatch()and calls[#calls].point==q.finish and calls[#calls].purpose==nil)
 assert(u.quest==selected and u.questTreeRoot==root,"informational contacts preserve selectednode/root")
 assert(u:DetailContactBinding(other,"start",function()return true end)==nil,"selecteddefinition only")
 local foreign={id=q.id,name=q.name,start=q.start,finish=q.finish}
 assert(u:DetailContactBinding(foreign,"start",function()return true end)==nil,"lookalike not canonical")
end
for _,mode in ipairs({"maponly","unknownmap","item","drop","summon","alternatives","missing"})do
 local a,u,q,other,calls=fixture()
 if mode=="maponly"then q.start.x,q.start.y=nil,nil
 elseif mode=="unknownmap"then q.start.mapID,q.start.x,q.start.y=nil,nil,nil
 elseif mode=="item"then q.start={itemID=301,name="Starter item"}
 elseif mode=="drop"then q.start.dropNPCID=101
 elseif mode=="summon"then q.start.summonItem={itemID=302}
 elseif mode=="alternatives"then q.start=nil;q.startAlternatives={{npcID=303,name="Alternative",mapID=1453,x=15,y=25}}
 elseif mode=="missing"then q.start=nil end
 local b=bind(u,q,"start")
 if mode=="maponly"then assert(b.mapOnly and b.action and b.dispatch()and calls[1].point==q.start and calls[1].id==q.id)
 else assert(not b.action and not b.dispatch()and #calls==0,"read-only "..mode)end
 if mode=="alternatives"or mode=="missing"then assert(b.endpoint==nil,"missing start must not borrow finish")end
end
for _,mode in ipairs({"mixed","badmap","badx","partialxy","sparse","oversized","nested","badID","malformed"})do
 local a,u,q=fixture()
 if mode=="mixed"then q.start.objectID=1
 elseif mode=="badmap"then q.start.mapID=false
 elseif mode=="badx"then q.start.x=0/0
 elseif mode=="partialxy"then q.start.y=nil
 elseif mode=="sparse"then q.start.reportedLocations={[2]={mapID=1453,x=1,y=2}}
 elseif mode=="oversized"then for i=1,101 do q.start.reportedLocations[i]={mapID=1453,x=i%100,y=2}end
 elseif mode=="nested"then q.start.reportedLocations[1].reportedLocations={}
 elseif mode=="badID"then q.start.npcID=4294967296
 elseif mode=="malformed"then q.start.reportedLocations[1].x="bad"end
 local ok,result=pcall(u.DetailContactBinding,u,q,"start",function()return true end)
 assert(ok and result==nil,"malformed source rejected "..mode)
end
do
 local a,u,q=fixture();local secret={};issecretvalue=function(v)return rawequal(v,secret)end
 q.start.x=secret
 assert(u:DetailContactBinding(q,"start",function()return true end)==nil,"restricted presentfield")
end
for _,mode in ipairs({"source","definition","selection","character","frame","engine","helper","clean","read","checker","nav","reportMember","reportField","reportSparse","alternate"})do
 local a,u,q,other,calls=fixture();q.startAlternatives={{npcID=401,name="Alternative",mapID=1453,x=1,y=2}}
 local b=bind(u,q,"start")
 if mode=="source"then q.start={}
 elseif mode=="definition"then a.quests[q.id]={id=q.id,start=q.start}
 elseif mode=="selection"then u.quest=other.id
 elseif mode=="character"then a.char={}
 elseif mode=="frame"then u.frame={}
 elseif mode=="engine"then u.engine={}
 elseif mode=="helper"then u.DetailContactBinding=function()end
 elseif mode=="clean"then a.Clean=function()error("changed clean ran")end
 elseif mode=="read"then a.Read=function()error("changed read ran")end
 elseif mode=="checker"then issecretvalue=function()return false end
 elseif mode=="nav"then a.Navigation.Start=function()error("changed nav ran")end
 elseif mode=="reportMember"then q.start.reportedLocations[1]={mapID=1453,x=10,y=20}
 elseif mode=="reportField"then q.start.reportedLocations[1].x=33
 elseif mode=="reportSparse"then q.start.reportedLocations[42]={mapID=1453,x=1,y=2}
 elseif mode=="alternate"then q.startAlternatives[1].npcID=402 end
 assert(not b.rawCurrent()and not b.current()and not b.dispatch()and #calls==0,"stale "..mode)
end
for _,mode in ipairs({"actionID","actionKind","actionPlace","endpoint","purpose","current","raw","dispatch"})do
 local a,u,q,other,calls=fixture();local b=bind(u,q,"start");local retained=b.dispatch
 if mode=="actionID"then b.action.id=other.id
 elseif mode=="actionKind"then b.action.kind="turnin"
 elseif mode=="actionPlace"then b.action.place=q.finish
 elseif mode=="endpoint"then b.endpoint=q.finish
 elseif mode=="purpose"then b.purpose="quest-turnin"
 elseif mode=="current"then b.current=function()return true end
 elseif mode=="raw"then b.rawCurrent=function()return true end
 elseif mode=="dispatch"then b.dispatch=function()return true end end
 assert(not retained()and #calls==0,"model tampering cannot redirect "..mode)
end
for _,stage in ipairs({"initial","retained"})do
 for _,producer in ipairs({"owner","engine","shown"})do
  for _,slot in ipairs({"Clean","Read","nav"})do
   if not(stage=="initial"and producer=="shown")then
    local a,u,q,other,calls=fixture();local armed=stage=="initial";local changedCalls=0
    local function callback()
     if armed then armed=false
      if slot=="nav"then a.Navigation.Start=function()changedCalls=changedCalls+1;error("changed navigation ran")end
      else a[slot]=function()changedCalls=changedCalls+1;error("changed helper ran")end end
     end
     return true
    end
    local owner=function()return true end
    if producer=="owner"then owner=callback elseif producer=="engine"then u.engine.Current=callback else u.frame.IsShown=callback end
    local ok,b=pcall(u.DetailContactBinding,u,q,"start",owner)
    if stage=="initial"then assert(ok and b==nil and changedCalls==0,"initial callback guard "..producer..slot)
    else assert(ok and b);armed=true;local ok,result=pcall(b.dispatch);assert(ok and result==false and changedCalls==0 and #calls==0,"retained callback guard "..producer..slot)end
   end
  end
 end
end
for _,producer in ipairs({"clean","owner","engine"})do
 local a,u,q,other,calls=fixture();local clean=a.Clean;local armed=true
 local function mutate()if armed then armed=false;q.start={npcID=999,mapID=1453,x=99,y=99}end;return true end
 local owner=function()return true end
 if producer=="clean"then a.Clean=function(v,k)mutate();return clean(v,k)end
 elseif producer=="owner"then owner=mutate else u.engine.Current=mutate end
 local ok,result=pcall(u.DetailContactBinding,u,q,"start",owner)
 assert(ok and result==nil and #calls==0,"first callback source snapshot "..producer)
end
do
 local a,u,q,other,calls=fixture();local b=bind(u,q,"finish")
 u.frame.IsShown=function()return false end;assert(not b.dispatch()and #calls==0,"changed visibility capability rejected")
end
print("PASS contact primitive: direct typed starts/neutral finish, selected canonical source, map-only/unknown/item/drop/summon/alternatives, malformed/restricted arrays, source/context/helper/model retirement, owner/engine/shown callback guards; no Dispatcher/locale/window mutation")

for _,field in ipairs({"start","finish"})do
 local opposite=field=="start"and"finish"or"start"
 for _,mode in ipairs({"malformed","restricted","sparse"})do
  local a,u,q,other,calls=fixture()
  local secret={}
  issecretvalue=function(v)return rawequal(v,secret)end
  if mode=="malformed"then q[opposite]={npcID="bad",objectID=44}
  elseif mode=="restricted"then q[opposite]={npcID=secret}
  else q[opposite.."Alternatives"]={[99]={npcID=45}}end
  local b=bind(u,q,field)
  assert(b.dispatch(),"opposite invalid must not disable "..field..mode)
  q[opposite]={npcID="changed"}
  q[opposite.."Alternatives"]={[0]=secret}
  assert(b.current()and b.dispatch(),"opposite mutation must not retire "..field)
 end
end
do
 local a,u,q=fixture();local lookups=0
 u.frame=setmetatable({},{__index=function(_,key)if key=="IsShown"then lookups=lookups+1;return function()return true end end end})
 -- Stable inherited capability, raw proof must not resolve it.
 local shown=function()return true end
 getmetatable(u.frame).__index=function(_,key)if key=="IsShown"then lookups=lookups+1;return shown end end
 local b=bind(u,q,"start");lookups=0
 assert(b.rawCurrent()and lookups==0,"raw proof invokes no inherited getter")
end
do
 local a,u,q=fixture();local secret={}
 a.Navigation.Start=function()return secret end
 local b=bind(u,q,"start");issecretvalue=function(v)return rawequal(v,secret)end
 assert(not b.dispatch(),"changed checker retires before secret Nav return")
end
print("PASS independent contacts and callback-free inherited getter raw proof")

for _,field in ipairs({"start","finish"})do
 for _,mode in ipairs({"maponly-without-Map","coordinates-without-Start"})do
  local a,u,q,other,calls=fixture()
  if mode=="maponly-without-Map"then q[field].x=nil;q[field].y=nil;a.Navigation.Map=nil
  else a.Navigation.Start=nil end
  local b=bind(u,q,field)
  assert(b.endpoint==q[field]and b.action==nil and b.purpose==nil and b.reason=="NAVIGATION_UNAVAILABLE","missing selectedmethod must be readonly "..field..mode)
  assert(b.current()and b.dispatch()==false and #calls==0,"readonly absent capability must never dispatch")
 end
end
do
 local a,u,q,other,calls=fixture();q.start.x=nil;q.start.y=nil;a.Navigation.Start=nil
 local s,f=bind(u,q,"start"),bind(u,q,"finish")
 assert(s.action and s.dispatch()and calls[#calls].point==q.start,"available Map must stay usable")
 assert(not f.action and not f.dispatch(),"unavailable Start affects only coordinate contact")
end
print("PASS captured Map/Start capability gates action; readonly missing method bothfields; available othermethod independent")

