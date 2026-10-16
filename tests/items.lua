local addon, total, timers, names, cached, requests, notices, lastID
local secret = {}
local function reset()
    addon, timers, names, cached, requests, notices = {}, {}, {}, false, 0, 0
    assert(loadfile("Core/Namespace.lua"))("DungeonPrep", addon)
    assert(loadfile("Core/Client.lua"))("DungeonPrep", addon)
    addon.listeners[1] = function() notices = notices + 1 end
    issecretvalue = function(value) return value == secret end
    C_Item = {
        GetItemNameByID = function(id) lastID = id; return names[id] end,
        IsItemDataCachedByID = function(id) lastID = id; return cached end,
        RequestLoadItemDataByID = function(id) requests = requests + 1; lastID = id end,
    }
    C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay = delay, callback = callback } end }
end
local function fire(delay)
    for i, timer in ipairs(timers) do
        if timer.delay == delay then table.remove(timers, i); timer.callback(); return end
    end
    error("No timer for " .. delay)
end
local function check(label, fn)
    reset()
    local ok, err = pcall(fn)
    if not ok then error(label .. ": " .. tostring(err), 0) end
    total = (total or 0) + 1; print("PASS " .. label)
end
check("Readable native item name needs no cache API and no selection or request writes", function()
    names[7083] = "Purified Kor Gem"
    C_Item.IsItemDataCachedByID = nil
    assert(addon.ItemName(7083) == "Purified Kor Gem" and requests == 0 and lastID == 7083)
    assert(#timers == 0 and notices == 0)
end)
check("Missing APIs return nil rather than fabricated names", function()
    C_Item = nil; assert(addon.ItemName(7083) == nil)
    C_Item = {}; assert(addon.ItemName(7083) == nil)
end)
check("Only clean positive integer IDs reach any native item API", function()
    local calls = 0
    C_Item.GetItemNameByID = function() calls = calls + 1 end
    for _, id in ipairs({ 0, -1, 1.5, "7083", math.huge, 0 / 0, secret }) do
        assert(addon.ItemName(id) == nil)
        addon.ItemDataResult(id, false)
    end
    assert(addon.ItemName(nil) == nil and calls == 0 and requests == 0)
end)
check("Unknown cached status does not authorize data loading", function()
    for _, value in ipairs({ secret, 1, "false" }) do
        cached = value; assert(addon.ItemName(7083) == nil and requests == 0)
    end
    cached = nil; assert(addon.ItemName(7083) == nil and requests == 0)
    C_Item.IsItemDataCachedByID = function() error("unknown") end
    assert(addon.ItemName(7083) == nil and requests == 0)
end)
check("Known cached item with missing restricted or oversized name stays unknown", function()
    cached = true
    for _, value in ipairs({ "", false, secret, string.rep("N", 1025) }) do
        names[7083] = value; assert(addon.ItemName(7083) == nil and requests == 0)
    end
    C_Item.GetItemNameByID = function() error("not ready") end
    assert(addon.ItemName(7083) == nil and requests == 0)
end)
check("Missing name with uncached data requests once and coalesces pending reads", function()
    for _ = 1, 10 do assert(addon.ItemName(7083) == nil) end
    assert(requests == 1 and lastID == 7083 and #timers == 1 and timers[1].delay == 10)
    assert(notices == 0)
end)
check("Failed loads retry after two seconds with a strict three-attempt bound", function()
    addon.ItemName(7083); addon.ItemDataResult(7083, false)
    addon.ItemName(7083); assert(requests == 1)
    fire(2); assert(requests == 1 and notices == 1)
    addon.ItemName(7083); assert(requests == 2)
    fire(10); assert(requests == 2 and notices == 1)
    addon.ItemDataResult(7083, false); fire(2)
    assert(notices == 2 and requests == 2)
    addon.ItemName(7083); assert(requests == 3)
    addon.ItemDataResult(7083, false)
    for _ = 1, 20 do assert(addon.ItemName(7083) == nil) end
    assert(requests == 3 and notices == 2)
end)
check("Silent loads leave pending through a watchdog and stale watchdogs ignore newer attempts", function()
    addon.ItemName(7083)
    local stale = timers[1].callback
    fire(10); assert(requests == 1 and notices == 0)
    fire(2); assert(requests == 1 and notices == 1)
    addon.ItemName(7083); assert(requests == 2)
    stale(); addon.ItemName(7083)
    assert(requests == 2 and notices == 1)
    fire(10); fire(2); addon.ItemName(7083)
    assert(requests == 3)
    fire(10)
    for _ = 1, 5 do addon.ItemName(7083) end
    assert(requests == 3)
end)
check("Synchronous native failure callbacks do not overwrite retry state", function()
    C_Item.RequestLoadItemDataByID = function(id)
        requests = requests + 1; addon.ItemDataResult(id, false)
    end
    addon.ItemName(7083); assert(#timers == 1 and timers[1].delay == 2)
    addon.ItemName(7083); assert(requests == 1)
    fire(2); addon.ItemName(7083); assert(requests == 2)
end)
check("Native request exceptions and missing or broken timers cannot loop or remain pending forever", function()
    C_Item.RequestLoadItemDataByID = function() requests = requests + 1; error("load failed") end
    addon.ItemName(7083); addon.ItemName(7083); assert(requests == 1)
    fire(2); addon.ItemName(7083); assert(requests == 2)
    reset(); C_Timer = nil
    for _ = 1, 10 do addon.ItemName(7083) end
    assert(requests == 3 and notices == 0)
    reset(); C_Timer.After = function() error("timer failed") end
    for _ = 1, 10 do addon.ItemName(7083) end
    assert(requests == 3 and notices == 0)
end)
check("Successful events finish requests without scheduling retries or notifying directly", function()
    addon.ItemName(7083)
    addon.ItemDataResult(7083, true)
    fire(10)
    for _ = 1, 5 do assert(addon.ItemName(7083) == nil) end
    assert(requests == 1 and notices == 0 and #timers == 0)
    names[7083] = "Loaded Gem"; assert(addon.ItemName(7083) == "Loaded Gem")
end)
check("Unowned restricted and duplicate result events do not cancel an owned pending request", function()
    addon.ItemName(7083)
    addon.ItemDataResult(999, false); addon.ItemDataResult(7083, secret)
    addon.ItemDataResult(7083, nil)
    addon.ItemName(7083); assert(requests == 1 and #timers == 1)
    addon.ItemDataResult(7083, false); addon.ItemDataResult(7083, false)
    assert(#timers == 2)
    fire(2); assert(notices == 1)
end)
check("Names read afresh across locales and readable cache invalidates stale failure timers", function()
    addon.ItemName(7083)
    local stale = timers[1].callback
    names[7083] = "Очищенный самоцвет"
    GetLocale = function() return "ruRU" end
    assert(addon.ItemName(7083) == "Очищенный самоцвет")
    stale(); assert(#timers == 1 and notices == 0)
    names[7083] = "Purified Gem"; assert(addon.ItemName(7083) == "Purified Gem")
    assert(requests == 1)
end)
check("Different item IDs maintain independent coalesced request state", function()
    addon.ItemName(7083); addon.ItemName(272448)
    assert(requests == 2)
    addon.ItemDataResult(7083, false); fire(2)
    addon.ItemName(7083); addon.ItemName(272448)
    assert(requests == 3)
    names[272448] = "Other Gem"; assert(addon.ItemName(272448) == "Other Gem")
end)
issecretvalue = nil
print("Item name adapter modeled checks passed: " .. total .. " (native client unverified)")
