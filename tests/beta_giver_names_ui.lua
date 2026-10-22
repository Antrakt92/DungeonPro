-- Creature labels preserve typed identity, source certainty, and existing navigation facts.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u=f.addon,f.addon.UI
-- Native FontStrings are shown on creation; journal purpose is its own region.
local createFontString=f.methods.CreateFontString
function f.methods:CreateFontString(...)local value=createFontString(self,...);value.shown=true;return value end
issecretvalue=function()return false end;GetLocale=function()return"enUS"end;C_Timer={After=function()end}
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();u.includeUnavailable=true;u.range=false
local samples={
 {16013,8926,"Deliana"},{16012,8927,"Mokvar"},{14368,7463,"Lorekeeper Lydros"},
 {8379,8235,"Archmage Xylem"},{253092,92753,"Alba Fairmoon"},
}
local reviewed={
 ruRU={[16013]="Делиана",[16012]="Моквар",[14368]="Сказитель Лидрос",[8379]="Верховный маг Ксилем",[253092]="Альба Светлая Луна"},
 koKR={[16013]="델리아나",[16012]="모크바르",[14368]="현자 리드로스",[8379]="대마법사 실렘",[253092]="알바 페어문"},
 zhCN={[16013]="德莉亚娜",[16012]="莫克瓦尔",[14368]="博学者莱德罗斯",[8379]="大法师克希雷姆",[253092]="阿尔巴·晴月"},
 zhTW={[16013]="德莉娜",[16012]="莫克瓦",[14368]="博學者萊德羅斯",[8379]="大法師克希雷姆",[253092]="艾芭‧皎月"},
 deDE={[14368]="Hüter des Wissens Lydros",[8379]="Erzmagier Xylem"},
 frFR={[14368]="Gardien du savoir Lydros",[8379]="Archimage Xylem",[253092]="Alba Lunepâle"},
 esES={[14368]="Tradicionalista Lydros",[8379]="Archimago Xylem",[253092]="Alba Lunajusta"},
 ptBR={[14368]="Erudito Lydros",[8379]="Arquimago Tauriel",[253092]="Alba Belua"},
}
local locales={"enUS","ruRU","deDE","frFR","esES","itIT","ptBR","koKR","zhCN","zhTW"}
local owners,counts,points={}, {},{}
local engine={Current=function()return true end,State=function()return{status="UNKNOWN"}end}
for _,d in ipairs(a.dungeons)do
 counts[d]=#d.quests
 for _,id in ipairs(d.quests)do
  owners[id]=owners[id]or d
  local tree=assert(a.QuestTree.Build(a.quests,engine,id))
  for _,node in ipairs(tree)do owners[node.id]=owners[node.id]or d end
 end
end
for id,q in pairs(a.quests)do
 for _,role in ipairs({"start","finish"})do
  local p=q[role]
  for _,s in ipairs(samples)do if p and p.npcID==s[1]then
   points[#points+1]={id=id,role=role,p=p,npc=p.npcID,name=p.name,map=p.mapID,x=p.x,y=p.y,zone=p.zoneName,
    known=q.requirementsKnown,classes=q.classes,races=q.races,factions=q.factions,requires=q.requires}
  end end
 end
