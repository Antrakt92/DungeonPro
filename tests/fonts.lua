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
local function providerChoices(locale, gameLocale)
    local result = {}
    for _, row in ipairs(fonts:Choices(locale, gameLocale)) do
        if row.kind == "provider" then result[#result + 1] = row end
    end
    return result
end
local catalog
local function provider(list, revision)
    catalog = { formatMajor = 1, catalogRevision = string.rep(revision or "a", 64), fonts = list or { face("first") } }
    AntraktFonts = { GetCatalog = function() return catalog end }
    return fonts:Refresh()
end
local function test(name, run)
    addon.db, addon.Language, addon.L = { locale = "auto" }, nil, nil
    fonts:CancelPreview()
    LibStub, C_AddOns, UnitGUID = nil, nil, nil
    DoesAddOnExist, IsAddOnLoaded, GetAddOnEnableState, GetNumAddOns, GetAddOnInfo = nil, nil, nil, nil, nil
    GetLocale = function() return "enUS" end
    AntraktFonts = nil
    fonts:Refresh()
    run(); total = total + 1; print("ok - " .. name)
end
test("optional provider absent or late retains and recovers preference", function()
    addon.db.fontId = "first"
    assert(not fonts:Refresh() and #providerChoices() == 0 and fonts:Resolve() == nil)
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
    assert(fonts.revision == string.rep("b", 64) and #providerChoices() == 2)
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
    local choice = providerChoices()[1]
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
        assert(not fonts:Refresh() and #providerChoices() == 0)
    end
end)
test("filter requires both interface and game-text script coverage", function()
    assert(provider({ face("latin", { cyrillic = false }), face("both") }))
    GetLocale = function() return "ruRU" end
    addon.db.locale = "enUS"
    local choices = providerChoices()
    assert(#choices == 1 and choices[1].id == "both")
    assert(not fonts:Select("latin") and fonts:Select("both"))
    assert(#providerChoices("ruRU", "enUS") == 1)
    assert(#providerChoices("unknown", "enUS") == 0)
end)
test("exact Latin locale coverage and English alias are respected", function()
    assert(provider({ face("limited", { latin = false, latinLocales = { enUS = true } }) }))
    assert(#providerChoices("enGB", "enGB") == 1)
    assert(#providerChoices("frFR", "enUS") == 0)
end)
test("CN and TW region forms are separate and Korean requires Hangul", function()
    assert(provider({ face("cn", { hans = true, region = "zhCN" }),
        face("tw", { hant = true, region = "zhTW" }), face("ko", { hangul = true }) }))
    assert(providerChoices("zhCN", "enUS")[1].id == "cn")
    assert(providerChoices("zhTW", "enUS")[1].id == "tw")
    assert(providerChoices("zhTW", "zhTW")[1].id == "tw")
    assert(#providerChoices("zhCN", "zhTW") == 0)
    assert(providerChoices("koKR", "enUS")[1].id == "ko")
end)
test("native text checks glyphs without applying output regional preference", function()
    assert(provider({ face("tw", { hant = true, region = "zhTW" }),
        face("hans-only", { latin = false, cyrillic = false, hans = true, region = "zhCN" }),
        face("tw-no-latin", { latin = false, cyrillic = false, hant = true, region = "zhTW" }) }))
    addon.db.locale = "zhTW"
    local choices = providerChoices()
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
    assert(#providerChoices() == 0 and not fonts:Select("ko") and not fonts:Select("ru"))
    addon.db.locale = "ruRU"
    GetLocale = function() return "koKR" end
    assert(#providerChoices() == 0, "changing UI/client order does not invent a shared face")
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

test("live preview and default preview remain transient and caption tracks committed preference", function()
    assert(provider({ face("first"), face("second") }))
    assert(fonts:Select("first"))
    local before = addon.db.fontId
    assert(fonts:Preview("second") and fonts:Resolve():find("second.ttf", 1, true))
    assert(addon.db.fontId == before and fonts:Caption() == "first")
    assert(fonts:Preview(nil) and fonts:Resolve() == nil and addon.db.fontId == before)
    assert(fonts:CancelPreview() and fonts:Resolve():find("first.ttf", 1, true))
    assert(not fonts:CancelPreview())
    assert(fonts:Preview("second") and not fonts:Select("missing") and fonts.preview)
    assert(fonts:Select("second") and not fonts.preview and addon.db.fontId == "second")
end)

test("preview rejects incompatible output and restores retained preference when coverage returns", function()
    assert(provider({ face("latin", { cyrillic = false }), face("both") }))
    assert(fonts:Select("both") and fonts:Preview("latin"))
    addon.db.locale = "ruRU"
    assert(fonts:Resolve() == nil and addon.db.fontId == "both" and not fonts:Preview("latin"))
    assert(fonts:Caption() == "both")
    fonts:CancelPreview()
    assert(fonts:Resolve():find("both.ttf", 1, true))
end)

local function media(paths)
    local names = {}
    for name in pairs(paths) do names[#names + 1] = name end
    table.sort(names)
    local instance = {
        List = function(_, kind) assert(kind == "font"); return names end,
        Fetch = function(_, kind, name, noDefault)
            assert(kind == "font" and noDefault == true)
            return paths[name]
        end,
    }
    LibStub = setmetatable({}, { __call = function(_, name, silent)
        assert(name == "LibSharedMedia-3.0" and silent == true)
        return instance
    end })
end
local function findChoice(id, locale, gameLocale)
    for _, row in ipairs(fonts:Choices(locale, gameLocale)) do
        if row.id == id then return row end
    end
end

test("native choices remain available independently of optional-provider guidance", function()
    assert(not fonts:Refresh() and #fonts.records == 0 and fonts.revision == nil)
    assert(#fonts:Choices() == 4)
    local id = "native:fonts\\arialn.ttf"
    assert(findChoice(id).kind == "native" and fonts:Select(id))
    assert(fonts:Resolve() == "Fonts\\ARIALN.TTF" and fonts:Caption() == "Arial Narrow")
    assert(findChoice(id, "ruRU", "enUS"))
    assert(not findChoice("native:fonts\\frizqt__.ttf", "ruRU", "enUS"))
    assert(findChoice("native:fonts\\2002.ttf", "koKR", "ruRU"))
    assert(not findChoice("native:fonts\\bhei00m.ttf", "zhTW", "enUS"), "Hant-only face cannot render English game text")
end)

test("shared media merges exact identities and rejects unknown non-English coverage", function()
    assert(provider())
    media({ ["Duplicate provider"] = "interface/addons/antraktfonts/fonts/FIRST.ttf",
        ["Duplicate native"] = "fonts/ARIALN.ttf", ["Unknown face"] = "Interface/AddOns/Other/Unknown.ttf",
        ["Known Cyrillic"] = "Fonts/MORPHEUS_CYR.TTF", ["Noto CJK Guess"] = "Interface/AddOns/Other/NotoCJK.ttf",
        ["Unsafe"] = "Interface/AddOns/../Other/Unsafe.ttf",
        ["Absolute"] = "C:/Windows/Fonts/arial.ttf",
        ["Baseline"] = "Interface/AddOns/DungeonPro/Media/Fonts/AntraktUISans.ttf" })
    assert(fonts:Refresh())
    local unknown = "lsm:interface\\addons\\other\\unknown.ttf"
    assert(findChoice(unknown) and findChoice(unknown).kind == "lsm")
    assert(not findChoice(unknown, "deDE", "enUS") and not findChoice(unknown, "ruRU", "enUS"))
    assert(not findChoice("lsm:interface\\addons\\other\\notocjk.ttf", "zhCN", "enUS"))
    assert(findChoice("lsm:fonts\\morpheus_cyr.ttf", "ruRU", "enUS"))
    local seen = {}
    for _, row in ipairs(fonts:Choices()) do
        local key = row.path:gsub("/", "\\"):lower()
        assert(not seen[key] and not key:find("%.%."))
        assert(not key:find("antraktuisans.ttf", 1, true))
        seen[key] = true
    end
    assert(fonts:Select(unknown) and fonts:Resolve() == "Interface\\AddOns\\Other\\Unknown.ttf")
    LibStub = nil; fonts:Refresh()
    assert(fonts:Resolve() == nil and addon.db.fontId == unknown)
end)

test("favorites sort first persist separately and cannot select or star unavailable identities", function()
    assert(provider({ face("alpha"), face("zed") }))
    assert(fonts:Select("alpha"))
    assert(fonts:ToggleFavorite("zed") and fonts:IsFavorite("zed"))
    assert(fonts:Choices()[1].id == "zed" and addon.db.fontId == "alpha")
    assert(fonts:ToggleFavorite(nil) and fonts:IsFavorite(nil) and addon.db.fontFavorites.default)
    assert(not fonts:ToggleFavorite("missing") and addon.db.fontId == "alpha")
    fonts:Refresh(); assert(fonts:IsFavorite("zed"))
    assert(fonts:ToggleFavorite("zed") and not fonts:IsFavorite("zed"))
    addon.db.fontFavorites = {}
    for index = 1, 512 do addon.db.fontFavorites["old-" .. index] = true end
    assert(not fonts:ToggleFavorite("alpha") and not fonts:IsFavorite("alpha"))
end)

test("provider state distinguishes missing disabled not-loaded incompatible and ready without mutations", function()
    local exists, loaded, enabled = false, false, 0
    UnitGUID = function(unit) assert(unit == "player"); return "ephemeral-character" end
    C_AddOns = {
        DoesAddOnExist = function(name) assert(name == "AntraktFonts"); return exists end,
        IsAddOnLoaded = function() return true, loaded end,
        GetAddOnEnableState = function(name, character)
            assert(name == "AntraktFonts" and character == "ephemeral-character")
            return enabled
        end,
        EnableAddOn = function() error("read-only query must never enable") end,
    }
    assert(fonts:ProviderState() == "missing")
    exists = true; assert(fonts:ProviderState() == "disabled")
    enabled = 2; assert(fonts:ProviderState() == "notLoaded", "loading-only first return is not loaded proof")
    loaded = true; assert(fonts:ProviderState() == "incompatible")
    assert(provider() and fonts:ProviderState() == "ready")
    AntraktFonts = {}; assert(fonts:ProviderState() == "incompatible")
    loaded = false
    UnitGUID = function() return nil end
    enabled = 0; assert(fonts:ProviderState() == "notLoaded", "unknown current character cannot prove disabled")
end)

test("invalid modern addon methods cannot borrow conflicting legacy state", function()
    DoesAddOnExist = function() return false end
    IsAddOnLoaded = function() return true end
    C_AddOns = { DoesAddOnExist = false, IsAddOnLoaded = false }
    assert(fonts:ProviderState() == "notLoaded")
    C_AddOns = nil
    assert(fonts:ProviderState() == "incompatible", "legacy completed load is readable when modern method is absent")
end)

print("Font catalogue tests passed: " .. total)
