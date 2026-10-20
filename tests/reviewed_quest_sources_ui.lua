-- Actual catalogue endpoints and source roles, exercised through the real TOC.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui = fixture.addon, fixture.addon.UI
C_Timer = { After = function() end }
issecretvalue = function() return false end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
ui:Toggle(); addon.db.locale = "enUS"; ui.includeUnavailable = true
local ready, selected, visits = false, nil, {}
addon.Context = function()
    return {level=60, faction="Alliance", class="MAGE", race=3,
        completed=function(id) return id==155 end,
        active=function(id) return ready and id==selected end,
        ready=function(id) return ready and id==selected end}
end
UnitLevel = function() return 60 end
UnitEffectiveLevel = function() return 60 end
UnitQuestTrivialLevelRange = function() return 5 end
GetQuestDifficultyColor = function() return {r=0,g=1,b=0} end
addon.Navigation = {Start=function(action) visits[#visits+1]=action; return true end}
addon.GiverName = function(point) return point.name end
addon.ItemName = function(id) return "Recorded item "..id end
addon.ItemIcon = function() return 134400 end
addon.CarriedItemCount = function() return 0 end
addon.DialogueRewards, addon.QuestRewards, addon.CachedQuestRewards = function() end, function() end, function() end
local owners = {}
local function associate(id,dungeon,seen)
    if seen[id] then return end
    seen[id]=true; owners[id]=owners[id] or dungeon
    local quest=assert(addon.quests[id])
    for _,member in ipairs(quest.storyline or {}) do associate(member,dungeon,seen) end
    for _,group in ipairs(quest.requires or {}) do
        for _,member in ipairs(group.ids) do associate(member,dungeon,seen) end
    end
    for _,group in ipairs(quest.storylineGroups or {}) do
        for _,member in ipairs(group) do associate(member,dungeon,seen) end
    end
end
for _,dungeon in ipairs(addon.dungeons) do
    local seen={}
    for _,id in ipairs(dungeon.quests) do associate(id,dungeon,seen) end
    for _,id in ipairs(dungeon.sharedQuests or {}) do associate(id,dungeon,seen) end
end
local function contains(text)
    for _,field in ipairs(ui.details) do
        if field:IsShown() and field.text:find(text,1,true) then return true end
    end
    return false
end
local function render(id, turnin, inspectionDungeon)
    selected, ready = id, turnin == true
    ui.dungeon, ui.quest = assert(inspectionDungeon or owners[id]), id
    if inspectionDungeon then ui.questTreeRoot, ui.questTreeDungeon = nil, nil
    else ui.questTreeRoot, ui.questTreeDungeon = 92819, ui.dungeon end
    ui:Refresh()
    if ui.detailTab ~= "quest" then assert(ui:SetDetailTab("quest")) end
    assert(ui.quest==id and ui.renderedQuest==id, "render keeps inspected quest identity")
end
local function giver(id, npc)
    render(id)
    local definition = addon.quests[id]
    assert(ui.giverAction and ui.giverAction.id==id and ui.giverAction.place==definition.start,
        "giver navigation belongs to inspected quest rather than selected root")
    assert(ui.giverAction.place.npcID==npc, "reviewed start NPC must be rendered")
    assert(contains(definition.start.name), "reviewed giver identity is visible")
    local before=#visits; ui.giver.scripts.OnClick()
    assert(#visits==before+1 and visits[#visits].id==id and visits[#visits].place==definition.start,
        "native giver click visits its own recorded endpoint")
end
local function finish(id, npc, inspectionDungeon)
    render(id,true,inspectionDungeon)
    local definition=addon.quests[id]
    assert(ui.action and ui.action.id==id and ui.action.kind=="turnin" and ui.action.place and
        ui.action.place==definition.finish and ui.action.place.npcID==npc,
        "ready quest targets its reviewed turn-in NPC")
    assert(ui:DispatchDetail(ui.action,false))
    assert(visits[#visits].id==id and visits[#visits].place==definition.finish,
        "turn-in dispatch preserves its exact recorded endpoint")
    if definition.start.npcID~=npc then
        assert(contains(addon.L("DETAIL_TURNIN")..": "..definition.finish.name), "distinct turn-in identity is visible")
    end
end
giver(214,820); finish(214,820)
assert(addon.quests[214].start.x==56.6 and addon.quests[214].start.y==47.4 and
    addon.quests[214].finish.x==56.6 and addon.quests[214].finish.y==47.4,
    "Scout start and finish use the same actual source pin")
for _,sample in ipairs({{96394,264943,5},{96403,265003,6}}) do
    local id,npc,count=unpack(sample)
    giver(id,npc); finish(id,npc)
    assert(ui:SetDetailTab("sources"), "reported source choices are reachable in Sources")
    local toggle
    for _,button in ipairs(ui.reportedToggles) do if button:IsShown() and button.locationKey=="start" then toggle=button end end
    assert(toggle and toggle.title.text:find("("..count..")",1,true), "every reported NPC point is offered")
    toggle.scripts.OnClick()
    local countShown=0
    for _,button in ipairs(ui.reportedRows) do if button:IsShown() and button.locationKey=="start" then
        countShown=countShown+1
        local point=addon.quests[id].start.reportedLocations[countShown]
        assert(button.destination.mapID==point.mapID and button.destination.x==point.x and button.destination.y==point.y)
        button.scripts.OnClick()
        assert(visits[#visits].id==id and visits[#visits].place==button.destination, "reported visit retains own quest and exact source point")
    end end
    assert(countShown==count)
end
for _,sample in ipairs({{92748,253092,11026},{92749,11026,11026},{92750,11026,1325},
    {92751,1325,11026},{92752,11026,253092},{92819,253279,253279}}) do
    giver(sample[1],sample[2]); finish(sample[1],sample[3])
end
for _,sample in ipairs({{92744,12},{92747,15}}) do
    render(sample[1])
    assert(contains("|cff00ff00"..addon.L("DETAIL_LEVEL",sample[2]).."|r"), "corrected quest level receives native difficulty color")
end
for _,sample in ipairs({{92751,254552},{92752,254553}}) do
    render(sample[1])
    local found=false
    for _,button in ipairs(ui.objectiveButtons) do if button:IsShown() then
        local binding=button.objectiveBinding
        if binding.id==sample[2] then
            assert(binding.role=="provided" and binding.sourceField=="providedItems" and binding.current(),
                "supplied item remains in its explicit provided role")
            found=true
        end
    end end
    assert(found and contains("Recorded item "..sample[2].." ×?"), "unverified supplied quantity stays explicit")
    assert(not contains("Recorded item "..sample[2].." ×1"), "no invented supplied count")
    for _,button in ipairs(ui.rewardButtons) do assert(not button:IsShown(), "supplied item is not invented as reward") end
end
render(92819)
assert(contains("Detonator used"), "final quest event label is displayed")
assert(addon.quests[92819].objectiveEvents[1].npcID==266995, "event objective retains exact typed NPC identity")
for _,id in ipairs({214,96394,96403,92744,92747,92748,92749,92750,92751,92752,92819}) do
    assert(addon.quests[id].requirementsKnown==false, "source corrections do not claim complete requirements")
end
assert(addon.quests[214].requires[1].ids[1]==155, "existing prerequisite fact survives source correction")
for _,sample in ipairs({{2040,6579},{5725,2425},{5761,3216},{96391,264936}}) do
    finish(sample[1],sample[2])
end
local itemGoals = {
    {96987,{275996}}, {95250,{268518}}, {95775,{270308,270309,270310,270311}},
    {95787,{270308,270309,270310,270311}}, {95788,{270343},5}, {96774,{276894}},
}
for _,sample in ipairs(itemGoals) do
    render(sample[1])
    local shown = {}
    for _,button in ipairs(ui.objectiveButtons) do if button:IsShown() then
        local binding = button.objectiveBinding
        assert(binding.role == "objective" and binding.sourceField == "objectiveItems" and binding.current(),
            "listed collection goals keep their objective role")
        shown[binding.id] = true
    end end
    for _,id in ipairs(sample[2]) do
        assert(shown[id], "every reviewed collection goal is inspectable")
        assert(contains("Recorded item "..id.." ×"..(sample[3] or "?")),
            "only the explicitly recorded quantity is displayed")
    end
    for _,button in ipairs(ui.rewardButtons) do assert(not button:IsShown(), "collection goals are not rewards") end
    assert(not addon.quests[sample[1]].finish, "collection item identity does not invent a finisher")
end
local classGoals={
    {8985,{22227}}, {8990,{22048,22046}}, {8962,{22226}}, {8963,{22227}},
    {8964,{22228}}, {8935,{16713,16712}}, {8941,{16713,16712}}, {8937,{16736,16737}},
    {7647,{18799,18792,18749,18746}}, {8256,{7972},1},
}
for _,sample in ipairs(classGoals) do
    render(sample[1])
    for _,id in ipairs(sample[2]) do
        local found=false
        for _,button in ipairs(ui.objectiveButtons) do if button:IsShown() then
            local binding=button.objectiveBinding
            if binding.id==id then
                assert(binding.role=="objective" and binding.sourceField=="objectiveItems" and binding.current())
                found=true
            end
        end end
        assert(found and contains("Recorded item "..id.." ×"..(sample[3] or "?")),
            "class collection goals retain their exact recorded quantity and role")
    end
    for _,button in ipairs(ui.rewardButtons) do assert(not button:IsShown(), "class goals are not fabricated rewards") end
end
for _,sample in ipairs({{8990,22050},{7647,18804}}) do
    render(sample[1])
    local found=false
    for _,button in ipairs(ui.objectiveButtons) do if button:IsShown() then
        local binding=button.objectiveBinding
        if binding.id==sample[2] then
            assert(binding.role=="provided" and binding.sourceField=="providedItems" and binding.current())
            found=true
        end
    end end
    assert(found,"existing supplied tools remain separate from the newly listed collection goals")
end
-- Standalone definitions are inspected in an explicit pane context, without adding dungeon targets.
local roleInspection = {
    [2203]=assert(owners[2201]), [2440]=assert(owners[2439]), [2501]=assert(owners[2500]),
    [3374]=assert(owners[1424]), [4701]=assert(owners[4742]),
    [4724]=assert(owners[4742]), [4729]=assert(owners[4742]),
    [4734]=assert(owners[4765]), [4788]=assert(owners[4742]), [4862]=assert(owners[4742]),
    [4867]=assert(owners[4742]), [4982]=assert(owners[4742]), [4983]=assert(owners[4742]),
    [5065]=assert(owners[1424]),
    [96392]=assert(owners[96394]),
}
for id,dungeon in pairs(roleInspection)do
    assert(not owners[id], "standalone definition has no invented natural dungeon association")
    for _,target in ipairs(dungeon.quests)do assert(target~=id,"inspection does not add a dungeon target")end
end
local reviewedItemRoles = {
    {1954,"objectiveItems",{{7291}}}, {8255,"objectiveItems",{{20027,4}}},
    {8419,"objectiveItems",{{14256}}}, {8420,"objectiveItems",{{14256}}},
    {8421,"objectiveItems",{{20613,10},{20614,4}}}, {9052,"objectiveItems",{{22435,8},{22434,8}}},
    {8153,"objectiveItems",{{20017,2}}}, {8231,"objectiveItems",{{20087,6}}},
    {8251,"objectiveItems",{{20028,10}}}, {8252,"objectiveItems",{{20029,6}}},
    {8234,"objectiveItems",{{19775}}}, {8235,"objectiveItems",{{20023,10}}},
    {7646,"objectiveItems",{{12800},{18335}}}, {7624,"objectiveItems",{{18719}}},
    {7625,"objectiveItems",{{18687}}}, {7667,"objectiveItems",{{12800},{18335}}},
    {9051,"providedItems",{{22432}}}, {8416,"providedItems",{{20612}}}, {7644,"providedItems",{{18792}}},
    {5726,"objectiveItems",{{14544}}}, {5727,"providedItems",{{14544}}},
    {877,"providedItems",{{5068}}}, {880,"objectiveItems",{{5098,8}}},
    {1150,"objectiveItems",{{5843},{5845}}}, {1151,"objectiveItems",{{5844}}},
    {1154,"objectiveItems",{{5860}}}, {1052,"providedItems",{{5539}}},
    {4742,"objectiveItems",{{12336},{12335},{12337},{12219}}},
    {8949,"objectiveItems",{{21982,25}}},
    {5466,"providedItems",{{13752}}}, {7508,"providedItems",{{18513}}},
    {3520,"providedItems",{{10699}}}, {2933,"providedItems",{{9321}}},
    {2934,"objectiveItems",{{9322}}}, {2937,"objectiveItems",{{9324}}},
    {2937,"providedItems",{{9323}}}, {2990,"providedItems",{{9468}}},
    {2994,"objectiveItems",{{9472}}}, {4787,"objectiveItems",{{12402}}},
    {3444,"objectiveItems",{{10556}}}, {98815,"objectiveItems",{{284845,4}}},
    {4022,"objectiveItems",{{10575}}}, {4023,"objectiveItems",{{10575}}},
    {4061,"objectiveItems",{{11266,10}}}, {4062,"providedItems",{{11267}}},
    {4121,"objectiveItems",{{11286}}}, {4122,"providedItems",{{11286}}},
    {4183,"providedItems",{{11366}}}, {4184,"providedItems",{{11367}}},
    {4186,"providedItems",{{11368}}}, {4264,"providedItems",{{11446}}},
    {5001,"objectiveItems",{{12345}}}, {5160,"providedItems",{{12923}}},
    {132,"providedItems",{{1327}}}, {135,"providedItems",{{1327}}},
    {141,"providedItems",{{1353}}}, {142,"objectiveItems",{{1381}}},
    {469,"providedItems",{{3347}}}, {471,"objectiveItems",{{3348,6}}},
    {484,"objectiveItems",{{3397,6}}}, {723,"providedItems",{{4635}}},
    {724,"providedItems",{{4635}}}, {725,"providedItems",{{4622}}},
    {762,"objectiveItems",{{4621}}}, {865,"objectiveItems",{{5055,5}}},
    {1193,"objectiveItems",{{15994},{3829}}},
    {8992,"objectiveItems",{{22048},{22046}}},
    {8992,"providedItems",{{22052}}},
    {5531,"providedItems",{{13761}}},
    {5461,"objectiveItems",{{13585}}},
    {5462,"providedItems",{{13585}}},
    {5464,"providedItems",{{13624}}},
    {5465,"providedItems",{{13624}}},
    {5522,"providedItems",{{13761}}},
    {5344,"objectiveItems",{{13470}}},
    {5342,"objectiveItems",{{13469}}},
    {8986,"objectiveItems",{{22226}}},
    {8987,"objectiveItems",{{22228}}},
    {8988,"objectiveItems",{{22229}}},
    {8989,"objectiveItems",{{22048},{22046}}},
    {8989,"providedItems",{{22049}}},
    {8991,"objectiveItems",{{22048},{22046}}},
    {8994,"objectiveItems",{{22138,40},{13512}}},
    {8994,"providedItems",{{22048}}},
    {8995,"objectiveItems",{{22048}}},
    {8995,"providedItems",{{22056}}},
    {8996,"objectiveItems",{{22056}}},
    {8965,"objectiveItems",{{22229}}},
    {8966,"objectiveItems",{{21984}}},
    {8966,"providedItems",{{22049}}},
    {8970,"objectiveItems",{{22094,20}}},
    {8970,"providedItems",{{21984}}},
    {5781,"objectiveItems",{{14613}}},
    {5845,"objectiveItems",{{14625}}},
    {5861,"providedItems",{{14872}}},
    {5862,"providedItems",{{14872}}},
    {7503,"providedItems",{{18361}}},
    {7502,"providedItems",{{18360}}},
    {7506,"providedItems",{{18364}}},
    {7498,"providedItems",{{18356}}},
    {7483,"objectiveItems",{{18332},{18335,1},{14344,2},{12938,2}}},
    {7499,"providedItems",{{18357}}},
    {1424,"objectiveItems",{{6175,10}}},
    {1429,"providedItems",{{6193}}},
    {1452,"objectiveItems",{{6257,3},{6258,3},{6259,3}}},
    {1469,"providedItems",{{6287}}},
    {2201,"providedItems",{{7668}}},
    {2203,"objectiveItems",{{7867,3}}},
    {2203,"providedItems",{{7870}}},
    {2258,"objectiveItems",{{7847,5},{7846,10},{7848,5}}},
    {2279,"providedItems",{{6064}}},
    {2280,"providedItems",{{6064}}},
    {2318,"providedItems",{{7886}}},
    {2338,"providedItems",{{7886}}},
    {2339,"providedItems",{{7668}}},
    {2439,"providedItems",{{8070}}},
    {2440,"providedItems",{{8070}}},
    {2500,"objectiveItems",{{7847,5},{7846,10},{7848,5}}},
    {2501,"objectiveItems",{{7867,3}}},
    {2501,"providedItems",{{7870}}},
    {3374,"providedItems",{{10589}}},
    {4141,"objectiveItems",{{11316,15}}},
    {4142,"providedItems",{{11316}}},
    {4729,"objectiveItems",{{12263}}},
    {4729,"providedItems",{{12262}}},
    {4734,"providedItems",{{12286}}},
    {4743,"objectiveItems",{{12324}}},
    {4743,"providedItems",{{12339}}},
    {4765,"providedItems",{{12437}}},
    {4788,"objectiveItems",{{12740},{12741}}},
    {4862,"objectiveItems",{{12530,15}}},
    {4867,"objectiveItems",{{12712}}},
    {4867,"providedItems",{{12730}}},
    {4982,"objectiveItems",{{12345}}},
    {4983,"providedItems",{{12652}}},
    {5002,"providedItems",{{12770}}},
    {5047,"providedItems",{{12710}}},
    {5065,"objectiveItems",{{12411},{12412}}},
    {5089,"providedItems",{{12780}}},
    {6501,"providedItems",{{16662}}},
    {5527,"objectiveItems",{{22201}}},
    {6568,"providedItems",{{16785}}},
    {6570,"providedItems",{{16787}}},
    {6585,"objectiveItems",{{16872}}},
    {6601,"providedItems",{{16888}}},
    {6824,"objectiveItems",{{17332},{17329},{17331},{17330}}},
    {7029,"objectiveItems",{{17696}}},
    {8939,"objectiveItems",{{16685},{16684}}},
    {8940,"objectiveItems",{{16696},{16692}}},
    {8942,"objectiveItems",{{16673},{16672}}},
    {8943,"objectiveItems",{{16702},{16705}}},
    {8944,"objectiveItems",{{16736},{16737}}},
    {8946,"providedItems",{{22139}}},
    {8947,"objectiveItems",{{11371,3},{12810,20},{14342,3},{15407,4}}},
    {8948,"providedItems",{{21983}}},
    {8950,"objectiveItems",{{22224,1},{20520,4},{14344,8}}},
    {92415,"providedItems",{{251522}}},
    {92421,"objectiveItems",{{268580,25}}},
    {92434,"providedItems",{{279469}}},
    {92459,"providedItems",{{251961}}},
    {95161,"providedItems",{{251522}}},
    {95189,"providedItems",{{268579}}},
    {95195,"providedItems",{{268540,10}}},
    {95204,"providedItems",{{275521}}},
    {95216,"objectiveItems",{{275443}}},
    {95809,"providedItems",{{270901}}},
    {96988,"objectiveItems",{{275997,6}}},
    {97287,"providedItems",{{251961}}},
    {97288,"providedItems",{{280438}}},
    {97289,"providedItems",{{268518}}},
    {97291,"objectiveItems",{{281246},{281300},{8923}}},
    {97292,"providedItems",{{281327}}},
    {5127,"objectiveItems",{{12847},{12806}}}, {5127,"providedItems",{{12848}}},
}
for _,sample in ipairs(reviewedItemRoles) do
    render(sample[1],false,roleInspection[sample[1]])
    for _,item in ipairs(sample[3]) do
        local found=false
        for _,button in ipairs(ui.objectiveButtons) do if button:IsShown() then
            local binding=button.objectiveBinding
            if binding.id==item[1] and binding.sourceField==sample[2] then
                assert(binding.current(), "reviewed item role is current")
                assert(binding.role==(sample[2]=="providedItems" and "provided" or "objective"))
                found=true
            end
        end end
        assert(found and contains("Recorded item "..item[1].." ×"..(item[2] or "?")),
            "reviewed goal/supply has exact known quantity or explicit unknown")
    end
    for _,button in ipairs(ui.rewardButtons) do assert(not button:IsShown(), "reviewed source role is not a reward") end
    assert(addon.quests[sample[1]].requirementsKnown==false)
end
for _,sample in ipairs({{1955,{{6549}}},{1957,{{6550,12}}},{8423,{{5993,7}}},
    {8424,{{6006,20},{6004,10},{6005,20}}},{261,{{11561,30}}},
    {3906,{{9026}}},{4003,{{9019}}},{4182,{{7047,15},{7040,10},{7044,1},{7041,4}}},
    {4262,{{9026}}},{4362,{{9019}}},
    {303,{{1051,15},{1053,5},{1052,5},{1054,5}}},{739,{{2945},{2893,12}}},
    {8992,{{16118}}},{8989,{{16080}}},{8995,{{16042}}},{8966,{{16080}}},
    {4145,{{6509,5},{6512,5},{6510,5},{6511,5}}},{4701,{{10220}}},{4724,{{10220}}},
    {6822,{{11658,1},{11668,1},{11673,1},{12101,1}}},
    {92422,{{250657}}},{92489,{{246016}}},{96986,{{247126}}}}) do
    render(sample[1],false,roleInspection[sample[1]])
    local goals=assert(addon.quests[sample[1]].objectiveKills)
    assert(#goals==#sample[2])
    for index,expected in ipairs(sample[2]) do
        local goal=goals[index]
        assert(goal.npcID==expected[1] and goal.quantity==expected[2], "typed class kill identity and quantity")
        assert(contains(goal.name.." ×"..(expected[2] or "?")), "class kills are visible with truthful quantity")
    end
    assert(addon.quests[sample[1]].requirementsKnown==false)
end
assert(addon.quests[7631].providedItems[1].itemID==18818 and not addon.quests[7631].objectiveItems,
    "existing mount supply remains supplied rather than a collection goal")
-- A continuation definition is inspected in an explicit context without adding a dungeon target.
for _,id in ipairs(owners[5728].quests) do assert(id~=5729, "inspection context does not invent a dungeon target") end
finish(5729,3216,assert(owners[5728]))
render(5727)
assert(contains("Gauge Neeru Fireblade's reaction"), "reaction task is visible as a non-kill event")
assert(addon.quests[5727].objectiveEvents[1].npcID==3216 and not addon.quests[5727].objectiveKills,
    "talking to Neeru is not a slain objective or an invented quantity")
render(877)
assert(contains("Test the Dried Seeds"), "typed world object task is visible")
assert(addon.quests[877].objectiveObjects[1].objectID==3737 and not addon.quests[877].objectiveKills)
for _,id in ipairs({5726,5727,5729,877,880,1150,1151,1154,1052,261}) do
    assert(addon.quests[id].requirementsKnown==false, "new source roles do not authorize availability")
end
render(7508)
local bladeRoles={}
for _,button in ipairs(ui.objectiveButtons) do if button:IsShown() then
    local binding=button.objectiveBinding
    if binding.id==18513 and binding.current() then bladeRoles[binding.role]=binding.sourceField end
end end
assert(bladeRoles.starter=="start" and bladeRoles.provided=="providedItems",
    "the same catalogue item has distinct starter and supplied-item bindings")
render(8945)
assert(contains("Ysida Freed"), "rescue task is visible as a non-kill event")
assert(addon.quests[8945].objectiveEvents[1].npcID==16031 and not addon.quests[8945].objectiveEvents[1].quantity,
    "rescue credit retains its typed NPC identity without an invented quantity")
assert(not addon.quests[8945].objectiveKills and addon.quests[8945].requirementsKnown==false,
    "freeing Ysida does not become killing her or authorize quest pickup")
render(3520)
local spirits=assert(addon.quests[3520].objectiveEvents)
assert(#spirits==1 and spirits[1].npcID==8612 and spirits[1].quantity==3 and contains("Screecher Spirits Collected ×3"),
    "spirit collection is the explicit three-count non-kill NPC credit")
assert(not addon.quests[3520].objectiveKills and addon.quests[3520].requirementsKnown==false,
    "collecting spirits does not invent a slain objective or authorize pickup")
for _,sample in ipairs({{2988,{{144066,"Check First Cage"},{144067,"Check Second Cage"},{144068,"Check Third Cage"}}},
    {2994,{{144070,"Open Sharpbeak's Cage"}}}})do
    render(sample[1])
    local goals=assert(addon.quests[sample[1]].objectiveObjects)
    assert(#goals==#sample[2])
    for index,expected in ipairs(sample[2])do
        local goal=goals[index]
        assert(goal.objectID==expected[1] and goal.name==expected[2] and not goal.quantity,
            "cage tasks retain exact object identity, source order and unknown quantity")
        assert(contains(goal.name.." ×?") and not contains(goal.name.." ×1"),
            "each cage task renders without an invented count")
    end
    assert(not addon.quests[sample[1]].objectiveKills and addon.quests[sample[1]].requirementsKnown==false)
end
render(2933)
assert(not addon.quests[2933].start and #addon.quests[2933].startAlternatives==12,
    "Venom Bottle starter objects remain separate from the supplied item")
for _,point in ipairs(addon.quests[2933].startAlternatives)do
    assert(point.objectID and not point.itemID,"supplied item9321 does not replace any typed starter object")
end
assert(not addon.quests[2933].objectiveItems,
    "the supplied Venom Bottle does not become an invented collection goal")
render(4264)
local noteRoles={}
for _,button in ipairs(ui.objectiveButtons)do if button:IsShown()then
    local binding=button.objectiveBinding
    if binding.id==11446 and binding.current()then noteRoles[binding.role]=binding.sourceField end
end end
assert(noteRoles.starter=="start" and noteRoles.provided=="providedItems","the note retains both its starter and supplied-item bindings")
-- The same shackles are collected in one quest and supplied in the next.
assert(addon.quests[4121].objectiveItems[1].itemID==11286 and not addon.quests[4121].providedItems)
assert(addon.quests[4122].providedItems[1].itemID==11286 and not addon.quests[4122].objectiveItems)
assert(addon.quests[4182].objectiveKills[3].npcID==7044 and addon.quests[4182].objectiveKills[3].quantity==1,
    "Black Drake one is an explicit source count, not an unknown-quantity default")
assert(addon.quests[722].objectiveItems[1].itemID==4635 and not addon.quests[722].providedItems,
    "Hammertoe's Amulet remains a collected objective in Amulet of Secrets")
for _,id in ipairs({723,724})do
    assert(addon.quests[id].providedItems[1].itemID==4635 and not addon.quests[id].objectiveItems,
        "subsequent amulet deliveries remain supplied-item roles")
end
assert(not addon.quests[739].objectiveKills[1].quantity and addon.quests[739].objectiveKills[2].quantity==12,
    "Murdaloc stays quantity-unknown while the explicit twelve Bonesnappers remain known")
for _,sample in ipairs({{7503,18361},{7502,18360},{7506,18364},{7498,18356},{7499,18357}})do
    render(sample[1])
    local roles={}
    for _,button in ipairs(ui.objectiveButtons)do if button:IsShown()then
        local binding=button.objectiveBinding
        if binding.id==sample[2] and binding.current()then roles[binding.role]=binding.sourceField end
    end end
    assert(roles.starter=="start" and roles.provided=="providedItems","the class book retains both starter and supplied-item bindings")
end
assert(addon.quests[5461].objectiveItems[1].itemID==13585 and not addon.quests[5461].providedItems)
assert(addon.quests[5462].providedItems[1].itemID==13585 and not addon.quests[5462].objectiveItems)
assert(addon.quests[8994].providedItems[1].itemID==22048 and addon.quests[8995].objectiveItems[1].itemID==22048,
    "the amulet changes supplied and collected roles between separate quests")
render(3374,false,roleInspection[3374])
local oathstoneRoles={}
for _,button in ipairs(ui.objectiveButtons)do if button:IsShown()then
    local binding=button.objectiveBinding
    assert(binding.id~=10455,"an unverified item reference is not invented as a quest role")
    if binding.id==10589 and binding.current()then oathstoneRoles[binding.role]=binding.sourceField end
end end
assert(oathstoneRoles.starter=="start" and oathstoneRoles.provided=="providedItems",
    "the oathstone retains both its actual starter and supplied-item bindings")
assert(addon.quests[4141].objectiveItems[1].itemID==11316 and not addon.quests[4141].providedItems)
assert(addon.quests[4142].providedItems[1].itemID==11316 and not addon.quests[4142].objectiveItems,
    "the collected bloodpetal becomes an explicit supplied item only in its delivery quest")
render(5089)
local commandRoles={}
for _,button in ipairs(ui.objectiveButtons)do if button:IsShown()then
    local binding=button.objectiveBinding
    if binding.id==12780 and binding.current()then commandRoles[binding.role]=binding.sourceField end
end end
assert(commandRoles.starter=="start"and commandRoles.provided=="providedItems",
    "Drakkisath's command retains both starter and supplied-item bindings")
render(5527)
assert(#addon.quests[5527].objectiveItems==1 and addon.quests[5527].objectiveItems[1].itemID==22201,
    "the exact reliquary identity is not substituted by a same-name different item")
for _,button in ipairs(ui.objectiveButtons)do if button:IsShown()then
    assert(button.objectiveBinding.id~=18539 and button.objectiveBinding.id~=18540,
        "the neighbouring quest's supplied and sealed reliquaries do not leak into5527")
end end
render(5526)
local reliquaryRoles={}
for _,button in ipairs(ui.objectiveButtons)do if button:IsShown()then
    local binding=button.objectiveBinding
    if binding.current()then reliquaryRoles[binding.id]=binding.role end
end end
assert(reliquaryRoles[18539]=="provided"and reliquaryRoles[18540]=="objective"and not reliquaryRoles[22201],
    "the neighbouring reliquary quest keeps its separate supplied and collected identities")
render(7029)
local vines=assert(addon.quests[7029].objectiveEvents)
assert(#vines==1 and vines[1].npcID==13696 and vines[1].quantity==8 and contains("Vylestem Vines healed ×8"),
    "healing eight vines remains an exact non-kill task")
assert(not addon.quests[7029].objectiveKills and addon.quests[7029].requirementsKnown==false,
    "healing does not become a slain objective or a confirmed availability gate")
local vialRoles={}
for _,button in ipairs(ui.objectiveButtons)do if button:IsShown()then
    local binding=button.objectiveBinding
    if binding.current()then vialRoles[binding.id]=binding.role end
end end
assert(vialRoles[17693]=="provided"and vialRoles[17696]=="objective",
    "coated supplied and filled collected vials keep distinct identities and roles")
assert(not addon.quests[6569].objectiveItems and not addon.quests[6569].providedItems,
    "unverified eye item references remain held rather than invented quest roles")
render(96392,false,roleInspection[96392])
assert(#addon.quests[96392].objectiveEvents==1 and addon.quests[96392].objectiveEvents[1].npcID==264936 and not addon.quests[96392].objectiveEvents[1].quantity,
    "typed non-kill event retains NPC identity and unknown quantity")
assert(contains("Use Farsen's Far Sight ×?") and not addon.quests[96392].objectiveKills and addon.quests[96392].requirementsKnown==false,
    "the source action is visible without an invented slain count or availability gate")
render(97292,false,roleInspection[97292])
assert(#addon.quests[97292].objectiveEvents==1 and addon.quests[97292].objectiveEvents[1].npcID==272513 and not addon.quests[97292].objectiveEvents[1].quantity,
    "typed non-kill event retains NPC identity and unknown quantity")
assert(contains("Hissing Serum administered ×?") and not addon.quests[97292].objectiveKills and addon.quests[97292].requirementsKnown==false,
    "the source action is visible without an invented slain count or availability gate")
for _,sample in ipairs({{95189,268579},{95204,275521},{97288,280438}})do
    render(sample[1])
    local roles={}
    for _,button in ipairs(ui.objectiveButtons)do if button:IsShown()then
        local binding=button.objectiveBinding
        if binding.id==sample[2]and binding.current()then roles[binding.role]=binding.sourceField end
    end end
    assert(roles.starter=="start"and roles.provided=="providedItems","starter item keeps both recorded roles and its own identity")
end
assert(addon.quests[95195].providedItems[1].itemID==268540 and addon.quests[95195].providedItems[1].quantity==10 and not addon.quests[95195].objectiveItems,
    "typed supplied ten insignia are not relabelled as a collection from narrative wording")
for _,id in ipairs({92459,97287})do assert(addon.quests[id].providedItems[1].itemID==251961 and not addon.quests[id].objectiveItems)end
for _,id in ipairs({92458,96984})do
    render(id)
    local roles={}
    for _,button in ipairs(ui.objectiveButtons)do if button:IsShown()then
        local binding=button.objectiveBinding
        if binding.current()then roles[binding.id]=binding.role end
    end end
    assert(roles[251961]=="objective"and roles[277507]=="provided",
        "collecting arcane motes preserves the separate supplied sewer key")
end
for _,id in ipairs({92401,92434,97288})do assert(not addon.quests[id].objectiveEvents,"unlinked prose actions stay held without guessed typed identities")end
assert(not addon.quests[5127].objectiveKills,"the Demon Forge item requirements do not invent a Goraluk slain goal")
print("Reviewed quest sources UI: PASS (actual TOC; modeled routing and roles, no native acceptance)")
