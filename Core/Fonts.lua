local _, addon = ...
local Fonts = { records = {}, byID = {}, extraRecords = {}, allByID = {} }
addon.Fonts = Fonts

local scripts = { enUS = "latin", deDE = "latin", frFR = "latin", esES = "latin", esMX = "latin",
    itIT = "latin", ptBR = "latin", ruRU = "cyrillic", koKR = "hangul", zhCN = "hans", zhTW = "hant" }
local glyphs = { "latin", "cyrillic", "hans", "hant", "hangul", "japanese" }
local function plain(value)
    return addon.Clean(value, "table") and getmetatable(value) == nil
end
local function text(value, limit)
    return addon.Clean(value, "string") and #value > 0 and #value <= limit and not value:find("[%c\127]")
end
local function identifier(value)
    return text(value, 64) and value:match("^[a-z0-9][a-z0-9%-]*$") ~= nil
end
local function digest(value)
    return text(value, 64) and #value == 64 and value:match("^[a-f0-9]+$") ~= nil
end
local function normalize(locale)
    locale = addon.Clean(locale, "string")
    if locale == "enGB" then return "enUS" end
    return scripts[locale or ""] and locale or nil
end

local function pathKey(path)
    if not text(path, 512) then return nil end
    local key = path:gsub("/", "\\"):lower()
    if key:sub(1, 6) ~= "fonts\\" and key:sub(1, 17) ~= "interface\\addons\\" then return nil end
    if not key:match("%.[to]tf$") or key:find('[/:*?"<>|]') then return nil end
    for segment in key:gmatch("[^\\]+") do
        if segment == "." or segment == ".." or #segment > 128 then return nil end
    end
    if key:find("\\\\", 1, true) then return nil end
    return key
end

-- Exact native-path coverage mirrors the established consumers. Unrecognized
-- shared-media files promise basic English only, never Cyrillic/CJK or accents.
local nativeCoverage = {}
local function coverage(path, fields)
    local row = { latin = false, cyrillic = false, hans = false, hant = false, hangul = false, japanese = false }
    for _, field in ipairs(fields) do row[field] = true end
    nativeCoverage[pathKey(path)] = row
end
coverage("Fonts\\2002.ttf", { "latin", "cyrillic", "hangul" })
coverage("Fonts\\2002B.ttf", { "latin", "cyrillic", "hangul" })
coverage("Fonts\\ARHei.TTF", { "latin", "cyrillic", "hans", "hant" })
coverage("Fonts\\ARIALN.TTF", { "latin", "cyrillic" })
coverage("Fonts\\ARKai_C.ttf", { "latin", "cyrillic", "hans", "hant" })
coverage("Fonts\\ARKai_T.ttf", { "latin", "cyrillic", "hans", "hant" })
for _, path in ipairs({ "bHEI00M.ttf", "bHEI01B.ttf", "bKAI00M.ttf", "bLEI00D.ttf" }) do
    coverage("Fonts\\" .. path, { "hant" })
