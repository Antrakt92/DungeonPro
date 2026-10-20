-- DP-5 overview kind marks: outside/inside/level/unknown stay distinguishable.
local override = ...
local loader = loadfile
if override then loadfile = function(path) return loader(path == "UI/Window.lua" and override or path) end end
local f = assert(loader("tests/client_ui.lua"))("fixture")
loadfile = loader
local a, u = f.addon, f.addon.UI
assert(a.DungeonOverview and type(a.DungeonOverview.Get) == "function", "actual TOC must load the overview producer")
issecretvalue = function() return false end
C_Timer = { After = function() end }
GetLocale = function() return "enUS" end
UnitGUID = function() return "Player-overview-kinds" end
UnitLevel = function() return 60 end
UnitClass = function() return "Mage", "MAGE", 8 end
UnitFactionGroup = function() return "Alliance" end
f.eventFrame.scripts.OnEvent(f.eventFrame, "ADDON_LOADED", "DungeonPro")
u:Toggle(); a.db.locale = "enUS"
local routes = 0
a.Navigation = { Start = function() routes = routes + 1; return true end, Map = function() routes = routes + 1; return true end }

-- Controlled catalogue, not new facts: two pickups (outside/inside), one level gate, one unknown.
a.quests = {
    [9001] = { id = 9001, name = "Outside pickup", minLevel = 1, requirementsKnown = true },
    [9002] = { id = 9002, name = "Inside pickup", minLevel = 1, requirementsKnown = true, startsInside = true },
    [9003] = { id = 9003, name = "Level gate", minLevel = 100, requirementsKnown = true },
    [9004] = { id = 9004, name = "Unknown work", minLevel = 1, requirementsKnown = false },
}
local kindsDungeon = { key = "controlled-kinds", name = "Kinds fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = { 9001, 9002, 9003, 9004 } }
a.dungeons = { kindsDungeon }

local function render(dungeon, all)
    u.dungeon, u.quest, u.includeUnavailable, u.range = dungeon, nil, all == true, false
    u.questTreeRoot, u.questTreeDungeon = nil, nil
    u:Refresh()
    assert(u.quest == nil and u.engine and u.currentPlan)
end

local function summary()
    local b = u.overviewBinding
    assert(b and b.model and b.current() and b.rawProof(), "kinds overview must publish a current summary")
    return b, b.model
end

local function rowById(id)
    local found
    for _, r in ipairs(u.actionInspectButtons) do
        if r:IsShown() and r.questID == id then assert(not found, "kind step appears once"); found = r end
    end
    return assert(found, "expected visible kind row " .. id)
end

local function noteOf(id) return rowById(id).note.text end

-- (1) pickup + inside have distinct marks, stable pickup -> inside order, click opens its own card.
render(kindsDungeon)
local _, model = summary()
assert(model.counts.AVAILABLE == 2 and model.counts.LOCKED == 1 and model.counts.UNKNOWN == 1, "controlled AVAILABLE/LOCKED/UNKNOWN counts")
assert(#model.steps == 3 and model.steps[1].id == 9001 and model.steps[2].id == 9002 and model.steps[3].id == 9003,
    "producer phase order stays pickup -> inside -> level")
assert(model.steps[1].kind == "pickup" and model.steps[2].kind == "inside" and model.steps[3].kind == "level")
assert(model.unknown and not model.knownPrepared, "partial coverage never prepares")
for _, step in ipairs(model.steps) do assert(step.id ~= 9004, "unknown leaf never invents a pickup step") end
local outsideMark, insideMark = a.L("PREP_outside"), a.L("PREP_inside")
assert(outsideMark ~= "PREP_outside" and insideMark ~= "PREP_inside" and outsideMark ~= insideMark, "outside/inside need distinct translated marks")
local outsideNote, insideNote = noteOf(9001), noteOf(9002)
assert(outsideNote:find(outsideMark, 1, true) and not outsideNote:find(insideMark, 1, true), "outside row carries only the outside mark")
assert(insideNote:find(insideMark, 1, true) and not insideNote:find(outsideMark, 1, true), "inside row carries only the inside mark")
assert(outsideNote:find(a.L("BRANCH_INSPECT"), 1, true) and insideNote:find(a.L("BRANCH_INSPECT"), 1, true), "kind rows keep the inspect action")
do
    local order = {}
    for _, r in ipairs(u.actionInspectButtons) do if r:IsShown() then order[#order + 1] = r.questID end end
    local first, second
    for index, id in ipairs(order) do if id == 9001 then first = index end; if id == 9002 then second = index end end
    assert(first and second and first < second, "rendered order keeps pickup before inside")
end
rowById(9001).scripts.OnClick()
assert(u.quest == 9001 and u.dungeon == kindsDungeon and routes == 0, "outside click inspects its own card without routing")
assert(u:BackQuest() and u.quest == nil)
rowById(9002).scripts.OnClick()
assert(u.quest == 9002 and u.dungeon == kindsDungeon and routes == 0, "inside click inspects its own card without routing")
assert(u:BackQuest() and u.quest == nil)

-- (2) level/unknown stay under NEXT without promising availability; unknown never uses the ready green.
render(kindsDungeon)
local _, levelModel = summary()
assert(levelModel.unknown, "unknown coverage stays explicit beside level work")
local levelNote = noteOf(9003)
local levelMark = a.L("PREP_level")
assert(levelMark ~= "PREP_level", "level gate needs its own translated mark")
assert(levelNote:find(levelMark, 1, true), "level row carries the level mark")
assert(not levelNote:find(a.L("AVAILABLE"), 1, true), "level gate must not promise availability")
assert(levelNote:find(a.L("LOCKED"), 1, true) or levelNote:find(a.L("BRANCH_INSPECT"), 1, true), "level row keeps status/inspect context")
local uncertainMark = a.L("PREP_uncertain")
assert(uncertainMark ~= "PREP_uncertain", "unknown work needs its own translated mark")
for _, r in ipairs(u.actionInspectButtons) do
    if r:IsShown() then
        assert(not r.note.text:find(a.L("PREP_outside") .. ".*" .. a.L("PREP_inside")), "one row never merges both pickup marks")
        if r.overviewStep and r.overviewStep.status == "UNKNOWN" then
            assert(r.note.text:find(uncertainMark, 1, true), "unknown step keeps the uncertain mark")
            assert(not r.note.text:find("|cff66dd99", 1, true), "unknown never uses the completed/ready green")
        end
    end
end
do
    local seen = {}
    for _, pool in ipairs({ u.overviewTexts or {}, u.details }) do
        for _, fs in ipairs(pool) do if fs:IsShown() then seen[#seen + 1] = fs.text end end
    end
    local function position(value) for i, text in ipairs(seen) do if text == value then return i end end end
    assert(position(a.L("OVERVIEW_NEXT_STEPS")), "non-held kind work stays under NEXT")
    assert(not position(a.L("OVERVIEW_KNOWN_STEPS")), "no held steps means no held header")
    assert(position(a.L("OVERVIEW_UNCERTAIN")), "unknown coverage stays explicit")
end
assert(u.overviewBinding.model.counts.UNKNOWN == 1, "unknown count preserved")
for _, r in ipairs(u.actionInspectButtons) do if r:IsShown() then assert(r.questID ~= 9004, "unknown quest has no availability row") end end

-- (3) More/Fewer keeps kind grouping; switching dungeons retires old row ownership.
local manyIds = {}
for index = 1, 8 do
    local id = 9100 + index
    manyIds[index] = id
    a.quests[id] = { id = id, name = "Many step " .. index, minLevel = 1, requirementsKnown = true, startsInside = index == 3 }
end
a.quests[9200] = { id = 9200, name = "Many level", minLevel = 100, requirementsKnown = true }
manyIds[#manyIds + 1] = 9200
local manyDungeon = { key = "controlled-many", name = "Many fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = manyIds }
a.dungeons = { kindsDungeon, manyDungeon }
render(manyDungeon)
local _, many = summary()
assert(#many.steps == 6 and many.remainingSteps == 3, "six-step cap paginates the many fixture")
local more = u.overviewMoreButton
assert(more and more:IsShown(), "More control appears past the cap")
local firstKindNote = noteOf(manyIds[1])
assert(firstKindNote:find(a.L("PREP_outside"), 1, true), "paged outside row keeps its mark")
more.scripts.OnClick(more)
local _, expanded = summary()
assert(#expanded.steps == 9 and expanded.remainingSteps == 0, "More reveals the tail without changing phases")
assert(noteOf(manyIds[3]):find(a.L("PREP_inside"), 1, true), "inside mark survives expansion")
assert(noteOf(9200):find(a.L("PREP_level"), 1, true), "level mark survives expansion")
local fewer = u.overviewFewerButton
assert(fewer and fewer:IsShown(), "Fewer control appears after expansion")
fewer.scripts.OnClick(fewer)
local _, compacted = summary()
assert(#compacted.steps == 6 and compacted.remainingSteps == 3, "Fewer restores the cap")
assert(noteOf(manyIds[1]):find(a.L("PREP_outside"), 1, true), "kind grouping survives Fewer")
local staleClick = rowById(manyIds[1]).scripts.OnClick
render(kindsDungeon)
local _, switched = summary()
assert(switched.steps[1].id == 9001, "dungeon switch publishes the new dungeon steps")
assert(noteOf(9001):find(a.L("PREP_outside"), 1, true), "new dungeon keeps its own kind marks")
staleClick()
assert(u.quest == nil and routes == 0, "retired many-dungeon row cannot inspect after the switch")

-- (4) supporting x kind: shared support appears once as SUPPORTING·KIND·STATUS·INSPECT.
a.quests[9301] = { id = 9301, name = "Listed one", minLevel = 1, requirementsKnown = true, requires = { { ids = { 9302 } } } }
a.quests[9302] = { id = 9302, name = "Support outside", minLevel = 1, requirementsKnown = true }
a.quests[9303] = { id = 9303, name = "Listed two", minLevel = 1, requirementsKnown = true, requires = { { ids = { 9304 } } } }
a.quests[9304] = { id = 9304, name = "Support inside", minLevel = 1, requirementsKnown = true, startsInside = true }
a.quests[9305] = { id = 9305, name = "Listed three", minLevel = 1, requirementsKnown = true, requires = { { ids = { 9306 } } } }
a.quests[9306] = { id = 9306, name = "Support level", minLevel = 100, requirementsKnown = true }
local supportDungeon = { key = "controlled-supporting", name = "Supporting fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = { 9301, 9303, 9305 } }
a.dungeons = { kindsDungeon, manyDungeon, supportDungeon }
render(supportDungeon)
local _, sup = summary()
assert(sup.counts.LOCKED == 3 and sup.counts.AVAILABLE == 0, "listed parents stay level/requirement locked, support work is not a target count")
assert(#sup.steps == 3, "one supporting step per listed parent")
assert(sup.steps[1].id == 9302 and sup.steps[1].kind == "pickup" and sup.steps[1].status == "AVAILABLE" and sup.steps[1].listedTarget == false)
assert(sup.steps[2].id == 9304 and sup.steps[2].kind == "inside" and sup.steps[2].status == "AVAILABLE" and sup.steps[2].listedTarget == false)
assert(sup.steps[3].id == 9306 and sup.steps[3].kind == "level" and sup.steps[3].status == "LOCKED" and sup.steps[3].listedTarget == false)
assert(sup.unknown and not sup.knownPrepared, "partial coverage never prepares through support work")
local supportingMark, inspectMark = a.L("OVERVIEW_SUPPORTING_QUEST"), a.L("BRANCH_INSPECT")
assert(supportingMark ~= "OVERVIEW_SUPPORTING_QUEST" and inspectMark ~= "BRANCH_INSPECT")
local function colored(status, color) return "|cff" .. color .. a.L(status) .. "|r" end
local function expectedSupport(kindKey, status, color)
    return supportingMark .. " · " .. a.L(kindKey) .. " · " .. colored(status, color) .. " · " .. inspectMark
end
assert(noteOf(9302) == expectedSupport("PREP_outside", "AVAILABLE", "ffe9b0"), "support-outside keeps the exact supporting composition")
assert(noteOf(9304) == expectedSupport("PREP_inside", "AVAILABLE", "ffe9b0"), "support-inside keeps the exact supporting composition")
assert(noteOf(9306) == expectedSupport("PREP_level", "LOCKED", "f0b080"), "support-level keeps the exact supporting composition")
local function countOccurrences(haystack, needle)
    local count, start = 0, 1
    while true do
        local found = haystack:find(needle, start, true)
        if not found then return count end
        count, start = count + 1, found + #needle
    end
end
local function assertSupportOrder(id, kindKey, status, color)
    local note = noteOf(id)
    local parts = { supportingMark, a.L(kindKey), colored(status, color), inspectMark }
    local cursor = 1
    for _, part in ipairs(parts) do
        local at = note:find(part, cursor, true)
        assert(at, "supporting row keeps SUPPORTING·KIND·STATUS·INSPECT order")
        cursor = at + #part
    end
    for _, part in ipairs({ supportingMark, a.L(kindKey) }) do
        assert(countOccurrences(note, part) == 1, "supporting composition never doubles a mark")
    end
end
assertSupportOrder(9302, "PREP_outside", "AVAILABLE", "ffe9b0")
assertSupportOrder(9304, "PREP_inside", "AVAILABLE", "ffe9b0")
assertSupportOrder(9306, "PREP_level", "LOCKED", "f0b080")
assert(not noteOf(9306):find(a.L("AVAILABLE"), 1, true), "support level gate must not promise availability")
do
    local seen = {}
    for _, pool in ipairs({ u.overviewTexts or {}, u.details }) do
        for _, fs in ipairs(pool) do if fs:IsShown() then seen[#seen + 1] = fs.text end end
    end
    local function position(value) for i, text in ipairs(seen) do if text == value then return i end end end
    assert(position(a.L("OVERVIEW_NEXT_STEPS")), "supporting kind work stays under NEXT")
    assert(not position(a.L("OVERVIEW_KNOWN_STEPS")), "no held steps means no held header beside support work")
    assert(position(a.L("OVERVIEW_UNCERTAIN")), "unknown coverage stays explicit beside support work")
end
for _, r in ipairs(u.actionInspectButtons) do
    if r:IsShown() then
        assert(not r.note.text:find("|cff66dd99", 1, true), "supporting kind work never uses the completed green")
    end
end
rowById(9302).scripts.OnClick()
assert(u.quest == 9302 and u.dungeon == supportDungeon and routes == 0, "support-outside click inspects its own card without routing")
assert(u:BackQuest() and u.quest == nil)
rowById(9304).scripts.OnClick()
assert(u.quest == 9304 and u.dungeon == supportDungeon and routes == 0, "support-inside click inspects its own card without routing")
assert(u:BackQuest() and u.quest == nil)
rowById(9306).scripts.OnClick()
assert(u.quest == 9306 and u.dungeon == supportDungeon and routes == 0, "support-level click inspects its own card without routing")
assert(u:BackQuest() and u.quest == nil)
-- One shared support prerequisite serves two listed parents exactly once.
a.quests[9311] = { id = 9311, name = "Listed four", minLevel = 1, requirementsKnown = true, requires = { { ids = { 9302 } } } }
local sharedDungeon = { key = "controlled-shared", name = "Shared fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = { 9301, 9311 } }
a.dungeons = { kindsDungeon, manyDungeon, supportDungeon, sharedDungeon }
render(sharedDungeon)
local _, shared = summary()
assert(#shared.steps == 1 and shared.steps[1].id == 9302 and shared.steps[1].listedTarget == false, "shared support appears once")
assert(noteOf(9302) == expectedSupport("PREP_outside", "AVAILABLE", "ffe9b0"), "shared support keeps its composition")
-- A kind label colliding with the supporting cue still renders a single mark.
local realLocalize = a.L
a.L = function(key, ...) if key == "PREP_outside" then return realLocalize("OVERVIEW_SUPPORTING_QUEST") end return realLocalize(key, ...) end
render(supportDungeon)
local collided = noteOf(9302)
assert(countOccurrences(collided, supportingMark) == 1, "colliding kind/supporting marks never double")
assert(collided == supportingMark .. " · " .. colored("AVAILABLE", "ffe9b0") .. " · " .. inspectMark, "collision keeps order without the doubled mark")
a.L = realLocalize
render(supportDungeon)
assert(noteOf(9302) == expectedSupport("PREP_outside", "AVAILABLE", "ffe9b0"), "composition recovers after the collision probe")

-- (5) More/Fewer and dungeon switches preserve supporting composition and retire stale clicks.
local supTargets, supSupports = {}, {}
for index = 1, 8 do
    local target, support = 9410 + index, 9430 + index
    supTargets[index], supSupports[index] = target, support
    a.quests[target] = { id = target, name = "Support target " .. index, minLevel = 1, requirementsKnown = true, requires = { { ids = { support } } } }
    a.quests[support] = { id = support, name = "Support pickup " .. index, minLevel = 1, requirementsKnown = true }
end
local supManyDungeon = { key = "controlled-support-many", name = "Support many fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = supTargets }
a.dungeons = { kindsDungeon, manyDungeon, supportDungeon, sharedDungeon, supManyDungeon }
render(supManyDungeon)
local _, supMany = summary()
assert(#supMany.steps == 6 and supMany.remainingSteps == 2, "six-step cap paginates supporting work")
local supMore = u.overviewMoreButton
assert(supMore and supMore:IsShown(), "More control appears past the supporting cap")
assert(noteOf(supSupports[1]) == expectedSupport("PREP_outside", "AVAILABLE", "ffe9b0"), "paged support row keeps its composition")
supMore.scripts.OnClick(supMore)
local _, supExpanded = summary()
assert(#supExpanded.steps == 8 and supExpanded.remainingSteps == 0, "More reveals the supporting tail")
assert(noteOf(supSupports[8]) == expectedSupport("PREP_outside", "AVAILABLE", "ffe9b0"), "supporting composition survives expansion")
local supFewer = u.overviewFewerButton
assert(supFewer and supFewer:IsShown(), "Fewer control appears after supporting expansion")
supFewer.scripts.OnClick(supFewer)
local _, supCompacted = summary()
assert(#supCompacted.steps == 6 and supCompacted.remainingSteps == 2, "Fewer restores the supporting cap")
assert(noteOf(supSupports[1]) == expectedSupport("PREP_outside", "AVAILABLE", "ffe9b0"), "supporting composition survives Fewer")
local staleSupportClick = rowById(supSupports[1]).scripts.OnClick
render(kindsDungeon)
local _, supSwitched = summary()
assert(supSwitched.steps[1].id == 9001, "dungeon switch publishes the new dungeon steps")
staleSupportClick()
assert(u.quest == nil and routes == 0, "retired supporting row cannot inspect after the switch")

-- (6) item-only pickup uses the item mark, not outside; giver/nil/invalid/mixed stay outside, inside stays inside.
a.quests[9501] = { id = 9501, name = "Item starter", minLevel = 1, requirementsKnown = true, start = { itemID = 50001 } }
a.quests[9502] = { id = 9502, name = "Giver starter", minLevel = 1, requirementsKnown = true, start = { npcID = 1234, name = "Giver" } }
a.quests[9503] = { id = 9503, name = "Nil starter", minLevel = 1, requirementsKnown = true }
a.quests[9504] = { id = 9504, name = "Mixed starter", minLevel = 1, requirementsKnown = true, start = { itemID = 50002, npcID = 1234 } }
a.quests[9505] = { id = 9505, name = "Alt starter", minLevel = 1, requirementsKnown = true, start = { itemID = 50003 }, startAlternatives = { { npcID = 5678 } } }
a.quests[9506] = { id = 9506, name = "Bad item", minLevel = 1, requirementsKnown = true, start = { itemID = 0 } }
a.quests[9507] = { id = 9507, name = "Inside item", minLevel = 1, requirementsKnown = true, startsInside = true, start = { itemID = 50004 } }
local itemSingleDungeon = { key = "controlled-item-single", name = "Item single fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = { 9501 } }
local itemMixedDungeon = { key = "controlled-item-mixed", name = "Item mixed fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = { 9502, 9503, 9504, 9505, 9506, 9507 } }
a.dungeons = { kindsDungeon, manyDungeon, supportDungeon, sharedDungeon, supManyDungeon, itemSingleDungeon, itemMixedDungeon }
render(itemSingleDungeon)
local _, itemSingle = summary()
assert(#itemSingle.steps == 1 and itemSingle.steps[1].id == 9501 and itemSingle.steps[1].kind == "pickup" and itemSingle.steps[1].status == "AVAILABLE" and itemSingle.steps[1].listedTarget ~= false, "item-only target stays a listed pickup")
local itemMark = a.L("PREP_item")
assert(itemMark ~= "PREP_item", "item mark needs its own translated string")
assert(itemMark ~= outsideMark and itemMark ~= insideMark, "item mark stays distinct from outside/inside")
local itemNote = noteOf(9501)
assert(itemNote:find(itemMark, 1, true) and not itemNote:find(outsideMark, 1, true), "item-only row carries the item mark instead of outside")
assert(itemNote:find(a.L("AVAILABLE"), 1, true) and itemNote:find(a.L("BRANCH_INSPECT"), 1, true), "item row keeps status/inspect context")
do
    local parts = { itemMark, a.L("AVAILABLE"), a.L("BRANCH_INSPECT") }
    local cursor = 1
    for _, part in ipairs(parts) do
        local at = itemNote:find(part, cursor, true)
        assert(at, "item row keeps ITEM·STATUS·INSPECT order")
        cursor = at + #part
    end
    assert(countOccurrences(itemNote, itemMark) == 1, "item mark never doubles on a target row")
end
rowById(9501).scripts.OnClick()
assert(u.quest == 9501 and u.dungeon == itemSingleDungeon and routes == 0, "item click inspects its own card without routing")
assert(u:BackQuest() and u.quest == nil)
for _, locale in ipairs({"enUS","ruRU","deDE","frFR","esES","itIT","ptBR","koKR","zhCN","zhTW"}) do
    a.db.locale = locale
    render(itemSingleDungeon)
    local mark = a.L("PREP_item")
    assert(mark ~= "PREP_item" and mark:find("%S"), "item mark translated in " .. locale)
    local note = noteOf(9501)
    assert(note:find(mark, 1, true) and not note:find(a.L("PREP_outside"), 1, true), "item mark holds in " .. locale)
end
a.db.locale = "enUS"
render(itemMixedDungeon)
assert(noteOf(9502):find(outsideMark, 1, true) and not noteOf(9502):find(itemMark, 1, true), "giver starter stays outside")
assert(noteOf(9503):find(outsideMark, 1, true) and not noteOf(9503):find(itemMark, 1, true), "nil starter stays outside")
assert(noteOf(9504):find(outsideMark, 1, true) and not noteOf(9504):find(itemMark, 1, true), "mixed starter stays outside")
assert(noteOf(9505):find(outsideMark, 1, true) and not noteOf(9505):find(itemMark, 1, true), "alternative starter stays outside")
assert(noteOf(9506):find(outsideMark, 1, true) and not noteOf(9506):find(itemMark, 1, true), "invalid item starter stays outside")
assert(noteOf(9507):find(insideMark, 1, true) and not noteOf(9507):find(itemMark, 1, true), "inside item starter stays inside")

-- (7) supporting item starter keeps SUPPORTING·ITEM·STATUS·INSPECT without doubles.
a.quests[9611] = { id = 9611, name = "Listed item parent", minLevel = 1, requirementsKnown = true, requires = { { ids = { 9612 } } } }
a.quests[9612] = { id = 9612, name = "Support item", minLevel = 1, requirementsKnown = true, start = { itemID = 50011 } }
local supportItemDungeon = { key = "controlled-support-item", name = "Support item fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = { 9611 } }
a.dungeons = { kindsDungeon, manyDungeon, supportDungeon, sharedDungeon, supManyDungeon, itemSingleDungeon, itemMixedDungeon, supportItemDungeon }
render(supportItemDungeon)
local _, supItem = summary()
assert(#supItem.steps == 1 and supItem.steps[1].id == 9612 and supItem.steps[1].kind == "pickup" and supItem.steps[1].status == "AVAILABLE" and supItem.steps[1].listedTarget == false, "support item appears once as a pickup")
assert(noteOf(9612) == expectedSupport("PREP_item", "AVAILABLE", "ffe9b0"), "support-item keeps the exact supporting composition")
assertSupportOrder(9612, "PREP_item", "AVAILABLE", "ffe9b0")
do
    local note = noteOf(9612)
    assert(countOccurrences(note, itemMark) == 1, "supporting item composition never doubles the item mark")
    assert(not note:find(outsideMark, 1, true), "support-item row never shows the outside mark")
end
rowById(9612).scripts.OnClick()
assert(u.quest == 9612 and u.dungeon == supportItemDungeon and routes == 0, "support-item click inspects its own card without routing")
assert(u:BackQuest() and u.quest == nil)

-- (8) More/Fewer and dungeon switches preserve the item mark and retire stale clicks.
local manyItemIds = {}
for index = 1, 8 do
    local id = 9720 + index
    manyItemIds[index] = id
    a.quests[id] = { id = id, name = "Many item step " .. index, minLevel = 1, requirementsKnown = true, start = { itemID = 60000 + index } }
end
local manyItemDungeon = { key = "controlled-item-many", name = "Item many fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = manyItemIds }
a.dungeons = { kindsDungeon, manyDungeon, supportDungeon, sharedDungeon, supManyDungeon, itemSingleDungeon, itemMixedDungeon, supportItemDungeon, manyItemDungeon }
render(manyItemDungeon)
local _, manyItem = summary()
assert(#manyItem.steps == 6 and manyItem.remainingSteps == 2, "six-step cap paginates item work")
local itemMore = u.overviewMoreButton
assert(itemMore and itemMore:IsShown(), "More control appears past the item cap")
assert(noteOf(manyItemIds[1]):find(itemMark, 1, true) and not noteOf(manyItemIds[1]):find(outsideMark, 1, true), "paged item row keeps its mark")
itemMore.scripts.OnClick(itemMore)
local _, itemExpanded = summary()
assert(#itemExpanded.steps == 8 and itemExpanded.remainingSteps == 0, "More reveals the item tail")
assert(noteOf(manyItemIds[8]):find(itemMark, 1, true) and not noteOf(manyItemIds[8]):find(outsideMark, 1, true), "item mark survives expansion")
local itemFewer = u.overviewFewerButton
assert(itemFewer and itemFewer:IsShown(), "Fewer control appears after item expansion")
itemFewer.scripts.OnClick(itemFewer)
local _, itemCompacted = summary()
assert(#itemCompacted.steps == 6 and itemCompacted.remainingSteps == 2, "Fewer restores the item cap")
assert(noteOf(manyItemIds[1]):find(itemMark, 1, true) and not noteOf(manyItemIds[1]):find(outsideMark, 1, true), "item mark survives Fewer")
local staleItemClick = rowById(manyItemIds[1]).scripts.OnClick
render(kindsDungeon)
local _, itemSwitched = summary()
assert(itemSwitched.steps[1].id == 9001, "dungeon switch publishes the new dungeon steps")
assert(noteOf(9001):find(outsideMark, 1, true), "new dungeon keeps its own outside mark")
staleItemClick()
assert(u.quest == nil and routes == 0, "retired item-dungeon row cannot inspect after the switch")

-- (9) DP-5 OVERVIEW-EMPTY-START-ALTERNATIVES: empty list counts as absent, malformed/secret stay outside.
a.quests[9731] = { id = 9731, name = "Empty alt item", minLevel = 1, requirementsKnown = true, start = { itemID = 50031 }, startAlternatives = {} }
a.quests[9732] = { id = 9732, name = "Nil alt item", minLevel = 1, requirementsKnown = true, start = { itemID = 50032 } }
a.quests[9733] = { id = 9733, name = "Nonempty alt item", minLevel = 1, requirementsKnown = true, start = { itemID = 50033 }, startAlternatives = { { npcID = 5678 } } }
a.quests[9734] = { id = 9734, name = "Listed empty parent", minLevel = 1, requirementsKnown = true, requires = { { ids = { 9735 } } } }
a.quests[9735] = { id = 9735, name = "Support empty alt item", minLevel = 1, requirementsKnown = true, start = { itemID = 50034 }, startAlternatives = {} }
a.quests[9741] = { id = 9741, name = "Malformed alt item", minLevel = 1, requirementsKnown = true, start = { itemID = 50035 }, startAlternatives = 5 }
local emptySingleDungeon = { key = "controlled-empty-single", name = "Empty single fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = { 9731 } }
local emptyGuardDungeon = { key = "controlled-empty-guard", name = "Empty guard fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = { 9731, 9732, 9733 } }
local supportEmptyDungeon = { key = "controlled-support-empty", name = "Support empty fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = { 9734 } }
local malformedDungeon = { key = "controlled-malformed-alt", name = "Malformed alt fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = { 9741 } }
a.dungeons = { kindsDungeon, manyDungeon, supportDungeon, sharedDungeon, supManyDungeon, itemSingleDungeon, itemMixedDungeon, supportItemDungeon, manyItemDungeon, emptySingleDungeon, emptyGuardDungeon, supportEmptyDungeon, malformedDungeon }
render(emptySingleDungeon)
local _, emptySingle = summary()
assert(#emptySingle.steps == 1 and emptySingle.steps[1].id == 9731 and emptySingle.steps[1].kind == "pickup", "empty-alternative item stays a listed pickup")
local emptyNote = noteOf(9731)
assert(emptyNote:find(itemMark, 1, true) and not emptyNote:find(outsideMark, 1, true), "item + {} carries PREP_item without PREP_outside")
assert(emptyNote:find(a.L("BRANCH_INSPECT"), 1, true), "empty-alternative item row keeps the inspect action")
rowById(9731).scripts.OnClick()
assert(u.quest == 9731 and u.dungeon == emptySingleDungeon and routes == 0, "empty-alternative item click inspects its own card without routing")
assert(u:BackQuest() and u.quest == nil)
render(emptyGuardDungeon)
assert(noteOf(9732):find(itemMark, 1, true) and not noteOf(9732):find(outsideMark, 1, true), "item + nil stays PREP_item")
assert(noteOf(9733):find(outsideMark, 1, true) and not noteOf(9733):find(itemMark, 1, true), "item + {{npcID}} stays PREP_outside")
render(supportEmptyDungeon)
local _, supEmpty = summary()
assert(#supEmpty.steps == 1 and supEmpty.steps[1].id == 9735 and supEmpty.steps[1].listedTarget == false, "support item + {} appears once as a supporting pickup")
assert(noteOf(9735) == expectedSupport("PREP_item", "AVAILABLE", "ffe9b0"), "support item + {} keeps the exact supporting composition")
assertSupportOrder(9735, "PREP_item", "AVAILABLE", "ffe9b0")
do
    local note = noteOf(9735)
    assert(countOccurrences(note, itemMark) == 1, "supporting empty-alternative composition never doubles the item mark")
    assert(not note:find(outsideMark, 1, true), "support empty-alternative row never shows the outside mark")
end
rowById(9735).scripts.OnClick()
assert(u.quest == 9735 and u.dungeon == supportEmptyDungeon and routes == 0, "support empty-alternative click inspects its own card without routing")
assert(u:BackQuest() and u.quest == nil)
render(malformedDungeon)
local _, malformed = summary()
assert(#malformed.steps == 1 and malformed.steps[1].id == 9741, "malformed alternatives keep a listed pickup step")
assert(noteOf(9741):find(outsideMark, 1, true) and not noteOf(9741):find(itemMark, 1, true), "malformed alternatives stay PREP_outside without a crash")
do
    local secretAlt = {}
    local savedChecker = issecretvalue
    a.quests[9742] = { id = 9742, name = "Secret alt item", minLevel = 1, requirementsKnown = true, start = { itemID = 50036 }, startAlternatives = secretAlt }
    issecretvalue = function(value) return value == secretAlt end
    local secretDungeon = { key = "controlled-secret-alt", name = "Secret alt fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = { 9742 } }
    a.dungeons[#a.dungeons + 1] = secretDungeon
    render(secretDungeon)
    local _, secretModel = summary()
    assert(#secretModel.steps == 1 and secretModel.steps[1].id == 9742, "secret alternatives keep a listed pickup step")
    assert(noteOf(9742):find(outsideMark, 1, true) and not noteOf(9742):find(itemMark, 1, true), "secret alternatives stay PREP_outside without a crash")
    issecretvalue = savedChecker
end
local manyEmptyIds = {}
for index = 1, 8 do
    local id = 9760 + index
    manyEmptyIds[index] = id
    a.quests[id] = { id = id, name = "Many empty step " .. index, minLevel = 1, requirementsKnown = true, start = { itemID = 60030 + index }, startAlternatives = {} }
end
local manyEmptyDungeon = { key = "controlled-empty-many", name = "Empty many fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = manyEmptyIds }
a.dungeons[#a.dungeons + 1] = manyEmptyDungeon
render(manyEmptyDungeon)
local _, manyEmpty = summary()
assert(#manyEmpty.steps == 6 and manyEmpty.remainingSteps == 2, "six-step cap paginates empty-alternative work")
local emptyMore = u.overviewMoreButton
assert(emptyMore and emptyMore:IsShown(), "More control appears past the empty-alternative cap")
assert(noteOf(manyEmptyIds[1]):find(itemMark, 1, true) and not noteOf(manyEmptyIds[1]):find(outsideMark, 1, true), "paged empty-alternative row keeps PREP_item")
emptyMore.scripts.OnClick(emptyMore)
local _, emptyExpanded = summary()
assert(#emptyExpanded.steps == 8 and emptyExpanded.remainingSteps == 0, "More reveals the empty-alternative tail")
assert(noteOf(manyEmptyIds[8]):find(itemMark, 1, true) and not noteOf(manyEmptyIds[8]):find(outsideMark, 1, true), "empty-alternative mark survives expansion")
local emptyFewer = u.overviewFewerButton
assert(emptyFewer and emptyFewer:IsShown(), "Fewer control appears after empty-alternative expansion")
emptyFewer.scripts.OnClick(emptyFewer)
local _, emptyCompacted = summary()
assert(#emptyCompacted.steps == 6 and emptyCompacted.remainingSteps == 2, "Fewer restores the empty-alternative cap")
assert(noteOf(manyEmptyIds[1]):find(itemMark, 1, true) and not noteOf(manyEmptyIds[1]):find(outsideMark, 1, true), "empty-alternative mark survives Fewer")

-- (10) DP-5 OVERVIEW-SUMMON-KIND-COHERENCE: summon pickups map to uncertain, not outside/item/inside.
a.quests[9801] = { id = 9801, name = "Summon pickup", minLevel = 1, requirementsKnown = true, start = { objectID = 112877, summonItem = { itemID = 7667 } } }
a.quests[9802] = { id = 9802, name = "Summon inside", minLevel = 1, requirementsKnown = true, startsInside = true, start = { objectID = 112877, summonItem = { itemID = 7667 } } }
local summonDungeon = { key = "controlled-summon", name = "Summon fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = { 9801, 9802 } }
a.dungeons[#a.dungeons + 1] = summonDungeon
render(summonDungeon)
local _, summonModel = summary()
assert(#summonModel.steps == 2 and summonModel.steps[1].id == 9801 and summonModel.steps[1].kind == "pickup", "summon pickup stays a listed pickup")
assert(summonModel.steps[2].id == 9802 and summonModel.steps[2].kind == "inside", "summon inside stays a listed inside step")
local summonUncertain = a.L("PREP_uncertain")
assert(summonUncertain ~= "PREP_uncertain" and summonUncertain:find("%S"), "summon coherence needs the translated uncertain mark")
local summonNote = noteOf(9801)
assert(summonNote:find(summonUncertain, 1, true), "summon pickup carries PREP_uncertain")
assert(not summonNote:find(outsideMark, 1, true), "summon pickup never shows PREP_outside")
assert(not summonNote:find(itemMark, 1, true), "summon pickup never shows PREP_item")
assert(summonNote:find(a.L("BRANCH_INSPECT"), 1, true), "summon pickup keeps the inspect action")
local summonInsideNote = noteOf(9802)
assert(summonInsideNote:find(summonUncertain, 1, true), "summon inside carries PREP_uncertain")
assert(not summonInsideNote:find(insideMark, 1, true), "summon inside never shows PREP_inside")
rowById(9801).scripts.OnClick()
assert(u.quest == 9801 and u.dungeon == summonDungeon and routes == 0, "summon pickup click inspects its own card without routing")
assert(u:BackQuest() and u.quest == nil)
rowById(9802).scripts.OnClick()
assert(u.quest == 9802 and u.dungeon == summonDungeon and routes == 0, "summon inside click inspects its own card without routing")
assert(u:BackQuest() and u.quest == nil)

-- (11) supporting summon keeps SUPPORTING·UNCERTAIN·STATUS·INSPECT exactly once.
a.quests[9811] = { id = 9811, name = "Listed summon parent", minLevel = 1, requirementsKnown = true, requires = { { ids = { 9812 } } } }
a.quests[9812] = { id = 9812, name = "Support summon", minLevel = 1, requirementsKnown = true, start = { objectID = 112877, summonItem = { itemID = 7667 } } }
local supportSummonDungeon = { key = "controlled-support-summon", name = "Support summon fixture", minLevel = 1, maxLevel = 60, coverage = "partial", quests = { 9811 } }
a.dungeons[#a.dungeons + 1] = supportSummonDungeon
render(supportSummonDungeon)
local _, supSummon = summary()
assert(#supSummon.steps == 1 and supSummon.steps[1].id == 9812 and supSummon.steps[1].kind == "pickup" and supSummon.steps[1].status == "AVAILABLE" and supSummon.steps[1].listedTarget == false, "support summon appears once as a supporting pickup")
assert(noteOf(9812) == expectedSupport("PREP_uncertain", "AVAILABLE", "ffe9b0"), "support-summon keeps the exact supporting composition")
assertSupportOrder(9812, "PREP_uncertain", "AVAILABLE", "ffe9b0")
do
    local note = noteOf(9812)
    assert(countOccurrences(note, summonUncertain) == 1, "supporting summon composition never doubles the uncertain mark")
    assert(countOccurrences(note, supportingMark) == 1, "supporting summon composition keeps supporting once")
    assert(not note:find(outsideMark, 1, true), "support-summon row never shows the outside mark")
    assert(not note:find(itemMark, 1, true), "support-summon row never shows the item mark")
end
rowById(9812).scripts.OnClick()
assert(u.quest == 9812 and u.dungeon == supportSummonDungeon and routes == 0, "support-summon click inspects its own card without routing")
assert(u:BackQuest() and u.quest == nil)

-- (12) summonItem mutation retires overview ownership.
render(summonDungeon)
local summonBinding = summary()
assert(summonBinding.current() and summonBinding.rawProof(), "summon overview starts current")
local staleSummonClick = rowById(9801).scripts.OnClick
local originalSummon = a.quests[9801].start.summonItem
a.quests[9801].start.summonItem = nil
assert(summonBinding.rawProof() == false, "nil summonItem retires rawProof")
assert(summonBinding.current() == false, "nil summonItem retires current")
staleSummonClick()
assert(u.quest == nil and routes == 0, "retired summon row cannot inspect after nil mutation")
a.quests[9801].start.summonItem = originalSummon
render(summonDungeon)
local summonBinding2 = summary()
assert(summonBinding2.current() and summonBinding2.rawProof(), "restored summon overview is current again")
local staleSummonClick2 = rowById(9801).scripts.OnClick
a.quests[9801].start.summonItem = { itemID = 99999 }
assert(summonBinding2.rawProof() == false, "replaced summonItem retires rawProof")
assert(summonBinding2.current() == false, "replaced summonItem retires current")
staleSummonClick2()
assert(u.quest == nil and routes == 0, "retired summon row cannot inspect after replacement")
a.quests[9801].start.summonItem = originalSummon
render(summonDungeon)
assert(noteOf(9801):find(summonUncertain, 1, true), "composition recovers after the mutation probe")

print("Overview kinds UI: PASS (pickup/inside distinct + order + clicks; level/unknown under NEXT without availability or green; More/Fewer and dungeon-switch ownership; supporting-kind composition without doubles)")
