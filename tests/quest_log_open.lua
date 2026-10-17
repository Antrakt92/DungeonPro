local addon, total, secret = {}, 0, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local calls, active, index
local function reset()
    calls, active, index = 0, true, 4
    addon.char, addon.quests = {}, { [123] = { id = 123 } }
    issecretvalue = function(value) return value == secret end
    C_QuestLog = {
        IsOnQuest = function(id) assert(id == 123); return active end,
        GetLogIndexForQuestID = function(id) assert(id == 123); return index end,
        GetSelectedQuest = function() error("selection read unnecessary") end,
        SetSelectedQuest = function() error("separate selection write forbidden") end,
        RequestLoadQuestByID = function() error("request forbidden") end,
    }
    QuestMapFrame_OpenToQuestDetails = function(...) assert(select("#", ...) == 1 and (...) == 123); calls = calls + 1 end
    C_Timer = { After = function() error("timer forbidden") end }
end
local function check(name, callback)
    reset(); local ok, err = pcall(callback)
    assert(ok, name .. ": " .. tostring(err)); total = total + 1; print("PASS " .. name)
end
check("Capability is read-only and explicit dispatch uses quest ID rather than log index", function()
    assert(addon.CanOpenQuestLog(123) == true and calls == 0)
    assert(addon.OpenQuestLogQuest(123) == true and calls == 1)
    assert(addon.CanOpenQuestLog(123) == true and calls == 1)
end)
check("Inactive history-only unknown or header quests cannot dispatch", function()
    for _,value in ipairs({false, secret, "true", 1}) do
        active=value; assert(addon.CanOpenQuestLog(123)==false and addon.OpenQuestLogQuest(123)==false)
    end
    active=nil; assert(addon.OpenQuestLogQuest(123)==false)
    active=true
    for _,value in ipairs({0,-1,1.5,secret,"4",math.huge,0/0}) do
        index=value;assert(addon.OpenQuestLogQuest(123)==false)
    end
    index=nil;assert(addon.OpenQuestLogQuest(123)==false and calls==0)
end)
check("Invalid or unknown catalogue identities stay quiet", function()
    for _,value in ipairs({0,-1,1.5,secret,"123",false,math.huge,0/0,9007199254740992}) do
        assert(addon.CanOpenQuestLog(value)==false and addon.OpenQuestLogQuest(value)==false)
    end
    assert(addon.OpenQuestLogQuest(nil)==false)
    addon.quests[123]=nil; assert(addon.OpenQuestLogQuest(123)==false and calls==0)
end)
check("Missing malformed and throwing native capabilities never dispatch", function()
    for _,value in ipairs({false,true,42,"bad",secret}) do
        reset();C_QuestLog=value;assert(addon.OpenQuestLogQuest(123)==false)
    end
    reset();C_QuestLog=nil;assert(addon.OpenQuestLogQuest(123)==false)
    for _,key in ipairs({"IsOnQuest","GetLogIndexForQuestID"}) do
        reset();C_QuestLog[key]=nil;assert(addon.OpenQuestLogQuest(123)==false)
        reset();C_QuestLog[key]=function() error("native failure") end;assert(addon.OpenQuestLogQuest(123)==false)
    end
    reset();QuestMapFrame_OpenToQuestDetails=nil;assert(addon.CanOpenQuestLog(123)==false)
    reset();QuestMapFrame_OpenToQuestDetails=function() error("unavailable")end
    assert(addon.OpenQuestLogQuest(123)==false and calls==0)
end)
check("Both held queries reject character namespace getter opener and catalogue drift", function()
    for _,query in ipairs({"IsOnQuest","GetLogIndexForQuestID"}) do
        for mode=1,7 do
            reset();local native=C_QuestLog[query]
            C_QuestLog[query]=function(id)
                local result=native(id)
                if mode==1 then addon.char={}
                elseif mode==2 then C_QuestLog={}
                elseif mode==3 then C_QuestLog.IsOnQuest=function()return true end
                elseif mode==4 then C_QuestLog.GetLogIndexForQuestID=function()return 4 end
                elseif mode==5 then QuestMapFrame_OpenToQuestDetails=function()calls=calls+100 end
                elseif mode==6 then addon.quests[123]={id=123}
                else issecretvalue=function()return false end end
                return result
            end
            assert(addon.OpenQuestLogQuest(123)==false and calls==0)
        end
    end
end)
check("Final sanitizer reentry cannot publish a stale dispatch capability", function()
    local native=issecretvalue
    issecretvalue=function(value)
        if value==index then QuestMapFrame_OpenToQuestDetails=function()calls=calls+100 end end
        return native(value)
    end
    assert(addon.OpenQuestLogQuest(123)==false and calls==0)
    reset();issecretvalue=function()error("restricted")end
    assert(addon.OpenQuestLogQuest(123)==false and calls==0)
end)
check("Capability snapshots are not cached across clicks and successful dispatch is not visibility proof", function()
    assert(addon.CanOpenQuestLog(123));active=false
    assert(addon.OpenQuestLogQuest(123)==false and calls==0)
    active=true;QuestMapFrame_OpenToQuestDetails=function()calls=calls+1;return false end
    assert(addon.OpenQuestLogQuest(123)==true and calls==1)
end)
print("Quest-log opening modeled checks passed: " .. total .. " (no native visibility validation)")
