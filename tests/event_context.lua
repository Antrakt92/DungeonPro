local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, events = fixture.addon, fixture.eventFrame
local pending = {}
C_Timer = { After = function(delay, callback) pending[#pending + 1] = { delay, callback } end }
events.scripts.OnEvent(events, "ADDON_LOADED", "DungeonPro")
local active, ready, level = false, false, 20
UnitLevel = function() return level end
C_QuestLog.IsOnQuest = function() return active end
C_QuestLog.ReadyForTurnIn = function() return ready end
local quests = { [91001] = { id = 91001, minLevel = 10, requirementsKnown = true } }
local total = 0
local function event(name, id) events.scripts.OnEvent(events, name, id) end
do
    local previousFrame = addon.UI.frame
    addon.UI.frame = { IsShown = function() return true end }
    local context = addon.Context()
    event("QUEST_LOG_UPDATE")
    local queued = 0
    for _, task in ipairs(pending) do if task[1] == .1 then queued = queued + 1 end end
    assert(queued == 1 and not context.current(), "visible planner retained old evidence until its queued paint")
    addon.UI.frame = previousFrame
    total = total + 1
end
for _, name in ipairs({ "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE",
    "QUEST_ITEM_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD",
    "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT" }) do
    active, ready, level = false, false, 20
    local context = addon.Context()
    local engine = addon.Planner.New(quests, context, {})
    assert(engine:State(91001).status == "AVAILABLE")
    active, ready, level = true, true, 21
    event(name, 91001)
    assert(not context.current(), "old character evidence survived " .. name .. " before deferred refresh")
    assert(engine:State(91001).status == "UNKNOWN", "a cached state survived " .. name)
    local fresh = addon.Planner.New(quests, addon.Context(), {})
    assert(fresh:State(91001).status == "READY", "new context could not recover after " .. name)
    total = total + 1
end
-- Loading a name or moving through dialogue does not itself change quest history.
for _, name in ipairs({ "QUEST_DATA_LOAD_RESULT", "ITEM_DATA_LOAD_RESULT", "QUEST_DETAIL", "GOSSIP_SHOW" }) do
    local context = addon.Context()
    event(name, 91001)
    assert(context.current(), "non-state data event expired character evidence: " .. name)
    total = total + 1
end
do
    local armed, fired = false, false
    local complete = function() return false end
    C_QuestLog.IsComplete = complete
    issecretvalue = function(value)
        if armed and not fired and value == complete then fired = true; addon.InvalidateContext() end
        return false
    end
    local context = addon.Context()
    armed = true
    assert(not context.current() and fired, "an event during validity checks published the previous revision")
    assert(not context.current(), "expired context revived")
    total = total + 1
end
print("Event context lifecycle: " .. total .. " checks passed (actual TOC, no native-game validation)")
