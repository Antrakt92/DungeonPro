-- Static search relationships do not invoke quest state, native hydration or actions.
local a={};assert(loadfile("Core/Namespace.lua"))("DungeonPro",a)
assert(loadfile("Database/Catalog.lua"))("DungeonPro",a)
local definitions,catalogue=a.quests,a.dungeons
local effects=0
local function forbidden()effects=effects+1;error("static relationships have no client or planner effects")end
a.Context,a.Planner,a.QuestTree=forbidden,{New=forbidden},{Build=forbidden}
C_QuestLog={RequestLoadQuestByID=forbidden,GetQuestObjectives=forbidden};CreateFrame,OpenWorldMap=forbidden,forbidden
issecretvalue=function()return false end
assert(loadfile("Core/SearchRelations.lua"))("DungeonPro",a)
local function owner(key)for _,d in ipairs(catalogue)do if d.key==key then return d end end;error(key)end
local total=0
local function test(name,fn)
 a.quests,a.dungeons=definitions,catalogue;fn();assert(effects==0);total=total+1;print("PASS "..name)
end
local function ids(model)
 local found={};for _,node in ipairs(model.nodes)do
  assert(node.rootTargetID==model.rootTargetID and node.relation=="related"and not found[node.questID])
  found[node.questID]=true
 end;assert(not found[model.rootTargetID]);return found
end
local function expect(model,wanted)
 assert(model);local found=ids(model)
 for _,id in ipairs(wanted)do assert(found[id],"missing related quest "..id);found[id]=nil end
 assert(next(found)==nil,"no unrelated quests")
end
local function controlled()
 local q={};for id=1,9 do q[id]={id=id,name="Controlled quest "..id}end
 q[1].requires={{ids={2,3},mode="active"}};q[2].requires={{ids={4}}}
 q[1].storyline={1,5,6};q[5].requires={{ids={7}}};q[2].storyline={8};q[5].storyline={9}
 local d={key="controlled",name="Controlled dungeon",quests={1}};a.quests,a.dungeons=q,{d}
 return q,d
end

test("Actual ZF, Temple and Wailing Caverns expose only their recorded related steps",function()
 for _,case in ipairs({{"zf",2991,{2988,2989,2990,2992,2993,2994}},
  {"st",1475,{1452,1469}},{"wc",914,{870,877,880,1489,1490}}})do
  local d=owner(case[1]);local roots=d.quests;local model,current,raw=a.QuestSearchRelations(d,case[2])
  expect(model,case[3]);assert(current()and raw()and d.quests==roots)
 end
end)

test("OR members and optional story ancestors are generic related nodes without nested story inheritance",function()
 local q,d=controlled();local model,current,raw=a.QuestSearchRelations(d,1)
 expect(model,{2,3,4,5,6,7});assert(current()and raw())
 q[2].storyline={9};assert(current()and raw(),"unconsulted child story is not a relationship")
end)

test("Missing referenced definitions stay negatively owned without hiding other known steps",function()
 local q,d=controlled();q[3]=nil
 local model,current,raw=a.QuestSearchRelations(d,1);expect(model,{2,4,5,6,7});assert(current()and raw())
 q[3]={id=3,name="Arrived definition"};assert(not raw()and not current())
end)

test("Root membership and exact definition identity are required",function()
 local q,d=controlled();assert(a.QuestSearchRelations(d,2)==nil)
 local model,current,raw=a.QuestSearchRelations(d,1);assert(model and current())
 d.quests[1]=2;assert(not raw())
 controlled();d={key="foreign",quests={1}};assert(a.QuestSearchRelations(d,1)==nil)
 q,d=controlled();q[2].id=3;assert(a.QuestSearchRelations(d,1)==nil)
end)

test("Absent story and prerequisite arrays are retained negative source facts",function()
 local q,d=controlled();q[1].storyline=nil;q[3].requires=nil
 local model,current,raw=a.QuestSearchRelations(d,1);expect(model,{2,3,4});assert(current())
 q[3].requires={};assert(not raw())
 q,d=controlled();q[1].storyline=nil;model,current,raw=a.QuestSearchRelations(d,1)
 q[1].storylineGroups={};assert(not raw())
end)

test("Readable malformed and cyclic graphs expose no partial results but retain negative proofs",function()
 for _,mutate in ipairs({function(q)q[4].requires={{ids={1}}}end,
  function(q)q[1].storylineGroups={}end,function(q)q[1].requires[1].mode="invented"end,
  function(q)q[2].name=" "end,function(q)q[1].requires[1].ids={}end})do
  local q,d=controlled();mutate(q);local model,current,raw=a.QuestSearchRelations(d,1)
  assert(model==nil and current and raw and current()and raw(),"unchanged readable invalid graph has a negative proof")
  q[1].requires={};assert(not raw())
 end
end)

