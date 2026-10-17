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
check("Story order is optional context and never turns story-only prerequisites into mandatory nodes", function()
    local quests = {[1]={requires={{ids={2}}},storyline={3,2,1,4}},[2]={},[3]={requires={{ids={5}}}},[4]={},[5]={}}
    local engine = fixture(quests)
    local tree = assert(addon.QuestTree.Build(quests,engine,1))
    assert(ids(tree)=="2,1,3,4" and tree[3].relation=="story" and tree[4].relation=="story")
    assert(tree[1].relation=="required" and tree[3].storyIndex==1 and tree[4].storyIndex==4)
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
        count=count+1
    end
    assert(count==571)
end)
print("Quest hierarchy modeled checks passed: "..total)
