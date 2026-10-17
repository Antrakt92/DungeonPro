local addon, secret = {}, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Database/SearchCaseFold.lua"))("DungeonPro", addon)
assert(loadfile("Core/Search.lua"))("DungeonPro", addon)
issecretvalue = function(value) return value == secret end
local function same(left, right) assert(addon.SearchFold(left) == addon.SearchFold(right), left) end
same("DeAdMiNeS", "deadmines")
same("ОГНЕННАЯ ПРОПАСТЬ", "Огненная Пропасть")
same("ТЁМНЫЕ ПЕЩЕРЫ", "тёмные пещеры")
same("ÉCOLE À L'ENTRÉE", "école à l'entrée")
same("Straße", "STRASSE")
same("MARAUDÓN", "maraudón")
same("AÇÃO", "ação")
same("Σίσυφος", "ΣΊΣΥΦΟΣ")
same("𐐀𐐁", "𐐨𐐩")
for _, text in ipairs({ "死亡礦坑", "죽음의 폐광", "Мёртвые копи · Deadmines", "🙂 dungeon", "", "100% [quest].*" }) do
    assert(addon.SearchFold(addon.SearchFold(text)) == addon.SearchFold(text))
end
assert(addon.SearchFold("é") ~= addon.SearchFold("e"), "case folding does not strip accents")
assert(addon.SearchFold("é") ~= addon.SearchFold("é"), "normalization is a separate operation")
assert(addon.SearchFold("I") == "i" and addon.SearchFold("İ") == "i̇", "default, not Turkic folding")
for _, bad in ipairs({ false, 123, secret, {}, "\128", "\192\128", "\194", "\224\128\128", "\237\160\128",
    "\240\128\128\128", "\244\144\128\128", "\245\128\128\128", "\226x\172", string.rep("A", 16385) }) do
    assert(addon.SearchFold(bad) == nil, "malformed, restricted or oversized input")
end
assert(addon.SearchFold("A\0Б") == "a\0б")
issecretvalue = function() error("restricted") end
assert(addon.SearchFold("A") == nil)
local passed = 0
local function check(name, run)
    issecretvalue = function(value) return rawequal(value, secret) end
    local ok, why = pcall(run)
    assert(ok, name .. ": " .. tostring(why))
    passed = passed + 1
    print("PASS " .. name)
end
local function has(terms, text, kind)
    for _, term in ipairs(terms) do if term.text == text and term.kind == kind then return true end end
    return false
end

check("canonical exact quest IDs", function()
    for _, pair in ipairs({ { "1", 1 }, { "166", 166 }, { " \t95036\r\n", 95036 },
        { "4294967296", 4294967296 }, { "9007199254740991", 9007199254740991 } }) do
        assert(addon.SearchQuestID(pair[1]) == pair[2])
    end
end)
check("noncanonical and imprecise quest IDs stay literal queries", function()
    for _, value in ipairs({ "", "0", "0166", "+166", "-166", "166.0", "1e2", "0xA6", "#166",
        "quest=166", "１６６", "١٦٦", "16 6", "166\0", "9007199254740992", "9999999999999999",
        "10000000000000000", string.rep(" ", 16385), false, 166, secret, {} }) do
        assert(addon.SearchQuestID(value) == nil)
    end
    assert(addon.SearchQuestID(nil) == nil)
end)
check("restricted quest-ID input fails closed", function()
    issecretvalue = function() error("restricted") end
    assert(addon.SearchQuestID("166") == nil)
end)
local function fixture()
    return { name = "Target quest", description = "Narrative only", source = "https://example.invalid/quest",
        start = { npcID = 1, name = "Giver One", zoneName = "Westfall", locationName = "Sentinel Hill" },
        finish = { objectID = 2, name = "Sealed Coffer", zoneName = "Elwynn" },
        startAlternatives = { { itemID = 3, name = "Unindexed starter item", dropNPCID = 4, dropName = "Recorded Dropper",
            containerSource = { objectID = 5, name = "Starter Cache", locationName = "Lower Cellar" },
            dropSources = { { npcID = 6, name = "Other Dropper", zoneName = "Darkshore", dungeonKey = "Not a location" } } } },
        finishAlternatives = { { mapID = 7, zoneName = "Duskwood" } },
        requires = { { name = "Prerequisite name" } }, objectiveItemSources = { { name = "Outside initial scope" } } }
