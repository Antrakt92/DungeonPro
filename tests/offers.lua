local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPrep", addon)
assert(loadfile("Core/Client.lua"))("DungeonPrep", addon)
assert(loadfile("Core/Planner.lua"))("DungeonPrep", addon)
local secret, now, player, npc, rows, calls, notifications = {}, 0, "", "", {}, 0, 0
local function reset()
    addon.ClearOffers()
    now, player, npc, rows, calls, notifications = 100, "Player-one", "Creature-one", { { questID = 1 } }, 0, 0
    C_Timer = nil
    addon.Notify = function() notifications = notifications + 1 end
    addon.quests = { [1] = { id = 1, minLevel = 1, requirementsKnown = false },
        [2] = { id = 2, minLevel = 1, requirementsKnown = true } }
    issecretvalue = function(v) return v == secret end
    GetTime = function() return now end
    UnitGUID = function(unit) return unit == "player" and player or npc end
    C_GossipInfo = { GetAvailableQuests = function(...) assert(select("#", ...) == 0); calls = calls + 1; return rows end,
        SelectAvailableQuest = function() error("must not select quest") end,
        SelectOption = function() error("must not interact") end }
    AcceptQuest = function() error("must not accept quest") end
end
local function check(label, fn)
    reset()
    local ok, err = pcall(fn); assert(ok, label .. ": " .. tostring(err))
    total = total + 1; print("PASS " .. label)
