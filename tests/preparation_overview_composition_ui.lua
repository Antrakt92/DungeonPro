-- Actual Client context and registered quest events drive the overview; no Context/Planner mocks.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui, events = fixture.addon, fixture.addon.UI, fixture.eventFrame
if not addon.DungeonOverview then assert(loadfile("Core/DungeonOverview.lua"))("DungeonPro", addon) end
local nativeContext, nativePlanner, nativeNavigation = addon.Context, addon.Planner, addon.Navigation
local held, ready, completed, faction = {}, {}, {}, "Alliance"
issecretvalue = function() return false end
GetLocale = function() return "enUS" end
UnitLevel = function() return 60 end
UnitClass = function() return "Mage", "MAGE", 8 end
UnitRace = function() return "Human", "Human", 1 end
UnitFactionGroup = function() return faction end
C_QuestLog.IsOnQuest = function(id) return held[id] == true end
C_QuestLog.ReadyForTurnIn = function(id) return ready[id] == true end
C_QuestLog.IsQuestFlaggedCompleted = function(id) return completed[id] == true end
-- Only the registered event refresh is immediate; unrelated hydration retries are not manufactured.
C_Timer = { After = function(delay, callback) if delay == 0.1 then callback() end end }
GetItemCount = function() return 0 end
local routes, selections, accepts = 0, 0, 0
C_Map.SetUserWaypoint = function() routes = routes + 1; return true end
C_QuestLog.SetSelectedQuest = function() selections = selections + 1 end
SelectQuestLogEntry = function() selections = selections + 1 end
AcceptQuest = function() accepts = accepts + 1 end
CompleteQuest = function() accepts = accepts + 1 end
GetQuestReward = function() accepts = accepts + 1 end
events.scripts.OnEvent(events, "ADDON_LOADED", "DungeonPro")
ui:Toggle(); addon.db.locale = "enUS"
local dungeon
for _, value in ipairs(addon.dungeons) do if value.key == "dm" then dungeon = value end end
assert(dungeon)
local target, other, classQuest, support = addon.quests[166], addon.quests[214], addon.quests[1654], addon.quests[155]
local catalogue, group1, group2, classes, start, finish = dungeon.quests, target.requires, other.requires,
    classQuest.classes, classQuest.start, support.finish
ui.dungeon, ui.quest, ui.includeUnavailable, ui.range = dungeon, nil, false, false
ui:Refresh()
local function textVisible(text)
    for _, pool in ipairs({ ui.details, ui.overviewTexts or {} }) do
        for _, field in ipairs(pool) do if field:IsShown() and field:GetText() == text then return true end end
    end
    return false
end
local function summary()
    local binding = ui.overviewBinding
    assert(binding and binding.model and binding.current and binding.rawProof,
        "the actual dungeon overview must expose its owned preparation summary")
    assert(binding.current() and binding.rawProof())
    assert(ui.quest == nil and ui.dungeon == dungeon and ui.engine:Current())
    assert(binding.model.unknown and not binding.model.knownPrepared,
        "partial catalogue coverage and unverified requirements cannot become prepared")
    assert(textVisible(addon.L("OVERVIEW_PREPARATION")) and textVisible(addon.L("OVERVIEW_UNCERTAIN")),
        "visible progress and uncertainty must accompany the actual summary")
    return binding, binding.model
end
local function step(id, kind)
    local found
    for _, button in ipairs(ui.actionInspectButtons) do
        if button:IsShown() and button.questID == id and button.overviewStep then
            assert(not found, "a shared preparation step appears only once")
            assert(button.overviewStep.id == id and button.overviewStep.kind == kind)
            found = button
        end
    end
    return found
end
local function staleSnapshot(id, kind)
    local binding, model = summary()
    local button = id and assert(step(id, kind))
    return { binding = binding, current = binding.current, model = model,
        click = button and button.scripts.OnClick, quest = ui.quest }
end
local function expire(previous)
    assert(ui.overviewBinding ~= previous.binding and previous.current() ~= true,
        "a native quest event retires the old overview proof")
    if previous.click then
        previous.click()
        assert(ui.quest == nil and ui.dungeon == dungeon, "a stale overview inspection cannot reopen an earlier event state")
    end
