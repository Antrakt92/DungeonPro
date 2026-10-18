-- Summoned object endpoints show their recorded informational item source without travel guesses.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
function f.methods:GetVerticalScroll()return self.verticalScroll or 0 end
C_Timer={After=function()end};issecretvalue=function()return false end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle();ui.includeUnavailable=true
local carried=0
local context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
a.Context=context
local routes,maps,uses,inspections=0,0,0,0
local nativeInspector=ui.InspectQuest
ui.InspectQuest=function(self,...)inspections=inspections+1;return nativeInspector(self,...)end
a.Navigation={Start=function()routes=routes+1;return true end,Map=function()maps=maps+1;return true end}
UseItemByName=function()uses=uses+1 end
C_Item={UseItemByName=function()uses=uses+1 end}
a.ItemName=function(id)return "Item "..id end
a.ItemIcon=function()return 134400 end
a.CarriedItemCount=function()return carried end
a.DialogueRewards,a.QuestRewards,a.CachedQuestRewards=function()end,function()end,function()end
local tip={}
function tip:SetOwner(owner)self.owner=owner end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetItemByID(id)self.item=id;return true end
function tip:SetText(text)self.title=text end
function tip:AddLine(text)self.body=text end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip
local owners={}
for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=owners[id]or d end end
local inspection=assert(owners[2204]or owners[2201],"actual Uldaman root association required")
local q2201,q2204=assert(a.quests[2201]),assert(a.quests[2204])
assert(q2201.finish.objectID==112877 and q2204.start.objectID==112877)
assert(not q2201.finish.mapID and not q2204.start.mapID,"no historical spawn coordinates injected")
local originalStart,originalFinish=q2204.start.summonItem,q2201.finish.summonItem
assert(originalStart and originalStart.itemID==7667 and originalFinish and originalFinish.itemID==7667,"actual production endpoints retain the independently sourced item relation")
assert(originalStart.name=="Talvash's Phial of Scrying"and originalFinish.name==originalStart.name)
local tool=originalStart
local function render(id)
 ui.dungeon,ui.quest=owners[id]or inspection,id;ui:Refresh()
 assert(ui.quest==id and ui.renderedQuest==id,"own quest stays inspected")
end
local function visible(text)
 for index,field in ipairs(ui.details)do if field:IsShown()and field.text==text then return field,index end end
end
local function row(id)
 for _,r in ipairs(ui.rows)do if r:IsShown()and r.questID==id then return r end end
 error("actual source quest row absent "..id)
end
local function binding(field)
 local found
 for _,b in ipairs(ui.objectiveButtons)do if b:IsShown()and b.objectiveBinding and b.objectiveBinding.sourceField==field then
  assert(not found,"one current source-tool icon per endpoint");found=b
 end end
 assert(found,"visible source-tool item icon")
 local proof=found.objectiveBinding
 assert(proof.id==7667 and proof.role=="source-tool"and proof.current(),"typed informational item retains its own relation")
 return found,proof
end
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","koKR","zhCN","zhTW","itIT"})do
 a.db.locale=locale
 for _,sample in ipairs({{2204,"start.summonItem"},{2201,"finish.summonItem"}})do
  carried=0;render(sample[1])
  local text=a.L("SOURCE_SUMMON_ITEM","Item 7667",a.quests[sample[1]][sample[1]==2204 and"start"or"finish"].name)
  assert(text~="SOURCE_SUMMON_ITEM"and visible(text),"localized instruction identifies exact source item and object")
  if sample[1]==2204 then assert(not ui.giver:IsShown()and not visible(a.L("GIVER_LOCATION_UNKNOWN")),"created source replaces the false fixed-location warning and route icon")end
  local _,position=visible(text)
  assert(ui.details[position+1]and ui.details[position+1]:IsShown()and ui.details[position+1].text==a.L("ITEM_CARRIED",0),"known zero bag count stays adjacent to its source instruction")
  local b= binding(sample[2]);b.scripts.OnEnter()
  assert(tip.item==7667 and tip:IsOwned(b),"source tool uses the item tooltip without using the item")
  assert(ui.engine:State(sample[1]).status~="AVAILABLE","source instruction does not promote unknown prerequisites/readiness")
  for _,other in ipairs(ui.objectiveButtons)do if other:IsShown()and other.objectiveBinding and other.objectiveBinding.id==7667 then
   assert(other.objectiveBinding.role=="source-tool","summoning tool is not a quest objective or supplied item")
  end end
  carried=nil;render(sample[1])
  local _,position=visible(text)
  local nextField=ui.details[position+1]
  assert(not nextField or not nextField:IsShown()or nextField.text~=a.L("ITEM_CARRIED",0),"unavailable bag count does not invent zero beside source instruction")
 end
