-- Cache/dialogue events reuse validated catalogue state; character changes never do.
local total = 0
local function check(name, callback)
    callback(); total = total + 1; print("PASS " .. name)
end
local function model(timerMode, buildMode)
    local frame = { scripts = {} }
    function frame:RegisterEvent() end
    function frame:SetScript(key, value) self.scripts[key] = value end
    CreateFrame = function() return frame end
    if buildMode == "missing" then GetBuildInfo = nil
    elseif buildMode == "throwing" then GetBuildInfo = function() error("build unavailable") end
    else GetBuildInfo = function() return "1.60.1", "70450", "", 16001 end end
    WOW_PROJECT_ID, SlashCmdList, issecretvalue = 18, {}, nil
    local addon, queue, reasons = {}, {}, {}
    assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
    local shown, invalidations = true, 0
    addon.UI = { frame = { IsShown = function() return shown end } }
    addon.RestoreDB = function() return true end
    addon.InvalidateContext = function() invalidations = invalidations + 1; return true end
    addon.L = function(key) return key end
    for _, key in ipairs({ "OfferEvent", "QuestDataResult", "ItemDataResult", "CaptureQuestText" }) do addon[key] = function() end end
    addon.listeners[1] = function(reason) reasons[#reasons + 1] = reason or "full" end
    C_Timer = { After = function(_, callback)
        if timerMode == "inline" then callback()
        elseif timerMode == "throw" then error("timer unavailable")
        else queue[#queue + 1] = callback end
    end }
    assert(loadfile("Core/Diagnostics.lua"))("DungeonPro", addon)
    assert(loadfile("Core/Events.lua"))("DungeonPro", addon)
    local function event(name) frame.scripts.OnEvent(frame, name, 166, true) end
    frame.scripts.OnEvent(frame, "ADDON_LOADED", "DungeonPro")
    return { addon = addon, reasons = reasons, queue = queue, event = event,
        hide = function() shown = false end, show = function() shown = true end,
        invalidations = function() return invalidations end,
        drain = function() while #queue > 0 do table.remove(queue, 1)() end end }
end
check("Notify forwards data reasons and preserves ordinary full notifications", function()
    local m = model()
    m.addon.Notify("data"); m.addon.Notify()
    assert(m.reasons[1] == "data" and m.reasons[2] == "full")
end)
check("Throwing listeners cannot abort later listeners while the first error still surfaces", function()
    local m = model()
    local later = 0
    m.addon.listeners[2] = function() error("first listener unavailable") end
    m.addon.listeners[3] = function() error("second listener unavailable") end
    m.addon.listeners[4] = function(reason) later = later + 1; assert(reason == nil) end
    local ok, message = pcall(m.addon.Notify)
    assert(not ok and later == 1 and #m.reasons == 1 and m.reasons[1] == "full")
    assert(tostring(message):find("first listener unavailable", 1, true))
end)
check("Mutating listeners cannot skip or extend the in-flight broadcast", function()
    local m = model()
    local ran = { remover = 0, mid = 0, victim = 0, appended = 0 }
    m.addon.listeners[2] = function()
        ran.remover = ran.remover + 1
        m.addon.listeners[4] = nil
        m.addon.listeners[5] = function() ran.appended = ran.appended + 1 end
    end
    m.addon.listeners[3] = function() ran.mid = ran.mid + 1 end
    m.addon.listeners[4] = function() ran.victim = ran.victim + 1 end
    m.addon.Notify("data")
    assert(ran.remover == 1 and ran.mid == 1 and ran.victim == 1, "all originally-registered listeners must run exactly once")
    assert(ran.appended == 0, "appended listener must not receive the in-flight reason")
    assert(#m.reasons == 1 and m.reasons[1] == "data")
end)
check("Coalesced cache and dialogue events stay data-only", function()
    local m = model()
    for _, event in ipairs({ "QUEST_DATA_LOAD_RESULT", "ITEM_DATA_LOAD_RESULT", "GOSSIP_SHOW", "QUEST_DETAIL", "QUEST_COMPLETE" }) do m.event(event) end
    assert(#m.queue == 1); m.drain()
    assert(#m.reasons == 1 and m.reasons[1] == "data" and m.invalidations() == 0)
end)
check("Full context refresh wins in either mixed event order", function()
    for _, first in ipairs({ "QUEST_DATA_LOAD_RESULT", "QUEST_LOG_UPDATE" }) do
        local m = model()
        m.event(first); m.event(first == "QUEST_LOG_UPDATE" and "ITEM_DATA_LOAD_RESULT" or "QUEST_LOG_UPDATE")
        assert(#m.queue == 1); m.drain()
        assert(#m.reasons == 1 and m.reasons[1] == "full" and m.invalidations() == 1)
    end
end)
check("Hidden and inline event handling retain suppression without recursive paints", function()
    local hidden = model()
    hidden.event("ITEM_DATA_LOAD_RESULT"); hidden.hide(); hidden.drain(); assert(#hidden.reasons == 0)
    hidden.event("QUEST_LOG_UPDATE"); assert(#hidden.queue == 0 and hidden.invalidations() == 1)
    for _, mode in ipairs({ "inline", "throw" }) do
        local m = model(mode)
        m.addon.listeners[2] = function() m.event("QUEST_DATA_LOAD_RESULT") end
        m.event("ITEM_DATA_LOAD_RESULT")
        assert(#m.reasons == 1 and m.reasons[1] == "data")
    end
end)
check("Actual TOC data events retain catalogue status while quest changes rebuild it", function()
    local f = assert(loadfile("tests/client_ui.lua"))("fixture")
    local addon, ui, queue = f.addon, f.addon.UI, {}
    issecretvalue = function() return false end
    C_Timer = { After = function(delay, callback) if delay == .1 then queue[#queue + 1] = callback end end }
    local function drain()
        local count = 0
        while #queue > 0 do count = count + 1; assert(count < 100, "data notifications must settle"); table.remove(queue, 1)() end
    end
    local function event(name) f.eventFrame.scripts.OnEvent(f.eventFrame, name, 166, true) end
    local getter, calls = addon.DungeonStatus.Get, 0
    addon.DungeonStatus.Get = function(...) calls = calls + 1; return getter(...) end
    f.eventFrame.scripts.OnEvent(f.eventFrame, "ADDON_LOADED", "DungeonPro")
    ui:Toggle(); drain()
    for _, dungeon in ipairs(addon.dungeons) do if dungeon.key == "dm" then ui.dungeon = dungeon end end
    ui:Refresh(); drain()
    calls = 0
    event("QUEST_DATA_LOAD_RESULT"); event("ITEM_DATA_LOAD_RESULT"); drain()
    assert(calls == 0, "data-only notifications must reuse the current catalogue")
    event("QUEST_LOG_UPDATE"); drain()
    assert(calls == #addon.dungeons, "quest-state invalidation must rebuild every catalogue status")
    calls = 0; addon.Notify(); drain()
    assert(calls == #addon.dungeons, "ordinary Notify remains a full refresh")
end)
check("Missing or throwing GetBuildInfo fails closed without throwing", function()
    for _, mode in ipairs({ "missing", "throwing" }) do
        local m = model("queued", mode)
        m.event("QUEST_LOG_UPDATE"); m.drain()
        assert(#m.reasons == 0, "uninitialized client must not notify for build mode " .. mode)
    end
end)
check("Truthy non-table C_Timer fails closed to inline refresh without throwing", function()
    for _, bad in ipairs({ true, 1, "timer" }) do
        local m = model()
        C_Timer = bad
        local ok, err = pcall(m.event, "QUEST_LOG_UPDATE")
        assert(ok, "non-table C_Timer threw: " .. tostring(err))
        assert(#m.queue == 0, "non-table C_Timer must not queue a delayed refresh")
        m.drain()
        assert(#m.reasons == 1 and m.reasons[1] == "full", "non-table C_Timer lost its inline refresh")
    end
end)
print("Event refresh checks passed: " .. total)
