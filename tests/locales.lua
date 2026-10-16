local addon = {}
GetLocale = function() return "enUS" end
assert(loadfile("Locales/Strings.lua"))("DungeonPro", addon)
assert(loadfile("Locales/Translations.lua"))("DungeonPro", addon)
local n = 0
for locale, strings in pairs(addon.locales) do
    for key, english in pairs(addon.locales.enUS) do
        assert(type(strings[key]) == "string", locale .. " missing " .. key)
        local expected, actual = {}, {}
        local pattern = "%%[%-%+ #0]*%d*%.?%d*[cdeEfgGiouxXqs]"
        for s in english:gsub("%%%%", ""):gmatch(pattern) do expected[#expected + 1] = s end
        for s in strings[key]:gsub("%%%%", ""):gmatch(pattern) do actual[#actual + 1] = s end
        assert(table.concat(expected) == table.concat(actual), locale .. " format mismatch " .. key)
    end
    addon.db = { locale = locale }
    assert(type(addon.L("SUMMARY", 1, 2, 3, 4)) == "string")
    assert(addon.L("ITEM_CARRIED", 1e20):find("100000000000000000000", 1, true), locale .. " count overflow")
    n = n + 1
end
addon.db.locale = "esMX"
assert(addon.L("NEXT") == addon.locales.esES.NEXT)
addon.db.locale = "enGB"
assert(addon.L("NEXT") == addon.locales.enUS.NEXT)
print("Localization checks passed: " .. n .. " dictionaries, esMX/enGB aliases; visual review pending")
