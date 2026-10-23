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
test("RestoreDB rejects metatable-carrying nested roots and oversized texts",function()
    local f=fixture()
    local savedPro,savedChar,savedPrep,savedPrepChar=DungeonProDB,DungeonProCharDB,DungeonPrepDB,DungeonPrepCharDB
    local activeDB,activeChar=f.addon.db,f.addon.char
    local function hostileNested(payload)
        return setmetatable(payload or {},{
            __index=function() error("hostile nested index") end,
            __newindex=function() error("hostile nested newindex") end,
            __pairs=function() error("hostile nested pairs") end})
    end
    local function checkRoots(label,setupDB,setupChar)
        DungeonProDB,DungeonProCharDB,DungeonPrepDB,DungeonPrepCharDB=setupDB,setupChar,nil,nil
        local ok,result=pcall(f.addon.RestoreDB)
        assert(ok,label.." threw instead of failing closed: "..tostring(result))
        assert(result==false,label.." adopted a metatable-carrying nested root")
        assert(f.addon.db==activeDB and f.addon.char==activeChar,label.." replaced active state on rejection")
        assert(DungeonProDB==setupDB and DungeonProCharDB==setupChar,label.." mutated saved roots on rejection")
    end
    for _,pair in ipairs({
        {"texts",function(h) return {},{texts=h,filters={}} end},
        {"window",function(h) return {window=h},{texts={},filters={}} end},
        {"filters",function(h) return {},{texts={},filters=h} end},
        {"minimap",function(h) return {minimap=h},{texts={},filters={}} end},
    }) do
        local label,nest=pair[1],pair[2]
        local db,char=nest(hostileNested({[0]={text="Bad",locale="enUS"}}))
        checkRoots("new "..label,db,char)
        local legacyDB,legacyChar=nest(hostileNested({}))
        DungeonProDB,DungeonProCharDB=nil,nil
        DungeonPrepDB,DungeonPrepCharDB=legacyDB,legacyChar
        local okLegacy,legacyResult=pcall(f.addon.RestoreDB)
        assert(okLegacy,"legacy "..label.." threw instead of failing closed: "..tostring(legacyResult))
        assert(legacyResult==false,"legacy "..label.." adopted a metatable-carrying nested root")
        assert(f.addon.db==activeDB and f.addon.char==activeChar,"legacy "..label.." replaced active state")
        assert(DungeonPrepDB==legacyDB and DungeonPrepCharDB==legacyChar,"legacy "..label.." mutated saved roots")
        assert(legacyDB.schema==nil,"legacy "..label.." normalized schema before failing closed")
    end
    local bloated={};for id=1,10001 do bloated[id]={text="Quest "..id,locale="enUS"} end
    DungeonProDB,DungeonProCharDB={},{texts=bloated,filters={}}
    DungeonPrepDB,DungeonPrepCharDB=nil,nil
    local okBig,bigResult=pcall(f.addon.RestoreDB)
    assert(okBig,"oversized texts threw instead of failing closed: "..tostring(bigResult))
    assert(bigResult==false,"oversized texts did not fail closed")
    assert(f.addon.db==activeDB and f.addon.char==activeChar,"oversized texts replaced active state")
    local capped={};for id=1,10000 do capped[id]={text="Quest "..id,locale="enUS"} end
    DungeonProDB,DungeonProCharDB={},{texts=capped,filters={}}
    local okCap,capResult=pcall(f.addon.RestoreDB)
    assert(okCap and capResult==true,"10000 retained texts must still restore")
    assert(f.addon.char.texts==capped and f.addon.char.texts[10000].text=="Quest 10000","capped retention lost entries")
    DungeonProDB,DungeonProCharDB,DungeonPrepDB,DungeonPrepCharDB=savedPro,savedChar,savedPrep,savedPrepChar
    f.addon.db,f.addon.char=activeDB,activeChar
end)
test("RestoreDB rejects metatable-carrying choices root without throwing",function()
    local f=fixture()
    local savedPro,savedChar,savedPrep,savedPrepChar=DungeonProDB,DungeonProCharDB,DungeonPrepDB,DungeonPrepCharDB
    local activeDB,activeChar=f.addon.db,f.addon.char
    local hostile=setmetatable({[1]={[1]=1}},{
        __index=function() error("hostile choices index") end,
        __newindex=function() error("hostile choices newindex") end,
        __pairs=function() error("hostile choices pairs") end})
    DungeonProDB,DungeonProCharDB,DungeonPrepDB,DungeonPrepCharDB={},{texts={},filters={},choices=hostile},nil,nil
    local ok,result=pcall(f.addon.RestoreDB)
    assert(ok,"choices root threw instead of failing closed: "..tostring(result))
    assert(result==false,"choices root adopted a metatable-carrying choices table")
    assert(f.addon.db==activeDB and f.addon.char==activeChar,"choices root replaced active state on rejection")
    assert(DungeonProDB.schema==nil,"choices root normalized schema before failing closed")
    DungeonProDB,DungeonProCharDB={},{texts={},filters={},choices={[1]={[1]=1}}}
    local okPlain,plainResult=pcall(f.addon.RestoreDB)
    assert(okPlain and plainResult==true,"plain-table choices path changed")
    assert(f.addon.char.choices[1][1]==1,"plain choices entry changed")
    DungeonProDB,DungeonProCharDB,DungeonPrepDB,DungeonPrepCharDB=savedPro,savedChar,savedPrep,savedPrepChar
    f.addon.db,f.addon.char=activeDB,activeChar
end)
test("RestoreDB drops metatable-carrying texts entries while keeping valid minimap configs",function()
    local f=fixture()
    local savedPro,savedChar,savedPrep,savedPrepChar=DungeonProDB,DungeonProCharDB,DungeonPrepDB,DungeonPrepCharDB
    local activeDB,activeChar=f.addon.db,f.addon.char
    f.addon.L=function(key) return key end
    local function hostileEntry(payload)
        return setmetatable(payload or {},{
            __index=function() error("hostile entry index") end,
            __newindex=function() error("hostile entry newindex") end})
    end
    local config={hide=false,angle=225}
    DungeonProDB,DungeonProCharDB,DungeonPrepDB,DungeonPrepCharDB=
        {minimap=config},{texts={[1]=hostileEntry(),[2]=hostileEntry({text="Bad",locale="enUS"}),[3]={text="Good",locale="enUS"}},filters={}},nil,nil
    local ok,result=pcall(f.addon.RestoreDB)
    assert(ok,"entry hygiene threw instead of failing closed: "..tostring(result))
    assert(result==true,"valid roots with hostile entries did not restore")
    assert(f.addon.char.texts[1]==nil and f.addon.char.texts[2]==nil,"hygiene retained a metatable-carrying entry")
    assert(f.addon.char.texts[3] and f.addon.char.texts[3].text=="Good","hygiene dropped a valid entry")
    assert(f.addon.db.minimap==config and f.addon.db.minimap.hide==false and f.addon.db.minimap.angle==225,"valid minimap config changed")
    local okGone,gone=pcall(f.addon.Description,1)
    assert(okGone and gone=="NO_TEXT","dropped entry did not fail closed: "..tostring(gone))
    local okGood,good=pcall(f.addon.Description,3)
    assert(okGood and good=="Good","valid entry path changed: "..tostring(good))
    DungeonProDB,DungeonProCharDB,DungeonPrepDB,DungeonPrepCharDB=savedPro,savedChar,savedPrep,savedPrepChar
    f.addon.db,f.addon.char=activeDB,activeChar
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
