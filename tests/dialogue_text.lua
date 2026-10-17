local total, addon, f = 0, nil, nil
local secret = {}
local function setup()
    addon={};assert(loadfile("Core/Namespace.lua"))("DungeonPro",addon)
    addon.quests={[65]={id=65},[66]={id=66}};addon.char={texts={enUS={[65]={description="Saved offer"}}}}
    f={id=65,player="Player-one",locale="enUS",shown=true,progress=true,completion=false,progressText="Current progress",rewardText="Current turn-in",progressReads=0,rewardReads=0}
    issecretvalue=function(v)return v==secret end
    GetQuestID=function(...)assert(select("#",...)==0);return f.id end
    UnitGUID=function(unit)assert(unit=="player");return f.player end
    GetLocale=function(...)assert(select("#",...)==0);return f.locale end
    GetProgressText=function(...)assert(select("#",...)==0);f.progressReads=f.progressReads+1;return f.progressText end
    GetRewardText=function(...)assert(select("#",...)==0);f.rewardReads=f.rewardReads+1;return f.rewardText end
    QuestFrame={IsShown=function(self)assert(self==QuestFrame);return f.shown end}
    QuestFrameProgressPanel={IsShown=function(self)assert(self==QuestFrameProgressPanel);return f.progress end}
    QuestFrameRewardPanel={IsShown=function(self)assert(self==QuestFrameRewardPanel);return f.completion end}
    local function forbidden()error("No selection held NPC acceptance load timer or balance reads")end
    C_QuestLog={IsOnQuest=forbidden,GetSelectedQuest=forbidden,SetSelectedQuest=forbidden,RequestLoadQuestByID=forbidden}
    AcceptQuest,CompleteQuest,GetQuestReward,GetMoney=forbidden,forbidden,forbidden,forbidden
    C_Timer={After=forbidden};C_GossipInfo={SelectAvailableQuest=forbidden}
    assert(loadfile("Core/DialogueText.lua"))("DungeonPro",addon)
end
local function check(name,fn)
    setup();local ok,err=pcall(fn);assert(ok,name..": "..tostring(err));total=total+1;print("PASS "..name)
end
local function open(stage)
    f.progress,f.completion=stage=="progress",stage=="completion"
    addon.DialogueTextEvent(stage=="progress"and"QUEST_PROGRESS"or"QUEST_COMPLETE")
