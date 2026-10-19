-- Reviewed NPC names extend actual source records without changing quest or route facts.
local a={}
for _,path in ipairs({"Core/Namespace.lua","Core/Client.lua","Database/Catalog.lua",
 "Database/NameTranslations.lua","Database/SearchCaseFold.lua","Core/Search.lua"})do
 assert(loadfile(path))("DungeonPro",a)
end
issecretvalue=function()return false end;GetLocale=function()return"enUS"end
C_QuestLog={RequestLoadQuestByID=function()error("NPC name search must not hydrate quests")end,
 GetTitleForQuestID=function()error("NPC source aliases must not read live quest names")end}
C_Item={RequestLoadItemDataByID=function()error("NPC name search must not hydrate items")end}
UnitName=function()error("reviewed names must not read the current target")end
GetUnitName=UnitName;GetRealZoneText=function()error("NPC names do not need native locations")end
local function copy(value)
 if type(value)~="table"then return value end
 local result={};for key,child in pairs(value)do result[key]=copy(child)end;return result
end
local function same(left,right)
 if type(left)~=type(right)then return false end
 if type(left)~="table"then return left==right end
 for key,value in pairs(left)do if not same(value,right[key])then return false end end
 for key in pairs(right)do if left[key]==nil then return false end end
 return true
end
local before,roots=copy(a.quests),copy(a.dungeons)
local samples={
 {234,166,"start","Gryan Stoutmantle","Гриан Камнегрив","格里安·斯托曼","Gryan Stoutmantle"},
 {820,214,"start","Scout Riell","Разведчица Риэла","哨兵瑞尔","Eclaireur Riell"},
 {3446,865,"start","Mebok Mizzyrix","Мебок Миззрикс","麦伯克·米希瑞克斯","Mebok Mizzyrix"},
 {6826,2204,"finish","Talvash del Kissel","Талваш де Киссель","塔瓦斯德·基瑟尔","Talvash del Kissel"},
 {2216,2933,"finish","Apothecary Lydon","Аптекарь Лидон","药剂师林度恩","Apothicaire Lydon"},
 {2784,98423,"finish","King Magni Bronzebeard","Король Магни Бронзобород","国王麦格尼·铜须","Roi Magni Bronzebeard"},
 {9560,6402,"start","Marshal Maxwell","Маршал Максвелл","麦克斯韦尔元帅","Maréchal Maxwell"},
 {6868,2203,"start","Jarkal Mossmeld","Джаркал Замшелый Клык","加卡尔","Jarkal Mossmeld"},
 {6546,1954,"start","Tabetha","Табета","塔贝萨","Tabetha"},
 {8405,8257,"start","Ogtinc","Огтинк","奥汀克","Ogtinc"},
 {4949,5728,"start","Thrall","Тралл","萨尔","Thrall"},
 {2055,97291,"start","Master Apothecary Faranell","Мастер аптекарь Фаранелл","大药剂师法拉尼尔","Maître apothicaire Faranell"},
}
local function has(terms,text,kind)
 for _,term in ipairs(terms)do if term.text==text and term.kind==(kind or"npc")then return true end end
end
local scout=assert(a.quests[214].start)
assert(scout.npcID==820 and scout.name=="Scout Riell")
a.db={locale="ruRU"};a.Language=nil
assert(a.SourceName(scout)=="Разведчица Риэла","reviewed Russian Scout Riell name must be imported")
for _,locale in ipairs({{"ruRU",5},{"zhCN",6},{"frFR",7}})do
 a.db.locale=locale[1]
 for _,sample in ipairs(samples)do
  local q=assert(a.quests[sample[2]]);local source=assert(q[sample[3]])
  assert(source.npcID==sample[1]and source.name==sample[4],"sample must retain its exact actual NPC identity")
  local name,proof,raw=a.SourceName(source)
  local expected=sample[locale[2]]
  if locale[1]=="frFR"and expected==source.name then
   assert(name==nil,"unchanged French proper names use canonical fallback rather than stored aliases")
  else assert(name==expected,locale[1].." NPC "..sample[1])end
  assert((name or source.name)==expected and proof()and raw())
  local terms,current,unchanged=a.QuestSourceSearchTerms(q)
  assert(has(terms,sample[4])and has(terms,expected)and current()and unchanged(),"localized NPC terms retain English")
 end
 local needle=a.SearchFold(samples[2][locale[2]])
 local matches={}
 for id,q in pairs(a.quests)do
  for _,term in ipairs(a.QuestSourceSearchTerms(q))do
   if term.kind=="npc"and a.SearchFold(term.text)==needle then matches[#matches+1]=id;break end
  end
 end
 assert(#matches==1 and matches[1]==214,"exact Scout alias finds its actual quest, not another source")
 print("PASS "..locale[1].." twelve actual NPC names, canonical terms and Scout quest search")
end
a.db.locale="ruRU"
local bowl=assert(a.quests[2204].start)
assert(bowl.objectID==112877 and not bowl.npcID)
assert(a.SourceName(bowl)=="Гадальная чаша Талваша"and a.SourceName(bowl)~=a.SourceName(scout))
assert(a.SourceName({})==nil and a.SourceName({npcID=820,name="Different source"})==nil)
local terms=a.QuestSourceSearchTerms(a.quests[2933])
assert(has(terms,"Аптекарь Лидон")and not has(terms,"Разведчица Риэла"),"supporting source references keep the correct NPC")
terms=a.QuestSourceSearchTerms(a.quests[2204])
assert(has(terms,"Талваш де Киссель")and has(terms,"Гадальная чаша Талваша","place"))
print("PASS actual NPC and object names remain separate on supporting source references")
a.db.locale="enUS";assert(a.SourceName(scout)=="Scout Riell")
a.db.locale="itIT";assert(a.SourceName(scout)==nil)
terms=a.QuestSourceSearchTerms(a.quests[214]);assert(has(terms,"Scout Riell"))
a.db.locale="ruRU"
local dictionary=assert(a.GetNameTranslations("ruRU",function()return true end))
local entries=dictionary.npcs;dictionary.npcs=nil
local missing,proof,raw=a.SourceName(scout)
assert(missing==nil and proof()and raw())
terms=a.QuestSourceSearchTerms(a.quests[214]);assert(has(terms,"Scout Riell")and not has(terms,"Разведчица Риэла"))
dictionary.npcs=entries;assert(not proof()and not raw())
assert(a.SourceName(scout)=="Разведчица Риэла")
assert(same(a.quests,before)and same(a.dungeons,roots),"localized labels must not change catalogue routes roles or quest facts")
print("PASS sparse language and dictionary fallback preserve exact catalogue facts without native hydration")
