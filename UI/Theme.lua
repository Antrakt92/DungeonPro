local _, addon = ...
local Theme = {}
addon.Theme = Theme
local surfaces = setmetatable({}, { __mode = "k" })
local windows = setmetatable({}, { __mode = "k" })
local palette = {
    base = { 0.027, 0.038, 0.049, 1 }, panel = { 0.041, 0.058, 0.071, 0.96 },
    row = { 0.059, 0.077, 0.090, 0.96 }, selected = { 0.088, 0.119, 0.132, 1 },
    card = { 0.045, 0.059, 0.071, 1 }, cardSelected = { 0.080, 0.093, 0.101, 1 },
    edge = { 0.20, 0.27, 0.30, 0.55 }, faint = { 0.16, 0.21, 0.24, 0.50 },
    amber = { 0.83, 0.64, 0.34, 0.95 }, teal = { 0.31, 0.67, 0.65, 0.95 },
    scrollThumb = { 0.39, 0.48, 0.51, 0.65 },
    path = { 0.68, 0.51, 0.25, 0.85 }, target = { 0.11, 0.09, 0.052, 0.98 },
    text = { 0.91, 0.91, 0.86, 1 }, muted = { 0.64, 0.71, 0.73, 1 },
    quiet = { 0.49, 0.59, 0.62, 1 }, heading = { 0.91, 0.77, 0.49, 1 },
}

local function cleanObject(value)
    return addon.Clean(value, "table") or addon.Clean(value, "userdata")
end

local function invoke(object, key, ...)
    local fn = addon.Read(function() return object[key] end, "function")
    if not fn then return false end
    return pcall(fn, object, ...)
end

local function objectResult(object, key, ...)
    local ok, value = invoke(object, key, ...)
    return ok and cleanObject(value) or nil
end

local function color(texture, value)
    return texture and invoke(texture, "SetColorTexture", unpack(value))
end

local function texture(parent, layer, sublevel)
    return objectResult(parent, "CreateTexture", nil, layer or "BACKGROUND", nil, sublevel or 0)
end

local function anchor(region, ...)
    invoke(region, "SetPoint", ...)
end

local fontSerial = 0
local styledButtons = setmetatable({}, { __mode = "k" })
local fontRegions, inputRegions = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local NOTO_FONT = "Interface\\AddOns\\DungeonPro\\Media\\Fonts\\NotoSans-Regular.ttf"
local FONT_LOCALES = { enUS = true, enGB = true, ruRU = true, deDE = true, frFR = true,
    esES = true, esMX = true, itIT = true, ptBR = true, koKR = true, zhCN = true, zhTW = true }
local CJK_FONTS = {
    zhCN = { "Fonts\\ARKai_T.ttf", "Fonts\\ARHei.TTF", "Fonts\\ARKai_C.ttf" },
    zhTW = { "Fonts\\bHEI00M.ttf", "Fonts\\ARKai_T.ttf", "Fonts\\ARHei.TTF" },
    koKR = { "Fonts\\2002.ttf", "Fonts\\K_Pagetext.TTF", "Fonts\\K_Damage.TTF" },
}
local function fontContext(explicitLocale)
    local family = cleanObject(ChatFontNormal) or cleanObject(GameFontHighlight)
    local game = addon.Read(GetLocale, "string")
    local database = addon.Clean(addon.db, "table")
    local selection = database and addon.Clean(rawget(database, "locale"), "string") or "auto"
    local language = addon.Clean(addon.Language, "table")
    local preview = language and addon.Read(language.GetSelection, "string", language)
    if preview then selection = preview end
    if explicitLocale and explicitLocale ~= "auto" then selection = explicitLocale end
    if not selection or #selection > 32 then selection = "auto" end
    local locale = selection == "auto" and game or selection
    if locale == "enGB" then locale = "enUS" elseif locale == "esMX" then locale = "esES" end
    if not FONT_LOCALES[locale or ""] then locale = "enUS" end
    local cjk = { koKR = true, zhCN = true, zhTW = true }
    local path = game and FONT_LOCALES[game] and not cjk[game] and not cjk[locale] and NOTO_FONT or nil
    local candidates = CJK_FONTS[locale]
    return { family = family, path = path, candidates = candidates,
        source = candidates and locale or path or "native",
        key = (path or locale) .. ":" .. selection .. ":" .. (game or "?") }
end

local function setFontAsset(region, path, size, fontObject)
    local ok, result = invoke(region, "SetFont", path, size, "")
    if not ok or addon.Clean(result, "boolean") == false then return nil end
    if not fontObject then return addon.Clean(result, "boolean") == true and path or nil end
    -- Font objects have a void SetFont setter; verify the resulting asset and size.
    local inspected, currentPath, height = invoke(region, "GetFont")
    currentPath, height = addon.Clean(currentPath, "string"), addon.Clean(height, "number")
    if inspected and currentPath and #currentPath <= 4096 and height == size and
        currentPath:gsub(string.char(92), "/"):lower() == path:gsub(string.char(92), "/"):lower() then return path end
end

local function applyFontSource(region, size, context, fontObject)
    if context.candidates then
        for _, path in ipairs(context.candidates) do
            if setFontAsset(region, path, size, fontObject) then return path end
        end
    end
    if context.path and setFontAsset(region, context.path, size, fontObject) then return context.path end
    if context.family and invoke(region, "SetFontObject", context.family) and invoke(region, "SetFontHeight", size) then
        return context.family
    end
    if context.path then return nil end
    local path = addon.Clean(STANDARD_TEXT_FONT, "string") or "Fonts\\ARIALN.TTF"
    return setFontAsset(region, path, size, fontObject)
end

local function compatibleSource(context, source)
    if not context.candidates then return true end
    for _, path in ipairs(context.candidates) do if source == path then return true end end
    return false
end

