local addon,total,secret={},0,{}
assert(loadfile("Core/Namespace.lua"))("DungeonPro",addon)
assert(loadfile("Core/Planner.lua"))("DungeonPro",addon)
assert(loadfile("Core/DungeonStatus.lua"))("DungeonPro",addon)
local function check(name,fn)
    issecretvalue=function(v)return v==secret end
    local ok,err=pcall(fn);assert(ok,name..": "..tostring(err));total=total+1;print("PASS "..name)
end
local function fixture(rows,definitions)
    local quests,states,list={},{},{}
    for i,row in ipairs(rows)do
        list[i]=i;quests[i]=definitions and definitions[i]or{minLevel=1,requirementsKnown=true}
        states[i]={id=i,status=row[1],reason=row[2],completedHistory=row[1]=="COMPLETED"}
    end
    local alive,calls=true,0
    local engine={quests=quests,context={level=20,faction="Alliance",class="MAGE"},choices={}}
    function engine:Current()return alive end
    function engine:State(id)calls=calls+1;return states[id]end
    function engine:Dungeon()error("aggregate must not build preparation actions")end
    function engine:Next()error("aggregate must not walk action routes")end
    return {dungeon={key="test",quests=list,coverage="partial"},engine=engine,states=states,
        calls=function()return calls end,expire=function()alive=false end}
end
local function status(f)
    local value,current=addon.DungeonStatus.Get(f.dungeon,f.engine);assert(value and current())
    return value,current
