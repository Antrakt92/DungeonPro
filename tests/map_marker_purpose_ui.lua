-- Quest purpose glyphs stay owned: typed starts keep the quest scroll,
-- turn-ins keep the bang, everything else stays a neutral waypoint pin.
local total = 0
local function client()
    local frames, methods, addon = {}, {}, {}
    local function create(kind, _, parent)
        local frame = setmetatable({ kind = kind, parent = parent, scripts = {}, shown = true }, { __index = methods })
        frames[#frames + 1] = frame
        return frame
    end
    function methods:SetScript(event, callback) self.scripts[event] = callback end
    function methods:Show() if self.beforeShow then self.beforeShow() end; self.shown = true end
    function methods:Hide() if self.beforeHide then self.beforeHide() end; self.shown = false end
    function methods:IsShown() return self.shown end
    function methods:SetParent(parent) self.parent = parent end
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:SetScale(scale) self.scale = scale end
    function methods:GetWidth() if self.beforeWidth then self.beforeWidth() end; return self.width or 1000 end
    function methods:GetHeight() return self.height or 500 end
    function methods:ClearAllPoints() self.point = nil end
    function methods:SetPoint(...) if self.beforePoint then self.beforePoint() end; self.point = { ... } end
    function methods:EnableMouse(value) self.mouse = value end
    function methods:CreateTexture() return create("Texture", nil, self) end
    function methods:SetAllPoints(parent) self.anchor = parent end
    function methods:SetTexture(path) self.texture = path end
    function methods:SetAtlas(atlas) self.atlas = atlas end
    function methods:GetAtlas() return self.atlas end
    function methods:CreateFontString() return create("FontString", nil, self) end
    function methods:GetStringHeight() return 18 end
    for _, name in ipairs({ "SetClampedToScreen", "SetMovable", "RegisterForDrag", "SetWidth", "SetText",
        "SetHeight", "SetJustifyH", "SetRotation", "StartMoving", "StopMovingOrSizing" }) do
        if not methods[name] then methods[name] = function() end end
    end
    CreateFrame = create
    UIParent = create("Frame")
    local canvas, map = create("Frame"), create("Frame")
    map.mapID, map.zoom = 1455, 1
    function map:GetMapID() return self.mapID end
    function map:GetCanvas() return canvas end
    function map:GetCanvasScale() return self.zoom end
    WorldMapFrame = map
    local manual = { uiMapID = 99, position = { x = .2, y = .3 } }
    local nativeWrites = 0
    C_Map = {
        OpenWorldMap = function(mapID) map.mapID = mapID; map:Show() end,
        CanSetUserWaypointOnMap = function() return false end,
        GetUserWaypoint = function() return manual end,
        SetUserWaypoint = function() nativeWrites = nativeWrites + 1 end,
        ClearUserWaypoint = function() nativeWrites = nativeWrites + 1 end,
    }
    issecretvalue = function() return false end
    TomTom = nil
    assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
    assert(loadfile("UI/Navigation.lua"))("DungeonPro", addon)
    addon.L = function(key) return key end
    addon.DungeonName = function() return "Dungeon" end
    addon.QuestName = function() return "Quest" end
    local function marker()
        for _, frame in ipairs(frames) do if frame.icon then return frame end end
    end
    local function tick()
        for _, frame in ipairs(frames) do
            if frame.shown and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, .1) end
        end
    end
    return addon.Navigation, map, canvas, marker, tick, methods, function() return nativeWrites, manual end, addon
end
local function check(name, fn)
    fn(); total = total + 1; print("PASS " .. name)
end

