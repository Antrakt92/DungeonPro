-- Retired catalogue status proofs release engines without replacing public objects.
local f=assert(loadfile('tests/client_ui.lua'))('fixture');local a,ui=f.addon,f.addon.UI
issecretvalue=function()return false end;GetLocale=function()return'enUS'end
UnitGUID=function(unit)return unit=='player'and'Player-StatusPeer'or nil end
C_Timer={After=function()end};f.eventFrame.scripts.OnEvent(f.eventFrame,'ADDON_LOADED','DungeonPro')
ui:Toggle();ui.includeUnavailable=true;ui.range=false;a.db.locale='enUS'
local weak=setmetatable({},{__mode='v'});local calls={};local active
local new=a.Planner.New;a.Planner.New=function(...)
 local engine=new(...);if active then weak[active]=engine end;return engine
end
local get=a.DungeonStatus.Get;a.DungeonStatus.Get=function(...)
 local dto,current=get(...);local label=active
 if not current then return dto,current end
 return dto,function()if label then calls[label]=(calls[label]or 0)+1 end return current()end
end
local function query(label,text)
 active=label;ui.search=text;ui:RefreshDungeons();active=nil
 assert(ui.catalogLanguageView and ui.catalogLanguageView.current())
end
query('six','The Barrens');local old=assert(ui.catalogLanguageView.results[1].statusCurrent)
local dto=ui.catalogLanguageView.results[1].statusDTO
assert(old()and weak.six)
query('one','Tirion Fordring');collectgarbage('collect');collectgarbage('collect')
assert(not weak.six and weak.one,'old six-card status engine must collect; current one-card engine stays owned')
local count=calls.six;assert(old()==false and calls.six==count,'retired proof is callable false without touching released context')
local live=assert(ui.catalogLanguageView.results[1].statusCurrent);local currentResult=ui.catalogLanguageView.results[1]
ui.frame:Hide();assert(live()and weak.one,'hiding retains the reusable current status engine')
ui.frame:Show();assert(live(),'normal unchanged reopen preserves the reusable status slot')
query('current','Tirion Fordring');assert(live()==false,'explicit new request retires the former warm status slot')
local proof=assert(ui.catalogLanguageView.results[1].statusCurrent)
for _,key in ipairs({'Read','Clean','checker'})do
 local previous=key=='checker'and issecretvalue or a[key]
 local count=calls.current
 if key=='checker'then issecretvalue=function()return false end else a[key]=function()return true end end
 local ok,result=pcall(proof)
 if key=='checker'then issecretvalue=previous else a[key]=previous end
 assert(ok and result==false and calls.current==count,'a replacement '..key..' cannot bypass status proof ownership or invoke its context')
end
assert(proof(),'restoring a capability permits the still-current exact status proof')
a.InvalidateContext();assert(proof()==false,'context expiry must reject a live slot')
query('fresh','Tirion Fordring');assert(ui.catalogLanguageView.results[1].statusCurrent())
query('zero','__No status peer result__');collectgarbage('collect');collectgarbage('collect')
assert(not weak.one and not weak.current and not weak.fresh,'retired one-card engines must collect')
assert(type(old)=='function'and type(dto)=='table'and type(currentResult.statusDTO)=='table')
print('PASS status slots collect obsolete engines, keep current/hide reuse, reject capabilities/context and preserve DTO objects')
query('paint-base','Tirion Fordring')
local row=ui.catalogLanguageView.results[1].row;local texture=row.dungeonStatusControl.statusIcon
local set=texture.SetTexture;local fired=false;local latestDTO,latestOwner
texture.SetTexture=function(self,value)
 if not fired and active=='paint-six'and value~=nil then
  fired=true;query('paint-latest','Tirion Fordring')
  latestDTO,latestOwner=row.dungeonStatusDTO,row.dungeonStatusCurrent
 end
 return set(self,value)
end
query('paint-six','The Barrens');texture.SetTexture=set
assert(fired and ui.search=='Tirion Fordring'and row:IsShown()and texture:IsShown())
assert(row.dungeonStatusDTO==latestDTO and row.dungeonStatusCurrent==latestOwner and latestOwner())
assert(ui.catalogLanguageView.current())
print('PASS late native status asset write preserves newest DTO, visual and status proof')

local previousGUID=UnitGUID;UnitGUID=function()return nil end
query('unknown-scope','Tirion Fordring')
local beforeGeneration=ui.catalogGeneration;local beforeProof=ui.catalogLanguageView.results[1].statusCurrent
ui.frame:Hide();assert(beforeProof(),'hiding alone retains even an unproven name-cache scope')
ui.frame:Show()
assert(ui.catalogGeneration~=beforeGeneration and beforeProof()==false,
    'unknown scope must rebuild on reopen and retire its former status slot')
assert(ui.catalogLanguageView.current());UnitGUID=previousGUID
print('PASS unknown scope rebuilds while valid scope warm reuse stays current')