end
check("Ready available active unknown and locked precedence describes at least one known listed quest",function()
    for _,case in ipairs({{{"READY"},{"AVAILABLE"},{"ACTIVE"},{"UNKNOWN"},{"LOCKED","level"}},
        {{"AVAILABLE"},{"ACTIVE"},{"UNKNOWN"}},{{"ACTIVE"},{"UNKNOWN"}},{{"UNKNOWN"},{"LOCKED","level"}},{{"LOCKED","requirements"}}})do
        local f=fixture(case);local value=status(f);assert(value.status==case[1][1])
        assert(value.partial and value.listed==#case and value.eligible==#case)
    end
end)
check("Red level blocking requires every unfinished listed quest to have that exact known reason",function()
    local f=fixture({{"COMPLETED"},{"LOCKED","level"},{"LOCKED","level"}})
    local value=status(f);assert(value.status=="LOCKED"and value.reason=="level"and value.allLevelBlocked)
    f.states[3].reason="requirements";value=status(f);assert(value.status=="LOCKED"and value.reason==nil and not value.allLevelBlocked)
    f.states[3].status="UNKNOWN";value=status(f);assert(value.status=="UNKNOWN"and value.reason==nil)
end)
check("Only nonempty positive completed eligible lists receive a listed-only completion check",function()
    local f=fixture({{"COMPLETED"},{"COMPLETED"}});local value=status(f)
    assert(value.status=="COMPLETED"and value.completed==2 and value.unfinished==0 and value.partial)
    f.states[2].completedHistory=nil;value=status(f);assert(value.status=="UNKNOWN"and value.completed==1)
    f=fixture({});value=status(f);assert(value.status=="UNAVAILABLE"and value.eligible==0 and value.completed==0)
end)
check("Foreign-character inspection does not affect aggregates even with positive past completion",function()
    local f=fixture({{"COMPLETED"},{"AVAILABLE"},{"UNAVAILABLE","class"}},
        {{minLevel=1,factions={"Horde"}},{minLevel=1},{minLevel=1,classes={"WARRIOR"}}})
    local value=status(f);assert(value.status=="AVAILABLE"and value.eligible==1 and value.excluded==2 and value.completed==0)
    f.dungeon.includeUnavailable=true;value=status(f);assert(value.status=="AVAILABLE"and value.eligible==1)
    f.engine.quests[2].factions={"Horde"};value=status(f)
    assert(value.status=="UNAVAILABLE"and value.eligible==0 and value.excluded==3)
end)
check("Current active and ready log evidence retains precedence over stale catalogue restrictions",function()
    local f=fixture({{"ACTIVE"},{"READY"}},{{factions={"Horde"}},{classes={"WARRIOR"}}})
    local value=status(f);assert(value.status=="READY"and value.eligible==2 and value.excluded==0)
end)
check("Unknown character eligibility cannot certify a completed list",function()
    local f=fixture({{"COMPLETED"}},{{factions={"Alliance"}}});f.engine.context.faction=nil
    local value=status(f);assert(value.status=="UNKNOWN"and value.completed==0 and value.eligible==1)
end)
check("Duplicate IDs count once and no action builder or native hydration is used",function()
    local f=fixture({{"AVAILABLE"}});f.dungeon.quests={1,1,1}
    local native,eligibilityCalls=addon.Planner.Eligible,0
    addon.Planner.Eligible=function(...)eligibilityCalls=eligibilityCalls+1;return native(...)end
    local value,current=status(f);assert(value.listed==1 and value.eligible==1 and f.calls()==1)
    for i=1,100 do assert(current())end
    assert(f.calls()==1 and eligibilityCalls==1,"warm source proof must never call State or Eligible again")
    addon.Planner.Eligible=native
end)
check("State callback reentry cannot publish an expired character or source",function()
    for _,mode in ipairs({"context","quests","list","provider","expire","definition"})do
        local f=fixture({{"AVAILABLE"}});local getter=f.engine.State
        f.engine.State=function(self,id)
            local value=getter(self,id)
            if mode=="context"then self.context={}elseif mode=="quests"then self.quests={}
            elseif mode=="list"then f.dungeon.quests={1}elseif mode=="provider"then self.State=function()return value end
            elseif mode=="definition"then self.quests[1]={}else f.expire()end
            return value
        end
        local value=addon.DungeonStatus.Get(f.dungeon,f.engine);assert(value==nil,mode)
    end
end)
check("Published source proofs expire on context list eligibility state and provider drift",function()
    for _,mode in ipairs({"level","class","faction","coverage","list","definition","restriction","state","getter","cache"})do
        local f=fixture({{"AVAILABLE"}},{{minLevel=1,classes={"MAGE"}}});local _,current=status(f)
        if mode=="level"then f.engine.context.level=1 elseif mode=="class"then f.engine.context.class="WARRIOR"
        elseif mode=="faction"then f.engine.context.faction="Horde"elseif mode=="coverage"then f.dungeon.coverage="reviewed"
        elseif mode=="list"then f.dungeon.quests[1]=2 elseif mode=="definition"then f.engine.quests[1]={}
        elseif mode=="restriction"then f.engine.quests[1].classes[1]="WARRIOR"
        elseif mode=="state"then f.states[1].status="READY"elseif mode=="cache"then f.engine.states={}
        else f.engine.State=function()return f.states[1]end end
        assert(not current(),mode)
    end
end)
check("Invalid restricted sparse or oversized quest snapshots fail closed",function()
    for _,bad in ipairs({{0},{secret},{1,2,3},{[1]=1,[3]=1},{["wrong"]=1}})do
        local f=fixture({{"AVAILABLE"}});f.dungeon.quests=bad
        assert(addon.DungeonStatus.Get(f.dungeon,f.engine)==nil)
    end
    local f=fixture({{"AVAILABLE"}});f.states[1].status=secret
    assert(addon.DungeonStatus.Get(f.dungeon,f.engine)==nil)
    f=fixture({{"AVAILABLE"}});f.dungeon.quests={};for i=1,201 do f.dungeon.quests[i]=1 end
    assert(addon.DungeonStatus.Get(f.dungeon,f.engine)==nil)
end)
check("In-place requirement group membership and mode changes expire the aggregate",function()
    for _,mode in ipairs({"member","mode","append","replace"})do
        local f=fixture({{"LOCKED","requirements"}},{{minLevel=1,requires={{ids={2},mode="completed"}}}})
        local _,current=status(f);local group=f.engine.quests[1].requires[1]
        if mode=="member"then group.ids[1]=3 elseif mode=="mode"then group.mode="active"
        elseif mode=="append"then group.ids[2]=3 else f.engine.quests[1].requires[1]={ids={2}}end
        assert(not current(),mode)
    end
end)
check("Reachable dependency definitions are captured without querying their states on warm proof",function()
    for _,mode in ipairs({"level","restriction","deepMember","replacement","missing"})do
        local f=fixture({{"LOCKED","requirements"}},{{minLevel=1,requires={{ids={2}}}}})
        f.engine.quests[2]={minLevel=1,requires={{ids={3}}}};f.engine.quests[3]={minLevel=1,classes={"MAGE"}}
        local _,current=status(f);assert(f.calls()==1)
        if mode=="level"then f.engine.quests[3].minLevel=25
        elseif mode=="restriction"then f.engine.quests[3].classes[1]="WARRIOR"
        elseif mode=="deepMember"then f.engine.quests[2].requires[1].ids[1]=4
        elseif mode=="replacement"then f.engine.quests[2]={}
        else f.engine.quests[3]=nil end
        assert(not current()and f.calls()==1,mode)
    end
    local f=fixture({{"AVAILABLE"}});for i=1,201 do f.engine.quests[i]={requires=i<201 and{{ids={i+1}}}or nil}end
    assert(addon.DungeonStatus.Get(f.dungeon,f.engine)==nil and f.calls()==0,"dependency capture has a hard source budget")
end)
check("Absent captured fields remain guarded after later populated fields and warm checks",function()
    for _,field in ipairs({"requires","factions","classes","reason","completedHistory"})do
        local f=fixture({{"AVAILABLE"}},{{minLevel=1,requirementsKnown=true}})
        if field=="completedHistory"then f.states[1].completedHistory=nil end
        local _,current=status(f)
        local calls=f.calls()
        for _=1,20 do assert(current())end
        if field=="reason"then f.states[1].reason="level"
        elseif field=="completedHistory"then f.states[1].completedHistory=true
        elseif field=="requires"then f.engine.quests[1].requires={{ids={2}}}
        else f.engine.quests[1][field]={field=="classes"and"WARRIOR"or"Horde"}end
        assert(not current()and f.calls()==calls,field.." changed without querying quest state")
    end
end)
check("Every actual dungeon aggregates planner states without changing them or invoking Next",function()
    local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    local engine=addon.Planner.New(actual.quests,{level=60,faction="Alliance",class="MAGE",
        completed=function()return false end,active=function()return false end},{})
    engine.Next=function()error("No action walk")end;engine.Dungeon=function()error("No full preparation")end
    local count=0
    for _,d in ipairs(actual.dungeons)do
        local before={};for _,id in ipairs(d.quests)do before[id]=engine:State(id)end
        local result,current=addon.DungeonStatus.Get(d,engine)
        assert(result and current()and result.listed==#d.quests)
        for id,state in pairs(before)do assert(engine:State(id)==state)end
        count=count+1
    end
    assert(count==29)
end)
check("Pure aggregate construction scales linearly while published guards retain complete source proofs",function()
    local function measured(size)
        local rows={};for i=1,size do rows[i]={"AVAILABLE"}end
        local f=fixture(rows);local checks=0
        issecretvalue=function()checks=checks+1;return false end
        local value,current=addon.DungeonStatus.Get(f.dungeon,f.engine)
        assert(value and value.listed==size and f.calls()==size)
        local construction=checks
        assert(current());local warm=checks-construction
        f.engine.quests[1].minLevel=99
        assert(not current(),"first definition remains part of the published snapshot")
        return construction,warm
    end
    local small,smallGuard=measured(20)
    local large,largeGuard=measured(40)
    assert(large<=small*2.5,"doubling listed quests must not quadruple construction proof work: "..small.." -> "..large)
    assert(largeGuard>smallGuard,"published guards still validate the complete larger snapshot")
end)
check("Later state callbacks cannot publish mutations to an earlier completed aggregate row",function()
    for _,mode in ipairs({"definition","state","eligibility"})do
        local f=fixture({{"AVAILABLE"},{"AVAILABLE"}});local state=f.engine.State
        f.engine.State=function(self,id)
            local value=state(self,id)
            if id==2 then
                if mode=="definition"then self.quests[1].minLevel=99
                elseif mode=="state"then f.states[1].status="COMPLETED"
                else self.quests[1].classes={"WARRIOR"}end
            end
            return value
        end
        assert(addon.DungeonStatus.Get(f.dungeon,f.engine)==nil,mode)
    end
end)
check("Actual catalogue aggregate proofs avoid duplicate sanitization of unchanged engine bindings",function()
    local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    local checks=0;issecretvalue=function()checks=checks+1;return false end
    local engine=addon.Planner.New(actual.quests,{level=60,faction="Alliance",class="MAGE",
        completed=function()return false end,active=function()return false end,current=function()return true end},{})
    local count=0
    for _,d in ipairs(actual.dungeons)do
        local result,current=addon.DungeonStatus.Get(d,engine)
        assert(result and current()and result.listed==#d.quests);count=count+1
    end
    assert(count==29 and checks<68000,"duplicate aggregate binding checks: "..checks)
end)
check("Root counts share Planner membership without changing readiness or duplicate handling",function()
    local f=fixture({{"UNAVAILABLE"},{"LOCKED","level"},{"UNKNOWN"},{"ACTIVE"},{"READY"},{"COMPLETED"}},
        {{factions={"Horde"}},{minLevel=99},{classes={"MAGE"}},{factions={"Horde"}},{classes={"PALADIN"}},{classes={"PALADIN"}}})
    f.dungeon.quests[7]=2
    local dto,fresh=status(f)
    assert(dto.listedRoots==7 and dto.characterRoots==5 and dto.listed==6 and f.calls()==6)
    local predicate=addon.Planner.RelevantToCharacter
    addon.Planner.RelevantToCharacter=function(...)return predicate(...)end
    assert(not fresh());addon.Planner.RelevantToCharacter=predicate
    local f2=fixture({{"UNAVAILABLE"}})
    assert(status(f2).characterRoots==1,"root membership is eligibility, not readiness exclusion")
end)
check("Root predicate callback source mutation cannot publish counts",function()
    local f=fixture({{"AVAILABLE"}});local original=addon.Planner.RelevantToCharacter
    addon.Planner.RelevantToCharacter=function(...)f.dungeon.quests[1]=2;return original(...)end
    assert(addon.DungeonStatus.Get(f.dungeon,f.engine)==nil)
    addon.Planner.RelevantToCharacter=original
end)
check("Retained root-array proofs preserve the initially validated key shape",function()
    local function captured(roots,size)
        local rows={};for id=1,size or 2 do rows[id]={"COMPLETED"}end
        local f=fixture(rows);f.dungeon.quests=roots
        local dto,current=status(f)
        return f,dto,current
    end
    for _,case in ipairs({
        {"dictionary",function(ids)ids.extra=2 end},
        {"false dictionary value",function(ids)ids.extra=false end},
        {"zero",function(ids)ids[0]=2 end},
        {"negative",function(ids)ids[-1]=2 end},
        {"fractional",function(ids)ids[1.5]=2 end},
        {"sparse",function(ids)ids[3]=2 end},
        {"oversized",function(ids)ids[201]=2 end},
        {"append",function(ids)ids[2]=2 end},
        {"replace",function(ids)ids[1]=2 end},
        {"remove",function(ids)ids[1]=nil end},
    })do
        local f,_,current=captured({1});case[2](f.dungeon.quests)
        assert(not current(),case[1].." source mutation retained its old root proof")
    end
    local f,dto,current=captured({1,1,2})
    assert(dto.listedRoots==3 and dto.listed==2 and current(),"valid duplicate multiplicity remains supported")
    f.dungeon.quests[1]=1;assert(current(),"unchanged dense roots remain current")
    for _,size in ipairs({0,200})do
        local ids={};for id=1,size do ids[id]=id end
        f,dto,current=captured(ids,math.max(2,size));assert(dto.listedRoots==size)
        ids.extra=1
        assert(addon.DungeonStatus.Get(f.dungeon,f.engine)==nil and not current(),"boundary-size key mutation")
    end
    local armed,roots=false,{1}
    issecretvalue=function(value)
        if armed and value=="root-shape-tail"then armed=false;roots.extra=2 end
        return false
    end
    f=fixture({{"COMPLETED","root-shape-tail"}});f.dungeon.quests=roots
    dto,current=status(f);armed=true
    assert(not current()and not armed,"late sanitizer cannot append an unowned key")
end)
print("Dungeon status modeled checks passed: "..total)