end
assert(#points==65,"actual typed source inventory must remain explicit")
local routes={};local nav=a.Navigation;local start=nav.Start
nav.Start=function(action)routes[#routes+1]=action;return start(action)end
local function render(id)
 u.search="";u.dungeon,u.quest=assert(owners[id],"existing exact tree owner required"),id;u:Refresh()
 if u.detailTab~="quest"then assert(u:SetDetailTab("quest"))end
 assert(u.renderedQuest==id)
end
local function visible(text)
 for _,fs in ipairs(u.details)do if fs:IsShown()and fs.text and fs.text:find(text,1,true)then return true end end
 for index=1,2 do local contact=u.detailContactRows and u.detailContactRows[index];if contact and contact:IsShown()and(contact.title.text:find(text,1,true)or contact.note.text:find(text,1,true))then return true end end
end
local function ownContact(field)
 local q=assert(a.quests[u.quest]);local point=assert(q[field]);local contact=assert(u.detailContactRows[field=="start"and 1 or 2])
 local binding=assert(contact.detailContactBinding)
 assert(contact:IsShown()and binding.questID==q.id and binding.field==field and binding.endpoint==point and binding.current(),"actual contact owns exact selected source")
 local purpose=assert(contact.detailPurpose,"contact purpose is a distinct region")
 assert(not purpose:IsShown()and purpose.text==a.L(field=="start"and "DETAIL_GIVER"or"DETAIL_TURNIN"),"current source purpose remains independently available for its tooltip")
 return contact
end
local function sourceHint()
 local selected,dungeon=u.quest,u.dungeon
 local function control()
  for _,row in ipairs(u.rows)do if row:IsShown()and row.questID==selected then return assert(row.navigationControl)end end
 end
 local found=control();if found then return found end
 -- Explicitly open the real containing middle-tree group for a support quest before hovering its source control.
 for _,root in ipairs(dungeon.quests)do
  local tree=assert(a.QuestTree.Build(a.quests,u.engine,root))
  for _,node in ipairs(tree)do if node.id==selected then
   u.questTreeRoot,u.questTreeDungeon=root,dungeon
   u:RefreshQuests();u:RefreshDetail()
   assert(u.quest==selected and u.dungeon==dungeon,"source hint expansion keeps actual selected quest and dungeon")
   return assert(control(),"expanded exact tree contains selected source hint")
  end end
 end
 error("selected source has no actual containing middle-tree group")
end

local aliases=0
for _,locale in ipairs(locales)do
 a.db.locale=locale
 for _,s in ipairs(samples)do
  local p=a.quests[s[2]].start;local label=reviewed[locale]and reviewed[locale][s[1]]
  local translated,current,raw=a.SourceName(p)
  if label then assert(translated==label,"missing reviewed creature label "..locale.."/"..s[1]);assert(current()and raw());aliases=aliases+1
  elseif locale=="enUS"then assert(translated==s[3],"English source identity remains canonical")
  else assert(translated==nil,"unchanged/placeholder response must remain a sparse fallback")end
  render(s[2]);assert(ownContact("start").title.text==(label or s[3]),"Quest summary loses own selected pickup source name")
  assert(u:SetDetailTab("sources")and visible(label or s[3]),"Sources loses current selected source name")
 end
 for _,saved in ipairs(points)do
  local expected=locale=="enUS"and saved.name or(reviewed[locale]and reviewed[locale][saved.npc])
  assert(a.SourceName(saved.p)==expected,"all descriptors share exact typed name policy")
 end
end
assert(aliases==31 and #routes==0,"presentation never automatically navigates")
-- The other Alba has the same canonical name but a distinct typed source ID.
a.db.locale="zhCN"
assert(a.quests[92819].start.npcID==253279 and a.SourceName(a.quests[92819].start)==nil)
-- Every actual starter displays the reviewed Chinese name; finisher-only descriptors are covered above.
local starters=0
for _,saved in ipairs(points)do if saved.role=="start"then
 render(saved.id);assert(visible(reviewed.zhCN[saved.npc]));starters=starters+1
end end
assert(starters==32,"starter inventory stays separate from finishers")
-- Missing Lydros coordinates remain missing; naming must not invent a route.
render(7463);local lydros=a.quests[7463].start
assert(not lydros.mapID and not lydros.x and not lydros.y)
assert(not(u.giverAction and u.giverAction.place and u.giverAction.place.mapID),"localized Lydros must not gain a map destination")
local tip={}
function tip:SetOwner(o)self.owner=o end;function tip:IsOwned(o)return self.owner==o end
function tip:SetText(t)self.title=t end;function tip:AddLine(t)self.body=t end
function tip:Show()self.shown=true end;function tip:Hide()self.shown=false end
GameTooltip=tip
local function guide()
 for _,o in ipairs(f.objects)do if o.title and o.note and o.label and o.scripts.OnUpdate then return o end end
end
for _,s in ipairs(samples)do if s[1]~=14368 then
 render(s[2]);local p=a.quests[s[2]].start;local before=#routes
 local contact=ownContact("start");assert(p.mapID and p.x and p.y and contact.enabled and contact.scripts.OnClick)
 local hint=sourceHint();hint.scripts.OnEnter();assert(tip.shown and tip.owner==hint and tip.body:find(reviewed.zhCN[s[1]],1,true))
 assert(#routes==before);contact.scripts.OnClick()
 assert(#routes==before+1 and routes[#routes].place==p and routes[#routes].id==s[2])
 local g=assert(guide());assert(g:IsShown()and g.note.text:find(reviewed.zhCN[s[1]],1,true));nav.Stop()
end end
assert(#routes==4)
local hydrates=0;C_QuestLog.RequestLoadQuestByID=function()hydrates=hydrates+1 end
local selected,context,plan=u.quest,u.engine,u.currentPlan
for index,locale in ipairs(locales)do
 local s=samples[(index-1)%#samples+1];a.db.locale=locale
 local label=reviewed[locale]and reviewed[locale][s[1]]or s[3];local signature
 for _,query in ipairs({label,s[3]})do
  u.search=query;u:RefreshDungeons();local found={}
  for _,card in ipairs(u.cards)do if card:IsShown()then
   local r=card.catalogResult;found[#found+1]=r.dungeon.key..":"..tostring(r.questID)..":"..tostring(r.relatedRootID)
   assert(r.count==counts[r.dungeon],"support search cannot add dungeon targets")
  end end
  table.sort(found);local actual=table.concat(found,"|")
  if signature then assert(signature==actual,"canonical/localized source association must agree")else signature=actual end
  if s[1]~=16013 and s[1]~=16012 then assert(#found>0,"actual root-bearing source must remain discoverable")end
 end
 assert(u.quest==selected and u.engine==context and u.currentPlan==plan and #routes==4)
end
assert(hydrates==0,"source discovery must not request quest hydration")
for _,saved in ipairs(points)do
 local q=a.quests[saved.id];local p=q[saved.role]
 assert(p==saved.p and p.npcID==saved.npc and p.name==saved.name and p.mapID==saved.map and p.x==saved.x and p.y==saved.y and p.zoneName==saved.zone)
 assert(q.requirementsKnown==saved.known and q.classes==saved.classes and q.races==saved.races and q.factions==saved.factions and q.requires==saved.requires)
end
for d,n in pairs(counts)do assert(#d.quests==n)end
nav.Start=start
print("Beta giver names UI: PASS (65 typed descriptors,31 reviewed labels,ten locales,four exact routes,no invented Lydros route)")
