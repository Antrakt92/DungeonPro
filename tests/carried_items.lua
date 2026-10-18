local addon, total, secret = {}, 0, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
assert(loadfile("Core/Planner.lua"))("DungeonPro", addon)
local count, calls
local function reset()
    count, calls = 3, 0
    addon.quests = {
        [65] = { id = 65, minLevel = 1, requirementsKnown = false, start = { itemID = 5791 } },
        [66] = { id = 66, minLevel = 1, requirementsKnown = false,
            completionQuests = { { id = 67, itemID = 7083 } } },
        [67] = { id = 67, minLevel = 1, requirementsKnown = false },
    }
    issecretvalue = function(value) return value == secret end
    C_Item = { GetItemCount = function(id, bank, uses, reagent, account, ...)
        assert((id == 5791 or id == 7083 or id == 20606) and bank == false and uses == false and reagent == false and account == false)
        assert(select("#", ...) == 0); calls = calls + 1; return count
    end, RequestLoadItemDataByID = function() error("item requests forbidden") end }
    C_QuestLog = { SetSelectedQuest = function() error("selection forbidden") end,
        RequestLoadQuestByID = function() error("quest requests forbidden") end }
    C_Timer = { After = function() error("timers forbidden") end }
    GetItemCount = function() error("unverified global fallback forbidden") end
end
local function check(name, callback)
    reset(); local ok, err = pcall(callback)
    assert(ok, name .. ": " .. tostring(err)); total = total + 1; print("PASS " .. name)
