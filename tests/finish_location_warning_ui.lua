-- A known destination area does not imply an available exact turn-in point.
local override=...
local loader=loadfile
if override then loadfile=function(p)return loader(p=="UI/Window.lua"and override or p)end end
local f=assert(loader("tests/client_ui.lua"))("fixture");loadfile=loader
local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return "enUS"end
UnitGUID=function()return "Player-finish-warning"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro")
u:Toggle();a.db.locale="enUS";u.includeUnavailable=true
local owners={};for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=d end end
local token,id,status={},4241,"READY"
a.Context=function()
 local own=token
 return{level=60,class="WARRIOR",faction="Alliance",race=1,current=function()return own==token end,
 active=function(q)return q==id end,ready=function(q)return q==id and status=="READY"end,completed=function()return false end}
end
local routes,maps={},{}
a.Navigation={Start=function(action)routes[#routes+1]=action;return true end,Map=function(point)maps[#maps+1]=point;return true end}
local function render(quest,state,context)
 token={};id,status=quest,state or "READY";u.dungeon,u.quest=assert(context or owners[quest]),quest;u:Refresh()
 assert(u.quest==quest and u.renderedQuest==quest)
end
local function finish()
 local prefix=a.L("DETAIL_TURNIN")..": "
 for i,fs in ipairs(u.details)do if fs:IsShown()and fs.text and fs.text:find(prefix,1,true)==1 then
  return fs,u.details[i+1]
 end end
end
local function warned()
 local caption,warning=finish()
 assert(caption and warning and warning:IsShown()and warning.text==a.L("SOURCE_POSITION_UNKNOWN")and warning.detailStyle=="warning",
 "known finisher area needs one adjacent exact-position-unknown explanation")
 return caption,warning
end
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","itIT","koKR","zhCN","zhTW"})do
 a.db.locale=locale
 for _,state in ipairs({"READY","ACTIVE"})do
  render(4241,state);local caption=warned()
  assert(caption.text:find(a.SourceName(a.quests[4241].finish)or a.quests[4241].finish.name,1,true))
  assert(not u.turnin:IsShown()and not u.turnin.enabled and u.action.id==4241 and
   (state=="READY"and u.action.place==a.quests[4241].finish or state=="ACTIVE"and u.action.kind=="complete"and u.action.place==nil))
  assert(u.giverAction.place==a.quests[4241].start,"finisher warning cannot replace the known pickup-source visit")
  assert(#routes==0 and #maps==0)
 end
end
a.db.locale="enUS";render(4241);warned();u.giver.scripts.OnClick()
assert(#routes==1 and routes[1].kind=="visit"and routes[1].place==a.quests[4241].start)
render(5724);local caption,nextLine=finish();assert(caption and (not nextLine:IsShown()or nextLine.text~=a.L("SOURCE_POSITION_UNKNOWN")))
assert(u.turnin:IsShown()and u.turnin.enabled);u.turnin.scripts.OnClick()
assert(#routes==2 and routes[2].kind=="turnin"and routes[2].place==a.quests[5724].finish)
-- Controlled map-only shape retains the real typed finisher and real map identity.
local point=a.quests[5724].finish;local x,y=point.x,point.y;point.x,point.y=nil,nil
render(5724);warned();assert(u.turnin:IsShown()and u.turnin.enabled);u.turnin.scripts.OnClick()
assert(#maps==1 and maps[1]==point,"map-only finisher keeps its existing explicit map action")
point.x,point.y=x,y
for _,quest in ipairs({96987,3801})do
 render(quest,"READY");assert(not finish(),"absent or alternative-only finisher must not gain a synthetic primary destination")
end
render(2201,"READY",assert(owners[2204]));local caption,nextLine=finish()
assert(caption and nextLine.text~=a.L("SOURCE_POSITION_UNKNOWN"),"item-created source keeps its creation instruction rather than a fixed-position warning")
for _,phase in ipairs({"before","after"})do
 render(4241);local _,field=warned();local native=field.SetText;local fired=false
 field.SetText=function(self,value)
  if phase=="after"then native(self,value)end
  if not fired and value==a.L("SOURCE_POSITION_UNKNOWN")then fired=true;render(5724)end
  if phase=="before"then native(self,value)end
 end
 u:RefreshDetail();field.SetText=native
 assert(fired and u.quest==5724 and u.turnin:IsShown()and u.turnin.enabled)
 local _,following=finish();assert(not following:IsShown()or following.text~=a.L("SOURCE_POSITION_UNKNOWN"),"retired warning cannot overwrite a newer exact finisher")
end
render(4241);local localize=a.L;local fired=false
a.L=function(key,...)
 if key=="SOURCE_POSITION_UNKNOWN"and not fired then fired=true;render(5724)end
 return localize(key,...)
end
u:RefreshDetail();a.L=localize
assert(fired and u.quest==5724 and u.turnin.enabled)
local _,following=finish();assert(not following:IsShown()or following.text~=a.L("SOURCE_POSITION_UNKNOWN"))
-- ACTIVE follows the same classified presence boundary as READY before nil decisions.
for _,field in ipairs({"finishAlternatives","summonItem"})do
 local source=field=="summonItem"and a.quests[4241].finish or a.quests[4241]
 local previous=source[field];local restricted={};local checked=0;source[field]=restricted
 issecretvalue=function(value)if value==restricted then checked=checked+1;return true end;return false end
 render(4241,"ACTIVE")
 local _,following=finish()
 assert(checked>0 and following.text~=a.L("SOURCE_POSITION_UNKNOWN")and not u.turnin.enabled,
  "restricted optional finisher source cannot authorize an unknown-position decision")
 source[field]=previous;issecretvalue=function()return false end
end
local source=a.quests[4241];local previous=source.finishAlternatives;local marker={};source.finishAlternatives=marker
local checkerFired=false
issecretvalue=function(value)
 if value==marker and not checkerFired then checkerFired=true;render(5724)end
 return false
end
token={};id,status=4241,"ACTIVE";u.dungeon,u.quest=owners[4241],4241;u:Refresh()
source.finishAlternatives=previous;issecretvalue=function()return false end
assert(checkerFired and u.quest==5724 and u.turnin.enabled,"presence classification reentry preserves the newer exact destination")
local _,following=finish();assert(following.text~=a.L("SOURCE_POSITION_UNKNOWN"))
-- Empty finish alternatives are absence, not a turn-in choice section.
do
 local baseRoutes, baseMaps = #routes, #maps
 local quest = a.quests[5724]
 local previous = quest.finishAlternatives
 assert(previous == nil, "5724 ships without finish alternatives")
 local empty = {}
 quest.finishAlternatives = empty
 render(5724)
 local caption = finish()
 assert(caption and caption.text:find(a.SourceName(quest.finish) or quest.finish.name, 1, true),
  "empty finish alternatives cannot hide the real turn-in caption")
 assert(u:SetDetailTab("sources"))
 local function headings()
  local count = 0
  for _, fs in ipairs(u.details) do
   if fs:IsShown() and fs.text == a.L("POSSIBLE_TURNINS") then count = count + 1 end
  end
  return count
 end
 local function hiddenButtons()
  for _, button in ipairs(u.finishButtons) do
   assert(not button:IsShown(), "empty finish alternatives offer no choice buttons")
  end
 end
 assert(headings() == 0, "empty finish alternatives must not draw an empty turn-in section")
 hiddenButtons()
 assert(#routes == baseRoutes and #maps == baseMaps, "empty alternatives navigate nowhere")
 quest.finishAlternatives = previous
 if u.detailTab ~= "quest" then assert(u:SetDetailTab("quest")) end
 render(5724)
 assert(finish(), "restored nil alternatives keep the real turn-in caption")
 assert(u.turnin:IsShown() and u.turnin.enabled, "restored nil alternatives keep the turn-in action")
 u.turnin.scripts.OnClick()
 assert(#routes == baseRoutes + 1 and routes[#routes].kind == "turnin" and routes[#routes].place == quest.finish,
  "restored nil alternatives keep the real turn-in route")
 assert(u:SetDetailTab("sources"))
 assert(headings() == 0, "nil alternatives show no turn-in section")
 hiddenButtons()
 quest.finishAlternatives = empty
 empty[1] = { npcID = 990001, name = "Synthetic first turn-in", mapID = 1 }
 empty[2] = { npcID = 990002, name = "Synthetic second turn-in", mapID = 1, x = 10, y = 20 }
 u:RefreshDetail()
 assert(headings() == 1, "grown finish alternatives show exactly one turn-in section")
 local first, second = u.finishButtons[1], u.finishButtons[2]
 assert(first:IsShown() and second:IsShown(), "grown finish alternatives show both choices")
 assert(first.title.text == "Synthetic first turn-in" and second.title.text == "Synthetic second turn-in",
  "grown finish alternatives keep their choice names")
 assert(first.enabled and second.enabled, "mapped finish alternatives stay actionable")
 first.scripts.OnClick()
 assert(#maps == baseMaps + 1 and maps[#maps] == empty[1] and #routes == baseRoutes + 1,
  "map-only finish choice dispatches its own known map")
 second.scripts.OnClick()
 assert(#routes == baseRoutes + 2 and routes[#routes].kind == "visit" and routes[#routes].place == empty[2] and #maps == baseMaps + 1,
  "located finish choice visits its exact point")
 empty[1], empty[2] = nil, nil
 u:RefreshDetail()
 assert(headings() == 0, "truncated finish alternatives retire the stale turn-in section")
 hiddenButtons()
 local reopened = finish()
 assert(reopened and reopened.text:find(a.SourceName(quest.finish) or quest.finish.name, 1, true),
  "truncated finish alternatives restore the real turn-in caption")
 quest.finishAlternatives = previous
 if u.detailTab ~= "quest" then assert(u:SetDetailTab("quest")) end
 render(5724)
 assert(#routes == baseRoutes + 2 and #maps == baseMaps + 1, "choice inspection never navigates automatically")
end
print("Finish location warning UI: PASS (actual READY/ACTIVE, ten locales, exact/map-only sources, summon/alternatives, empty-alternative section and native retirement)")
