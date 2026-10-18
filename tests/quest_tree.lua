local addon = {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/QuestTree.lua"))("DungeonPro", addon)
local total = 0
local function check(name, fn)
    issecretvalue = nil
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err))
    total = total + 1
    print("PASS " .. name)
end
local function fixture(quests, status)
    local fresh, calls = true, {}
    local engine = {}
    function engine:Current() return fresh end
    function engine:State(id)
        calls[#calls + 1] = id
        return { status = status and status[id] or (quests[id] and "AVAILABLE" or "UNKNOWN"),
            reason = not quests[id] and "missing" or nil, completedHistory = status and status[id] == "COMPLETED" or false }
    end
    return engine, calls, function() fresh = false end
end
local function ids(nodes)
    local values = {}
    for _, node in ipairs(nodes) do values[#values + 1] = node.id end
    return table.concat(values, ",")
end
check("Required history is chronological and retains completed parents and the selected root", function()
    local quests = { [1] = { requires = {{ids={2}}} }, [2] = { requires = {{ids={3}}} }, [3] = {} }
    local engine = fixture(quests, {[3]="COMPLETED",[2]="ACTIVE",[1]="LOCKED"})
    local tree = assert(addon.QuestTree.Build(quests, engine, 1))
    assert(ids(tree)=="3,2,1" and tree[1].state.completedHistory and tree[2].state.status=="ACTIVE")
    assert(tree[1].depth==2 and tree[2].depth==1 and tree[3].root and tree[3].depth==0)
    assert(tree[2].parentID==1 and tree[2].mode=="completed" and tree.current())
end)
check("AND groups and OR alternatives preserve source group semantics without choosing a branch", function()
    local quests = {[1]={requires={{ids={2,3},mode="active"},{ids={4}}}},[2]={},[3]={},[4]={}}
    local engine = fixture(quests)
    local tree = assert(addon.QuestTree.Build(quests,engine,1))
    assert(ids(tree)=="2,3,4,1")
    assert(tree[1].group==1 and tree[2].group==1 and tree[1].alternatives==2 and tree[2].alternatives==2)
    assert(tree[1].mode=="active" and tree[3].group==2 and tree[3].alternatives==1 and tree[3].mode=="completed")
end)
check("Optional story prerequisites stay inspectable without becoming mandatory target requirements", function()
    local quests = {[1]={requires={{ids={2}}},storyline={3,2,1,4}},[2]={},[3]={requires={{ids={5}}}},[4]={},[5]={}}
    local engine = fixture(quests)
    local tree = assert(addon.QuestTree.Build(quests,engine,1))
    assert(ids(tree)=="2,1,5,3,4" and tree[4].relation=="story" and tree[5].relation=="story")
    assert(tree[1].relation=="required" and tree[4].storyIndex==1 and tree[5].storyIndex==4)
    assert(tree[3].relation=="required" and tree[3].requirementScope=="story" and tree[3].storyOwnerID==3 and not tree[3].onTargetPath)
end)
check("A source story member exposes its proven ancestors with exact OR active-mode links",function()
    local quests={[92819]={storyline={92742,92819}},[92742]={requires={{ids={9971,9972},mode="active"},{ids={9973}}}},
        [9971]={requires={{ids={9973}}}},[9972]={},[9973]={}}
    local engine,calls=fixture(quests)
    local tree=assert(addon.QuestTree.Build(quests,engine,92819))
    assert(ids(tree.presentation)=="9973,9971,9972,92742,92819")
    local first,second,third=tree.presentation[1],tree.presentation[2],tree.presentation[3]
    assert(first.requirementScope=="story" and #first.links==2 and not first.onTargetPath)
    assert(second.parentID==92742 and second.group==1 and second.mode=="active" and second.alternatives==2)
    assert(third.parentID==92742 and third.group==1 and third.mode=="active" and third.alternatives==2)
    for _,node in ipairs({first,second,third})do
        assert(node.storyOwnerID==92742 and not node.onTargetPath)
        for _,edge in ipairs(node.links)do assert(edge.scope=="story" and edge.storyOwnerID==92742)end
    end
    assert(#calls==5 and tree.current())
    quests[9971].requires[1].ids[1]=9972;assert(not tree.current(),"retained story dependency sources remain guarded")
end)
check("Explicit story slots outrank conflicting optional dependency order without inventing target requirements",function()
    local quests={[1]={storyline={2,1,3}},[2]={requires={{ids={3}}}},[3]={requires={{ids={4}}}},[4]={}}
    local engine=fixture(quests)
    local tree=assert(addon.QuestTree.Build(quests,engine,1))
    assert(ids(tree.presentation)=="4,2,1,3")
    assert(tree.presentation[1].id==4 and not tree.presentation[1].onTargetPath)
    assert(tree.presentation[4].id==3 and tree.presentation[4].links[1].parentID==2)
    assert(tree.presentation[4].presentationRelation=="story" and not tree.presentation[4].onTargetPath)
end)
check("Shared target and optional-story requirements retain distinct exact edges and bounded cycles",function()
    local quests={[1]={requires={{ids={2}}},storyline={3,1}},[2]={},[3]={requires={{ids={2,4},mode="active"}}},
        [4]={requires={{ids={3}}}}}
    local engine,calls=fixture(quests)
    local tree=assert(addon.QuestTree.Build(quests,engine,1))
    assert(ids(tree.presentation)=="2,4,3,1" and tree.cycle and #calls==4)
    local shared,optional=tree.presentation[1],tree.presentation[2]
    assert(shared.onTargetPath and shared.requirementScope==nil and #shared.links==2)
    assert(shared.links[1].parentID==1 and shared.links[1].scope==nil)
    assert(shared.links[2].parentID==3 and shared.links[2].scope=="story" and shared.links[2].mode=="active")
    assert(not optional.onTargetPath and optional.requirementScope=="story")
    optional.state.status="COMPLETED";assert(not tree.current(),"optional ancestor state snapshots remain owned")
    quests={[1]={storyline={2,1}}}
    for index=2,100 do quests[index]={requires=index<100 and{{ids={index+1}}}or nil}end
    engine=fixture(quests);tree=assert(addon.QuestTree.Build(quests,engine,1))
    assert(tree.truncated and #tree<=80 and tree.current())
    for _,node in ipairs(tree)do assert(node.depth<=50);if node.id~=1 then assert(not node.root)end end
    local rootCount=0;for _,node in ipairs(tree.presentation)do if node.root then rootCount=rootCount+1 end end
    assert(rootCount==1)
end)
check("An earlier story member retains both OR alternatives when it later becomes a proven story prerequisite",function()
    local quests={[1]={storyline={2,3,1}},[2]={},[3]={requires={{ids={2,4},mode="active"}}},[4]={}}
    local engine=fixture(quests)
    local tree=assert(addon.QuestTree.Build(quests,engine,1))
    assert(ids(tree.presentation)=="2,4,3,1")
    local first,second=tree.presentation[1],tree.presentation[2]
    for _,node in ipairs({first,second})do
        assert(node.relation=="required" and node.requirementScope=="story" and node.storyOwnerID==3)
        assert(node.parentID==3 and node.group==1 and node.alternatives==2 and node.mode=="active")
        assert(not node.onTargetPath and #node.links==1 and node.links[1].scope=="story")
    end
    assert(first.storyIndex==1 and first.presentationRelation=="story" and tree.current())
end)
check("Grouped story entries preserve parallel group metadata and deduplicate the root", function()
    local quests = {[1]={storylineGroups={{2,3},{1,4}}},[2]={},[3]={},[4]={}}
    local engine = fixture(quests)
    local tree = assert(addon.QuestTree.Build(quests,engine,1))
    assert(ids(tree)=="1,2,3,4" and tree[2].group==1 and tree[3].group==1 and tree[4].group==2)
    assert(tree[2].mode==nil and tree[2].alternatives==nil)
end)
check("Shared prerequisites are emitted once and cycles terminate with explicit context", function()
    local quests = {[1]={requires={{ids={2}},{ids={3}}}},[2]={requires={{ids={4}}}},[3]={requires={{ids={4}}}},[4]={requires={{ids={1}}}}}
    local engine,calls = fixture(quests)
    local tree = assert(addon.QuestTree.Build(quests,engine,1))
    assert(ids(tree)=="4,2,3,1" and #calls==4 and tree.cycle)
    assert(#tree[1].links==2 and tree[1].links[1].parentID==2 and tree[1].links[2].parentID==3,
        "deduplication retains both dependency edges")
end)
check("Missing records remain unknown inspectable nodes rather than disappearing", function()
    local quests = {[1]={requires={{ids={99}}}}}
    local engine = fixture(quests)
    local tree = assert(addon.QuestTree.Build(quests,engine,1))
    assert(ids(tree)=="99,1" and tree[1].missing and tree[1].state.status=="UNKNOWN" and tree[1].state.reason=="missing")
end)
check("Depth and node budgets preserve the root and disclose truncation", function()
    local quests = {}
    for n=1,100 do quests[n]={requires=n<100 and {{ids={n+1}}} or nil} end
    local engine = fixture(quests)
    local tree = assert(addon.QuestTree.Build(quests,engine,1))
    assert(#tree==51 and tree[#tree].id==1 and tree.truncated)
    quests[1]={storyline={}}
    for n=1,100 do quests[1].storyline[n]=n end
    tree = assert(addon.QuestTree.Build(quests,engine,1))
    assert(#tree==80 and tree[1].root and tree.truncated)
end)
check("Expired context during a state callback publishes no partial hierarchy", function()
    local quests = {[1]={requires={{ids={2}}}},[2]={}}
    local engine,_,expire = fixture(quests)
    local state=engine.State
    engine.State=function(self,id) local result=state(self,id);expire();return result end
    local tree,reason=addon.QuestTree.Build(quests,engine,1)
    assert(tree==nil and reason=="expired")
end)
check("In-place prerequisite mutation and provider replacement invalidate the model", function()
    for _,mode in ipairs({"member","group","definition","getter"})do
        local quests = {[1]={requires={{ids={2}}}},[2]={},[3]={}}
        local engine = fixture(quests)
        local state=engine.State
        engine.State=function(self,id)
            if mode=="member"then quests[1].requires[1].ids[1]=3
            elseif mode=="group"then quests[1].requires[1].mode="active"
            elseif mode=="definition"then quests[1]={}
            else engine.State=function()return{status="AVAILABLE"}end end
            return state(self,id)
        end
        assert(addon.QuestTree.Build(quests,engine,1)==nil,mode)
    end
end)
check("Published models expire when their source state or character context changes", function()
    local quests={[1]={storyline={1,2}},[2]={}}
    local engine,_,expire=fixture(quests)
    local tree=assert(addon.QuestTree.Build(quests,engine,1))
    quests[1].storyline[2]=3;assert(not tree.current())
    quests[1].storyline[2]=2;assert(tree.current())
    tree[1].state.status="COMPLETED";assert(not tree.current())
    tree[1].state.status="AVAILABLE";expire();assert(not tree.current())
end)
check("Malformed restricted or ambiguous graph metadata fails closed", function()
    local secret={}
    issecretvalue=function(v)return v==secret end
    for _,q in ipairs({{requires={{ids={secret}}}},{requires={{ids={0}}}},{requires={{ids={2},mode="invented"}}},
        {storyline={1},storylineGroups={{1}}}})do
        local quests={[1]=q,[2]={}}
        local engine=fixture(quests)
        assert(addon.QuestTree.Build(quests,engine,1)==nil)
    end
end)
check("A false requirement mode is malformed rather than an absent completed-mode default", function()
    local quests={[1]={requires={{ids={2},mode=false}}},[2]={}}
    local engine=fixture(quests)
    local tree,reason=addon.QuestTree.Build(quests,engine,1)
    assert(tree==nil and reason=="source")
end)
check("Engine graph character context and branch-choice ownership expire before publication and after Build", function()
    for _,field in ipairs({"quests","context","choices"})do
        local quests={[1]={requires={{ids={2}}}},[2]={}}
        local engine=fixture(quests)
        engine.quests,engine.context,engine.choices=quests,{},{}
        local tree=assert(addon.QuestTree.Build(quests,engine,1))
        local old=engine[field];engine[field]={};assert(not tree.current(),field)
        engine[field]=old
        local state=engine.State
        engine.State=function(self,id)self[field]={};return state(self,id)end
        assert(addon.QuestTree.Build(quests,engine,1)==nil,field)
    end
    local quests={[1]={}}
    local engine=fixture(quests);engine.quests={}
    assert(addon.QuestTree.Build(quests,engine,1)==nil)
end)
check("Actual same-name Deadmines quests retain the target at its exact recorded story position",function()
    local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    assert(actual.quests[92753].name==actual.quests[92819].name)
    local engine=fixture(actual.quests,{[92742]="COMPLETED"})
    local tree=assert(addon.QuestTree.Build(actual.quests,engine,92753))
    assert(tree.targetID==92753 and #tree.presentation==11 and tree[1].id==92753 and tree[1].root)
    for index,node in ipairs(tree.presentation)do
        assert(node.id==actual.quests[92753].storyline[index] and node.storyIndex==index)
        assert(node.onTargetPath==(index<=10))
        assert(node.presentationRelation=="story")
    end
    assert(tree.presentation[10].root and not tree.presentation[11].root)
    assert(tree.presentation[1].state.completedHistory and tree.presentation[1].relation=="story")
    assert(tree.presentation[10].relation=="required","presentation does not rewrite dependency semantics")
    tree=assert(addon.QuestTree.Build(actual.quests,engine,92819))
    assert(tree.presentation[11].root and tree.presentation[11].id==92819)
    assert(tree.presentation[10].id==92753 and not tree.presentation[10].root and tree.presentation[10].onTargetPath)
end)
check("Recorded route highlighting distinguishes repeated names without inventing required ancestors",function()
    local quests={[1]={name="Same name",storyline={3,1,2}},[2]={name="Same name"},[3]={name="First"}}
    local engine=fixture(quests)
    local tree=assert(addon.QuestTree.Build(quests,engine,1))
    assert(ids(tree.presentation)=="3,1,2")
    assert(tree.presentation[1].onTargetPath and tree.presentation[2].onTargetPath and not tree.presentation[3].onTargetPath)
    assert(tree.presentation[1].relation=="story" and #tree.presentation[1].links==0)
    assert(tree.presentation[2].id==1 and tree.presentation[3].id==2)
end)
check("Required paths stay deduplicated before optional story and OR alternatives never become a chosen route",function()
    local quests={[1]={requires={{ids={2,3}}},storyline={5,2,1,4}},[2]={requires={{ids={6}}}},
        [3]={requires={{ids={6}}}},[4]={},[5]={},[6]={}}
    local engine=fixture(quests)
    local tree=assert(addon.QuestTree.Build(quests,engine,1))
    assert(ids(tree.presentation)=="6,2,3,5,1,4")
    local seen={};for _,node in ipairs(tree.presentation)do assert(not seen[node.id]);seen[node.id]=true end
    assert(tree.presentation[2].alternatives==2 and tree.presentation[3].alternatives==2)
    assert(tree.presentation[1].onTargetPath and #tree.presentation[1].links==2)
    assert(tree.presentation[2].storyIndex==2 and tree.presentation[2].relation=="required")
    assert(tree.presentation[4].relation=="story" and tree.presentation[4].onTargetPath)
    assert(tree.presentation[5].root and not tree.presentation[6].onTargetPath)
end)
check("Parallel target-group peers and stories without the target do not claim a route into it",function()
    local quests={[1]={storylineGroups={{2,3},{1,4},{5}}},[2]={},[3]={},[4]={},[5]={}}
    local engine=fixture(quests)
    local tree=assert(addon.QuestTree.Build(quests,engine,1))
    assert(ids(tree.presentation)=="2,3,1,4,5")
    assert(tree.presentation[1].onTargetPath and tree.presentation[2].onTargetPath)
    assert(tree.presentation[3].root and tree.presentation[3].storyGroup==2)
    assert(not tree.presentation[4].onTargetPath and not tree.presentation[5].onTargetPath)
    quests[1]={requires={{ids={2}}},storyline={3,4}}
    tree=assert(addon.QuestTree.Build(quests,engine,1))
    assert(ids(tree.presentation)=="2,1,3,4" and tree.presentation[2].root)
    assert(not tree.presentation[3].onTargetPath and not tree.presentation[4].onTargetPath)
end)
check("Truncated unknown and cyclic routes retain one exact target and current source ownership",function()
    local quests={};for n=1,100 do quests[n]={}end
    quests[90].storyline={};for n=1,100 do quests[90].storyline[n]=n end
    local engine=fixture(quests)
    local tree=assert(addon.QuestTree.Build(quests,engine,90))
    assert(tree.truncated and #tree.presentation==80 and tree.presentation[80].id==90 and tree.presentation[80].root)
    assert(tree.presentation[80].storyIndex==90 and tree.current())
    quests[90].storyline[90]=91;assert(not tree.current())
    local missingEngine=fixture({});tree=assert(addon.QuestTree.Build({},missingEngine,999))
    assert(#tree.presentation==1 and tree.presentation[1].missing and tree.presentation[1].root and tree.presentation[1].onTargetPath)
    quests={[1]={requires={{ids={2}}}},[2]={requires={{ids={1}}}}};engine=fixture(quests)
    tree=assert(addon.QuestTree.Build(quests,engine,1))
    assert(tree.cycle and ids(tree.presentation)=="2,1" and tree.presentation[2].root)
end)
check("Every generated catalogue quest builds from the real planner without rewriting availability", function()
    local actual = {}
    assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    assert(loadfile("Core/Planner.lua"))("DungeonPro",addon)
    local engine = addon.Planner.New(actual.quests,{level=60,faction="Alliance",class="MAGE",
        completed=function()return false end,active=function()return false end},{})
    local count=0
    for questID in pairs(actual.quests)do
        local before=engine:State(questID)
        local tree=assert(addon.QuestTree.Build(actual.quests,engine,questID))
        local found=false
        for _,node in ipairs(tree)do
            if node.root then assert(node.id==questID and node.state==before);found=true end
        end
        assert(found and #tree<=80 and tree.current() and engine:State(questID)==before)
        local seen,targets={},0
        assert(#tree.presentation==#tree and tree.targetID==questID)
        for _,node in ipairs(tree.presentation)do
            assert(not seen[node.id] and type(node.onTargetPath)=="boolean");seen[node.id]=true
            if node.root then assert(node.id==questID and node.onTargetPath);targets=targets+1 end
        end
        assert(targets==1)
        count=count+1
    end
    assert(count==571)
end)
check("Private hierarchy construction stays linear while retained source proofs remain complete",function()
    local function measured(size)
        local quests={}
        for id=1,size do quests[id]={requires=id<size and{{ids={id+1}}}or nil}end
        local engine,calls=fixture(quests);local checks=0
        issecretvalue=function()checks=checks+1;return false end
        local tree=assert(addon.QuestTree.Build(quests,engine,1))
        assert(#tree==size and #calls==size)
        local construction=checks
        assert(tree.current());local warm=checks-construction
        quests[size].requires={{ids={1}}}
        assert(not tree.current(),"the oldest captured leaf remains protected after publication")
        return construction,warm
    end
    local small,smallGuard=measured(20)
    local large,largeGuard=measured(40)
    assert(large<=small*2.5,"private chain proofs repeat accumulated fields: "..small.." -> "..large)
    assert(largeGuard>smallGuard,"warm proofs retain every source field")
end)
check("Later engine callbacks cannot publish edits to an earlier private source or state",function()
    for _,mode in ipairs({"source","state"})do
        local quests={[1]={requires={{ids={2}}}},[2]={requires={{ids={3}}}},[3]={}}
        local engine=fixture(quests);local original=engine.State;local first,changed
        engine.State=function(self,id)
            local value=original(self,id)
            if id==3 then first=value end
            if id==1 then
                assert(first,"the earlier leaf state must already have been captured")
                changed=true
                if mode=="source"then quests[3].requires={{ids={4}}}
                else first.status="COMPLETED"end
            end
            return value
        end
        assert(addon.QuestTree.Build(quests,engine,1)==nil and changed,mode)
    end
end)
print("Quest hierarchy modeled checks passed: "..total)