local function matchingFontAsset(region, path, size)
    if not path then return false end
    local ok, currentPath, height, flags = invoke(region, "GetFont")
    currentPath, height = addon.Clean(currentPath, "string"), addon.Clean(height, "number")
    flags = addon.Clean(flags, "string")
    return ok and currentPath and #currentPath <= 4096 and height == size and flags == "" and
        currentPath:gsub(string.char(92), "/"):lower() == path:gsub(string.char(92), "/"):lower()
end

local function matchingFont(region, path, size, font)
    if type(font) ~= "string" and objectResult(region, "GetFontObject") ~= font then return false end
    return matchingFontAsset(region, path, size)
end

local fontCaches, cacheFamily, cacheCreator
local function sourceCache(context, creator)
    if not fontCaches or cacheFamily ~= context.family or cacheCreator ~= creator then
        fontCaches, cacheFamily, cacheCreator = {}, context.family, creator
    end
    local mode = context.source
    local cache = fontCaches[mode]
    if not cache then cache = { text = {} }; fontCaches[mode] = cache end
    return cache
end

local fontUpdates, fontRepairs = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local applyTextFont, applyInputFont, styleButtonFonts

local function updateFont(region, kind, size, locale, paint)
    local previous = fontUpdates[region]
    local creator, getter, clean, read = CreateFont, GetLocale, addon.Clean, addon.Read
    local context = fontContext(locale)
    -- Context getters can complete a newer request before this call paints.
    if addon.Theme ~= Theme or fontUpdates[region] ~= previous then return nil end
    local held = { kind = kind, size = size, locale = locale }
    fontUpdates[region] = held
    local first, second = paint(region, size, locale)
    local fresh = fontContext(locale)
    if addon.Theme == Theme and fontUpdates[region] == held and CreateFont == creator and GetLocale == getter and
        addon.Clean == clean and addon.Read == read and fresh.key == context.key and fresh.source == context.source and
        fresh.family == context.family then return first, second end
    -- A newer request owns the desired font even when its native setter was a
    -- no-op before this older call resumed. Never retain the region in a weak-key value.
    local newer = fontUpdates[region]
    if addon.Theme == Theme and newer and not fontRepairs[region] then
        fontRepairs[region] = true
        if newer.kind == "text" then pcall(applyTextFont, region, newer.size, newer.locale)
        elseif newer.kind == "input" then pcall(applyInputFont, region)
        elseif newer.kind == "button" then pcall(styleButtonFonts, region, newer.locale) end
        fontRepairs[region] = nil
    end
    return nil
end

-- Keep asset overrides on owned font objects when switching back to native families.
local function paintTextFont(region, size, locale)
    region, size = cleanObject(region), addon.Clean(size, "number")
    if not region or not size or size < 1 or size > 72 then return nil end
    local context, creator = fontContext(locale), addon.Clean(CreateFont, "function")
    local previous = fontRegions[region]
    if previous and previous.size == size and previous.locale == locale and previous.source == context.source and
        previous.family == context.family and previous.creator == creator and previous.compatible and
        matchingFont(region, previous.path, size, previous.applied) then
        -- A font readback may release the preview or replace its native family.
        local fresh = fontContext(locale)
        if fresh.key ~= context.key or fresh.source ~= context.source or fresh.family ~= context.family or
            addon.Clean(CreateFont, "function") ~= creator then return nil end
        previous.key = context.key
        return previous.applied, previous.compatible
    end
    local applied, compatible, path
    if creator then
        local fonts = sourceCache(context, creator).text
        local font = fonts[size]
        if font and fonts["path" .. size] and not matchingFontAsset(font, fonts["path" .. size], size) then
            fonts[size], font = nil, nil
        end
        if not font then
            fontSerial = fontSerial + 1
            local ok, value = pcall(creator, "DungeonProTextFont" .. fontSerial)
            font = ok and cleanObject(value) or nil
            local source = font and applyFontSource(font, size, context, true)
            if source then
                invoke(font, "SetShadowOffset", 0, 0)
                fonts[size] = font
                fonts["compatible" .. size] = compatibleSource(context, source)
                fonts["path" .. size] = type(source) == "string" and source or nil
            else font = nil end
        end
        if font and invoke(region, "SetFontObject", font) then
            applied, compatible, path = font, fonts["compatible" .. size], fonts["path" .. size]
        end
    end
    if not applied then
        applied = applyFontSource(region, size, context)
        compatible = compatibleSource(context, applied)
        path = type(applied) == "string" and applied or nil
    end
    if applied then
        invoke(region, "SetShadowOffset", 0, 0)
        fontRegions[region] = { size = size, locale = locale, key = context.key, source = context.source,
            family = context.family, creator = creator, applied = applied, compatible = compatible, path = path }
        return applied, compatible
    end
end

applyTextFont = function(region, size, locale)
    region, size = cleanObject(region), addon.Clean(size, "number")
    if not region or not size or size < 1 or size > 72 then return nil end
    return updateFont(region, "text", size, locale, paintTextFont)
end

function Theme.ApplyFont(region, size)
    return applyTextFont(region, size)
end

-- Each language label retains its own script while the rest of the UI previews another locale.
function Theme.ApplyLanguageFont(region, locale, size)
    locale = addon.Clean(locale, "string")
    if locale ~= "auto" and not FONT_LOCALES[locale or ""] then return nil end
    local font, compatible = applyTextFont(region, size, locale)
    if compatible then return font end
end

