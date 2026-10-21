-- Reviewed dungeon objectives retain unknown acceptance and character restrictions.
local f = assert(loadfile("tests/client_ui.lua"))("fixture")
local a, u = f.addon, f.addon.UI
issecretvalue = function() return false end
GetLocale = function() return "enUS" end
C_Timer = { After = function() end }
f.eventFrame.scripts.OnEvent(f.eventFrame, "ADDON_LOADED", "DungeonPro")
u:Toggle(); a.db.locale = "enUS"; u.preparation = false
local dungeons = {}
for _, d in ipairs(a.dungeons) do dungeons[d.key] = d end
local expected = {
    [1701] = { dungeon = "rfk", faction = "Alliance", class = "WARRIOR" },
    [1838] = { dungeon = "rfk", faction = "Horde", class = "WARRIOR" },
    [1192] = { dungeon = "ulda", repeatable = true },
    [5305] = { dungeon = "strat", profession = "BLACKSMITHING" },
    [5307] = { dungeon = "strat", profession = "BLACKSMITHING" },
    [9257] = { dungeon = "strat" },
}
for id, facts in pairs(expected) do
    local q = assert(a.quests[id], "reviewed quest definition " .. id)
    assert(q.requirementsKnown == false, "reviewed objectives do not certify acceptance")
    assert(q.source:match("^https://www%.wowhead%.com/forever/quest=" .. id .. "/"), "primary Forever source")
    local count = 0
    for _, member in ipairs(assert(dungeons[facts.dungeon]).quests) do if member == id then count = count + 1 end end
    assert(count == 1, "one canonical root in the evidenced dungeon " .. id)
    if facts.faction then assert(#q.factions == 1 and q.factions[1] == facts.faction) end
    if facts.class then assert(#q.classes == 1 and q.classes[1] == facts.class) end
    if facts.repeatable then assert(q.repeatable == true) end
    if facts.profession then assert(q.profession == facts.profession) end
end
local function draw(key, faction, class, all, id)
    a.Context = function() return { level = 60, faction = faction, class = class,
        completed = function() return false end, active = function() return false end } end
    u.search = ""; u.dungeon, u.quest = dungeons[key], id
    a.char.selectedDungeon = key; u.includeUnavailable = all
    u.questTreeRoot, u.questTreeDungeon = nil, nil
    u:Refresh()
end
local function rowFor(id)
    for _, row in ipairs(u.rows) do if row:IsShown() and row.questID == id then return row end end
end
local function detailHas(text)
    for _, field in ipairs(u.details) do
        if field:IsShown() and type(field.text) == "string" and field.text:find(text, 1, true) then return true end
    end
    return false
end
for _, faction in ipairs({ "Alliance", "Horde" }) do
    for _, class in ipairs({ "WARRIOR", "MAGE" }) do
        for _, all in ipairs({ false, true }) do
            draw("rfk", faction, class, all)
            for _, id in ipairs({ 1701, 1838 }) do
                local eligible = class == "WARRIOR" and faction == expected[id].faction
                assert((rowFor(id) ~= nil) == (all or eligible), "Mine/All respects actual faction and class " .. id)
                local state = u.engine:State(id)
                assert(state.status == (eligible and "UNKNOWN" or "UNAVAILABLE"))
                if eligible then assert(state.reason == "requirements") end
            end
            assert(u.currentPlan and not u.currentPlan.ready, "new roots do not certify prepared")
        end
    end
end
local professionQueries = 0
for _, name in ipairs({ "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo" }) do
    _G[name] = function() professionQueries = professionQueries + 1; error("Display must not inspect profession eligibility") end
end
for _, id in ipairs({ 1192, 5305, 5307, 9257 }) do
    for _, faction in ipairs({ "Alliance", "Horde" }) do
        for _, class in ipairs({ "WARRIOR", "MAGE" }) do
            draw(expected[id].dungeon, faction, class, false, id)
            assert(rowFor(id), "profession/event context does not invent a character filter")
            local state = u.engine:State(id)
            assert(state.status == "UNKNOWN" and state.reason == "requirements" and not u.action)
            assert(rowFor(id).note.text:find(a.L("UNKNOWN_REQUIREMENTS"), 1, true))
            assert(detailHas(a.L("REASON_requirementsUnknown")) and not u.currentPlan.ready)
        end
    end
end
local localeCount = 0
for locale in pairs(a.locales) do
    a.db.locale = locale
    for _, id in ipairs({ 5305, 5307 }) do
        draw("strat", "Alliance", "MAGE", false, id)
        assert(detailHas(a.L("PROFESSION", a.L("PROFESSION_BLACKSMITHING"))), "localized profession context")
        assert(rowFor(id).note.text:find(a.L("UNKNOWN_REQUIREMENTS"), 1, true))
        assert(detailHas(a.L("REASON_requirementsUnknown")) and not u.action)
    end
    draw("ulda", "Alliance", "MAGE", false, 1192)
    assert(detailHas(a.L("REPEATABLE")), "repeatable collection remains explicit")
    assert(not detailHas(a.L("PROFESSION", a.L("PROFESSION_BLACKSMITHING"))), "recycled journal clears profession")
    localeCount = localeCount + 1
end
assert(localeCount == 10 and professionQueries == 0)
a.db.locale = "enUS"
local q = a.quests[5305]
for _, value in ipairs({ false, 123, "UNREVIEWED_PROFESSION" }) do
    q.profession = value
    draw("strat", "Alliance", "MAGE", false, 5305)
    assert(rowFor(5305) and u.engine:State(5305).status == "UNKNOWN" and not u.action)
    assert(not detailHas(a.L("PROFESSION", a.L("PROFESSION_BLACKSMITHING"))))
end
q.profession = "BLACKSMITHING"
for _, helper in ipairs({ "Clean", "Read" }) do
    q.profession = nil
    draw("strat", "Alliance", "MAGE", false, 5305)
    q.profession = "BLACKSMITHING"
    local original, fired = a[helper], false
    if helper == "Clean" then
        a.Clean = function(value, kind)
            if value == "BLACKSMITHING" and kind == "string" and not fired then
                fired = true; a.Clean = original
            end
            return original(value, kind)
        end
    else
        a.Read = function(fn, kind, ...)
            if select(1, ...) == "PROFESSION_BLACKSMITHING" and not fired then
                fired = true; a.Read = original
            end
            return original(fn, kind, ...)
        end
    end
    u:RefreshDetail(); a[helper] = original
    assert(fired, "profession " .. helper .. " replacement exercised")
    assert(not detailHas(a.L("PROFESSION", a.L("PROFESSION_BLACKSMITHING"))), "retired metadata " .. helper .. " cannot publish profession")
end
for _, mode in ipairs({ "source", "helper", "reentry" }) do
    q.profession = nil
    draw("strat", "Alliance", "MAGE", false, 5305)
    q.profession = "BLACKSMITHING"
    local localize, fired = a.L, false
    a.L = function(key, ...)
        if key == "PROFESSION_BLACKSMITHING" and not fired then
            fired = true
            if mode == "source" then q.profession = nil
            elseif mode == "helper" then a.L = localize
            else u.quest = 9257; u:RefreshDetail() end
        end
        return localize(key, ...)
    end
    u:RefreshDetail(); a.L = localize
    assert(fired, "profession localization callback exercised")
    assert(not detailHas(a.L("PROFESSION", a.L("PROFESSION_BLACKSMITHING"))), "retired metadata cannot publish stale profession")
    if mode == "reentry" then assert(u.quest == 9257 and u.renderedQuest == 9257) end
    q.profession = "BLACKSMITHING"
end
assert(professionQueries == 0)
print("Reviewed quest additions UI: PASS (six roots, Mine/All, class/faction, unknown requirements, repeatable, ten-locales profession, retirement)")
