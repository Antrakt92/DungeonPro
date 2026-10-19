-- Source aliases extend canonical search without native data requests.
local a={}
for _,path in ipairs({"Core/Namespace.lua","Core/Client.lua","Database/Catalog.lua",
 "Database/NameTranslations.lua","Database/SearchCaseFold.lua","Core/Search.lua"})do
 assert(loadfile(path))("DungeonPro",a)
end
issecretvalue=function()return false end;GetLocale=function()return"enUS"end
C_QuestLog={RequestLoadQuestByID=function()error("search must not hydrate quests")end}
C_Item={RequestLoadItemDataByID=function()error("search must not hydrate items")end}
local total=0
local function test(name,fn)
 a.db={locale="ruRU"};a.Language=nil
 fn();total=total+1;print("PASS "..name)
end
local function has(terms,text,kind)
 for _,term in ipairs(terms)do if term.text==text and(not kind or term.kind==kind)then return true end end
end
local function dictionary(objects,npcs)
 a.nameTranslationFactories=nil
 a.nameTranslations={ruRU={quests={},dungeons={},objects=objects or{},npcs=npcs or{}}}
end
test("Actual bowl and journal source aliases retain canonical terms",function()
 local terms,current,raw=a.QuestSourceSearchTerms(a.quests[2204])
 assert(has(terms,"Гадальная чаша Талваша","place"),"Russian bowl alias is missing")
 assert(has(terms,"Talvash's Scrying Bowl","place")and current()and raw())
 terms=a.QuestSourceSearchTerms(a.quests[1100])
 assert(has(terms,"Дневник Хенрига Хмурня","place")and has(terms,"Henrig Lonebrow's Journal"))
 a.db.locale="zhCN";terms=a.QuestSourceSearchTerms(a.quests[2204])
 assert(has(terms,"塔瓦斯德的占卜之碗")and has(terms,"Talvash's Scrying Bowl"))
end)
test("Object and NPC numeric namespaces remain separate",function()
 dictionary({[112877]={source="Bowl",name="Чаша"}},{[112877]={source="Person",name="Человек"}})
 local terms=a.QuestSourceSearchTerms({start={objectID=112877,name="Bowl"},finish={npcID=112877,name="Person"}})
 assert(has(terms,"Чаша","place")and has(terms,"Человек","npc"))
 assert(not has(terms,"Чаша","npc")and not has(terms,"Человек","place"))
 assert(not has(a.QuestSourceSearchTerms({start={objectID=112877,itemID=1,name="Bowl"}}),"Чаша"))
end)
test("Valid absence proofs retire on missing root group or entry becoming present",function()
 for _,missing in ipairs({"root","locale","group","entry"})do
  dictionary();local point={objectID=112877,name="Bowl"}
  if missing=="root"then a.nameTranslations=nil
  elseif missing=="locale"then a.nameTranslations.ruRU=nil
  elseif missing=="group"then a.nameTranslations.ruRU.objects=nil end
  local name,proof,raw=a.SourceName(point)
  assert(name==nil and type(proof)=="function"and type(raw)=="function"and proof()and raw(),missing)
  local terms,current,unchanged=a.QuestSourceSearchTerms({start=point})
  assert(has(terms,"Bowl")and current()and unchanged())
  dictionary({[112877]={source="Bowl",name="Чаша"}})
  assert(not proof()and not raw()and not current()and not unchanged(),missing)
 end
 dictionary();local entries=a.nameTranslations.ruRU.objects
 local _,current,raw=a.QuestSourceSearchTerms({start={objectID=112877,name="Bowl"}})
 entries[112877]={source="Bowl",name="Чаша"};assert(not current()and not raw())
end)
test("Raw proof has no callbacks and retains preview identity",function()
 dictionary({[112877]={source="Bowl",name="Чаша"}})
 local calls=0;local session={preview="ruRU"}
 a.Language={session=session,GetSelection=function(self)calls=calls+1;return self.session.preview end}
 local ownerCalls=0
 local _,proof,raw=a.SourceName({objectID=112877,name="Bowl"},function()ownerCalls=ownerCalls+1;return true end)
 assert(type(raw)=="function");local before,owners=calls,ownerCalls
 assert(raw()and calls==before and ownerCalls==owners)
 assert(proof()and ownerCalls==owners)
 session.preview="zhCN";assert(not raw()and not proof())
end)
test("Search owns source helper dictionary locale and callback mutations",function()
 dictionary({[112877]={source="Bowl",name="Чаша"}})
 local point={objectID=112877,name="Bowl"};local q={start=point}
 local _,current,raw=a.QuestSourceSearchTerms(q)
 point.name="Other";assert(not current()and not raw());point.name="Bowl"
 _,current,raw=a.QuestSourceSearchTerms(q);a.db.locale="zhCN";assert(not current()and not raw());a.db.locale="ruRU"
 _,current,raw=a.QuestSourceSearchTerms(q)
 local original=a.SourceName;a.SourceName=function(...)return original(...)end
 assert(not current()and not raw());a.SourceName=original
 local fired=false
 a.SourceName=function(...)
  local name,proof,unchanged=original(...);point.name="Other";fired=true;return name,proof,unchanged
 end
 local terms,valid=a.QuestSourceSearchTerms(q);assert(fired and #terms==0 and not valid());a.SourceName=original
end)
test("Canonical terms use the complete budget before aliases",function()
 dictionary({[112877]={source="Bowl",name="Чаша"}})
 local q={start={objectID=112877,name="Bowl"},startAlternatives={}}
 for i=1,100 do
  local p={mapID=i,name="unused",zoneName="Zone"..i,reportedLocations={}}
  for j=1,10 do p.reportedLocations[j]={mapID=i,zoneName="Position"..i..":"..j}end
  q.startAlternatives[i]=p
 end
 local helper=a.SourceName;a.SourceName=nil
 local baseline=a.QuestSourceSearchTerms(q);a.SourceName=helper
 local terms,current,raw=a.QuestSourceSearchTerms(q)
 assert(#baseline==1024 and #terms==1024 and current()and raw())
 for i=1,#baseline do assert(terms[i].text==baseline[i].text and terms[i].kind==baseline[i].kind)end
 assert(not has(terms,"Чаша"))
end)
test("Missing optional resolver preserves canonical search",function()
 local helper=a.SourceName;a.SourceName=nil
 local terms,current,raw=a.QuestSourceSearchTerms(a.quests[2204])
 assert(has(terms,"Talvash's Scrying Bowl")and current()and raw())
 a.SourceName=helper;assert(not current()and not raw())
end)
test("Request-local duplicate labels keep every physical source owned",function()
 dictionary({[112877]={source="Bowl",name="Чаша"}})
 local first,second={objectID=112877,name="Bowl"},{objectID=112877,name="Bowl"}
 local helper,calls=a.SourceName,0
 a.SourceName=function(...)calls=calls+1;return helper(...)end
 local terms,current,raw=a.QuestSourceSearchTerms({start=first,finish=second})
 assert(calls==1 and has(terms,"Bowl")and has(terms,"Чаша")and current()and raw())
 second.objectID=19861;assert(not current()and not raw());a.SourceName=helper
 local _,fresh=a.QuestSourceSearchTerms({start=first});assert(fresh())
end)
test("Raw absence and alias proofs never call sanitizers or locale providers",function()
 dictionary()
 local clean,read,checker=a.Clean,a.Read,issecretvalue
 local calls=0
 a.Clean=function(...)calls=calls+1;return clean(...)end
 a.Read=function(...)calls=calls+1;return read(...)end
 issecretvalue=function(...)calls=calls+1;return checker(...)end
 GetLocale=function()calls=calls+1;return"enUS"end
 local _,current,raw=a.QuestSourceSearchTerms({start={objectID=112877,name="Bowl"}})
 assert(current());local before=calls;assert(raw()and calls==before)
 a.Clean,a.Read,issecretvalue=clean,read,checker
end)
test("A failed translation read cannot publish a new dictionary as valid absence",function()
 dictionary({[112877]={source="Bowl",name="Чаша"}})
 local clean,fired=a.Clean,false
 a.Clean=function(value,kind)
  if value=="Чаша"and not fired then
   fired=true;a.nameTranslations.ruRU.objects[112877]={source="Bowl",name="Новая чаша"}
  end
  return clean(value,kind)
 end
 local terms,current=a.QuestSourceSearchTerms({start={objectID=112877,name="Bowl"}})
 a.Clean=clean
 assert(fired and #terms==0 and not current(),"an invalidated alias read must retire the request")
end)
print(total.." localized source search groups passed")
