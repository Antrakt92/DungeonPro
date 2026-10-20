-- Starter and supplied roles remain separate while a single item has one bag-count display.
local total = 0
local function fixture(id, count, ready, mutate)
    local f = assert(loadfile("tests/client_ui.lua"))("fixture")
    local a, u = f.addon, f.addon.UI
    issecretvalue = function() return false end
    GetLocale = function() return "enUS" end
    UnitLevel = function() return 60 end
    UnitClass = function() return "Mage", "MAGE", 8 end
    UnitFactionGroup = function() return "Alliance" end
    C_QuestLog.IsOnQuest = function(other) return ready and other == id or false end
    C_QuestLog.ReadyForTurnIn = function(other) return ready and other == id or false end
    C_Timer = { After = function() end }
    local itemID = id == 6981 and 10441 or 281030
    local name = id == 6981 and "Glowing Shard" or "Treaty of Understanding"
    C_Item = {
        GetItemCount = function() return count end,
        GetItemNameByID = function(other) if other == itemID then return name end end,
        GetItemIconByID = function() return 134400 end,
    }
    local routes = 0
    C_Map.SetUserWaypoint = function() routes = routes + 1; return true end
    f.eventFrame.scripts.OnEvent(f.eventFrame, "ADDON_LOADED", "DungeonPro")
    u:Toggle(); a.db.locale = "enUS"
    local q, dungeon = a.quests[id]
    for _, d in ipairs(a.dungeons) do for _, target in ipairs(d.quests) do if target == id then dungeon = d end end end
    assert(q and dungeon and q.start.itemID == itemID and q.providedItems[1].itemID == itemID)
    if mutate then mutate(q) end
    u.dungeon, u.quest = dungeon, id; u:Refresh()
    return a, u, q, itemID, name, function() return routes end
