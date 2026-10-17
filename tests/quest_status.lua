local addon, total = {}, 0
local secret = {}
local baseChecker = function(value) return value == secret end
issecretvalue = baseChecker
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("UI/QuestStatus.lua"))("DungeonPro", addon)
local active, ready = "Quest-In-Progress-Icon-yellow", "UI-QuestIcon-TurnIn-Normal"
local function texture()
    return { shown = true, atlas = "old", clears = 0,
        Hide = function(self) self.shown = false end,
        Show = function(self) self.shown = true end,
        SetTexture = function(self, value) assert(value == nil); self.atlas = nil; self.clears = self.clears + 1 end,
        SetAtlas = function(self, atlas, size, filter, reset)
            assert((atlas == active or atlas == ready) and size == false and filter == nil and reset == true)
            self.atlas = atlas
        end }
end
local function native()
    issecretvalue = baseChecker
    C_Texture = { GetAtlasInfo = function(atlas) assert(atlas == active or atlas == ready); return {} end }
end
local function check(label, fn)
    native()
    local ok, err = pcall(fn)
    assert(ok, label .. ": " .. tostring(err)); total = total + 1; print("PASS " .. label)
end
check("Native void setters paint only the two exact current quest roles", function()
    local t = texture()
    assert(addon.PaintQuestStatus(t, "ACTIVE") == true and t.shown and t.atlas == active)
    assert(addon.PaintQuestStatus(t, "READY") == true and t.shown and t.atlas == ready)
end)
check("Historical unknown blocked and offer states recycle to hidden textual fallback", function()
    local t, reads = texture(), 0
    C_Texture.GetAtlasInfo = function() reads = reads + 1; error("No lookup for unsupported status") end
    for _, status in ipairs({ "UNKNOWN", "COMPLETED", "UNAVAILABLE", "LOCKED", "BLOCKED", "AVAILABLE", "active", "", false, secret }) do
        t.shown, t.atlas = true, "stale"
        assert(addon.PaintQuestStatus(t, status) == false and not t.shown and t.atlas == nil)
    end
    assert(reads == 0)
end)
check("Missing failing or restricted atlas metadata hides the old icon quietly", function()
    for _, value in ipairs({ false, 4, "atlas", secret }) do
        local t = texture(); C_Texture.GetAtlasInfo = function() return value end
        assert(not addon.PaintQuestStatus(t, "ACTIVE") and not t.shown and not t.atlas)
    end
    for _, getter in ipairs({ false, function() end, function() error("Unavailable") end }) do
        C_Texture = { GetAtlasInfo = getter }; local t = texture()
        assert(not addon.PaintQuestStatus(t, "READY") and not t.shown and not t.atlas)
    end
    for _, ns in ipairs({ false, secret }) do
        C_Texture = ns; local t = texture(); assert(not addon.PaintQuestStatus(t, "READY") and not t.shown)
    end
    C_Texture = nil; local t = texture(); assert(not addon.PaintQuestStatus(t, "READY") and not t.shown)
end)
check("Setter errors and partial writes cannot leave an owned icon visible", function()
    local t = texture()
    t.SetAtlas = function(self) self.atlas = "partial"; error("Native failure") end
    assert(not addon.PaintQuestStatus(t, "ACTIVE") and not t.shown and not t.atlas)
    t = texture(); t.Show = function(self) self.shown = true; error("Show failure") end
    assert(not addon.PaintQuestStatus(t, "READY") and not t.shown and not t.atlas)
    t = texture(); t.SetAtlas = nil
    assert(not addon.PaintQuestStatus(t, "READY") and not t.shown)
end)
check("A caller scope must authorize painting and is rechecked after native content reads", function()
    for _, answer in ipairs({ false, secret, "true" }) do
        local t = texture(); assert(not addon.PaintQuestStatus(t, "READY", function() return answer end) and not t.shown)
    end
    local t = texture(); assert(not addon.PaintQuestStatus(t, "ACTIVE", function() error("Closed") end) and not t.shown)
    local live = true; C_Texture.GetAtlasInfo = function() live = false; return {} end
    t = texture(); assert(not addon.PaintQuestStatus(t, "ACTIVE", function() return live end) and not t.shown and not t.atlas)
end)
check("A nested metadata paint owns the texture even with the same atlas", function()
    for _, nextStatus in ipairs({ "READY", "ACTIVE", "UNKNOWN" }) do
        native(); local t, armed = texture(), true
        C_Texture.GetAtlasInfo = function()
            if armed then armed = false; addon.PaintQuestStatus(t, nextStatus) end
            return {}
        end
        assert(not addon.PaintQuestStatus(t, "ACTIVE"))
        assert(t.shown == (nextStatus ~= "UNKNOWN") and t.atlas == (nextStatus == "READY" and ready or nextStatus == "ACTIVE" and active or nil))
    end
end)
check("Nested setters and Show callbacks keep newer visible or deliberately hidden paints", function()
    for _, boundary in ipairs({ "SetAtlas", "Show" }) do
        for _, nextStatus in ipairs({ "ACTIVE", "UNKNOWN" }) do
            native(); local t, armed = texture(), true; local original = t[boundary]
            t[boundary] = function(self, ...)
                original(self, ...)
                if armed then armed = false; addon.PaintQuestStatus(t, nextStatus) end
            end
            assert(not addon.PaintQuestStatus(t, "READY"))
            assert(t.shown == (nextStatus == "ACTIVE") and t.atlas == (nextStatus == "ACTIVE" and active or nil))
        end
    end
end)
check("Cleanup Hide and reset callbacks never clear a newer same-texture paint", function()
    for _, boundary in ipairs({ "Hide", "SetTexture" }) do
        local t, armed = texture(), true; local original = t[boundary]
        t[boundary] = function(self, ...)
            original(self, ...)
            if armed then armed = false; assert(addon.PaintQuestStatus(t, "ACTIVE")) end
        end
        assert(not addon.PaintQuestStatus(t, "UNKNOWN"))
        assert(t.shown and t.atlas == active)
    end
end)
check("Changed namespaces getter methods or restriction checker reject mixed paints", function()
    for _, change in ipairs({ "namespace", "getter", "setter", "checker" }) do
        native(); local t = texture()
        C_Texture.GetAtlasInfo = function()
            if change == "namespace" then C_Texture = {}
            elseif change == "getter" then C_Texture.GetAtlasInfo = function() return {} end
            elseif change == "setter" then t.SetAtlas = function() error("Replacement must not run") end
            else issecretvalue = function() return false end end
            return {}
        end
        assert(not addon.PaintQuestStatus(t, "READY") and not t.shown)
    end
end)
check("Restriction and scope callbacks can supersede entry without stale cleanup", function()
    local t, armed = texture(), true
    issecretvalue = function(value)
        if armed and value == t then armed = false; assert(addon.PaintQuestStatus(t, "READY")) end
        return false
    end
    assert(not addon.PaintQuestStatus(t, "ACTIVE") and t.shown and t.atlas == ready)
    native(); t = texture(); armed = true
    assert(not addon.PaintQuestStatus(t, "ACTIVE", function()
        if armed then armed = false; assert(addon.PaintQuestStatus(t, "READY")) end
        return true
    end))
    assert(t.shown and t.atlas == ready)
end)
check("Invalid textures missing methods and failing reset remain quiet", function()
    assert(not addon.PaintQuestStatus(nil, "READY"))
    for _, t in ipairs({ false, 1, "texture", secret, {} }) do assert(not addon.PaintQuestStatus(t, "ACTIVE")) end
    local t = texture(); t.SetTexture = function() error("Reset failure") end
    assert(not addon.PaintQuestStatus(t, "READY") and not t.shown)
    t = texture(); t.Hide = nil; assert(not addon.PaintQuestStatus(t, "READY"))
end)
check("Different texture ownership stays independent and no gameplay APIs are used", function()
    UnitGUID = function() error("No identity query") end
    C_QuestLog = setmetatable({}, { __index = function() error("No quest API") end })
    addon.Navigation = setmetatable({}, { __index = function() error("No navigation") end })
    local first, second, armed = texture(), texture(), true
    C_Texture.GetAtlasInfo = function()
        if armed then armed = false; assert(addon.PaintQuestStatus(second, "READY")) end
        return {}
    end
    assert(addon.PaintQuestStatus(first, "ACTIVE") and first.atlas == active and second.atlas == ready)
end)
check("Final getter sanitization cannot invoke a Show method replaced by that callback", function()
    local t, armed = texture(), false
    local original, getter = t.SetAtlas, C_Texture.GetAtlasInfo
    t.SetAtlas = function(self, ...) original(self, ...); armed = true end
    issecretvalue = function(value)
        if armed and value == getter then
            armed = false; t.Show = function() error("Replacement must not run") end
        end
        return false
    end
    assert(not addon.PaintQuestStatus(t, "ACTIVE") and not t.shown,
        "Superseded captured Show left a false-result icon visible")
end)
check("An entry checker painting another texture does not cancel this target's hidden fallback", function()
    local t, other = texture(), texture()
    assert(addon.PaintQuestStatus(t, "ACTIVE"))
    local armed = true
    issecretvalue = function(value)
        if armed and value == t then armed = false; assert(addon.PaintQuestStatus(other, "READY")) end
        return false
    end
    assert(not addon.PaintQuestStatus(t, "UNKNOWN") and not t.shown and not t.atlas)
    assert(other.shown and other.atlas == ready)
end)
local function compactTexture()
    local t=texture()
    function t:SetTexture(value) self.texture=value; self.atlas=nil end
    function t:SetVertexColor(r,g,b) self.color={r,g,b} end
    function t:SetDesaturated(value) self.desaturated=value end
    return t
