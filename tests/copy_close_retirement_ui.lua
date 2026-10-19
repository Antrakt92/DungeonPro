-- Closing a link retires only its own text, visibility and keyboard focus.
local function fixture()
 local f=assert(loadfile('tests/client_ui.lua'))('fixture');local a,u=f.addon,f.addon.UI
 issecretvalue=function()return false end;GetLocale=function()return'enUS'end;C_Timer={After=function()end}
 f.eventFrame.scripts.OnEvent(f.eventFrame,'ADDON_LOADED','DungeonPro');u:Toggle();a.db.locale='enUS';u.includeUnavailable=true
 u:InspectQuest(166,true);u.detailScroll:SetSize(400,100);u.detailScroll:SetVerticalScroll(35)
 assert(u:CopyLink(166)~=false and u.copy:IsShown())
 function u.copy:SetFocus()self.focused=true end
 function u.copy:ClearFocus()self.focused=false end
 function u.copy:HighlightText()self.highlighted=true end
 assert(u:CopyLink(166)~=false and u.copy.focused)
 return a,u
end
local total=0
for _,method in ipairs({'SetText','Hide','ClearFocus'})do for _,phase in ipairs({'before','after'})do for _,repaint in ipairs({false,true})do
 local a,u=fixture();local original=u.copy[method];local armed,fired=true,false;local newest
 local function replace()
  if not armed then return end;armed=false;fired=true
  assert(u:InspectQuest(214,true)~=false and u:CopyLink(214)~=false)
  if repaint then u:Refresh()end
  newest={revision=u.copyRevision,generation=u.rewardGeneration,text=u.copy:GetText(),offset=u.detailScroll:GetVerticalScroll()}
  assert(u.copyQuest==214 and u.copy:IsShown()and u.copy.focused)
 end
 u.copy[method]=function(self,...)
  local trigger=armed and(method~='SetText'or(...)=='')
  if trigger and phase=='before'then replace()end
  local result=original(self,...)
  if trigger and phase=='after'then replace()end
  return result
 end
 u:CloseCopyLink()
 assert(fired and newest and u.quest==214 and u.copyQuest==214 and u.copyRevision==newest.revision and u.rewardGeneration==newest.generation)
 assert(u.copy:GetText()==newest.text and u.copy:IsShown()and u.copyHint:IsShown()and u.copy.focused,
  'retired '..phase..' '..method..' close must preserve the new link text/visibility/focus')
 assert(u.detailScroll:GetVerticalScroll()==newest.offset,'retired close cannot scroll newer quest')
 u.copy[method]=original;total=total+1
end end end
-- Normal publication shares physical visibility/focus keys with a newer close.
for _,method in ipairs({'Show','SetFocus'})do for _,phase in ipairs({'before','after'})do
 local a,u=fixture();local original=u.copy[method];local fired=false
 u.copy[method]=function(self,...)
  if not fired and phase=='before'then fired=true;u:CloseCopyLink()end
  local result=original(self,...)
  if not fired and phase=='after'then fired=true;u:CloseCopyLink()end
  return result
 end
 assert(u:CopyLink(166)==false)
 assert(fired and u.copyQuest==nil and not u.copy:IsShown()and not u.copyHint:IsShown()and not u.copy.focused,
  'retired '..method..' publication cannot undo a newer close')
 u.copy[method]=original;total=total+1
end end
for _,phase in ipairs({'clean','offset'})do
 local a,u=fixture();u:CloseCopyLink();local fired=false;local latest
 local function replace()
  if fired then return end;fired=true;u:InspectQuest(214,true);assert(u:CopyLink(214)~=false)
  latest={u.copyRevision,u.copyReturn,u.copy:GetText()}
 end
 if phase=='clean'then local clean=a.Clean;a.Clean=function(value,kind)if value==166 and kind=='number'then replace()end;return clean(value,kind)end
 else local getter=u.detailScroll.GetVerticalScroll;u.detailScroll.GetVerticalScroll=function(self)local value=getter(self);replace();return value end end
 assert(u:CopyLink(166)==false and fired and u.quest==214 and u.copyQuest==214)
 assert(u.copyRevision==latest[1]and u.copyReturn==latest[2]and u.copy:GetText()==latest[3]and u.copy:IsShown(),
  'early '..phase..' callback cannot overwrite newer copy intent or reading offset')
 total=total+1
end
-- Escape must not refresh or restore the earlier quest's offset after a superseded close.
do
 local a,u=fixture();local set=u.copy.SetText;local fired=false;local latest
 u.copy.SetText=function(self,value)
  local result=set(self,value)
  if not fired and value==''then fired=true;u:InspectQuest(214,true);assert(u:CopyLink(214)~=false);latest={u.rewardGeneration,u.copyRevision,u.detailScroll:GetVerticalScroll()}end
  return result
 end
 u:EscapeCopyLink()
 assert(fired and u.quest==214 and u.copyQuest==214 and u.copy:IsShown()and u.copy.focused)
 assert(u.rewardGeneration==latest[1]and u.copyRevision==latest[2]and u.detailScroll:GetVerticalScroll()==latest[3],
  'retired Escape must not repaint or restore old reading into a new copy')
 total=total+1
