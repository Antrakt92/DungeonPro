local addon, total = {}, 0
local secret = {}
issecretvalue = function(value) return value == secret end
GetLocale = function() return "enUS" end
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Locales/Strings.lua"))("DungeonPro", addon)
assert(loadfile("Locales/Translations.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local lower = { name = "Lower Blackrock Spire", instanceID = 229, wing = "lower" }
local upper = { name = "Upper Blackrock Spire", instanceID = 229, wing = "upper" }
local ordinary = { name = "Source dungeon", instanceID = 230 }
local function check(label, test)
    addon.db = { locale = "enUS" }
    issecretvalue = function(value) return value == secret end
    GetLocale = function() return "enUS" end
    GetRealZoneText = function(id, ...)
        assert((id == 229 or id == 230) and select("#", ...) == 0)
        return "Client dungeon"
    end
    test()
    total = total + 1; print("PASS " .. label)
end
check("Shared instance retains distinct wing names with the actual client adapter", function()
    assert(addon.DungeonName(lower) == "Client dungeon — Lower wing")
    assert(addon.DungeonName(upper) == "Client dungeon — Upper wing")
    assert(addon.DungeonName(lower) ~= addon.DungeonName(upper))
    assert(lower.name == "Lower Blackrock Spire" and upper.name == "Upper Blackrock Spire")
end)
check("All ten dictionaries format the unchanged native base with distinct localized wings", function()
    local count = 0
    for locale, strings in pairs(addon.locales) do
        addon.db.locale = locale
        GetRealZoneText = function() return "Название клиента" end
        assert(type(strings.DUNGEON_WING_lower) == "string")
        assert(type(strings.DUNGEON_WING_upper) == "string")
        assert(addon.DungeonName(lower) == string.format(strings.DUNGEON_WING_lower, "Название клиента"))
        assert(addon.DungeonName(upper) == string.format(strings.DUNGEON_WING_upper, "Название клиента"))
        assert(addon.DungeonName(lower) ~= addon.DungeonName(upper))
        assert(addon.DungeonName(lower):find("Название клиента", 1, true))
        count = count + 1
    end
    assert(count == 10)
end)
check("Auto locale and unsupported locale fallback keep the native base", function()
    addon.db.locale = "auto"; GetLocale = function() return "ruRU" end
    assert(addon.DungeonName(lower) == "Client dungeon — Нижнее крыло")
    addon.db.locale = "unsupported"
    assert(addon.DungeonName(upper) == "Client dungeon — Upper wing")
    addon.db.locale = "esMX"
    assert(addon.DungeonName(lower) == string.format(addon.locales.esES.DUNGEON_WING_lower, "Client dungeon"))
    addon.db.locale = "enGB"
    assert(addon.DungeonName(upper) == "Client dungeon — Upper wing")
end)
check("Missing empty throwing malformed and restricted native names preserve exact source fallback", function()
    local cases = { function() return "" end, function() error("Unavailable") end,
        function() return 229 end, function() return secret end, function() return nil end }
    for _, fn in ipairs(cases) do
        GetRealZoneText = fn
        assert(addon.DungeonName(lower) == lower.name and addon.DungeonName(upper) == upper.name)
    end
    GetRealZoneText = nil
    assert(addon.DungeonName(lower) == lower.name and addon.DungeonName(upper) == upper.name)
    GetRealZoneText = function() error("No instance must not query") end
    assert(addon.DungeonName({ name = "Exact source — text", wing = "lower" }) == "Exact source — text")
end)
check("Ordinary and unknown wing metadata do not invent a suffix", function()
    assert(addon.DungeonName(ordinary) == "Client dungeon")
    for _, wing in ipairs({ "middle", "LOWER", "", true, 229, {}, secret }) do
        assert(addon.DungeonName({ name = "Source", instanceID = 229, wing = wing }) == "Client dungeon")
    end
    assert(addon.DungeonName({ name = "Source", instanceID = 229 }) == "Client dungeon")
end)
check("Native names cannot escape changed dungeon map source or wing ownership", function()
    for _,field in ipairs({"instanceID","name","wing"}) do
        local dungeon={name="Original source",instanceID=230,wing="lower"}
        GetRealZoneText=function()
            dungeon[field]=field=="instanceID" and 229 or field=="name" and "Current source" or "upper"
            return "Old native name"
        end
        assert(addon.DungeonName(dungeon)==dungeon.name)
    end
end)
check("Replaced native name capability rejects its detached result and recovers on the next read", function()
    local dungeon={name="Source",instanceID=230}
    local fresh=function() return "Fresh native name" end
    GetRealZoneText=function() GetRealZoneText=fresh; return "Detached native name" end
    assert(addon.DungeonName(dungeon)=="Source")
    assert(addon.DungeonName(dungeon)=="Fresh native name")
end)
check("Changed game and interface locales cannot publish a mixed native wing label", function()
    local localize=addon.L
    for _,mode in ipairs({"gameValue","gameGetter","choice","database","localizer"}) do
        local locale="enUS"
        GetLocale=function() return locale end
        addon.db={locale="enUS"}; addon.L=localize
        GetRealZoneText=function()
            if mode=="gameValue" then locale="ruRU"
            elseif mode=="gameGetter" then GetLocale=function() return "enUS" end
            elseif mode=="choice" then addon.db.locale="ruRU"
            elseif mode=="database" then addon.db={locale="enUS"}
            else addon.L=function() return "Changed formatter" end end
            return "Old native base"
        end
        assert(addon.DungeonName(lower)==lower.name,mode)
    end
    addon.L=localize
end)
check("Wing formatting reentry cannot publish an obsolete suffix", function()
    local localize=addon.L
    local dungeon={name="Source",instanceID=230,wing="lower"}
    addon.L=function(key,name) dungeon.wing="upper"; return localize(key,name) end
    assert(addon.DungeonName(dungeon)=="Source")
    addon.L=localize
end)
check("Invalid maps never query native locale or names and current restricted fallback stays private", function()
    GetLocale=function() error("invalid maps must not read native locale") end
    GetRealZoneText=function() error("invalid maps must not read native names") end
    for _,id in ipairs({secret,false,0,-1,1.5,math.huge,0/0,"230",{}}) do
        assert(addon.DungeonName({name="Exact source",instanceID=id})=="Exact source")
    end
    assert(addon.DungeonName(nil)=="" and addon.DungeonName(secret)=="")
    GetLocale=function() return "enUS" end
    local dungeon={name="Old source",instanceID=230}
    GetRealZoneText=function() dungeon.name=secret; return "Old native name" end
    assert(addon.DungeonName(dungeon)=="")
end)
check("Restriction checker drift and unreadable locale never authorize a stale label", function()
    GetRealZoneText=function() issecretvalue=function() error("restricted") end; return "Old native name" end
    assert(addon.DungeonName(ordinary)=="")
    issecretvalue=function(value) return value==secret end
    local calls=0; GetRealZoneText=function() calls=calls+1;return "Native name" end
    GetLocale=function() return secret end
    assert(addon.DungeonName(ordinary)==ordinary.name and calls==0)
    GetLocale=function() return "enUS" end
    for _,name in ipairs({" ",string.rep("x",1025)}) do
        GetRealZoneText=function() return name end
        assert(addon.DungeonName(ordinary)==ordinary.name)
    end
end)
check("Reviewed instance identities and legacy art-only maps supply labels without mutating source facts", function()
    local catalog={}
    assert(loadfile("Database/Catalog.lua"))("DungeonPro",catalog)
    local expected={thanes=3065,lordaeron=2999,excavation=2998,dalaran=2959}
    local count=0
    for _,dungeon in ipairs(catalog.dungeons) do
        if expected[dungeon.key] then
            local source,art=dungeon.name,dungeon.art
            assert(dungeon.instanceID==expected[dungeon.key] and art.gameMapID==expected[dungeon.key])
            GetRealZoneText=function(id,...) assert(id==expected[dungeon.key] and select("#",...)==0);return "Native label "..id end
            assert(addon.DungeonName(dungeon)=="Native label "..expected[dungeon.key])
            assert(dungeon.name==source and dungeon.instanceID==expected[dungeon.key] and dungeon.art==art)
            local legacy={name=source,art=art}
            assert(addon.DungeonName(legacy)=="Native label "..expected[dungeon.key])
            assert(legacy.name==source and legacy.instanceID==nil and legacy.art==art)
            count=count+1
        end
    end
    assert(count==4)
end)
check("Display-only art maps never override explicitly present invalid instance IDs or malformed artwork", function()
    GetLocale = function() error("invalid identity must not query locale") end
    GetRealZoneText = function() error("invalid identity must not query native label") end
    local art = { fileID = 7963781, gameMapID = 3065 }
    for _, value in ipairs({ false, secret, 0, -1, 1.5, math.huge, 0/0, "3065", {} }) do
        assert(addon.DungeonName({ name = "Source", instanceID = value, art = art }) == "Source")
    end
    for _, field in ipairs({ "fileID", "gameMapID" }) do
        for _, value in ipairs({ false, secret, 0, -1, 1.5, math.huge, 0/0, "3065", {} }) do
            local invalid = { fileID = 7963781, gameMapID = 3065 }
            invalid[field] = value
            assert(addon.DungeonName({ name = "Source", art = invalid }) == "Source")
        end
        local incomplete = { fileID = 7963781, gameMapID = 3065 }
        incomplete[field] = nil
        assert(addon.DungeonName({ name = "Source", art = incomplete }) == "Source")
    end
    assert(addon.DungeonName({ name = "No artwork" }) == "No artwork")
end)
check("Art-only names retain native failure fallback and an existing instance keeps priority", function()
    local art = { fileID = 7963781, gameMapID = 3065 }
    local dungeon = { name = "Exact source", art = art }
    GetRealZoneText = nil
    assert(addon.DungeonName(dungeon) == dungeon.name)
    for _, getter in ipairs({ function() return nil end, function() return secret end,
        function() return false end, function() return "" end, function() return " " end,
        function() error("unavailable") end }) do
        GetRealZoneText = getter
        assert(addon.DungeonName(dungeon) == dungeon.name)
    end
    dungeon.instanceID = 230
    GetRealZoneText = function(id) assert(id == 230); return "Native instance label" end
    assert(addon.DungeonName(dungeon) == "Native instance label")
    assert(dungeon.instanceID == 230 and dungeon.art == art and dungeon.name == "Exact source")
end)
check("Art table file map and identity-route drift reject detached names and recover fresh", function()
    for _, mode in ipairs({ "table", "file", "map", "route" }) do
        local dungeon = { name = "Source", art = { fileID = 7963781, gameMapID = 3065 } }
        GetRealZoneText = function()
            if mode == "table" then dungeon.art = { fileID = 7963781, gameMapID = 3065 }
            elseif mode == "file" then dungeon.art.fileID = 7963782
            elseif mode == "map" then dungeon.art.gameMapID = 2999
            else dungeon.instanceID = 3065 end
            return "Detached native label"
        end
        assert(addon.DungeonName(dungeon) == "Source", mode)
        GetRealZoneText = function(id) return "Fresh native label " .. id end
        assert(addon.DungeonName(dungeon) == "Fresh native label " .. (mode == "map" and 2999 or 3065))
    end
end)
print("Dungeon name checks passed: " .. total)
