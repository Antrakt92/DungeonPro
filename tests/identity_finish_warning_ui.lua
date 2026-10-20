-- An existing identity-only finisher needs an honest missing-position explanation.
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
 local row=u.detailContactRows and u.detailContactRows[2]
 if row and row:IsShown()and row.detailPurpose and row.detailPurpose.text==a.L("DETAIL_TURNIN") then
  local binding=assert(row.detailContactBinding)
  assert(binding.field=="finish"and binding.questID==u.quest and binding.endpoint==a.quests[u.quest].finish and binding.current(),
   "the visible turn-in caption owns the exact selected current finisher")
  local bottom=-row.point[3]+row.height
  local following,top
  for _,fs in ipairs(u.details)do
   local y=fs.point and fs.point[1]=="TOPLEFT"and -fs.point[3]
   if fs:IsShown()and y and y>=bottom and fs.text~=a.L("VISIT_TURNIN")and(not top or y<top)then following,top=fs,y end
  end
  return row.title,following
 end
 for i,fs in ipairs(u.details)do if fs:IsShown()and fs.text and fs.text:find(prefix,1,true)==1 then
  return fs,u.details[i+1]
 end end
end
local originalFinish=a.quests[3447].finish
local originalArea=assert(originalFinish.zoneName,"the recorded object area is retained")
local function warned()
 local caption,warning=finish()
 assert(caption and warning and warning:IsShown()and warning.text==a.L("SOURCE_POSITION_UNKNOWN")and warning.detailStyle=="warning",
  "known identity-only finisher needs an adjacent exact-position-unknown explanation")
 return caption,warning
end
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","itIT","koKR","zhCN","zhTW"})do
 a.db.locale=locale
 for _,state in ipairs({"READY","ACTIVE"})do
  render(3447,state);local caption=warned()
  assert(caption.text:find(a.SourceName(originalFinish)or originalFinish.name,1,true))
  assert(a.quests[3447].finish==originalFinish and originalFinish.objectID==148838)
  assert(not u.turnin:IsShown()and not u.turnin.enabled and u.giverAction.place==a.quests[3447].start)
  assert(u.action.id==3447 and (state=="READY"and u.action.place==originalFinish or state=="ACTIVE"and u.action.kind=="complete"))
  assert(#routes==0 and #maps==0,"explanation must not add navigation or automatic actions")
 end
end
a.db.locale="enUS"
local function copy()
 local p={};for k,v in pairs(originalFinish)do p[k]=v end
 -- Controlled identity-only cases intentionally omit the newly recorded area.
 p.zoneName=nil
 return p
end
-- Synthetic malformed identities are not new typed source evidence.
for _,shape in ipairs({"unnamed","blank","untyped","mixed","zero","fraction","item"})do
 local point=copy()
 if shape=="unnamed"then point.name=nil
 elseif shape=="blank"then point.name="   "
 elseif shape=="untyped"then point.objectID=nil
 elseif shape=="mixed"then point.npcID=7771
 elseif shape=="zero"then point.objectID=0
 elseif shape=="fraction"then point.objectID=1.5
 elseif shape=="item"then point.objectID=nil;point.itemID=7667 end
 a.quests[3447].finish=point
 for _,state in ipairs({"READY","ACTIVE"})do
  render(3447,state);local _,following=finish()
  assert(not following or not following:IsShown()or following.text~=a.L("SOURCE_POSITION_UNKNOWN"),
   "malformed identity-only fixture must not authorize a position assertion: "..shape)
  assert(not u.turnin.enabled and #routes==0 and #maps==0)
 end
end
-- A controlled NPC identity uses the same presentation rule; no catalogue fact is added.
a.quests[3447].finish={npcID=7771,name="Synthetic named finisher"}
render(3447,"ACTIVE");warned();assert(not u.turnin.enabled)
a.quests[3447].finish=originalFinish
for _,shape in ipairs({"alternative","summon","exact","maponly"})do
 local point=copy();a.quests[3447].finish=point
 if shape=="alternative"then a.quests[3447].finishAlternatives={copy()}
 elseif shape=="summon"then point.summonItem={itemID=7667,name="Synthetic source tool"}
 else point.mapID=1419;if shape=="exact"then point.x,point.y=20,30 end end
 render(3447,"READY");local _,following=finish()
 if shape=="maponly"then warned();assert(u.turnin.enabled)
 else assert(not following or not following:IsShown()or following.text~=a.L("SOURCE_POSITION_UNKNOWN"))end
 assert(#routes==0 and #maps==0)
 a.quests[3447].finishAlternatives=nil
end
a.quests[3447].finish=originalFinish
local function exactReplacement()
 local point=copy();point.mapID,point.x,point.y=1419,20,30
 a.quests[3447].finish=point;render(3447,"READY")
end
for _,phase in ipairs({"before","after"})do
 render(3447,"READY");local _,field=warned();local native=field.SetText;local fired=false
 field.SetText=function(self,value)
  if phase=="after"then native(self,value)end
  if not fired and value==a.L("SOURCE_POSITION_UNKNOWN")then fired=true;exactReplacement()end
  if phase=="before"then native(self,value)end
 end
 u:RefreshDetail();field.SetText=native
 assert(fired and u.quest==3447 and u.turnin.enabled)
 local _,following=finish();assert(not following:IsShown()or following.text~=a.L("SOURCE_POSITION_UNKNOWN"),
  "retired identity-only warning must not overwrite the newer exact source")
 a.quests[3447].finish=originalFinish
end
render(3447,"ACTIVE");local localize=a.L;local fired=false
a.L=function(key,...)
 if key=="SOURCE_POSITION_UNKNOWN"and not fired then fired=true;exactReplacement()end
 return localize(key,...)
end
u:RefreshDetail();a.L=localize
assert(fired and u.quest==3447 and u.turnin.enabled and #routes==0 and #maps==0)
a.quests[3447].finish=originalFinish
assert(a.quests[3447].finish==originalFinish and originalFinish.mapID==nil and originalFinish.zoneName==originalArea)
print("Identity-only finish warning: PASS (actual object source, 10 locales, statuses, invalid/controlled sources and native retirement)")
