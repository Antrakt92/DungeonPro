-- Single-stream source/native writes retain the newest card and reading owner.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return"enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();a.db.locale="enUS";ui.includeUnavailable=true
assert(type(ui.SetDetailTab)=="function","legacy entry point cannot restore hidden modes")
local owners={};for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=d end end
assert(not owners[2933],"Venom Bottles remains a standalone support definition")
-- Explicit inspection context, without adding a dungeon target or graph edge.
owners[2933]=assert(owners[166])
-- The held Defias predecessor is inspected within its existing target's dungeon.
owners[141]=owners[141]or owners[166]
local token={}
a.Context=function()
 local own=token
 return{level=60,class="MAGE",faction="Alliance",race=3,current=function()return own==token end,
 completed=function()return false end,active=function(id)return id==141 end,ready=function(id)return id==141 end}
end
a.Description=function()return "A readable story supplied by the current quest text adapter."end
a.DialogueText=function()return nil end
local routes=0
a.Navigation={Start=function()routes=routes+1 end,Map=function()routes=routes+1 end}
function ui.detailScroll:GetVerticalScroll()return self.verticalScroll or 0 end
function ui.detailScroll:GetHeight()return 100 end
local function render(id)
 token={};ui.dungeon,ui.quest=assert(owners[id]),id;ui.questTreeRoot,ui.questTreeDungeon=nil,nil;ui:Refresh()
 assert(ui.quest==id and ui.renderedQuest==id)
end
local function visibleText(fragment)
 for _,line in ipairs(ui.details)do if line:IsShown()and line.text and line.text:find(fragment,1,true)then return line end end
end
local function sourceRow()
 local row=ui.startButtons and ui.startButtons[1]
 assert(row and row:IsShown()and row.enabled and row.scripts.OnClick,
 "actual Venom Bottles additional source remains actionable in its current stream")
 return row
end

