local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/QuestRowInfo.lua"))("DungeonPro", addon)
local function test(name, fn)
    issecretvalue = nil
    local ok, err = pcall(fn); assert(ok, name .. ": " .. tostring(err))
    total = total + 1; print("PASS " .. name)
end
local function get(q, others)
    local quests = others or {[2]={},[3]={}}
    quests[1] = q
    return addon.QuestRowInfo.Get(quests,1)
end
test("Only one exact known faction produces a marker and duplicates deduplicate", function()
    for _, faction in ipairs({"Alliance","Horde"}) do
        local dto, current = get({factions={faction,faction}})
        assert(dto.faction==faction and not dto.chain and current())
    end
    for _, values in ipairs({{}, {"Alliance","Horde"}, {"Horde","unknown"}, {false}, {"alliance"}}) do
        local dto = get({factions=values}); assert(dto and dto.faction==nil)
    end
    assert(get({factions="Alliance"}).faction==nil)
end)
test("Class restrictions retain every known token once in source order without guessing",function()
    local dto,current=get({classes={"PALADIN","WARRIOR","PALADIN"}})
    assert(current()and #dto.classes==2 and dto.classes[1]=="PALADIN"and dto.classes[2]=="WARRIOR")
    for _,values in ipairs({{}, {"CUSTOM"},{"PALADIN","CUSTOM"},{false},{"paladin"},{[1]="PALADIN",extra="MAGE"}})do
        local value=get({classes=values});assert(value and #value.classes==0)
    end
    assert(#get({classes="PALADIN"}).classes==0)
    local secret={};issecretvalue=function(value)return value==secret end
    assert(not get({classes={secret}}))
end)

test("Class membership replacement append and invalid dictionary keys expire the existing source proof",function()
    for _,mutate in ipairs({function(q)q.classes[1]="WARRIOR"end,function(q)q.classes[2]="MAGE"end,
        function(q)q.classes={}end,function(q)q.classes.extra="MAGE"end})do
        local q={classes={"PALADIN"}};local dto,current=get(q);assert(current()and dto.classes[1]=="PALADIN")
        mutate(q);assert(not current())
    end
end)

test("Requirements ordered stories and grouped stories mark another distinct known ID", function()
    for _, q in ipairs({{requires={{ids={2},mode="active"}}}, {storyline={1,2,3}}, {storylineGroups={{1,2},{3}}}}) do
        local dto,current=get(q);assert(dto.chain and current())
    end
end)
test("Single self cycles and empty relations do not claim a chain", function()
    for _,q in ipairs({{}, {requires={{ids={1}}}}, {storyline={1,1}}, {storylineGroups={{1},{1}}}}) do
        local dto=get(q);assert(dto and not dto.chain)
    end
end)
test("Known relation IDs retain an unknown tree member without inventing availability", function()
    for _,q in ipairs({{storyline={999}}, {requires={{ids={2,999}}}}})do
        local quests={[1]=q,[2]={}}
        local dto,current=addon.QuestRowInfo.Get(quests,1);assert(dto.chain and current())
        quests[999]={};assert(not current())
    end
end)
test("Malformed modes groups IDs mixed story schemas and excessive arrays are conservative", function()
    local over={};for i=1,101 do over[i]=2 end
    for _,q in ipairs({{requires={{ids={2},mode="done"}}},{requires={{ids={}}}}, {requires={false}},
        {storyline={2,0}}, {storyline={2,1.5}}, {storyline={2,math.huge}}, {storyline={2,9007199254740992}},
        {storyline={2},storylineGroups={{3}}}, {storylineGroups={{ids={2}}}}, {storyline=over},
        {storylineGroups={false}}})do
        local dto=get(q);assert(dto and not dto.chain)
    end
end)
test("Root arrays member identities modes and appended elements invalidate freshness", function()
    for _,change in ipairs({function(q,qs)qs[1]={}end, function(q)q.factions[1]="Horde"end,
        function(q)q.storyline[2]=3 end,function(q)q.storyline[3]=3 end,
        function(q)q.requires[1].mode="active"end,function(q)q.requires[1].ids[1]=3 end,
        function(q)q.storylineGroups[1][1]=3 end,function(_,qs)qs[2]={}end,
        function(q)q.requires={}end})do
        local qs={[2]={},[3]={}};local q={factions={"Alliance"},requires={{ids={2}}},storyline={1,2},storylineGroups={{2}}}
        local dto,current=get(q,qs);assert(dto and current());change(q,qs);assert(not current())
    end
end)
test("Late Clean Read checker and provider replacement invalidate retained predicates", function()
    for _,field in ipairs({"Clean","Read","QuestRowInfo"})do
        local old=addon[field];local dto,current=get({storyline={2}});assert(dto.chain)
        addon[field]={};assert(not current());addon[field]=old
    end
    local getter=addon.QuestRowInfo.Get
    local _,fresh=get({});addon.QuestRowInfo.Get=function()end;assert(not fresh());addon.QuestRowInfo.Get=getter
    local dto,current=get({});assert(dto);issecretvalue=function()return false end;assert(not current())
end)
test("Restricted source values and invalid inputs never authorize display metadata", function()
    local secret={};issecretvalue=function(value)return value==secret end
    assert(not get({factions={secret}}))
    assert(not get({storyline={secret}}))
    assert(not addon.QuestRowInfo.Get({},0) and not addon.QuestRowInfo.Get({},math.huge))
end)
test("Retained class proofs directly reject failed restricted and nonboolean checker results",function()
    for _,mode in ipairs({"true","nil","string","throw"})do
        local changed=false
        issecretvalue=function(value)
            if changed and value=="PALADIN"then
                if mode=="throw"then error("unreadable")end
                if mode=="true"then return true elseif mode=="nil"then return nil else return "false"end
            end
            return false
        end
        local dto,current=get({classes={"PALADIN"}});assert(dto and current());changed=true
        local ok,result=pcall(current);assert(ok and not result,mode)
    end
end)

test("Direct checker reentry cannot approve old class membership or provider ownership",function()
    for _,mode in ipairs({"class","provider","checker"})do
        local q={classes={"PALADIN"}};local changed=false
        local getter=addon.QuestRowInfo.Get
        issecretvalue=function(value)
            if changed and value=="PALADIN"then
                changed=false
                if mode=="class"then q.classes[1]="MAGE"
                elseif mode=="provider"then addon.QuestRowInfo.Get=function()end
                else issecretvalue=function()return false end end
            end
            return false
        end
        local dto,current=get(q);assert(dto and current());changed=true
        assert(not current(),mode);addon.QuestRowInfo.Get=getter
    end
end)

test("Edge traversal is bounded without state tree or native provider calls", function()
    local qs={[1]={requires={}}};for i=2,101 do qs[i]={}end
    for i=1,4 do local ids={};for j=2,101 do ids[#ids+1]=j end;qs[1].requires[i]={ids=ids}end
    local dto,current=addon.QuestRowInfo.Get(qs,1);assert(dto and not dto.chain and current())
end)
test("Every actual catalogue claim has a second displayed tree ID and all singleton trees stay unmarked", function()
    local actual={};assert(loadfile("Database/Catalog.lua"))("DungeonPro",actual)
    assert(loadfile("Core/QuestTree.lua"))("DungeonPro",addon)
    local engine={State=function()return{status="AVAILABLE"}end}
    local count,claims=0,0
    for id in pairs(actual.quests)do
        local dto,current=addon.QuestRowInfo.Get(actual.quests,id);assert(dto and current())
        local tree=assert(addon.QuestTree.Build(actual.quests,engine,id))
        if dto.chain then assert(tree and #tree>1,"false chain claim for "..id);claims=claims+1 end
        if tree then assert(dto.chain==(#tree>1),"tree disagreement for "..id)end
        count=count+1
    end
    assert(count==571 and claims>0);print("Catalogue roots "..count..", chain claims "..claims)
end)
test("Third return checks captured sources without Clean Read or checker callbacks", function()
    local clean, read, armed, calls = addon.Clean, addon.Read, false, 0
    addon.Clean = function(...) if armed then calls = calls + 1; error("raw proof called Clean") end; return clean(...) end
    addon.Read = function(...) if armed then calls = calls + 1; error("raw proof called Read") end; return read(...) end
    issecretvalue = function() if armed then calls = calls + 1; error("raw proof called checker") end; return false end
    local dto, current, raw = get({ classes = { "PALADIN" }, requires = { { ids = { 2 } } } })
    assert(dto and current() and type(raw) == "function", "callback-free companion is required")
    armed = true
    local ok, valid = pcall(raw)
    addon.Clean, addon.Read, issecretvalue = clean, read, nil
    assert(ok and valid and calls == 0)
end)

test("Raw companion rejects late field shape source and capability changes", function()
    for _, mutate in ipairs({
        function(q) q.classes[1] = "MAGE" end,
        function(q) q.classes.extra = "MAGE" end,
        function(q) q.requires[1].mode = "active" end,
        function(q) q.requires[1].ids[2] = 3 end,
        function(_, quests) quests[2] = {} end,
        function(_, quests) quests[1] = {} end,
        function(q) q.storyline = { 3 } end,
    }) do
        local quests = { [2] = {} }
        local q = { classes = { "PALADIN" }, requires = { { ids = { 2 } } } }
        local dto, current, raw = get(q, quests)
        assert(dto and current() and type(raw) == "function" and raw())
        mutate(q, quests); assert(not raw() and not current())
    end
    for _, field in ipairs({ "Clean", "Read", "QuestRowInfo" }) do
        local _, _, raw = get({}); local previous = addon[field]
        addon[field] = {}; assert(not raw()); addon[field] = previous
    end
end)

test("Final callback mutations retire a successful dynamic preflight", function()
    local q = { classes = { "PALADIN" } }
    local _, current, raw = get(q)
    assert(type(raw) == "function" and current() and raw())
    local function finalCallback() q.classes[1] = "MAGE"; return true end
    assert(finalCallback() and not raw())
end)
print("Quest row info: "..total.." checks passed")