end
a.db.locale="enUS"
-- Same object/tool at both endpoints contributes one instruction, without changing catalogue data.
local finish=q2204.finish
q2204.finish={objectID=112877,name=q2204.start.name,summonItem={itemID=7667,name=tool.name}}
render(2204)
local matches=0
for _,field in ipairs(ui.details)do if field:IsShown()and field.text==a.L("SOURCE_SUMMON_ITEM","Item 7667",q2204.start.name)then matches=matches+1 end end
assert(matches==1,"same summoned object and tool are not repeated at both endpoints")
q2204.finish=finish
a.db.locale="enUS";carried=0;render(2204)
local r=row(2204);local control=r.navigationControl
assert(control.enabled and control.sourceInspect,"mapless summoned-object start exposes source inspection book")
control.scripts.OnEnter();assert(tip.title==a.L("SOURCE_DETAILS")and tip.body==a.L("SOURCE_DETAILS_HINT"),"source inspection explains clicking to inspect, without a map or unseen-item instruction")
ui.detailScroll.GetHeight=function()return 90 end
local click=control.scripts.OnClick
click();assert(ui.quest==2204 and ui.renderedQuest==2204)
local text=a.L("SOURCE_SUMMON_ITEM","Item 7667",q2204.start.name)
local instruction=assert(visible(text));local offset=ui.detailScroll:GetVerticalScroll()
assert(-instruction.point[3]>=offset and -instruction.point[3]<offset+90,"book inspection focuses its own source instruction")
assert(routes==0 and maps==0 and uses==0,"instruction never invents navigation or automatically uses item")
-- Retired source, public inspector, and character contexts cannot dispatch.
render(2204);click=row(2204).navigationControl.scripts.OnClick
local oldID=tool.itemID;local inspected=inspections
tool.itemID=7668;click();tool.itemID=oldID
assert(inspections==inspected and ui.quest==2204 and routes==0 and maps==0,"changed nested source cannot dispatch old inspector")
local b,proof=binding("start.summonItem")
tool.itemID=7668;assert(not proof.current(),"nested item mutation expires tooltip ownership");tool.itemID=oldID
local reports=q2204.start.reportedLocations
q2204.start.reportedLocations={{mapID=1455,x=36,y=3.4},{mapID=1455,x=37,y=4}}
assert(not proof.current(),"a newly introduced historical spawn list expires the old summoned-source proof")
assert(not ui:SummonSource(q2204.start),"summoned-object relation cannot coexist with historical spawn destinations")
click();assert(inspections==inspected,"changed endpoint evidence cannot dispatch old source inspection")
local originalMap,originalX,originalY=q2204.start.mapID,q2204.start.x,q2204.start.y
q2204.start.mapID,q2204.start.x,q2204.start.y=1455,36,3.4
render(2204);ui.detailReferencesExpanded=true;ui:RefreshDetail()
assert(not visible(a.L("SOURCE_SUMMON_ITEM","Item 7667",q2204.start.name)),"invalid mixed fixed-spawn relation does not publish a creation instruction")
local invalidControl=row(2204).navigationControl
assert(not invalidControl.enabled,"declared created object cannot fall back to a precise or map route")
if invalidControl.scripts.OnClick then invalidControl.scripts.OnClick()end
assert(routes==0 and maps==0 and not ui.giver.enabled,"mixed relation cannot dispatch a guessed fixed point")
q2204.start.mapID,q2204.start.x,q2204.start.y=originalMap,originalX,originalY
for _,button in ipairs(ui.reportedToggles)do assert(not button:IsShown(),"an explicitly created source does not expose stale historical spawn choices")end
for _,button in ipairs(ui.reportedRows)do assert(not button:IsShown(),"no historical spawn route is rendered for a created source")end
q2204.start.reportedLocations=reports
q2204.start.summonItem={itemID="invalid",name=tool.name};render(2204)
assert(not visible(a.L("SOURCE_SUMMON_ITEM","Item 7667",q2204.start.name))and visible(a.L("GIVER_LOCATION_UNKNOWN")),"malformed tool retains honest unknown source without invented instruction")
assert(not row(2204).navigationControl.enabled and not ui.giver.enabled,"malformed creation relation offers no navigation fallback")
q2204.start.summonItem=tool
render(2204);click=row(2204).navigationControl.scripts.OnClick
b,proof=binding("start.summonItem")
local sourceGetter=ui.SummonSource
ui.SummonSource=function()error("replaced source reader must not run")end
assert(not proof.current(),"replaced source reader retires its item tooltip proof");click()
assert(inspections==inspected,"replaced source reader cannot dispatch an old source action")
ui.SummonSource=sourceGetter
local inspector=ui.InspectQuest;local fired=false
ui.InspectQuest=function()fired=true end;click();ui.InspectQuest=inspector
assert(not fired,"replaced inspector is not called through retired source action")
local character=a.char;a.char={};click();a.char=character
assert(inspections==inspected and routes==0 and maps==0 and uses==0,"changed character cannot dispatch old inspector")
-- Each source item getter may complete another card before returning its old value.
for _,method in ipairs({"ItemName","ItemIcon","CarriedItemCount"})do
 local getter=a[method];local armed=true;local changed=false
 a[method]=function(itemID,...)
  if armed and itemID==7667 then armed,changed=false,true;render(6981)end
  return getter(itemID,...)
 end
 ui.quest=2204;ui:Refresh();a[method]=getter
 assert(changed and ui.quest==6981 and ui.renderedQuest==6981,"item source getter actually rendered a newer card: "..method)
 for _,button in ipairs(ui.objectiveButtons)do assert(not button:IsShown()or not button.objectiveBinding or button.objectiveBinding.role~="source-tool","retired source getter does not leak a source-tool icon")end
