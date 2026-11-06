local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
GetLocale = function() return "enUS" end
addon.db = { locale = "auto" }
assert(loadfile("Core/Fonts.lua"))("DungeonPro", addon)
local fonts = addon.Fonts
local function face(id, extra)
    local value = { id = id, name = id, file = id .. ".ttf", path = "Interface\\AddOns\\AntraktFonts\\fonts\\" .. id .. ".ttf",
        sha256 = string.rep("a", 64), latin = true, cyrillic = true, hans = false, hant = false, hangul = false, japanese = false }
    for key, field in pairs(extra or {}) do value[key] = field end
    return value
end
local catalog
local function provider(list, revision)
    catalog = { formatMajor = 1, catalogRevision = string.rep(revision or "a", 64), fonts = list or { face("first") } }
    AntraktFonts = { GetCatalog = function() return catalog end }
    return fonts:Refresh()
end
local function test(name, run)
    addon.db, addon.Language = { locale = "auto" }, nil
    GetLocale = function() return "enUS" end
    AntraktFonts = nil
    fonts:Refresh()
    run(); total = total + 1; print("ok - " .. name)
end
test("optional provider absent or late retains and recovers preference", function()
    addon.db.fontId = "first"
    assert(not fonts:Refresh() and #fonts:Choices() == 0 and fonts:Resolve() == nil)
    assert(addon.db.fontId == "first" and fonts:Caption() == "Unavailable")
    assert(provider() and fonts:Resolve():find("first.ttf", 1, true))
    AntraktFonts = nil
    assert(not fonts:Refresh() and fonts:Resolve() == nil and addon.db.fontId == "first")
    assert(provider() and fonts:Resolve())
end)
test("compatible revisions add identities and names without a shipped snapshot", function()
    assert(provider()); assert(fonts:Select("first"))
    local renamed = face("first", { name = "Renamed" })
    assert(provider({ renamed, face("new") }, "b"))
    assert(fonts.revision == string.rep("b", 64) and #fonts:Choices() == 2)
    assert(fonts:Caption() == "Renamed" and fonts:Select("new"))
end)
test("unknown major and throwing providers use fallback without erasing choice", function()
    assert(provider()); assert(fonts:Select("first"))
    catalog.formatMajor = 2
    assert(not fonts:Refresh() and fonts:Resolve() == nil and addon.db.fontId == "first")
    AntraktFonts.GetCatalog = function() error("unavailable") end
    assert(not fonts:Refresh() and addon.db.fontId == "first")
end)
test("catalogue snapshot and returned picker rows cannot mutate one another", function()
    assert(provider())
    catalog.fonts[1].path = "wrong"
    local choice = fonts:Choices()[1]
    assert(choice.path:find("first.ttf", 1, true)); choice.path = "also wrong"
    assert(fonts:Select("first") and fonts:Resolve():find("first.ttf", 1, true))
end)
test("malformed catalogue rejects complete snapshot", function()
    local changes = {
        function(c) c.fonts[2] = face("first") end,
        function(c) c.fonts[3] = face("third") end,
        function(c) c.fonts[1].path = "Interface\\AddOns\\Other\\first.ttf" end,
        function(c) c.fonts[1].id = "../first" end,
        function(c) c.fonts[1].latin = nil end,
        function(c) c.fonts[1].region = "koKR" end,
        function(c) c.fonts[1].latinLocales = { enGB = true } end,
        function(c) c.fonts[1].name = "bad\nname" end,
        function(c) c.fonts[1].sha256 = "a" end,
        function(c) c.catalogRevision = "bad" end,
        function(c) c.fonts = {} end,
        function(c) setmetatable(c.fonts[1], {}) end,
    }
    for _, change in ipairs(changes) do
        assert(provider()); change(catalog)
        assert(not fonts:Refresh() and #fonts:Choices() == 0)
    end
end)
test("filter requires both interface and game-text script coverage", function()
    assert(provider({ face("latin", { cyrillic = false }), face("both") }))
    GetLocale = function() return "ruRU" end
    addon.db.locale = "enUS"
    local choices = fonts:Choices()
    assert(#choices == 1 and choices[1].id == "both")
    assert(not fonts:Select("latin") and fonts:Select("both"))
    assert(#fonts:Choices("ruRU", "enUS") == 1)
    assert(#fonts:Choices("unknown", "enUS") == 0)
end)
test("exact Latin locale coverage and English alias are respected", function()
    assert(provider({ face("limited", { latin = false, latinLocales = { enUS = true } }) }))
    assert(#fonts:Choices("enGB", "enGB") == 1)
    assert(#fonts:Choices("frFR", "enUS") == 0)
end)
test("CN and TW region forms are separate and Korean requires Hangul", function()
    assert(provider({ face("cn", { hans = true, region = "zhCN" }),
        face("tw", { hant = true, region = "zhTW" }), face("ko", { hangul = true }) }))
    assert(fonts:Choices("zhCN", "enUS")[1].id == "cn")
    assert(fonts:Choices("zhTW", "enUS")[1].id == "tw")
    assert(fonts:Choices("zhTW", "zhTW")[1].id == "tw")
    assert(#fonts:Choices("zhCN", "zhTW") == 0)
    assert(fonts:Choices("koKR", "enUS")[1].id == "ko")
end)
test("native text checks glyphs without applying output regional preference", function()
    assert(provider({ face("tw", { hant = true, region = "zhTW" }),
        face("hans-only", { latin = false, cyrillic = false, hans = true, region = "zhCN" }),
        face("tw-no-latin", { latin = false, cyrillic = false, hant = true, region = "zhTW" }) }))
    addon.db.locale = "zhTW"
    local choices = fonts:Choices()
    assert(#choices == 1 and choices[1].id == "tw")
    assert(fonts:Select("tw") and fonts:Resolve():find("tw.ttf", 1, true))
    assert(not fonts:Select("hans-only") and not fonts:Select("tw-no-latin"))
    assert(fonts:Supported(fonts.byID.tw, "zhTW") and not fonts:Supported(fonts.byID.tw, "enUS"))
    assert(not fonts:Supported(fonts.byID.tw, "zhCN"), "UI region preference remains separate")
end)

test("Korean and Russian require a real shared script intersection", function()
    assert(provider({ face("ko", { hangul = true, cyrillic = false }), face("ru") }))
    addon.db.locale = "koKR"
    GetLocale = function() return "ruRU" end
    assert(#fonts:Choices() == 0 and not fonts:Select("ko") and not fonts:Select("ru"))
    addon.db.locale = "ruRU"
    GetLocale = function() return "koKR" end
    assert(#fonts:Choices() == 0, "changing UI/client order does not invent a shared face")
end)

test("language preview cannot destroy temporarily incompatible preference", function()
    assert(provider({ face("latin", { cyrillic = false }) }))
    assert(fonts:Select("latin"))
    addon.Language = { GetSelection = function() return "ruRU" end }
    assert(fonts:Resolve() == nil and addon.db.fontId == "latin" and not fonts:Select("latin"))
    assert(fonts:Caption() == "latin (Unavailable)", "caption discloses temporary fallback and retained choice")
    addon.L = function(key) return key == "FONT_UNAVAILABLE" and "Недоступен" or key end
    assert(fonts:Caption() == "latin (Недоступен)", "unavailable caption follows selected interface language")
    addon.L = nil
    addon.Language = nil
    assert(fonts:Resolve() and addon.db.fontId == "latin" and fonts:Caption() == "latin")
end)
test("explicit default resets only the font preference", function()
    assert(provider()); assert(fonts:Select("first"))
    addon.db.unrelated = "kept"
    assert(not fonts:Select("missing") and addon.db.fontId == "first")
    assert(fonts:Select(nil) and addon.db.fontId == nil and fonts:Resolve() == nil)
    assert(fonts:Caption() == "Default" and addon.db.unrelated == "kept")
    addon.L = function(key) return key == "FONT_DEFAULT" and "По умолчанию" or "Недоступен" end
    assert(fonts:Caption() == "По умолчанию")
end)
print("Font catalogue tests passed: " .. total)