-- Source focus is one stream scroll intent even for the already selected quest.
render(2933)
local history=ui.detailHistory;local count=#history
ui.detailScroll:SetVerticalScroll(35)
ui:InspectQuest(2933,true,true)
assert(ui.detailTab=="quest"and ui.detailHistory==history and #history==count)
sourceRow()
ui:SetDetailTab("quest")
assert(ui.detailScroll.verticalScroll==0,"missing acquisition anchor uses bounded top fallback in the same stream")
ui:SetDetailTab("sources")
ui.detailScroll:SetVerticalScroll(67)
ui:InspectQuest(141,true)
assert(ui.quest==141 and ui.detailTab=="quest")
assert(ui:BackQuest()and ui.quest==2933 and ui.detailTab=="quest"and ui.detailScroll.verticalScroll==67,
 "Back restores the same selected stream and reading offset")
local offset=ui.detailScroll.verticalScroll
ui:RefreshDetail();assert(ui.detailTab=="quest"and ui.detailScroll.verticalScroll==offset)

-- A native actual source caption can finish a newer quest before its old write returns.
local label=sourceRow().title
local nativeText=f.methods.SetText;local fired=false
label.SetText=function(self,value)
 if not fired then fired=true;ui:InspectQuest(92753,true)end
 return nativeText(self,value)
end
ui:RefreshDetail();label.SetText=nativeText
assert(fired and ui.quest==92753 and ui.renderedQuest==92753 and ui.detailTab=="quest")
assert(not ui.startButtons[1]:IsShown()or not ui.startButtons[1].enabled,"late source caption cannot revive old source row over newer quest")
-- A late actual source Show cannot replace a newly inspected quest.
render(2933);local button=sourceRow();local nativeShow=f.methods.Show;fired=false
button.Show=function(self)
 if not fired then fired=true;ui:InspectQuest(92753,true)end
 return nativeShow(self)
end
ui:RefreshDetail();button.Show=nativeShow
assert(fired and ui.quest==92753 and ui.renderedQuest==92753 and ui.detailTab=="quest","late source Show preserves new selected card")
-- Route callbacks belong to the source pane that displayed them.
render(2933);ui:SetDetailTab("sources")
local row=sourceRow();local oldSource=row.scripts.OnClick
ui:RefreshDetail();oldSource(row)
assert(ui.quest==2933 and ui.detailTab=="quest"and routes==0,"retired source cannot navigate after a newer detail render")
ui:SetDetailTab("sources");row=sourceRow();row.scripts.OnClick(row)
assert(routes==1,"a freshly rendered source row remains usable")

render(141)
local finish=assert(ui.turnin);assert(finish:IsShown()and finish.enabled and finish.scripts.OnClick)
local oldTurnin=finish.scripts.OnClick
ui:RefreshDetail();oldTurnin(finish)
assert(ui.quest==141 and ui.detailTab=="quest"and routes==1,"retired READY control cannot dispatch after a newer detail render")
ui:SetDetailTab("quest");finish=ui.turnin;finish.scripts.OnClick(finish)
assert(routes==2,"a current READY stream retains its separate exact turn-in route")

-- An expired character context retires actual retained source input.
render(2933);local stale=sourceRow().scripts.OnClick
token={};stale(sourceRow())
assert(ui.quest==2933 and ui.detailTab=="quest"and routes==2)
render(166);local sameCount=#ui.detailHistory;ui:SetDetailTab("sources")
assert(ui.detailTab=="quest"and #ui.detailHistory==sameCount,"quiet compatibility aliases do not manufacture history")
-- Reading the old pane's offset can itself select a new card.
render(2933);ui:SetDetailTab("quest")
local scroll=ui.detailScroll;local nativeOffset=scroll.GetVerticalScroll
fired=false
scroll.GetVerticalScroll=function(self)
 if not fired then fired=true;ui:InspectQuest(92753,true)end
 return nativeOffset(self)
end
ui:InspectQuest(141,true)
scroll.GetVerticalScroll=nativeOffset
assert(fired and ui.quest==92753 and ui.renderedQuest==92753 and ui.detailTab=="quest",
 "inspection offset getter cannot supersede a newly inspected card")

-- A real completion-material relationship is neutral context, never a duplicate selector.
owners[1654]=owners[1654]or owners[166]
local function materialLine()
 local found=false;for _,entry in ipairs(a.quests[1654].completionQuests)do if entry.id==1442 and entry.itemID==7083 then found=true end end
 assert(found,"actual Seeking the Kor Gem completion relationship is unchanged")
 local line=assert(visibleText(a.QuestName(1442)),"actual completion-material name remains visible as neutral context")
 for _,row in ipairs(ui.materialButtons or{})do assert(not row:IsShown()and not row.enabled and row.scripts.OnClick==nil,"no duplicate material selector survives")end
 return line
end
for _,method in ipairs({"SetText","Show"})do
 render(1654);local material=materialLine();local native=material[method];fired=false;local expected
 material[method]=function(self,...)
  if not fired then
   fired=true;ui:InspectQuest(92753,true)
   local point={};for i,v in ipairs(self.point or{})do point[i]=v end
   expected={text=self.text,shown=self:IsShown(),width=self.width,height=self.height,point=point}
  end
  return native(self,...)
 end
 ui:RefreshDetail();material[method]=native
 assert(fired and expected and ui.quest==92753 and ui.renderedQuest==92753 and ui.detailTab=="quest","actual neutral material native callback must finish new selection")
 assert(material.text==expected.text and material:IsShown()==expected.shown and material.width==expected.width and material.height==expected.height,"late material native write cannot overwrite new label or geometry")
 for i,v in ipairs(expected.point)do assert(material.point[i]==v,"late material anchor cannot overwrite newer geometry")end
 assert(routes==2,"neutral material context does not navigate")
end
render(1654);materialLine();assert(ui.quest==1654 and routes==2,"neutral context leaves central selection and routes unchanged")
print("Single-stream retirement: PASS (source caption/Show, sourceFocus/history, current source/READY routes and neutral material native ownership)")
