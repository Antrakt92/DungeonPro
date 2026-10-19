local count=0
local function run(mode)
 local f=assert(loadfile('tests/client_ui.lua'))('fixture');local a,u,e=f.addon,f.addon.UI,f.eventFrame
 issecretvalue=function()return false end;GetLocale=function()return'enUS'end;C_Timer={After=function()end}
 UnitGUID=function()return'Player-map29'end;UnitLevel=function()return 60 end;UnitClass=function()return'Mage','MAGE',8 end;UnitFactionGroup=function()return'Alliance'end
 C_QuestLog.IsOnQuest=function()return false end;C_QuestLog.ReadyForTurnIn=function()return false end
 C_QuestLog.GetTitleForQuestID=function(id)return a.quests[id]and a.quests[id].name end
 local canvas=CreateFrame('Frame');canvas:SetSize(1000,500)
 local map=CreateFrame('Frame');WorldMapFrame=map
 map.GetCanvas=function()return canvas end;map.GetCanvasScale=function()return 1 end;map.GetMapID=function(self)return self.mapID end
 local maps,armed,fired,badCalls={},false,false,0
 local function opener(id)maps[#maps+1]=id;map.mapID=id;map:Show();if mode=='binding'and not fired then armed=true end end
 C_Map.OpenWorldMap=opener
 if mode=='fallback'or mode=='fallbackDrift'then C_Map.OpenWorldMap=nil;OpenWorldMap=opener else OpenWorldMap=nil end
 local point=a.quests[166].start
 local target=mode=='crossmap'and a.quests[5724].finish or a.quests[214].start
 local marker
 local function locate(p)
  for _,object in ipairs(f.objects)do
   local v=object.point
   if object:IsShown()and v and v[1]=='CENTER'and v[2]==canvas and v[3]=='TOPLEFT'and
    math.abs(v[4]-1000*(p.x/100))<1e-9 and math.abs(v[5]+500*(p.y/100))<1e-9 then return object end
  end
 end
 local function replace()
  fired=true;armed=false
  if mode=='readDrift'then local read=a.Read;a.Read=function(...)return read(...)end;return end
  if mode=='nativeDrift'then C_Map.OpenWorldMap=function()badCalls=badCalls+1 end;return end
  if mode=='fallbackDrift'then OpenWorldMap=function()badCalls=badCalls+1 end;return end
  assert(u:InspectQuest(214,true));assert(u:SetDetailTab('sources'))
  if mode=='start'then assert(a.Navigation.Start(u.giverAction))else assert(a.Navigation.Map(target))end
  marker=assert(locate(target),'new exact source marker must be positively visible before old continuation')
  assert(map.mapID==target.mapID)
 end
 local clean=a.Clean
 a.Clean=function(value,kind)
  local result=clean(value,kind)
  local hit=(mode=='identity'and value==point.mapID and kind=='number')or
   (mode=='binding'and value==map.GetCanvas and kind=='function')or
   (mode~='identity'and mode~='binding'and value==point.x and kind=='number')
  if armed and not fired and hit then replace()end
  return result
 end
 local pin;C_Map.GetUserWaypoint=function()return pin end
 C_Map.SetUserWaypoint=function(p)pin=p;return true end;C_Map.ClearUserWaypoint=function()pin=nil end
 UiMapPoint.CreateFromCoordinates=function(id,x,y)return{uiMapID=id,position={x=x,y=y}}end
 e.scripts.OnEvent(e,'ADDON_LOADED','DungeonPro');u:Toggle();u.includeUnavailable=true;u.range=false
 for _,card in ipairs(u.cards)do if card.entranceDungeon and card.entranceDungeon.key=='dm'then card.scripts.OnClick(card);break end end
 assert(u:InspectQuest(166,true));assert(u:SetDetailTab('sources'))
 if mode=='cleanupBefore'or mode=='cleanupAfter'then
  assert(a.Navigation.Map(point));local oldMarker=assert(locate(point));maps={}
  local native=oldMarker.Hide
  oldMarker.Hide=function(self,...)
   if not fired and mode=='cleanupBefore'then replace()end
   local result=native(self,...)
   if not fired and mode=='cleanupAfter'then replace()end
   return result
  end
 elseif mode=='start'then
  -- Observe entry to the real Map body; do not replace its producer or result.
  local real=a.Navigation.Map;a.Navigation.Map=function(p)armed=true;return real(p)end
 else armed=mode~='binding'end
 local accepted
 if mode=='start'then accepted=a.Navigation.Start(u.giverAction)else accepted=a.Navigation.Map(point)end
 assert(fired,'intended native/sanitizer boundary must fire')
 if mode=='readDrift'or mode=='nativeDrift'or mode=='fallbackDrift'then
  assert(accepted==false and #maps==0 and badCalls==0,'changed helper/capability cannot dispatch an old request')
 else
  assert(u.quest==214 and marker==locate(target)and marker:IsShown()and map.mapID==target.mapID,'newest selected source marker and displayed map survive')
  assert(#maps==(mode=='binding'and 2 or 1),'older map cannot dispatch after supersession')
  if mode~='binding'then assert(accepted==false)end
  if mode=='start'then assert(pin and pin.position.x==a.quests[214].start.x/100)end
 end
 print('PASS '..mode);count=count+1
end
local selected=arg and arg[1]
for _,mode in ipairs({'direct','crossmap','identity','binding','cleanupBefore','cleanupAfter','start','fallback','readDrift','nativeDrift','fallbackDrift'})do if not selected or selected==mode then run(mode)end end
-- Explicit unowned map-only and optional coordinate absence remain legitimate.
local a={};assert(loadfile('Core/Namespace.lua'))('DungeonPro',a);assert(loadfile('UI/Navigation.lua'))('DungeonPro',a)
local opened;C_Map=nil;WorldMapFrame=nil;OpenWorldMap=function(id)opened=id end
assert(a.Navigation.Map({mapID=1436})and opened==1436)
local restricted={};issecretvalue=function(v)return rawequal(v,restricted)end
assert(a.Navigation.Map({mapID=1436,x=restricted,y=1})and opened==1436)
print('PASS explicit map-only/fallback/restrictedcoordinate no-marker semantics');count=count+1
print('Map request lifecycle: '..count..' PASS; no native pixel/atomic-rollback claim')