check("typed npc start and finish keep their own glyphs on the same point", function()
    local guide, _, _, findMarker, _, _, native, addon = client()
    local spot = { mapID = 1455, x = 32.8, y = 48.6, npcID = 123 }
    local dungeon = { key = "example" }
    addon.quests = { [1] = { id = 1, start = spot, finish = spot } }
    assert(guide.Map(spot, "quest-start", 1))
    local marker = assert(findMarker())
    assert(marker.icon.atlas == "QuestNormal", "typed start keeps the quest scroll")
    assert(guide.Map(spot, "quest-turnin", 1))
    assert(marker.icon.atlas == "UI-QuestPoi-QuestBangTurnIn", "same point finish keeps the bang")
    assert(guide.StartEntrance(dungeon, spot))
    assert(marker.icon.atlas == "Dungeon", "entrance still wins after quest glyphs")
    assert(guide.Map(spot))
    assert(marker.icon.atlas == "Waypoint-MapPin-Untracked", "plain request on the same point returns to neutral")
    assert(guide.Start({ id = 1, kind = "visit", place = spot }, "quest-start"))
    assert(marker.icon.atlas == "QuestNormal", "guide with an explicit purpose keeps the scroll")
    assert(guide.Start({ id = 1, kind = "visit", place = spot }))
    assert(marker.icon.atlas == "Waypoint-MapPin-Untracked", "generic visit stays neutral")
    assert(native() == 0 and marker.width == 30, "manual pin and geometry preserved")
end)

check("only the exact typed source authorizes a purpose glyph", function()
    local guide, _, _, findMarker, _, _, native, addon = client()
    local spot = { mapID = 1455, x = 32.8, y = 48.6, npcID = 123 }
    addon.quests = { [1] = { id = 1, start = spot, finish = spot } }
    assert(guide.Map(spot, "quest-start", 1))
    local marker = assert(findMarker())
    assert(marker.icon.atlas == "QuestNormal", "exact typed start authorizes the scroll")
    local stranger = { npcID = 456, mapID = 1455, x = 32.8, y = 48.6 }
    assert(guide.Map(stranger, "quest-start", 1))
    assert(marker.icon.atlas == "Waypoint-MapPin-Untracked", "same coordinates without identity stay neutral")
    spot.itemID = 44
    assert(guide.Map(spot, "quest-start", 1))
    assert(marker.icon.atlas == "Waypoint-MapPin-Untracked", "mixed item source stays neutral")
    spot.itemID = nil
    spot.dropNPCID = 123
    assert(guide.Map(spot, "quest-start", 1))
    assert(marker.icon.atlas == "Waypoint-MapPin-Untracked", "drop source stays neutral")
    spot.dropNPCID = nil
    spot.npcID = nil
    spot.objectID = 777
    assert(guide.Map(spot, "quest-start", 1))
    assert(marker.icon.atlas == "QuestNormal", "typed object start authorizes the scroll")
    assert(native() == 0, "manual pin untouched")
end)

check("retired owners and mutated sources cannot keep a purpose glyph", function()
    local guide, _, _, findMarker, tick, methods, native, addon = client()
    local spot = { mapID = 1455, x = 32.8, y = 48.6, npcID = 123, objectID = nil }
    spot.objectID = nil
    addon.quests = { [1] = { id = 1, start = spot, finish = spot } }
    -- Object-typed tail used below; start from the npc identity first.
    assert(guide.Map(spot, "quest-start", 1))
    local marker = assert(findMarker())
    assert(marker.icon.atlas == "QuestNormal", "typed start visible before retirement")
    local base = addon.Clean
    local live, entered = true, false
    addon.Clean = function(value, kind)
        if value == "quest-start" and not entered then entered = true; live = false end
        return base(value, kind)
    end
    local oldWrites = native()
    guide.Map(spot, "quest-start", 1, function() return live end)
    assert(entered and native() == oldWrites, "retired owner cannot touch native pins")
    addon.Clean = base
    live = true
    assert(guide.Map(spot, "quest-start", 1))
    spot.objectID = 778
    tick()
    assert(not marker.shown, "typed source mutation retires the marker")
    spot.objectID = nil
    spot.npcID = 123
    local atlas = methods.SetAtlas
    methods.SetAtlas = function() return false end
    assert(guide.Map(spot, "quest-start", 1))
    assert(marker.icon.texture == "Interface\\GossipFrame\\AvailableQuestIcon", "start keeps its texture fallback")
    assert(guide.Map(spot, "quest-turnin", 1))
    assert(marker.icon.texture == "Interface\\GossipFrame\\ActiveQuestIcon", "turn-in keeps its texture fallback")
    methods.SetAtlas = atlas
    assert(native() == 0 and marker.width == 30, "manual pin and geometry preserved")
end)