local function paintInputFont(region)
    region = cleanObject(region)
    local context = fontContext()
    if not region or not context.family then return nil end
    local creator = addon.Clean(CreateFont, "function")
    local previous = inputRegions[region]
    if previous and previous.source == context.source and previous.family == context.family and
        previous.creator == creator and matchingFont(region, previous.path, 14, previous.applied) then
        local fresh = fontContext()
        if fresh.key ~= context.key or fresh.source ~= context.source or fresh.family ~= context.family or
            addon.Clean(CreateFont, "function") ~= creator then return nil end
        previous.key = context.key
        return previous.applied
    end
    local cache = sourceCache(context, creator)
    local inputFont = cache.input
    if inputFont and inputFont.font and inputFont.path and
        not matchingFontAsset(inputFont.font, inputFont.path, 14) then
        cache.input, inputFont = nil, nil
    end
    if not inputFont then
        inputFont = { family = context.family, creator = creator }
        cache.input = inputFont
        if creator then
            fontSerial = fontSerial + 1
            local ok, value = pcall(creator, "DungeonProInputFont" .. fontSerial)
            local font = ok and cleanObject(value) or nil
            local source = font and applyFontSource(font, 14, context, true)
            if font and source and invoke(font, "SetTextColor", unpack(palette.text)) then
                invoke(font, "SetShadowOffset", 0, 0)
                inputFont.font = font
                inputFont.path = type(source) == "string" and source or nil
            end
        end
    end
    -- EditBox receives an owned font object, never FontString's height setter.
    local font = inputFont.font or context.family
    if invoke(region, "SetFontObject", font) then
        inputRegions[region] = { key = context.key, source = context.source, family = context.family,
            creator = creator, applied = font, path = inputFont.path }
        return font
    end
end

applyInputFont = function(region)
    region = cleanObject(region)
    if not region then return nil end
    return updateFont(region, "input", 14, nil, paintInputFont)
end

function Theme.ApplyInputFont(region)
    return applyInputFont(region)
end

local function matchingControlFonts(button, fonts)
    for _, role in ipairs({ "Normal", "Highlight", "Disabled" }) do
        if objectResult(button, "Get" .. role .. "FontObject") ~= fonts[role] or
            (fonts["path" .. role] and not matchingFontAsset(fonts[role], fonts["path" .. role], 14)) then return false end
    end
    return true
end

local function paintButtonFonts(button, _, locale)
    button = cleanObject(button)
    local context, creator = fontContext(locale), addon.Clean(CreateFont, "function")
    local family = context.family
    if not button or not family or not creator then return false end
    local roles = { { "Normal", palette.text }, { "Highlight", palette.heading }, { "Disabled", palette.quiet } }
    local previous = {}
    for _, role in ipairs(roles) do
        if not addon.Read(function() return button["Set" .. role[1] .. "FontObject"] end, "function") then return false end
        previous[role[1]] = objectResult(button, "Get" .. role[1] .. "FontObject")
        if not previous[role[1]] then return false end
    end
    local cache = sourceCache(context, creator)
    local controlFonts = cache.controls
    if controlFonts and not controlFonts.failed then
        for _, role in ipairs(roles) do
            local path = controlFonts["path" .. role[1]]
            if path and not matchingFontAsset(controlFonts[role[1]], path, 14) then
                cache.controls, controlFonts = nil, nil
                break
            end
        end
    end
    if not controlFonts then
        controlFonts = { family = family, creator = creator, failed = true, compatible = true }
        cache.controls = controlFonts
        for _, role in ipairs(roles) do
            fontSerial = fontSerial + 1
            local ok, value = pcall(creator, "DungeonProControlFont" .. fontSerial)
            local font = ok and cleanObject(value) or nil
            local source = font and applyFontSource(font, 14, context, true)
            if not font or not source or
                not invoke(font, "SetTextColor", unpack(role[2])) then return false end
            invoke(font, "SetShadowOffset", 0, 0)
            controlFonts[role[1]] = font
            controlFonts["path" .. role[1]] = type(source) == "string" and source or nil
            if not compatibleSource(context, source) then controlFonts.compatible = false end
        end
        controlFonts.failed = nil
    end
    if controlFonts.failed then return false end
    local tracked = styledButtons[button]
    if tracked and tracked.fonts == controlFonts and previous.Normal == controlFonts.Normal and
        previous.Highlight == controlFonts.Highlight and previous.Disabled == controlFonts.Disabled then
        tracked.key, tracked.locale = context.key, locale
        return true, controlFonts.compatible
    end
    for _, role in ipairs(roles) do
        if not invoke(button, "Set" .. role[1] .. "FontObject", controlFonts[role[1]]) then
            for _, restore in ipairs(roles) do invoke(button, "Set" .. restore[1] .. "FontObject", previous[restore[1]]) end
            return false
        end
    end
    -- Cached roles may serve the main UI and fixed-language popup rows together.
    -- Their locale binding belongs to each button, not the shared font objects.
    styledButtons[button] = { fonts = controlFonts, key = context.key, locale = locale,
        family = context.family, creator = creator }
    return true, controlFonts.compatible
end

styleButtonFonts = function(button, locale)
    button = cleanObject(button)
    if not button then return false end
    return updateFont(button, "button", 14, locale, paintButtonFonts)
end

function Theme.StyleButtonFonts(button)
    return styleButtonFonts(button)
end

function Theme.StyleLanguageRow(button, locale)
    locale = addon.Clean(locale, "string")
    if locale ~= "auto" and not FONT_LOCALES[locale or ""] then return false end
    local applied, compatible = styleButtonFonts(button, locale)
    return applied and compatible or false
end

local closeButtons = setmetatable({}, { __mode = "k" })