end
coverage("Fonts\\FRIZQT___CYR.TTF", { "cyrillic" })
coverage("Fonts\\FRIZQT__.TTF", { "latin" })
coverage("Fonts\\K_Damage.TTF", { "cyrillic", "hangul" })
coverage("Fonts\\K_Pagetext.TTF", { "latin", "cyrillic", "hangul" })
coverage("Fonts\\MORPHEUS.TTF", { "latin" })
coverage("Fonts\\MORPHEUS_CYR.TTF", { "latin", "cyrillic" })
coverage("Fonts\\NIM_____.ttf", { "latin", "cyrillic" })
coverage("Fonts\\SKURRI.TTF", { "latin" })
coverage("Fonts\\SKURRI_CYR.TTF", { "latin", "cyrillic" })
local nativeFonts = {
    { "Friz Quadrata TT", "Fonts\\FRIZQT__.TTF" }, { "Arial Narrow", "Fonts\\ARIALN.TTF" },
    { "Skurri", "Fonts\\SKURRI.TTF" }, { "Morpheus", "Fonts\\MORPHEUS.TTF" },
    { "Chinese (Simplified)", "Fonts\\ARKai_T.ttf", "zhCN" },
    { "Chinese (Traditional)", "Fonts\\bHEI00M.ttf", "zhTW" },
    { "Korean", "Fonts\\2002.ttf", "koKR" },
}
local baselineKey = pathKey("Interface\\AddOns\\DungeonPro\\Media\\Fonts\\AntraktUISans.ttf")
local function locales(locale, gameLocale)
    gameLocale = normalize(gameLocale or addon.Read(GetLocale, "string"))
    if not locale then
        local language = addon.Clean(addon.Language, "table")
        locale = language and addon.Read(language.GetSelection, "string", language)
        local db = addon.Clean(addon.db, "table")
        locale = locale or (db and addon.Clean(rawget(db, "locale"), "string")) or "auto"
    end
    return locale == "auto" and gameLocale or normalize(locale), gameLocale
end

local function supportsGlyphs(font, locale)
    locale = normalize(locale)
    if not locale or not plain(font) then return false end
    local field = scripts[locale]
    return font[field] == true or (field == "latin" and font.latinLocales and font.latinLocales[locale] == true) or false
end

function Fonts:Supported(font, locale)
    locale = normalize(locale)
    if not locale or not plain(font) then return false end
    if font.region then
        if locale == "zhCN" or locale == "zhTW" then
            if font.region ~= locale then return false end
        elseif font.region == "zhTW" then return false end
    end
    return supportsGlyphs(font, locale)
end

