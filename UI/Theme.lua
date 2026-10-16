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