check("row and detail producers tag only genuinely typed quest sources", function()
    local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
    local addon, ui = fixture.addon, fixture.addon.UI
    fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
    ui:Toggle()
    ui.includeUnavailable = true
    local active, ready
    local context = { level = 20, faction = "Alliance", class = "MAGE",
        completed = function() return false end,
        active = function(id) return id == active end,
        ready = function(id) return id == ready end }
    addon.Context = function() return context end
    local ids = { 992201, 992202, 992203, 992204 }
    for _, id in ipairs(ids) do addon.quests[id] = { id = id, name = "Purpose " .. id, minLevel = 1, requirementsKnown = true } end
    local first = addon.quests[ids[1]]
    first.minLevel = 80
    first.start = { npcID = 1, name = "Giver", mapID = 1453, x = 10, y = 20 }
    first.finish = { objectID = 9, name = "Finisher", mapID = 1453, x = 50, y = 60 }
    addon.quests[ids[2]].start = { objectID = 2, name = "Quest object", mapID = 1455 }
    addon.quests[ids[3]].start = { itemID = 3, name = "Item only", mapID = 1453, x = 30, y = 40 }
    addon.quests[ids[4]].start = { npcID = 4, dropNPCID = 4, name = "Drop", mapID = 1453, x = 30, y = 40 }
    local dungeon = { key = "purpose", name = "Purpose", minLevel = 1, maxLevel = 80, quests = ids }
    addon.dungeons = { dungeon }
    local calls = {}
    addon.Navigation = {
        Start = function(action, purpose, owner) calls[#calls + 1] = { action = action, purpose = purpose, owner = owner }; return true end,
        Map = function(point, purpose, id, owner) calls[#calls + 1] = { point = point, purpose = purpose, id = id, owner = owner }; return true end,
    }
    local function draw(id) ui.dungeon = dungeon; ui.quest = id; ui.questTreeRoot = nil; ui.questTreeDungeon = nil; ui:Refresh() end
    local function row(id)
        for _, control in ipairs(ui.rows) do if control:IsShown() and control.questID == id then return control end end
        error("row")
    end
    draw(ids[1])
    row(ids[1]).navigationControl.scripts.OnClick()
    assert(calls[#calls].purpose == "quest-start" and type(calls[#calls].owner) == "function", "level-gated browse keeps its start purpose")
    row(ids[2]).navigationControl.scripts.OnClick()
    assert(calls[#calls].purpose == "quest-start" and calls[#calls].id == ids[2], "object map-only keeps its purpose")
    ui.giver.scripts.OnClick()
    assert(calls[#calls].purpose == "quest-start", "main typed giver keeps its purpose")
    draw(ids[3])
    ui.giver.scripts.OnClick()
    assert(calls[#calls].purpose == nil, "item-only main source stays neutral")
    draw(ids[4])
    ui.giver.scripts.OnClick()
    assert(calls[#calls].purpose == nil, "drop main source stays neutral")
    active, ready = ids[1], ids[1]
    draw(ids[1])
    assert(ui.turnin:IsShown() and ui.turnin.enabled)
    ui.turnin.scripts.OnClick()
    assert(calls[#calls].purpose == "quest-turnin" and calls[#calls].action.place == first.finish, "ready turn-in keeps its exact finisher")
    local click = ui.turnin.scripts.OnClick
    ready = nil
    draw(ids[1])
    local count = #calls
    click()
    assert(#calls == count, "stale active turn-in cannot dispatch")
    local action = { id = ids[1], kind = "visit", place = first.start }
    ui:DispatchDetail(action, false, false, function() return true end)
    assert(calls[#calls].purpose == nil, "untagged visit remains neutral")
end)

check("sanitizer replacement and appearance reentry keep the newest request", function()
    local function setup()
        local guide, _, _, findMarker, tick, methods, _, addon = client()
        local spot = { npcID = 123, mapID = 1455, x = 32.8, y = 48.6 }
        addon.quests = { [1] = { id = 1, start = spot, finish = spot } }
        return guide, findMarker, methods, addon, spot, tick
    end
    for _, oldKind in ipairs({ "Map", "Start" }) do
        for _, newKind in ipairs({ "Map", "Start" }) do
            local guide, findMarker, _, addon, spot = setup()
            local base = addon.Clean
            local entered = false
            local replacement = { mapID = 1455, x = 77, y = 61 }
            addon.Clean = function(value, kind)
                if value == "quest-start" and not entered then
                    entered = true
                    if newKind == "Map" then assert(guide.Map(replacement))
                    else assert(guide.Start({ id = 2, kind = "visit", place = replacement })) end
                end
                return base(value, kind)
            end
            local ok
            if oldKind == "Map" then ok = guide.Map(spot, "quest-start", 1)
            else ok = guide.Start({ id = 1, kind = "visit", place = spot }, "quest-start") end
            local marker = assert(findMarker())
            assert(entered and ok == false and marker.shown and marker.point[4] == 770 and marker.point[5] == -305,
                "newer request survives purpose sanitizer " .. oldKind .. newKind)
            addon.Clean = base
        end
    end
    for _, setter in ipairs({ "SetAtlas", "SetTexture", "GetAtlas" }) do
        local guide, findMarker, methods, addon, spot = setup()
        assert(guide.Map(spot))
        local marker = findMarker()
        local old = methods[setter]
        local entered = false
        methods[setter] = function(self, ...)
            if self == marker.icon and not entered then
                entered = true
                assert(guide.Map({ mapID = 1455, x = 77, y = 61 }))
            end
            return old(self, ...)
        end
        assert(guide.Map(spot, "quest-start", 1))
        assert(entered and marker.shown and marker.point[4] == 770
            and marker.icon.atlas == "Waypoint-MapPin-Untracked", "newer neutral survives " .. setter)
        methods[setter] = old
    end
    for _, mode in ipairs({ "missing", "throws", "false", "mismatch" }) do
        local guide, findMarker, methods, addon, spot = setup()
        if mode == "missing" then methods.SetAtlas = nil
        elseif mode == "throws" then methods.SetAtlas = function() error("atlas") end
        elseif mode == "false" then methods.SetAtlas = function() return false end
        else methods.SetAtlas = function(self) self.atlas = "other" end end
        assert(guide.Map(spot, "quest-start", 1))
        assert(findMarker().icon.texture == "Interface\\GossipFrame\\AvailableQuestIcon", "start fallback " .. mode)
        assert(guide.Map(spot, "quest-turnin", 1))
        assert(findMarker().icon.texture == "Interface\\GossipFrame\\ActiveQuestIcon", "turn-in fallback " .. mode)
    end
    local guide, findMarker, _, addon, spot, tick = setup()
    local restricted = {}
    local rawEqual = rawequal
    local attempted = false
    issecretvalue = function(value) return rawEqual(value, restricted) end
    rawequal = function(x, y)
        if rawEqual(x, restricted) or rawEqual(y, restricted) then attempted = true; error("secret comparison") end
        return rawEqual(x, y)
    end
    assert(guide.Map(spot, restricted, 1))
    assert(findMarker().icon.atlas == "Waypoint-MapPin-Untracked" and not attempted, "restricted role stays neutral")
    assert(guide.Map(spot, "quest-start", restricted))
    assert(findMarker().icon.atlas == "Waypoint-MapPin-Untracked" and not attempted, "restricted quest id stays neutral")
    assert(guide.Map(spot, "quest-start", 1))
    spot.npcID = restricted
    tick()
    assert(not findMarker().shown and not attempted, "restricted source retires without comparison")
    rawequal = rawEqual
end)

check("substituted owner helpers and swapped sources never authorize a glyph", function()
    local function setup()
        local guide, _, _, findMarker, tick, methods, _, addon = client()
        local spot = { npcID = 123, mapID = 1455, x = 32.8, y = 48.6 }
        addon.quests = { [1] = { id = 1, start = spot, finish = spot } }
        return guide, findMarker, methods, addon, spot, tick
    end
    for _, method in ipairs({ "Map", "Start" }) do
        local guide, _, _, addon, spot = setup()
        local changedCalls, replacementInstalled = 0, false
        local owner = function()
            addon.Clean = function() changedCalls = changedCalls + 1; error("substituted clean") end
            replacementInstalled = true
            return true
        end
        local ok, result = pcall(function()
            if method == "Map" then return guide.Map(spot, "quest-start", 1, owner)
            else return guide.Start({ id = 1, kind = "visit", place = spot }, "quest-start", owner) end
        end)
        assert(ok and result == false and changedCalls == 0 and replacementInstalled, "owner cannot authorize substituted helpers " .. method)
    end
    for _, method in ipairs({ "Map", "Start" }) do
        local guide, findMarker, _, addon, spot = setup()
        local old = { npcID = 999, mapID = 1455, x = 10, y = 20 }
        addon.quests[1].start = old
        local base = addon.Clean
        local entered = false
        addon.Clean = function(value, kind)
            if value == 1 and kind == "number" and not entered then
                entered = true
                addon.quests[1] = { id = 1, start = spot, finish = spot }
            end
            return base(value, kind)
        end
        if method == "Map" then guide.Map(spot, "quest-start", 1)
        else guide.Start({ id = 1, kind = "visit", place = spot }, "quest-start") end
        addon.Clean = base
        assert(entered and findMarker() and findMarker().icon.atlas == "Waypoint-MapPin-Untracked",
            "initial relation substitution never authorizes " .. method)
    end
end)

check("retained helper swaps and late endpoint edits retire the glyph", function()
    local function setup()
        local guide, _, _, findMarker, tick, methods, _, addon = client()
        local spot = { npcID = 123, mapID = 1455, x = 32.8, y = 48.6 }
        addon.quests = { [1] = { id = 1, start = spot, finish = spot } }
        return guide, findMarker, methods, addon, spot, tick
    end
    local guide, findMarker, _, addon, spot, tick = setup()
    local changed, armed = 0, false
    issecretvalue = function(value)
        if armed then
            armed = false
            addon.Clean = function() changed = changed + 1; error("retained changed Clean invoked") end
        end
        return false
    end
    assert(guide.Map(spot, "quest-start", 1))
    armed = true
    local ok = pcall(tick)
    assert(ok and changed == 0 and not findMarker().shown, "retained helper swap stays inert and hides the glyph")
    guide, findMarker, _, addon, spot, tick = setup()
    local swaps, lateArmed = 0, false
    local other = { npcID = 124, mapID = 1455, x = 77, y = 61 }
    issecretvalue = function(value)
        if lateArmed then
            if rawequal(value, addon.quests) then addon.quests[1].start = spot end
            if rawequal(value, 123) then addon.quests[1].start = other; swaps = swaps + 1 end
        end
        return false
    end
    assert(guide.Map(spot, "quest-start", 1))
    lateArmed = true
    assert(pcall(tick) and swaps > 0 and addon.quests[1].start == other and not findMarker().shown,
        "late endpoint mutation retires the glyph")
    guide, findMarker, _, addon, spot, tick = setup()
    assert(guide.Map(spot, "quest-start", 1))
    changed = 0
    addon.Clean = function() changed = changed + 1; error("external changed Clean invoked") end
    assert(pcall(tick) and changed == 0 and not findMarker().shown, "between-tick helper swap retires before use")
end)

print("Quest purpose marker checks passed: " .. total .. " (native acceptance pending)")
