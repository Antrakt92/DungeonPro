-- Dungeon selection leaves quest discovery in the central column.
-- Actual TOC with modeled native controls; no in-game pixel claim.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u,m=f.addon,f.addon.UI,f.methods
for _,key in ipairs({"CreateFontString","CreateTexture"})do
 local original=m[key]
 m[key]=function(self,...)local value=original(self,...);value.parent=self;value.shown=true;return value end
end
issecretvalue=function()return false end;GetLocale=function()return"enUS"end
C_Timer={After=function()end}
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle()
a.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
u.range=false;u.includeUnavailable=true
local dungeon
for _,d in ipairs(a.dungeons)do if d.key=="dalaran"then dungeon=d end end
assert(dungeon and a.quests[92458],"actual dungeon and quest required")
local narrative="Selected quest journal narrative marker."
a.Description=function(id)if id==92458 then return narrative end end
a.DialogueText=nil
local routes,overviewReads,overviewPaints=0,0,0
a.Navigation={Start=function()routes=routes+1;return true end,Map=function()routes=routes+1;return true end}
local overview=u.RenderPreparationOverview
u.RenderPreparationOverview=function(self,...)
 overviewReads=overviewReads+1;return overview(self,...)
end
local painter=a.PaintDungeonArt
a.PaintDungeonArt=function(texture,d,scope,...)
 if scope=="overview"then overviewPaints=overviewPaints+1 end
 if painter then return painter(texture,d,scope,...)end
end
local function visibleFields()
 local out={};for _,field in ipairs(u.details or{})do if field:IsShown()then out[#out+1]=field end end;return out
end
local function text(value)
 for _,field in ipairs(visibleFields())do if field.text==value then return field end end
end
local function middle()
 local out={}
 for _,row in ipairs(u.rows or{})do if row:IsShown()then
  out[#out+1]=table.concat({tostring(row.questID),tostring(row.questTreeNode),tostring(row.heading),tostring(row.title.text)},"|")
 end end
 return table.concat(out,"\n")
end
local function selectDungeon()
 u.search="";u:RefreshDungeons()
 local card
 for _,row in ipairs(u.cards)do if row:IsShown()and row.entranceDungeon==dungeon then card=row end end
 assert(card and card.scripts.OnClick,"actual catalogue card must be clickable")
 card.scripts.OnClick(card,"LeftButton",false)
 assert(u.dungeon==dungeon and u.quest==nil and a.char.selectedDungeon==dungeon.key,"catalogue selection retains exact dungeon and clears quest")
end
local function noControls(pool)
 for _,control in ipairs(pool or{})do
  assert(not control:IsShown(),"retired right-pane quest controls are hidden")
  if control.scripts then assert(not control.enabled and control.scripts.OnClick==nil,"retired right-pane quest controls are inert")end
 end
end
local function compact()
 assert(u.dungeon==dungeon and u.quest==nil and u.renderedQuest==nil,"overview owns no selected quest")
 assert(overviewReads==0 and overviewPaints==0,"compact overview does not hydrate duplicate preparation rows or dungeon artwork")
 local fields=visibleFields()
 assert(#fields==3,"right overview contains only dungeon title, level range and quest-selection prompt")
 assert(fields[1].text==a.DungeonName(dungeon)and fields[1].detailStyle=="title","dungeon title is the only right-pane heading")
 assert(fields[2].text==a.L("CATALOG_LEVELS",dungeon.minLevel,dungeon.maxLevel),"actual dungeon range remains readable")
 assert(fields[3].text==a.L("OVERVIEW_PICK"),"existing localized prompt directs quest selection to the middle column")
 assert(not text(narrative)and not text(a.quests[92458].name),"old selected quest title and prose cannot survive overview selection")
 assert(u.action==nil and u.giverAction==nil and u.overviewBinding==nil,"overview publishes no quest action or duplicate preparation binding")
 assert(not u.overviewArt or not u.overviewArt:IsShown(),"overview does not show large dungeon artwork")
 for _,key in ipairs({"overviewMoreButton","overviewFewerButton","overviewMapControl","source"})do
  local control=u[key];assert(not control or not control:IsShown(),"compact overview has no extra right-pane actions: "..key)
 end
 noControls(u.actionInspectButtons);noControls(u.overviewTexts)
 for _,pool in ipairs({u.detailContactRows,u.objectiveButtons,u.rewardButtons})do
  for _,control in ipairs(pool or{})do assert(not control:IsShown(),"previous selected quest controls retire")end
 end
 for _,section in pairs(u.detailJournalSections or{})do assert(not section:IsShown(),"previous quest journal surfaces retire")end
end
local function inspectCentral()
 local selected
 for _,row in ipairs(u.rows)do if row:IsShown()and row.questID==92458 then selected=row end end
 assert(selected and selected.scripts.OnClick,"actual selected quest remains available in the middle column")
 selected.scripts.OnClick(selected,"LeftButton",false)
 assert(u.quest==92458 and u.renderedQuest==92458 and text(narrative),"actual central quest click still opens the selected journal")
 local title=assert(text(a.QuestName(92458)));assert(title.detailStyle=="title","selected quest retains journal title")
 local contact=assert(u.detailContactRows[1]);local binding=assert(contact.detailContactBinding)
 assert(contact:IsShown()and binding.questID==92458 and binding.endpoint==a.quests[92458].start and binding.current(),"selected journal retains exact current pickup contact")
 assert(u.questTreeRoot==92458 and u.questTreeDungeon==dungeon,"actual central root is expanded before testing tree preservation")
 local before,root,owner=middle(),u.questTreeRoot,u.questTreeDungeon
 u:RefreshDetail()
 assert(before==middle()and u.questTreeRoot==root and u.questTreeDungeon==owner,"right journal redraw preserves central quest tree and selection")
 return before
end
local localeCount=0
for _,includeUnavailable in ipairs({false,true})do
 u.includeUnavailable=includeUnavailable
for code in pairs(a.locales)do
 localeCount=localeCount+1
 a.db.locale=code;selectDungeon();compact()
 local before=middle();assert(before~="","dungeon selection retains central quest discovery")
 u:RefreshDetail();compact();assert(before==middle(),"compact overview redraw does not replace the central quest list")
 inspectCentral();selectDungeon();compact();inspectCentral()
end
end
assert(localeCount==20,"all ten supported locales and both character filters exercise overview and journal transitions")
assert(routes==0,"overview, central inspection and journal transitions never dispatch navigation automatically")
print("PASS compact dungeon overview: title/range/prompt only; no duplicate right quests/actions/art; central discovery and journal transitions retained in ten locales (modeled only)")
