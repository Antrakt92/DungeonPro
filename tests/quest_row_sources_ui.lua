-- Real item-start and alternative-source controls inspect without inventing a route.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
function f.methods:GetVerticalScroll()return self.verticalScroll or 0 end
C_Timer={After=function()end};issecretvalue=function()return false end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle();a.db.locale="enUS"
a.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
local routes,maps=0,0
a.Navigation={Start=function()routes=routes+1;return true end,Map=function()maps=maps+1;return true end}
a.CachedQuestRewards,a.DialogueRewards,a.QuestRewards=function()end,function()end,function()end
local function row(id)
 for _,r in ipairs(ui.rows)do if r:IsShown()and r.questID==id then return r end end
 error("missing actual quest row "..id)
end
local function field(text)
 for _,v in ipairs(ui.details)do if v:IsShown()and v.text:find(text,1,true)then return v end end
end
local function choose(id,previous)
 for _,d in ipairs(a.dungeons)do for _,q in ipairs(d.quests)do if q==id then ui.dungeon=d end end end
 ui.quest=previous;ui.questTreeRoot=nil;ui.questTreeDungeon=nil;ui.includeUnavailable=true;ui:Refresh()
 return row(id)
end
local tip={}
function tip:SetOwner(owner)self.owner=owner end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetText(text)self.title=text end
function tip:AddLine(text)self.body=text end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip
local shard=choose(6981,1491)
-- Model a short viewport to exercise focus even when the unexpanded real card fits.
ui.detailScroll.GetHeight=function()return 90 end
local click=shard.navigationControl.scripts.OnClick
shard.navigationControl.scripts.OnEnter()
assert(shard.navigationControl.enabled and tip.title==a.L("SOURCE_DETAILS"),"item sources are enabled inspection, never labelled giver on map")
assert(shard.navigationControl.sourceInspect and #shard.navigationControl.footerIconParts==7,"source choice uses a book rather than a route arrow")
for _,part in ipairs(shard.navigationControl.navigationIconParts)do assert(not part:IsShown(),"navigation arrow is hidden for inspection")end
click()
assert(ui.quest==6981 and ui.renderedQuest==6981 and routes==0 and maps==0,"source click inspects its own quest without arbitrary navigation")
local source=assert(field("Mutanus the Devourer"),"recorded Mutanus acquisition source visible")
local offset=ui.detailScroll:GetVerticalScroll()
assert(offset and offset>0 and -source.point[3]>=offset and -source.point[3]<offset+90,"known acquisition text is actually within the focused viewport")
assert(not ui.referenceToggle or not ui.referenceToggle:IsShown(),"item acquisition is direct, not hidden in another drawer")
assert(ui:InspectQuest(1491,true));click();assert(ui.quest==1491,"retired row click cannot reopen an old inspected source")
local retired=row(6981).navigationControl.scripts.OnClick
local start=a.quests[6981].start
local itemID=start.itemID;start.itemID=itemID+1;retired();assert(ui.quest==1491,"changed item source expires its old inspection");start.itemID=itemID
local inspect=ui.InspectQuest;ui.InspectQuest=function()error("replaced inspector must not be invoked")end
retired();assert(ui.quest==1491,"changed inspection API expires its old control");ui.InspectQuest=inspect
local character=a.char;a.char={};retired();assert(ui.quest==1491,"changed character expires its old control");a.char=character
ui.frame:Hide();retired();assert(ui.quest==1491,"hidden planner cannot be reopened by an old source click");ui.frame:Show()
local npc=row(1491).navigationControl
assert(not npc.sourceInspect and #npc.footerIconParts==3 and npc.enabled,"real NPC retains its route arrow")
npc.scripts.OnClick();assert(routes==1 and maps==0 and ui.quest==1491)
-- Native scroll setter completes a newer inspection before the old source-focus tail resumes.
local setter,armed,fired=ui.detailScroll.SetVerticalScroll,true,false
ui.detailScroll.SetVerticalScroll=function(self,value)
 if armed and value>0 then armed,fired=false,true;ui:InspectQuest(1491,true)end
 return setter(self,value)
end
row(6981).navigationControl.scripts.OnClick()
assert(fired and ui.quest==1491 and ui.renderedQuest==1491 and ui.detailScroll:GetVerticalScroll()==0,"newer inspection wins a late source-focus scroll write")
ui.detailScroll.SetVerticalScroll=setter
local navigation=a.Navigation;a.Navigation=nil;ui:RefreshQuests()
assert(row(6981).navigationControl.enabled,"source inspection does not require a navigation capability")
row(6981).navigationControl.scripts.OnClick();assert(ui.quest==6981)
a.Navigation=navigation
local treaty=choose(98423,96394)
treaty.navigationControl.scripts.OnClick()
assert(ui.quest==98423 and field(a.L("START_ITEM_LOCATION_UNKNOWN"))and ui.detailScroll:GetVerticalScroll()==0,
 "unknown item source opens its explicit warning without a guessed giver")
local alternatives=choose(7492,7508)
alternatives.navigationControl.scripts.OnEnter()
assert(alternatives.navigationControl.enabled and tip.title==a.L("SOURCE_DETAILS")and tip.body==a.L("SOURCE_DETAILS_HINT"))
local alternativeClick=alternatives.navigationControl.scripts.OnClick
local choicesSource=a.quests[7492].startAlternatives
local original=choicesSource[1];choicesSource[1]=choicesSource[2]
alternativeClick();assert(ui.quest==7508,"changed alternative membership expires old source inspection")
choicesSource[1]=original
alternativeClick()
assert(ui.quest==7492 and ui.detailReferencesExpanded,"alternative-source inspection opens the remaining choices")
local choices=0
for _,pool in ipairs({ui.giverButtons,ui.startButtons})do for _,button in ipairs(pool)do if button:IsShown()then choices=choices+1 end end end
assert(choices==#a.quests[7492].startAlternatives,"all recorded trainer choices are immediately accessible")
assert(routes==1 and maps==0,"manual source selection never routes to a guessed first choice")
for _,r in ipairs(ui.rows)do if r:IsShown()and r.navigationControl and r.navigationControl:IsShown()then
    local c=r.navigationControl
    assert(c.sourceInspect==(r.navigationBinding.inspect==true),"recycled icon matches its current source action")
    for _,part in ipairs(c.sourceInspect and c.navigationIconParts or c.sourceIconParts or{})do assert(not part:IsShown(),"recycled source/route glyph is hidden")end
end end
-- A stable restriction checker replaces the inspector during its source proof.
local inherited=ui.InspectQuest
local oldCalls,newCalls,armed,matches,fired=0,0,false,0,false
local replacement=function()newCalls=newCalls+1;return false end
ui.InspectQuest=function(self,...)oldCalls=oldCalls+1;return inherited(self,...)end
issecretvalue=function(value)
    if armed and value==10441 then matches=matches+1;if matches==2 then fired=true;ui.InspectQuest=replacement end end
    return false
end
local control=choose(6981,1491).navigationControl
armed=true;control.scripts.OnClick();armed=false
assert(fired and oldCalls==0 and newCalls==0 and ui.quest==1491,"inspector replacement during source proof retires the pending click")
ui.InspectQuest=inherited;issecretvalue=function()return false end
-- A late old Show/Hide tail cannot leave the opposite glyph on the completed view.
control=choose(6981,1491).navigationControl
for _,mode in ipairs({true,false})do
    assert(ui:PaintQuestRowSourceIcon(control,not mode,function()return true end))
    local generation,original={},nil;original=generation
    local part=(mode and control.sourceIconParts or control.navigationIconParts)[1]
    local show,once,didFire=part.Show,true,false
    part.Show=function(self,...)
        if once then once,didFire=false,true;generation={};assert(ui:PaintQuestRowSourceIcon(control,not mode,function()return true end))end
        return show(self,...)
    end
    assert(not ui:PaintQuestRowSourceIcon(control,mode,function()return generation==original end)and didFire,"retired glyph Show callback actually fires")
    part.Show=show
    assert(control.sourceInspect==not mode and control.sourceIconDepth==0,"latest glyph owns the completed control")
    for _,piece in ipairs(mode and control.sourceIconParts or control.navigationIconParts)do assert(not piece:IsShown(),"retired glyph parts stay hidden after a late Show tail")end
end
print("Quest row source inspection: PASS (actual TOC; owned sources and modeled focus, no native layout proof)")
