-- Contextual detail tabs retain the newest pane, card and reading owner.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return"enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();a.db.locale="enUS";ui.includeUnavailable=true
assert(type(ui.SetDetailTab)=="function","detail sections need one context-aware tab entry point")
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
local function tabs()
 local controls=assert(ui.detailTabButtons)
 for _,key in ipairs({"quest","sources","story"})do assert(controls[key]and controls[key].label and controls[key].scripts.OnClick)end
 return controls
end
local function sourceRow()
 local row=ui.startButtons and ui.startButtons[1]
 assert(row and row:IsShown()and row.enabled and row.scripts.OnClick,
 "actual Venom Bottles additional source must be actionable in its Sources pane")
 return row
end

-- Source focus is a pane choice even when inspection keeps the same quest.
render(2933)
local history=ui.detailHistory;local count=#history
ui.detailScroll:SetVerticalScroll(35)
ui:InspectQuest(2933,true,true)
assert(ui.detailTab=="sources"and ui.detailHistory==history and #history==count)
sourceRow()
ui:SetDetailTab("quest")
assert(ui.detailScroll.verticalScroll==35,"same-quest source focus must preserve the previous Quest reading offset")
ui:SetDetailTab("sources")
ui.detailScroll:SetVerticalScroll(67)
ui:InspectQuest(141,true)
assert(ui.quest==141 and ui.detailTab=="quest")
assert(ui:BackQuest()and ui.quest==2933 and ui.detailTab=="sources"and ui.detailScroll.verticalScroll==67,
 "Back must restore a matching Sources pane and reading offset")
local offset=ui.detailScroll.verticalScroll
ui:RefreshDetail();assert(ui.detailTab=="sources"and ui.detailScroll.verticalScroll==offset)

-- Changing the pane inside a native caption write owns the remaining render.
local controls=tabs();local label=controls.sources.label
local nativeText=f.methods.SetText;local fired=false
label.SetText=function(self,value)
 if not fired then fired=true;ui:SetDetailTab("story")end
 return nativeText(self,value)
end
ui:RefreshDetail()
label.SetText=nativeText
assert(fired and ui.quest==2933 and ui.renderedQuest==2933 and ui.detailTab=="story")
assert(not ui.startButtons[1]:IsShown()or not ui.startButtons[1].enabled,
 "late Sources rendering cannot revive a source row over the newer Story pane")

-- A late tab-button Show cannot replace a newly inspected quest.
ui:SetDetailTab("sources");controls=tabs()
local nativeShow=f.methods.Show;local button=controls.sources;fired=false
button.Show=function(self)
 if not fired then fired=true;ui:InspectQuest(92753,true)end
 return nativeShow(self)
end
ui:RefreshDetail()
button.Show=nativeShow
assert(fired and ui.quest==92753 and ui.renderedQuest==92753 and ui.detailTab=="quest",
 "late tab geometry must keep the new quest and its default pane")

-- Route callbacks belong to the source pane that displayed them.
render(2933);ui:SetDetailTab("sources")
local row=sourceRow();local oldSource=row.scripts.OnClick
ui:SetDetailTab("quest");oldSource(row)
assert(ui.quest==2933 and ui.detailTab=="quest"and routes==0,"retired source cannot navigate through another pane")
ui:SetDetailTab("sources");row=sourceRow();row.scripts.OnClick(row)
assert(routes==1,"a freshly rendered source row remains usable")

render(141)
local finish=assert(ui.turnin);assert(finish:IsShown()and finish.enabled and finish.scripts.OnClick)
local oldTurnin=finish.scripts.OnClick
ui:SetDetailTab("story");oldTurnin(finish)
assert(ui.quest==141 and ui.detailTab=="story"and routes==1,"retired Quest turn-in cannot dispatch from Story")
ui:SetDetailTab("quest");finish=ui.turnin;finish.scripts.OnClick(finish)
assert(routes==2,"a current READY Quest pane retains its own turn-in route")

-- An expired character context also retires retained tab input.
render(166);local stale=tabs().sources.scripts.OnClick
token={};stale(tabs().sources)
assert(ui.quest==166 and ui.detailTab=="quest"and routes==2)
render(166);local sameCount=#ui.detailHistory;ui:SetDetailTab("sources")
assert(ui.detailTab=="sources"and #ui.detailHistory==sameCount,
 "same-quest tab changes do not manufacture inspection history")

-- Reading the old pane's offset can itself select a new card.
render(2933);ui:SetDetailTab("quest")
local scroll=ui.detailScroll;local nativeOffset=scroll.GetVerticalScroll
fired=false
scroll.GetVerticalScroll=function(self)
 if not fired then fired=true;ui:InspectQuest(92753,true)end
 return nativeOffset(self)
end
ui:InspectQuest(2933,true,true)
scroll.GetVerticalScroll=nativeOffset
assert(fired and ui.quest==92753 and ui.renderedQuest==92753 and ui.detailTab=="quest",
 "source-focus offset getter cannot supersede a newly inspected card")

-- A real completion-material row must not finish painting over a newer Story.
owners[1654]=owners[1654]or owners[166]
render(1654);ui:SetDetailTab("sources")
local material=assert(ui.materialButtons[1])
assert(material.questID==1442 and material:IsShown()and material.enabled,
 "The Test of Righteousness retains its actual Seeking the Kor Gem material link")
local materialClick=assert(material.scripts.OnClick)
ui:SetDetailTab("quest");fired=false
material.title.SetText=function(self,value)
 if not fired then fired=true;ui:SetDetailTab("story")end
 return nativeText(self,value)
end
ui:SetDetailTab("sources")
material.title.SetText=nativeText
assert(fired and ui.quest==1654 and ui.renderedQuest==1654 and ui.detailTab=="story")
assert(not material:IsShown()or not material.enabled,
 "late completion-material paint cannot revive a Sources row over Story")
materialClick(material)
assert(ui.quest==1654 and routes==2,"retired material link cannot inspect another quest from Story")
ui:SetDetailTab("sources");material=ui.materialButtons[1]
ui:SetDetailTab("quest");fired=false
material.Show=function(self)
 if not fired then fired=true;ui:SetDetailTab("story")end
 return nativeShow(self)
end
ui:SetDetailTab("sources")
material.Show=nativeShow
assert(fired and ui.quest==1654 and ui.renderedQuest==1654 and ui.detailTab=="story")
assert(not material:IsShown()or not material.enabled,
 "late native completion-material Show cannot revive the previous Sources row")
ui:SetDetailTab("sources");material=ui.materialButtons[1];material.scripts.OnClick(material)
assert(ui.quest==1442 and ui.renderedQuest==1442 and ui.detailTab=="quest"and routes==2,
 "a fresh material link still inspects its exact support quest without navigation")
print("Detail tabs retirement: PASS (fired caption/Show reentry, source focus/history coherence and pane-owned routes)")
