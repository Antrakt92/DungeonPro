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
test("Equal numeric quest and item IDs retain independent results and ignore late callbacks",function()
    local f=fixture()
    local questRequests,itemRequests=0,0
    f.addon.quests[1]={id=1,name="Quest"}
    C_QuestLog.RequestLoadQuestByID=function()questRequests=questRequests+1 end
    C_Item.RequestLoadItemDataByID=function()itemRequests=itemRequests+1 end
    f.addon.QuestName(1);f.addon.ItemName(1)
    assert(questRequests==1 and itemRequests==1)
    f.addon.QuestDataResult(1,true);f.addon.ItemDataResult(1,false)
    assert(f:fire(2)==1 and f:fire(.1)==1 and f.notifications==1)
    f.addon.QuestName(1);f.addon.ItemName(1)
    assert(questRequests==1 and itemRequests==2)
    f.addon.ItemDataResult(1,false)
    local stale
    for _,job in ipairs(f.queue)do if job.delay==2 then stale=job.fn end end
    assert(stale and f:fire(2)==1 and f:fire(.1)==1)
    f.addon.ItemName(1);f.addon.ItemDataResult(1,true)
    stale();f:fire(10)
    assert(f:fire(2)==0 and f:fire(.1)==0 and f.notifications==2)
    f.addon.QuestName(1);f.addon.ItemName(1)
    assert(questRequests==1 and itemRequests==3)
end)
test("Hostile throwing-index Blizzard tables fail closed without throwing",function()
    local f=fixture()
    local function hostile() return setmetatable({},{__index=function() error("hostile index") end}) end
    local savedTimer,savedLog,savedItem=C_Timer,C_QuestLog,C_Item
    C_QuestLog=hostile()
    local ok,ctx=pcall(f.addon.Context)
    assert(ok and ctx,"Context must not throw on a hostile C_QuestLog")
    assert(ctx.completed(1)==nil and ctx.active(1)==nil and ctx.ready(1)==nil)
    assert(pcall(ctx.current))
    assert(pcall(f.addon.CanOpenQuestLog,1) and f.addon.CanOpenQuestLog(1)==false)
    assert(pcall(f.addon.QuestLogCapacity) and f.addon.QuestLogCapacity()==nil)
    assert(pcall(f.addon.QuestObjectives,1) and f.addon.QuestObjectives(1)==nil)
    C_Item=hostile()
    assert(pcall(f.addon.CarriedItemCount,1) and f.addon.CarriedItemCount(1)==nil)
    assert(pcall(f.addon.ItemName,1) and f.addon.ItemName(1)==nil)
    C_QuestLog={GetNumQuestLogEntries=function() return 0,0 end}
    Constants=hostile()
    local okCap,cap=pcall(f.addon.QuestLogCapacity)
    assert(okCap and cap==nil,"capacity fallback must not throw on hostile Constants")
    Constants=nil
    C_Timer=hostile()
    f.addon.quests[99]={id=99,name="Quest 99"}
    C_QuestLog,C_Item=savedLog,savedItem
    assert(pcall(f.addon.QuestName,99) and pcall(f.addon.ItemName,1099))
    assert(pcall(f.addon.QuestDataResult,99,false) and pcall(f.addon.ItemDataResult,1099,false))
    C_Timer,C_QuestLog,C_Item=savedTimer,savedLog,savedItem
    C_QuestLog={GetNumQuestLogEntries=function() return 0,3 end,GetMaxNumQuestsCanAccept=function() return 25 end}
    local okFull,full=pcall(f.addon.QuestLogCapacity)
    assert(okFull and type(full)=="table" and full.count==3 and full.capacity==25,"valid capacity path changed")
    C_QuestLog=savedLog
    local okValid,validCtx=pcall(f.addon.Context)
    assert(okValid and validCtx and validCtx.completed(1)==nil,"valid Context path changed")
end)
test("RestoreDB rejects metatable-carrying saved variables without throwing",function()
    local f=fixture()
    local savedPro,savedChar,savedPrep,savedPrepChar=DungeonProDB,DungeonProCharDB,DungeonPrepDB,DungeonPrepCharDB
    local activeDB,activeChar=f.addon.db,f.addon.char
    local function hostileSV() return setmetatable({},{__index=function() error("hostile SV") end}) end
    DungeonProDB,DungeonProCharDB=hostileSV(),hostileSV()
    DungeonPrepDB,DungeonPrepCharDB=nil,nil
    local ok,result=pcall(f.addon.RestoreDB)
    assert(ok and result==false,"RestoreDB must return false, not throw, on hostile SVs")
    assert(f.addon.db==activeDB and f.addon.char==activeChar)
    DungeonProDB,DungeonProCharDB={},hostileSV()
    local okHalf,halfResult=pcall(f.addon.RestoreDB)
    assert(okHalf and halfResult==false,"RestoreDB must reject a hostile character root")
    DungeonProDB,DungeonProCharDB={},{texts={}}
    local okPlain,plainResult=pcall(f.addon.RestoreDB)
    assert(okPlain and plainResult==true,"plain-table RestoreDB path changed")
    assert(DungeonProDB.schema==1 and DungeonProDB.locale=="auto")
    DungeonProDB,DungeonProCharDB,DungeonPrepDB,DungeonPrepCharDB=savedPro,savedChar,savedPrep,savedPrepChar
end)
test("Hostile throwing-index timer fails closed in the event refresh probe",function()
    local f=fixture()
    local savedTimer,savedLog,savedItem=C_Timer,C_QuestLog,C_Item
    local savedBuild,savedProject,savedSlash=GetBuildInfo,WOW_PROJECT_ID,SlashCmdList
    local savedDiag=f.addon.Diagnostics
    local frame={events={}}
    function frame:RegisterEvent(event) self.events[event]=true end
    function frame:SetScript(name,fn) self.scripts=name=="OnEvent"and fn or nil end
    CreateFrame=function() return frame end
    f.addon.Diagnostics={Navigation=function() end,Minimap=function() end}
    f.addon.L=function(key) return key end
    GetBuildInfo=function() return "1.60.1","70425","",16001 end
    WOW_PROJECT_ID=18
    SlashCmdList={}
    assert(loadfile("Core/Events.lua"))("DungeonPro",f.addon)
    frame.scripts(frame,"ADDON_LOADED","DungeonPro")
    assert(frame.events.QUEST_LOG_UPDATE,"refresh events did not register")
    local before=f.notifications
    C_Timer=setmetatable({},{__index=function() error("hostile timer") end})
    local ok=pcall(frame.scripts,frame,"QUEST_LOG_UPDATE")
    assert(ok,"event refresh threw on a hostile C_Timer")
    assert(f.notifications==before+1,"hostile timer skipped the inline refresh")
    C_Timer,C_QuestLog,C_Item=savedTimer,savedLog,savedItem
    GetBuildInfo,WOW_PROJECT_ID,SlashCmdList=savedBuild,savedProject,savedSlash
    f.addon.Diagnostics=savedDiag
    SLASH_DUNGEONPRO1,SLASH_DUNGEONPRO2,SLASH_DUNGEONPRO3,SLASH_DUNGEONPRO4,SLASH_DUNGEONPRORELOAD1=nil,nil,nil,nil,nil
    CreateFrame=nil
end)
print("Client retry refresh: "..total.." checks passed")
