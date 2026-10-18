local total=0
local function fixture()
    local addon={};assert(loadfile("Core/Namespace.lua"))("DungeonPro",addon)
    assert(loadfile("Core/Client.lua"))("DungeonPro",addon)
    addon.db,addon.char,addon.quests={locale="enUS"},{},{}
    GetLocale=function()return"enUS"end;issecretvalue=function()return false end
    local f={addon=addon,queue={},requests=0,notifications=0}
    C_Timer={After=function(delay,fn)f.queue[#f.queue+1]={delay=delay,fn=fn}end}
    C_QuestLog={GetTitleForQuestID=function()return nil end,RequestLoadQuestByID=function()f.requests=f.requests+1 end}
    C_Item={GetItemNameByID=function()return nil end,IsItemDataCachedByID=function()return false end,
        RequestLoadItemDataByID=function()f.requests=f.requests+1 end}
    addon.Notify=function()f.notifications=f.notifications+1 end
    function f:prime(count)
        for id=1,count do addon.quests[id]={id=id,name="Quest "..id};addon.QuestName(id);addon.ItemName(1000+id)end
    end
    function f:fail(count)
        for id=1,count do addon.QuestDataResult(id,false);addon.ItemDataResult(1000+id,false)end
    end
    function f:fire(delay)
        local due={}
        for index=#self.queue,1,-1 do if self.queue[index].delay==delay then table.insert(due,1,table.remove(self.queue,index))end end
        for _,job in ipairs(due)do job.fn()end
        return #due
    end
    return f
end
local function test(name,fn)
    local ok,err=pcall(fn);assert(ok,name..": "..tostring(err));total=total+1;print("PASS "..name)
end
test("Forty failed title and item retries coalesce into one deferred refresh",function()
    local f=fixture();f:prime(20);f:fail(20)
    assert(f.requests==40 and f:fire(2)==40)
    assert(f.notifications==0,"retry batch painted immediately for every ID")
    assert(f:fire(.1)==1 and f.notifications==1)
end)
test("Batch refresh preserves every per-ID retry and the three-request limit",function()
    local f=fixture();f:prime(10)
    f.addon.Notify=function()f.notifications=f.notifications+1;f:prime(10)end
    for _=1,2 do f:fail(10);assert(f:fire(2)==20);assert(f:fire(.1)==1)end
    f:fail(10);assert(f:fire(2)==0 and f.requests==60 and f.notifications==2)
    f:fire(10);assert(f.notifications==2)
end)
test("A new retry during asynchronous Notify schedules a later refresh",function()
    local f=fixture();f:prime(2)
    f.addon.Notify=function()
        f.notifications=f.notifications+1
        if f.notifications==1 then f.addon.QuestDataResult(2,false);f:fire(2)end
    end
    f.addon.QuestDataResult(1,false);f:fire(2);assert(f:fire(.1)==1 and f.notifications==1)
    assert(f:fire(.1)==1 and f.notifications==2)
end)
test("Missing rejected throwing inline and queued-then-failed timers stay bounded",function()
    for _,mode in ipairs({"missing","rejected","throw","inline","queued-throw"})do
        local f=fixture();f:prime(1);f:fail(1)
        local stale
        C_Timer=mode=="missing"and{}or{After=function(_,fn)
            if mode=="rejected"then return false elseif mode=="throw"then error("unsupported")
            elseif mode=="queued-throw"then stale=fn;error("queued")else fn()end
        end}
        f:fire(2);assert(f.notifications==2,"fallback must deliver each independent retry without recursion")
        if stale then stale();assert(f.notifications==2)end
    end
end)
test("Successful irrelevant or duplicate results schedule no retry refresh",function()
    local f=fixture();f:prime(1)
    f.addon.QuestDataResult(1,true);f.addon.ItemDataResult(1001,true)
    f:fail(1);f.addon.QuestDataResult(999,false);f.addon.ItemDataResult(999,false)
    assert(f:fire(2)==0 and f.notifications==0)
end)
print("Client retry refresh: "..total.." checks passed")