end
-- Normal copy/close/Escape and same-id repeat preserve history and initial reading offset.
do
 local a,u=fixture();u:CloseCopyLink();u:RefreshDetail();u.detailScroll:SetVerticalScroll(35)
 local history=u.detailHistory;assert(u:CopyLink(166)~=false);local saved=u.copyReturn;assert(saved and saved.offset==35)
 assert(u:CopyLink(166)~=false and u.copyReturn==saved,'same-quest copy keeps its original return position')
 local revision=u.copyRevision;assert(u:CopyLink(214)==false and u.copyRevision==revision and u.copyQuest==166,'foreign copy cannot retire valid copy')
 u.copy:SetText('User-selected copy text');u:RefreshDetail();assert(u.copy:GetText()=='User-selected copy text'and u.copy.focused,'same-card refresh preserves manual copy text and focus')
 u:EscapeCopyLink();assert(u.copyQuest==nil and not u.copy:IsShown()and not u.copyHint:IsShown()and not u.copy.focused)
 local expected=math.min(35,math.max(0,u.detail:GetHeight()-u.detailScroll:GetHeight()))
 assert(u.quest==166 and u.detailHistory==history and u.detailScroll:GetVerticalScroll()==expected)
 for _,ack in ipairs({'true','false','nil','throw'})do
  assert(u:CopyLink(166)~=false);local clear=u.copy.ClearFocus
  u.copy.ClearFocus=function(self)clear(self);if ack=='throw'then error('native focus failure')end;return ack=='true'and true or ack=='false'and false or nil end
  local ok=pcall(u.CloseCopyLink,u);assert(ok and u.copyQuest==nil and not u.copy:IsShown())
  u.copy.ClearFocus=clear
 end
 total=total+1
end
print('PASS copy close retirement: '..total..' native text/visibility/focus/Escape and normal offset/ack groups')

-- Closed copy controls must not retain a retired render engine through native highlight repair.
do
 local f=assert(loadfile('tests/client_ui.lua'))('fixture');local a,u=f.addon,f.addon.UI
 issecretvalue=function()return false end;GetLocale=function()return'enUS'end;C_Timer={After=function()end}
 f.eventFrame.scripts.OnEvent(f.eventFrame,'ADDON_LOADED','DungeonPro');u:Toggle();a.db.locale='enUS';u.includeUnavailable=true
 a.QuestListRewards=nil;a.RewardCache=nil
 local weak=setmetatable({},{__mode='v'})
 assert(u:InspectQuest(166,true));weak.old=u.engine;assert(u:CopyLink(166)~=false)
 local prior=assert(u.copy.questListWrites.HighlightText);assert(prior.current()and weak.old==u.engine)
 local saved=u.copyReturn;assert(u:CopyLink(166)~=false and u.copyReturn==saved)
 local repeated=assert(u.copy.questListWrites.HighlightText)
 assert(repeated~=prior and prior.current()==false and repeated.current(),'same-id fresh copy supersedes old highlight ownership')
 u:CloseCopyLink();assert(not repeated.current()and u.copyQuest==nil and not u.copy:IsShown())
 assert(u:InspectQuest(214,true));weak.current=u.engine
 collectgarbage('collect');collectgarbage('collect')
 assert(not weak.old and weak.current==u.engine,'retired closed copy highlight must release old166 engine while current214 stays alive')
 u.dungeon,u.quest=nil,nil;u:RefreshQuests();u:RefreshDetail();collectgarbage('collect');collectgarbage('collect')
 assert(not weak.old and u.engine==nil,'overview cannot retain the old copy engine')
 assert(type(prior.current)=='function'and prior.current()==false and repeated.current()==false,'retired stored highlight guards remain safely callable')
end
print('PASS copy highlight retirement: old166 engine GC/current214 retention/same-id and retained native records')
for _,mode in ipairs({'quest','same','close'})do for _,phase in ipairs({'before','after'})do
 local a,u=fixture();local original=u.copy.HighlightText;local fired=false;local newest
 local function replace()
  if fired then return end;fired=true
  if mode=='close'then u:CloseCopyLink()
  elseif mode=='quest'then u:InspectQuest(214,true);assert(u:CopyLink(214)~=false)
  else assert(u:CopyLink(166)~=false)end
  newest={revision=u.copyRevision,generation=u.rewardGeneration,quest=u.quest,copyQuest=u.copyQuest,text=u.copy:GetText(),shown=u.copy:IsShown(),focused=u.copy.focused,offset=u.detailScroll:GetVerticalScroll()}
 end
 u.copy.HighlightText=function(self,...)
  if not fired and phase=='before'then replace()end
  local result=original(self,...)
  if not fired and phase=='after'then replace()end
  return result
 end
 assert(u:CopyLink(166)==false and fired)
 assert(u.copyRevision==newest.revision and u.rewardGeneration==newest.generation and u.quest==newest.quest and u.copyQuest==newest.copyQuest)
 assert(u.copy:GetText()==newest.text and u.copy:IsShown()==newest.shown and u.copy.focused==newest.focused and u.detailScroll:GetVerticalScroll()==newest.offset,
  'retired '..phase..' HighlightText cannot change newer '..mode..' copy state')
end end
print('PASS six before/after native HighlightText callbacks preserve newest copy/close/same-id text focus and reading')
