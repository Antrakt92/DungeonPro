local _, addon = ...
local Theme = {}
addon.Theme = Theme
local surfaces = setmetatable({}, { __mode = "k" })
local windows = setmetatable({}, { __mode = "k" })
local palette = {
    base = { 0.027, 0.038, 0.049, 0.99 }, panel = { 0.041, 0.058, 0.071, 0.96 },
    row = { 0.059, 0.077, 0.090, 0.96 }, selected = { 0.088, 0.119, 0.132, 1 },
    edge = { 0.20, 0.27, 0.30, 0.55 }, faint = { 0.16, 0.21, 0.24, 0.50 },
    amber = { 0.83, 0.64, 0.34, 0.95 }, teal = { 0.31, 0.67, 0.65, 0.95 },
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

local controlFonts, fontSerial = nil, 0
local styledButtons = setmetatable({}, { __mode = "k" })
local fontRegions, inputRegions = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local NOTO_FONT = "Interface\\AddOns\\DungeonPro\\Media\\Fonts\\NotoSans-Regular.ttf"
local FONT_LOCALES = { enUS = true, enGB = true, ruRU = true, deDE = true, frFR = true,
    esES = true, esMX = true, itIT = true, ptBR = true, koKR = true, zhCN = true, zhTW = true }
local function fontContext()
    local family = cleanObject(ChatFontNormal) or cleanObject(GameFontHighlight)
    local game = addon.Read(GetLocale, "string")
    local database = addon.Clean(addon.db, "table")
    local selection = database and addon.Clean(rawget(database, "locale"), "string") or "auto"
    if not selection or #selection > 32 then selection = "auto" end
    local locale = selection == "auto" and game or selection
    if locale == "enGB" then locale = "enUS" elseif locale == "esMX" then locale = "esES" end
    if not FONT_LOCALES[locale or ""] then locale = "enUS" end
    local cjk = { koKR = true, zhCN = true, zhTW = true }
    local path = game and FONT_LOCALES[game] and not cjk[game] and not cjk[locale] and NOTO_FONT or nil
    return { family = family, path = path, key = (path or "native") .. ":" .. selection .. ":" .. (game or "?") }
end

local function setFontAsset(region, path, size, fontObject)
    local ok, result = invoke(region, "SetFont", path, size, "")
    if not ok then return nil end
    if not fontObject then return addon.Clean(result, "boolean") == true and path or nil end
    -- Font objects have a void SetFont setter; verify the resulting asset and size.
    local inspected, currentPath, height = invoke(region, "GetFont")
    currentPath, height = addon.Clean(currentPath, "string"), addon.Clean(height, "number")
    if inspected and currentPath and #currentPath <= 4096 and height == size and
        currentPath:gsub(string.char(92), "/"):lower() == path:gsub(string.char(92), "/"):lower() then return path end
end

local function applyFontSource(region, size, context, fontObject)
    if context.path and setFontAsset(region, context.path, size, fontObject) then return context.path end
    if context.family and invoke(region, "SetFontObject", context.family) and invoke(region, "SetFontHeight", size) then
        return context.family
    end
    if context.path then return nil end
    local path = addon.Clean(STANDARD_TEXT_FONT, "string") or "Fonts\\ARIALN.TTF"
    return setFontAsset(region, path, size, fontObject)
end

local fontCaches, cacheFamily, cacheCreator
local function sourceCache(context, creator)
    if not fontCaches or cacheFamily ~= context.family or cacheCreator ~= creator then
        fontCaches, cacheFamily, cacheCreator = {}, context.family, creator
    end
    local mode = context.path and "bundled" or "native"
    local cache = fontCaches[mode]
    if not cache then cache = { text = {} }; fontCaches[mode] = cache end
    return cache
end

-- Keep asset overrides on owned font objects when switching back to native families.
function Theme.ApplyFont(region, size)
    region, size = cleanObject(region), addon.Clean(size, "number")
    if not region or not size or size < 1 or size > 72 then return nil end
    local context, creator = fontContext(), addon.Clean(CreateFont, "function")
    local applied
    if creator then
        local fonts = sourceCache(context, creator).text
        local font = fonts[size]
        if not font then
            fontSerial = fontSerial + 1
            local ok, value = pcall(creator, "DungeonProTextFont" .. fontSerial)
            font = ok and cleanObject(value) or nil
            if font and applyFontSource(font, size, context, true) then
                invoke(font, "SetShadowOffset", 0, 0)
                fonts[size] = font
            else font = nil end
        end
        if font and invoke(region, "SetFontObject", font) then applied = font end
    end
    if not applied then applied = applyFontSource(region, size, context) end
    if applied then
        invoke(region, "SetShadowOffset", 0, 0)
        fontRegions[region] = { size = size, key = context.key, family = context.family, creator = creator }
        return applied
    end
end

local inputFont
function Theme.ApplyInputFont(region)
    region = cleanObject(region)
    local context = fontContext()
    if not region or not context.family then return nil end
    local creator = addon.Clean(CreateFont, "function")
    local cache = sourceCache(context, creator)
    inputFont = cache.input
    if not inputFont then
        inputFont = { family = context.family, creator = creator }
        cache.input = inputFont
        if creator then
            fontSerial = fontSerial + 1
            local ok, value = pcall(creator, "DungeonProInputFont" .. fontSerial)
            local font = ok and cleanObject(value) or nil
            if font and applyFontSource(font, 14, context, true) and invoke(font, "SetTextColor", unpack(palette.text)) then
                invoke(font, "SetShadowOffset", 0, 0)
                inputFont.font = font
            end
        end
    end
    -- EditBox receives an owned font object, never FontString's height setter.
    local font = inputFont.font or context.family
    if invoke(region, "SetFontObject", font) then
        inputRegions[region] = { key = context.key, family = context.family, creator = creator }
        return font
    end
end

function Theme.StyleButtonFonts(button)
    button = cleanObject(button)
    local context, creator = fontContext(), addon.Clean(CreateFont, "function")
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
    controlFonts = cache.controls
    if not controlFonts then
        controlFonts = { family = family, creator = creator, failed = true }
        cache.controls = controlFonts
        for _, role in ipairs(roles) do
            fontSerial = fontSerial + 1
            local ok, value = pcall(creator, "DungeonProControlFont" .. fontSerial)
            local font = ok and cleanObject(value) or nil
            if not font or not applyFontSource(font, 14, context, true) or
                not invoke(font, "SetTextColor", unpack(role[2])) then return false end
            invoke(font, "SetShadowOffset", 0, 0)
            controlFonts[role[1]] = font
        end
        controlFonts.failed = nil
    end
    controlFonts.key = context.key
    if controlFonts.failed then return false end
    if styledButtons[button] == controlFonts then return true end
    for _, role in ipairs(roles) do
        if not invoke(button, "Set" .. role[1] .. "FontObject", controlFonts[role[1]]) then
            for _, restore in ipairs(roles) do invoke(button, "Set" .. restore[1] .. "FontObject", previous[restore[1]]) end
            return false
        end
    end
    styledButtons[button] = controlFonts
    return true
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
        if previous.key ~= context.key or previous.family ~= context.family or previous.creator ~= creator then Theme.ApplyFont(region, previous.size) end
    end
    for region, previous in pairs(inputRegions) do
        if previous.key ~= context.key or previous.family ~= context.family or previous.creator ~= creator then Theme.ApplyInputFont(region) end
    end
    for button, previous in pairs(styledButtons) do
        if previous.key ~= context.key or previous.family ~= context.family or previous.creator ~= creator then Theme.StyleButtonFonts(button) end
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

function Theme.StyleRow(row, options)
    row = cleanObject(row)
    if not row then return false end
    options = addon.Clean(options, "table") or {}
    local kind = addon.Clean(options.kind, "string") or "quest"
    if kind ~= "dungeon" and kind ~= "quest" and kind ~= "section" and kind ~= "control" then return false end
    local selected = addon.Clean(options.selected, "boolean") == true
    local state = surface(row, row.bg)
    if not state then return false end
    color(state.bg, kind == "section" and palette.panel or (selected and palette.selected or palette.row))
    edges(state, selected and (kind == "dungeon" and palette.amber or palette.teal) or palette.faint)
    color(state.accent, kind == "dungeon" and palette.amber or palette.teal)
    invoke(state.accent, selected and "Show" or "Hide")
    textColor(row.title, kind == "section" and palette.heading or palette.text)
    textColor(row.note, palette.muted)
    local highlight = objectResult(row, "GetHighlightTexture")
    if highlight then invoke(highlight, "SetColorTexture", 0.55, 0.72, 0.73, 0.09) end
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
    return true
end

local scrollbars, scrollArrows = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })

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
        state.thumb = thumb and color(thumb, palette.teal) and thumb or nil
    end
    styleScrollArrow(bar.ScrollUpButton, false)
    styleScrollArrow(bar.ScrollDownButton, true)
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
        decoration.header = strip(frame, 1, "TOPLEFT", "TOPRIGHT", -72, palette.amber)
        decoration.footer = strip(frame, 1, "BOTTOMLEFT", "BOTTOMRIGHT", 46, palette.faint)
    end
    if not decoration.panels then
        decoration.panels = {}
        local catalog = cleanObject(ui.catalogScroll) or (cleanObject(ui.catalog) and objectResult(ui.catalog, "GetParent"))
        for key, target in pairs({ catalog = catalog, quests = cleanObject(ui.questScroll), detail = cleanObject(ui.detailScroll) }) do
            decoration.panels[key] = panel(frame, target)
        end
    end
    local catalogScroll = cleanObject(ui.catalogScroll) or (cleanObject(ui.catalog) and objectResult(ui.catalog, "GetParent"))
    for _, scroll in pairs({ catalogScroll, cleanObject(ui.questScroll), cleanObject(ui.detailScroll) }) do Theme.StyleScrollBar(scroll) end
    textColor(ui.title, palette.heading); textColor(ui.subtitle, palette.muted)
    textColor(ui.heading, palette.text); textColor(ui.summary, palette.muted)
    textColor(ui.coverage, palette.quiet); textColor(ui.footer, palette.quiet)
    textColor(ui.capacityStatus, palette.muted); textColor(ui.searchPlaceholder, palette.quiet)
    for _, key in ipairs({ "back", "clearSearch", "rangeButton", "preparationButton", "characterButton", "language", "map", "guide", "source", "giver" }) do
        local button = cleanObject(ui[key])
        if button then Theme.StyleRow(button, { kind = "control" }) end
    end
    return true
end
