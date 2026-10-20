-- Reviewed creature labels change presentation, not source identity or quest certainty.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
issecretvalue=function()return false end;GetLocale=function()return"enUS"end;C_Timer={After=function()end}
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle();ui.includeUnavailable=true
local groups={
 {1855,"提里奥·弗丁",{5742,5781,5845,5846,5861},1423,7.4,43.4},
 {5636,"狮鹫管理员沙拉克·鹰斧",{2988,2989,2990,2994,1451},1425,9.8,44.4},
 {3448,"图加·符文图腾",{1489,870,877,880},1413,52.2,31.8},
 {8579,"叶基亚",{3527,3520,4787,3528},1446,67,22.4},
 {11035,"贝蒂娜·比格辛克",{4771,5529,5213,5212},1423,81.4,59.4},
}
local owners,rootCounts={},{}
local function visit(id,d,seen)
 if seen[id]then return end;seen[id]=true;owners[id]=owners[id]or d
 local q=assert(a.quests[id])
 for _,g in ipairs(q.requires or{})do for _,other in ipairs(g.ids)do visit(other,d,seen)end end
 for _,other in ipairs(q.storyline or{})do visit(other,d,seen)end
 for _,g in ipairs(q.storylineGroups or{})do for _,other in ipairs(g)do visit(other,d,seen)end end
end
for _,d in ipairs(a.dungeons)do rootCounts[d]=#d.quests;for _,id in ipairs(d.quests)do visit(id,d,{})end end
local stateToken={}
a.Context=function()
 local token=stateToken
 return{level=60,class="MAGE",faction="Alliance",current=function()return token==stateToken end,
 completed=function()return false end,active=function()return false end,ready=function()return false end}