function Theme.StyleCloseButton(button)
    button = cleanObject(button)
    if not button then return false end
    local state = closeButtons[button]
    if state then return state.active == true end
    state = {}; closeButtons[button] = state
    local hook = addon.Read(function() return button.HookScript end, "function")
    local enabled = addon.Read(function() return button:IsEnabled() end, "boolean")
    if not hook or enabled == nil then return false end
    local originals, alphas = {}, {}
    for _, key in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
        local original = objectResult(button, "Get" .. key .. "Texture")
        local alpha = original and addon.Read(function() return original:GetAlpha() end, "number")
        if not original or alpha == nil or alpha < 0 or alpha > 1 or not addon.Read(function() return original.SetAlpha end, "function") then return false end
        originals[key], alphas[key] = original, alpha
    end
    local background = texture(button, "BACKGROUND")
    local glyph = objectResult(button, "CreateFontString", nil, "OVERLAY")
    if background and not invoke(background, "Hide") then return false end
    if glyph and not invoke(glyph, "Hide") then return false end
    if not background or not glyph or not Theme.ApplyFont(glyph, 20) or
        not invoke(background, "SetAllPoints", button) or not color(background, palette.panel) or
        not invoke(glyph, "SetAllPoints", button) or not invoke(glyph, "SetJustifyH", "CENTER") or
        not invoke(glyph, "SetJustifyV", "MIDDLE") or not invoke(glyph, "SetText", "×") or
        not invoke(glyph, "SetTextColor", unpack(palette.muted)) then return false end
    state.background, state.glyph = background, glyph
    local function refresh()
        if not state.active then return end
        local on = addon.Read(function() return button:IsEnabled() end, "boolean") == true
        color(background, on and (state.pressed and palette.selected or state.hover and palette.row or palette.panel) or palette.panel)
        invoke(glyph, "SetTextColor", unpack(on and (state.hover and palette.text or palette.muted) or palette.quiet))
        invoke(glyph, "SetAlpha", on and 1 or 0.45)
    end
    state.refresh = refresh
    for _, event in ipairs({ "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp", "OnHide", "OnEnable", "OnDisable" }) do
        local name = event
        local ok, installed = pcall(hook, button, name, function()
            if name == "OnEnter" then state.hover = true end
            if name == "OnLeave" or name == "OnHide" or name == "OnDisable" then state.hover, state.pressed = false, false end
            if name == "OnMouseDown" then state.pressed = true end
            if name == "OnMouseUp" then state.pressed = false end
            refresh()
        end)
        if not ok or addon.Clean(installed, "boolean") ~= true then return false end
    end
    for key, original in pairs(originals) do
        if not invoke(original, "SetAlpha", 0) then
            for field, previous in pairs(originals) do invoke(previous, "SetAlpha", alphas[field]) end
            return false
        end
    end
    state.active = true
    refresh()
    if not invoke(background, "Show") or not invoke(glyph, "Show") then
        state.active = nil
        invoke(background, "Hide"); invoke(glyph, "Hide")
        for field, previous in pairs(originals) do invoke(previous, "SetAlpha", alphas[field]) end
        return false
    end
    return true
end

function Theme.RefreshFonts()
    local context, creator = fontContext(), addon.Clean(CreateFont, "function")
    for region, previous in pairs(fontRegions) do
        local intent = fontUpdates[region]
        local target = previous.locale and fontContext(previous.locale) or context
        local repair = previous.key ~= target.key or previous.family ~= target.family or previous.creator ~= creator or
            (previous.path and not matchingFont(region, previous.path, previous.size, previous.applied))
        if repair and fontUpdates[region] == intent and fontRegions[region] == previous then
            applyTextFont(region, previous.size, previous.locale)
        end
    end
    for region, previous in pairs(inputRegions) do
        local intent = fontUpdates[region]
        local repair = previous.key ~= context.key or previous.family ~= context.family or previous.creator ~= creator or
            (previous.path and not matchingFont(region, previous.path, 14, previous.applied))
        if repair and fontUpdates[region] == intent and inputRegions[region] == previous then Theme.ApplyInputFont(region) end
    end
    for button, previous in pairs(styledButtons) do
        local intent = fontUpdates[button]
        local target = previous.locale and fontContext(previous.locale) or context
        local repair = previous.key ~= target.key or previous.family ~= target.family or previous.creator ~= creator or
            not matchingControlFonts(button, previous.fonts)
        if repair and fontUpdates[button] == intent and styledButtons[button] == previous then styleButtonFonts(button, previous.locale) end
    end
    for _, state in pairs(closeButtons) do
        if state.active then invoke(state.glyph, "SetText", "×"); state.refresh() end
    end
end

