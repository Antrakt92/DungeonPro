-- Classic-derived wing assignments remain distinct from Forever quest facts.
local f = assert(loadfile("tests/client_ui.lua"))("fixture")
local a, u = f.addon, f.addon.UI
issecretvalue = function() return false end
GetLocale = function() return "enUS" end
C_Timer = { After = function() end }
f.eventFrame.scripts.OnEvent(f.eventFrame, "ADDON_LOADED", "DungeonPro")
u:Toggle(); a.db.locale = "enUS"; u.preparation = false
local wings, originalSources = {}, {}
for id, q in pairs(a.quests) do originalSources[id] = q.source end
for _, d in ipairs(a.dungeons) do if d.complexKey == "sm" then wings[d.wing] = d end end
local expected = { graveyard = {1051}, library = {1049, 1048, 1053}, armory = {1048, 1053}, cathedral = {1048, 1053} }
local function draw(d, all, faction)
    a.Context = function() return { level = 60, faction = faction or "Horde", class = "MAGE",
        completed = function() return false end, active = function() return false end } end
    u.search = ""; u.dungeon, u.quest = d, nil; a.char.selectedDungeon = d.key
    u.includeUnavailable = all; u.questTreeRoot, u.questTreeDungeon = nil, nil
    u:RefreshQuests()
end
local function questRow(id)
    for _, row in ipairs(u.rows) do if row:IsShown() and row.questID == id then return row end end
end
local function hasDetail(text)
    for _, field in ipairs(u.details) do
        if field:IsShown() and field.text and field.text:find(text, 1, true) then return true end
    end
    return false
end
for wing, ids in pairs(expected) do
    local d = assert(wings[wing])
    assert(#d.classicQuests == #ids, "explicit Classic edge count " .. wing)
    for index, id in ipairs(ids) do assert(d.classicQuests[index] == id) end
    for _, faction in ipairs({"Horde", "Alliance"}) do for _, all in ipairs({false, true}) do
        draw(d, all, faction)
        assert(u.currentPlan and u.currentPlan.unknown and not u.currentPlan.ready, "partial coverage never certifies prepared")
        assert(not questRow(96800) and not questRow(1113), "unresolved/flexible shared quests never acquire a wing")
        if wing == "graveyard" then
            assert((questRow(1051) ~= nil) == (all or faction == "Horde"), "legitimate Horde pickup vs Alliance empty wing")
        end
        for _, id in ipairs(ids) do
            local row = questRow(id)
            if row then
                local key = (id == 1048 or id == 1053) and "SM_CLASSIC_MULTI_WING" or "SM_CLASSIC_QUEST"
                assert(row.note.text:find(a.L(key), 1, true), "visible Classic/multiwing middle note " .. id)
            end
        end
    end end
    draw(d, true)
    local model = assert(u:ScarletDiscoveryScope(d))
    assert(model.current() and #model.classicIDs == #ids)
    assert(model.wingCounts[1048] == 3 and model.wingCounts[1053] == 3, "boss quests span three wings")
    local id = ids[1]
    local key = (id == 1048 or id == 1053) and "SM_CLASSIC_MULTI_WING" or "SM_CLASSIC_QUEST"
    assert(questRow(id)).scripts.OnClick()
    assert(u.quest == id and hasDetail(a.L(key)), "selected quest caption retains Classic provenance")
    for _, mutation in ipairs({"member", "source", "order", "helper"}) do
        draw(d, true)
        local click = assert(questRow(id)).scripts.OnClick
        local first, source, helper = d.classicQuests[1], d.classicSource, u.ScarletClassicCaption
        if mutation == "member" then d.classicQuests[1] = 96800
        elseif mutation == "source" then d.classicSource = source .. "?changed=1"
        elseif mutation == "order" then
            if #d.classicQuests > 1 then d.classicQuests[1], d.classicQuests[2] = d.classicQuests[2], d.classicQuests[1]
            else d.classicQuests = {first} end
        else u.ScarletClassicCaption = function() return "foreign" end end
        click()
        assert(u.quest == nil and u.dungeon == d, "mutated Classic " .. mutation .. " retires old quest action")
        if mutation == "order" and #d.classicQuests > 1 then
            d.classicQuests[1], d.classicQuests[2] = d.classicQuests[2], d.classicQuests[1]
        end
        d.classicQuests[1], d.classicSource, u.ScarletClassicCaption = first, source, helper
    end
end
draw(wings.library, true)
assert(not questRow(1050).note.text:find(a.L("SM_CLASSIC_QUEST"), 1, true), "direct Forever edge is not relabeled Classic")
local scope = assert(u:ScarletDiscoveryScope(wings.library))
scope.classicIDs[1] = 96800
assert(not scope.rawCurrent() and not scope.current(), "returned provenance DTO cannot be rewritten")
scope = assert(u:ScarletDiscoveryScope(wings.library))
scope.wingCounts[1048] = 1
assert(not scope.rawCurrent(), "multiwing DTO cannot turn into exclusive assignment")
do
    local d, saved = wings.library, wings.library.classicSource
    d.classicSource = saved:gsub("/classic/", "/forever/")
    assert(u:ScarletDiscoveryScope(d) == nil, "wrong-flavor source cannot certify Classic provenance")
    d.classicSource = saved
    local hidden = {}; local original = issecretvalue
    issecretvalue = function(value) return rawequal(value, hidden) end
    d.classicSource = hidden
    assert(u:ScarletDiscoveryScope(d) == nil, "restricted provenance source is rejected")
    d.classicSource, issecretvalue = saved, original
end
for id, source in pairs(originalSources) do assert(a.quests[id].source == source, "quest source remains Forever-owned") end
print("Scarlet Classic membership UI: PASS (actual catalogue, all wings, character filters, visible provenance, multiwing, retirement)")
