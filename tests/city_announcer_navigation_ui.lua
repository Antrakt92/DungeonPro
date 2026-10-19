-- Actual city announcements retain complete patrol lists and honest held sources.
local fixture=assert(loadfile("tests/client_ui.lua"))("fixture")
local addon,ui=fixture.addon,fixture.addon.UI
C_Timer={After=function()end}
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();addon.db.locale="enUS";ui.includeUnavailable=true;ui.range=false
addon.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
C_Map.GetMapInfo=function()return nil end
local visits,maps={},{}
addon.Navigation={Start=function(action)visits[#visits+1]=action;return true end,
    Map=function(point)maps[#maps+1]=point;return true end}
local expected={[10880]={1454,35.6,74.6,59},[10881]={1456,36.4,54.6,87},[2198]={1453,33.2,70.4,76}}
local held={[10879]=1458,[10877]=1455,[10878]=1457}
local function shown(pool)local rows={};for _,row in ipairs(pool or{})do if row:IsShown()then rows[#rows+1]=row end end;return rows end
local function locate(id)
    for _,d in ipairs(addon.dungeons)do
        local seen={}
        local function walk(qid)
            if seen[qid]then return false end;seen[qid]=true
            if qid==id then return true end
            local q=assert(addon.quests[qid])
            for _,other in ipairs(q.storyline or{})do if walk(other)then return true end end
            for _,group in ipairs(q.requires or{})do for _,other in ipairs(group.ids)do if walk(other)then return true end end end
            for _,group in ipairs(q.storylineGroups or{})do for _,other in ipairs(group)do if walk(other)then return true end end end
        end
        for _,root in ipairs(d.quests)do if walk(root)then return d end end
    end
    error("missing actual dungeon association "..id)
end
local function visit(row,id,point)
    assert(row.enabled and row.scripts.OnClick,"complete announcer source has enabled navigation")
    local count,selected,tree,history=#visits,ui.quest,ui.questTreeRoot,ui.detailHistory
    row.scripts.OnClick()
    local action=visits[#visits]
    assert(#visits==count+1 and action.id==id and action.kind=="visit" and action.place==point,
        "native visit keeps the inspected quest and exact selected source endpoint")
    assert(ui.quest==selected and ui.questTreeRoot==tree and ui.detailHistory==history)
end
local points,alternatives=0,0
local retiredSource,retiredPoint
for _,id in ipairs({7492,7494})do
    local q=addon.quests[id];assert(not q.start and #q.startAlternatives==3)
    ui.dungeon,ui.quest=locate(id),id;ui.questTreeRoot,ui.questTreeDungeon=nil,nil
    ui.detailReferencesExpanded=false;ui:Refresh()
    local count,mapCount=#visits,#maps
    if retiredSource then retiredSource();retiredPoint()end
    assert(#visits==count and #maps==mapCount,"old pooled source callbacks expire on another quest")
    assert(ui.renderedQuest==id and not ui.giverAction,"multiple givers never choose a first NPC implicitly")
    local roots=#ui.currentPlan.rows
    assert(ui.detailTab=="quest" and #shown(ui.giverButtons)==0 and #shown(ui.startButtons)==0)
    assert(ui:SetDetailTab("sources"))
    assert(ui.detailTab=="sources")
    assert(#shown(ui.giverButtons)==2 and #shown(ui.startButtons)==1,"compact two plus disclosure expose exactly three sources")
    local rows=shown(ui.giverButtons);rows[#rows+1]=shown(ui.startButtons)[1]
    for index,point in ipairs(q.startAlternatives)do
        alternatives=alternatives+1
        local row=rows[index];assert(row.title.text==point.name,"source identity and order remain exact")
        local key=index<=2 and "giverAlternative:"..index or "startAlternative:"..(index-2)
        local toggle
        for _,button in ipairs(shown(ui.reportedToggles))do if button.locationKey==key then toggle=button end end
        local fact=expected[point.npcID]
        if fact then
            assert(point.mapID==fact[1]and point.x==fact[2]and point.y==fact[3],"primary is actual first source point")
            assert(#point.reportedLocations==fact[4]and toggle,"all complete source points are reachable")
            visit(row,id,point);retiredSource=row.scripts.OnClick
            toggle.scripts.OnClick()
            local reported={};for _,button in ipairs(shown(ui.reportedRows))do if button.locationKey==key then reported[#reported+1]=button end end
            assert(#reported==fact[4],"no patrol point is truncated")
            for position,button in ipairs(reported)do
                local original=point.reportedLocations[position]
                assert(button.destination.mapID==original.mapID and button.destination.x==original.x and button.destination.y==original.y,
                    "reported visits preserve every source coordinate and its source order")
                visit(button,id,button.destination);points=points+1;retiredPoint=button.scripts.OnClick
            end
            for _,button in ipairs(shown(ui.reportedToggles))do if button.locationKey==key then button.scripts.OnClick();break end end
        else
            assert(held[point.npcID]~=nil and not point.x and not point.y and not point.reportedLocations and not toggle,
                "large held patrols never acquire a partial or invented precise route")
            if held[point.npcID]then
                assert(row.enabled and point.mapID==held[point.npcID])
                local before=#maps;row.scripts.OnClick()
                assert(#maps==before+1 and maps[#maps]==point,"existing area-only source opens its own map")
            else assert(not row.enabled and not row.scripts.OnClick,"unknown area remains unavailable")end
        end
    end
    assert(#ui.currentPlan.rows==roots,"source navigation does not change dungeon root membership")
end
assert(alternatives==6 and points==222 and #visits==225 and #maps==3)
ui.quest=7492;ui:Refresh()
local count=#visits;retiredSource();retiredPoint();assert(#visits==count,"last quest source controls also retire")
print("City announcer navigation: PASS (actual two quests, three complete sources/222 points, three held sources; modeled)")
