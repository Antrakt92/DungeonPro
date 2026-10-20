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

print("Overview kinds UI: PASS (pickup/inside distinct + order + clicks; level/unknown under NEXT without availability or green; More/Fewer and dungeon-switch ownership)")