end
check("Starter and material item counts use five exact explicit arguments and preserve zero", function()
    assert(addon.CarriedItemCount(5791) == 3 and addon.CarriedItemCount(7083) == 3 and calls == 2)
    count = 0; assert(addon.CarriedItemCount(5791) == 0 and calls == 3)
    assert(addon.db == nil and addon.char == nil)
end)
check("Unknown and malformed IDs never reach native count or global fallback", function()
    for _, id in ipairs({ 1, 65, 0, -1, 5791.5, false, "5791", math.huge, 0 / 0, secret }) do
        assert(addon.CarriedItemCount(id) == nil and calls == 0)
    end
    assert(addon.CarriedItemCount(nil) == nil)
    addon.quests[65].start = { npcID = 5791 }; assert(addon.CarriedItemCount(5791) == nil)
end)
check("Missing malformed and throwing native capabilities remain unknown", function()
    for _, value in ipairs({ false, 7, secret, "missing" }) do
        C_Item = value; assert(addon.CarriedItemCount(5791) == nil)
    end
    C_Item = nil; assert(addon.CarriedItemCount(5791) == nil)
    C_Item = {}; assert(addon.CarriedItemCount(5791) == nil)
    C_Item.GetItemCount = function() error("unavailable") end
    assert(addon.CarriedItemCount(5791) == nil)
end)
check("Only finite nonnegative integer native counts may become display data", function()
    for _, value in ipairs({ false, "0", {}, secret, -1, 1.5, math.huge, -math.huge, 0 / 0 }) do
        count = value; assert(addon.CarriedItemCount(5791) == nil)
    end
    count = nil; assert(addon.CarriedItemCount(5791) == nil)
    count = 1000000; assert(addon.CarriedItemCount(5791) == 1000000)
    issecretvalue = function() error("restricted checker") end
    assert(addon.CarriedItemCount(5791) == nil)
end)
check("Library getter and restriction-checker replacement during reads rejects older results", function()
    C_Item.GetItemCount = function() C_Item = { GetItemCount = function() return 99 end }; return 3 end
    assert(addon.CarriedItemCount(5791) == nil)
    reset(); C_Item.GetItemCount = function() C_Item.GetItemCount = function() return 99 end; return 3 end
    assert(addon.CarriedItemCount(5791) == nil)
    reset(); C_Item.GetItemCount = function() issecretvalue = function() return false end; return 3 end
    assert(addon.CarriedItemCount(5791) == nil)
end)
check("Catalogue replacement or removed item links cannot publish stale ownership information", function()
    C_Item.GetItemCount = function() addon.quests = {}; return 3 end
    assert(addon.CarriedItemCount(5791) == nil)
    reset(); C_Item.GetItemCount = function() addon.quests[65].start.itemID = 1; return 3 end
    assert(addon.CarriedItemCount(5791) == nil)
    reset(); C_Item.GetItemCount = function() addon.quests[66].completionQuests = {}; return 3 end
    assert(addon.CarriedItemCount(7083) == nil)
end)
check("Related item scan is bounded and restricted entries never authorize native reads", function()
    addon.quests[65].start = secret
    addon.quests[66].completionQuests = { secret, { itemID = secret } }
    assert(addon.CarriedItemCount(5791) == nil and addon.CarriedItemCount(7083) == nil and calls == 0)
    local links = {}
    for index = 1, 100 do links[index] = { itemID = index == 100 and 7083 or 1 } end
    addon.quests[66].completionQuests = links
    assert(addon.CarriedItemCount(7083) == 3)
    links[100].itemID = 1; links[101] = { itemID = 7083 }
    assert(addon.CarriedItemCount(7083) == nil)
end)
check("Counts reread live data without changing quest state actions or catalogue facts", function()
    local context = { level = 60, active = function() return false end, completed = function() return false end }
    local dungeon = { coverage = "reviewed", quests = { 65, 66 } }
    local before = addon.Planner.New(addon.quests, context)
    assert(before:State(65).status == "UNKNOWN" and not before:Dungeon(dungeon).ready)
    for _, value in ipairs({ 0, 1, 7, 2 }) do
        count = value; assert(addon.CarriedItemCount(5791) == value)
        local after = addon.Planner.New(addon.quests, context)
        local actions, unknown = after:Next(65)
        assert(after:State(65).status == "UNKNOWN" and #actions == 0 and unknown and not after:Dungeon(dungeon).ready)
    end
    assert(calls == 4 and addon.quests[65].start.itemID == 5791 and addon.quests[65].requirementsKnown == false)
end)
check("Objective-only items expose live carried counts without quantity or quest-state gates", function()
    addon.quests[68] = { id = 68, minLevel = 1, requirementsKnown = false,
        objectiveItems = { { itemID = 20606, quantity = 2 } } }
    local context = { level = 60, active = function() return false end, completed = function() return false end }
    for _, value in ipairs({ 0, 1, 2, 3 }) do
        count = value; assert(addon.CarriedItemCount(20606) == value)
        local engine = addon.Planner.New(addon.quests, context)
        local actions, uncertain = engine:Next(68)
        assert(engine:State(68).status == "UNKNOWN" and #actions == 0 and uncertain)
        assert(not engine:Dungeon({ coverage = "partial", quests = { 68 } }).ready)
    end
    assert(calls == 4 and addon.quests[68].objectiveItems[1].quantity == 2)
    assert(addon.db == nil and addon.char == nil)
end)
check("Objective links require valid identity and every present quantity remains strict", function()
    local row = { itemID = 20606, quantity = 2 }
    addon.quests[68] = { id = 68, objectiveItems = { row } }
    for _, value in ipairs({ 0, -1, 1.5, "2", false, secret, math.huge, 0/0, 9007199254740992 }) do
        row.quantity = value; assert(addon.CarriedItemCount(20606) == nil and calls == 0)
    end
    row.quantity = 2
    for _, value in ipairs({ 0, -1, 1.5, "20606", false, secret, math.huge, 0/0, 9007199254740992 }) do
        row.itemID = value; assert(addon.CarriedItemCount(20606) == nil and calls == 0)
    end
    row.itemID = nil; assert(addon.CarriedItemCount(20606) == nil and calls == 0)
    row.itemID, row.quantity = 20606, 9007199254740991
    assert(addon.CarriedItemCount(20606) == 3)
end)
check("Objective scan rejects malformed restricted oversized and unbounded tails", function()
    addon.quests[68] = { id = 68 }
    for _, value in ipairs({ false, 2, "items", secret }) do
        addon.quests[68].objectiveItems = value
        assert(addon.CarriedItemCount(20606) == nil and calls == 0)
    end
    addon.quests[68].objectiveItems = { secret, { itemID = secret, quantity = 2 }, { itemID = 20606, quantity = secret } }
    assert(addon.CarriedItemCount(20606) == nil and calls == 0)
    local entries = {}
    for index = 1, 100 do entries[index] = { itemID = index == 100 and 20606 or 1, quantity = 2 } end
    addon.quests[68].objectiveItems = entries
    assert(addon.CarriedItemCount(20606) == 3 and calls == 1)
    entries[101] = { itemID = 20606, quantity = 2 }
    assert(addon.CarriedItemCount(20606) == nil and calls == 1)
end)
check("Objective removal identity and quantity changes during native reads discard results", function()
    for mode = 1, 4 do
        reset(); addon.quests[68] = { id = 68, objectiveItems = { { itemID = 20606, quantity = 2 } } }
        C_Item.GetItemCount = function()
            if mode == 1 then addon.quests[68].objectiveItems = nil
            elseif mode == 2 then addon.quests[68].objectiveItems[1].itemID = 1
            elseif mode == 3 then addon.quests[68].objectiveItems[1].quantity = false
            else addon.quests[68].objectiveItems[1].quantity = secret end
            return 3
        end
        assert(addon.CarriedItemCount(20606) == nil)
    end
end)
check("A remaining valid objective or starter link still authorizes a shared item", function()
    addon.quests[68] = { id = 68, objectiveItems = { { itemID = 20606, quantity = 2 } } }
    addon.quests[69] = { id = 69, objectiveItems = { { itemID = 20606, quantity = 3 } } }
    C_Item.GetItemCount = function()
        addon.quests[68].objectiveItems = nil
        return 3
    end
    assert(addon.CarriedItemCount(20606) == 3)
    addon.quests[69].objectiveItems = nil; assert(addon.CarriedItemCount(20606) == nil)
    addon.quests[68].start = { itemID = 20606 }
    assert(addon.CarriedItemCount(20606) == 3)
end)
check("Known objective identity without a quantity exposes independent carried zero", function()
    addon.quests[68] = { id = 68, minLevel = 1, requirementsKnown = false,
        objectiveItems = { { itemID = 20606 } } }
    local context = { level = 60, active = function() return false end, completed = function() return false end }
    for _, value in ipairs({ 0, 1, 20 }) do
        count = value; assert(addon.CarriedItemCount(20606) == value)
        local engine = addon.Planner.New(addon.quests, context)
        local actions, uncertain = engine:Next(68)
        assert(engine:State(68).status == "UNKNOWN" and #actions == 0 and uncertain)
        assert(not engine:Dungeon({ coverage = "partial", quests = { 68 } }).ready)
    end
    assert(addon.quests[68].objectiveItems[1].quantity == nil and calls == 3)
end)
check("Unknown quantity linkage is rechecked after native reads without inventing a goal", function()
    for mode = 1, 3 do
        reset(); local row = { itemID = 20606 }
        addon.quests[68] = { id = 68, objectiveItems = { row } }
        local reads = 0
        C_Item.GetItemCount = function()
            reads = reads + 1
            if mode == 1 then row.quantity = secret
            elseif mode == 2 then row.quantity = false
            else row.itemID = 1 end
            return 3
        end
        assert(addon.CarriedItemCount(20606) == nil and reads == 1)
    end
    reset(); local row = { itemID = 20606 }
    addon.quests[68] = { id = 68, objectiveItems = { row } }
    C_Item.GetItemCount = function() row.quantity = 2; return 3 end
    assert(addon.CarriedItemCount(20606) == 3 and row.quantity == 2)
    C_Item.GetItemCount = function() row.quantity = nil; return 3 end
    assert(addon.CarriedItemCount(20606) == 3 and row.quantity == nil)
end)
check("Provided-only supplies expose neutral carried zero without changing objective or preparation state", function()
    local quest = { id = 68, minLevel = 1, requirementsKnown = false,
        providedItems = { { itemID = 20606, name = "Provided supply" } } }
    addon.quests[68] = quest
    for _, value in ipairs({ 0, 1, 5 }) do
        count = value; assert(addon.CarriedItemCount(20606) == value)
        local context = { level = 60, active = function() return false end, completed = function() return false end }
        local engine = addon.Planner.New(addon.quests, context)
        assert(engine:State(68).status == "UNKNOWN" and not engine:Dungeon({ coverage = "partial", quests = { 68 } }).ready)
    end
    assert(quest.objectiveItems == nil and quest.requires == nil and quest.providedItems[1].quantity == nil and calls == 3)
end)
check("Malformed supplied metadata cannot authorize an inventory query", function()
    addon.quests[68] = { id = 68 }
    for _, rows in ipairs({ false, {}, secret, { false }, { secret },
        { { itemID = 20606 } }, { { itemID = 20606, name = " " } },
        { { itemID = 20606, name = secret } }, { { itemID = 20606, name = string.rep("界", 167) } },
        { { itemID = 20606, name = "Provided", quantity = false } },
        { { itemID = 20606, name = "Provided", quantity = 0 } },
        { { itemID = 20606, name = "Provided", quantity = secret } },
        { { itemID = 20606, name = "Provided", quantity = 1.5 } },
        { { itemID = 20606, name = "Provided", objectID = 1 } },
        { { itemID = 4294967296, name = "Provided" } } }) do
        addon.quests[68].providedItems = rows
        assert(addon.CarriedItemCount(20606) == nil and calls == 0)
    end
end)
check("Provided relation scan accepts the hundredth entry and rejects an oversized list", function()
    local rows = {}
    for i = 1, 99 do rows[i] = { itemID = i, name = "Other" } end
    rows[100] = { itemID = 20606, name = "Provided", quantity = 2 }
    addon.quests[68] = { id = 68, providedItems = rows }
    assert(addon.CarriedItemCount(20606) == 3 and calls == 1)
    rows[101] = { itemID = 20606, name = "Tail" }
    assert(addon.CarriedItemCount(20606) == nil and calls == 1)
end)
check("Removed replaced invalid or reclassified supplied relations discard a read count", function()
    for mode = 1, 5 do
        reset()
        local row = { itemID = 20606, name = "Provided" }
        addon.quests[68] = { id = 68, providedItems = { row } }
        C_Item.GetItemCount = function()
            if mode == 1 then addon.quests[68].providedItems = nil
            elseif mode == 2 then addon.quests[68].providedItems[1] = { itemID = 1, name = "Other" }
            elseif mode == 3 then row.name = " "
            elseif mode == 4 then row.quantity = secret
            else row.objectID = 1 end
            return 3
        end
        assert(addon.CarriedItemCount(20606) == nil)
    end
end)
check("Final capability sanitization cannot remove the sole provided relation after its linked check", function()
    addon.quests[68] = { id = 68, providedItems = { { itemID = 20606, name = "Provided" } } }
    local read = false
    local getter = function() read = true; return 3 end
    C_Item.GetItemCount = getter
    issecretvalue = function(value)
        if read and value == getter then addon.quests[68].providedItems = nil end
        return false
    end
    assert(addon.CarriedItemCount(20606) == nil and read)
end)
check("Final capability sanitization cannot grow a source list beyond its valid bound", function()
    for _, field in ipairs({ "objectiveItems", "providedItems" }) do
        reset()
        local rows = { { itemID = 20606, name = "Provided" } }
        addon.quests[68] = { id = 68, [field] = rows }
        local read, armed = false, false
        C_Item.GetItemCount = function() read = true; return 3 end
        issecretvalue = function(value)
            if read and (value == "Provided" or type(value) == "table" and value == rows[1]) then armed = true end
            if armed and value == C_Item then
                armed = false
                for i = 2, 101 do rows[i] = { itemID = i, name = "Other" } end
            end
            return false
        end
        assert(addon.CarriedItemCount(20606) == nil and #rows == 101)
    end
end)
check("Supplied name sanitization cannot authorize a stale entry before the native read", function()
    local row = { itemID = 20606, name = "Provided" }
    addon.quests[68] = { id = 68, providedItems = { row } }
    issecretvalue = function(value)
        if value == "Provided" then row.name = false end
        return false
    end
    assert(addon.CarriedItemCount(20606) == nil and calls == 0)
end)
check("Malformed supplied metadata does not suppress another independently valid item role", function()
    addon.quests[68] = { id = 68, providedItems = { { itemID = 20606, name = "Provided", objectID = 1 } },
        completionQuests = { { id = 69, itemID = 20606 } } }
    assert(addon.CarriedItemCount(20606) == 3 and calls == 1)
    addon.quests[68].providedItems = nil
    assert(addon.CarriedItemCount(20606) == 3 and calls == 2)
    addon.quests[68].completionQuests = nil
    assert(addon.CarriedItemCount(20606) == nil and calls == 2)
end)
check("Warm source locations recover moved roles and never cache absence", function()
    assert(addon.CarriedItemCount(5791)==3 and calls==1)
    addon.quests[65].start=nil
    addon.quests[67].objectiveItems={{itemID=5791,name="Moved source"}}
    count=0
    assert(addon.CarriedItemCount(5791)==0 and calls==2)
    addon.quests[67].objectiveItems=nil
    assert(addon.CarriedItemCount(5791)==nil and calls==2)
    addon.quests[67].providedItems={{itemID=5791,name="New source"}}
    count=8
    assert(addon.CarriedItemCount(5791)==8 and calls==3,"an absent relation must not stay negatively cached")
    addon.quests={[70]={id=70,start={itemID=5791}}}
    assert(addon.CarriedItemCount(5791)==8 and calls==4,"replacement catalogues establish their own source locations")
end)
check("Warm supplied locations revalidate names quantities schemas and native capabilities", function()
    addon.quests[68]={id=68,providedItems={{itemID=20606,name="Provided",quantity=2}}}
    assert(addon.CarriedItemCount(20606)==3 and calls==1)
    local entry=addon.quests[68].providedItems[1]
    entry.objectID=10
    assert(addon.CarriedItemCount(20606)==nil and calls==1)
    entry.objectID=nil;entry.quantity=secret
    assert(addon.CarriedItemCount(20606)==nil and calls==1)
    entry.quantity=2;entry.name=" "
    assert(addon.CarriedItemCount(20606)==nil and calls==1)
    entry.name="Provided"
    C_Item.GetItemCount=function()return 17 end
    assert(addon.CarriedItemCount(20606)==17,"the source-location cache must not retain a native getter")
end)
check("Repeated actual-catalogue item reads reuse only positive source ownership, never inventory values", function()
    assert(loadfile("Database/Catalog.lua"))("DungeonPro", addon)
    local frequency, ordered = {}, {}
    for _,quest in next,addon.quests do
        local ids={}
        if quest.start and quest.start.itemID then ids[#ids+1]=quest.start.itemID end
        for _,field in ipairs({"objectiveItems","providedItems","completionQuests"})do
            for _,entry in ipairs(quest[field] or{})do if entry.itemID then ids[#ids+1]=entry.itemID end end
        end
        for _,id in ipairs(ids)do frequency[id]=(frequency[id]or 0)+1;ordered[#ordered+1]=id end
    end
    local selected
    for _,id in ipairs(ordered)do if frequency[id]==1 then selected=id end end
    assert(selected)
    local reads,checks,clean=0,0,addon.Clean
    addon.Clean=function(...)checks=checks+1;return clean(...)end
    C_Item.GetItemCount=function(id)assert(id==selected);reads=reads+1;return reads==21 and 0 or reads end
    assert(addon.CarriedItemCount(selected)==1)
    checks=0
    for expected=2,20 do assert(addon.CarriedItemCount(selected)==expected)end
    assert(addon.CarriedItemCount(selected)==0 and reads==21,"inventory counts must stay live")
    local warmChecks=checks
    addon.Clean=clean
    assert(warmChecks<2000,"repainting one known item must not rescan all571quest definitions twice per read: "..warmChecks)
    print("Actual catalogue repeated item source checks: "..warmChecks.." /20reads")
end)
issecretvalue = nil
print("Carried item count checks passed: " .. total .. " (native client unverified)")
