-- Supporting source matches retain their real dungeon target context, never new targets.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
issecretvalue=function()return false end;GetLocale=function()return"enUS"end;C_Timer={After=function()end}
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle();ui.includeUnavailable=true;ui.range=false
local token={}
a.Context=function()local own=token;return{level=60,class="MAGE",faction="Alliance",current=function()return own==token end,
 completed=function()return false end,active=function()return false end,ready=function()return false end}end
local dungeons,counts={},{}
for _,d in ipairs(a.dungeons)do dungeons[d.key]=d;counts[d]=#d.quests end
ui.dungeon,ui.quest=dungeons.dm,166;ui:Refresh()
local routes,hydrates=0,0
local request=C_QuestLog.RequestLoadQuestByID
C_QuestLog.RequestLoadQuestByID=function(...)hydrates=hydrates+1;return request(...)end
a.Navigation={Start=function()routes=routes+1 end,Map=function()routes=routes+1 end}
local function cards(query,locale)
 a.db.locale=locale or"zhCN";ui.search=query;ui:RefreshDungeons()
 local result={};for _,row in ipairs(ui.cards)do if row:IsShown()then result[#result+1]=row end end
 assert(routes==0 and hydrates==0,"source discovery cannot navigate or hydrate native quest data")
 return result
end
local function inDungeon(rows,key)
 for _,row in ipairs(rows)do if row.catalogResult.dungeon==dungeons[key]then return row,row.catalogResult end end
end
local function inspect(result)
 assert(result.inspect and result.inspect:IsShown()and result.inspect.scripts.OnClick)
 result.inspect.scripts.OnClick()
 assert(ui.quest==result.questID and ui.renderedQuest==result.questID and ui.dungeon==result.dungeon)
 assert(ui.questTreeRoot==result.relatedRootID and ui.questTreeDungeon==result.dungeon,"related inspection uses its original target tree")
 local target=false;for _,id in ipairs(result.dungeon.quests)do if id==result.relatedRootID then target=true end;assert(id~=result.questID)end
 assert(target,"related definition is supported by a real target, not added as a target")
end
local queries={
 {"狮鹫管理员沙拉克·鹰斧","Gryphon Master Talonaxe",5636,{"zf"}},
 {"图加·符文图腾","Tonga Runetotem",3448,{"wc"}},
}
for _,sample in ipairs(queries)do
 local matching
 for _,query in ipairs({sample[1],sample[2]})do
  local rows=cards(query)
  local seen={}
  for _,key in ipairs(sample[4])do
   local row,result=inDungeon(rows,key)
   assert(row and result.related and result.relatedRootID,"known supporting giver must find its existing dungeon: "..query.."/"..key)
   assert(result.sourceMatch and result.sourceMatch.kind=="npc"and result.sourceMatch.text==query)
   assert(row.note.text:find(a.L("SEARCH_RELATED_STEP",result.matchedName),1,true),"support result is explicitly a related step")
   local q=assert(a.quests[result.questID]);local identity=false
   for _,point in ipairs({q.start or{},q.finish or{}})do if point.npcID==sample[3]then identity=true end end
   assert(identity,"related match inspects the actual typed source record")
   assert(result.count==#result.dungeon.quests,"support matches cannot inflate the original target count")
   seen[#seen+1]=key..":"..result.questID..":"..result.relatedRootID
  end
  table.sort(seen);local signature=table.concat(seen,",")
  if matching then assert(signature==matching,"canonical and selected-language source matches retain the same association")else matching=signature end
 end
end
local row,result=inDungeon(cards(queries[1][1]),"zf");inspect(result)
assert(ui.detailTab=="quest"and routes==0)
-- Numeric IDs remain exact root-ID search; a support match does not broaden it.
assert(not inDungeon(cards("2988"),"zf"))
local _,root=inDungeon(cards("3527"),"zf");assert(root and root.questID==3527 and not root.related)
local _,primary=inDungeon(cards("叶基亚"),"zf");assert(primary and primary.questID==3527 and not primary.related,"existing target source match wins over supporting candidates")
assert(not inDungeon(cards("图加·符文图腾"),"zf"),"unrelated dungeons cannot inherit another dungeon's supporting sources")
local selected=ui.quest;local blank=cards("");assert(#blank==#a.dungeons and ui.quest==selected)
-- Missing optional relation support preserves existing root search in direct-load consumers.
local relationAPI=a.QuestSearchRelations;a.QuestSearchRelations=nil
local _,existing=inDungeon(cards("叶基亚"),"zf");assert(existing and not existing.related)
a.QuestSearchRelations=relationAPI
local _,fallback=inDungeon(cards(queries[1][1]),"zf")
local titleGetter=a.CachedQuestName
local missingID=fallback.questID
a.CachedQuestName=function(id)if id==missingID then return "  "end;return titleGetter(id)end
local _,fallbackName=inDungeon(cards(queries[1][1]),"zf")
assert(fallbackName.matchedName==a.quests[missingID].name,"unavailable localized related title keeps its real canonical fallback")
a.CachedQuestName=titleGetter
local function retained()
 -- Keep an unrelated real card selected so a retired callback cannot pass vacuously by reselecting itself.
 ui.search="";ui.dungeon,ui.quest=dungeons.dm,166;ui.questTreeRoot,ui.questTreeDungeon=nil,nil;ui:Refresh()
 local card,result=inDungeon(cards(queries[1][1]),"zf")
 assert(card and result.related and result.inspect and result.inspect.scripts.OnClick)
 return result.inspect.scripts.OnClick,result,card
end
for _,mode in ipairs({"graph","source","dictionary","title-entry","title-source","title-kind","title-pointer","helper","query","locale","root-context"})do
 local click,matched=retained();local before=ui.quest
 local q=a.quests[matched.questID];local target=a.quests[matched.relatedRootID]
 local dictionary=assert(a.GetNameTranslations("zhCN",function()return true end));local entry=assert(dictionary.npcs[5636])
 local requires,story,groups=target.requires,target.storyline,target.storylineGroups
 local titleEntries=dictionary.quests;local titleEntry=assert(titleEntries[matched.questID]);local titleName,titleSource=titleEntry.name,titleEntry.source
 local npc,name,api,search,locale,context= q.start and q.start.npcID,entry.name,a.QuestSearchRelations,ui.search,a.db.locale,matched.relatedRootID
 if mode=="graph"then target.requires,target.storyline,target.storylineGroups={},{},{}
 elseif mode=="source"then assert(q.start);q.start.npcID=999998
 elseif mode=="dictionary"then entry.name="Changed reviewed label"
 elseif mode=="title-entry"then titleEntry.name="Changed translated quest title"
 elseif mode=="title-source"then titleEntry.source="Changed canonical title"
 elseif mode=="title-kind"then dictionary.quests={}
 elseif mode=="title-pointer"then titleEntries[matched.questID]={source=titleSource,name=titleName}
 elseif mode=="helper"then a.QuestSearchRelations=function(...)return api(...)end
 elseif mode=="query"then ui.search="new query"
 elseif mode=="locale"then a.db.locale="enUS"
 elseif mode=="root-context"then
  for _,id in ipairs(dungeons.zf.quests)do if id~=context then matched.relatedRootID=id;break end end
  assert(matched.relatedRootID~=context)
 end
 click();assert(ui.quest==before and routes==0,"retained related inspection must expire after "..mode)
 target.requires,target.storyline,target.storylineGroups=requires,story,groups
 if q.start then q.start.npcID=npc end
 dictionary.quests=titleEntries;titleEntries[matched.questID]=titleEntry;titleEntry.name,titleEntry.source=titleName,titleSource
 entry.name=name;a.QuestSearchRelations=api;ui.search=search;a.db.locale=locale;matched.relatedRootID=context
end
-- Snapshot the used translated title before its callback returns an older value.
local _,titleMatch=retained();local dictionary=a.GetNameTranslations("zhCN",function()return true end)
local titleEntry=dictionary.quests[titleMatch.questID];local oldTitle=titleEntry.name
local getter=a.CachedQuestName;local changed=false
 a.CachedQuestName=function(id)
 local value=getter(id)
 if not changed and id==titleMatch.questID then changed=true;titleEntry.name="New title during cached lookup"end
 return value
end
local oldQuest=ui.quest;local after=cards(queries[1][1])
a.CachedQuestName=getter;titleEntry.name=oldTitle
assert(changed and ui.quest==oldQuest and not inDungeon(after,"zf"),"a retired title callback must not publish its old related caption")
-- A previously empty earlier root is a consulted negative graph, not an unowned gap.
local click,matched=retained();local empty
for _,id in ipairs(dungeons.zf.quests)do
 if id==matched.relatedRootID then break end
 local model=a.QuestSearchRelations(dungeons.zf,id)
 if model and #model.nodes==0 then empty=a.quests[id];break end
end
assert(empty,"actual ZF has an earlier empty projection")
local requires=empty.requires;empty.requires={{ids={matched.questID}}};local before=ui.quest
click();assert(ui.quest==before,"new relation in an empty projection must retire the old related result")
empty.requires=requires
-- Native text completion cannot publish an old related cue over a newer query.
local _,matched,card=retained();local oldText=card.note.text;local native=card.note.SetText;local fired=false
card.note.SetText=function(self,text)
 if not fired and text==oldText then fired=true;ui.search="Ragefire Chasm";ui:RefreshDungeons()end
 return native(self,text)
end
ui:RefreshDungeons();card.note.SetText=native
assert(fired and ui.search=="Ragefire Chasm")
local shown=0
for _,other in ipairs(ui.cards)do if other:IsShown()then shown=shown+1;assert(other.catalogResult.dungeon==dungeons.rfc and not other.catalogResult.related)end end
assert(shown==1 and routes==0)
-- A returned graph proof can reenter with a newer query; the UI must recheck ownership afterwards.
local api=a.QuestSearchRelations;local armed,entered=false,false
a.QuestSearchRelations=function(...)
 local model,current,raw=api(...)
 if not current then return model,current,raw end
 return model,function()
  if armed and not entered then entered=true;ui.search="Ragefire Chasm";ui:RefreshDungeons()end
  return current()
 end,raw
end
local oldClick=retained();armed=true;local selected=ui.quest;oldClick()
assert(entered and ui.quest==selected and ui.search=="Ragefire Chasm"and routes==0)
a.QuestSearchRelations=api
for d,count in pairs(counts)do assert(#d.quests==count)end
print("Related source search UI: PASS (real supporting NPCs, exact context, root priority, numeric/blank preservation)")