end
local function event(name, id) events.scripts.OnEvent(events, name, id) end
local _, first = summary()
assert(first.shownRoots == 7 and first.counts.UNKNOWN == 7 and #first.steps == 0)
-- Real log evidence outranks stale class restrictions without changing the recorded PALADIN fact.
local previous = staleSnapshot()
held[1654] = true; event("QUEST_ACCEPTED", 1654); expire(previous)
local _, active = summary()
assert(active.shownRoots == 8 and active.counts.ACTIVE == 1 and active.counts.UNKNOWN == 7)
assert(#active.steps == 1 and step(1654, "complete") and ui.engine:State(1654).status == "ACTIVE")
previous = staleSnapshot(1654, "complete")
ready[1654] = true; event("QUEST_LOG_UPDATE"); expire(previous)
local _, turnin = summary()
assert(turnin.counts.READY == 1 and turnin.counts.ACTIVE == 0 and #turnin.steps == 1 and step(1654, "turnin"))
previous = staleSnapshot(1654, "turnin")
held[1654], ready[1654] = false, false; event("QUEST_REMOVED", 1654); expire(previous)
local _, removed = summary()
assert(removed.shownRoots == 7 and removed.counts.READY == 0 and #removed.steps == 0 and not step(1654, "turnin"))
assert(ui.engine:State(1654).status == "UNAVAILABLE")
-- Existing Mine/All control changes displayed roots, never character preparation or certainty.
ui.characterButton.scripts.OnClick()
local _, all = summary()
assert(ui.includeUnavailable and all.shownRoots == 9 and all.counts.UNAVAILABLE == 2 and #all.steps == 0)
ui.characterButton.scripts.OnClick()
assert(not ui.includeUnavailable and select(2, summary()).shownRoots == 7)
-- Both actual targets share required155. One READY support step is not a READY target count.
held[155], ready[155] = true, true; event("QUEST_ACCEPTED", 155)
local _, shared = summary()
assert(shared.shownRoots == 7 and shared.counts.UNKNOWN == 7 and shared.counts.READY == 0)
assert(#shared.steps == 1 and step(155, "turnin") and ui.engine:State(166).status == "UNKNOWN" and ui.engine:State(214).status == "UNKNOWN")
ui.characterButton.scripts.OnClick()
local _, sharedAll = summary()
assert(sharedAll.shownRoots == 9 and sharedAll.counts.UNAVAILABLE == 2 and #sharedAll.steps == 1 and step(155, "turnin"))
step(155, "turnin").scripts.OnClick()
assert(ui.quest == 155 and ui.dungeon == dungeon and routes == 0 and selections == 0 and accepts == 0,
    "the fresh shared-step control inspects exact155 without creating a route or selecting the native log")
assert(ui:BackQuest() and ui.quest == nil and ui.dungeon == dungeon)
assert(select(2, summary()).shownRoots == 9 and select(2, summary()).counts.READY == 0,
    "inspection and Back cannot add the support step to primary target counts")
previous = staleSnapshot(155, "turnin")
held[155], ready[155] = false, false; event("QUEST_REMOVED", 155); expire(previous)
assert(#select(2, summary()).steps == 0)
-- Changing the native faction also invalidates the real Context; a held root still wins its restriction.
faction = "Horde"; held[166] = true; event("PLAYER_ENTERING_WORLD")
local _, factionAll = summary()
assert(factionAll.shownRoots == 9 and factionAll.counts.ACTIVE == 1 and factionAll.counts.UNAVAILABLE == 8)
ui.characterButton.scripts.OnClick()
local _, factionMine = summary()
assert(not ui.includeUnavailable and factionMine.shownRoots == 1 and factionMine.counts.ACTIVE == 1 and #factionMine.steps == 1)
previous = staleSnapshot(166, "complete")
held[166] = false; event("QUEST_REMOVED", 166); expire(previous)
local empty = ui.overviewBinding
if empty and empty.model then
    assert(empty.model.shownRoots == 0 and #empty.model.steps == 0 and not empty.model.knownPrepared)
else
    assert(textVisible(addon.L("NO_CHARACTER_QUESTS", addon.L("FILTER_QUEST_ALL"))), "empty Mine must explain the absence of listed character quests")
end
-- A locale getter runs after the dynamic list proof. Its late mutation must also
-- expire borrowed raw source associations before the final inspection dispatch.
for _, mutation in ipairs({ "replace", "member" }) do
    faction, held[155], ready[155] = "Alliance", true, true
    local getter = ui.CatalogLanguageKey
    local calls, armed, fired = 0, false, false
    ui.CatalogLanguageKey = function(self, ...)
        local value = getter(self, ...)
        if armed then
            calls = calls + 1
            if calls == 2 then
                armed, fired = false, true
                if mutation == "replace" then
                    target.requires, other.requires = {}, {}
                else
                    group1[1].ids[1], group2[1].ids[1] = 65, 65
                end
            end
        end
        return value
    end
    event("PLAYER_ENTERING_WORLD")
    local previous = staleSnapshot(155, "turnin")
    armed = true; previous.click(); armed = false
    local inspected = ui.quest
    target.requires, other.requires = group1, group2
    group1[1].ids[1], group2[1].ids[1] = 155, 155
    ui.CatalogLanguageKey = getter
    assert(fired and calls == 2, "the final locale callback must actually mutate the shared source dependency")
    assert(inspected == nil, "late " .. mutation .. " source mutation must retire the old shared-step inspection")
end
assert(routes == 0 and selections == 0 and accepts == 0, "events, summaries and retired clicks never route, select or accept quests")
assert(addon.Context == nativeContext and addon.Planner == nativePlanner and addon.Navigation == nativeNavigation)
assert(dungeon.quests == catalogue and target.requires == group1 and other.requires == group2 and group1[1].ids[1] == 155 and group2[1].ids[1] == 155)
assert(classQuest.classes == classes and classes[1] == "PALADIN" and classQuest.start == start and support.finish == finish)
assert(target.requirementsKnown == false and other.requirementsKnown == false and classQuest.requirementsKnown == false)
print("PASS actual preparation overview composition: native accept/READY/remove, shared support, Mine/All/faction/class, expired inspections and unknown coverage; no automatic actions")
