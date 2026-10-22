-- Reviewed NPC labels follow the selected language without changing quest sources.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
-- Native FontStrings are shown on creation; journal purpose is its own region.
local createFontString=f.methods.CreateFontString
function f.methods:CreateFontString(...)local value=createFontString(self,...);value.shown=true;return value end
issecretvalue=function()return false end;GetLocale=function()return"enUS"end;C_Timer={After=function()end}
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle();ui.includeUnavailable=true
local owners={}
local function visit(id,dungeon,seen)
 if seen[id]then return end;seen[id]=true;owners[id]=owners[id]or dungeon
 local q=assert(a.quests[id])
 for _,group in ipairs(q.requires or{})do for _,parent in ipairs(group.ids)do visit(parent,dungeon,seen)end end
 for _,other in ipairs(q.storyline or{})do visit(other,dungeon,seen)end
 for _,group in ipairs(q.storylineGroups or{})do for _,other in ipairs(group)do visit(other,dungeon,seen)end end
end
for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do visit(id,d,{})end end
local ready
a.Context=function()local held=ready;return{level=60,faction="Alliance",class="MAGE",
 completed=function()return false end,active=function(id)return id==held end,ready=function(id)return id==held end}end
a.ItemName=function(id)return"Native item "..id end;a.ItemIcon=function()return 134400 end;a.CarriedItemCount=function()return 0 end
local nativeName="Native client Riell"
UnitGUID=function(unit)if unit=="npc"then return"Creature-0-0-0-0-820-0000000000"end end
UnitName=function(unit)if unit=="npc"then return nativeName end end
C_CreatureInfo=C_CreatureInfo or{};C_CreatureInfo.GetCreatureID=function()return 820 end
local tip={}
function tip:SetOwner(owner)self.owner=owner end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetText(text)self.title=text end
function tip:AddLine(text)self.body=text end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip
local nav=a.Navigation;local start=nav.Start;local actions={}
nav.Start=function(action)actions[#actions+1]=action;return start(action)end
local function render(id,ending)
 ready=ending and id or nil;ui.quest,ui.dungeon=id,assert(owners[id]);ui:Refresh()
 if ui.detailTab~="quest"then assert(ui:SetDetailTab("quest"))end
 assert(ui.quest==id and ui.renderedQuest==id)
end
local function visible(text)
 for _,field in ipairs(ui.details)do if field:IsShown()and field.text and field.text:find(text,1,true)then return true end end
 for index=1,2 do local contact=ui.detailContactRows and ui.detailContactRows[index];if contact and contact:IsShown()and(contact.title.text:find(text,1,true)or contact.note.text:find(text,1,true))then return true end end
end
local function ownContact(field)
 local q=assert(a.quests[ui.quest]);local point=assert(q[field]);local contact=assert(ui.detailContactRows[field=="start"and 1 or 2])
 local binding=assert(contact.detailContactBinding)
 assert(contact:IsShown()and binding.questID==q.id and binding.field==field and binding.endpoint==point and binding.current(),"actual contact owns exact selected source")
 local purpose=assert(contact.detailPurpose,"contact purpose is a distinct region")
 assert(not purpose:IsShown()and purpose.text==a.L(field=="start"and "DETAIL_GIVER"or"DETAIL_TURNIN"),"current source purpose remains independently available for its tooltip")
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

local samples={
 {166,"start",234},{214,"start",820},{1491,"start",3446},{2204,"finish",6826},
 {2933,"finish",2216},{98423,"finish",2784},{4322,"finish",9560},{2202,"start",6868},
 {2846,"start",6546},{8257,"start",8405},{5726,"start",4949},{1109,"start",2055},
}
local expected={
 ruRU={[234]="Гриан Камнегрив",[820]="Разведчица Риэла",[3446]="Мебок Миззрикс",[6826]="Талваш де Киссель",
  [2216]="Аптекарь Лидон",[2784]="Король Магни Бронзобород",[9560]="Маршал Максвелл",[6868]="Джаркал Замшелый Клык",
  [6546]="Табета",[8405]="Огтинк",[4949]="Тралл",[2055]="Мастер аптекарь Фаранелл"},
 zhCN={[234]="格里安·斯托曼",[820]="哨兵瑞尔",[3446]="麦伯克·米希瑞克斯",[6826]="塔瓦斯德·基瑟尔",
  [2216]="药剂师林度恩",[2784]="国王麦格尼·铜须",[9560]="麦克斯韦尔元帅",[6868]="加卡尔",
  [6546]="塔贝萨",[8405]="奥汀克",[4949]="萨尔",[2055]="大药剂师法拉尼尔"},
 frFR={[820]="Eclaireur Riell",[2216]="Apothicaire Lydon",[2784]="Roi Magni Bronzebeard",
  [9560]="Maréchal Maxwell",[2055]="Maître apothicaire Faranell"},
}
local total=0
for _,locale in ipairs({"ruRU","zhCN","frFR"})do
 a.db.locale=locale
 for _,sample in ipairs(samples)do
  local id,role,npc=unpack(sample);local name=expected[locale][npc]
  if name then
   local point=assert(a.quests[id][role]);assert(point.npcID==npc and not point.objectID and not point.itemID)
   local source,map,x,y,zone=point.name,point.mapID,point.x,point.y,point.zoneName
   render(id,role=="finish")
   assert(ownContact(role).title.text==name,"actual own NPC contact needs its reviewed selected-language name: "..locale.."/"..npc)
   local contact=ownContact(role)
   local control=role=="finish"and ui.turnin or contact
   assert(control and control:IsShown()and control.enabled and control.scripts.OnClick)
   local hint=role=="finish"and control or sourceHint()
   hint.scripts.OnEnter();assert(tip.shown and tip.owner==hint and tip.body:find(name,1,true),"source hint matches its exact NPC")
   local before=#actions;control.scripts.OnClick()
   local action=assert(actions[#actions]);assert(#actions==before+1 and action.id==id and action.place==point)
   local guide;for _,o in ipairs(f.objects)do if o.title and o.note and o.label and o.scripts.OnUpdate then guide=o end end
   assert(guide and guide:IsShown()and guide.note.text:find(name,1,true),"guide uses the same reviewed NPC label")
   nav.Stop()
   assert(ui:SetDetailTab("sources"));assert(visible(name),"Sources retains the same starting or finishing identity")
   assert(point.name==source and point.npcID==npc and point.mapID==map and point.x==x and point.y==y and point.zoneName==zone,
    "localized captions never rewrite identity or recorded position")
   if id==98423 then assert(visible("Native item 281030"),"item starter naming stays independent of NPC naming")end
   total=total+1
  end
 end
end
assert(total==29)
assert(a.GiverName(a.quests[214].start)==nativeName,"matching native creature adapter remains available independently")
a.db.locale="itIT";render(214)
assert(visible(nativeName),"a locale without a reviewed NPC entry preserves the matching native creature fallback")
a.db.locale="ruRU";render(214)
local selected;for _,r in ipairs(ui.rows)do if r:IsShown()and r.questID==214 then selected=r;break end end
assert(selected);selected.navigationControl.scripts.OnEnter()
assert(tip.shown and tip.body:find(expected.ruRU[820],1,true),"middle-list hint follows selected language instead of matching native NPC language")
local oldBinding=ownContact("start").detailContactBinding;local oldClick=ownContact("start").scripts.OnClick;local _,oldProof=a.SourceName(a.quests[214].start);local before=#actions
ui.language.scripts.OnEnter()
local session=assert(a.Language.session)
assert(a.Language:Commit(session,"zhCN")and a.db.locale=="zhCN")
assert(#actions==before,"committing a language refresh never starts navigation automatically")
assert(not oldBinding.current()and not oldProof(),"the actual refresh retires the former card binding and name proof")
assert(not tip.shown and visible(expected.zhCN[820])and not visible(expected.ruRU[820]),"the former hint and caption retire on language refresh")
sourceHint().scripts.OnEnter()
assert(tip.shown and tip.body:find(expected.zhCN[820],1,true),"locale refresh replaces the previous NPC hint")
oldClick();assert(#actions==before,"old language contact click stays retired")
ownContact("start").scripts.OnClick();assert(#actions==before+1 and actions[#actions].place==a.quests[214].start)
local guide;for _,o in ipairs(f.objects)do if o.title and o.note and o.label and o.scripts.OnUpdate then guide=o end end
assert(guide and guide:IsShown()and guide.note.text:find(expected.zhCN[820],1,true),"explicit fresh click routes the same NPC with the selected-language guide")
nav.Stop();nav.Start=start
print("NPC source names UI: PASS (29 actual source captions, hints, guides and typed destinations; modeled)")
