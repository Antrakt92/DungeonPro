local addon, total = {}, 0
local secret = {}
issecretvalue = function(value) return value == secret end
GetLocale = function() return "enUS" end
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Locales/Strings.lua"))("DungeonPro", addon)
assert(loadfile("Locales/Translations.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local lower = { name = "Lower Blackrock Spire", instanceID = 229, wing = "lower" }
local upper = { name = "Upper Blackrock Spire", instanceID = 229, wing = "upper" }
local ordinary = { name = "Source dungeon", instanceID = 230 }
local function check(label, test)
    addon.db = { locale = "enUS" }
    GetLocale = function() return "enUS" end
    GetRealZoneText = function(id, ...)
        assert((id == 229 or id == 230) and select("#", ...) == 0)
        return "Client dungeon"
    end
    test()
    total = total + 1; print("PASS " .. label)
end
check("Shared instance retains distinct wing names with the actual client adapter", function()
    assert(addon.DungeonName(lower) == "Client dungeon — Lower wing")
    assert(addon.DungeonName(upper) == "Client dungeon — Upper wing")
    assert(addon.DungeonName(lower) ~= addon.DungeonName(upper))
    assert(lower.name == "Lower Blackrock Spire" and upper.name == "Upper Blackrock Spire")
end)
check("All ten dictionaries format the unchanged native base with distinct localized wings", function()
    local count = 0
    for locale, strings in pairs(addon.locales) do
        addon.db.locale = locale
        GetRealZoneText = function() return "Название клиента" end
        assert(type(strings.DUNGEON_WING_lower) == "string")
        assert(type(strings.DUNGEON_WING_upper) == "string")
        assert(addon.DungeonName(lower) == string.format(strings.DUNGEON_WING_lower, "Название клиента"))
        assert(addon.DungeonName(upper) == string.format(strings.DUNGEON_WING_upper, "Название клиента"))
        assert(addon.DungeonName(lower) ~= addon.DungeonName(upper))
        assert(addon.DungeonName(lower):find("Название клиента", 1, true))
        count = count + 1
    end
    assert(count == 10)
end)
check("Auto locale and unsupported locale fallback keep the native base", function()
    addon.db.locale = "auto"; GetLocale = function() return "ruRU" end
    assert(addon.DungeonName(lower) == "Client dungeon — Нижнее крыло")
    addon.db.locale = "unsupported"
    assert(addon.DungeonName(upper) == "Client dungeon — Upper wing")
    addon.db.locale = "esMX"
    assert(addon.DungeonName(lower) == string.format(addon.locales.esES.DUNGEON_WING_lower, "Client dungeon"))
    addon.db.locale = "enGB"
    assert(addon.DungeonName(upper) == "Client dungeon — Upper wing")
end)
check("Missing empty throwing malformed and restricted native names preserve exact source fallback", function()
    local cases = { function() return "" end, function() error("Unavailable") end,
        function() return 229 end, function() return secret end, function() return nil end }
    for _, fn in ipairs(cases) do
        GetRealZoneText = fn
        assert(addon.DungeonName(lower) == lower.name and addon.DungeonName(upper) == upper.name)
    end
    GetRealZoneText = nil
    assert(addon.DungeonName(lower) == lower.name and addon.DungeonName(upper) == upper.name)
    GetRealZoneText = function() error("No instance must not query") end
    assert(addon.DungeonName({ name = "Exact source — text", wing = "lower" }) == "Exact source — text")
end)
check("Ordinary and unknown wing metadata do not invent a suffix", function()
    assert(addon.DungeonName(ordinary) == "Client dungeon")
    for _, wing in ipairs({ "middle", "LOWER", "", true, 229, {}, secret }) do
        assert(addon.DungeonName({ name = "Source", instanceID = 229, wing = wing }) == "Client dungeon")
    end
    assert(addon.DungeonName({ name = "Source", instanceID = 229 }) == "Client dungeon")
end)
print("Dungeon name checks passed: " .. total)