end
check("Only known quests in the current gossip list get an informational offer DTO", function()
    rows = { { questID = 1, title = secret }, { questID = 999 }, { questID = 1 } }
    addon.OfferEvent("GOSSIP_SHOW")
    local offer = addon.CurrentOffer(1)
    assert(offer.offeredNow == true and offer.source == "gossip" and offer.npcID == nil)
    assert(addon.CurrentOffer(2) == nil and addon.CurrentOffer(999) == nil)
    assert(calls == 1, "reading an offer must not call the native list again")
    rows[1].questID = 2
    assert(addon.CurrentOffer(1) and not addon.CurrentOffer(2), "snapshot must not retain mutable native rows")
end)
check("Offers never fill missing prerequisites or grant dungeon readiness", function()
    addon.CaptureOffers()
    local context = { level = 20, completed = function() return false end, active = function() return false end }
    local engine = addon.Planner.New(addon.quests, context)
    assert(addon.CurrentOffer(1) and engine:State(1).status == "UNKNOWN")
    local actions, uncertain = engine:Next(1)
    assert(#actions == 0 and uncertain and addon.quests[1].requirementsKnown == false)
    assert(not engine:Dungeon({ quests = { 1 }, coverage = "partial" }).ready)
end)
check("Closing including continuing transitions and character quest events invalidate immediately", function()
    for _, event in ipairs({ "GOSSIP_CLOSED", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING",
        "QUEST_FINISHED", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
        "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT" }) do
        addon.CaptureOffers(); assert(addon.CurrentOffer(1))
        addon.OfferEvent(event, true); assert(addon.CurrentOffer(1) == nil, event)
    end
    addon.OfferEvent("GOSSIP_OPTIONS_REFRESHED"); assert(addon.CurrentOffer(1) == nil)
end)
check("New gossip and explicit refresh replace rather than merge IDs", function()
    addon.CaptureOffers(); rows = { { questID = 2 } }
    addon.OfferEvent("GOSSIP_SHOW")
    assert(not addon.CurrentOffer(1) and addon.CurrentOffer(2))
    rows = {}; addon.OfferEvent("GOSSIP_OPTIONS_REFRESHED")
    assert(not addon.CurrentOffer(1) and not addon.CurrentOffer(2))
end)
check("Thirty second TTL is absolute and clock failures or regression clear ownership", function()
    addon.CaptureOffers(); now = 129.9
    assert(addon.CurrentOffer(1)); now = 130; assert(not addon.CurrentOffer(1))
    now = 110; assert(not addon.CurrentOffer(1), "expired snapshot must not revive")
    for _, value in ipairs({ 99, -1, math.huge, 0/0, secret, "101" }) do
        now = 100; addon.CaptureOffers(); now = value; assert(not addon.CurrentOffer(1))
    end
    reset(); addon.CaptureOffers(); GetTime = function() error("no clock") end
    assert(not addon.CurrentOffer(1))
end)
check("Changing or unavailable player or NPC identity fails closed without resurrection", function()
    for _, unit in ipairs({ "player", "npc" }) do
        for _, value in ipairs({ "Changed", "", secret, false, string.rep("x", 257) }) do
            reset(); addon.CaptureOffers()
            if unit == "player" then player = value else npc = value end
            assert(not addon.CurrentOffer(1))
            player, npc = "Player-one", "Creature-one"; assert(not addon.CurrentOffer(1))
        end
    end
    reset(); UnitGUID = nil; addon.CaptureOffers(); assert(not addon.CurrentOffer(1) and calls == 0)
end)
check("Missing throwing restricted malformed and oversized native lists discard previous offers", function()
    local invalid = { secret, false, "rows", { { questID = secret } }, { { questID = 0 } },
        { { questID = 1.5 } }, { secret }, { [2] = { questID = 1 } }, { bad = { questID = 1 } } }
    local tooMany = {}; for i = 1, 101 do tooMany[i] = { questID = 1 } end
    invalid[#invalid + 1] = tooMany
    for _, value in ipairs(invalid) do
        reset(); addon.CaptureOffers(); rows = value; addon.CaptureOffers(); assert(not addon.CurrentOffer(1))
    end
    reset(); addon.CaptureOffers(); C_GossipInfo = nil; addon.CaptureOffers(); assert(not addon.CurrentOffer(1))
    reset(); addon.CaptureOffers(); C_GossipInfo.GetAvailableQuests = function() error("native failed") end
    addon.CaptureOffers(); assert(not addon.CurrentOffer(1))
    reset(); rows = { setmetatable({}, { __index = function() error("bad row") end }) }
    addon.CaptureOffers(); assert(not addon.CurrentOffer(1))
end)
check("Invalid or unknown requested quest IDs cannot authorize a marker", function()
    addon.CaptureOffers()
    for _, value in ipairs({ secret, 0, -1, 1.5, "1", math.huge, 0/0, 999 }) do assert(not addon.CurrentOffer(value)) end
    assert(not addon.CurrentOffer(nil))
end)
check("Reentrant close or replacement during native read cannot commit the older generation", function()
    C_GossipInfo.GetAvailableQuests = function() addon.OfferEvent("GOSSIP_CLOSED"); return rows end
    addon.CaptureOffers(); assert(not addon.CurrentOffer(1))
    reset()
    C_GossipInfo.GetAvailableQuests = function()
        C_GossipInfo.GetAvailableQuests = function() return { { questID = 2 } } end
        addon.CaptureOffers(); return { { questID = 1 } }
    end
    addon.CaptureOffers(); assert(not addon.CurrentOffer(1) and addon.CurrentOffer(2))
end)
check("Identity changes during capture or reentrant close during lookup cannot escape validation", function()
    C_GossipInfo.GetAvailableQuests = function() npc = "Changed"; return rows end
    addon.CaptureOffers(); assert(not addon.CurrentOffer(1))
    reset(); addon.CaptureOffers()
    UnitGUID = function() addon.OfferEvent("GOSSIP_CLOSED"); return "Player-one" end
    assert(not addon.CurrentOffer(1))
end)
check("Owned expiry notifies once without reading native offers and early callbacks never recurse", function()
    local callback
    C_Timer = { After = function(delay, fn) assert(delay == 30); callback = fn end }
    addon.CaptureOffers(); assert(callback and calls == 1)
    now = 129; callback(); assert(notifications == 0 and addon.CurrentOffer(1))
    now = 130; callback(); assert(notifications == 1 and not addon.CurrentOffer(1) and calls == 1)
    callback(); assert(notifications == 1)
    reset(); C_Timer = { After = function(_, fn) now = 150; fn() end }
    addon.CaptureOffers(); assert(notifications == 0 and calls == 1)
    assert(not addon.CurrentOffer(1), "inline scheduler leaves the getter expiry fallback")
end)
check("An owned expiry with unavailable or regressed clock conservatively clears the visible observation once", function()
    for _, broken in ipairs({ function() return nil end, function() error("clock unavailable") end,
        function() return secret end, function() return 99 end }) do
        reset()
        local callback, visible
        C_Timer = { After = function(_, fn) callback = fn end }
        addon.CaptureOffers(); visible = addon.CurrentOffer(1) ~= nil
        assert(visible and callback)
        addon.Notify = function()
            notifications = notifications + 1
            visible = addon.CurrentOffer(1) ~= nil
        end
        GetTime = broken
        callback()
        assert(notifications == 1 and not visible, "failed expiry clock must invalidate and refresh a stationary marker")
        GetTime = function() return 100 end
        assert(not addon.CurrentOffer(1), "invalidated evidence must not revive after clock recovery")
        callback(); assert(notifications == 1 and calls == 1, "no duplicate refresh or native offer fetch")
    end
end)
check("A stale expiry with unavailable clock cannot invalidate a newer observation", function()
    local callbacks = {}
    C_Timer = { After = function(_, fn) callbacks[#callbacks + 1] = fn end }
    addon.CaptureOffers(); now = 120; rows = { { questID = 2 } }; addon.CaptureOffers()
    GetTime = function() error("clock unavailable") end
    callbacks[1](); assert(notifications == 0)
    GetTime = function() return now end
    assert(addon.CurrentOffer(2) and not addon.CurrentOffer(1), "stale callback must preserve newer ownership")
end)
check("Stale expiry preserves later snapshots and a clean clock preserves pre-expiry evidence", function()
    local callbacks = {}
    C_Timer = { After = function(_, fn) callbacks[#callbacks + 1] = fn end }
    addon.CaptureOffers(); now = 120; rows = { { questID = 2 } }; addon.CaptureOffers()
    now = 130; callbacks[1](); assert(notifications == 0 and addon.CurrentOffer(2))
    now = 149; callbacks[2](); assert(notifications == 0 and addon.CurrentOffer(2))
    now = 150; callbacks[2](); assert(notifications == 1 and not addon.CurrentOffer(2))
end)
check("Missing failed and queued-then-throw schedulers retain only getter or event expiry fallback", function()
    for _, timer in ipairs({ {}, { After = true }, { After = function() error("timer failed") end } }) do
        reset(); C_Timer = timer; addon.CaptureOffers(); assert(addon.CurrentOffer(1))
        now = 130; assert(not addon.CurrentOffer(1) and notifications == 0)
    end
    reset(); addon.CaptureOffers(); now = 130; assert(not addon.CurrentOffer(1))
    reset(); local abandoned
    C_Timer = { After = function(_, fn) abandoned = fn; error("queued then failed") end }
    addon.CaptureOffers(); now = 130; abandoned()
    assert(notifications == 0 and calls == 1)
    now = 100; assert(addon.CurrentOffer(1), "failed timer callback must not mutate snapshot")
    addon.OfferEvent("GOSSIP_CLOSED"); assert(not addon.CurrentOffer(1))
end)
check("A replacement during the expiry clock read keeps the newer observation", function()
    local callbacks = {}
    C_Timer = { After = function(_, fn) callbacks[#callbacks + 1] = fn end }
    addon.CaptureOffers(); now = 130
    GetTime = function()
        GetTime = function() return now end
        rows = { { questID = 2 } }; addon.CaptureOffers()
        return now
    end
    callbacks[1]()
    assert(notifications == 0 and addon.CurrentOffer(2) and not addon.CurrentOffer(1))
end)
print("Current gossip offer checks passed: " .. total .. " (no native-client acceptance)")