end
check("Source terms use explicit typed NPC and place facts without quest or dungeon inference", function()
    local terms, current = addon.QuestSourceSearchTerms(fixture())
    assert(current() and has(terms, "Giver One", "npc") and has(terms, "Westfall", "place"))
    for _, text in ipairs({ "Sentinel Hill", "Sealed Coffer", "Elwynn", "Starter Cache", "Lower Cellar", "Darkshore", "Duskwood" }) do
        assert(has(terms, text, "place"), text)
    end
    assert(has(terms, "Recorded Dropper", "npc") and has(terms, "Other Dropper", "npc"))
    for _, text in ipairs({ "Target quest", "Narrative only", "https://example.invalid/quest", "Unindexed starter item",
        "Not a location", "Prerequisite name", "Outside initial scope" }) do
        assert(not has(terms, text, "npc") and not has(terms, text, "place"), text)
    end
end)
check("Ambiguous or invalid identities cannot create NPC names or untyped locations", function()
    local q = { start = { npcID = 1, objectID = 2, name = "Ambiguous" },
        finish = { itemID = 3, name = "Item", zoneName = "Unmapped item zone" },
        startAlternatives = { { name = "Untyped", zoneName = "Unknown zone" }, { npcID = 0, name = "Zero" },
            { npcID = 1.5, name = "Fraction" }, { objectID = 8, name = "Object label" } } }
    local terms, current = addon.QuestSourceSearchTerms(q)
    assert(current() and #terms == 1 and has(terms, "Object label", "place"))
end)
check("Source terms deduplicate exact text by kind and retain multilingual display bytes", function()
    local q = { start = { npcID = 1, name = "Straße", zoneName = "死亡礦坑" },
        finish = { npcID = 2, name = "Straße", zoneName = "死亡礦坑" },
        startAlternatives = { { objectID = 3, name = "Straße" }, { npcID = 4, name = "СТРАЖ" } } }
    local terms, current = addon.QuestSourceSearchTerms(q)
    assert(current() and #terms == 4 and terms[1].text == "Straße" and terms[1].kind == "npc")
    assert(has(terms, "Straße", "place") and has(terms, "СТРАЖ", "npc"))
    assert(addon.SearchFold(terms[1].text) == "strasse")
end)
check("Malformed restricted oversized or blank source text never becomes a term", function()
    for _, value in ipairs({ secret, false, 12, {}, "\128", "\194", string.rep("x", 2001), " \t ", "bad\0name" }) do
        local terms = addon.QuestSourceSearchTerms({ start = { npcID = 1, name = value } })
        assert(#terms == 0)
    end
    local terms, current = addon.QuestSourceSearchTerms(secret)
    assert(#terms == 0 and not current())
end)
check("Static source extraction does not request names read locale or mutate saved data", function()
    local oldLocale, oldMap, oldName, oldItem, oldDB = GetLocale, C_Map, addon.GiverName, addon.ItemName, addon.db
    GetLocale = function() error("Locale API read") end
    C_Map = setmetatable({}, { __index = function() error("Map API read") end })
    addon.GiverName = function() error("Name request") end
    addon.ItemName = function() error("Item request") end
    addon.db = { locale = "ruRU", untouched = {} }
    local db, nested = addon.db, addon.db.untouched
    local terms, current = addon.QuestSourceSearchTerms(fixture())
    assert(#terms > 0 and current() and addon.db == db and addon.db.untouched == nested and addon.db.locale == "ruRU")
    GetLocale, C_Map, addon.GiverName, addon.ItemName, addon.db = oldLocale, oldMap, oldName, oldItem, oldDB
end)
check("Source binding rejects replaced sources lists entries and in-place name or type changes", function()
    for _, mutate in ipairs({ function(q) q.start = { npcID = 1, name = "Other" } end,
        function(q) q.start.name = "Changed" end, function(q) q.start.npcID = 9 end,
        function(q) q.start.zoneName = secret end, function(q) q.startAlternatives = {} end,
        function(q) q.startAlternatives[1] = {} end,
        function(q) q.startAlternatives[1].containerSource.name = "Changed cache" end,
        function(q) q.startAlternatives[1].dropSources[1].name = "Changed dropper" end }) do
        local q = fixture()
        local _, current = addon.QuestSourceSearchTerms(q)
        assert(current()); mutate(q); assert(not current())
    end
end)
check("Returned term bindings reject edited list text kind and extra fields", function()
    for _, mutate in ipairs({ function(t) t[1].text = "Changed" end, function(t) t[1].kind = "place" end,
        function(t) t[1] = { text = t[1].text, kind = t[1].kind } end,
        function(t) t[#t + 1] = { text = "Injected", kind = "npc" } end,
        function(t) t[1].url = "Unexpected" end, function(t) t.extra = true end }) do
        local terms, current = addon.QuestSourceSearchTerms(fixture())
        assert(current()); mutate(terms); assert(not current())
    end
end)
check("Source current proof rejects checker reentry and replaced helper capabilities", function()
    local q = fixture()
    local armed = false
    issecretvalue = function(value)
        if armed and value == "Sealed Coffer" then armed = false; q.start.name = "Changed during proof" end
        return rawequal(value, secret)
    end
    local _, current = addon.QuestSourceSearchTerms(q)
    assert(current()); armed = true; assert(not current() and not armed)
    issecretvalue = function() return false end
    local _, nextCurrent = addon.QuestSourceSearchTerms(fixture())
    issecretvalue = function() return false end
    assert(not nextCurrent())
    for _, field in ipairs({ "SearchFold", "Clean", "QuestSourceSearchTerms" }) do
        local original = addon[field]
        local _, changedCurrent = addon.QuestSourceSearchTerms(fixture())
        addon[field] = function() return "changed" end
        assert(not changedCurrent()); addon[field] = original
    end
end)
check("A valid empty source binding detects facts added later while unavailable input stays inert", function()
    local q = {}
    local terms, current = addon.QuestSourceSearchTerms(q)
    assert(#terms == 0 and current())
    q.start = { npcID = 1, name = "New source" }
    assert(not current())
    terms, current = addon.QuestSourceSearchTerms(nil)
    assert(#terms == 0 and not current())
end)
check("Extraction fails closed when folding reenters a captured source", function()
    local q, folder = fixture(), addon.SearchFold
    addon.SearchFold = function(value) q.start.name = "Changed while folding"; return folder(value) end
    local terms, current = addon.QuestSourceSearchTerms(q)
    addon.SearchFold = folder
    assert(#terms == 0 and not current())
end)
check("Source traversal is bounded per list and overall and ignores metatable getters", function()
    local q = { startAlternatives = {} }
    for i = 1, 101 do q.startAlternatives[i] = { npcID = i, name = "Giver " .. i } end
    local terms, current = addon.QuestSourceSearchTerms(q)
    assert(current() and #terms == 100 and not has(terms, "Giver 101", "npc"))
    for i = 1, 100 do
        q.startAlternatives[i] = { itemID = i, dropSources = {} }
        for j = 1, 100 do q.startAlternatives[i].dropSources[j] = { npcID = j, name = i .. ":" .. j, zoneName = "Zone " .. i .. ":" .. j } end
    end
    terms, current = addon.QuestSourceSearchTerms(q)
    assert(current() and #terms == 1024)
    local getters = 0
    q = setmetatable({}, { __index = function() getters = getters + 1; error("Getter must not run") end })
    terms, current = addon.QuestSourceSearchTerms(q)
    assert(current() and #terms == 0 and getters == 0)
end)
check("Batch final ownership proof detects a later checker changing an earlier or empty source", function()
    local early, empty = { start = { npcID = 1, name = "Earlier NPC" } }, {}
    local late = { start = { npcID = 2, name = "Later NPC" } }
    local armed = false
    issecretvalue = function(value)
        if armed and value == "Later NPC" then
            armed = false
            early.start.name = "Mutated earlier"
            empty.start = { npcID = 3, name = "Added fact" }
        end
        return false
    end
    local _, first, firstRaw = addon.QuestSourceSearchTerms(early)
    local _, blank, blankRaw = addon.QuestSourceSearchTerms(empty)
    local _, last, lastRaw = addon.QuestSourceSearchTerms(late)
    assert(first() and blank())
    armed = true
    assert(last() and not armed)
    assert(not firstRaw() and not blankRaw() and lastRaw())
end)
check("Final source ownership proof never invokes callback-bearing capabilities", function()
    local q = { start = { npcID = 1, name = "Recorded NPC", zoneName = "Recorded zone" } }
    local calls = 0
    issecretvalue = function() calls = calls + 1; return false end
    local _, current, unchanged = addon.QuestSourceSearchTerms(q)
    assert(current())
    local before = calls
    assert(unchanged() and calls == before)
    q.start.name = "Changed"
    assert(not unchanged() and calls == before)
end)
check("Mutated term proof stops after exceeding its original two fields", function()
    local terms, _, unchanged = addon.QuestSourceSearchTerms({ start = { npcID = 1, name = "Recorded NPC" } })
    local term = terms[1]
    for index = 1, 10000 do term["extra" .. index] = true end
    local original, visits = next, 0
    next = function(object, key)
        if rawequal(object, term) then visits = visits + 1 end
        return original(object, key)
    end
    local ok, valid = pcall(unchanged)
    next = original
    assert(ok and valid == false and visits <= 3, "visited keys: " .. visits)
end)
check("Mutated result array proof stops after exceeding its original term count", function()
    local terms, _, unchanged = addon.QuestSourceSearchTerms({ start = { npcID = 1, name = "Recorded NPC" } })
    for index = 1, 10000 do terms["extra" .. index] = true end
    local original, visits = next, 0
    next = function(object, key)
        if rawequal(object, terms) then visits = visits + 1 end
        return original(object, key)
    end
    local ok, valid = pcall(unchanged)
    next = original
    assert(ok and valid == false and visits <= 2, "visited keys: " .. visits)
end)
print("Unicode, quest-ID and recorded source search checks passed: " .. passed .. " cases")
