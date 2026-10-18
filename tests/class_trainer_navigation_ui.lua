-- Actual multi-trainer starts keep every distinct source and reported position.
local fixture=assert(loadfile("tests/client_ui.lua"))("fixture")
local addon,ui=fixture.addon,fixture.addon.UI
C_Timer={After=function()end}
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();addon.db.locale="enUS";ui.includeUnavailable=true;ui.range=false
local context={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}
addon.Context=function()return context end
C_Map.GetMapInfo=function()return nil end
local visits,maps={},0
addon.Navigation={Start=function(action)visits[#visits+1]=action;return true end,
    Map=function()maps=maps+1;return true end}
local expected={
    [3048]={1456,25.4,14.4,5},[4568]={1458,84.4,11,3},[5144]={1455,26.4,9.4,4},
    [5497]={1453,38.4,79.4,6},[5885]={1454,37.8,86.6,5},[3354]={1454,80,32.6,3},
    [4593]={1458,46.6,16.6,5},[5113]={1455,69.2,91.4,7},[5479]={1453,78.8,45.4,3},
    [7315]={1457,58.4,35.4,4},[5489]={1453,38.4,26.6,4},[6018]={1454,35.4,87.6,3},
    [11406]={1455,23.4,7,10},[461]={1453,25.4,78.2,4},[3326]={1454,48.2,45.4,4},
    [4563]={1458,85.2,15.8,4},[5172]={1455,50.2,5.4,4},[3033]={1456,76.4,27.4,4},
    [4217]={1457,34.8,7.4,3},[5505]={1453,21.2,52.6,5},[12042]={1450,52.4,40.4,3},
    [3039]={1456,57.2,89.6,5},[3352]={1454,66.2,18.2,2},[4205]={1457,42.2,7.4,3},
    [5116]={1455,70,84.6,5},[5516]={1453,61.8,15.6,4},[918]={1453,74,52.4,5},
    [3328]={1454,44,54.4,2},[4163]={1457,36.2,21.4,3},[4583]={1458,84.2,71,5},
    [5165]={1455,51.2,16,7},
}
local owners={}
local function associate(id,dungeon,seen)
    if seen[id]then return end;seen[id]=true;owners[id]=owners[id]or dungeon
    local q=assert(addon.quests[id])
    for _,member in ipairs(q.storyline or{})do associate(member,dungeon,seen)end
    for _,group in ipairs(q.requires or{})do for _,member in ipairs(group.ids)do associate(member,dungeon,seen)end end
    for _,group in ipairs(q.storylineGroups or{})do for _,member in ipairs(group)do associate(member,dungeon,seen)end end
end
for _,d in ipairs(addon.dungeons)do local seen={};for _,id in ipairs(d.quests)do associate(id,d,seen)end end
local function shown(pool)local result={};for _,row in ipairs(pool or{})do if row:IsShown()then result[#result+1]=row end end;return result end
local function click(row,id,point)
    assert(row.enabled and type(row.scripts.OnClick)=="function","mapped trainer has an enabled visit action")
    local before,selected,root,history=#visits,ui.quest,ui.questTreeRoot,ui.detailHistory
    row.scripts.OnClick()
    local action=visits[#visits]
    assert(#visits==before+1 and action.id==id and action.kind=="visit" and action.place==point,
        "trainer click visits this quest's exact source without choosing another trainer")
    assert(ui.quest==selected and ui.questTreeRoot==root and ui.detailHistory==history and context.faction=="Alliance",
        "visiting a trainer preserves inspected quest, hierarchy, history and character faction")
end
local occurrences,pointOccurrences,unique=0,0,{}
local retiredTrainer,retiredPoint
for _,id in ipairs({2861,1953,8417,8254,8419,9063,8151,8233})do
    local q=assert(addon.quests[id]);local alternatives=assert(q.startAlternatives)
    assert(not q.start and #alternatives>=3,"all recorded starters remain explicit alternatives")
    ui.dungeon,ui.quest=assert(owners[id]),id;ui.questTreeRoot,ui.questTreeDungeon=nil,nil
    ui.detailReferencesExpanded=false;ui:Refresh()
    local beforeRetired=#visits
    if retiredTrainer then retiredTrainer();retiredPoint()end
    assert(#visits==beforeRetired,"recycled old trainer and reported-point callbacks cannot navigate")
    local roots=#ui.currentPlan.rows
    assert(ui.renderedQuest==id and not ui.giverAction,"no single trainer is selected implicitly")
    local compact=shown(ui.giverButtons)
    assert(#compact==2 and #shown(ui.startButtons)==0,"compact card previews exactly two trainers")
    for index,row in ipairs(compact)do
        assert(row.title.text==alternatives[index].name,"compact trainer identity preserves source order")
        click(row,id,alternatives[index])
        if index==1 then retiredTrainer=row.scripts.OnClick end
    end
    assert(ui.referenceToggle:IsShown(),"remaining trainer sources are reachable")
    ui.referenceToggle.scripts.OnClick()
    local expanded=shown(ui.startButtons)
    assert(#expanded==#alternatives-2,"disclosure retains every remaining trainer")
    for index,row in ipairs(expanded)do
        assert(row.title.text==alternatives[index+2].name,"additional trainer identity preserves source order")
        click(row,id,alternatives[index+2])
    end
    for index,point in ipairs(alternatives)do
        local fact=assert(expected[point.npcID]);occurrences=occurrences+1;unique[point.npcID]=true
        assert(point.mapID==fact[1]and point.x==fact[2]and point.y==fact[3],"trainer targets an actual first source pin")
        assert(#point.reportedLocations==fact[4],"all source-reported positions remain stored")
        local key=index<=2 and "giverAlternative:"..index or "startAlternative:"..(index-2)
        local toggle
        for _,row in ipairs(shown(ui.reportedToggles))do if row.locationKey==key then toggle=row end end
        assert(toggle and toggle.title.text:find(point.name,1,true),"each alternative exposes its own reported points")
        toggle.scripts.OnClick()
        local rows={};for _,row in ipairs(shown(ui.reportedRows))do if row.locationKey==key then rows[#rows+1]=row end end
        assert(#rows==fact[4],"reported-point disclosure exposes the complete source set")
        for position,row in ipairs(rows)do
            local destination=point.reportedLocations[position]
            assert(row.destination.mapID==destination.mapID and row.destination.x==destination.x and row.destination.y==destination.y,
                "reported point retains exact source order and coordinates")
            click(row,id,row.destination);pointOccurrences=pointOccurrences+1
            retiredPoint=row.scripts.OnClick
        end
        toggle=nil
        for _,row in ipairs(shown(ui.reportedToggles))do if row.locationKey==key then toggle=row end end
        toggle.scripts.OnClick()
    end
    assert(#ui.currentPlan.rows==roots,"trainer navigation never changes the dungeon root count")
end
local uniqueCount=0;for _ in pairs(unique)do uniqueCount=uniqueCount+1 end
assert(occurrences==35 and uniqueCount==31 and pointOccurrences==152 and maps==0)
print("Class trainer actual-TOC navigation passed: eight quests, 35 trainers, 152 reported-point visits (native visual acceptance pending)")
