local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,event=f.addon,f.eventFrame
event.scripts.OnEvent(event,"ADDON_LOADED","DungeonPro")
SlashCmdList.DUNGEONPRO("")
local ui=a.UI
ui.rangeButton:Show();ui.characterButton:Show()
local tip={hides=0}
function tip:SetOwner(button)self.owner=button end
function tip:IsOwned(button)return self.owner==button end
function tip:SetText(text)self.text=text end
function tip:AddLine(text)self.body=text end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false;self.hides=self.hides+1 end
GameTooltip=tip
ui.rangeButton.scripts.OnEnter()
local leave=ui.rangeButton.scripts.OnLeave
local control=ui.cards[1].dungeonStatusControl
control.scripts.OnEnter()
local latest=ui.navigationTooltip
assert(latest and latest.button==control and tip.shown)
leave()
assert(ui.navigationTooltip==latest and tip.shown,"retired filter leave must preserve the newer status tooltip")
control.scripts.OnLeave();assert(not tip.shown and not ui.navigationTooltip)
-- Native ownership inspection can synchronously open a newer tooltip.
ui.rangeButton.scripts.OnEnter()
local isOwned=tip.IsOwned;local once=false
function tip:IsOwned(button)
 local was=isOwned(self,button)
 if not once then once=true;ui.characterButton.scripts.OnEnter()end
 return was
end
ui:HideNavigationHint()
tip.IsOwned=isOwned
assert(once and tip.shown and ui.navigationTooltip and ui.navigationTooltip.button==ui.characterButton,
 "outer cleanup must not dismiss a tooltip opened by its native ownership getter")
-- Every retained leave/hide handler may run after a different control takes ownership.
ui.dungeon=a.dungeons[1];ui.quest=ui.dungeon.quests[1];ui:Refresh()
local controls={ui.rangeButton,ui.characterButton,ui.source,ui.issueLink,ui.supportLink,
 ui.cards[1].entranceControl,ui.cards[1].dungeonStatusControl,ui.questEntrance}
for _,row in ipairs(ui.rows)do if row.shown and row.questID then
 controls[#controls+1]=row
 if row.navigationControl then controls[#controls+1]=row.navigationControl end
 break
end end
local checked=0
for _,old in ipairs(controls)do
 for _,name in ipairs({"OnLeave","OnHide"})do
  local retire=old.scripts[name]
  if retire then
   ui:HideNavigationHint();old.scripts.OnEnter(old)
   assert(ui.navigationTooltip,"test surface must expose a real hint")
   local other=old==ui.characterButton and ui.rangeButton or ui.characterButton
   other.scripts.OnEnter(other)
   local newest=ui.navigationTooltip;assert(newest.button==other and tip.shown)
   retire(old)
   assert(ui.navigationTooltip==newest and tip.shown,"retired "..name.." must preserve newer owner")
   checked=checked+1
  end
 end
end
assert(checked>=12,"exercise real catalogue, quest, header and detail control callbacks")
-- Ordinary leave/hide still dismisses its own hint; external tooltip owners survive.
ui.source.scripts.OnEnter(ui.source);assert(tip.shown)
ui.source.scripts.OnHide(ui.source);assert(not tip.shown and not ui.navigationTooltip)
ui.characterButton.scripts.OnEnter(ui.characterButton);tip.owner={}
ui.characterButton.scripts.OnLeave(ui.characterButton);assert(tip.shown and not ui.navigationTooltip)
-- Native cleanup methods may disappear, throw, or be replaced during ownership inspection.
for _,kind in ipairs({"missing","throws","replaced"})do
 ui.characterButton.scripts.OnEnter(ui.characterButton)
 local hide=tip.Hide;local owned=tip.IsOwned
 if kind=="missing"then tip.Hide=nil
 elseif kind=="throws"then tip.IsOwned=function()error("ownership unavailable")end
 else tip.IsOwned=function(self,button)self.Hide=function()error("new owner hide must not run")end;return true end end
 local ok=pcall(ui.HideNavigationHint,ui,ui.characterButton)
 assert(ok and tip.shown and not ui.navigationTooltip,"cleanup fails closed: "..kind)
 tip.Hide,tip.IsOwned=hide,owned
end
-- A late Hide can resume after opening a newer completed hint on the same tooltip.
ui:HideNavigationHint()
ui.rangeButton.scripts.OnEnter()
local hide=tip.Hide;local once=false
function tip:Hide()
 if not once then once=true;ui.characterButton.scripts.OnEnter()end
 hide(self)
end
ui:HideNavigationHint();tip.Hide=hide
assert(once and tip.shown and ui.navigationTooltip and ui.navigationTooltip.button==ui.characterButton,
 "latest completed tooltip is restored after a late old Hide")
-- Repair must not revive a borrowed, hidden, or invalidated newer hint.
for _,mode in ipairs({"borrowed","hidden","invalid"})do
 ui.frame:Show();ui:Refresh();ui.rangeButton.scripts.OnEnter()
 local hide=tip.Hide;local once=false;local oldL=a.L
 function tip:Hide()
  if not once then
   once=true;ui.characterButton.scripts.OnEnter()
   if mode=="borrowed"then self.owner={}
   elseif mode=="hidden"then ui.frame:Hide()
   else ui.includeUnavailable=not ui.includeUnavailable end
  end
  hide(self)
 end
 ui:HideNavigationHint();tip.Hide=hide;a.L=oldL
 assert(once and not tip.shown,"no resurrection after "..mode.." ownership")
end
-- Visibility getters run before the final native ownership proof.
ui.frame:Show();ui:Refresh();ui.rangeButton.scripts.OnEnter()
local held=ui.navigationTooltip;assert(held.restore)
tip.shown=false
local shown=ui.rangeButton.IsShown;local visibilityRead=false
ui.rangeButton.IsShown=function(self)visibilityRead=true;tip.owner={};return shown(self)end
held.restore();ui.rangeButton.IsShown=shown
assert(visibilityRead and not tip.shown,"visibility inspection cannot resurrect a borrowed tooltip")
-- The final ownership getter cannot resurrect a completed hint for an old view.
for _,mode in ipairs({"mode","quest","character","database","definitions","invalid-engine"})do
 ui:HideNavigationHint();ui.frame:Show();ui:Refresh()
 local owned=tip.IsOwned;local all,quest,char,db,definitions,invalid=ui.includeUnavailable,ui.quest,a.char,a.db,a.quests,ui.engine.invalid
 local armed,fired=false,false
 tip.IsOwned=function(self,button)
  local result=owned(self,button)
  if armed then
   armed,fired=false,true
   if mode=="mode"then ui.includeUnavailable=not all
   elseif mode=="quest"then ui.quest=999999
   elseif mode=="character"then a.char={}
   elseif mode=="database"then a.db={locale=db.locale}
   elseif mode=="definitions"then a.quests={}
   else ui.engine.invalid=true end
  end
  return result
 end
 ui.rangeButton.scripts.OnEnter()
 local held=ui.navigationTooltip;assert(held.restore);tip.shown=false;armed=true
 held.restore();tip.IsOwned=owned
 assert(fired and not tip.shown,"final ownership inspection invalidated "..mode.." view")
 ui.includeUnavailable,ui.quest,a.char,a.db,a.quests,ui.engine.invalid=all,quest,char,db,definitions,invalid
end
assert(not ui.navigationTooltipRepair,"bounded repair guard clears")
print("Navigation tooltip retirement UI checks passed: "..checked.." retained callbacks")
