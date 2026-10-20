-- World-area display aliases never supply a map identity or change a source point.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
local actualAPI=a.SourceAreaName
issecretvalue=function()return false end;GetLocale=function()return"enUS"end;C_Timer={After=function()end}
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");ui:Toggle();ui.includeUnavailable=true
a.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
local owners={};for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do owners[id]=owners[id]or d end end
local labels={["The Hinterlands"]="Внутренние земли",Ironforge="Стальгорн"}
local function provider(name,owner)
 if owner and not owner()then return nil end
 local locale=a.db.locale;local label=locale=="ruRU"and labels[name]
 local function current()return a.SourceAreaName==provider and a.db.locale==locale and
  (not label or labels[name]==label)end
 return label,current,current -- callback-free identity/locale/label proof also supplies the raw capability
end
a.SourceAreaName=provider;a.db.locale="ruRU"
C_Map.GetMapInfo=function()return{name="Opposite native area"}end
local function render(id,tab)
 ui.quest,ui.dungeon=id,owners[id]or owners[166];ui:Refresh()
 if tab then assert(ui:SetDetailTab(tab))end
 assert(ui.quest==id and ui.renderedQuest==id)
end
local function visible(text)
 for _,field in ipairs(ui.details)do if field:IsShown()and field.text and field.text:find(text,1,true)then return true end end
 for index,row in ipairs(ui.detailContactRows or{})do
  local binding=row.detailContactBinding
  if row:IsShown()and binding and binding.questID==ui.quest and binding.field==(index==1 and "start"or"finish")and
   binding.endpoint==a.quests[ui.quest][binding.field]and binding.current()then
   for _,field in ipairs({row.title,row.note})do
    if field:IsShown()and field.text and field.text:find(text,1,true)then return field end
   end
  end
 end
end
render(2933,"sources")
local alternatives=a.quests[2933].startAlternatives
local points={};for index,point in ipairs(alternatives)do
 assert(point.zoneName=="The Hinterlands"and point.mapID==1425)
 points[index]={point=point,x=point.x,y=point.y}
end
local choices={};for _,pool in ipairs({ui.giverButtons,ui.startButtons})do for _,row in ipairs(pool)do
 if row:IsShown()then choices[#choices+1]=row end
end end
assert(#choices==12)
local nav=a.Navigation;local visits={}
a.Navigation={Start=function(action)visits[#visits+1]=action;return true end}
-- Refresh to bind the current navigation provider while keeping the actual source array.
ui:RefreshDetail()
for index,row in ipairs(choices)do
 assert(row.note.text:find(labels["The Hinterlands"],1,true),"all actual bottle areas use the selected label")
 row.scripts.OnClick()
 assert(visits[index].place==points[index].point and visits[index].place.mapID==1425 and
  visits[index].place.x==points[index].x and visits[index].place.y==points[index].y,"display aliases preserve every exact recorded point")
end
a.Navigation=nav
render(2204)
assert(visible(labels.Ironforge),"actual finisher area is translated independently of the mapless summoned start")
local finish=a.quests[2204].finish
assert(finish.mapID==1455 and not a.quests[2204].start.mapID)
assert(nav.Start({id=2204,kind="visit",place=finish}))
local guide;for _,o in ipairs(f.objects)do if o.title and o.note and o.label and o.scripts.OnUpdate then guide=o end end
assert(guide and guide.note.text:find(labels.Ironforge,1,true)and not guide.note.text:find("Opposite native area",1,true),
 "guide prefers the selected reviewed canonical area before native map language")
nav.Stop()
a.db.locale="itIT";render(2933,"sources")
assert(ui.giverButtons[1].note.text:find("Opposite native area",1,true),"missing reviewed language keeps native area fallback")
a.SourceAreaName=function(name)return labels[name]end;a.db.locale="ruRU";render(2933,"sources")
assert(ui.giverButtons[1].note.text:find(labels["The Hinterlands"],1,true),"existing one-return area adapters remain supported")
-- Arrow-hint composition reuses an actual bottle point in a controlled direct-start
-- renderer fixture; this does not assert a new association or alter source data.
a.SourceAreaName=provider
local q=a.quests[166];local original=q.start;q.start=alternatives[1]
local tip={}
function tip:SetOwner(owner)self.owner=owner end
function tip:IsOwned(owner)return self.owner==owner end
function tip:SetText(text)self.title=text end
function tip:AddLine(text)self.body=text end
function tip:Show()self.shown=true end
function tip:Hide()self.shown=false end
GameTooltip=tip;render(166)
local selected;for _,r in ipairs(ui.rows)do if r:IsShown()and r.questID==166 then selected=r;break end end
assert(selected and selected.navigationBinding.action)
selected.navigationControl.scripts.OnEnter()
assert(tip.shown and tip.body:find(labels["The Hinterlands"],1,true),"row hint retains the same selected area")
ui.giver.scripts.OnEnter()
assert(tip.shown and tip.body:find(labels["The Hinterlands"],1,true),"detail hint retains the same selected area")
q.start=original
-- The real registry and lazy reviewed dictionary supply the production labels.
a.SourceAreaName=actualAPI
local dictionary=assert(a.GetNameTranslations("ruRU",function()return true end))
local hinterlands=assert(dictionary.areas["The Hinterlands"]).name
local ironforge=assert(dictionary.areas.Ironforge).name
assert(a.sourceAreaNames["The Hinterlands"].name=="The Hinterlands")
render(2933,"sources")
for _,pool in ipairs({ui.giverButtons,ui.startButtons})do for _,r in ipairs(pool)do
 if r:IsShown()then assert(r.note.text:find(hinterlands,1,true),"actual reviewed world label reaches every source row")end
end end
render(2204);assert(visible(ironforge),"actual reviewed finisher area reaches Quest")
render(1100,"sources");ui.reportedExpanded["container:1"]=true;ui:RefreshDetail()
local thousand=assert(dictionary.areas["Thousand Needles"]).name
local count=0;for _,r in ipairs(ui.reportedRows)do if r:IsShown()and r.locationKey=="container:1"then
 count=count+1;assert(r.title.text:find(thousand,1,true),"reported container positions share the reviewed area")
end end
assert(count==2,"both actual journal-container positions are exercised")
print("World area names UI: PASS (actual12 source points, finisher and guide language; modeled presentation only)")
