-- Repeatable actual-TOC workload counts; CPU times are modeled, not game FPS.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui = fixture.addon, fixture.addon.UI
issecretvalue = function() return false end
local queue, clock = {}, 0
C_Timer = { After = function(delay, callback)
    queue[#queue + 1] = { at = clock + delay, callback = callback }
end }
local function drain()
    local steps = 0
    while #queue > 0 do
        steps = steps + 1
        assert(steps <= 10000, "startup work must settle without an endless timer chain")
        table.sort(queue, function(a, b) return a.at < b.at end)
        local task = table.remove(queue, 1)
        clock = task.at
        task.callback()
    end
    return steps
end
local counters = {}
local function count(object, key)
    local original = assert(object[key])
    object[key] = function(...)
        counters[key] = (counters[key] or 0) + 1
        return original(...)
    end
end
for _, key in ipairs({ "Context", "Clean", "Read", "CachedQuestName" }) do count(addon, key) end
count(addon.Planner, "New")
count(addon.DungeonStatus, "Get")
for _, key in ipairs({ "IsOnQuest", "IsQuestFlaggedCompleted" }) do count(C_QuestLog, key) end
local function phase(name, callback)
    counters = {}
    local start, allocated = os.clock(), #fixture.objects
    callback()
    local firstPaint = os.clock() - start
    local jobs = drain()
    counters.objects = #fixture.objects - allocated
    print(string.format("PROFILE %s first-cpu=%.6f settled-cpu=%.6f jobs=%d objects=%d context=%d planner=%d status=%d clean=%d read=%d active=%d history=%d",
        name, firstPaint, os.clock() - start, jobs, #fixture.objects - allocated,
        counters.Context or 0, counters.New or 0, counters.Get or 0,
        counters.Clean or 0, counters.Read or 0, counters.IsOnQuest or 0, counters.IsQuestFlaggedCompleted or 0))
    return counters
end
phase("initialize", function() fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro") end)
local cold = phase("cold-open", function() ui:Toggle() end)
assert(ui.frame:IsShown() and ui.quest == nil and ui.dungeon == nil)
assert(cold.Get == #addon.dungeons, "initial catalogue retains status for every dungeon")
assert(cold.Context == 1 and cold.New == 1, "empty quest pane must not build a second unused planner")
local warm = phase("warm-reopen", function() ui:Toggle(); ui:Toggle() end)
assert(warm.objects == 0, "reopening reuses the existing native controls")
for _, dungeon in ipairs(addon.dungeons) do if dungeon.key == "dm" then ui.dungeon = dungeon end end
local selected = phase("select-dungeon", function() ui:Refresh() end)
assert(selected.New <= 8 and selected.Get <= #addon.dungeons * 4,
    "cold per-ID failures must not fan out into repeated whole-catalogue rebuilds")
phase("repeat-refresh", function() ui:Refresh() end)
phase("language-selection-refresh", function() addon.db.locale = "zhCN"; ui:Refresh(true) end)
ui.frame:Hide()
local hidden = phase("hidden-events", function()
    for _ = 1, 1000 do fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "QUEST_LOG_UPDATE") end
end)
assert(not hidden.Get and not hidden.New, "hidden event bursts cannot construct catalogue or planner")
print("Startup workload: PASS (actual TOC, modeled timing only)")
