local addon, total, timers, names, cached, requests, notices, lastID
local secret = {}
local function reset()
    addon, timers, names, cached, requests, notices = {}, {}, {}, false, 0, 0
    assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
    assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
    addon.listeners[1] = function() notices = notices + 1 end
    issecretvalue = function(value) return value == secret end
    GetLocale = function() return "enUS" end
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
    fire(2); assert(requests == 1 and notices == 0)
    fire(.1); assert(requests == 1 and notices == 1)
    addon.ItemName(7083); assert(requests == 2)
    fire(10); assert(requests == 2 and notices == 1)
    addon.ItemDataResult(7083, false); fire(2); fire(.1)
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
    fire(2); fire(.1); assert(requests == 1 and notices == 1)
    addon.ItemName(7083); assert(requests == 2)
    stale(); addon.ItemName(7083)
    assert(requests == 2 and notices == 1)
    fire(10); fire(2); fire(.1); addon.ItemName(7083)
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
    fire(2); fire(.1); addon.ItemName(7083); assert(requests == 2)
end)
check("Native request exceptions and missing or broken timers cannot loop or remain pending forever", function()
    C_Item.RequestLoadItemDataByID = function() requests = requests + 1; error("load failed") end
    addon.ItemName(7083); addon.ItemName(7083); assert(requests == 1)
    fire(2); fire(.1); addon.ItemName(7083); assert(requests == 2)
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
    fire(2); fire(.1); assert(notices == 1)
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
    addon.ItemDataResult(7083, false); fire(2); fire(.1)
    addon.ItemName(7083); addon.ItemName(272448)
    assert(requests == 3)
    names[272448] = "Other Gem"; assert(addon.ItemName(272448) == "Other Gem")
end)
check("Malformed native item libraries fail quietly without requests", function()
    for _, value in ipairs({ false, 3, "unavailable", secret }) do
        C_Item = value
        local ok, result = pcall(addon.ItemName, 7083)
        assert(ok and result == nil and requests == 0)
    end
end)
check("Native item names cannot escape a replaced namespace getter or locale", function()
    for mode = 1, 5 do
        reset()
        C_Item.GetItemNameByID = function()
            if mode == 1 then C_Item = {}
            elseif mode == 2 then C_Item.GetItemNameByID = function() return "New name" end
            elseif mode == 3 then GetLocale = function() return "deDE" end
            elseif mode == 4 then issecretvalue = function() return false end
            else C_Item.RequestLoadItemDataByID = function() error("replaced request forbidden") end end
            return "Old name"
        end
        assert(addon.ItemName(7083) == nil and requests == 0 and #timers == 0)
    end
end)
check("Cached status cannot authorize a stale native item request after scope changes", function()
    for mode = 1, 3 do
        reset()
        local staleRequests = 0
        C_Item.RequestLoadItemDataByID = function() staleRequests = staleRequests + 1 end
        C_Item.IsItemDataCachedByID = function()
            if mode == 1 then C_Item = {}
            elseif mode == 2 then GetLocale = function() return "ruRU" end
            else C_Item.RequestLoadItemDataByID = function() error("replacement request forbidden") end end
            return false
        end
        assert(addon.ItemName(7083) == nil and staleRequests == 0 and #timers == 0)
    end
end)
check("A reentrant cache read keeps the inner pending request and its single watchdog", function()
    local nested = false
    C_Item.IsItemDataCachedByID = function(id)
        if not nested then nested = true; assert(addon.ItemName(id) == nil) end
        return false
    end
    assert(addon.ItemName(7083) == nil and requests == 1)
    assert(#timers == 1 and timers[1].delay == 10)
    for _ = 1, 5 do assert(addon.ItemName(7083) == nil) end
    assert(requests == 1 and #timers == 1)
    fire(10); fire(2); fire(.1)
    assert(notices == 1)
    assert(addon.ItemName(7083) == nil and requests == 2 and #timers == 1)
end)
check("Item icon reads the exact numeric native identity without name hydration or locale requirements", function()
    local calls = 0
    C_Item.GetItemIconByID = function(id, ...)
        assert(id == 7083 and select("#", ...) == 0); calls = calls + 1; return 134400
    end
    GetLocale = nil
    assert(addon.ItemIcon(7083) == 134400 and calls == 1)
    assert(requests == 0 and notices == 0 and #timers == 0 and addon.db == nil and addon.char == nil)
end)
check("Item icons reject malformed restricted and out-of-range IDs before native reads", function()
    local calls = 0
    C_Item.GetItemIconByID = function() calls = calls + 1; return 134400 end
    for _, id in ipairs({ false, 0, -1, 1.5, math.huge, 0 / 0, "7083", secret, 4294967296 }) do
        assert(addon.ItemIcon(id) == nil)
    end
    assert(addon.ItemIcon(nil) == nil and calls == 0 and requests == 0)
    assert(addon.ItemIcon(4294967295) == 134400 and calls == 1)
end)
check("Item icons preserve cold missing and invalid native results as absence", function()
    for _, value in ipairs({ false, 0, -1, 1.5, math.huge, 0 / 0, "134400", secret, 4294967296 }) do
        C_Item.GetItemIconByID = function() return value end
        assert(addon.ItemIcon(7083) == nil)
    end
    C_Item.GetItemIconByID = function() return nil end
    assert(addon.ItemIcon(7083) == nil)
    C_Item.GetItemIconByID = function() error("cold icon") end
    assert(addon.ItemIcon(7083) == nil)
    C_Item.GetItemIconByID = nil; assert(addon.ItemIcon(7083) == nil)
    C_Item = nil; assert(addon.ItemIcon(7083) == nil)
    assert(requests == 0 and notices == 0 and #timers == 0)
end)
check("Native icon getter namespace and checker replacement discard an old result", function()
    for mode = 1, 3 do
        reset()
        C_Item.GetItemIconByID = function()
            if mode == 1 then C_Item = { GetItemIconByID = function() return 123 end }
            elseif mode == 2 then C_Item.GetItemIconByID = function() return 123 end
            else issecretvalue = function() return false end end
            return 134400
        end
        assert(addon.ItemIcon(7083) == nil and requests == 0 and #timers == 0)
    end
end)
check("Icon result sanitization cannot authorize a replaced native getter", function()
    C_Item.GetItemIconByID = function() return 134400 end
    issecretvalue = function(value)
        if value == 134400 then C_Item.GetItemIconByID = function() return 123 end end
        return false
    end
    assert(addon.ItemIcon(7083) == nil and requests == 0 and #timers == 0)
end)
check("Final icon getter sanitization cannot replace the namespace or getter after its earlier check", function()
    for mode = 1, 2 do
        reset()
        local read = false
        local getter = function() read = true; return 134400 end
        C_Item.GetItemIconByID = getter
        issecretvalue = function(value)
            if read and value == getter then
                if mode == 1 then C_Item = { GetItemIconByID = function() return 123 end }
                else C_Item.GetItemIconByID = function() return 123 end end
            end
            return false
        end
        assert(addon.ItemIcon(7083) == nil and requests == 0 and #timers == 0)
    end
end)
check("An unreadable icon restriction checker fails closed without native calls", function()
    local calls = 0
    C_Item.GetItemIconByID = function() calls = calls + 1; return 134400 end
    issecretvalue = function() error("restricted") end
    assert(addon.ItemIcon(7083) == nil and calls == 0 and requests == 0)
end)
issecretvalue = nil
print("Item display adapters modeled checks passed: " .. total .. " (native client unverified)")