local function surface(frame, existing)
    local state = surfaces[frame]
    if state then return not state.failed and state or nil end
    state = { failed = true }
    surfaces[frame] = state
    state.bg = cleanObject(existing) or texture(frame, "BACKGROUND", -6)
    state.top, state.bottom = texture(frame, "BORDER"), texture(frame, "BORDER")
    state.left, state.right = texture(frame, "BORDER"), texture(frame, "BORDER")
    state.accent = texture(frame, "BORDER", 1)
    if not state.bg or not state.top or not state.bottom or not state.left or not state.right or not state.accent then return nil end
    invoke(state.bg, "SetAllPoints", frame)
    for _, edge in ipairs({ state.top, state.bottom }) do invoke(edge, "SetHeight", 1) end
    for _, edge in ipairs({ state.left, state.right }) do invoke(edge, "SetWidth", 1) end
    anchor(state.top, "TOPLEFT", frame, "TOPLEFT", 0, 0); anchor(state.top, "TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    anchor(state.bottom, "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0); anchor(state.bottom, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    anchor(state.left, "TOPLEFT", frame, "TOPLEFT", 0, 0); anchor(state.left, "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    anchor(state.right, "TOPRIGHT", frame, "TOPRIGHT", 0, 0); anchor(state.right, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    invoke(state.accent, "SetWidth", 2)
    anchor(state.accent, "TOPLEFT", frame, "TOPLEFT", 0, -1); anchor(state.accent, "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 1)
    for _, part in ipairs({ state.bg, state.top, state.bottom, state.left, state.right }) do invoke(part, "Show") end
    invoke(state.accent, "Hide")
    state.failed = nil
    return state
end

local function edges(state, value)
    for _, region in ipairs({ state.top, state.bottom, state.left, state.right }) do color(region, value) end
end

local function textColor(fontString, value)
    if cleanObject(fontString) then invoke(fontString, "SetTextColor", unpack(value)) end
end

local function cardArt(state, row, active, selected)
    local art = cleanObject(row.art)
    if active and art and not state.cardFrame then
        state.cardFrame = {}
        for index = 1, 4 do
            local edge = texture(row, "OVERLAY")
            if not edge then break end
            state.cardFrame[index] = edge
            local horizontal = index <= 2
            invoke(edge, horizontal and "SetHeight" or "SetWidth", 1)
            local first = index == 2 and "BOTTOMLEFT" or index == 4 and "TOPRIGHT" or "TOPLEFT"
            local last = index == 1 and "TOPRIGHT" or index == 3 and "BOTTOMLEFT" or "BOTTOMRIGHT"
            anchor(edge, first, art, first, 0, 0)
            anchor(edge, last, art, last, 0, 0)
        end
    end
    for _, edge in ipairs(state.cardFrame or {}) do
        color(edge, selected and palette.amber or palette.edge)
        invoke(edge, active and "Show" or "Hide")
    end
end

function Theme.StyleRow(row, options)
    row = cleanObject(row)
    if not row then return false end
    options = addon.Clean(options, "table") or {}
    local kind = addon.Clean(options.kind, "string") or "quest"
    if kind ~= "dungeon" and kind ~= "quest" and kind ~= "section" and kind ~= "control" then return false end
    local selected = addon.Clean(options.selected, "boolean") == true
    local state = surface(row, row.bg)
    if not state then return false end
    local revision = {}
    state.rowRevision, state.rowKind, state.rowSelected = revision, kind, selected
    local anchor = addon.Clean(row.questTreeAnchor, "boolean") == true
    local branch = kind == "quest" and addon.Clean(row.questTreeNode, "boolean") == true
    local path = branch and addon.Clean(row.questTreePath, "boolean") == true
    local target = branch and addon.Clean(row.questTreeTarget, "boolean") == true
    local dungeon = branch and addon.Clean(row.dungeonTarget, "boolean") == true
    local background = selected and palette.selected or (target and palette.target or
        ((kind == "section" or anchor) and palette.panel or palette.row))
    if kind == "dungeon" then background = selected and palette.cardSelected or palette.card end
    local border = (target and palette.amber) or ((selected or anchor) and palette.teal) or palette.faint
    color(state.bg, background)
    edges(state, kind == "dungeon" and selected and palette.amber or border)
    color(state.accent, kind == "dungeon" and palette.amber or palette.teal)
    invoke(state.accent, (selected or anchor) and "Show" or "Hide")
    textColor(row.title, (anchor or target or dungeon or kind == "section") and palette.heading or
        (branch and not path and not selected and palette.muted or palette.text))
    textColor(row.note, palette.muted)
    if kind == "dungeon" then textColor(row.title, selected and palette.heading or palette.text) end
    cardArt(state, row, kind == "dungeon", selected)
    textColor(row.dungeonTargetLabel, palette.heading)
    for _, connector in ipairs({ row.treeRail, row.treeElbow }) do
        if cleanObject(connector) then color(connector, path and palette.path or palette.faint) end
    end
    local highlight = objectResult(row, "GetHighlightTexture")
    if highlight then invoke(highlight, "SetColorTexture", 0.55, 0.72, 0.73, kind == "dungeon" and .055 or .09) end
    if kind == "control" then
        Theme.StyleButtonFonts(row)
        for _, name in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
            local original = objectResult(row, name)
            if original then invoke(original, "SetAlpha", 0) end
        end
        for _, key in ipairs({ "Left", "Middle", "Right" }) do
            local original = cleanObject(row[key])
            if original then invoke(original, "SetAlpha", 0) end
        end
        if highlight then invoke(highlight, "SetAllPoints", row) end
        -- The template keeps its normal, highlighted and disabled font states.
    end
    if addon.Theme == Theme and state.rowRevision ~= revision and not state.rowRepairing then
        state.rowRepairing = true
        Theme.StyleRow(row, { kind = state.rowKind, selected = state.rowSelected })
        state.rowRepairing = nil
        return false
    end
    return true
end

local searchStyles, filterStyles = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })

local function quietNativeArt(control)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        local original = cleanObject(control[key])
        if original then invoke(original, "SetAlpha", 0) end
    end
    for _, key in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        local original = objectResult(control, key)
        if original then invoke(original, "SetAlpha", 0) end
    end
end

function Theme.StyleSearch(editBox, clearButton)
    editBox = cleanObject(editBox)
    if not editBox then return false end
    local state = searchStyles[editBox]
    if state and state.building then return false end
    if not state then
        state = { building = true }; searchStyles[editBox] = state
        state.surface = surface(editBox)
        if not state.surface then return false end
        state.icon = texture(editBox, "ARTWORK")
        if state.icon then
            invoke(state.icon, "Hide")
            local ok, accepted = invoke(state.icon, "SetAtlas", "common-search-magnifyingglass", false)
            local atlas = addon.Read(function() return state.icon:GetAtlas() end, "string")
            local ready = ok and addon.Clean(accepted, "boolean") ~= false and atlas == "common-search-magnifyingglass"
            if not ready then
                -- The legacy search-icon crop comes from the same native UI art.
                ok, accepted = invoke(state.icon, "SetTexture", "Interface\\EncounterJournal\\UI-EncounterJournalTextures")
                ready = ok and addon.Clean(accepted, "boolean") ~= false and
                    invoke(state.icon, "SetTexCoord", .8984375, .97265625, .21386719, .25097656)
            end
            if ready and invoke(state.icon, "SetWidth", 12) and invoke(state.icon, "SetHeight", 12) and
                invoke(state.icon, "SetPoint", "LEFT", editBox, "LEFT", 8, 0) then invoke(state.icon, "Show") end
        end
        state.focus = addon.Read(function() return editBox:HasFocus() end, "boolean") == true
        local function refresh()
            if addon.Theme ~= Theme or searchStyles[editBox] ~= state then return end
            local revision = state.revision
            color(state.surface.bg, palette.panel)
            edges(state.surface, state.focus and palette.teal or (state.hover and palette.edge or palette.faint))
            invoke(state.surface.accent, "Hide")
            if state.icon then invoke(state.icon, "SetVertexColor", unpack(state.focus and palette.text or palette.muted)) end
            if state.revision ~= revision and not state.repairing then
                state.repairing = true; refresh(); state.repairing = nil
            end
        end
        state.refresh = refresh
        local hook = addon.Read(function() return editBox.HookScript end, "function")
        if hook then
            for _, entry in ipairs({ { "OnEditFocusGained", "focus", true }, { "OnEditFocusLost", "focus", false },
                { "OnEnter", "hover", true }, { "OnLeave", "hover", false }, { "OnHide", "focus", false } }) do
                local key, field, value = entry[1], entry[2], entry[3]
                local ok, installed = pcall(hook, editBox, key, function()
                    if addon.Theme ~= Theme or searchStyles[editBox] ~= state then return end
                    state[field] = value
                    state.revision = {}
                    if key == "OnHide" then state.hover = false end
                    refresh()
                end)
                if not ok or addon.Clean(installed, "boolean") ~= true then break end
            end
        end
        state.building = nil
    end
    if not state.surface then return false end
    state.revision = {}
    quietNativeArt(editBox)
    state.refresh()
    clearButton = cleanObject(clearButton)
    if clearButton then
        Theme.StyleRow(clearButton, { kind = "control" })
        local clearSurface = surfaces[clearButton]
        if clearSurface then
            color(clearSurface.bg, { 0, 0, 0, 0 }); edges(clearSurface, { 0, 0, 0, 0 })
            invoke(clearSurface.accent, "Hide")
        end
    end
    return true
end

function Theme.StyleFilter(button, active)
    button = cleanObject(button)
    if not button then return false end
    active = addon.Clean(active, "boolean") == true
    local state = filterStyles[button]
    if state and state.building then return false end
    if not state then
        state = { building = true }; filterStyles[button] = state
        state.surface = surface(button, button.bg)
        if not state.surface then return false end
        local function refresh()
            if addon.Theme ~= Theme or filterStyles[button] ~= state then return end
            local revision = state.revision
            local enabled = addon.Read(function() return button:IsEnabled() end, "boolean") == true
            color(state.surface.bg, state.active and palette.selected or palette.panel)
            edges(state.surface, state.active and palette.amber or (state.hover and palette.edge or palette.faint))
            invoke(state.surface.accent, "Hide")
            local tint = enabled and (state.active and palette.amber or (state.hover and palette.text or palette.muted)) or palette.quiet
            local icon = cleanObject(button.filterIcon)
            if icon then
                local portrait = addon.Clean(button.filterPortrait, "boolean") == true
                if portrait then invoke(icon, "SetVertexColor", 1, 1, 1)
                else invoke(icon, "SetVertexColor", unpack(tint)) end
                invoke(icon, "SetAlpha", enabled and 1 or .4)
            end
            textColor(button.filterCaption, enabled and palette.text or palette.quiet)
            local list = addon.Clean(button.filterList, "table")
            for index = 1, math.min(list and #list or 0, 3) do
                local strip = cleanObject(list[index])
                if strip then
                    invoke(strip, "SetVertexColor", unpack(tint))
                    invoke(strip, "SetAlpha", enabled and 1 or .4)
                end
            end
            if state.revision ~= revision and not state.repairing then
                state.repairing = true; refresh(); state.repairing = nil
            end
        end
        state.refresh = refresh
        local hook = addon.Read(function() return button.HookScript end, "function")
        if hook then
            for _, name in ipairs({ "OnEnter", "OnLeave", "OnEnable", "OnDisable" }) do
                local event = name
                local ok, installed = pcall(hook, button, event, function()
                    if addon.Theme ~= Theme or filterStyles[button] ~= state then return end
                    if event == "OnEnter" then state.hover = true
                    elseif event == "OnLeave" or event == "OnDisable" then state.hover = false end
                    state.revision = {}
                    refresh()
                end)
                if not ok or addon.Clean(installed, "boolean") ~= true then break end
            end
        end
        state.building = nil
    end
    if not state.surface then return false end
    state.active, state.revision = active, {}
    quietNativeArt(button)
    state.refresh()
    return true
end

local scrollbars, scrollArrows = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })

local function quietScrollBar(scroll, bar, state)
    if state.quietAttempted then return end
    state.quietAttempted = true
    local mouse = addon.Clean(MouseIsOver, "function")
    local range = addon.Read(function() return bar.GetMinMaxValues end, "function")
    local objects = { bar, cleanObject(bar.ScrollUpButton), cleanObject(bar.ScrollDownButton) }
    local policies = {}
    local originalAlpha = addon.Read(function() return bar:GetAlpha() end, "number") or 1
    if not mouse or not range or #objects ~= 3 then return end
    for _, object in ipairs(objects) do
        local enabled = addon.Read(function() return object:IsMouseEnabled() end, "boolean")
        if enabled == nil or not addon.Read(function() return object.EnableMouse end, "function") or
            not addon.Read(function() return object.HookScript end, "function") then return end
        policies[object] = enabled
    end
    if not addon.Read(function() return scroll.HookScript end, "function") or
        not addon.Read(function() return scroll.IsShown end, "function") or
        not addon.Read(function() return bar.IsShown end, "function") or
        not addon.Read(function() return bar.SetAlpha end, "function") then return end
    local function current()
        return state.quiet and addon.Theme == Theme and scrollbars[bar] == state and
            scroll.ScrollBar == bar and MouseIsOver == mouse and bar.GetMinMaxValues == range
    end
    local function update()
        if not current() then
            if state.quiet and addon.Theme == Theme and scrollbars[bar] == state and scroll.ScrollBar == bar then
                state.quiet = false
                invoke(bar, "SetAlpha", originalAlpha)
                for _, object in ipairs(objects) do invoke(object, "EnableMouse", policies[object]) end
            end
            return
        end
        if state.quietBusy then return end
        state.quietBusy = true
        local scrollShown = addon.Read(function() return scroll.IsVisible or scroll.IsShown end, "function")
        local barShown = addon.Read(function() return bar.IsVisible or bar.IsShown end, "function")
        local shown = addon.Read(scrollShown, "boolean", scroll) == true and addon.Read(barShown, "boolean", bar) == true
        local down = addon.Clean(IsMouseButtonDown, "function")
        if state.quietPressed and down and addon.Read(down, "boolean", "LeftButton") == false then state.quietPressed = false end
        local ok, minimum, maximum = pcall(range, bar)
        minimum, maximum = addon.Clean(minimum, "number"), addon.Clean(maximum, "number")
        local overflow = ok and minimum ~= nil and maximum ~= nil and maximum > minimum
        local viewport, controls = false, false
        if shown and overflow then
            viewport = addon.Read(mouse, "boolean", scroll) == true
            for _, object in ipairs(objects) do
                if addon.Read(mouse, "boolean", object) == true then controls = true end
            end
        else state.quietPressed = false end
        local active = shown and overflow and (viewport or controls or state.quietPressed)
        local alpha = active and ((controls or state.quietPressed) and 1 or .5) or 0
        if current() and state.quietAlpha ~= alpha then
            if invoke(bar, "SetAlpha", alpha) and current() then state.quietAlpha = alpha end
        end
        for _, object in ipairs(objects) do
            local enabled = active == true and policies[object] == true
            state.quietMouse = state.quietMouse or {}
            if current() and state.quietMouse[object] ~= enabled then
                if invoke(object, "EnableMouse", enabled) and current() then state.quietMouse[object] = enabled end
            end
        end
        state.quietBusy = false
    end
    local function hook(object, name, callback)
        local ok, installed = pcall(object.HookScript, object, name, callback)
        return ok and addon.Clean(installed, "boolean") == true
    end
    for _, object in ipairs(objects) do
        for _, name in ipairs({ "OnEnter", "OnLeave", "OnShow", "OnHide" }) do
            if not hook(object, name, update) then return end
        end
        if not hook(object, "OnMouseDown", function(_, button)
            if current() and addon.Clean(button, "string") == "LeftButton" then state.quietPressed = true; update() end
        end) or not hook(object, "OnMouseUp", function()
            if current() then state.quietPressed = false; update() end
        end) then return end
    end
    for _, name in ipairs({ "OnEnter", "OnLeave", "OnShow", "OnHide" }) do
        if not hook(scroll, name, update) then return end
    end
    if not hook(scroll, "OnUpdate", function(_, elapsed)
        if not state.quiet then return end
        elapsed = addon.Clean(elapsed, "number")
        if not elapsed or elapsed < 0 then return end
        state.quietElapsed = (state.quietElapsed or 0) + elapsed
        if state.quietElapsed < .08 then return end
        state.quietElapsed = 0
        update()
    end) then return end
    state.quiet = true
    update()