end
-- Restriction proof callbacks cannot transfer the inspector after an earlier identity check.
local checker=issecretvalue;local stableInspector=ui.InspectQuest
local armed,matches,fired=false,0,false
local oldCalls,newCalls=0,0
ui.InspectQuest=function(self,...)oldCalls=oldCalls+1;return stableInspector(self,...)end
issecretvalue=function(value)
 if armed and value==7667 then
  matches=matches+1
  if matches==2 then
   armed,fired=false,true
   ui.InspectQuest=function()newCalls=newCalls+1 end
   render(6981)
  end
 end
 return false
end
render(2204);local retired=row(2204).navigationControl.scripts.OnClick
armed=true;retired()
ui.InspectQuest=stableInspector;issecretvalue=checker
assert(fired and oldCalls==0 and newCalls==0 and ui.quest==6981,"restriction proof actually replaced inspector but retired click invokes neither old nor new method")
-- A localization callback actually completes a different source card.
local localize,armed=a.L,true;fired=false
a.L=function(key,...)
 local text=localize(key,...)
 if armed and key=="SOURCE_SUMMON_ITEM"then armed,fired=false,true;render(6981);return "Retired summon instruction"end
 return text
end
ui.quest=2204;ui:Refresh();a.L=localize
assert(fired and ui.quest==6981 and ui.renderedQuest==6981 and not visible("Retired summon instruction"),"newer card survives retired source localization")
-- A late native instruction setter cannot overwrite the newer source card.
render(2204);instruction=assert(visible(a.L("SOURCE_SUMMON_ITEM","Item 7667",q2204.start.name)))
local setter=instruction.SetText;armed,fired=true,false
instruction.SetText=function(self,value,...)
 if armed and value==a.L("SOURCE_SUMMON_ITEM","Item 7667",q2204.start.name)then armed,fired=false,true;render(6981)end
 return setter(self,value,...)
end
ui.quest=2204;ui:Refresh();instruction.SetText=setter
assert(fired and ui.quest==6981 and ui.renderedQuest==6981,"native source setter actually completed a newer card")
assert(not visible(a.L("SOURCE_SUMMON_ITEM","Item 7667",q2204.start.name)),"retired instruction setter tail cannot leak onto new card")
q2204.start.summonItem,q2201.finish.summonItem=originalStart,originalFinish
assert(routes==0 and maps==0 and uses==0)
print("Summoned object source instructions: PASS (actual TOC and controlled relation fixtures; modeled UI only)")
