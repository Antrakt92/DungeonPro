-- A click may reuse a warm catalogue, but cannot outlive its own visibility/selection.
local total=0
local function scenario(kind,mode,hook)
 local f=assert(loadfile('tests/client_ui.lua'))('fixture');local a,u=f.addon,f.addon.UI
 issecretvalue=function()return false end;GetLocale=function()return'enUS'end
 UnitGUID=function()return'Player-CatalogClick'end;C_Timer={After=function()end}
 f.eventFrame.scripts.OnEvent(f.eventFrame,'ADDON_LOADED','DungeonPro');u:Toggle();u.includeUnavailable=true;u.range=false;a.db.locale='enUS'
 local d={};for _,x in ipairs(a.dungeons)do d[x.key]=x end
 u.dungeon,u.quest=d.rfc,5728;u:Refresh()
 local armed,fired=false,false;local beforeQuest,beforeDungeon,beforePersist
 local function supersede()
  if not armed or fired then return end;fired=true
  if mode=='hide'or mode=='hide-show'then u.frame:Hide();u.frame.scripts.OnHide(u.frame);if mode=='hide-show'then u.frame:Show()end
  elseif mode=='selection'then u:InspectQuest(92753,true);u:SetDetailTab('story');u.detailScroll:SetVerticalScroll(7)end
 end
 local source=a.QuestSourceSearchTerms
 a.QuestSourceSearchTerms=function(...)
  local terms,current,raw=source(...)
  return terms,function()if hook=='proof'then supersede()end;return current()end,raw
 end
 u.search='Gryan Stoutmantle';u:RefreshDungeons();local card
 for _,r in ipairs(u.cards)do if r:IsShown()and r.catalogResult.dungeon==d.dm then card=r end end
 assert(card and card.catalogResult.questID and card.catalogResult.inspect)
 local id=card.catalogResult.questID;local control=kind=='row'and card or card.catalogResult.inspect
 local shown=card.IsShown
 card.IsShown=function(self)local value=shown(self);if hook=='visible'then supersede()end;return value end
 local history=u.detailHistory;beforeQuest,beforeDungeon,beforePersist=u.quest,u.dungeon,a.char.selectedDungeon
 local requests=0;C_QuestLog.RequestLoadQuestByID=function()requests=requests+1 end
 local routes=0;local start=a.Navigation.Start;a.Navigation.Start=function(...)routes=routes+1;return start(...)end
 armed=true;control.scripts.OnClick();armed=false;card.IsShown=shown
 assert(fired,'the '..hook..' callback must actually supersede the '..kind..' click')
 if mode=='selection'then
  assert(u.quest==92753 and u.detailTab=='story'and u.detailScroll:GetVerticalScroll()==7,'new inspection and reading position must survive retired '..kind..' click')
 else
  assert(u.quest==beforeQuest and u.dungeon==beforeDungeon and a.char.selectedDungeon==beforePersist and u.detailHistory==history,
   'a '..kind..' click retired by '..mode..' cannot mutate quest/dungeon/persisted selection')
 end
 assert(routes==0,'catalogue clicks never route automatically')
 if mode~='selection'then assert(requests==0,'an aborted click cannot hydrate quest data')end
 total=total+1
end
scenario('row','hide','visible')
scenario('row','hide-show','visible')
scenario('row','selection','proof')
scenario('inspect','hide','visible')
scenario('inspect','hide-show','proof')
scenario('inspect','selection','visible')
-- Old pooled handlers remain valid when a NEW click begins after a normal warm reopen.
local f=assert(loadfile('tests/client_ui.lua'))('fixture');local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;GetLocale=function()return'enUS'end;UnitGUID=function()return'Player-CatalogReopen'end;C_Timer={After=function()end}
f.eventFrame.scripts.OnEvent(f.eventFrame,'ADDON_LOADED','DungeonPro');u:Toggle();u.includeUnavailable=true;u.range=false;a.db.locale='enUS'
local d={};for _,x in ipairs(a.dungeons)do d[x.key]=x end
u.dungeon,u.quest=d.rfc,5728;u:Refresh();u.search='Gryan Stoutmantle';u:RefreshDungeons()
local card;for _,r in ipairs(u.cards)do if r:IsShown()and r.catalogResult.dungeon==d.dm then card=r end end
local result=assert(card.catalogResult);local click=card.scripts.OnClick;local inspect=result.inspect.scripts.OnClick
local generation=u.catalogGeneration;u.frame:Hide();u.frame.scripts.OnHide(u.frame);u.frame:Show()
assert(u.catalogGeneration==generation and result.inspect.scripts.OnClick==inspect,'normal reopen retains the warm catalogue and pooled handler')
click();assert(u.dungeon==d.dm and u.quest==nil and a.char.selectedDungeon=='dm')
inspect();assert(u.dungeon==d.dm and u.quest==result.questID and u.renderedQuest==result.questID,'fresh invocation of retained handler inspects exact current source quest')
local selected,quest,persisted=u.dungeon,u.quest,a.char.selectedDungeon
assert(u:SetCatalogCollapsed(true));click();inspect()
assert(u.dungeon==selected and u.quest==quest and a.char.selectedDungeon==persisted,'retained hidden-rail handlers cannot select or persist')
assert(u:SetCatalogCollapsed(false))
local close=u.CloseDungeonMap;local previous=u.detailTabRevision;local cleanupFired=false
u.CloseDungeonMap=function(self,...)
 cleanupFired=true;assert(self.detailTabRevision~=previous,'OnHide must retire input before its first callback-bearing cleanup')
 return close(self,...)
end
u.frame:Hide();u.frame.scripts.OnHide(u.frame);u.CloseDungeonMap=close
assert(cleanupFired)
print('PASS catalogue click retirement: '..total..' fired visibility/proof interleavings plus warm reopen/normal inputs/collapsed rail/early cleanup cancellation')
