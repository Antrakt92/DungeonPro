-- Reviewed object/NPC names have separate typed identities and selected-locale ownership.
local a={};assert(loadfile("Core/Namespace.lua"))("DungeonPro",a)
assert(loadfile("Core/Client.lua"))("DungeonPro",a)
local total=0
local function setup()
 issecretvalue=function()return false end;GetLocale=function()return"enUS"end
 a.db,a.Language={locale="ruRU"},nil
 a.nameTranslations={ruRU={quests={},dungeons={},objects={
  [142702]={source="Venom Bottle",name="Флакон с ядом"}},npcs={
  [142702]={source="Different creature",name="Другое существо"},
  [2216]={source="Apothecary Lydon",name="Аптекарь Лидон"}}}}
 a.nameTranslationFactories=nil
 C_QuestLog={RequestLoadQuestByID=function()error("source names must not request native quest data")end}
 C_Item={RequestLoadItemDataByID=function()error("source names must not request native item data")end}
end
local function test(name,fn)setup();fn();total=total+1;print("PASS "..name)end
assert(type(a.SourceName)=="function","reviewed source names need a typed selected-language resolver")
test("Selected Russian object and NPC names remain separate at an equal numeric ID",function()
 assert(a.SourceName({objectID=142702,name="Venom Bottle"})=="Флакон с ядом")
 assert(a.SourceName({npcID=142702,name="Different creature"})=="Другое существо")
 assert(a.SourceName({npcID=2216,name="Apothecary Lydon"})=="Аптекарь Лидон")
 assert(a.SourceName({objectID=2933,name="Venom Bottles"})==nil)
end)
test("Only a pure uint32 typed identity with its exact canonical name can resolve",function()
 for _,point in ipairs({{}, {name="Venom Bottle"},{objectID=142702,name="Wrong source"},
  {objectID=142702,npcID=142702,name="Venom Bottle"},{objectID=142702,itemID=1,name="Venom Bottle"},
  {objectID=142702,dropNPCID=1,name="Venom Bottle"}})do assert(a.SourceName(point)==nil)end
 for _,id in ipairs({0,-1,1.5,4294967296,"142702",false,math.huge})do
  assert(a.SourceName({objectID=id,name="Venom Bottle"})==nil)
 end
 assert(a.SourceName({objectID=0/0,name="Venom Bottle"})==nil)
end)
test("Sparse missing groups or locales return nil while English uses canonical source",function()
 assert(a.SourceName({objectID=142703,name="Venom Bottle"})==nil)
 a.db.locale="zhCN";assert(a.SourceName({objectID=142702,name="Venom Bottle"})==nil)
 a.db.locale="enUS";assert(a.SourceName({objectID=142702,name="Venom Bottle"})=="Venom Bottle")
 a.db.locale="ruRU";a.nameTranslations.ruRU.objects=nil
 assert(a.SourceName({objectID=142702,name="Venom Bottle"})==nil)
end)
test("Returned proof owns source and dictionary but never calls the caller owner",function()
 local point={objectID=142702,name="Venom Bottle"};local calls=0
 local name,proof=a.SourceName(point,function()calls=calls+1;return true end)
 assert(name=="Флакон с ядом"and type(proof)=="function"and calls>0)
 local before=calls;assert(proof()and calls==before,"retained source proof must not recurse through UI owner")
 point.name="Changed source";assert(not proof())
end)
test("Expired or malformed owners cannot publish names",function()
 local point={objectID=142702,name="Venom Bottle"}
 assert(a.SourceName(point,function()return false end)==nil)
 assert(a.SourceName(point,true)==nil)
end)
test("Locale previews and dictionary entry replacement retire retained proof",function()
 local preview="ruRU";a.Language={GetSelection=function()return preview end}
 local point={objectID=142702,name="Venom Bottle"}
 local _,proof=a.SourceName(point);assert(proof())
 preview="zhCN";assert(not proof());preview="ruRU"
 _,proof=a.SourceName(point);a.nameTranslations.ruRU.objects[142702]={source="Venom Bottle",name="Изменённое имя"}
 assert(not proof())
end)
test("Sparse source groups use the existing locale factory once",function()
 local dictionary=a.nameTranslations.ruRU;local loads=0;a.nameTranslations={}
 a.nameTranslationFactories={root=a.nameTranslations,loaders={ruRU=function()loads=loads+1;return dictionary end}}
 local point={objectID=142702,name="Venom Bottle"}
 assert(a.SourceName(point)=="Флакон с ядом"and a.SourceName(point)=="Флакон с ядом"and loads==1)
end)
test("A lazy loader cannot publish a source changed during localization",function()
 local point={objectID=142702,name="Venom Bottle"};local dictionary=a.nameTranslations.ruRU;local fired=false
 a.nameTranslations={};a.nameTranslationFactories={root=a.nameTranslations,loaders={ruRU=function()
  fired=true;point.objectID=142703;return dictionary
 end}}
 assert(a.SourceName(point)==nil and fired)
end)
test("Source snapshots precede callback-bearing sanitization",function()
 local point={objectID=142702,name="Venom Bottle"};local clean=a.Clean;local fired=false
 a.Clean=function(value,kind)
  if value==point and not fired then fired=true;point.name="Changed during clean"end
  return clean(value,kind)
 end
 local result=a.SourceName(point);a.Clean=clean
 assert(fired and result==nil)
end)
test("Owner reentry cannot publish a prior locale or dictionary name",function()
 local point={objectID=142702,name="Venom Bottle"};local calls=0
 local result=a.SourceName(point,function()
  calls=calls+1;if calls==2 then a.db.locale="zhCN"end;return true
 end)
 assert(calls>=2 and result==nil)
end)
test("Translation sanitization and capability replacement retire source results",function()
 local point={objectID=142702,name="Venom Bottle"};local clean=a.Clean;local fired=false
 a.Clean=function(value,kind)
  if value=="Флакон с ядом"and not fired then fired=true;a.db.locale="zhCN"end
  return clean(value,kind)
 end
 local result=a.SourceName(point);a.Clean=clean
 assert(fired and result==nil)
 a.db.locale="ruRU";local _,proof=a.SourceName(point)
 local getter=a.GetNameTranslations;a.GetNameTranslations=function()end
 assert(not proof());a.GetNameTranslations=getter
end)
test("Malformed reviewed labels remain absent and exact uint32 endpoints stay valid",function()
 local point={objectID=142702,name="Venom Bottle"}
 for _,name in ipairs({"",string.rep("x",1025),false})do
  a.nameTranslations.ruRU.objects[142702].name=name;assert(a.SourceName(point)==nil)
 end
 a.db.locale="enUS"
 assert(a.SourceName({objectID=4294967295,name="Canonical endpoint"})=="Canonical endpoint")
end)
print("Source names: "..total.." checks passed")
