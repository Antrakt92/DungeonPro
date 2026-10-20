-- Scarlet four-wing UI regression: exact canonical profile, names, discovery scope,
-- shared-quest source-search retirement. Frozen handoff 1730 v5 chain only.
-- No fifth legacy sm row, no invented wing membership, unknown stays unknown.

-- Section 1: independent root32 four-wing profile guards on generated data.
local native = {}
assert(loadfile("Database/Catalog.lua"))("DungeonPro", native)
assert(#native.dungeons == 32, "root32 catalogue members")
local sharedNine = { 96800, 1049, 1113, 1051, 1048, 1053, 1160, 1050, 1951 }
local wings = {}
for _, d in ipairs(native.dungeons) do
    if d.key == "sm" then error("fifth legacy sm row forbidden") end
    if d.key and d.key:match("^sm_") then wings[#wings + 1] = d end
    if d.complexKey == "sm" or d.wing == "graveyard" or d.wing == "library"
        or d.wing == "armory" or d.wing == "cathedral" then
        assert(d.key and d.key:match("^sm_"), "Scarlet metadata only on wing rows")
    end
end
assert(#wings == 4, "exactly four wings")
local expectedActivity = { sm_graveyard = 805, sm_library = 829, sm_armory = 827, sm_cathedral = 828 }
local expectedRoots = { sm_graveyard = {}, sm_library = { 1050, 1160, 1951 }, sm_armory = {}, sm_cathedral = {} }
for _, d in ipairs(wings) do
    assert(expectedActivity[d.key] == d.activityID, "exact activity " .. d.key)
    assert(d.wing == d.key:match("^sm_(.+)$") and d.key == "sm_" .. d.wing, "wing identity " .. d.key)
    assert(d.complexKey == "sm" and d.levelScope == "complex", "complex metadata " .. d.key)
    assert(d.coverage == "partial", "partial coverage " .. d.key)
    assert(d.minLevel == 28 and d.maxLevel == 45, "complex band 28-45 " .. d.key)
    assert(d.instanceID == 189, "instance 189 " .. d.key)
    assert(type(d.entrance) == "table" and d.entrance.gameMapID == 189
        and d.entrance.mapID == 1420 and d.entrance.scope == "shared"
        and d.entrance.kind == "approach", "shared approach entrance " .. d.key)
    assert(#d.sharedQuests == 9, "shared nine " .. d.key)
    for i, id in ipairs(sharedNine) do assert(d.sharedQuests[i] == id, "shared order " .. d.key) end
    local roots = expectedRoots[d.key]
    assert(#d.quests == #roots, "roots count " .. d.key)
    for i, id in ipairs(roots) do assert(d.quests[i] == id, "root " .. d.key) end
    for _, id in ipairs(d.quests) do
        local found = false
        for _, shared in ipairs(d.sharedQuests) do if shared == id then found = true end end
        assert(found, "wing roots belong to shared discovery " .. d.key)
    end
end
local questCount = 0
for _, record in pairs(native.quests) do questCount = questCount + 1 end
assert(questCount == 571, "no quest definition changes")
for _, d in ipairs(wings) do
    for _, id in ipairs(d.sharedQuests) do assert(native.quests[id], "shared quest defined " .. id) end
end
print("PASS root32 exact four-wing profile, no fifth sm, library-only roots")

-- Section 2: exact four-wing DungeonName guards (client-names v5 inline harness core).
local addon = {}
issecretvalue = function() return false end
GetLocale = function() return "enUS" end
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Locales/Strings.lua"))("DungeonPro", addon)
assert(loadfile("Locales/Translations.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
addon.db = { locale = "enUS" }
local zoneCalls = 0
GetRealZoneText = function(id) zoneCalls = zoneCalls + 1; assert(id == 189); return "GENERIC SHARED" end
C_LFGList = nil
local activities = { graveyard = 805, library = 829, armory = 827, cathedral = 828 }
local function wingRow(wing, activity)
    return { key = "sm_" .. wing, name = "Scarlet Monastery - " .. wing,
        wing = wing, activityID = activity, complexKey = "sm", instanceID = 189 }
end
local expectedLabels = {
    enUS = { graveyard = "Scarlet Monastery - Graveyard", library = "Scarlet Monastery - Library",
        armory = "Scarlet Monastery - Armory", cathedral = "Scarlet Monastery - Cathedral" },
    ruRU = { graveyard = "Монастырь Алого ордена: кладбище", library = "Монастырь Алого ордена: библиотека",
        armory = "Монастырь Алого ордена: оружейная", cathedral = "Монастырь Алого ордена: собор" },
}
for locale, labels in pairs(expectedLabels) do
    addon.db.locale = locale
    for wing, activity in pairs(activities) do
        assert(addon.DungeonName(wingRow(wing, activity)) == labels[wing], "exact wing " .. locale .. "/" .. wing)
    end
end
addon.db.locale = "itIT"
assert(addon.DungeonName(wingRow("library", 829)) == expectedLabels.enUS.library, "Italian observed English fallback")
addon.db.locale = "enUS"
local malformed = wingRow("library", 829); malformed.activityID = "829"
assert(addon.DungeonName(malformed) == malformed.name, "malformed tuple keeps source name")
local secret = {}
issecretvalue = function(v) return v == secret end
local restricted = wingRow("library", 829); restricted.wing = secret
assert(addon.DungeonName(restricted) == "", "restricted metadata rejected")
assert(zoneCalls == 0, "wing names never consult generic shared-map name")
print("PASS exact four-wing DungeonName labels, fallback, restricted rejection")

-- Section 3: real discovery scope + shared-quest source-search retirement.
local f = assert(loadfile("tests/client_ui.lua"))("fixture")
local a, ui = f.addon, f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame, "ADDON_LOADED", "DungeonPro"); ui:Toggle()
ui.includeUnavailable = true; ui.preparation = false
local sharedIDs = { 991801, 991802, 991803 }
for _, id in ipairs(sharedIDs) do a.quests[id] = { id = id, name = "Shared " .. id, minLevel = 1, requirementsKnown = false } end
local group = {}
for _, wing in ipairs({ "graveyard", "library", "armory", "cathedral" }) do
    group[#group + 1] = { key = "sm_" .. wing, name = "Wing " .. wing, quests = {}, coverage = "partial",
        complexKey = "sm", wing = wing, activityID = activities[wing], instanceID = 189,
        levelScope = "complex", sharedQuests = { 991801, 991802, 991803 }, minLevel = 28, maxLevel = 45 }
end
a.dungeons = group
local scopeGetter = ui.ScarletDiscoveryScope
assert(type(scopeGetter) == "function", "helper present")
local model = a.Read(scopeGetter, "table", ui, group[2])
assert(model and model.current() and model.rawCurrent() and #model.ids == 3 and not model.legacy, "real helper builds wing scope")
a.char.selectedDungeon = "sm"
local legacy = a.Read(scopeGetter, "table", ui, nil)
assert(legacy and legacy.legacy and legacy.current(), "legacy sm selection stays chooser")
group[1].sharedQuests[1] = 1049
assert(not a.Read(scopeGetter, "table", ui, group[1]), "membership mutation rejected")
group[1].sharedQuests[1] = 991801
local function draw() a.char.selectedDungeon = group[1].key; ui.dungeon = group[1]; ui.quest = nil; ui.questTreeRoot = nil; ui.questTreeDungeon = nil; ui:RefreshQuests() end
local function sharedRows()
    local out = {}
    for _, r in ipairs(ui.rows) do if r:IsShown() and r.sharedDiscovery then out[#out + 1] = r end end
    return out
end
draw()
assert(#sharedRows() == 3, "shared roots discoverable")
assert(ui.currentPlan.notice == "SM_PARTIAL_WING" and not ui.currentPlan.ready and ui.currentPlan.unknown, "partial empty stays unknown")
local row = sharedRows()[1]
local click, inspect, opened = row.scripts.OnClick, ui.InspectQuest, nil
ui.InspectQuest = function(self, id) opened = id end
click(); assert(opened == sharedIDs[1], "ordinary detail inspect")
opened = nil; group[1].sharedQuests[2] = 991804; click(); assert(opened == nil, "source-search membership mutation retires click")
group[1].sharedQuests[2] = 991802
draw(); row = sharedRows()[1]; click = row.scripts.OnClick
a.quests[sharedIDs[1]].name = "Changed"; opened = nil; click(); assert(opened == nil, "definition mutation retires click")
a.quests[sharedIDs[1]].name = "Shared " .. sharedIDs[1]
ui.ScarletDiscoveryScope = function() return nil end
opened = nil; click(); assert(opened == nil, "scope getter replacement retires")
ui.ScarletDiscoveryScope = scopeGetter
ui.InspectQuest = inspect
print("PASS real helper scope, shared discovery, source-search retirement")
print("Scarlet wings UI checks passed (no native-client validation)")