end
check("Known live progress and turn-in stages read separate zeroargument native text",function()
    assert(addon.DialogueText(65)==nil);open("progress");assert(f.progressReads==0 and f.rewardReads==0)
    local d=assert(addon.DialogueText(65));assert(d.source=="dialogue"and d.stage=="progress"and d.text==f.progressText and d.questID==nil)
    d.text="Mutated detached";assert(addon.DialogueText(65).text==f.progressText)
    open("completion");assert(f.rewardReads==0);d=assert(addon.DialogueText(65));assert(d.stage=="completion"and d.text==f.rewardText)
    assert(f.rewardReads==1 and addon.char.texts.enUS[65].description=="Saved offer")
end)
check("Catalogue identity and visible exact native stage are mandatory without questlog or NPC reads",function()
    for _,id in ipairs({0,-1,65.5,"65",secret,math.huge,0/0,67})do open("progress");assert(addon.DialogueText(id)==nil)end
    for _,mode in ipairs({"frame","panel","both","unknown","wrongid","definition","character"})do
        setup();open("progress")
        if mode=="frame"then f.shown=false elseif mode=="panel"then f.progress=false elseif mode=="both"then f.completion=true
        elseif mode=="unknown"then f.progress=nil elseif mode=="wrongid"then f.id=66 elseif mode=="definition"then addon.quests[65].id=66 else addon.char=nil end
        assert(addon.DialogueText(65)==nil,mode)
    end
end)
check("Event capture does not depend on native panel event ordering and never captures text",function()
    f.shown,f.progress=false,false;addon.DialogueTextEvent("QUEST_PROGRESS");assert(f.progressReads==0)
    f.shown,f.progress=true,true;assert(addon.DialogueText(65).text==f.progressText)
    addon.DialogueTextEvent("QUEST_LOG_UPDATE");assert(addon.DialogueText(65))
end)
check("Every close context or quest mutation invalidates prior dialogue evidence",function()
    for _,event in ipairs({"QUEST_FINISHED","QUEST_DETAIL","QUEST_GREETING","GOSSIP_SHOW","GOSSIP_CLOSED","GOSSIP_OPTIONS_REFRESHED","QUEST_ACCEPTED","QUEST_REMOVED","QUEST_TURNED_IN","PLAYER_LEAVING_WORLD","PLAYER_ENTERING_WORLD","PLAYER_LOGOUT"})do
        open("progress");assert(addon.DialogueText(65));addon.DialogueTextEvent(event);assert(addon.DialogueText(65)==nil,event)
    end
    open("progress");assert(addon.DialogueText(65));f.shown=false;assert(addon.DialogueText(65)==nil);f.shown=true;assert(addon.DialogueText(65)==nil,"Previously observed closed evidence must not resurrect")
end)
check("Blank missing failed restricted and overbound text remain absent while multibyte text survives",function()
    for _,value in ipairs({"","  ",string.rep("x",30001),secret,42,false})do open("progress");f.progressText=value;assert(addon.DialogueText(65)==nil)end
    open("progress");GetProgressText=function()error("Unavailable")end;assert(addon.DialogueText(65)==nil)
    setup();open("progress");f.progressText=string.rep("x",30000);assert(#addon.DialogueText(65).text==30000)
    f.progressText=string.char(208,166,208,181,208,187,209,140);assert(addon.DialogueText(65).text==f.progressText)
end)
check("Character player locale catalogue and native capability drift reject old metadata",function()
    for _,mode in ipairs({"char","player","locale","definition","idgetter","textgetter","frame","panel","showngetter","checker","readhelper"})do
        setup();open("progress");local old=GetProgressText
        GetProgressText=function()return old()end;open("progress")
        local getter=GetProgressText
        GetProgressText=function()
            local result=getter()
            if mode=="char"then addon.char={} elseif mode=="player"then f.player="Player-two" elseif mode=="locale"then f.locale="ruRU"
            elseif mode=="definition"then addon.quests[65]={id=65} elseif mode=="idgetter"then GetQuestID=function()return 65 end
            elseif mode=="textgetter"then GetProgressText=function()return"New"end elseif mode=="frame"then QuestFrame={IsShown=function()return true end}
            elseif mode=="panel"then QuestFrameProgressPanel={IsShown=function()return true end} elseif mode=="showngetter"then QuestFrameProgressPanel.IsShown=function()return true end
            elseif mode=="checker"then issecretvalue=function()return false end else addon.Read=function()return nil end end
            return result
        end
        -- Capture the wrapper, so mutation occurs during the actual native text read.
        open("progress");assert(addon.DialogueText(65)==nil,mode)
    end
end)
check("Missing malformed or restricted stage capabilities quietly omit the optional module data",function()
    for _,mode in ipairs({"getter","frame","method","player","locale","id","secretframe"})do
        setup()
        if mode=="getter"then GetProgressText=nil elseif mode=="frame"then QuestFrame=true elseif mode=="method"then QuestFrameProgressPanel.IsShown=nil
        elseif mode=="player"then f.player=secret elseif mode=="locale"then f.locale=nil elseif mode=="id"then f.id=secret else QuestFrame=secret end
        open("progress");assert(addon.DialogueText(65)==nil,mode)
    end
end)
check("Nested native text reads preserve newer samequest event stage instead of older text",function()
    local armed=true
    GetProgressText=function()
        if armed then armed=false;f.progress=false;f.completion=true;addon.DialogueTextEvent("QUEST_COMPLETE")end
        return"Old progress"
    end
    open("progress");assert(addon.DialogueText(65)==nil);local dto=assert(addon.DialogueText(65));assert(dto.stage=="completion"and dto.text==f.rewardText)
end)
check("Reentrant metadata capture cannot overwrite a newer quest event",function()
    local armed=true;local get=GetQuestID
    GetQuestID=function()
        if armed then armed=false;f.id=66;f.progress=false;f.completion=true;addon.DialogueTextEvent("QUEST_COMPLETE");return 65 end
        return get()
    end
    addon.DialogueTextEvent("QUEST_PROGRESS");assert(addon.DialogueText(65)==nil);local dto=assert(addon.DialogueText(66));assert(dto.stage=="completion")
end)
check("Caller scope and late native visibility changes cannot authorize stale stage text",function()
    open("progress");assert(addon.DialogueText(65,function()return false end)==nil)
    open("progress");assert(addon.DialogueText(65,function()error("Gone")end)==nil)
    open("progress");assert(addon.DialogueText(65,secret)==nil)
    setup();local valid=true;local old=GetProgressText;GetProgressText=function()valid=false;return old()end;open("progress")
    assert(addon.DialogueText(65,function()return valid end)==nil)
    setup();local shown=QuestFrameProgressPanel.IsShown;QuestFrameProgressPanel.IsShown=function(self)local result=shown(self);f.id=66;return result end;open("progress")
    assert(addon.DialogueText(65)==nil)
end)
check("Final catalogue sanitization cannot replace a nested newer capture and late ID reads recheck caller ownership",function()
    local armed=true;local clean=addon.Clean
    addon.Clean=function(value,kind)
        if armed and kind=="number" and value==65 then
            armed=false;f.id=66;f.progress=false;f.completion=true;addon.DialogueTextEvent("QUEST_COMPLETE")
        end
        return clean(value,kind)
    end
    addon.DialogueTextEvent("QUEST_PROGRESS");assert(addon.DialogueText(65)==nil);assert(addon.DialogueText(66).stage=="completion")
    setup();local valid=true;local old=GetQuestID;GetQuestID=function()local id=old();if f.progressReads>0 then valid=false end;return id end
    open("progress");assert(addon.DialogueText(65,function()return valid end)==nil)
end)
check("Detached current predicate checks live scope without rereading native prose",function()
    open("progress");local dto=assert(addon.DialogueText(65));local reads=f.progressReads
    assert(type(dto.current)=="function");for i=1,5 do assert(dto.current()==true)end
    assert(f.progressReads==reads and f.rewardReads==0)
end)
check("Detached current predicate becomes false after close stage context or capability loss",function()
    for _,mode in ipairs({"close","stage","char","player","locale","panel","getter","caller"})do
        setup();local valid=true;open("progress");local dto=assert(addon.DialogueText(65,function()return valid end));local reads=f.progressReads
        if mode=="close"then f.shown=false elseif mode=="stage"then open("completion") elseif mode=="char"then addon.char={}
        elseif mode=="player"then f.player="Player-two" elseif mode=="locale"then f.locale="ruRU" elseif mode=="panel"then f.progress=false
        elseif mode=="getter"then GetProgressText=function()return"Replacement"end else valid=false end
        assert(dto.current()==false,mode);assert(f.progressReads==reads,mode)
    end
end)
check("An old detached current predicate cannot erase a newer samequest stage observation",function()
    open("progress");local old=assert(addon.DialogueText(65));open("completion");local fresh=assert(addon.DialogueText(65))
    assert(old.current()==false and fresh.current()==true)
    assert(addon.DialogueText(65).stage=="completion")
end)
check("Pending native stage survives an early UI read before the native panel handler runs",function()
    for _,stage in ipairs({"progress","completion"})do
        setup();f.shown,f.progress,f.completion=false,false,false
        addon.DialogueTextEvent(stage=="progress"and"QUEST_PROGRESS"or"QUEST_COMPLETE")
        assert(addon.DialogueText(65)==nil and f.progressReads==0 and f.rewardReads==0)
        f.shown,f.progress,f.completion=true,stage=="progress",stage=="completion"
        local dto=assert(addon.DialogueText(65),"Early getter erased a not-yet-visible event stage")
        assert(dto.stage==stage and dto.current()==true)
    end
end)
check("Pending nextstage is distinct from an already observed stage closing",function()
    open("progress");local old=assert(addon.DialogueText(65))
    addon.DialogueTextEvent("QUEST_COMPLETE")
    assert(addon.DialogueText(65)==nil and old.current()==false)
    f.progress,f.completion=false,true
    local dto=assert(addon.DialogueText(65));assert(dto.stage=="completion")
    f.completion=false;assert(addon.DialogueText(65)==nil);f.completion=true
    assert(addon.DialogueText(65)==nil,"A previously observed closed stage resurrected")
end)
check("A stale consumer cannot erase otherwise valid pending or visible global dialogue evidence",function()
    for _,pending in ipairs({false,true})do
        setup();f.shown,f.progress=not pending,not pending
        addon.DialogueTextEvent("QUEST_PROGRESS")
        assert(addon.DialogueText(65,function()return false end)==nil)
        f.shown,f.progress=true,true
        local dto=assert(addon.DialogueText(65,function()return true end));assert(dto.text==f.progressText)
    end
    setup();local valid=true;GetProgressText=function()valid=false;return f.progressText end;open("progress")
    assert(addon.DialogueText(65,function()return valid end)==nil)
    assert(addon.DialogueText(65).text==f.progressText)
end)
check("Pending visibility does not preserve terminal native identity loss",function()
    for _,mode in ipairs({"character","id","locale","getter"})do
        setup();f.shown,f.progress=false,false;addon.DialogueTextEvent("QUEST_PROGRESS")
        local char,getter,locale=addon.char,GetProgressText,f.locale
        if mode=="character"then addon.char={}elseif mode=="id"then f.id=66 elseif mode=="locale"then f.locale="ruRU"else GetProgressText=function()return"Other"end end
        assert(addon.DialogueText(65)==nil)
        addon.char,GetProgressText,f.locale,f.id=char,getter,locale,65;f.shown,f.progress=true,true
        assert(addon.DialogueText(65)==nil,mode)
    end
end)
issecretvalue=nil
print("Dialogue stage text modeled checks passed: "..total.." (native client unverified)")
