-- Native control records must release source ownership without dropping newest tail repairs.
local cases=0
local function fixture(mapped)
 local f=assert(loadfile("tests/client_ui.lua"))("fixture")
 local a,u=f.addon,f.addon.UI
 issecretvalue=function()return false end;GetLocale=function()return "enUS"end
 UnitLevel=function()return 60 end;UnitClass=function()return "Mage","MAGE",8 end
 UnitFactionGroup=function()return "Alliance"end;C_Timer={After=function()end}
 C_QuestLog.IsOnQuest=function()return false end;C_QuestLog.ReadyForTurnIn=function()return false end
 local routes={};a.Navigation.Start=function(action)routes[#routes+1]=action;return true end
 f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle()
 local brd;for _,d in ipairs(a.dungeons)do if d.key=="brd"then brd=d end end;assert(brd)
 if mapped then for _,id in ipairs({3801,3802})do
  local point=a.quests[id].startAlternatives[1]
  -- Controlled native navigation shape, not a new catalogue position observation.
  point.mapID,point.x,point.y=1418,10,20
 end end
 u.dungeon,u.quest,u.includeUnavailable,u.range=brd,3801,true,false;u:Refresh();assert(u:SetDetailTab("sources"))
 return a,u,routes
end
for _,id in ipairs({3801,3802})do
 local a,u=fixture(true)
 if id~=3801 then assert(u:InspectQuest(id,true));assert(u:SetDetailTab("sources"))end
 local row=assert(u.giverButtons[1]);assert(row:IsShown()and row.enabled)
 local registry=assert(row.questListWrites);local record=assert(registry.SetEnabled)
 local click=assert(row.scripts.OnClick)
 local old=u.engine;local weak=setmetatable({old},{__mode="v"});old=nil
 assert(u:InspectQuest(5724,true));u:Refresh();u.frame:Hide();u.frame.scripts.OnHide(u.frame);u.frame:Show();u:Refresh()
 collectgarbage("collect");collectgarbage("collect")
 assert(weak[1]==nil,"retired source control native records must not retain the previous quest engine")
 assert(row.questListWrites==registry and not record.current())
 local clean,reads=a.Clean,0;a.Clean=function(...)reads=reads+1;return clean(...)end
 assert(not record.current());click();assert(reads==0,"retired owner/action wrappers cannot call former source providers")
 a.Clean=clean;assert(u.quest==5724)
 cases=cases+1
end
local operations={
 {"Hide","cleanup"},{"SetEnabled","cleanup"},{"SetScript","cleanup"},
 {"Show","publish"},{"SetEnabled","publish"},{"SetScript","publish"},
}
for _,operation in ipairs(operations)do for _,phase in ipairs({"before","after"})do
 local a,u,routes=fixture(true)
 local row=assert(u.giverButtons[1]);local method,stage=operation[1],operation[2]
 local setter,fired,completed,newClick=row[method],false,false
 local function replace()
  fired=true
  assert(u:InspectQuest(3802,true));assert(u:SetDetailTab("sources"))
  newClick=assert(row.scripts.OnClick);completed=true
 end
 row[method]=function(self,...)
  local event,value=...
  local hit=not fired and (method=="Hide"or method=="Show"or
   method=="SetEnabled"and event==(stage=="publish")or
   method=="SetScript"and event=="OnClick"and((stage=="publish"and type(value)=="function")or(stage=="cleanup"and value==nil)))
  if hit and phase=="before"then replace()end
  local result=setter(self,...)
  if hit and phase=="after"then replace()end
  return result
 end
 if stage=="cleanup"then u:InspectQuest(5724,true)else u:RefreshDetail()end
 row[method]=setter
 assert(fired and completed and u.quest==3802 and u.detailTab=="quest")
 assert(row:IsShown()and row.enabled and row.scripts.OnClick==newClick,
  "late "..phase.." "..stage.." "..method.." must preserve the newer source row")
 assert(#routes==0);newClick();assert(#routes==1 and routes[1].place==a.quests[3802].startAlternatives[1],"fresh source click preserves its exact endpoint")
 cases=cases+1
end end
-- Objective-source rows keep their custom text protocol but share physical control repair keys.
for _,method in ipairs({"Show","SetEnabled","SetScript"})do for _,phase in ipairs({"before","after"})do
 local a,u,routes=fixture(false)
 u.quest=1221;u:Refresh();assert(u:SetDetailTab("sources"))
 local row=assert(u.objectiveContainerButtons[1]);assert(row:IsShown()and row.enabled)
 local setter,fired,completed=row[method],false,false
 row[method]=function(self,...)
  local event,value=...
  local hit=not fired and (method=="Show"or method=="SetEnabled"and event==true or method=="SetScript"and event=="OnClick"and type(value)=="function")
  local function replace()fired=true;assert(u:InspectQuest(5724,true));assert(u:SetDetailTab("sources"));completed=true end
  if hit and phase=="before"then replace()end
  local result=setter(self,...)
  if hit and phase=="after"then replace()end
  return result
 end
 u:RefreshDetail();row[method]=setter
 assert(fired and completed and u.quest==5724 and not row:IsShown()and not row.enabled and not row.scripts.OnClick,
  "late objective-source "..phase.." "..method.." cannot revive a retired container control")
 assert(#routes==0)
 cases=cases+1
end end
-- Actual five-point reported sources also release their selector and point-row owners.
do
 local a,u,routes=fixture(false);u.quest=971;u:Refresh();assert(u:SetDetailTab("sources"))
 local toggle=assert(u.reportedToggles[1]);assert(toggle:IsShown());toggle.scripts.OnClick()
 local row=assert(u.reportedRows[1]);assert(row:IsShown()and #u.reportedRows==5)
 local record=assert(row.questListWrites.SetEnabled);local toggleClick=toggle.scripts.OnClick;local click=row.scripts.OnClick
 click();assert(#routes==1 and routes[1].place.mapID==a.quests[971].start.reportedLocations[1].mapID)
 local weak=setmetatable({u.engine},{__mode="v"})
 assert(u:InspectQuest(5724,true));u.frame:Hide();u.frame.scripts.OnHide(u.frame);u.frame:Show();u:Refresh()
 collectgarbage("collect");collectgarbage("collect");assert(weak[1]==nil and not record.current())
 local clean,reads=a.Clean,0;a.Clean=function(...)reads=reads+1;return clean(...)end
 toggleClick();click();assert(reads==0 and #routes==1 and u.quest==5724);a.Clean=clean
 cases=cases+1
end
for _,phase in ipairs({"before","after"})do
 local a,u=fixture(false);u.quest=971;u:Refresh();assert(u:SetDetailTab("sources"));u.reportedToggles[1].scripts.OnClick()
 local row=assert(u.reportedRows[1]);local setter,fired=row.Show,false
 row.Show=function(self,...)
  local function replace()fired=true;assert(u:InspectQuest(5724,true));assert(u:SetDetailTab("sources"))end
  if not fired and phase=="before"then replace();return setter(self,...)end
  local result=setter(self,...);if not fired and phase=="after"then replace()end;return result
 end
 u:RefreshDetail();row.Show=setter
 assert(fired and u.quest==5724 and not row:IsShown()and not row.enabled and not row.scripts.OnClick)
 cases=cases+1
end
print("PASS source control release: "..cases.." actual-source GC/provider retirement and before/after native control tails")
