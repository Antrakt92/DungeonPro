local _, addon = ...
local Fonts = { records = {}, byID = {} }
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

-- Refresh only at provider/startup boundaries or when the picker opens; drawing
-- a label reads this detached snapshot without calling the optional provider.
function Fonts:Refresh()
    local ok, records, ids, revision = pcall(readCatalog)
    self.records, self.byID, self.revision = {}, {}, nil
    if ok and records then
        self.records, self.byID, self.revision = records, ids, revision
        return true
    end
    return false
end

function Fonts:Choices(locale, gameLocale)
    locale, gameLocale = locales(locale, gameLocale)
    local choices = {}
    for _, font in ipairs(self.records) do
        -- Regional forms follow the chosen UI language; native text still needs
        -- its glyphs, but its locale does not choose a second conflicting region.
        if self:Supported(font, locale) and supportsGlyphs(font, gameLocale) then
            choices[#choices + 1] = { id = font.id, name = font.name, path = font.path }
        end
    end
    return choices
end

function Fonts:Resolve(locale, gameLocale)
    local db = addon.Clean(addon.db, "table")
    local id = db and addon.Clean(rawget(db, "fontId"), "string")
    local font = id and self.byID[id]
    locale, gameLocale = locales(locale, gameLocale)
    if font and self:Supported(font, locale) and supportsGlyphs(font, gameLocale) then return font.path end
end

function Fonts:Select(id)
    local db = addon.Clean(addon.db, "table")
    if not plain(db) then return false end
    if id ~= nil then
        if not identifier(id) then return false end
        local locale, gameLocale = locales()
        local font = self.byID[id]
        if not font or not self:Supported(font, locale) or not supportsGlyphs(font, gameLocale) then return false end
    end
    db.fontId = id
    return true
end

function Fonts:Caption()
    local db = addon.Clean(addon.db, "table")
    local id = db and addon.Clean(rawget(db, "fontId"), "string")
    local font = id and self.byID[id]
    if font then
        if self:Resolve() then return font.name end
        local unavailable = addon.Read(addon.L, "string", "FONT_UNAVAILABLE") or "Unavailable"
        return font.name .. " (" .. unavailable .. ")"
    end
    local key = id and "FONT_UNAVAILABLE" or "FONT_DEFAULT"
    return addon.Read(addon.L, "string", key) or (id and "Unavailable" or "Default")
end
