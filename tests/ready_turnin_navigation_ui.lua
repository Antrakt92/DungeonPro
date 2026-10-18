-- A READY quest's distinct, known finisher must be reachable from its visible card.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
C_Timer={After=function()end}
issecretvalue=function()return false end
GetLocale=function()return"enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();a.db.locale="enUS";ui.includeUnavailable=true
local owners={}
for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=owners[id]or d end end
assert(a.quests[4322].storyline[2]==6402)
owners[6402]=assert(owners[4322]) -- actual Windsor supporting story, not an invented target
local held,ready,token
a.Context=function()
    local own=token
    return{level=60,faction="Horde",class="MAGE",current=function()return own==token end,
        completed=function()return false end,active=function(id)return id==held end,ready=function(id)return id==ready end}
end
local visits,maps={},{}
local start=function(action)visits[#visits+1]=action;return true end
a.Navigation={Start=start,Map=function(point)maps[#maps+1]=point;return true end}
local function render(id,status)
    token={};held=id;ready=status=="READY"and id or nil
    ui.dungeon,ui.quest=assert(owners[id]),id
    ui.questTreeRoot,ui.questTreeDungeon=nil,nil
    ui:Refresh()
    assert(ui.quest==id and ui.renderedQuest==id and ui.engine:State(id).status==status)
end
local function button()
    local control=ui.turnin
    assert(control and control:IsShown()and control.enabled and control.scripts.OnClick,
        "READY known distinct finisher needs an enabled direct navigation action")
    return control
end
local function noTurnin()
    assert(not ui.turnin or not ui.turnin:IsShown()or not ui.turnin.enabled,
        "no automatic destination when there is no single known READY finisher")
end
render(5724,"READY")
local q=a.quests[5724]
assert(q.start.npcID==11834 and q.start.mapID==nil and q.finish.npcID==11833 and q.finish.mapID==1456)
assert(ui.action.kind=="turnin"and ui.action.place==q.finish and not ui.giver.enabled,
    "actual planner knows Rahauro while the separate Maur pickup source remains mapless")
local turnin=button()
assert(turnin:GetWidth()==24 and turnin:GetHeight()==24,"turn-in action uses a compact inline icon")
local quest,dungeon,history=ui.quest,ui.dungeon,ui.detailHistory
turnin.scripts.OnClick()
assert(#visits==1 and visits[1].id==5724 and visits[1].kind=="turnin"and visits[1].place==q.finish,
    "visible action dispatches the inspected quest's exact typed finish")
assert(ui.quest==quest and ui.dungeon==dungeon and ui.detailHistory==history and ui.frame:IsShown())
local retired=turnin.scripts.OnClick
render(6402,"READY")
retired();assert(#visits==1,"selection replacement retires the former turn-in action")
q=a.quests[6402]
button().scripts.OnClick()
assert(#visits==2 and visits[2].id==6402 and visits[2].place==q.finish and q.finish.npcID==12580 and q.finish.mapID==1453)
ui.giver.scripts.OnClick()
assert(#visits==3 and visits[3].place==q.start and q.start.npcID==9560 and q.start.mapID==1428,
    "the existing pickup-giver action keeps its independent Maxwell endpoint")

render(5724,"READY");q=a.quests[5724];retired=button().scripts.OnClick
local x=q.finish.x;q.finish.x=x+.1;retired();assert(#visits==3,"in-place source changes expire retained clicks")
q.finish.x=x;ui:RefreshDetail();retired=button().scripts.OnClick
local char=a.char;a.char={};retired();assert(#visits==3,"another character cannot use the former action")
a.char=char;ui:RefreshDetail();retired=button().scripts.OnClick
local replacedCalls=0
a.Navigation.Start=function()replacedCalls=replacedCalls+1;return true end
retired();assert(#visits==3 and replacedCalls==0,"changed navigation capability retires its old binding")
a.Navigation.Start=start

-- Controlled capability variants preserve exact source ownership without invented coordinates.
local finish=q.finish
local mapOnly={};for key,value in pairs(finish)do mapOnly[key]=value end
mapOnly.x,mapOnly.y=nil,nil;q.finish=mapOnly
render(5724,"READY");button().scripts.OnClick()
assert(#maps==1 and maps[1]==mapOnly and #visits==3,"map-only finisher opens its own known map")
mapOnly.mapID=nil;ui:RefreshDetail();noTurnin()
assert(#maps==1 and #visits==3)
q.finish=finish
render(5724,"ACTIVE");noTurnin()
render(3801,"READY")
assert(a.quests[3801].finish==nil and #a.quests[3801].finishAlternatives==2)
noTurnin();assert(#maps==1 and #visits==3,"manual alternatives are never auto-selected")
render(2201,"READY")
assert(a.quests[2201].finish.objectID==112877 and a.quests[2201].finish.summonItem.itemID==7667)
noTurnin();assert(#maps==1 and #visits==3,"item-created objects do not gain a historical spawn route")

-- The separate action identifies turn-in, rather than pickup, in every supported UI language.
local oldTip=GameTooltip
local tip={}
function tip:SetOwner(owner)self.owner=owner end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetText(text)self.title=text end
function tip:AddLine(text)self.body=text end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","itIT","koKR","zhCN","zhTW"})do
    a.db.locale=locale;render(5724,"READY")
    local control=button();control.scripts.OnEnter(control)
    assert(tip.shown and tip.owner==control and tip.title==a.L("VISIT_TURNIN") and
        tip.title~=a.L("VISIT_GIVER") and tip.body and tip.body:find("70.4",1,true),
        "localized finisher hint must keep its separate role and exact destination")
    control.scripts.OnLeave(control)
end
GameTooltip=oldTip;a.db.locale="enUS"

-- A late native Show cannot revive the control after the quest becomes unfinished.
render(5724,"READY");turnin=button()
local show,armed,fired=f.methods.Show,true,false
f.methods.Show=function(self)
    if self==turnin and armed then armed,fired=false,true;render(5724,"ACTIVE")end
    return show(self)
end
ui:RefreshDetail();f.methods.Show=show
assert(fired and ui.engine:State(5724).status=="ACTIVE")
noTurnin()
print("READY turn-in navigation: PASS (actual distinct finishers, own routes, pickup separation, stale inputs and honest unavailable sources)")
