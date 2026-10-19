local total = 0
local function fixture()
    local addon, frame, queue, shown, notify, calls = {}, nil, {}, false, 0, {}
    assert(loadfile("Core/Namespace.lua"))("DungeonPro",addon)
    CreateFrame=function()
        frame={events={},scripts={}}
        function frame:RegisterEvent(event)self.events[event]=true end
        function frame:SetScript(event,fn)self.scripts[event]=fn end
        return frame
    end
    GetBuildInfo=function()return"1.60.1","70450","",16001 end
    WOW_PROJECT_ID=18;SlashCmdList={};issecretvalue=nil
    C_Timer={After=function(_,fn)queue[#queue+1]=fn end}
    addon.RestoreDB=function()return true end
    addon.UI={Toggle=function()end}
    addon.Minimap={Initialize=function()calls.minimap=(calls.minimap or 0)+1 end}
    for _,key in ipairs({"DialogueTextEvent","DialogueRewardEvent","OfferEvent","QuestDataResult","ItemDataResult","CaptureQuestText"})do
        local name=key;addon[name]=function(...)calls[name]=calls[name]or{};calls[name][#calls[name]+1]={...}end
    end
    addon.Navigation={QuestChanged=function(id)calls.navigation=id end}
    addon.Notify=function()notify=notify+1 end
    assert(loadfile("Core/Diagnostics.lua"))("DungeonPro",addon)
    assert(loadfile("Core/Events.lua"))("DungeonPro",addon)
    local f={addon=addon,frame=frame,queue=queue,calls=calls}
    function f:event(...)frame.scripts.OnEvent(frame,...)end
    function f:show(value)
        shown=value
        addon.UI.frame=addon.UI.frame or{IsShown=function()return shown end}
    end
    function f:notifications()return notify end
    function f:tick()local fn=table.remove(queue,1);assert(fn);fn()end
    f:event("ADDON_LOADED","DungeonPro")
    return f
end
local function test(name,fn)
    local ok,err=pcall(fn);assert(ok,name..": "..tostring(err));total=total+1;print("PASS "..name)
end
test("Login and hidden quest bursts process state without scheduling a render",function()
    local f=fixture()
    for _=1,1000 do f:event("QUEST_LOG_UPDATE")end
    assert(#f.queue==0 and f:notifications()==0,"unopened planner scheduled redundant rendering")
    assert(#f.calls.OfferEvent==1000 and #f.calls.DialogueRewardEvent==1000)
    f:show(false);f:event("PLAYER_ENTERING_WORLD");f:event("QUEST_ACCEPTED",65)
    f:event("QUEST_DATA_LOAD_RESULT",65,true);f:event("ITEM_DATA_LOAD_RESULT",7001,true);f:event("QUEST_DETAIL")
    assert(#f.queue==0 and f:notifications()==0)
    assert(f.calls.minimap==2 and f.calls.navigation==65 and f.calls.QuestDataResult[1][1]==65 and
        f.calls.ItemDataResult[1][1]==7001 and #f.calls.CaptureQuestText==1)
end)
test("Hidden arrival followed by first open adds no second event render",function()
    local f=fixture();f:event("QUEST_LOG_UPDATE");f:show(true)
    local initialShowRenders=1
    while #f.queue>0 do f:tick()end
    assert(initialShowRenders+f:notifications()==1,"pending login event duplicated first-open render")
end)
test("Visible event bursts coalesce and asynchronous state changes retain a later render",function()
    local f=fixture();f:show(true)
    for _=1,1000 do f:event("QUEST_LOG_UPDATE")end
    assert(#f.queue==1 and f:notifications()==0)
    local notify=f.addon.Notify
    f.addon.Notify=function()notify();if f:notifications()==1 then f:event("QUEST_LOG_UPDATE")end end
    f:tick();assert(#f.queue==1 and f:notifications()==1);f:tick();assert(f:notifications()==2)
end)
test("Closing before dispatch drops painting but still processes the event data",function()
    local f=fixture();f:show(true);f:event("QUEST_DATA_LOAD_RESULT",65,true)
    assert(#f.queue==1 and #f.calls.QuestDataResult==1)
    f:show(false);f:tick();assert(f:notifications()==0)
    f:show(true);f:event("QUEST_LOG_UPDATE");f:tick();assert(f:notifications()==1)
end)
test("Unknown visibility keeps conservative notifications instead of losing updates",function()
    local f=fixture();f:show(true);f.addon.UI.frame.IsShown=function()error("unreadable")end
    f:event("QUEST_LOG_UPDATE");assert(#f.queue==1);f:tick();assert(f:notifications()==1)
end)
test("Broken and inline timer fallbacks remain bounded with visible UI",function()
    for _,timer in ipairs({{}, {After=function()error("missing")end}, {After=function(_,fn)fn()end}})do
        local f=fixture();f:show(true);C_Timer=timer
        local notify=f.addon.Notify
        f.addon.Notify=function()notify();f:event("QUEST_LOG_UPDATE")end
        f:event("QUEST_LOG_UPDATE");assert(f:notifications()==1)
        f:event("QUEST_LOG_UPDATE");assert(f:notifications()==2)
    end
end)
print("Startup events: "..total.." checks passed")
