-- Missing alternative-source positions stand out without changing verified travel choices.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
C_Timer={After=function()end};issecretvalue=function()return false end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle();ui.includeUnavailable=true;a.db.locale="enUS"
a.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
a.DialogueRewards,a.QuestRewards,a.CachedQuestRewards=function()end,function()end,function()end
local visits,maps={},{}
a.Navigation={Start=function(action)visits[#visits+1]=action;return true end,Map=function(point)maps[#maps+1]=point;return true end}
local owners={}
for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=owners[id]or d end end
local function render(id,expanded)
 -- Standalone2933 is explicit pane inspection; no catalogue association is added.
 ui.dungeon,ui.quest=assert(owners[id]or(id==2933 and owners[3801])),id;ui:Refresh()
 if ui.detailTab~="quest"then assert(ui:SetDetailTab("quest"))end
 if expanded then assert(ui:SetDetailTab("sources")) end
 assert(ui.quest==id and ui.renderedQuest==id)
end
local function warning(text)return"|cffff594d"..text.."|r"end
for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","ptBR","koKR","zhCN","zhTW","itIT"})do
 a.db.locale=locale;render(3801,true)
 for _,pool in ipairs({ui.giverButtons,ui.finishButtons})do
  local known,unknown=assert(pool[1]),assert(pool[2])
  assert(known:IsShown()and unknown:IsShown()and known.title.text==unknown.title.text,"same-name NPC variants remain distinct source choices")
  local area=a.SourceAreaName("Burning Steppes")or"Burning Steppes"
  assert(known.note.text==area.." — "..warning(a.L("SOURCE_POSITION_UNKNOWN")),"known translated area stays normal text beside a red missing-position warning")
  assert(unknown.note.text==warning(a.L("UNKNOWN_PLACE")),"wholly unknown source location is conspicuous without claiming a known area")
  assert(not known.enabled and not unknown.enabled and not known.scripts.OnClick and not unknown.scripts.OnClick,"warning adds no arbitrary route or availability claim")
 end
end
a.db.locale="enUS"
render(7492,true)
local areaOnly=assert(ui.giverButtons[1]);assert(areaOnly.enabled and not areaOnly.note.text:find("|cffff594d",1,true),"verified map-only source retains its ordinary area note and usable map action")
areaOnly.scripts.OnClick();assert(#maps==1 and maps[1]==a.quests[7492].startAlternatives[1]and #visits==0,"map-only source dispatches its own known map")
render(7494,true)
local exact=assert(ui.giverButtons[1]);assert(exact.enabled and not exact.note.text:find("|cffff594d",1,true),"verified point retains normal note and precise visit action")
exact.scripts.OnClick();assert(#visits==1 and visits[1].id==7494 and visits[1].place==a.quests[7494].startAlternatives[1],"precise source visit retains exact own NPC point")
render(2933,true)
local count=0
for _,pool in ipairs({ui.giverButtons,ui.startButtons})do for _,button in ipairs(pool)do if button:IsShown()then
 count=count+1;assert(button.enabled and not button.note.text:find("|cffff594d",1,true),"all twelve actual mapped object sources keep usable ordinary notes")
end end end
assert(count==12,"warning styling does not hide or replace manual source choices")
-- A retired native warning write cannot recolor a newly rendered mapped source.
local button=assert(ui.giverButtons[1]);local expected=button.note.text
render(3801,true);assert(button==ui.giverButtons[1])
local setter=button.note.SetText;local armed,fired=true,false
button.note.SetText=function(self,text,...)
 if armed and text:find("|cffff594d",1,true)then armed,fired=false,true;render(2933,true)end
 return setter(self,text,...)
end
ui.quest=3801;ui.dungeon=assert(owners[3801]);ui:Refresh();button.note.SetText=setter
assert(fired and ui.quest==2933 and ui.renderedQuest==2933 and button:IsShown()and button.note.text==expected,"new mapped source survives the retired warning setter tail")
-- Source facts changed by warning localization retire that old area's publication.
render(3801,true)
local source=a.quests[3801].startAlternatives[1]
local previous=source.zoneName
local localize=a.L;armed,fired=true,false
a.L=function(key,...)
 local text=localize(key,...)
 if armed and key=="SOURCE_POSITION_UNKNOWN"then armed,fired=false,true;source.zoneName="Newly recorded area";return"Retired alternate warning"end
 return text
end
ui:RefreshDetail();a.L=localize
assert(fired,"source localization mutation actually fired")
for _,button in ipairs(ui.giverButtons)do assert(not button:IsShown()or not button.note.text:find("Retired alternate warning",1,true),"changed source facts cannot publish an old warning")end
render(3801,true)
assert(ui.giverButtons[1].note.text=="Newly recorded area — "..warning(a.L("SOURCE_POSITION_UNKNOWN")),"fresh render shows the latest recorded area with its warning")
source.zoneName=previous
-- Controlled same-NPC point insertion is a fixture only, not a production coordinate claim.
render(3801,true)
local previousMap,previousX,previousY=source.mapID,source.x,source.y
armed,fired=true,false
a.L=function(key,...)
 local text=localize(key,...)
 if armed and key=="SOURCE_POSITION_UNKNOWN"then
  armed,fired=false,true;source.mapID,source.x,source.y=1455,36,3.4
  return"Retired mapless-source warning"
 end
 return text
end
ui:RefreshDetail();a.L=localize
assert(fired and source.npcID==8888,"same typed NPC point actually changed during source warning localization")
for _,button in ipairs(ui.giverButtons)do assert(not button:IsShown()or not button.note.text:find("Retired mapless-source warning",1,true),"new point retires the old no-map warning")end
render(3801,true)
assert(ui.giverButtons[1].enabled and ui.giverButtons[1].note.text:find("(36.0, 3.4)",1,true)and not ui.giverButtons[1].note.text:find("|cffff594d",1,true),"fresh same-NPC point replaces its old missing-position warning")
source.mapID,source.x,source.y=previousMap,previousX,previousY
render(3801,true)
-- A finish source keeps its parent list, exact member, definition and catalogue identity.
for _,mode in ipairs({"array","member","definition","catalogue"})do
 render(3801,true)
 local catalogue,definition=a.quests,a.quests[3801]
 local finishes=definition.finishAlternatives;local first=finishes[1]
 local newFirst={npcID=first.npcID,name=first.name,zoneName="Latest finish area"}
 local replacement={newFirst,finishes[2]}
 local seen=0;localize=a.L;fired=false
 a.L=function(key,...)
  local text=localize(key,...)
  if key=="SOURCE_POSITION_UNKNOWN"then
   seen=seen+1
   if seen==2 then
    fired=true
    if mode=="array"then definition.finishAlternatives=replacement
    elseif mode=="member"then finishes[1]=newFirst
    else
     local newer={};for key,value in pairs(definition)do newer[key]=value end;newer.finishAlternatives=replacement
     if mode=="definition"then catalogue[3801]=newer
     else local root={};for key,value in pairs(catalogue)do root[key]=value end;root[3801]=newer;a.quests=root end
    end
    return"Retired finish warning"
   end
  end
  return text
 end
 ui:RefreshDetail();a.L=localize
 assert(fired,"finish source replacement actually fired: "..mode)
 for _,button in ipairs(ui.finishButtons)do assert(not button:IsShown()or not button.note.text:find("Retired finish warning",1,true),"expired finish source cannot publish its old warning: "..mode)end
 render(3801,true)
 assert(ui.finishButtons[1].note.text=="Latest finish area — "..warning(a.L("SOURCE_POSITION_UNKNOWN")),"fresh finish source displays the latest recorded area: "..mode)
 a.quests=catalogue;catalogue[3801]=definition;definition.finishAlternatives=finishes;finishes[1]=first
end
render(3801,true)
assert(#visits==1 and #maps==1,"inspection and styling never navigate automatically")
print("Alternative source warnings: PASS (actual TOC; modeled style and actions only)")
