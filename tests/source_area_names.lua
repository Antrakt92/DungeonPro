local addon, count = {}, 0
issecretvalue = function() return false end
GetLocale = function() return "enUS" end
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local function setup()
    assert(loadfile("Database/NameTranslations.lua"))("DungeonPro", addon)
    addon.db, addon.Language = { locale = "zhCN" }, nil
    addon.dungeons = {
        { key = "mara", name = "Maraudon", instanceID = 349 },
        { key = "gnom", name = "Gnomeregan", instanceID = 90 },
        { key = "lbrs", name = "Lower Blackrock Spire", instanceID = 229, wing = "lower" },
        { key = "ubrs", name = "Upper Blackrock Spire", instanceID = 229, wing = "upper" },
    }
    GetLocale = function() return "enUS" end
    GetRealZoneText = function() error("resolver must never call native zone labels") end
    addon.DungeonName = function() error("resolver must not consult native-capable DungeonName") end
end
local function check(label, fn)
    setup(); fn(); count = count + 1; print("PASS " .. label)
end
check("Reviewed areas resolve selected Chinese while game locale stays English", function()
    assert(addon.SourceAreaName("Maraudon", function() return true end) == "玛拉顿")
    assert(addon.SourceAreaName("Gnomeregan", function() return true end) == "诺莫瑞根")
    assert(addon.dungeons[1].name == "Maraudon")
end)
check("Generic Spire unrelated landmark and duplicate canonical names do not resolve", function()
    assert(addon.SourceAreaName("Blackrock Spire") == nil)
    assert(addon.SourceAreaName("At the entrance") == nil)
    addon.dungeons[5] = { key = "gnom", name = "Maraudon", instanceID = 90 }
    assert(addon.SourceAreaName("Maraudon") == nil)
end)
check("English returns exact canonical name without native API", function()
    for _, choice in ipairs({ "enUS", "auto" }) do
        addon.db.locale = choice
        assert(addon.SourceAreaName("Maraudon") == "Maraudon")
    end
end)
check("Missing mismatched or empty reviewed entry returns nil for UI fallback", function()
    assert(addon.SourceAreaName("Maraudon") == "玛拉顿")
    local entries = addon.nameTranslations.zhCN.dungeons
    for _, entry in ipairs({ {}, {source="Different",name="玛拉顿"}, {source="Maraudon",name=""} }) do
        entries.mara = entry; assert(addon.SourceAreaName("Maraudon") == nil)
    end
    entries.mara = nil; assert(addon.SourceAreaName("Maraudon") == nil)
end)
check("Expired or malformed caller scope never resolves", function()
    assert(addon.SourceAreaName("Maraudon", function() return false end) == nil)
    assert(addon.SourceAreaName("Maraudon", true) == nil)
end)
check("Lazy dictionary callback cannot publish a former locale", function()
    local loader, fired = addon.nameTranslationFactories.loaders.zhCN, false
    addon.nameTranslationFactories.loaders.zhCN = function()
        fired = true; addon.db.locale = "ruRU"; return loader()
    end
    assert(addon.SourceAreaName("Maraudon") == nil and fired)
end)
check("Lazy callback cannot introduce duplicate source or replace catalogue", function()
    for _, mutate in ipairs({
        function() addon.dungeons[2].name = "Maraudon" end,
        function() addon.dungeons = {} end,
        function() addon.dungeons[1].key = "gnom" end,
    }) do
        setup(); local loader, fired = addon.nameTranslationFactories.loaders.zhCN, false
        addon.nameTranslationFactories.loaders.zhCN = function()
            fired = true; mutate(); return loader()
        end
        assert(addon.SourceAreaName("Maraudon") == nil and fired)
    end
end)
check("Owner callback retiring reviewed entry cannot publish its former label", function()
    assert(addon.SourceAreaName("Maraudon") == "玛拉顿")
    local calls, fired = 0, false
    local result = addon.SourceAreaName("Maraudon", function()
        calls = calls + 1
        if calls == 3 then fired = true; addon.nameTranslations.zhCN.dungeons.mara.name = "Changed" end
        return true
    end)
    assert(fired and result ~= "玛拉顿")
end)
check("Clean reentry cannot revise a candidate or earlier source member", function()
    local originalClean = addon.Clean
    for _, mode in ipairs({ "candidate", "earlier" }) do
        setup(); addon.db.locale = "enUS"
        local fired, sourceReads = false, 0
        addon.Clean = function(value, expected)
            if expected == "string" and value == "Maraudon" then sourceReads = sourceReads + 1 end
            if not fired and expected == "string" and ((mode == "candidate" and value == "Maraudon" and sourceReads == 2) or
                (mode == "earlier" and value == "Gnomeregan")) then
                fired = true
                addon.dungeons[1].name, addon.dungeons[1].key = "Changed source", "gnom"
            end
            return originalClean(value, expected)
        end
        local result = addon.SourceAreaName("Maraudon")
        addon.Clean = originalClean
        assert(fired and result == nil, mode)
    end
end)
print(count .. " source area name groups passed")