end
local function fields(u)
    local result = {}; for _, f in ipairs(u.details) do if f:IsShown() then result[#result + 1] = f end end; return result
end
local function occurrences(u, value)
    local n = 0; for _, f in ipairs(fields(u)) do if f:GetText():find(value, 1, true) then n = n + 1 end end; return n
end
local function exact(u, value)
    for _, f in ipairs(fields(u)) do if f:GetText() == value then return f end end
end
local function role(u, key, itemID)
    for _, b in ipairs(u.objectiveButtons) do
        if b:IsShown() and b.objectiveBinding and b.objectiveBinding.role == key and b.objectiveBinding.id == itemID then return b end
    end
end
for _, id in ipairs({ 6981, 98423 }) do for _, ready in ipairs({ false, true }) do
    for _, mode in ipairs({ "zero", "positive", "unknown" }) do
        local count = mode == "zero" and 0 or mode == "positive" and 4 or nil
        local a, u, q, itemID, name, routes = fixture(id, count, ready)
        local provided, start = q.providedItems, q.start
        assert(exact(u, a.L("PROVIDED_ITEMS")) and role(u, "starter", itemID) and role(u, "provided", itemID))
        assert(occurrences(u, name .. " ×?") == 1 and q.providedItems[1].quantity == nil, "unknown supplied quantity cannot become one")
        if count ~= nil then
            local value = a.L("ITEM_CARRIED", count)
            assert(occurrences(u, value) == 1, "one physical item must not repeat its carried count in starter and supplied sections")
            assert(not exact(u, value), "the count stays on the successfully rendered supplied row, without a redundant standalone caption")
        else assert(occurrences(u, "Carried:") == 0, "unknown bag count is not zero") end
        assert(u:SetDetailTab("sources"))
        assert(not exact(u, a.L("PROVIDED_ITEMS")) and not role(u, "provided", itemID))
        if count ~= nil then assert(exact(u, a.L("ITEM_CARRIED", count)), "Sources retains the standalone starter count when supplied rows are absent")
        else assert(occurrences(u, "Carried:") == 0) end
        assert(q.start == start and q.providedItems == provided and routes() == 0)
        total = total + 1
    end
end end
-- A same-ID candidate alone does not authorize suppression: malformed/hidden entries do not render.
for _, invalid in ipairs({ "absent", "bad-name", "zero-quantity", "false-quantity", "wrong-type" }) do
    local a, u = fixture(6981, 0, false, function(q)
        if invalid == "absent" then q.providedItems = nil
        elseif invalid == "wrong-type" then q.providedItems = false
        elseif invalid == "bad-name" then q.providedItems = { { itemID = 10441, name = "" } }
        else q.providedItems = { { itemID = 10441, name = "Glowing Shard", quantity = invalid == "zero-quantity" and 0 or false } } end
    end)
    assert(exact(u, a.L("ITEM_CARRIED", 0)) and occurrences(u, a.L("ITEM_CARRIED", 0)) == 1,
        "unrenderable " .. invalid .. " supplied entry cannot hide the starter inventory count")
    assert(not exact(u, a.L("PROVIDED_ITEMS")) and not role(u, "provided", 10441))
    total = total + 1
end
-- A rendered supplied role without a fresh bag count cannot consume the known starter count.
do
    local a, u = fixture(6981, 0, false)
    local calls = 0
    C_Item.GetItemCount = function(id)
        if id == 10441 then calls = calls + 1; if calls == 1 then return 0 end end
    end
    u:RefreshDetail()
    assert(calls == 2 and role(u, "provided", 10441))
    assert(exact(u, a.L("ITEM_CARRIED", 0)) and occurrences(u, a.L("ITEM_CARRIED", 0)) == 1,
        "a supplied row with unknown later inventory preserves the already known starter count")
    total = total + 1
end
-- The native count callback can supersede the pending starter caption with another card/source/locale.
for _, kind in ipairs({ "quest", "source", "locale" }) do
    local a, u, q = fixture(6981, 0, false)
    local getter, calls, fired, completed = C_Item.GetItemCount, 0, false, false
    C_Item.GetItemCount = function(id, ...)
        if id == 10441 then
            calls = calls + 1
            if calls == 2 and not fired then
                fired = true
                if kind == "quest" then assert(u:InspectQuest(1491, true))
                elseif kind == "source" then q.providedItems = nil; u:RefreshDetail()
                else assert(a.Language:Open(u)); assert(a.Language:Commit(a.Language.session, "ruRU")) end
                completed = true
            end
        end
        return getter(id, ...)
    end
    u:RefreshDetail()
    assert(fired and completed, "the later provided-row count callback must actually complete superseding the pending starter count")
    if kind == "quest" then assert(u.quest == 1491 and occurrences(u, "Glowing Shard") == 0)
    else
        local value = a.L("ITEM_CARRIED", 0)
        assert(u.quest == 6981 and occurrences(u, value) == 1)
        if kind == "source" then assert(exact(u, value) and not role(u, "provided", 10441))
        else assert(a.db.locale == "ruRU" and occurrences(u, "Carried: 0") == 0) end
    end
    total = total + 1
end
for _, phase in ipairs({ "before", "after" }) do
    local a, u = fixture(6981, 0, false)
    local field
    for _, f in ipairs(fields(u)) do if f:GetText():find("Glowing Shard ×?", 1, true) then field = f end end
    assert(field)
    local setter, fired = field.SetText, false
    field.SetText = function(self, value)
        local hit = not fired and value:find("Glowing Shard ×?", 1, true)
        if hit and phase == "before" then fired = true; assert(u:InspectQuest(1491, true)) end
        local result = setter(self, value)
        if hit and phase == "after" then fired = true; assert(u:InspectQuest(1491, true)) end
        return result
    end
    u:RefreshDetail(); field.SetText = setter
    assert(fired and u.quest == 1491 and occurrences(u, "Glowing Shard") == 0,
        "late " .. phase .. " supplied-row text cannot restore an older starter caption")
    total = total + 1
end
-- DP-5 DETAIL-ACQUISITION-TYPED-STARTER-EMPTY: {} normalizes to nil, no extra standalone.
for _, count in ipairs({ 0, 4 }) do
    local a, u, q = fixture(6981, count, false)
    assert(q.startAlternatives == nil)
    local value = a.L("ITEM_CARRIED", count)
    assert(occurrences(u, value) == 1, "nil typed starter keeps one supplied count without a standalone")
    assert(not exact(u, value), "nil quest summary keeps the count on the supplied row")
    q.startAlternatives = {}
    u:Refresh()
    assert(occurrences(u, value) == 1, "empty alternatives keep the same single supplied count as nil without an extra standalone")
    assert(not exact(u, value), "empty quest summary keeps the count on the supplied row like nil")
    assert(u:SetDetailTab("sources"))
    q.startAlternatives = nil
    u:Refresh()
    local nilSources = occurrences(u, value)
    assert(nilSources == 1 and exact(u, value), "nil sources keep one standalone giver count when supplied rows are absent")
    q.startAlternatives = {}
    u:Refresh()
    local emptySources = occurrences(u, value)
    assert(emptySources == 1 and emptySources == nilSources, "empty alternatives keep the same single sources count as nil")
    assert(exact(u, value), "empty sources keep the standalone giver count like nil")
    -- Controls: nonempty alternatives stay untyped without a crash; nil is unchanged.
    q.startAlternatives = { { npcID = 1, name = "Alt source" } }
    u:Refresh()
    assert(u.quest == 6981, "nonempty alternatives keep selection without a crash")
    q.startAlternatives = nil
    u:Refresh()
    assert(occurrences(u, value) == 1, "nil still resolves the typed count after the nonempty control")
    total = total + 2
end
-- DP-5 DETAIL-TYPED-STARTER-HUGE-BOUND: huge starter yields no carried; uint32-max stays typed.
do
    local function shownExact(u, value)
        for _, f in ipairs(u.details) do if f:IsShown() and f:GetText() == value then return f end end
    end
    do
        local a, u, q = fixture(6981, 4, false)
        local savedStart, savedProvided = q.start, q.providedItems
        local value = a.L("ITEM_CARRIED", 4)
        q.providedItems = nil
        q.start = { itemID = 4294967296, name = "Huge starter", containerSource = { objectID = 11, name = "Huge Cache", zoneName = "Known zone" }, dropSources = { { npcID = 1, name = "Source", locationName = "Known zone" } } }
        q.startAlternatives = nil
        assert(u:SetDetailTab("sources"))
        assert(occurrences(u, value) == 0, "huge starter with routes shows no carried count")
        assert(not shownExact(u, value), "huge sources keep no standalone carried caption")
        assert(not exact(u, a.L("ITEM_ACQUISITION")), "huge starter builds no acquisition heading")
        assert(occurrences(u, a.L("ITEM_DROP_SOURCE", "Source", "Known zone")) == 0, "huge starter builds no drop route fact")
        q.start = { itemID = 9007199254740991, name = "Huge starter", containerSource = { objectID = 11, name = "Huge Cache", zoneName = "Known zone" }, dropSources = { { npcID = 1, name = "Source", locationName = "Known zone" } } }
        u:Refresh()
        assert(occurrences(u, value) == 0, "2^53-1 starter with routes shows no carried count")
        q.start = savedStart
        q.providedItems = savedProvided
        q.startAlternatives = nil
        u:Refresh()
        total = total + 1
    end
    for _, case in ipairs({ { id = 4294967295, expect = 1 }, { id = 9007199254740991, expect = 0 } }) do
        local a, u, q = fixture(6981, 4, false)
        local savedStart, savedProvided = q.start, q.providedItems
        local value = a.L("ITEM_CARRIED", 4)
        q.providedItems = nil
        q.start = { itemID = case.id, name = "Boundary starter" }
        q.startAlternatives = nil
        assert(u:SetDetailTab("sources"))
        local found = occurrences(u, value)
        assert(found == case.expect, "boundary " .. case.id .. " keeps " .. case.expect .. " carried")
        q.start = savedStart
        q.providedItems = savedProvided
        u:Refresh()
        total = total + 1
    end
end
print("PASS starter/supplied carried-count composition: " .. total .. " actual role/count/tab/invalid/reentry cases")
