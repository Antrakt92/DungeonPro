local addon, total, secret = {}, 0, {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
issecretvalue = function(value) return value == secret end
local methods = {}
local function region()
    return setmetatable({ textures = {}, text = "kept", width = 200, height = 40, scripts = {} }, { __index = methods })
end
function methods:CreateTexture(_, layer, _, sublevel)
    if self.failTexture then error("unavailable") end
    local result = region()
    result.layer, result.sublevel = layer, sublevel
    self.textures[#self.textures + 1] = result
    return result
end
function methods:SetColorTexture(...) self.color = {...} end
function methods:SetTextColor(...) self.textColor = {...} end
function methods:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = {...} end
function methods:SetAllPoints(value) self.allPoints = value end
function methods:SetWidth(value) self.width = value end
function methods:SetHeight(value) self.height = value end
function methods:SetAlpha(value) self.alpha = value end
function methods:SetBackdrop(value) self.backdrop = value; self.backdropCleared = value == nil end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:GetHighlightTexture() return self.highlight end
function methods:GetNormalTexture() return self.normal end
function methods:GetPushedTexture() return self.pushed end
function methods:GetDisabledTexture() return self.disabled end
function methods:GetFontString() return self.font end
local function row()
    local result = region()
    result.bg, result.title, result.note, result.art = region(), region(), region(), region()
    result.highlight = region()
    return result
end
local function reset()
    assert(loadfile("UI/Theme.lua"))("DungeonPro", addon)
end
local function test(name, fn)
    reset(); fn(); total = total + 1; print("ok - " .. name)
end
test("window hierarchy preserves content geometry and handlers", function()
    local ui = { frame = region(), title = region(), subtitle = region(), coverage = region() }
    local click = function() end
    ui.frame.scripts.OnClick = click
    assert(addon.Theme.Apply(ui))
    assert(ui.frame.backdropCleared and ui.frame.width == 200 and ui.frame.height == 40)
    assert(ui.frame.scripts.OnClick == click and not ui.frame.points)
    assert(ui.title.text == "kept" and ui.title.textColor[1] > ui.subtitle.textColor[1])
    assert(ui.subtitle.textColor[1] > ui.coverage.textColor[1])
    assert(ui.frame.textures[1].color[1] < .05)
end)
test("repeated application uses bounded decoration", function()
    local ui = { frame = region(), back = region() }
    assert(addon.Theme.Apply(ui)); local count = #ui.frame.textures
    local controls = #ui.back.textures
    for _ = 1, 100 do assert(addon.Theme.Apply(ui)) end
    assert(#ui.frame.textures == count and #ui.back.textures == controls)
    assert(count == 8 and controls == 6)
end)
test("recycled selected dungeon clears accent and restores border", function()
    local r = row()
    assert(addon.Theme.StyleRow(r, {kind="dungeon",selected=true}))
    local edge, accent = r.textures[1], r.textures[5]
    assert(accent.shown and edge.color[1] > edge.color[2])
    local selected = r.bg.color[1]
    assert(addon.Theme.StyleRow(r, {kind="dungeon",selected=false}))
    assert(not accent.shown and r.bg.color[1] < selected and edge.color[1] < .2)
    assert(#r.textures == 5)
end)
test("quest and section styles retain text art layout and actions", function()
    local r = row(); r.art.texture = "native-art"; r.enabled = false
    local click = function() end; r.scripts.OnClick = click
    assert(addon.Theme.StyleRow(r, {kind="quest",selected=true}))
    assert(r.textures[1].color[2] > r.textures[1].color[1])
    assert(addon.Theme.StyleRow(r, {kind="section"}))
    assert(r.title.textColor[1] > r.note.textColor[1])
    assert(r.title.text == "kept" and r.art.texture == "native-art" and #r.art.textures == 0)
    assert(r.width == 200 and r.height == 40 and not r.points and r.enabled == false and r.scripts.OnClick == click)
end)
test("modern control preserves click and disabled state", function()
    local r = row(); r.normal,r.pushed,r.disabled,r.font = region(),region(),region(),region()
    local click = function() end; r.scripts.OnClick = click; r.enabled = false
    assert(addon.Theme.StyleRow(r, {kind="control",selected=true}))
    assert(r.normal.alpha == 0 and r.pushed.alpha == 0 and r.disabled.alpha == 0)
    assert(not r.font.textColor and r.highlight.color[4] < .1)
    assert(r.enabled == false and r.scripts.OnClick == click)
end)
test("composite template textures stay quiet while native font states survive", function()
    local r = row(); r.Left,r.Middle,r.Right,r.font = region(),region(),region(),region()
    r.font.textColor = { .5,.5,.5,1 }; local disabledColor = r.font.textColor
    assert(addon.Theme.StyleRow(r, {kind="control",selected=true}))
    assert(r.Left.alpha == 0 and r.Middle.alpha == 0 and r.Right.alpha == 0)
    assert(r.font.textColor == disabledColor and r.highlight.allPoints == r)
    r.Left.texture = "native-pushed"
    assert(r.Left.alpha == 0)
end)
test("viewport depth follows existing geometry without click frames or polling", function()
    local ui = {frame=region(),catalogScroll=region(),questScroll=region(),detailScroll=region()}
    assert(addon.Theme.Apply(ui))
    assert(#ui.frame.textures == 17)
    local count = #ui.frame.textures
    for _=1,100 do assert(addon.Theme.Apply(ui)) end
    assert(#ui.frame.textures == count)
    for _, target in ipairs({ui.catalogScroll,ui.questScroll,ui.detailScroll}) do
        assert(not target.points and #target.textures == 0 and not next(target.scripts))
    end
    local surfaces = 0
    for _, part in ipairs(ui.frame.textures) do
        if part.points and part.points[1][2] ~= ui.frame then
            surfaces = surfaces + 1
            assert(part.points[1][2] == ui.catalogScroll or part.points[1][2] == ui.questScroll or part.points[1][2] == ui.detailScroll)
        end
    end
    assert(surfaces == 9)
end)
test("invalid and restricted values do not create surfaces", function()
    assert(not addon.Theme.Apply(nil) and not addon.Theme.Apply({frame=secret}))
    assert(not addon.Theme.StyleRow(secret, {kind="quest"}))
    local r = row()
    assert(not addon.Theme.StyleRow(r, {kind="unsupported"}) and #r.textures == 0)
    assert(addon.Theme.StyleRow(r, {kind="quest",selected=secret}))
    assert(not r.textures[5].shown)
end)
test("failed optional native texture capability stays bounded", function()
    local r = row(); r.failTexture = true
    for _ = 1, 100 do assert(not addon.Theme.StyleRow(r, {kind="quest"})) end
    assert(#r.textures == 0 and r.title.text == "kept")
    assert(not addon.Theme.StyleRow({}, {kind="quest"}))
end)
print("theme: " .. total .. " scenarios passed")