end

local function styleScrollArrow(button, down)
    button = cleanObject(button)
    if not button then return false end
    local state = scrollArrows[button]
    if state then return state.active == true end
    state = {}; scrollArrows[button] = state
    local hook = addon.Read(function() return button.HookScript end, "function")
    local enabled = addon.Read(function() return button:IsEnabled() end, "boolean")
    local originals, originalAlphas = {}, {}
    for _, key in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
        originals[key] = cleanObject(button[key]) or objectResult(button, "Get" .. key .. "Texture")
        if not originals[key] or not addon.Read(function() return originals[key].SetAlpha end, "function") then return false end
        originalAlphas[key] = addon.Read(function() return originals[key]:GetAlpha() end, "number")
        if originalAlphas[key] == nil then return false end
    end
    if not hook or enabled == nil then return false end
    local left, right = texture(button, "OVERLAY"), texture(button, "OVERLAY")
    if left then invoke(left, "Hide") end
    if right then invoke(right, "Hide") end
    if not left or not right then return false end
    state.parts = { left, right }
    for index, part in ipairs(state.parts) do
        invoke(part, "Hide")
        if not invoke(part, "SetWidth", 6) or not invoke(part, "SetHeight", 2) or
            not invoke(part, "SetPoint", "CENTER", button, "CENTER", index == 1 and -2 or 2, 0) or
            not invoke(part, "SetRotation", (index == 1 and 1 or -1) * (down and -1 or 1) * math.pi / 4) or
            not color(part, palette.muted) then return false end
    end
    local function refresh()
        if not state.active then return end
        local on = addon.Read(function() return button:IsEnabled() end, "boolean")
        local tint = on == true and (state.hover and palette.teal or palette.muted) or palette.quiet
        for _, part in ipairs(state.parts) do
            color(part, tint); invoke(part, "SetAlpha", on == true and 1 or 0.38)
        end
    end
    for _, entry in ipairs({ { "OnEnter", true }, { "OnLeave", false }, { "OnEnable" }, { "OnDisable" } }) do
        local name, hover = entry[1], entry[2]
        local ok, installed = pcall(hook, button, name, function()
            if name == "OnEnter" or name == "OnLeave" then state.hover = hover end
            if name == "OnDisable" then state.hover = false end
            refresh()
        end)
        if not ok or addon.Clean(installed, "boolean") ~= true then return false end
    end
    for key, original in pairs(originals) do
        if not invoke(original, "SetAlpha", 0) then
            for field, previous in pairs(originals) do invoke(previous, "SetAlpha", originalAlphas[field]) end
            return false
        end
    end
    state.active = true
    for _, part in ipairs(state.parts) do invoke(part, "Show") end
    refresh()
    return true
end