local function readCatalog()
    local provider = addon.Clean(rawget(_G, "AntraktFonts"), "table")
    if not plain(provider) then return nil end
    local catalog = addon.Read(rawget(provider, "GetCatalog"), "table")
    if not plain(catalog) or addon.Clean(catalog.formatMajor, "number") ~= 1 or
        not digest(catalog.catalogRevision) or not plain(catalog.fonts) then return nil end
    local count = 0
    for key in pairs(catalog.fonts) do
        count = count + 1
        if count > 256 or not addon.Clean(key, "number") or key % 1 ~= 0 or key < 1 or key > 256 then return nil end
    end
    if count == 0 then return nil end
    local records, ids, files = {}, {}, {}
    for index = 1, count do
        local font = catalog.fonts[index]
        if not plain(font) or not identifier(font.id) or ids[font.id] or not text(font.name, 128) or
            not text(font.file, 128) or not font.file:match("^[A-Za-z0-9_.%-]+%.[to]tf$") or
            files[font.file:lower()] or font.path ~= "Interface\\AddOns\\AntraktFonts\\fonts\\" .. font.file or
            not digest(font.sha256) then return nil end
        local copy = { id = font.id, name = font.name, path = font.path, region = font.region }
        for _, field in ipairs(glyphs) do
            local value = addon.Clean(font[field], "boolean")
            if value == nil then return nil end
            copy[field] = value
        end
        if font.region ~= nil and font.region ~= "zhCN" and font.region ~= "zhTW" then return nil end
        if font.latinLocales ~= nil then
            if not plain(font.latinLocales) then return nil end
            copy.latinLocales = {}
            local total = 0
            for code, value in pairs(font.latinLocales) do
                total = total + 1
                if total > 7 or not addon.Clean(code, "string") or scripts[code] ~= "latin" or
                    addon.Clean(value, "boolean") ~= true then return nil end
                copy.latinLocales[code] = true
            end
        end
        records[#records + 1], ids[font.id], files[font.file:lower()] = copy, copy, true
    end
    return records, ids, catalog.catalogRevision
end

local function copyFont(source, id, name, path, kind, locale)
    local row = { id = id, name = name, path = path, kind = kind, locale = locale }
    for _, field in ipairs(glyphs) do row[field] = source[field] == true end
    row.region, row.latinLocales = source.region, source.latinLocales
    return row
end

-- Refresh only at startup, provider/media boundaries or when the picker opens.
-- Drawing labels and hovering use the detached snapshot, not provider calls.
function Fonts:Refresh()
    local ok, records, ids, revision = pcall(readCatalog)
    self.records, self.byID, self.revision = {}, {}, nil
    if ok and records then self.records, self.byID, self.revision = records, ids, revision end
    self.provider = self.revision and rawget(_G, "AntraktFonts") or nil
    self.extraRecords, self.allByID = {}, {}
    local byPath = { [baselineKey] = true }
    for _, font in ipairs(self.records) do
        font.kind = "provider"
        self.allByID[font.id], byPath[pathKey(font.path)] = font, font
    end
    local function add(id, name, path, kind, locale)
        local key = pathKey(path)
        if not key or byPath[key] or not text(name, 128) then return end
        local source = nativeCoverage[key] or { latinLocales = { enUS = true } }
        local row = copyFont(source, id, name, path:gsub("/", "\\"), kind, locale)
        byPath[key], self.allByID[id] = row, row
        self.extraRecords[#self.extraRecords + 1] = row
    end
    for _, font in ipairs(nativeFonts) do
        add("native:" .. pathKey(font[2]), font[1], font[2], "native", font[3])
    end
    local available, media = pcall(function()
        local stub = rawget(_G, "LibStub")
        return stub and stub("LibSharedMedia-3.0", true)
    end)
    if available and addon.Clean(media, "table") then
        local list = addon.Read(media.List, "table", media, "font")
        if plain(list) and #list <= 512 then
            for index = 1, #list do
                local name = list[index]
                if text(name, 128) then
                    local path = addon.Read(media.Fetch, "string", media, "font", name, true)
                    local key = pathKey(path)
                    if key then add("lsm:" .. key, name, path, "lsm") end
                end
            end
        end
    end
    return self.revision ~= nil
end

local function offered(font, locale, gameLocale)
    return font and (not font.locale or font.locale == locale or font.locale == gameLocale) and
        Fonts:Supported(font, locale) and supportsGlyphs(font, gameLocale)
end
local function asciiLower(value)
    return value:gsub("[A-Z]", function(character) return string.char(character:byte() + 32) end)
end

function Fonts:IsFavorite(id)
    local db = addon.Clean(addon.db, "table")
    local saved = db and rawget(db, "fontFavorites")
    return plain(saved) and addon.Clean(rawget(saved, id or "default"), "boolean") == true or false
end

function Fonts:Choices(locale, gameLocale)
    locale, gameLocale = locales(locale, gameLocale)
    local choices = {}
    for _, list in ipairs({ self.records, self.extraRecords }) do
        for _, font in ipairs(list) do
            if offered(font, locale, gameLocale) then
                choices[#choices + 1] = { id = font.id, name = font.name, path = font.path,
                    kind = font.kind, favorite = self:IsFavorite(font.id) }
            end
        end
    end
    table.sort(choices, function(left, right)
        if left.favorite ~= right.favorite then return left.favorite end
        local first, second = asciiLower(left.name), asciiLower(right.name)
        if first ~= second then return first < second end
        return left.id < right.id
    end)
    return choices
end

local function selected(id, locale, gameLocale)
    if id == nil then return true end
    if not text(id, 600) then return false end
    return offered(Fonts.allByID[id], locale, gameLocale) == true
end

function Fonts:Resolve(locale, gameLocale)
    local db = addon.Clean(addon.db, "table")
    local id = db and addon.Clean(rawget(db, "fontId"), "string")
    if self.preview then id = self.preview.id end
    locale, gameLocale = locales(locale, gameLocale)
    if id and selected(id, locale, gameLocale) then return self.allByID[id].path end
end

function Fonts:Preview(id)
    local locale, gameLocale = locales()
    if not selected(id, locale, gameLocale) then return false end
    self.preview = { id = id }
    return true
end

function Fonts:CancelPreview()
    local active = self.preview ~= nil
    self.preview = nil
    return active
end

function Fonts:Select(id)
    local db = addon.Clean(addon.db, "table")
    local locale, gameLocale = locales()
    if not plain(db) or not selected(id, locale, gameLocale) then return false end
    db.fontId = id
    self.preview = nil
    return true
end

function Fonts:ToggleFavorite(id)
    local db = addon.Clean(addon.db, "table")
    local locale, gameLocale = locales()
    if not plain(db) or not selected(id, locale, gameLocale) then return false end
    local saved = rawget(db, "fontFavorites")
    if saved ~= nil and not plain(saved) then return false end
    local copy, count = {}, 0
    for key, value in pairs(saved or {}) do
        count = count + 1
        if count > 512 or not text(key, 600) or addon.Clean(value, "boolean") ~= true then return false end
        copy[key] = true
    end
    local key = id or "default"
    if copy[key] then copy[key] = nil
    elseif count < 512 then copy[key] = true
    else return false end
    db.fontFavorites = copy
    return true
end

function Fonts:Caption()
    local db = addon.Clean(addon.db, "table")
    local id = db and addon.Clean(rawget(db, "fontId"), "string")
    local font = id and self.allByID[id]
    if font then
        local locale, gameLocale = locales()
        if selected(id, locale, gameLocale) then return font.name end
        local unavailable = addon.Read(addon.L, "string", "FONT_UNAVAILABLE") or "Unavailable"
        return font.name .. " (" .. unavailable .. ")"
    end
    local key = id and "FONT_UNAVAILABLE" or "FONT_DEFAULT"
    return addon.Read(addon.L, "string", key) or (id and "Unavailable" or "Default")
end

local function api(name)
    local modern = rawget(_G, "C_AddOns")
    if modern ~= nil then
        if not plain(modern) then return false, true end
        local method = rawget(modern, name)
        if method ~= nil then return addon.Clean(method, "function") or false, true end
    end
    return addon.Clean(rawget(_G, name), "function"), false
end
local function query(method, ...)
    if type(method) ~= "function" then return nil end
    local ok, first, second = pcall(method, ...)
    if ok then return first, second end
end

function Fonts:ProviderState()
    local existsMethod = api("DoesAddOnExist")
    local exists = addon.Clean(query(existsMethod, "AntraktFonts"), "boolean")
    if existsMethod == nil then
        local countMethod, info = api("GetNumAddOns"), api("GetAddOnInfo")
        local count = addon.Clean(query(countMethod), "number")
        if count and count >= 0 and count <= 1024 and count % 1 == 0 then
            local complete = true
            exists = false
            for index = 1, count do
                local name = addon.Clean(query(info, index), "string")
                if not text(name, 128) then complete = false
                elseif name == "AntraktFonts" then exists = true; break end
            end
            if not complete and exists ~= true then exists = nil end
        end
    end
    local loadedMethod, modernLoaded = api("IsAddOnLoaded")
    local loading, loaded = query(loadedMethod, "AntraktFonts")
    if not modernLoaded and loaded == nil then loaded = loading end
    if addon.Clean(loaded, "boolean") == true then
        local current = rawget(_G, "AntraktFonts")
        return self.revision and current == self.provider and plain(current) and
            addon.Clean(rawget(current, "GetCatalog"), "function") and "ready" or "incompatible"
    end
    if exists == false then return "missing" end
    if exists == true then
        local character = addon.Read(rawget(_G, "UnitGUID"), "string", "player")
        if text(character, 128) then
            local stateMethod, modern = api("GetAddOnEnableState")
            local enabled
            if modern then enabled = query(stateMethod, "AntraktFonts", character)
            else enabled = query(stateMethod, character, "AntraktFonts") end
            if addon.Clean(enabled, "number") == 0 then return "disabled" end
        end
    end
    return "notLoaded"
end
