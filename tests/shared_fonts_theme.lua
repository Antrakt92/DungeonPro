local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
local SHARED = "Interface\\AddOns\\AntraktFonts\\fonts\\Selected.ttf"
local BASELINE = "Interface\\AddOns\\DungeonPro\\Media\\Fonts\\AntraktUISans.ttf"
local function fixture(options)
    options = options or {}
    local state = { made = 0, writes = 0, attempts = 0, holders = {}, warm = false }
    local methods = {}
    local function region(kind)
        return setmetatable({ kind = kind or "text" }, { __index = methods })
    end
    function methods:SetFont(path, size, flags)
        state.writes = state.writes + 1
        if self.kind == "holder" then self.direct = true end
        if path == BASELINE and options.baselineUnavailable then return false end
        if path == SHARED or (path == BASELINE and options.baselineCold) then
            state.attempts = state.attempts + 1
            if (path == SHARED and options.unavailable) or ((options.cold or options.baselineCold) and not state.warm and not self.attached) then return false end
            if self.attached then state.warm = true end
            if options.noop then return true end
        end
        self.path, self.size, self.flags, self.family = path, size, flags, nil
        if path == SHARED and options.falseReturn then return false end
        if self.kind ~= "object" then return true end
    end
    function methods:GetFont()
        if self.family then
            local path, size, flags = self.family:GetFont()
            return path, self.size or size, flags
        end
        if self.path == SHARED and options.readback then
            return options.readback(self.path, self.size, self.flags, self)
        end
        return self.path, self.size, self.flags
    end
    function methods:SetFontObject(font)
        state.writes = state.writes + 1
        self.family, self.path, self.size = font, nil, nil
        if self.kind == "holder" and not self.direct then font.attached = true end
    end
    function methods:GetFontObject() return self.family end
    function methods:SetFontHeight(size) self.size = size end
    function methods:SetShadowOffset() end
    function methods:SetTextColor() end
    function methods:Hide() self.hidden = true end
    CreateFont = function()
        state.made = state.made + 1
        return region("object")
    end
    UIParent = { CreateFontString = function()
        local holder = region("holder")
        state.holders[#state.holders + 1] = holder
        return holder
    end }
    ChatFontNormal = region("object"); ChatFontNormal:SetFont("Fonts\\ARIALN.TTF", 14, "")
    GameFontHighlight = nil
    GetLocale = function() return options.game or "enUS" end
    addon.db = { locale = options.locale or "enUS" }
    addon.Fonts = { Resolve = function() if not options.default then return SHARED end end,
        Choices = function() return { { id = "selected", path = SHARED } } end }
    assert(loadfile("UI/Theme.lua"))("DungeonPro", addon)
    state.text, state.input = region(), region("input")
    state.button = {}
    for _, role in ipairs({ "Normal", "Highlight", "Disabled" }) do
        state.button[role] = region("object")
        state.button["Get" .. role .. "FontObject"] = function(self) return self[role] end
        state.button["Set" .. role .. "FontObject"] = function(self, font) self[role] = font end
    end
    function state:paint()
        assert(addon.Theme.ApplyFont(self.text, 16))
        assert(addon.Theme.ApplyInputFont(self.input))
        assert(addon.Theme.StyleButtonFonts(self.button))
    end
    function state:expect(path)
        assert(self.text:GetFont() == path, "text font")
        assert(self.input:GetFont() == path, "input font")
        for _, role in ipairs({ "Normal", "Highlight", "Disabled" }) do
            assert(self.button[role]:GetFont() == path, role .. " button font")
        end
    end
    return state
end
local function test(name, run)
    run(); total = total + 1; print("ok - " .. name)
end
test("cold selected assets activate through one continuously inherited hidden holder", function()
    local f = fixture({ cold = true }); f:paint(); f:expect(SHARED)
    assert(f.warm and #f.holders == 1 and f.holders[1].hidden and not f.holders[1].direct)
    local count, writes = f.made, f.writes
    for _ = 1, 20 do addon.Theme.RefreshFonts(); f:paint() end
    assert(f.made == count and f.writes == writes, "healthy refresh retains bounded font objects")
end)
test("missing selected asset keeps readable bundled fallback then recovers on refresh", function()
    local options = { unavailable = true }; local f = fixture(options)
    f:paint(); f:expect(BASELINE)
    local count = f.made
    for _ = 1, 50 do f:paint() end
    assert(f.made == count, "ordinary label drawing shares fallback objects")
    options.unavailable = false
    addon.Theme.RefreshFonts(); f:expect(SHARED)
end)
test("selected asset failure retains Chinese script fallback on an English client", function()
    local f = fixture({ unavailable = true, baselineUnavailable = true, locale = "zhCN" })
    f:paint(); f:expect("Fonts\\ARKai_T.ttf")
end)
test("fallback caches retain each output language when a universal selected asset fails", function()
    local f = fixture({ unavailable = true, baselineUnavailable = true })
    f:paint(); f:expect("Fonts\\ARIALN.TTF")
    addon.db.locale = "zhCN"; addon.Theme.RefreshFonts(); f:expect("Fonts\\ARKai_T.ttf")
    addon.db.locale = "koKR"; addon.Theme.RefreshFonts(); f:expect("Fonts\\2002.ttf")
    addon.db.locale = "enUS"; addon.Theme.RefreshFonts(); f:expect("Fonts\\ARIALN.TTF")
end)
test("SetFont success without matching GetFont does not certify selected asset", function()
    local options = { noop = true }; local f = fixture(options)
    f:paint(); f:expect(BASELINE)
    options.noop = false; addon.Theme.RefreshFonts(); f:expect(SHARED)
end)
test("default multilingual baseline activates cold without the optional provider", function()
    local options = { default = true, baselineCold = true }; local f = fixture(options)
    addon.Fonts.Resolve = function() return nil end
    f:paint(); f:expect(BASELINE)
    assert(#f.holders == 1 and f.warm and not f.holders[1].direct)
end)
test("picker samples verify exact compatible catalog paths and leave theme objects unchanged", function()
    local f = fixture({ default = true, cold = true }); f:paint()
    local inherited = f.text:GetFontObject()
    assert(addon.Theme.ApplyFontPreview(f.text, SHARED, 16) == SHARED and f.text:GetFont() == SHARED)
    assert(inherited:GetFont() == BASELINE and f.input:GetFont() == BASELINE)
    addon.Theme.RefreshFonts(); assert(f.text:GetFont() == SHARED, "ordinary refresh preserves open sample")
    assert(not addon.Theme.ApplyFontPreview(f.text, "Interface\\\\AddOns\\\\Other\\\\Bad.ttf", 16))
    addon.Theme.ApplyFont(f.text, 16); assert(f.text:GetFont() == BASELINE)
end)
test("failed and misleading sample setters restore the readable baseline", function()
    for _, mode in ipairs({ "unavailable", "noop", "wrong" }) do
        local options = { default = true }; options[mode] = true
        local f = fixture(options); f:paint()
        if mode == "wrong" then
            local set = f.text.SetFont
            f.text.SetFont = function(self, path, size, flags)
                if path == SHARED then self.path, self.size, self.flags, self.family = "Fonts\\\\Wrong.ttf", size, flags, nil; return true end
                return set(self, path, size, flags)
            end
        end
        assert(not addon.Theme.ApplyFontPreview(f.text, SHARED, 16))
        assert(f.text:GetFont() == BASELINE and f.input:GetFont() == BASELINE)
    end
end)
test("native no-effect flags and tiny height rounding permit availability and selected fonts", function()
    for _, mode in ipairs({ { none = true, delta = .009 }, { flags = "", delta = -.009 },
        { flags = " \t ", delta = .004 } }) do
        local f = fixture({ readback = function(path, size)
            return path, size + mode.delta, mode.none and nil or mode.flags
        end })
        assert(addon.Theme.FontAvailable(SHARED), "native-equivalent readback must keep shared face available")
        f:paint(); f:expect(SHARED)
        local made, writes = f.made, f.writes
        for _ = 1, 5 do addon.Theme.RefreshFonts(); f:paint() end
        assert(f.made == made and f.writes == writes, "accepted rounding must not trigger perpetual font repair")
    end
end)

test("native-equivalent preview readback changes only the sample and restores baseline", function()
    for _, mode in ipairs({ { none = true, delta = -.004 }, { flags = " \t", delta = .009 } }) do
        local f = fixture({ default = true, readback = function(path, size)
            return path, size + mode.delta, mode.none and nil or mode.flags
        end })
        f:paint()
        local inherited = f.text:GetFontObject()
        assert(addon.Theme.ApplyFontPreview(f.text, SHARED, 16) == SHARED,
            "preview must accept nil/whitespace no-effect flags and small native rounding")
        assert(f.text:GetFont() == SHARED and inherited:GetFont() == BASELINE and f.input:GetFont() == BASELINE)
        addon.Theme.ApplyFont(f.text, 16)
        assert(f.text:GetFont() == BASELINE, "preview exit restores its committed font object")
    end
end)

test("availability selected rendering and previews reject incorrect or restricted readback", function()
    local restricted = {}
    local modes = {
        function(path, size) return path, size, "OUTLINE" end,
        function(path, size) return path, size, "UNKNOWN" end,
        function(_, size) return "Interface\\AddOns\\Other\\Wrong.ttf", size, nil end,
        function(path, size) return path, size + .02, nil end,
        function(path, size) return path, size, restricted end,
        function(path) return path, restricted, nil end,
    }
    local savedSecret = issecretvalue
    issecretvalue = function(value) return value == restricted end
    for _, readback in ipairs(modes) do
        local f = fixture({ readback = readback })
        assert(not addon.Theme.FontAvailable(SHARED), "invalid readback cannot certify native availability")
        f:paint(); f:expect(BASELINE)
        assert(not addon.Theme.ApplyFontPreview(f.text, SHARED, 16), "invalid preview cannot be accepted")
        assert(f.text:GetFont() == BASELINE and f.input:GetFont() == BASELINE,
            "invalid native readback leaves readable committed fallback")
    end
    issecretvalue = savedSecret
end)
test("matching native readback wins over a false SetFont pseudo-return", function()
    local f = fixture({ falseReturn = true })
    assert(addon.Theme.FontAvailable(SHARED), "matching readback must certify asset despite false pseudo-return")
    f:paint(); f:expect(SHARED)
    local preview = fixture({ default = true, falseReturn = true })
    preview:paint()
    assert(addon.Theme.ApplyFontPreview(preview.text, SHARED, 16) == SHARED and preview.text:GetFont() == SHARED,
        "matching preview readback must win over false pseudo-return")
    addon.Theme.ApplyFont(preview.text, 16); preview:expect(BASELINE)
    for _, options in ipairs({ { default = true, unavailable = true },
        { default = true, falseReturn = true, readback = function(_, size, flags)
            return "Interface\\AddOns\\Other\\Wrong.ttf", size, flags
        end } }) do
        local invalid = fixture(options); invalid:paint()
        assert(not addon.Theme.FontAvailable(SHARED), "false return with missing or wrong readback cannot certify asset")
        assert(not addon.Theme.ApplyFontPreview(invalid.text, SHARED, 16))
        invalid:expect(BASELINE)
    end
end)
print("Shared font renderer tests passed: " .. total)
