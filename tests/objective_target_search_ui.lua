-- Objective target matches are discovery cues, never giver/navigation identities.
local f=assert(loadfile('tests/client_ui.lua'))('fixture');local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;GetLocale=function()return'enUS'end
UnitGUID=function(unit)return unit=='player'and'Player-ObjectiveSearch'or nil end
C_Timer={After=function()end};f.eventFrame.scripts.OnEvent(f.eventFrame,'ADDON_LOADED','DungeonPro');u:Toggle()
u.includeUnavailable=true;u.range=false
local dungeons,counts={},{};for _,d in ipairs(a.dungeons)do dungeons[d.key]=d;counts[d]=#d.quests end
local q=assert(a.quests[5728]);local start=q.start;assert(start.npcID==4949)
local goal=assert(q.objectiveKills[1]);assert(goal.npcID==11519 and goal.name=='Bazzalan')
local route,hydrate,objectives=0,0,0
local nav=a.Navigation;a.Navigation={Start=function()route=route+1 end,Map=function()route=route+1 end}
C_QuestLog.RequestLoadQuestByID=function()hydrate=hydrate+1 end
local objectivesGetter=C_QuestLog.GetQuestObjectives
C_QuestLog.GetQuestObjectives=function(...)objectives=objectives+1;return objectivesGetter(...)end
local localize=a.L
a.L=function(key,...)
 if key=='SEARCH_OBJECTIVE_MATCH'then return '['..a.db.locale..'] Objective target: '..tostring((...))end
 return localize(key,...)
end
local function query(text,locale)
 local beforeHydrate,beforeObjectives=hydrate,objectives
 a.db.locale=locale or'enUS';u.search=text;u:RefreshDungeons()
 for _,d in ipairs(a.dungeons)do assert(#d.quests==counts[d],'goal matches cannot become dungeon roots')end
 assert(route==0 and hydrate==beforeHydrate and objectives==beforeObjectives,'discovery never routes, hydrates, or reads native objectives')
end
local function result(key)
 for _,row in ipairs(u.cards)do if row:IsShown()and row.catalogResult.dungeon==dungeons[key]then return row,row.catalogResult end end
end
query('Bazzalan');local row,match=result('rfc')
assert(row and match.questID==5728 and match.sourceMatch.kind=='objective','actual Bazzalan goal must find RFC/5728')
assert(match.sourceMatch.text=='Bazzalan' and match.count==#dungeons.rfc.quests)
assert(row.note.text:find(a.L('SEARCH_OBJECTIVE_MATCH','Bazzalan'),1,true))
assert(not row.note.text:find(a.L('SEARCH_NPC_MATCH','Bazzalan'),1,true)and not row.note.text:find(a.L('SEARCH_PLACE_MATCH','Bazzalan'),1,true))
assert(not match.related and q.start==start and q.start.npcID==4949 and objectives==0)
assert(match.inspect and match.inspect.scripts.OnClick);match.inspect.scripts.OnClick()
assert(u.quest==5728 and u.dungeon==dungeons.rfc and u.detailTab=='quest'and route==0,'goal inspection opens its quest without routing to the target')
assert(a.quests[5728].start==start and a.quests[5728].finish.npcID==4949)
assert(u.giverAction and u.giverAction.place==start and u.giverBinding and u.giverBinding.current(),
 'normal giver action remains the exact Thrall endpoint, never Bazzalan')
assert(start.mapID==1454 and start.x==32 and start.y==37.8)
u.quest=nil;u.dungeon=nil
for _,locale in ipairs({'enUS','ruRU','deDE','frFR','esES','itIT','ptBR','koKR','zhCN','zhTW'})do
 query('Bazzalan',locale);local card,r=result('rfc');assert(card and r.sourceMatch.kind=='objective')
 assert(card.note.text:find(a.L('SEARCH_OBJECTIVE_MATCH','Bazzalan'),1,true),'controlled locale cue must remain distinct')
end
query('Thrall');local _,source=result('rfc');assert(source and source.sourceMatch.kind=='npc','giver source matches retain their existing role')
query('5728');local _,numeric=result('rfc');assert(numeric and numeric.questID==5728 and not numeric.sourceMatch,'numeric policy remains exact')
query('Kobold Digger');local _,related=result('dm')
assert(related and related.related and related.questID==92745 and related.relatedRootID==92753 and related.sourceMatch.kind=='objective',
 'supporting goal retains the existing exact target tree')
assert(not result('rfc'),'unrelated dungeons cannot inherit a support objective')
local function retained()
 u.quest=nil;u.dungeon=nil;query('Bazzalan');local card,r=result('rfc');return card,assert(r),assert(r.inspect.scripts.OnClick)
end
for _,mode in ipairs({'name','identity','list','query','locale','helper'})do
 local card,r,click=retained();local name,id,list,api=goal.name,goal.npcID,q.objectiveKills,a.QuestSourceSearchTerms
 if mode=='name'then goal.name='Changed target'elseif mode=='identity'then goal.npcID=11518
 elseif mode=='list'then q.objectiveKills={}elseif mode=='query'then u.search='Changed query'
 elseif mode=='locale'then a.db.locale='ruRU'else a.QuestSourceSearchTerms=function(...)return api(...)end end
 click();assert(u.quest==nil and route==0,'retained objective inspection expires after '..mode)
 goal.name,goal.npcID,q.objectiveKills,a.QuestSourceSearchTerms=name,id,list,api
end
local name=goal.name;goal.name='Newly reported target';query('Bazzalan');assert(not result('rfc'))
goal.name=name;query('Bazzalan');assert(result('rfc'),'a previously absent target becomes discoverable on fresh search')
-- The same real target can receive a reviewed alias without becoming a source NPC.
local dict=assert(a.GetNameTranslations('zhCN',function()return true end));local npcs=dict.npcs;dict.npcs=npcs or{}
local old=dict.npcs[11519];dict.npcs[11519]={source='Bazzalan',name='受控目标名称'}
query('受控目标名称','zhCN');local aliasCard,alias=result('rfc')
assert(aliasCard and alias.questID==5728 and alias.sourceMatch.kind=='objective'and alias.sourceMatch.text=='受控目标名称')
local oldClick=alias.inspect.scripts.OnClick;dict.npcs[11519].name='Changed alias';u.quest=nil;oldClick();assert(u.quest==nil)
dict.npcs[11519]=old;dict.npcs=npcs
query('Bazzalan');local card=result('rfc');local set=card.note.SetText;local fired=false;local newest
card.note.SetText=function(self,text)
 if not fired and text:find('Objective target: Bazzalan',1,true)then fired=true;query('Thrall');newest=card.note.text end
 return set(self,text)
end
query('Bazzalan');card.note.SetText=set
assert(fired and u.search=='Thrall'and card.note.text==newest and card.catalogResult.sourceMatch.kind=='npc','late objective caption cannot overwrite newer source result')
a.Navigation=nav
print('PASS objective target UI: actual/related targets, distinct controlled locale cues, exact source identity, no auto-route/hydration, retained and late-caption ownership')
