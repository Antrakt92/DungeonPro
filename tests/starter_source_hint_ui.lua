-- Actual TOC item-start inspection retains acquisition provenance without routing.
local override=...;local loader=loadfile
if override then loadfile=function(path)return loader(path=="UI/QuestNavigation.lua"and override or path)end end
local f=assert(loader("tests/client_ui.lua"))("fixture");loadfile=loader
local a,u=f.addon,f.addon.UI
C_Timer={After=function()end};issecretvalue=function()return false end;GetLocale=function()return"enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true
local routes=0;a.Navigation={Start=function()routes=routes+1;return true end,Map=function()routes=routes+1;return true end}
a.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
a.ItemName=function(id)return"Item "..id end;a.GiverName=function(point)return point.name end
local q=assert(a.quests[373]);local original=q.start;local d
for _,candidate in ipairs(a.dungeons)do for _,id in ipairs(candidate.quests)do if id==373 then d=candidate end end end
assert(d,"actual Unsent Letter dungeon root")
local tip={lines={}}
function tip:SetOwner(owner)self.owner=owner;self.lines={}end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetText(value)self.title=value end
function tip:AddLine(value)self.lines[#self.lines+1]=value end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip
local function render()
 u.dungeon,u.quest=d,373;u:Refresh()
 for _,row in ipairs(u.rows)do if row:IsShown()and row.questID==373 then return row end end
 error("missing actual quest373 row")
end
local function has(value)for _,line in ipairs(tip.lines)do if line:find(value,1,true)then return true end end end
local row=render();local control=row.navigationControl
control.scripts.OnEnter()
assert(tip.shown and tip.title==a.L("SOURCE_DETAILS")and control.sourceInspect,"item retains the inspection book")
assert(has(a.L("START_ITEM_NAVIGATION"))and has("Item "..original.itemID),"generic inspection explanation and own item both remain")
assert(has(original.dropName)and has(d.name),"actual recorded drop actor and dungeon are shown")
assert(q.start==original and original.npcID==nil and routes==0,"drop actor never becomes a quest giver or route")
control.scripts.OnLeave()
local start={};for k,v in pairs(original)do start[k]=v end
start.dropNPCID,start.dropName,start.dungeonKey=nil,nil,nil
start.dropSources={{npcID=111,name="First drop",locationName="First zone"},{npcID=222,name="Second drop",zoneName="Second zone"}}
q.start=start;row=render();control=row.navigationControl;control.scripts.OnEnter()
assert(has("First drop")and has("First zone")and has("Second drop")and has("Second zone"),"typed sources keep independent labels")
local retained=u.navigationTooltip
for _,kind in ipairs({"npc","name","zone","item","member","locale","provider"})do
 row=render();control=row.navigationControl;control.scripts.OnEnter();local held=u.navigationTooltip
 local saved,restore
 if kind=="npc"then saved=start.dropSources[1].npcID;start.dropSources[1].npcID=333;restore=function()start.dropSources[1].npcID=saved end
 elseif kind=="name"then saved=start.dropSources[1].name;start.dropSources[1].name="Changed";restore=function()start.dropSources[1].name=saved end
 elseif kind=="zone"then saved=start.dropSources[1].locationName;start.dropSources[1].locationName="Changed";restore=function()start.dropSources[1].locationName=saved end
 elseif kind=="item"then saved=start.itemID;start.itemID=saved+1;restore=function()start.itemID=saved end
 elseif kind=="member"then saved=start.dropSources[1];start.dropSources[1]={npcID=111,name="First drop",locationName="First zone"};restore=function()start.dropSources[1]=saved end
 elseif kind=="locale"then a.db.locale="ruRU";restore=function()a.db.locale="enUS"end
 else saved=a.SourceName;a.SourceName=function()error("replacement must not run")end;restore=function()a.SourceName=saved end end
 tip.shown=false;assert(held and held.restore);held.restore();assert(not tip.shown,"retired tooltip cannot restore after "..kind)
 restore()
end
-- Name resolution and native tooltip callbacks cannot publish after ownership changes.
for _,phase in ipairs({"name","locale","native"})do
 row=render();control=row.navigationControl
 local source,add=a.SourceName,tip.AddLine;local fired=false
 if phase=="native"then tip.AddLine=function(self,text)add(self,text);if not fired then fired=true;u.quest=nil;u:Refresh()end end
 else a.SourceName=function(point,owner)
  if not fired then fired=true;if phase=="locale"then a.db.locale="ruRU"else q.start={itemID=start.itemID,name="Replacement"}end end
  return source(point,owner)
 end end
 control.scripts.OnEnter();assert(fired and not tip.shown,"reentrant "..phase.." change retires old acquisition hint")
 a.SourceName,tip.AddLine=source,add;a.db.locale="enUS";q.start=start
end
-- Legacy item/start zone fields are not evidence for the drop actor's zone.
local copy={};for k,v in pairs(original)do copy[k]=v end
copy.dungeonKey=nil;copy.zoneName="Unrelated item zone";copy.locationName="Unrelated item location";q.start=copy
row=render();row.navigationControl.scripts.OnEnter()
assert(tip.shown and has(original.dropName)and has(a.L("UNKNOWN_PLACE"))and not has(copy.zoneName)and not has(copy.locationName),"legacy drop uses only its own dungeon-key join")
q.start=original
local dungeonGetter=a.DungeonName
for _,phase in ipairs({"replace","reentry"})do
 row=render();row.navigationControl.scripts.OnEnter();local held=u.navigationTooltip
 if phase=="replace"then
  a.DungeonName=function()error("replaced dungeon resolver must not run")end;tip.shown=false;held.restore();assert(not tip.shown,"dungeon resolver replacement retires held labels")
 else
  local fired=false;a.DungeonName=function(value)if not fired then fired=true;a.db.locale="ruRU"end;return dungeonGetter(value)end
  row.navigationControl.scripts.OnEnter();assert(fired and not tip.shown,"dungeon resolver locale reentry cannot publish retired source labels")
 end
 a.DungeonName=dungeonGetter;a.db.locale="enUS"
end
-- Native dungeon label identities belong to the same acquisition proof.
q.start=original
for _,kind in ipairs({"instance","art","artFile","artMap","nativeGetter"})do
 row=render();row.navigationControl.scripts.OnEnter();local held=u.navigationTooltip
 assert(held and tip.shown,"current native dungeon label is shown")
 local restore
 if kind=="instance"then local saved=d.instanceID;d.instanceID=(saved or 1)+1;restore=function()d.instanceID=saved end
 elseif kind=="art"then local saved=d.art;d.art={fileID=1,gameMapID=2};restore=function()d.art=saved end
 elseif kind=="artFile"then local art=assert(d.art);local saved=art.fileID;art.fileID=(saved or 1)+1;restore=function()art.fileID=saved end
 elseif kind=="artMap"then local art=assert(d.art);local saved=art.gameMapID;art.gameMapID=(saved or 1)+1;restore=function()art.gameMapID=saved end
 else local saved=GetRealZoneText;GetRealZoneText=function()error("replacement must not be called")end;restore=function()GetRealZoneText=saved end end
 tip.shown=false;held.restore();assert(not tip.shown,"native dungeon identity mutation retires held label: "..kind)
 restore()
end
-- Optional exact container names stay separate from typed drop actors.
q.start={itemID=original.itemID,name=original.name,containerSource={objectID=444,name="Recorded cache",zoneName="Cache zone"}}
row=render();row.navigationControl.scripts.OnEnter();assert(tip.shown and has("Recorded cache")and has("Cache zone")and routes==0)
q.start={itemID=original.itemID,name=original.name};row=render();row.navigationControl.scripts.OnEnter()
assert(tip.shown and #tip.lines==2 and not has(original.dropName),"unknown acquisition adds only the actual item, never a guessed actor")
q.start={itemID=original.itemID,name=original.name,dropSources={{npcID=111,objectID=444,name="Mixed source",zoneName="Invented zone"}}}
row=render();row.navigationControl.scripts.OnEnter();assert(tip.shown and not has("Mixed source"),"mixed typed roles are not promoted into drop labels")
q.start=start;row=render();row.navigationControl.scripts.OnEnter();local held=u.navigationTooltip
local template=a.locales.enUS.ITEM_DROP_SOURCE;a.locales.enUS.ITEM_DROP_SOURCE="Changed %s in %s"
tip.shown=false;held.restore();assert(not tip.shown,"literal dictionary mutation retires old source wording");a.locales.enUS.ITEM_DROP_SOURCE=template
q.start=original;row=render();control=row.navigationControl;control.scripts.OnEnter();assert(tip.shown and has(original.dropName))
control.scripts.OnClick();assert(u.quest==373 and routes==0,"inspection never navigates to a guessed drop location")
print("PASS actual373 item/drop/dungeon hint, typed sources, stale source/member/locale/provider and native reentry; no giver substitution/navigation")
