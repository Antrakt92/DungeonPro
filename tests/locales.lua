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
    assert(strings.SEARCH_HELP:find("ID", 1, true), locale .. " search help omits quest ID")
    assert(type(strings.DETAIL_MORE) == "string" and strings.DETAIL_MORE:find("%S") and
        type(strings.DETAIL_LESS) == "string" and strings.DETAIL_LESS:find("%S") and
        strings.DETAIL_MORE ~= strings.DETAIL_LESS, locale .. " missing distinct detail disclosure labels")
    assert(type(strings.DETAIL_CHAIN) == "string" and strings.DETAIL_CHAIN:find("%S"), locale .. " missing known-chain disclosure label")
    for _, key in ipairs({ "DUNGEON_ENTRANCE", "DUNGEON_ENTRANCE_UNKNOWN", "STEP_MAP", "STEP_GUIDE" }) do
        assert(type(strings[key]) == "string" and strings[key]:find("%S"), locale .. " missing navigation label " .. key)
    end
    addon.db = { locale = locale }
    local idMatch = addon.L("SEARCH_QUEST_MATCH", "Example quest (#166)")
    assert(idMatch:find("Example quest (#166)", 1, true), locale .. " exact quest ID cue lost")
    assert(type(addon.L("SUMMARY", 1, 2, 3, 4)) == "string")
    assert(addon.L("ITEM_CARRIED", 1e20):find("100000000000000000000", 1, true), locale .. " count overflow")
    n = n + 1
end
addon.db.locale = "esMX"
assert(addon.L("NEXT") == addon.locales.esES.NEXT)
addon.db.locale = "enGB"
assert(addon.L("NEXT") == addon.locales.enUS.NEXT)
-- Fail-closed: hostile or missing GetLocale never throws; auto falls back to enUS.
addon.db.locale = "auto"
local savedGetLocale = GetLocale
GetLocale = nil
assert(addon.L("NEXT") == addon.locales.enUS.NEXT)
GetLocale = "hostile"
assert(addon.L("NEXT") == addon.locales.enUS.NEXT)
GetLocale = function() error("hostile GetLocale") end
assert(addon.L("NEXT") == addon.locales.enUS.NEXT)
GetLocale = function() return nil end
assert(addon.L("NEXT") == addon.locales.enUS.NEXT)
GetLocale = savedGetLocale
assert(addon.L("NEXT") == addon.locales.enUS.NEXT)
-- Reverse coverage: keys present in any locale but absent from enUS are dead
-- (or untranslated-new) and fail closed. Live exceptions belong in
-- LOCALE_EXTRA_ALLOW with a one-line reason each; empty is preferred.
local LOCALE_EXTRA_ALLOW = {}
for locale, strings in pairs(addon.locales) do
    if locale ~= "enUS" then
        for key, _ in pairs(strings) do
            if addon.locales.enUS[key] == nil and not LOCALE_EXTRA_ALLOW[locale .. ":" .. key] then
                error(locale .. " has extra key without enUS: " .. key)
            end
        end
    end
end
-- Fail-closed: malformed format args return the raw text without throwing;
-- valid formatting is unchanged.
do
    local template = addon.locales.enUS.SUMMARY
    assert(addon.L("SUMMARY", 1, 2, 3, 4) == template:format(1, 2, 3, 4))
    assert(addon.L("SUMMARY", 1) == template, "missing format args must return raw text")
    assert(addon.L("SUMMARY", {}, {}, {}, {}) == template, "unformattable args must return raw text")
    assert(addon.L("SEARCH_QUEST_MATCH", "Example quest (#166)"):find("Example quest (#166)", 1, true))
end
-- Fail-closed: non-string keys never throw and return as-is; valid keys
-- are byte-identical. All live callers pass string literals (latent path).
do
    local probe = {}
    assert(addon.L(nil) == nil)
    assert(addon.L(5) == 5)
    assert(addon.L(probe) == probe)
    assert(addon.L(nil, "x") == nil, "non-string key with format args must not throw")
    assert(addon.L("NEXT") == addon.locales.enUS.NEXT, "valid keys byte-identical")
end
-- Reader hardening: hostile namespaces never throw; results fall back to the
-- key/enUS text. Mirrors the nameLocaleScope() rawget discipline.
do
    addon.db = { locale = "enUS" }
    local expected = addon.L("NEXT")
    local savedDb, savedClean, savedRead, savedLanguage = addon.db, addon.Clean, addon.Read, addon.Language
    local savedDeDE = addon.locales.deDE
    -- The locale testbed loads no Namespace adapters; install faithful local
    -- stand-ins so the language-metatable probes exercise the rawget path.
    addon.Clean = function(value, kind) if type(value) ~= kind then return nil end return value end
    addon.Read = function(fn, kind, ...)
        if type(fn) ~= "function" then return nil end
        local ok, value = pcall(fn, ...)
        if not ok then return nil end
        return addon.Clean(value, kind)
    end
    local function hardened(label, setup, key)
        setup()
        local ok, result = pcall(addon.L, key or "NEXT")
        assert(ok, label .. " threw: " .. tostring(result))
        assert(type(result) == "string", label .. " must return a string, got " .. type(result))
        return result
    end
    hardened("db=5", function() addon.db = 5 end)
    addon.Clean = "x"
    hardened("Clean overwrite", function() addon.db = { locale = "enUS" } end)
    addon.Clean = savedClean == nil and (function(value, kind) if type(value) ~= kind then return nil end return value end) or savedClean
    hardened("throwing language metatable", function()
        addon.db = { locale = "enUS" }
        addon.Language = setmetatable({}, { __index = function() error("hostile __index") end })
    end)
    addon.Language = setmetatable({ GetSelection = function() return "ruRU" end },
        { __index = function() error("hostile __index") end })
    addon.db = { locale = "enUS" }
    assert(addon.L("NEXT") == addon.locales.ruRU.NEXT, "raw preview selection must survive a hostile language metatable")
    hardened("poisoned deDE table", function()
        addon.Language = nil
        addon.db = { locale = "deDE" }
        addon.locales.deDE = 5
    end)
    assert(hardened("poisoned lookup of missing key", function() end, "NO_SUCH_KEY_XYZ") == "NO_SUCH_KEY_XYZ")
    addon.db, addon.Clean, addon.Read, addon.Language = savedDb, savedClean, savedRead, savedLanguage
    addon.locales.deDE = savedDeDE
    addon.db = { locale = "enUS" }
    assert(addon.L("NEXT") == expected, "valid path must stay byte-identical")
end
print("Localization checks passed: " .. n .. " dictionaries, esMX/enGB aliases; visual review pending")