end
check("Compact quest roles distinguish completion level locks availability and unknown",function()
    local t=compactTexture()
    assert(addon.PaintCompactQuestStatus(t,"COMPLETED",nil) and t.shown and t.texture=="Interface\\RaidFrame\\ReadyCheck-Ready")
    assert(addon.PaintCompactQuestStatus(t,"LOCKED","level") and t.shown and t.color[1]>t.color[2])
    assert(addon.PaintCompactQuestStatus(t,"AVAILABLE",nil) and t.shown and t.color[1]>t.color[3])
    assert(addon.PaintCompactQuestStatus(t,"UNKNOWN","requirements") and t.shown and t.color[1]==t.color[2] and t.color[2]==t.color[3] and t.desaturated==true)
    assert(addon.PaintCompactQuestStatus(t,"AVAILABLE",nil) and t.desaturated==false)
    assert(addon.PaintCompactQuestStatus(t,"ACTIVE",nil) and t.atlas==active)
    assert(addon.PaintCompactQuestStatus(t,"READY",nil) and t.atlas==ready)
end)
check("Compact status invalidation and unsupported status clear recycled textures",function()
    local t=compactTexture()
    assert(addon.PaintCompactQuestStatus(t,"COMPLETED",nil))
    assert(not addon.PaintCompactQuestStatus(t,"LOCKED","level",function()return false end) and not t.shown)
    assert(not addon.PaintCompactQuestStatus(t,secret,nil) and not t.shown)
end)
check("A late compact tint setter restores the newer quest role color",function()
    local t=compactTexture();local original=t.SetVertexColor;local armed=true
    function t:SetVertexColor(r,g,b)
        if armed then armed=false;assert(addon.PaintCompactQuestStatus(self,"AVAILABLE",nil))end
        original(self,r,g,b)
    end
    assert(not addon.PaintCompactQuestStatus(t,"LOCKED","level"))
    assert(t.shown and t.color[1]==1 and t.color[2]==1 and t.color[3]==0,"newer available role must retain its yellow tint")
end)
check("A late gray desaturation setter preserves the newer colored quest role",function()
    local t=compactTexture();local original=t.SetDesaturated;local armed=true
    function t:SetDesaturated(value)
        if armed then armed=false;assert(addon.PaintCompactQuestStatus(self,"AVAILABLE",nil))end
        original(self,value)
    end
    assert(not addon.PaintCompactQuestStatus(t,"UNKNOWN","requirements"))
    assert(t.shown and t.desaturated==false,"newer available role must not inherit old gray desaturation")
end)
print("Quest status painter checks passed: " .. total .. " (no native-client validation)")
