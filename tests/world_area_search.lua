local a={}
for _,path in ipairs({"Core/Namespace.lua","Core/Client.lua","Database/Catalog.lua","Database/SearchCaseFold.lua","Core/Search.lua"})do
 assert(loadfile(path))("DungeonPro",a)
end
issecretvalue=function()return false end;GetLocale=function()return"enUS"end
local total=0
local function setup()
 a.db,a.Language={locale="ruRU"},nil;a.nameTranslationFactories=nil
 a.sourceAreaNames={["The Hinterlands"]={name="The Hinterlands"},Ironforge={name="Ironforge"}}
 a.nameTranslations={ruRU={quests={},dungeons={},areas={
  ["The Hinterlands"]={source="The Hinterlands",name="Внутренние земли"},Ironforge={source="Ironforge",name="Стальгорн"}}},
  zhCN={quests={},dungeons={},areas={["The Hinterlands"]={source="The Hinterlands",name="辛特兰"}}}}
end
local function test(name,fn)setup();fn();total=total+1;print("PASS "..name)end
local function has(terms,name)
 for _,term in ipairs(terms)do if term.text==name and term.kind=="place"then return true end end
end
test("Actual Venom Bottles area gains Russian and Chinese aliases without route mutation",function()
 local q=a.quests[2933];local first=q.startAlternatives[1]
 local map,x,y=first.mapID,first.x,first.y
 local terms,current,raw=a.QuestSourceSearchTerms(q)
 assert(has(terms,"Внутренние земли"),"Russian Hinterlands search alias is missing")
 assert(has(terms,"The Hinterlands")and current()and raw())
 a.db.locale="zhCN";terms=a.QuestSourceSearchTerms(q);assert(has(terms,"辛特兰"))
 assert(first.mapID==map and first.x==x and first.y==y)
end)
test("Source and reported position names are exact without splitting combined areas",function()
 local q={start={mapID=1,zoneName="Ironforge",locationName="Ironforge / The Hinterlands",reportedLocations={{mapID=2,zoneName="The Hinterlands"}}}}
 local terms=a.QuestSourceSearchTerms(q)
 assert(has(terms,"Стальгорн")and has(terms,"Внутренние земли")and has(terms,"Ironforge / The Hinterlands"))
 local isolated=a.QuestSourceSearchTerms({start={mapID=1,zoneName="Ironforge / The Hinterlands"}})
 assert(not has(isolated,"Стальгорн")and not has(isolated,"Внутренние земли"))
end)
test("Negative area ownership detects new translations registry and helper",function()
 local q={start={mapID=1,zoneName="Ironforge"}}
 a.nameTranslations.ruRU.areas.Ironforge=nil
 local _,current,raw=a.QuestSourceSearchTerms(q);assert(current()and raw())
 a.nameTranslations.ruRU.areas.Ironforge={source="Ironforge",name="Стальгорн"};assert(not current()and not raw())
 local helper=a.SourceAreaName;a.SourceAreaName=nil
 _,current,raw=a.QuestSourceSearchTerms(q);assert(current()and raw());a.SourceAreaName=helper
 assert(not current()and not raw())
end)
test("Reentry and later source or locale changes retire the entire term request",function()
 local point={mapID=1,zoneName="Ironforge"};local q={start=point}
 local _,current,raw=a.QuestSourceSearchTerms(q);point.zoneName="Other";assert(not current()and not raw());point.zoneName="Ironforge"
 _,current,raw=a.QuestSourceSearchTerms(q);a.db.locale="zhCN";assert(not current()and not raw());a.db.locale="ruRU"
 local helper,fired=a.SourceAreaName,false
 a.SourceAreaName=function(...)
  local name,proof,unchanged=helper(...);point.zoneName="Other";fired=true;return name,proof,unchanged
 end
 local terms,valid=a.QuestSourceSearchTerms(q);a.SourceAreaName=helper
 assert(fired and #terms==0 and not valid())
end)
test("Canonical terms keep the full budget before all aliases",function()
 local resolver,area=a.SourceName,a.SourceAreaName
 local q={start={mapID=1,zoneName="Ironforge"},startAlternatives={}}
 for i=1,100 do
  q.startAlternatives[i]={mapID=i,zoneName="Zone"..i,reportedLocations={}}
  for j=1,10 do q.startAlternatives[i].reportedLocations[j]={mapID=i,zoneName=i..":"..j}end
 end
 a.SourceName,a.SourceAreaName=nil,nil;local baseline=a.QuestSourceSearchTerms(q);a.SourceName,a.SourceAreaName=resolver,area
 local terms=a.QuestSourceSearchTerms(q);assert(#terms==1024 and #baseline==1024)
 for i=1,#terms do assert(terms[i].text==baseline[i].text)end
end)
test("Actual bowl alias gets the final slot before a reviewed area alias",function()
 local canonical=assert(a.quests[2204].start.name)
 assert(a.quests[2204].start.objectID==112877)
 a.nameTranslations.ruRU.objects={[112877]={source=canonical,name="Гадальная чаша Талваша"}}
 local q={start={objectID=112877,name=canonical,zoneName="Ironforge"},startAlternatives={}}
 for i=1,100 do
  local point={mapID=i,zoneName="Zone"..i,reportedLocations={}}
  for j=1,(i<=21 and 10 or 9)do point.reportedLocations[j]={mapID=i,zoneName=i..":"..j}end
  q.startAlternatives[i]=point
 end
 local source,area=a.SourceName,a.SourceAreaName
 a.SourceName,a.SourceAreaName=nil,nil
 local baseline=a.QuestSourceSearchTerms(q)
 a.SourceName,a.SourceAreaName=source,area
 assert(#baseline==1023,"fixture must leave exactly one term slot")
 local terms,current,raw=a.QuestSourceSearchTerms(q)
 assert(#terms==1024 and current()and raw())
 for i=1,#baseline do assert(terms[i].text==baseline[i].text and terms[i].kind==baseline[i].kind)end
 assert(terms[1024].text=="Гадальная чаша Талваша"and not has(terms,"Стальгорн"),
  "typed source aliases must receive the last slot before area aliases")
end)
print(total.." reviewed world area search groups passed")
