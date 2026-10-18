-- Windsor's READY destination and every reported visit retain their own map.
local fixture=assert(loadfile("tests/client_ui.lua"))("fixture")
local addon,ui=fixture.addon,fixture.addon.UI
C_Timer={After=function()end}
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();addon.db.locale="enUS";ui.includeUnavailable=true;ui.range=false
addon.Context=function()return{level=60,faction="Alliance",class="MAGE",
    completed=function()return false end,active=function(id)return id==6402 end,ready=function(id)return id==6402 end}end
C_Map.GetMapInfo=function()return nil end
local visits,maps={},0
addon.Navigation={Start=function(action)visits[#visits+1]=action;return true end,
    Map=function()maps=maps+1;return true end}
local dungeon;for _,d in ipairs(addon.dungeons)do if d.key=="brd"then dungeon=d end end
ui.dungeon,ui.quest=assert(dungeon),6402;ui.questTreeRoot,ui.questTreeDungeon=4322,dungeon
ui:Refresh()
local quest=addon.quests[6402];local finish=quest.finish
assert(finish.npcID==12580 and finish.mapID==1453 and finish.x==60.2 and finish.y==51.6,
    "READY Windsor has the actual first Stormwind source point")
assert(ui.action.id==6402 and ui.action.kind=="turnin" and ui.action.place==finish,
    "READY destination belongs to inspected Windsor quest, not selected dungeon root")
assert(ui:DispatchDetail(ui.action,false))
assert(#visits==1 and visits[1].id==6402 and visits[1].place==finish)
assert(ui.giverAction.id==6402 and ui.giverAction.place==quest.start and quest.start.npcID==9560 and quest.start.mapID==1428,
    "quest giver remains the separate Marshal Maxwell endpoint")
ui.giver.scripts.OnClick()
assert(#visits==2 and visits[2].place==quest.start)
assert(ui.referenceToggle:IsShown());ui.referenceToggle.scripts.OnClick()
local toggle
for _,row in ipairs(ui.reportedToggles)do if row:IsShown()and row.locationKey=="finish"then toggle=row end end
assert(toggle and toggle.title.text:find("Reginald Windsor",1,true))
toggle.scripts.OnClick()
local count,stormwind,elwynn=0,0,0
local retired
for _,row in ipairs(ui.reportedRows)do if row:IsShown()and row.locationKey=="finish"then
    count=count+1;local source=finish.reportedLocations[count];local point=row.destination
    assert(point.mapID==source.mapID and point.x==source.x and point.y==source.y,"exact reported position and order preserved")
    if count<=24 then assert(point.mapID==1453);stormwind=stormwind+1
    else assert(point.mapID==1429);elwynn=elwynn+1 end
    local before,selected,root,history=#visits,ui.quest,ui.questTreeRoot,ui.detailHistory
    row.scripts.OnClick()
    local action=visits[#visits]
    assert(#visits==before+1 and action.id==6402 and action.kind=="visit" and action.place==point,
        "reported click uses its own map and coordinate without the primary map leaking")
    assert(ui.quest==selected and ui.questTreeRoot==root and ui.detailHistory==history)
    retired=row.scripts.OnClick
end end
assert(count==31 and stormwind==24 and elwynn==7 and #visits==33 and maps==0)
local last=finish.reportedLocations[31];assert(last.mapID==1429 and last.x==34.6 and last.y==53.2)
assert(quest.requirementsKnown==false,"source positions do not authorize pickup availability")
ui.quest=4322;ui:Refresh();local countBefore=#visits;retired();assert(#visits==countBefore,"retired cross-map source handler cannot visit another quest")
print("Windsor navigation: PASS (actual READY finisher, distinct giver, 24 Stormwind plus seven Elwynn points; modeled)")