test("Node, edge and depth limits never publish partial relationships",function()
 local function base()
  local q={[1]={id=1,name="Root"}};local d={key="bounded",quests={1}};a.quests,a.dungeons=q,{d};return q,d
 end
 local q,d=base();q[1].requires={{ids={}}}
 for i=2,80 do q[i]={id=i,name="Related"};q[1].requires[1].ids[#q[1].requires[1].ids+1]=i end
 local model,current,raw=a.QuestSearchRelations(d,1);assert(model and #model.nodes==79 and current()and raw())
 q[81]={id=81,name="Related"};q[1].requires[1].ids[80]=81
 assert(a.QuestSearchRelations(d,1)==nil)
 q,d=base();for i=1,51 do q[i]={id=i,name="Chain",requires=i<51 and {{ids={i+1}}}or nil}end
 model,current,raw=a.QuestSearchRelations(d,1);assert(model and #model.nodes==50 and current()and raw())
 q[52]={id=52,name="Beyond depth"};q[51].requires={{ids={52}}}
 assert(a.QuestSearchRelations(d,1)==nil)
 q,d=base();q[2]={id=2,name="Related"};q[1].requires={}
 for g=1,4 do local group={ids={}};q[1].requires[g]=group;for i=1,(g==4 and 20 or 100)do group.ids[i]=2 end end
 model,current,raw=a.QuestSearchRelations(d,1);assert(model and #model.nodes==1 and current()and raw())
 q[1].requires[4].ids[21]=2
 assert(a.QuestSearchRelations(d,1)==nil)
end)

test("Trimming an oversized or sparse oversized array invalidates its negative proof",function()
 for _,sparse in ipairs({false,true})do
  local q,d=controlled();local list={2};q[1].requires[1].ids=list
  if sparse then for i=1000,1100 do list[i]=2 end else for i=2,102 do list[i]=2 end end
  local model,current,raw=a.QuestSearchRelations(d,1)
  assert(model==nil and current and raw and current()and raw())
  for key in pairs(list)do if key~=1 then list[key]=nil end end
  assert(not raw()and not current(),"same-object overflow becoming valid must retire negative search evidence")
  model,current,raw=a.QuestSearchRelations(d,1);assert(model and current()and raw())
 end
end)

test("Raw proof owns detached DTOs and calls no sanitizer, checker or caller",function()
 local q,d=controlled();local calls=0
 local checker=issecretvalue;local checked=0;issecretvalue=function()checked=checked+1;return false end
 local model,current,raw=a.QuestSearchRelations(d,1,function()calls=calls+1;return true end)
 assert(model and calls>0);local before=calls;assert(current()and raw()and calls==before)
 local beforeCheck=checked;assert(raw()and checked==beforeCheck,"valid raw proof must invoke no restriction checker")
 local clean=a.Clean;local cleanCalls=0;a.Clean=function(...)cleanCalls=cleanCalls+1;return clean(...)end
 assert(not raw()and cleanCalls==0);a.Clean=clean
 assert(raw());model.nodes[1].relation="required";assert(not raw())
 issecretvalue=checker
end)

test("Support title and helper replacements retire retained results",function()
 local q,d=controlled();local model,current,raw=a.QuestSearchRelations(d,1);assert(model and current())
 q[2].name="New caption";assert(not raw()and not current())
 q,d=controlled();model,current,raw=a.QuestSearchRelations(d,1);local helper=a.QuestSearchRelations
 a.QuestSearchRelations=function()end;assert(not raw());a.QuestSearchRelations=helper
end)

test("Cleaner and caller reentry cannot publish captured old graph facts",function()
 local q,d=controlled();local clean=a.Clean;local fired=false
 a.Clean=function(value,kind)
  if value==q[2]and kind=="table"and not fired then fired=true;q[2].name="Changed during cleaning"end
  return clean(value,kind)
 end
 local model=a.QuestSearchRelations(d,1);a.Clean=clean;assert(fired and model==nil)
 q,d=controlled();fired=false
 model=a.QuestSearchRelations(d,1,function()if not fired then fired=true;q[2].requires={}end;return true end)
 assert(fired and model==nil)
end)

test("Missing or failing validation helpers fail closed without throwing",function()
 local clean,read=a.Clean,a.Read
 for _,key in ipairs({"Clean","Read"})do
  for _,replacement in ipairs({false,function()error("unavailable validation")end})do
   local q,d=controlled();a[key]=replacement
   local ok,model=pcall(a.QuestSearchRelations,d,1);a.Clean,a.Read=clean,read
   assert(ok and model==nil)
  end
  local q,d=controlled();a[key]=nil
  local ok,model=pcall(a.QuestSearchRelations,d,1);a.Clean,a.Read=clean,read
  assert(ok and model==nil)
 end
 local q,d=controlled();local failing=false
 a.Read=function(...)if failing then error("retained read failure")end;return read(...)end
 local model,current,raw=a.QuestSearchRelations(d,1);assert(model and current())
 failing=true;assert(raw()and not current());a.Read=read
end)

print("Search relations: PASS "..total.." static graph groups; no eligibility or target membership changes")
