local a={};assert(loadfile("Core/Namespace.lua"))("DungeonPro",a)
assert(loadfile("Core/Client.lua"))("DungeonPro",a)
local total=0
local function setup()
 issecretvalue=function()return false end;GetLocale=function()return"enUS"end
 GetRealZoneText=function()error("reviewed areas must not read native labels")end
 a.db,a.Language={locale="ruRU"},nil
 a.dungeons={{key="mara",name="Maraudon"}}
 a.sourceAreaNames={["The Hinterlands"]={name="The Hinterlands"},Ironforge={name="Ironforge"}}
 a.nameTranslations={ruRU={quests={},dungeons={mara={source="Maraudon",name="Мародон"}},areas={
  ["The Hinterlands"]={source="The Hinterlands",name="Внутренние земли"},
  Ironforge={source="Ironforge",name="Стальгорн"}}}}
 a.nameTranslationFactories=nil
end
local function test(name,fn)setup();fn();total=total+1;print("PASS "..name)end
test("Exact reviewed world areas use selected locale and preserve English",function()
 assert(a.SourceAreaName("The Hinterlands")=="Внутренние земли","reviewed world area is missing")
 assert(a.SourceAreaName("Ironforge")=="Стальгорн")
 a.db.locale="enUS";assert(a.SourceAreaName("The Hinterlands")=="The Hinterlands")
 assert(a.SourceAreaName("Blackrock Spire")==nil)
 assert(a.SourceAreaName("The Hinterlands / Ironforge")==nil)
end)
test("Dungeon priority and ambiguity cannot be bypassed by world entries",function()
 a.sourceAreaNames.Maraudon={name="Maraudon"}
 a.nameTranslations.ruRU.areas.Maraudon={source="Maraudon",name="Wrong world alias"}
 assert(a.SourceAreaName("Maraudon")=="Мародон")
 a.dungeons[2]={key="other",name="Maraudon"};assert(a.SourceAreaName("Maraudon")==nil)
end)
test("Missing registry and translations have retained negative proofs",function()
 for _,mode in ipairs({"registry","member","dictionary","group","entry"})do
  setup()
  if mode=="registry"then a.sourceAreaNames=nil elseif mode=="member"then a.sourceAreaNames.Ironforge=nil
  elseif mode=="dictionary"then a.nameTranslations.ruRU=nil
  elseif mode=="group"then a.nameTranslations.ruRU.areas=nil else a.nameTranslations.ruRU.areas.Ironforge=nil end
  local name,proof,raw=a.SourceAreaName("Ironforge")
  assert(name==nil and type(proof)=="function"and type(raw)=="function"and proof()and raw(),mode)
  if mode=="registry"then a.sourceAreaNames={Ironforge={name="Ironforge"}}
  elseif mode=="member"then a.sourceAreaNames.Ironforge={name="Ironforge"}
  elseif mode=="dictionary"then a.nameTranslations.ruRU={areas={Ironforge={source="Ironforge",name="Стальгорн"}}}
  elseif mode=="group"then a.nameTranslations.ruRU.areas={Ironforge={source="Ironforge",name="Стальгорн"}}
  else a.nameTranslations.ruRU.areas.Ironforge={source="Ironforge",name="Стальгорн"}end
  assert(not proof()and not raw(),mode)
 end
end)
test("Returned proofs exclude owner and raw proof invokes no callbacks",function()
 local ownerCalls,localeCalls=0,0
 a.Language={session={preview="ruRU"},GetSelection=function(self)localeCalls=localeCalls+1;return self.session.preview end}
 local _,proof,raw=a.SourceAreaName("Ironforge",function()ownerCalls=ownerCalls+1;return true end)
 assert(type(proof)=="function"and type(raw)=="function")
 local owners,locales=ownerCalls,localeCalls;assert(raw()and localeCalls==locales and ownerCalls==owners)
 assert(proof()and ownerCalls==owners)
 a.Language.session.preview="zhCN";assert(not proof()and not raw())
end)
test("Registry dictionary helper and canonical source mutations retire proofs",function()
 for _,mutate in ipairs({
  function()a.sourceAreaNames.Ironforge.name="Other"end,
  function()a.nameTranslations.ruRU.areas.Ironforge.name="Other"end,
  function()a.dungeons[1].name="Ironforge"end,
  function()a.db.locale="enUS"end,
  function()a.GetNameTranslations=function()end end,
 })do
  setup();local getter=a.GetNameTranslations
  local _,proof,raw=a.SourceAreaName("Ironforge");assert(proof()and raw())
  mutate();assert(not proof()and not raw());a.GetNameTranslations=getter
 end
end)
test("Lazy load and sanitization cannot bless a replacement as absence",function()
 a.nameTranslations={};local root=a.nameTranslations;local fired=false
 a.nameTranslationFactories={root=root,loaders={ruRU=function()
  fired=true;return{quests={},dungeons={},areas={Ironforge={source="Ironforge",name="Стальгорн"}}}
 end}}
 assert(a.SourceAreaName("Ironforge")=="Стальгорн"and fired)
 local clean=a.Clean;fired=false
 a.Clean=function(value,kind)
  if value=="Стальгорн"and not fired then fired=true;a.nameTranslations.ruRU.areas.Ironforge.name="Changed"end
  return clean(value,kind)
 end
 local name,proof,raw=a.SourceAreaName("Ironforge");a.Clean=clean
 assert(fired and name==nil and(not proof or not proof())and(not raw or not raw()))
end)
test("Malformed source names and registry entries stay unknown",function()
 for _,name in ipairs({false,1,"",string.rep("x",1025),"Ironforge\0"})do assert(a.SourceAreaName(name)==nil)end
 for _,entry in ipairs({false,1,{}, {name="Different"}})do a.sourceAreaNames.Ironforge=entry;assert(a.SourceAreaName("Ironforge")==nil)end
 assert(a.SourceAreaName("The Hinterlands",true)==nil)
 assert(a.SourceAreaName("The Hinterlands",function()return false end)==nil)
end)
print(total.." reviewed world area name groups passed")
