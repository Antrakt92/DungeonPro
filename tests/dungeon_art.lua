local addon, total = {}, 0
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
assert(loadfile("Core/Client.lua"))("DungeonPro", addon)
local secret, state = {}, {}
local generic = "Interface\\Icons\\INV_Misc_Map_01"
local function tuple(map, art)
    local values = {}; values[11], values[22] = art, map
    return unpack(values, 1, 22)
end
local function reset()
    state = { list = { -1, 101, 102, 101 }, calls = 0, infoCalls = 0,
        rows = { [101] = { 36, "native/deadmines" }, [102] = { 43, 5678 } } }
    issecretvalue = function(v) return v == secret end
    C_EncounterJournal, EJ_GetInstanceInfo = nil, nil
    GetLFDChoiceOrder = function(...)
        assert(select("#", ...) == 0); state.calls = state.calls + 1; return state.list
    end
    GetLFGDungeonInfo = function(id)
        state.infoCalls = state.infoCalls + 1
        local row = state.rows[id]; if row then return tuple(row[1], row[2]) end
    end
end
local function check(name, fn)
    reset(); local ok, err = pcall(fn)
    if not ok then error(name .. ": " .. tostring(err), 0) end
    total = total + 1; print("PASS " .. name)
end
check("Native enumeration maps gameMapID and background exact tuple positions", function()
    assert(addon.DungeonArt({ instanceID = 36 }) == "native/deadmines")
    assert(addon.DungeonArt({ instanceID = 43 }) == 5678)
    assert(state.calls == 1 and state.infoCalls == 2, "deduplicate and cache once")
end)
check("Encounter Journal remains first and avoids LFG scans", function()
    C_EncounterJournal = { GetInstanceForGameMap = function(id) assert(id == 36); return 99 end }
    EJ_GetInstanceInfo = function(id) assert(id == 99); return nil, nil, nil, nil, 111, 222 end
    assert(addon.DungeonArt({ instanceID = 36 }) == 222 and state.calls == 0)
end)
check("Journal map lookup cannot return artwork after the dungeon identity changes", function()
    local dungeon, infoCalls = {instanceID=36}, 0
    C_EncounterJournal = {GetInstanceForGameMap=function(id)
        assert(id == 36); dungeon.instanceID = 43; return 99
    end}
    EJ_GetInstanceInfo = function() infoCalls = infoCalls + 1; return nil,nil,nil,nil,111,222 end
    assert(addon.DungeonArt(dungeon) == generic)
    assert(infoCalls == 0 and state.calls == 0, "a stale map scope cannot continue native reads")
end)
check("Journal capabilities changed inside a lookup cannot publish old art and recover fresh", function()
    local replacement = {GetInstanceForGameMap=function() return 100 end}
    C_EncounterJournal = {GetInstanceForGameMap=function() C_EncounterJournal = replacement; return 99 end}
    EJ_GetInstanceInfo = function(id) return nil,nil,nil,nil,111,id == 100 and 333 or 222 end
    assert(addon.DungeonArt({instanceID=36}) == generic)
    assert(addon.DungeonArt({instanceID=36}) == 333)
    local fresh = function() return nil,nil,nil,nil,111,444 end
    EJ_GetInstanceInfo = function() EJ_GetInstanceInfo = fresh; return nil,nil,nil,nil,111,555 end
    assert(addon.DungeonArt({instanceID=36}) == generic)
    assert(addon.DungeonArt({instanceID=36}) == 444)
end)
check("Metadata changed during journal info or finder scans cannot publish an old image", function()
    local dungeon = {instanceID=36}
    C_EncounterJournal = {GetInstanceForGameMap=function() return 99 end}
    EJ_GetInstanceInfo = function()
        dungeon.art = {fileID=777,gameMapID=36}
        return nil,nil,nil,nil,111,222
    end
    assert(addon.DungeonArt(dungeon) == generic)
    assert(addon.DungeonArt(dungeon) == 777)
    C_EncounterJournal, EJ_GetInstanceInfo = nil, nil
    dungeon = {instanceID=36}
    local native = GetLFGDungeonInfo
    GetLFGDungeonInfo = function(id) dungeon.instanceID=43; return native(id) end
    assert(addon.DungeonArt(dungeon) == generic)
    assert(addon.DungeonArt(dungeon) == 5678, "a subsequent fresh map scope may use the completed finder cache")
end)
check("Unknown catalog map IDs never enumerate or guess", function()
    for _, id in ipairs({ false, secret, 0, -1, 1.5, 0/0, math.huge, "36" }) do
        assert(addon.DungeonArt({ instanceID = id }) == generic)
    end
    assert(addon.DungeonArt({}) == generic and state.calls == 0)
end)
check("Missing APIs recover when supplied without rescanning on each refresh", function()
    local enumerate = GetLFDChoiceOrder; GetLFDChoiceOrder = nil
    assert(addon.DungeonArt({ instanceID = 36 }) == generic)
    GetLFDChoiceOrder = enumerate
    assert(addon.DungeonArt({ instanceID = 36 }) == "native/deadmines")
    state.rows[101][2] = 999
    assert(addon.DungeonArt({ instanceID = 36 }) == "native/deadmines" and state.calls == 1)
    local old = GetLFGDungeonInfo; GetLFGDungeonInfo = function(id) return old(id) end
    assert(addon.DungeonArt({ instanceID = 36 }) == 999 and state.calls == 2)
end)
check("Distinct images for the same map are ambiguous while duplicates agree", function()
    state.rows[102] = { 36, "native/deadmines" }
    assert(addon.DungeonArt({ instanceID = 36 }) == "native/deadmines")
    local old = GetLFGDungeonInfo; GetLFGDungeonInfo = function(id) return old(id) end
    state.rows[102][2] = "native/other"
    assert(addon.DungeonArt({ instanceID = 36 }) == generic)
end)
check("Malformed sparse oversized and restricted lists fail closed boundedly", function()
    for _, list in ipairs({ false, secret, { [1] = 101, [3] = 102 }, { ["1"] = 101 },
        { 101, secret }, { 101, "102" }, { 101, 1.5 }, { 101, math.huge } }) do
        state.list = list
        GetLFDChoiceOrder = function() return state.list end
        assert(addon.DungeonArt({ instanceID = 36 }) == generic)
    end
    state.list = {}; for i = 1, 501 do state.list[i] = 101 end
    GetLFDChoiceOrder = function() return state.list end
    assert(addon.DungeonArt({ instanceID = 36 }) == generic and state.infoCalls == 0)
end)
check("Throwing native reads remain bounded unknown for the same API identity", function()
    GetLFGDungeonInfo = function() state.infoCalls = state.infoCalls + 1; error("unavailable") end
    for _ = 1, 5 do assert(addon.DungeonArt({ instanceID = 36 }) == generic) end
    assert(state.calls == 1 and state.infoCalls == 1)
end)
check("Secret malformed maps and art never authorize textures", function()
    for _, row in ipairs({ {secret, 123}, {36, secret}, {36, false}, {36, 0}, {36, -1},
        {36, 1.5}, {36, math.huge}, {36, ""}, {36, string.rep("a", 1025)}, {0, 123}, {36.5, 123} }) do
        state.rows = { [101] = row }; GetLFGDungeonInfo = function(id)
            local r = state.rows[id]; if r then return tuple(r[1], r[2]) end
        end
        assert(addon.DungeonArt({ instanceID = 36 }) == generic)
    end
end)
check("Reentrant native scan does not recurse or expose partially built art", function()
    local old = GetLFGDungeonInfo
    GetLFGDungeonInfo = function(id)
        assert(addon.DungeonArt({ instanceID = 36 }) == generic)
        return old(id)
    end
    assert(addon.DungeonArt({ instanceID = 36 }) == "native/deadmines" and state.calls == 1)
end)
check("Changed API identity during native read cannot publish old mapping", function()
    local old = GetLFGDungeonInfo
    GetLFGDungeonInfo = function(id)
        local row = state.rows[id]
        GetLFGDungeonInfo = function() return tuple(36, 999) end
        return row and tuple(row[1], row[2])
    end
    assert(addon.DungeonArt({ instanceID = 36 }) == generic)
    assert(addon.DungeonArt({ instanceID = 36 }) == 999)
end)
check("No match empty list and unavailable background use generic icon", function()
    assert(addon.DungeonArt({ instanceID = 999 }) == generic)
    GetLFDChoiceOrder = function() return {} end
    assert(addon.DungeonArt({ instanceID = 36 }) == generic)
    GetLFDChoiceOrder = function() return {101} end
    GetLFGDungeonInfo = function() return tuple(36, nil) end
    assert(addon.DungeonArt({ instanceID = 36 }) == generic)
end)
check("The five-hundredth entry is included and headers never reach info", function()
    state.list = {}; for i = 1, 499 do state.list[i] = -i end
    state.list[500] = 101
    assert(addon.DungeonArt({ instanceID = 36 }) == "native/deadmines" and state.infoCalls == 1)
end)
check("Missing info and enumeration failures cannot read other client state", function()
    local original = GetLFGDungeonInfo; GetLFGDungeonInfo = nil
    assert(addon.DungeonArt({ instanceID = 36 }) == generic and state.calls == 0)
    GetLFGDungeonInfo = original
    GetLFDChoiceOrder = function() state.calls = state.calls + 1; error("not available") end
    for _ = 1, 5 do assert(addon.DungeonArt({ instanceID = 36 }) == generic) end
    assert(state.calls == 1 and state.infoCalls == 0)
end)
check("Restricted checker failure never reaches native enumeration", function()
    issecretvalue = function() error("restricted") end
    assert(addon.DungeonArt({ instanceID = 36 }) == generic and state.calls == 0)
end)
check("A later agreeing image cannot resolve an earlier same-map ambiguity", function()
    GetLFDChoiceOrder = function() return { 101, 102, 103 } end
    GetLFGDungeonInfo = function(id)
        return tuple(36, id == 102 and "native/conflicting" or "native/deadmines")
    end
    assert(addon.DungeonArt({ instanceID = 36 }) == generic)
    assert(addon.DungeonArt({ instanceID = 36 }) == generic, "cached ambiguity must remain unknown")
end)
check("A later native failure discards every partial mapping and stays bounded for the same capabilities", function()
    GetLFDChoiceOrder = function() state.calls = state.calls + 1; return { 101, 102, 103 } end
    GetLFGDungeonInfo = function(id)
        state.infoCalls = state.infoCalls + 1
        if id == 103 then error("later native row unavailable") end
        return tuple(id == 101 and 36 or 43, id == 101 and "native/deadmines" or "native/caverns")
    end
    for _ = 1, 5 do
        assert(addon.DungeonArt({ instanceID = 36 }) == generic)
        assert(addon.DungeonArt({ instanceID = 43 }) == generic)
    end
    assert(state.calls == 1 and state.infoCalls == 3, "failed scan must neither expose partial maps nor retry per card")
end)
check("Replacing the enumerator during its read prevents old publication and recovers on the new identity", function()
    local replacement = function() state.calls = state.calls + 1; return { 102 } end
    GetLFDChoiceOrder = function()
        state.calls = state.calls + 1
        GetLFDChoiceOrder = replacement
        return { 101 }
    end
    GetLFGDungeonInfo = function(id) return tuple(36, id == 101 and "native/old" or "native/new") end
    assert(addon.DungeonArt({ instanceID = 36 }) == generic, "detached old enumeration must not publish")
    assert(addon.DungeonArt({ instanceID = 36 }) == "native/new" and state.calls == 2)
    assert(addon.DungeonArt({ instanceID = 36 }) == "native/new" and state.calls == 2)
end)
check("Reviewed client artwork works without journal or finder services", function()
    C_EncounterJournal, GetLFDChoiceOrder, GetLFGDungeonInfo = nil, nil, nil
    assert(addon.DungeonArt({ instanceID = 36, art = { fileID = 131833, gameMapID = 36 } }) == 131833)
    assert(addon.DungeonArt({ art = { fileID = 7963781, gameMapID = 3065 } }) == 7963781)
    assert(addon.DungeonArt({ instanceID = 43, art = { fileID = 131833, gameMapID = 36 } }) == generic)
    for _, value in ipairs({ secret, false, 0, -1, 1.5, math.huge, "131833" }) do
        assert(addon.DungeonArt({ art = { fileID = value, gameMapID = 36 } }) == generic)
    end
end)
local function canvas()
    return { calls = {}, SetTexture = function(self, value)
        self.calls[#self.calls + 1] = value or false
        self.texture = value; return true
    end, SetTexCoord = function(self, ...) self.coords = { ... } end,
    Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end }
end
check("Reviewed wide preview artwork preserves its ratio within the existing content crop", function()
    local icon = canvas()
    icon.GetWidth,icon.GetHeight = function() return 44 end,function() return 44 end
    local dungeon = {instanceID=3065,art={fileID=7963781,gameMapID=3065,previewWidth=2992,previewHeight=1684}}
    assert(addon.PaintDungeonArt(icon,dungeon))
    local xspan,yspan=icon.coords[2]-icon.coords[1],icon.coords[4]-icon.coords[3]
    assert(math.abs(xspan-.64/(2992/1684))<1e-12 and math.abs(yspan-.64)<1e-12)
    assert(math.abs(icon.coords[1]+icon.coords[2]-1)<1e-12 and icon.shown)
end)
check("Preview crops adapt to portrait and landscape targets and preserve the content inset", function()
    local function spans(sw,sh,tw,th)
        local icon=canvas(); icon.GetWidth=function() return tw end; icon.GetHeight=function() return th end
        assert(addon.PaintDungeonArt(icon,{art={fileID=7963781,gameMapID=3065,previewWidth=sw,previewHeight=sh}}))
        return icon.coords[2]-icon.coords[1],icon.coords[4]-icon.coords[3]
    end
    local x,y=spans(2992,1684,148,148)
    assert(math.abs(x-.64/(2992/1684))<1e-12 and math.abs(y-.64)<1e-12)
    x,y=spans(2992,1684,300,150)
    assert(math.abs(x-.64)<1e-12 and math.abs(y-.64*(2992/1684)/2)<1e-12)
    x,y=spans(500,1000,44,44)
    assert(math.abs(x-.64)<1e-12 and math.abs(y-.32)<1e-12)
    x,y=spans(2048,2048,44,44)
    assert(math.abs(x-.64)<1e-12 and math.abs(y-.64)<1e-12)
end)
check("Incomplete malformed restricted preview dimensions and target geometry retain the old crop", function()
    local function unchanged(width,height,targetWidth,targetHeight)
        local icon=canvas()
        icon.GetWidth=function() return targetWidth end; icon.GetHeight=function() return targetHeight end
        assert(addon.PaintDungeonArt(icon,{art={fileID=7963781,gameMapID=3065,previewWidth=width,previewHeight=height}}))
        assert(icon.coords[1]==.18 and icon.coords[2]==1-.18 and icon.coords[3]==.18 and icon.coords[4]==1-.18)
    end
    for _,bad in ipairs({secret,false,0,-1,1.5,16385,"2992",0/0,math.huge}) do
        unchanged(bad,1684,44,44); unchanged(2992,bad,44,44)
    end
    unchanged(nil,1684,44,44); unchanged(2992,nil,44,44)
    for _,bad in ipairs({secret,false,0,-1,"44",0/0,math.huge}) do
        unchanged(2992,1684,bad,44); unchanged(2992,1684,44,bad)
    end
    unchanged(2992,1684,nil,44); unchanged(2992,1684,44,nil)
    unchanged(2992,1684,1e-300,1e300); unchanged(2992,1684,1e300,1e-300)
    local icon=canvas(); icon.GetWidth=function() error("unavailable") end; icon.GetHeight=function() return 44 end
    assert(addon.PaintDungeonArt(icon,{art={fileID=7963781,gameMapID=3065,previewWidth=2992,previewHeight=1684}}))
    assert(icon.coords[1]==.18 and icon.coords[3]==.18)
end)
check("Preview dimensions never apply to another file or a mismatched map or generic fallback", function()
    local icon=canvas(); icon.GetWidth=function() error("must not inspect unrelated geometry") end
    icon.GetHeight=icon.GetWidth
    C_EncounterJournal={GetInstanceForGameMap=function() return 99 end}
    EJ_GetInstanceInfo=function() return nil,nil,nil,nil,111,333 end
    local dungeon={instanceID=36,art={fileID=7963781,gameMapID=43,previewWidth=2992,previewHeight=1684}}
    assert(addon.PaintDungeonArt(icon,dungeon) and icon.texture==333 and icon.coords[1]==.18)
    EJ_GetInstanceInfo=function() return nil,nil,nil,nil,111,7963781 end
    assert(addon.PaintDungeonArt(icon,dungeon) and icon.texture==7963781 and icon.coords[1]==.18)
    local native=icon.SetTexture
    icon.SetTexture=function(self,value) if value==7963781 then return false end; return native(self,value) end
    dungeon.instanceID=43
    assert(addon.PaintDungeonArt(icon,dungeon) and icon.texture==generic and icon.coords[1]==0 and icon.coords[2]==1)
end)
check("Geometry getter reentry cannot overwrite or hide a newer paint", function()
    for _,hook in ipairs({"GetWidth","GetHeight"}) do
        local icon=canvas(); local entered=false
        icon.GetWidth=function() return 44 end; icon.GetHeight=function() return 44 end
        icon[hook]=function(self)
            if not entered then entered=true; assert(addon.PaintDungeonArt(self,{})) end
            return 44
        end
        assert(not addon.PaintDungeonArt(icon,{art={fileID=7963781,gameMapID=3065,previewWidth=2992,previewHeight=1684}}))
        assert(entered and icon.texture==generic and icon.shown and icon.coords[1]==0 and icon.coords[2]==1)
    end
end)
check("Metadata or getter identity drift during geometry reads abandons only the owned image", function()
    for _,hook in ipairs({"GetWidth","GetHeight"}) do
        local icon=canvas(); local dungeon={art={fileID=7963781,gameMapID=3065,previewWidth=2992,previewHeight=1684}}
        icon.GetWidth=function() return 44 end; icon.GetHeight=function() return 44 end
        icon[hook]=function() dungeon.art.previewWidth=1000; return 44 end
        assert(not addon.PaintDungeonArt(icon,dungeon))
        assert(icon.texture==nil and not icon.shown and not icon.coords)
    end
    local icon=canvas(); local heightCalls=0
    icon.GetHeight=function() heightCalls=heightCalls+1; return 44 end
    icon.GetWidth=function(self) self.GetHeight=function() heightCalls=heightCalls+1; return 148 end; return 44 end
    assert(not addon.PaintDungeonArt(icon,{art={fileID=7963781,gameMapID=3065,previewWidth=2992,previewHeight=1684}}))
    assert(heightCalls==0 and icon.texture==nil and not icon.shown)
end)
check("Art painting crops loading artwork and resets coordinates on recycled fallback", function()
    local icon = canvas()
    assert(addon.PaintDungeonArt(icon, { art = { fileID = 131833, gameMapID = 36 } }))
    assert(icon.texture == 131833 and icon.shown and icon.coords[1] == 0.18)
    GetLFDChoiceOrder = nil
    assert(addon.PaintDungeonArt(icon, {}))
    assert(icon.texture == generic and icon.coords[1] == 0 and icon.coords[2] == 1)
end)
check("Rejected or throwing textures fall back without retaining old dungeon art", function()
    for _, result in ipairs({ false, secret, "true", "throw" }) do
        local icon = canvas()
        local native = icon.SetTexture
        icon.SetTexture = function(self, value)
            if value == 131833 then
                if result == "throw" then error("file unavailable") end
                return result
            end
            return native(self, value)
        end
        assert(addon.PaintDungeonArt(icon, { art = { fileID = 131833, gameMapID = 36 } }))
        assert(icon.texture == generic and icon.shown)
    end
    local icon = canvas(); icon.texture = "old/dungeon"
    icon.SetTexture = function(self, value) self.texture = value; return false end
    assert(not addon.PaintDungeonArt(icon, {}))
    assert(icon.texture == nil and not icon.shown)
end)
check("A reentrant newer paint retains ownership over the reused icon", function()
    local icon = canvas(); local native = icon.SetTexture
    icon.SetTexture = function(self, value)
        native(self, value)
        if value == 131833 then
            assert(addon.PaintDungeonArt(self, { art = { fileID = 7963781, gameMapID = 3065 } }))
        end
        return true
    end
    assert(not addon.PaintDungeonArt(icon, { art = { fileID = 131833, gameMapID = 36 } }))
    assert(icon.texture == 7963781 and icon.shown and icon.coords[1] == 0.18)
end)
check("A newer paint during coordinate cropping keeps its fallback coordinates and visibility", function()
    local icon = canvas(); local native = icon.SetTexCoord
    local shows, entered = 0, false
    icon.Show = function(self) shows = shows + 1; self.shown = true end
    icon.SetTexCoord = function(self, ...)
        native(self, ...)
        if not entered then
            entered = true
            assert(addon.PaintDungeonArt(self, {}))
        end
    end
    assert(not addon.PaintDungeonArt(icon, {art={fileID=131833,gameMapID=36}}))
    assert(icon.texture == generic and icon.coords[1] == 0 and icon.coords[2] == 1)
    assert(icon.shown and shows == 1, "superseded outer paint must not show again")
end)
check("Rejected unknown and restricted results from both art and fallback clear stale pixels", function()
    for _, mode in ipairs({"false", "nil", "secret", "string", "throw"}) do
        local icon = canvas(); icon.texture, icon.shown = "old/dungeon", true
        local attempts, shows = {}, 0
        icon.Show = function() shows = shows + 1 end
        icon.SetTexture = function(self, value)
            attempts[#attempts+1] = value or false
            self.texture = value
            if mode == "false" then return false end
            if mode == "secret" then return secret end
            if mode == "string" then return "true" end
            if mode == "throw" then error("unavailable") end
            return nil
        end
        assert(not addon.PaintDungeonArt(icon, {art={fileID=131833,gameMapID=36}}))
        assert(attempts[1] == 131833 and attempts[2] == generic and attempts[3] == false and #attempts == 3)
        assert(icon.texture == nil and not icon.shown and shows == 0)
    end
end)
check("A newer paint during failed-art clearing cannot be hidden by the abandoned paint", function()
    local icon = canvas(); local entered, hides = false, 0
    icon.Hide = function(self) hides = hides + 1; self.shown = false end
    icon.SetTexture = function(self, value)
        self.texture = value
        if value == nil and not entered then
            entered = true
            assert(addon.PaintDungeonArt(self, {art={fileID=7963781,gameMapID=3065}}))
        end
        return value == 7963781
    end
    assert(not addon.PaintDungeonArt(icon, {art={fileID=131833,gameMapID=36}}))
    assert(icon.texture == 7963781 and icon.coords[1] == .18 and icon.shown and hides == 0)
end)
check("Every reviewed catalogue image matches its sourced game-map identity", function()
    assert(loadfile("Database/Catalog.lua"))("DungeonPro", addon)
    GetLFDChoiceOrder, GetLFGDungeonInfo, C_EncounterJournal = nil, nil, nil
    local count, seen, maps, previews = 0, {}, {}, {}
    for _, dungeon in ipairs(addon.dungeons) do
        if dungeon.art then
            count = count + 1
            assert(dungeon.art.fileID == addon.DungeonArt(dungeon))
            assert(not dungeon.instanceID or dungeon.art.gameMapID == dungeon.instanceID)
            seen[dungeon.key] = dungeon.art.fileID
            maps[dungeon.art.gameMapID] = true
            if dungeon.art.previewWidth then
                local icon = canvas()
                icon.GetWidth, icon.GetHeight = function() return 44 end, function() return 44 end
                assert(addon.PaintDungeonArt(icon, dungeon))
                local ratio = dungeon.art.previewWidth / dungeon.art.previewHeight
                assert(math.abs((icon.coords[2] - icon.coords[1]) * ratio - (icon.coords[4] - icon.coords[3])) < 1e-10)
                previews[dungeon.key] = true
            end
        else assert(addon.DungeonArt(dungeon) == generic) end
    end
    local mapCount = 0; for _ in pairs(maps) do mapCount = mapCount + 1 end
    assert(count == 24 and mapCount == 23)
    assert(seen.dm == 131833 and seen.thanes == 7963781 and seen.lordaeron == 7963782)
    assert(seen.lbrs == seen.ubrs and not seen.drowned and not seen.kroldok)
    local previewCount = 0; for _ in pairs(previews) do previewCount = previewCount + 1 end
    assert(previewCount == 4 and previews.thanes and previews.lordaeron and previews.excavation and previews.dalaran)
end)
check("Paint kind identifies accepted generic and artwork paths including actual rejected-art fallback",function()
    local icon=canvas();local success,kind=addon.PaintDungeonArt(icon,{})
    assert(success==true and kind=="generic"and icon.texture==generic)
    icon=canvas();success,kind=addon.PaintDungeonArt(icon,{art={fileID=131833,gameMapID=36}})
    assert(success==true and kind=="art"and icon.texture==131833)
    icon=canvas();success,kind=addon.PaintDungeonArt(icon,{instanceID=36})
    assert(success==true and kind=="art"and icon.texture=="native/deadmines")
    for _,result in ipairs({false,secret,"true","throw"})do
        icon=canvas();local original=icon.SetTexture
        icon.SetTexture=function(self,value)
            if value==131833 then if result=="throw"then error("unavailable")end;return result end
            return original(self,value)
        end
        success,kind=addon.PaintDungeonArt(icon,{art={fileID=131833,gameMapID=36}})
        assert(success==true and kind=="generic"and icon.texture==generic)
    end
end)
check("Failed or superseded paints never report a positive kind",function()
    local icon=canvas();icon.SetTexture=function()return false end
    local success,kind=addon.PaintDungeonArt(icon,{})
    assert(success==false and kind==nil)
    icon=canvas();local original=icon.SetTexture;local armed=true
    icon.SetTexture=function(self,value)
        original(self,value)
        if armed then
            armed=false;local newer,newerKind=addon.PaintDungeonArt(self,{})
            assert(newer==true and newerKind=="generic")
        end
        return true
    end
    success,kind=addon.PaintDungeonArt(icon,{art={fileID=131833,gameMapID=36}})
    assert(success==false and kind==nil and icon.texture==generic)
    local dungeon={art={fileID=131833,gameMapID=36}}
    icon=canvas();icon.Show=function(self)self.shown=true;dungeon.art.fileID=7963781 end
    success,kind=addon.PaintDungeonArt(icon,dungeon)
    assert(success==false and kind==nil)
end)

check("Explicit overview paints the complete reviewed texture without changing square thumbnails",function()
    local dungeon={instanceID=3065,art={fileID=7963781,gameMapID=3065,previewWidth=2992,previewHeight=1684}}
    local icon=canvas();icon.GetWidth=function()return 44 end;icon.GetHeight=function()return 44 end
    assert(addon.PaintDungeonArt(icon,dungeon))
    assert(icon.coords[1]>.18 and icon.coords[3]==.18)
    icon.GetWidth=function()error("full overview must not inspect target geometry")end;icon.GetHeight=icon.GetWidth
    local ok,kind,aspect=addon.PaintDungeonArt(icon,dungeon,"overview")
    assert(ok==true and kind=="art"and aspect==2992/1684)
    assert(icon.coords[1]==0 and icon.coords[2]==1 and icon.coords[3]==0 and icon.coords[4]==1)
end)
check("Overview aspect is optional and belongs only to its accepted matching reviewed image",function()
    for _,mode in ipairs({"legacy","generic","rejected","mismatch","invalid","restricted"})do
        local dungeon={instanceID=3065,art={fileID=7963781,gameMapID=3065,previewWidth=2992,previewHeight=1684}}
        if mode=="legacy"then dungeon.art.previewWidth=nil;dungeon.art.previewHeight=nil
        elseif mode=="generic"then dungeon={}
        elseif mode=="mismatch"then dungeon.instanceID=36
        elseif mode=="invalid"then dungeon.art.previewHeight=0
        elseif mode=="restricted"then dungeon.art.previewWidth=secret end
        local icon=canvas()
        if mode=="rejected"then icon.SetTexture=function(self,value)self.texture=value;return type(value)=="string"end end
        local ok,kind,aspect=addon.PaintDungeonArt(icon,dungeon,"overview")
        assert(ok==true and aspect==nil,mode)
        assert(icon.coords[1]==0 and icon.coords[2]==1 and icon.coords[3]==0 and icon.coords[4]==1,mode)
        if mode=="generic"or mode=="rejected"then assert(kind=="generic")end
    end
end)
check("Failed and superseded overview paints never publish a positive kind or aspect",function()
    local dungeon={art={fileID=7963781,gameMapID=3065,previewWidth=2992,previewHeight=1684}}
    local icon=canvas();icon.SetTexture=function()return false end
    local ok,kind,aspect=addon.PaintDungeonArt(icon,dungeon,"overview")
    assert(ok==false and kind==nil and aspect==nil)
    icon=canvas();local set=icon.SetTexture;local armed=true
    icon.SetTexture=function(self,value)
        if armed then armed=false;assert(addon.PaintDungeonArt(self,{},"overview"))end
        return set(self,value)
    end
    ok,kind,aspect=addon.PaintDungeonArt(icon,dungeon,"overview")
    assert(ok==false and kind==nil and aspect==nil)
end)

print("Dungeon art checks passed: " .. total)
