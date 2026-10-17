local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
local queue, reads, notices, ready, owner, cache, shown, valid, locale
local function reset()
    queue, reads, notices, ready, shown, valid, locale = {}, {}, 0, {}, true, true, "enUS"
    issecretvalue = function() return false end
    GetLocale = function() return locale end
    addon.char, addon.db, addon.quests, addon.Language = {}, { locale = "auto" }, { [1] = {}, [2] = {}, [3] = {} }, nil
    addon.CachedQuestRewards = function(id)
        reads[id] = (reads[id] or 0) + 1
        if ready[id] then return { source = "cache", items = {}, choices = {} } end
    end
    C_Timer = { After = function(delay, fn) queue[#queue + 1] = { delay = delay, fn = fn } end }
    owner = { frame = { IsShown = function() return shown end } }
    assert(loadfile("UI/RewardCache.lua"))("DungeonPro", addon); cache = addon.RewardCache
end
local function watch(ids, callback, predicate)
    cache.Watch(owner, ids or { 1 }, predicate or function() return valid end,
        callback or function() notices = notices + 1 end)
end
local function tick()
    local item = table.remove(queue, 1); assert(item, "missing timer"); item.fn(); return item.delay
end
local function test(name, fn)
    reset(); local ok, err = pcall(fn); assert(ok, name .. ": " .. tostring(err))
    total = total + 1; print("PASS " .. name)
end
test("Three deferred cache reads exhaust without requests or endless repaint", function()
    watch(); assert(#queue == 1 and reads[1] == nil)
    assert(tick() == .2); watch(); assert(#queue == 1)
    assert(tick() == .6); watch(); assert(tick() == 1.2)
    for _ = 1, 20 do watch() end
    assert(reads[1] == 3 and #queue == 0 and notices == 0)
end)
test("Ready IDs coalesce one notification and empty valid rewards stop retries", function()
    watch({1, 2, 1}); ready[1], ready[2] = true, true; tick()
    assert(notices == 1 and reads[1] == 1 and reads[2] == 1 and #queue == 0)
    watch({1, 2}); assert(#queue == 0)
end)
test("Latest repaint callback and membership replace pending view", function()
    watch({1}); watch({2}, function() notices = notices + 10 end)
    ready[2] = true; assert(#queue == 1); tick()
    assert(reads[1] == nil and reads[2] == 1 and notices == 10)
end)
test("Membership removal and return preserve per-ID attempt budgets", function()
    watch({1}); tick(); watch({2}); tick(); watch({1}); tick(); tick()
    assert(reads[1] == 3 and reads[2] == 1 and #queue == 0)
end)
test("Empty membership cancels pending work without resetting budget", function()
    watch(); tick(); watch({}); tick(); assert(reads[1] == 1 and #queue == 0)
    watch(); tick(); tick(); assert(reads[1] == 3 and #queue == 0)
end)
test("Hidden stale and replaced frames cannot read or notify", function()
    for _, mutate in ipairs({function() shown = false end, function() valid = false end,
        function() owner.frame = { IsShown = function() return true end } end}) do
        reset(); watch(); mutate(); tick(); assert(reads[1] == nil and notices == 0 and #queue == 0)
    end
end)
test("Character db provider locale checker and definition drift invalidate old work", function()
    for _, mutate in ipairs({function() addon.char = {} end, function() addon.db = {} end,
        function() addon.CachedQuestRewards = function() error("stale") end end,
        function() locale = "ruRU" end, function() issecretvalue = function() return false end end,
        function() addon.quests[1] = {} end, function() addon.quests = {} end,
        function() addon.db.locale = "ruRU" end}) do
        reset(); watch(); mutate(); tick(); assert(reads[1] == nil and #queue == 0)
    end
end)
test("New semantic context reuses the sole pending timer and latest binding", function()
    watch(); addon.char = {}; watch(); ready[1] = true
    assert(#queue == 1); tick(); assert(reads[1] == 1 and notices == 1)
end)
test("Definition replacement gets its own fresh bounded budget", function()
    watch(); tick(); tick(); tick(); addon.quests[1] = {}; watch(); tick(); tick(); tick()
    assert(reads[1] == 6 and #queue == 0)
end)
test("Provider reentry cannot notify stale view and retains newest membership", function()
    local provider = addon.CachedQuestRewards; local once
    addon.CachedQuestRewards = function(id)
        if not once then once = true; watch({2}, function() notices = notices + 10 end) end
        return provider(id)
    end
    watch(); ready[1], ready[2] = true, true; tick(); assert(notices == 0)
    tick(); assert(notices == 10 and reads[2] == 1 and #queue == 0)
end)
test("Notify repaint does not restart completed or exhausted budgets", function()
    watch({1,2}, function() notices = notices + 1; watch({1,2}) end)
    ready[1] = true; tick(); tick(); tick(); assert(reads[1] == 1 and reads[2] == 3 and #queue == 0)
end)
test("Missing throwing rejected and immediate schedulers terminate safely", function()
    for _, timer in ipairs({ {}, {After=function() error("unsupported") end},
        {After=function() return false end}, {After=function(_, fn) fn() end} }) do
        reset(); C_Timer = timer; watch(); assert(reads[1] == nil and #queue == 0)
    end
end)
test("Absent provider and unknown IDs never schedule work", function()
    watch({0, -1, 1.5, 999}); assert(#queue == 0)
    addon.CachedQuestRewards = nil; watch(); assert(#queue == 0)
end)
test("Rejected scheduler reentry cannot exhaust a newer semantic binding", function()
    C_Timer.After = function()
        addon.char = {}; watch({2}); return false
    end
    watch({1}); assert(#queue == 0)
    C_Timer.After = function(delay, fn) queue[#queue + 1] = {delay=delay,fn=fn} end
    ready[2] = true; watch({2}); tick(); assert(reads[2] == 1 and notices == 1)
end)
test("Language preview selection changes invalidate old work", function()
    local preview = "enUS"; addon.Language = {GetSelection=function() return preview end}
    watch(); preview = "zhCN"; tick(); assert(reads[1] == nil and #queue == 0)
end)
test("UI language previews commits and language objects preserve exhausted native cache budgets", function()
    local preview = "enUS"
    addon.Language = {GetSelection=function() return preview end}
    watch(); tick(); tick(); tick()
    for _, selection in ipairs({"ruRU", "enUS", "zhCN", "koKR", "enUS"}) do
        preview, addon.db.locale = selection, selection
        addon.Language = {GetSelection=function() return preview end}
        watch(); while #queue > 0 do tick() end
    end
    assert(reads[1] == 3 and notices == 0, "UI locale changes restarted cache budget")
    locale = "ruRU"; watch(); tick(); tick(); tick()
    assert(reads[1] == 6, "native locale must establish a new cache budget")
end)
test("Foreign and malformed DTOs remain cold and bounded", function()
    addon.CachedQuestRewards = function() return {source="dialogue",items={},choices={}} end
    watch(); tick(); tick(); tick(); assert(notices == 0 and #queue == 0)
end)
print("Reward cache: " .. total .. " checks passed")
