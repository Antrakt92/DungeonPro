-- Actual-TOC large-list workload; modeled CPU is not native game performance.
local mode, baseline = arg and arg[1] or "missing", arg and arg[2]
local originalLoad = loadfile
if baseline then
    loadfile = function(path)
        if path == "UI/Window.lua" or path == "UI/RewardCache.lua" or path == "Core/Client.lua" or
            path == "Core/DungeonStatus.lua" or path == "Core/Events.lua" or path == "Core/Namespace.lua" then
            return originalLoad(baseline .. "/" .. path)
        end
        return originalLoad(path)
    end
end
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui, event = fixture.addon, fixture.addon.UI, fixture.eventFrame
local queue, clock, ready, tasks, loads = {}, 0, {}, 0, 0
local counters, maxClean, maxCPU, maxHydrations, refreshes = {}, 0, 0, 0, 0
local function wrap(object, key)
    local original = assert(object[key])
    object[key] = function(...)
        counters[key] = (counters[key] or 0) + 1
        return original(...)
    end
end
issecretvalue = function() return false end
C_Timer = { After = function(delay, callback)
    queue[#queue + 1] = { at = clock + delay, callback = callback }
end }
GetLocale = function() return "enUS" end
HaveQuestRewardData = function() return mode == "items" end
GetNumQuestLogRewards = function() return 1 end
GetNumQuestLogChoices = function() return 2 end
local function reward(index, id)
    local item = id * 10 + index
    return ready[item] and "Reward " .. item or nil, ready[item] and 134400 or nil, 1, 2, true, item
end
GetQuestLogRewardInfo = function(_, id) return reward(1, id) end
GetQuestLogChoiceInfo = function(index, id) return reward(index + 1, id) end
C_TaskQuest = { RequestPreloadRewardData = function() end }
C_Item = {
    GetItemNameByID = function(id) return ready[id] and "Reward " .. id or nil end,
    IsItemDataCachedByID = function(id) return ready[id] == true end,
    RequestLoadItemDataByID = function(id)
        loads = loads + 1
        C_Timer.After(.03, function()
            ready[id] = true
            event.scripts.OnEvent(event, "ITEM_DATA_LOAD_RESULT", id, true)
        end)
    end,
}
wrap(addon, "Clean"); wrap(addon, "Read"); wrap(addon, "RequestQuestRewardItems")
wrap(addon.DungeonStatus, "Get")
local refresh = ui.Refresh
ui.Refresh = function(self, ...)
    refreshes = refreshes + 1
    return refresh(self, ...)
end
event.scripts.OnEvent(event, "ADDON_LOADED", "DungeonPro")
for _, dungeon in ipairs(addon.dungeons) do if dungeon.name == "Blackrock Depths" then ui.dungeon = dungeon end end
assert(ui.dungeon and #ui.dungeon.quests == 42, "exercise the reported full BRD catalogue")
addon.char.selectedDungeon = ui.dungeon.key
addon.char.filters = { includeUnavailable = true }
ui.includeUnavailable = true
if mode == "chain" then ui.questTreeRoot, ui.questTreeDungeon = 4241, ui.dungeon end
counters, queue = {}, {}
local start = os.clock()
ui:Toggle()
local visible = 0
for _, row in ipairs(ui.rows) do if row:IsShown() then visible = visible + 1 end end
assert(mode == "chain" and visible > 42 or mode ~= "chain" and visible == 42,
    "cold restored selection must paint all BRD rows and its expanded chain")
local firstCPU, firstClean, firstHydrations = os.clock() - start, counters.Clean or 0, counters.RequestQuestRewardItems or 0
while #queue > 0 do
    tasks = tasks + 1; assert(tasks <= 4000, "large dungeon work must settle")
    table.sort(queue, function(a, b) return a.at < b.at end)
    local task = table.remove(queue, 1); clock = task.at
    counters = {}; local tick = os.clock(); task.callback()
    maxCPU = math.max(maxCPU, os.clock() - tick)
    maxClean = math.max(maxClean, counters.Clean or 0)
    maxHydrations = math.max(maxHydrations, counters.RequestQuestRewardItems or 0)
end
print(string.format("BRD42 %s first-cpu=%.6f first-clean=%d first-hydrations=%d max-job-cpu=%.6f max-job-clean=%d max-job-hydrations=%d jobs=%d loads=%d refreshes=%d",
    mode, firstCPU, firstClean, firstHydrations, maxCPU, maxClean, maxHydrations, tasks, loads, refreshes))
if not baseline then
    assert(firstHydrations == 0, "opening a large list cannot synchronously hydrate every reward")
    assert(maxHydrations <= 2, "a deferred callback cannot hydrate the entire large dungeon")
    assert(firstClean < (mode == "chain" and 400000 or 300000), "cold restored selection must not repeat accumulated proofs per row")
    assert(maxClean < 160000, "a single deferred job cannot repeat a whole large-list source scan per item")
    counters = {}
    ui:Toggle(); ui:Toggle()
    assert((counters.Get or 0) == 0, "warm reopen must reuse valid catalogue status")
    assert((counters.RequestQuestRewardItems or 0) == 0, "warm reopen cannot synchronously restart reward hydration")
    ui:Toggle()
    event.scripts.OnEvent(event, "QUEST_LOG_UPDATE")
    counters = {}; ui:Toggle()
    assert(counters.Get == #addon.dungeons, "a hidden quest change must force fresh catalogue state on reopen")
end
print("Large dungeon workload: PASS (actual TOC, no native freeze acceptance)")
