local a={}
assert(loadfile("Core/Namespace.lua"))("DungeonPro",a)
assert(loadfile("Core/DungeonOverview.lua"))("DungeonPro",a)
-- Controlled actions are not catalogue facts; one primary root plus bounded supporting action IDs.
local function controlled(count)
 local states,actions={},{}
 for id=1,count do states[id]={id=id,status=id==count and 'READY'or'ACTIVE'};actions[id]={id=id,kind=id==count and'turnin'or'complete'}end
 local d={quests={1}};local e={State=function()error('no new State')end,Next=function()error('no new Next')end,Dungeon=function()error('no new Dungeon')end,Current=function()return true end,states=states,context={current=function()return true end},quests={},invalid=false}
 local plan={engine=e,dungeon=d,rows={{id=1,state=states[1]}},actions=actions,unknown=true,ready=false}
 return plan,d,e
end
for _,count in ipairs({8,50,1024})do
 local plan,d,e=controlled(count);local fourth=0
 local owner=function()fourth=fourth+1;return true end
 local originalCalls=0;local oldCurrent=e.Current;e.Current=function(self)originalCalls=originalCalls+1;return oldCurrent(self)end
 local default=assert(a.DungeonOverview.Get(plan,d,e,owner))
 assert(#default.steps==6 and default.remainingSteps==count-6 and fourth==1)
 local reads=originalCalls
 local expanded,current,raw=a.DungeonOverview.Get(plan,d,e,owner,count)
 assert(expanded and #expanded.steps==count and expanded.remainingSteps==0 and expanded.steps[1].id==count and expanded.shownRoots==1 and current()and raw())
 assert(originalCalls==reads+2,'constructor and explicit retained validation only call Current; no source/native/Planner scan')
 local compact=assert(a.DungeonOverview.Get(plan,d,e,nil,6));assert(#compact.steps==6)
 for _,invalid in ipairs({0,5,6.5,1025,'6',false,math.huge})do assert(a.DungeonOverview.Get(plan,d,e,nil,invalid)==nil)end
end
assert(a.DungeonOverview.Get(controlled(8)),'three argument existing call remains supported')
print('PASS controlled8/50/1024 bounds, default6/fourthowner, invalid limits failclosed, no extra producer scans')