function Theme.StyleScrollBar(scroll)
    scroll = cleanObject(scroll)
    local bar = scroll and cleanObject(scroll.ScrollBar)
    if not bar then return false end
    local state = scrollbars[bar]
    if not state then
        state = {}; scrollbars[bar] = state
        local thumb = cleanObject(bar.ThumbTexture) or objectResult(bar, "GetThumbTexture")
        local rail = texture(bar, "BACKGROUND", -1)
        if rail then
            invoke(rail, "Hide")
            if invoke(rail, "SetWidth", 3) and invoke(rail, "SetPoint", "TOP", bar, "TOP", 0, 0) and
                invoke(rail, "SetPoint", "BOTTOM", bar, "BOTTOM", 0, 0) and color(rail, palette.faint) then
                invoke(rail, "Show"); state.rail = rail
            end
        end
        -- Native thumb dimensions and anchors remain the slider's drag target.
        state.thumb = thumb and color(thumb, palette.scrollThumb) and thumb or nil
    end
    styleScrollArrow(bar.ScrollUpButton, false)
    styleScrollArrow(bar.ScrollDownButton, true)
    quietScrollBar(scroll, bar, state)
    return state.rail ~= nil and state.thumb ~= nil
end

local function panel(frame, target)
    if not target then return nil end
    local parts = { texture(frame, "BACKGROUND", -5), texture(frame, "BACKGROUND", -4), texture(frame, "BACKGROUND", -3) }
    if #parts ~= 3 then return nil end
    anchor(parts[1], "TOPLEFT", target, "TOPLEFT", -9, 5)
    anchor(parts[1], "BOTTOMRIGHT", target, "BOTTOMRIGHT", 9, -11)
    color(parts[1], { 0, 0, 0, 0.38 })
    anchor(parts[2], "TOPLEFT", target, "TOPLEFT", -7, 7)
    anchor(parts[2], "BOTTOMRIGHT", target, "BOTTOMRIGHT", 7, -7)
    color(parts[2], palette.panel)
    invoke(parts[3], "SetHeight", 1)
    anchor(parts[3], "TOPLEFT", target, "TOPLEFT", -6, 7)
    anchor(parts[3], "TOPRIGHT", target, "TOPRIGHT", 6, 7)
    color(parts[3], palette.edge)
    return parts
end

local function strip(parent, height, from, to, offset, tint)
    local region = texture(parent, "BACKGROUND", -5)
    if not region then return nil end
    invoke(region, "SetHeight", height)
    anchor(region, from, parent, from, 18, offset); anchor(region, to, parent, to, -18, offset)
    color(region, tint); invoke(region, "Show")
    return region
end

local function catalogVisibility(ui, force)
    ui = addon.Clean(ui, "table")
    local frame = ui and cleanObject(ui.frame)
    local state = frame and windows[frame]
    local parts = state and state.panels and state.panels.catalog
    if not frame or addon.Theme ~= Theme then return false end
    if not parts then return true end
    local rawMode = rawget(ui, "catalogCollapsed")
    local hidden = addon.Clean(rawMode, "boolean") == true
    if not force and state.catalogHidden == hidden then return true end
    local revision = {}
    state.catalogVisibilityRevision, state.catalogHidden = revision, nil
    local function current()
        return addon.Theme == Theme and ui.frame == frame and windows[frame] == state and
            state.panels.catalog == parts and state.catalogVisibilityRevision == revision and
            rawequal(rawget(ui, "catalogCollapsed"), rawMode)
    end
    for _, part in ipairs(parts) do
        if not current() then return false end
        local method = hidden and "Hide" or "Show"
        local writer = addon.Read(function() return part[method] end, "function")
        if not current() or not writer then return false end
        local ok = pcall(writer, part)
        if not current() then
            -- A native setter can finish after a newer layout has shown the panel.
            if addon.Theme == Theme and ui.frame == frame and windows[frame] == state and
                state.panels.catalog == parts and not state.catalogVisibilityRepairing then
                state.catalogVisibilityRepairing = true
                catalogVisibility(ui, true)
                state.catalogVisibilityRepairing = nil
            end
            return false
        end
        if not ok then return false end
    end
    state.catalogHidden = hidden
    return true
end

function Theme.SetCatalogVisible(ui)
    return catalogVisibility(ui, false)
end

function Theme.Apply(ui)
    ui = addon.Clean(ui, "table")
    local frame = ui and cleanObject(ui.frame)
    if not frame then return false end
    local state = surface(frame)
    if not state then return false end
    invoke(frame, "SetBackdrop", nil)
    color(state.bg, palette.base); edges(state, palette.edge)
    local decoration = windows[frame]
    if not decoration then
        decoration = {}
        windows[frame] = decoration
        decoration.header = strip(frame, 1, "TOPLEFT", "TOPRIGHT", -54, palette.amber)
    end
    if not decoration.panels then
        decoration.panels = {}
        local catalog = cleanObject(ui.catalogScroll) or (cleanObject(ui.catalog) and objectResult(ui.catalog, "GetParent"))
        for key, target in pairs({ catalog = catalog, quests = cleanObject(ui.questScroll), detail = cleanObject(ui.detailScroll) }) do
            decoration.panels[key] = panel(frame, target)
        end
        decoration.catalogHidden = false
    end
    if not Theme.SetCatalogVisible(ui) then return false end
    local catalogScroll = cleanObject(ui.catalogScroll) or (cleanObject(ui.catalog) and objectResult(ui.catalog, "GetParent"))
    for _, scroll in pairs({ catalogScroll, cleanObject(ui.questScroll), cleanObject(ui.detailScroll) }) do Theme.StyleScrollBar(scroll) end
    textColor(ui.title, palette.heading); textColor(ui.subtitle, palette.muted)
    textColor(ui.heading, palette.text); textColor(ui.summary, palette.muted)
    textColor(ui.coverage, palette.quiet)
    textColor(ui.capacityStatus, palette.muted); textColor(ui.searchPlaceholder, palette.quiet)
    if cleanObject(ui.searchBox) then Theme.StyleSearch(ui.searchBox, ui.clearSearch) end
    for _, key in ipairs({ "back", "rangeButton", "preparationButton", "characterButton", "language", "map", "guide", "source", "giver" }) do
        local button = cleanObject(ui[key])
        if button then
            if key == "rangeButton" or key == "characterButton" or cleanObject(button.filterIcon) then Theme.StyleFilter(button, button.filterSelected)
            else Theme.StyleRow(button, { kind = "control" }) end
        end
    end
    return true
end