end
local nativeItem=a.ItemName
a.ItemName=function(id)return"Native item marker "..id end
a.ItemIcon=function()return 134400 end;a.CarriedItemCount=function()return 0 end
UnitGUID=function(unit)if unit=="npc"then return"Creature-0-0-0-0-1855-0000000000"end end
UnitName=function(unit)if unit=="npc"then return"Native NPC in another language"end end
C_CreatureInfo=C_CreatureInfo or{};C_CreatureInfo.GetCreatureID=function()return 1855 end
local tip={}
function tip:SetOwner(owner)self.owner=owner end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetText(text)self.title=text end
function tip:AddLine(text)self.body=text end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip
local routes={};local nav=a.Navigation;local start=nav.Start
nav.Start=function(action)routes[#routes+1]=action;return start(action)end
local function render(id)
 stateToken={};ui.quest,ui.dungeon=id,assert(owners[id],"existing graph owner required for "..id)
 ui:Refresh();assert(ui.quest==id and ui.renderedQuest==id)
 if ui.detailTab~="quest"then assert(ui:SetDetailTab("quest"))end
end
local function visible(text)
 for _,field in ipairs(ui.details)do if field:IsShown()and field.text and field.text:find(text,1,true)then return true end end
 for index=1,2 do local contact=ui.detailContactRows and ui.detailContactRows[index];if contact and contact:IsShown()and(contact.title.text:find(text,1,true)or contact.note.text:find(text,1,true))then return true end end
end
local function ownContact(field)
 local q=assert(a.quests[ui.quest]);local point=assert(q[field]);local contact=assert(ui.detailContactRows[field=="start"and 1 or 2])
 local binding=assert(contact.detailContactBinding)
 assert(contact:IsShown()and binding.questID==q.id and binding.field==field and binding.endpoint==point and binding.current(),"actual contact owns exact selected source")
 return contact
end
local function sourceHint()
 local selected,dungeon=ui.quest,ui.dungeon
 local function control()
  for _,row in ipairs(ui.rows)do if row:IsShown()and row.questID==selected then return assert(row.navigationControl)end end
 end
 local found=control();if found then return found end
 -- Explicitly open the real containing middle-tree group for a support quest before hovering its source control.
 for _,root in ipairs(dungeon.quests)do
  local tree=assert(a.QuestTree.Build(a.quests,ui.engine,root))
  for _,node in ipairs(tree)do if node.id==selected then
   ui.questTreeRoot,ui.questTreeDungeon=root,dungeon
   ui:RefreshQuests();ui:RefreshDetail()
   assert(ui.quest==selected and ui.dungeon==dungeon,"source hint expansion keeps actual selected quest and dungeon")
   return assert(control(),"expanded exact tree contains selected source hint")
  end end
 end
 error("selected source has no actual containing middle-tree group")
end

local points,total={},0
a.db.locale="zhCN"
for _,group in ipairs(groups)do
 local npc,label,ids,map,x,y=unpack(group)
 for _,id in ipairs(ids)do
  local q=assert(a.quests[id]);local p=assert(q.start)
  assert(p.npcID==npc and p.mapID==map and p.x==x and p.y==y and not p.itemID and not p.objectID)
  points[id]={point=p,name=p.name,zone=p.zoneName,map=map,x=x,y=y,npc=npc,finish=q.finish,requires=q.requires,known=q.requirementsKnown}
  render(id)
  local status=ui.engine:State(id).status;local before=#routes
  assert(ownContact("start").title.text==a.L("DETAIL_GIVER")..": "..label,"reviewed Chinese NPC label missing on own actual pickup contact "..id.."/"..npc)
  if id==4771 then assert(visible("Native item marker 12368"),"provided item keeps independent native item naming")end
  assert(ui:SetDetailTab("sources")and visible(label),"Sources must retain the same reviewed NPC identity")
  assert(ui.engine:State(id).status==status and #routes==before,"translated source display cannot grant availability or start a route")
  local terms,current,raw=a.QuestSourceSearchTerms(q);local canonical,translated=false,false
  for _,term in ipairs(terms)do if term.kind=="npc"then
   if term.text==p.name then canonical=true end;if term.text==label then translated=true end
  end end
  assert(canonical and translated and current()and raw(),"each actual definition retains canonical and reviewed NPC search terms")
  total=total+1
 end
end
assert(total==22 and #routes==0,"displaying all reviewed starters must not start navigation")
local function guide()
 for _,object in ipairs(f.objects)do if object.title and object.note and object.label and object.scripts.OnUpdate then return object end end
end
-- One actual route per creature; other matching starter records keep their own bindings above.
for _,group in ipairs(groups)do
 local npc,label,ids=unpack(group);local id=ids[1];render(id)
 local before=#routes;local contact=ownContact("start");assert(contact.enabled and contact.scripts.OnClick)
 local hint=sourceHint();hint.scripts.OnEnter();assert(tip.shown and tip.owner==hint and tip.body:find(label,1,true))
 assert(#routes==before);contact.scripts.OnClick()
 local action=routes[#routes];assert(#routes==before+1 and action.id==id and action.place==points[id].point and action.place.npcID==npc)
 local g=assert(guide());assert(g:IsShown()and g.note.text:find(label,1,true))
 nav.Stop()
end
local explicitRoutes=#routes;assert(explicitRoutes==5)
-- Selected-language and canonical searches keep the current inspected card and never hydrate names.
local reads=0;local request=C_QuestLog.RequestLoadQuestByID
C_QuestLog.RequestLoadQuestByID=function(...)reads=reads+1;return request(...)end
local selection,engine,plan=ui.quest,ui.engine,ui.currentPlan
for _,group in ipairs(groups)do
 local npc,label,ids=unpack(group);local canonical=points[ids[1]].name;local previousMatches
 for _,query in ipairs({label,canonical})do
  local before=#routes;ui.search=query;ui:RefreshDungeons()
  local match=false;local matches={}
  for _,card in ipairs(ui.cards)do
   local result=card.catalogResult
   if card:IsShown()and result then
    matches[#matches+1]=result.dungeon.key
    if result.sourceMatch and result.sourceMatch.kind=="npc"and result.sourceMatch.text==query then match=true end
   end
  end
  table.sort(matches);local matchedKeys=table.concat(matches,",")
  if npc==5636 or npc==3448 then
   if previousMatches then assert(matchedKeys==previousMatches,"support-only canonical and translated searches retain equivalent catalogue coverage")end
   previousMatches=matchedKeys
  else assert(match,"NPC source search must match an existing dungeon for "..query)end
  assert(ui.quest==selection and ui.engine==engine and ui.currentPlan==plan and #routes==before)
 end
end
assert(reads==0,"localized/canonical source search must not hydrate native quest names")
C_QuestLog.RequestLoadQuestByID=request;ui.search=""
-- Other reviewed primary labels are sparse; unchanged responses are not imported.
local changed={
 deDE={[5636]="Greifenmeister Talonaxe"},
 frFR={[5636]="Maître des gryphons Talonaxe"},
 esES={[1855]="Tirión Vadín",[5636]="Maestro de grifos Garracha",[3448]="Tonga Runatótem"},
 ptBR={[5636]="Mestre de Grifos Garra-de-acha",[3448]="Tonga Runa Totem",[11035]="Betina Bigozinco"},
 ruRU={[1855]="Тирион Фордринг",[5636]="Укротитель грифонов Разящий Коготь",[3448]="Тонга Рунический Тотем",[8579]="Йе'кинья",[11035]="Бетина Биггльцинк"},
 koKR={[1855]="티리온 폴드링",[5636]="그리핀 조련사 탈론액스",[3448]="통가 룬토템",[8579]="예킨야",[11035]="베티나 비글징크"},
 zhTW={[1855]="提里奧·弗丁",[5636]="獅鷲獸管理員沙拉克·鷹斧",[3448]="圖加·符文圖騰",[8579]="葉基亞",[11035]="貝蒂娜·比格辛克"},
}
local aliasCases=5
for _,locale in ipairs({"deDE","frFR","esES","ptBR","ruRU","koKR","zhTW"})do
 a.db.locale=locale
 for _,group in ipairs(groups)do
  local npc,_,ids=unpack(group);local id=ids[1];render(id)
  local label=changed[locale]and changed[locale][npc]
  if label then assert(visible(label),"reviewed sparse NPC alias missing for "..locale.."/"..npc);aliasCases=aliasCases+1
  else
   assert(a.SourceName(a.quests[id].start)==nil,"unchanged English response should retain native/canonical fallback")
   assert(visible(npc==1855 and "Native NPC in another language"or points[id].name))
  end
 end
end
assert(aliasCases==28)
-- All five Italian responses were withheld placeholders; canonical fallback remains honest.
a.db.locale="itIT"
for _,group in ipairs(groups)do
 local npc,_,ids=unpack(group);local id=ids[1];render(id)
 assert(a.SourceName(a.quests[id].start)==nil,"withheld Italian placeholders must not become source labels")
 if npc==1855 then assert(visible("Native NPC in another language"))else assert(visible(points[id].name))end
end
assert(#routes==explicitRoutes,"sparse labels and fallback renders do not automatically visit a giver")
-- A normal language commit retires the old displayed source proof and tooltip, not the unchanged route.
a.db.locale="zhCN";render(3527);sourceHint().scripts.OnEnter()
assert(tip.shown and tip.body:find("叶基亚",1,true))
local binding=ownContact("start").detailContactBinding;local oldClick=ownContact("start").scripts.OnClick;local _,proof=a.SourceName(a.quests[3527].start);local before=#routes
ui.language.scripts.OnEnter();local session=assert(a.Language.session)
assert(a.Language:Commit(session,"enUS")and a.db.locale=="enUS")
assert(not binding.current()and not proof()and not tip.shown and #routes==before)
assert(visible(points[3527].name));sourceHint().scripts.OnEnter();assert(tip.body:find(points[3527].name,1,true))
oldClick();assert(#routes==before,"old localized contact callback stays retired")
ownContact("start").scripts.OnClick();assert(#routes==before+1 and routes[#routes].place==points[3527].point)
nav.Stop()
for id,saved in pairs(points)do
 local q=a.quests[id];local p=q.start
 assert(p==saved.point and p.name==saved.name and p.npcID==saved.npc and p.mapID==saved.map and p.x==saved.x and p.y==saved.y and p.zoneName==saved.zone)
 assert(q.finish==saved.finish and q.requires==saved.requires and q.requirementsKnown==saved.known)
end
for d,count in pairs(rootCounts)do assert(#d.quests==count)end
nav.Start=start;a.ItemName=nativeItem
print("Additional NPC names UI: PASS (22 actual starters, five exact routes/hints/guides, source search and normal language retirement)")
