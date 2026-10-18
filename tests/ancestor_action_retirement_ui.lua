-- Native writes cannot publish or activate an ancestor cue from an expired card.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
issecretvalue=function()return false end
C_Timer={After=function()end}
GetLocale=function()return"enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();a.db.locale="enUS";ui.includeUnavailable=true
local owners={};for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=d end end
local token,ready={},true
a.Context=function()
 local own=token
 return{level=60,class="MAGE",faction="Alliance",race=3,current=function()return own==token end,
 completed=function()return false end,active=function(id)return id==141 end,ready=function(id)return ready and id==141 end}
end
local routes=0
a.Navigation={Start=function()routes=routes+1 end,Map=function()routes=routes+1 end}
local function render(id,status)
 token={};ready=status~="ACTIVE"
 ui.dungeon,ui.quest=assert(owners[id]),id;ui.questTreeRoot,ui.questTreeDungeon=nil,nil;ui:Refresh()
end
local function cue()
 local control=ui.ancestorActionButton
 assert(control and control:IsShown()and control.enabled and control.scripts.OnClick,
 "actual166 target needs the known held141 inspection cue")
 return control
end
render(166,"READY")
local button=cue()
assert(ui.action.id==141 and ui.action.kind=="turnin" and ui.engine:State(166).status=="UNKNOWN")

-- A caption setter may synchronously replace the complete detail card.
local setText=f.methods.SetText
local fired=false
button.label.SetText=function(self,text)
 if not fired then fired=true;ui:InspectQuest(92753,true)end
 return setText(self,text)
end
local retired=button.scripts.OnClick
render(166,"READY")
button.label.SetText=setText
assert(fired and ui.quest==92753 and ui.renderedQuest==92753,"caption reentry must keep the newly inspected card")
retired();assert(ui.quest==92753 and routes==0,"retired caption cannot inspect or navigate the former ancestor")
assert(not button:IsShown()or not button.enabled,"late caption write must not revive the old cue")

-- An ordinary status refresh during Show must retain the newer ACTIVE action.
render(166,"READY");button=cue();retired=button.scripts.OnClick
local show=f.methods.Show;fired=false
button.Show=function(self)
 if not fired then fired=true;render(166,"ACTIVE")end
 return show(self)
end
render(166,"READY")
button.Show=show
assert(fired and ui.quest==166 and ui.engine:State(141).status=="ACTIVE" and ui.action.kind=="complete")
retired();assert(ui.quest==166 and routes==0,"old READY click cannot act on the replacement ACTIVE card")
button=cue();assert(button.label.text:find(a.L("ACTIVE"),1,true),"the newest caption keeps the current status")
button.scripts.OnClick();assert(ui.quest==141 and ui.renderedQuest==141 and routes==0,"fresh ACTIVE cue still inspects normally")

-- The physical control identity is part of the retained click's ownership.
render(166,"READY");button=cue();retired=button.scripts.OnClick
fired=false
button.Show=function(self)
 if not fired then fired=true;ui.ancestorActionButton=CreateFrame("Button",nil,ui.detail)end
 return show(self)
end
render(166,"READY")
button.Show=show
assert(fired and ui.ancestorActionButton~=button)
retired();assert(ui.quest==166 and routes==0,"replaced physical control cannot select the old ancestor")
ui.ancestorActionButton=button
render(166,"READY");cue().scripts.OnClick()
assert(ui.quest==141 and ui.renderedQuest==141 and routes==0,"normal rendering recovers after control replacement")
print("Ancestor action retirement: PASS (fired native caption/Show reentry, physical ownership and fresh inspection recovery)")
