local _, addon = ...
local function probeNavigation()
    local clean, read, checker = addon.Clean, addon.Read, issecretvalue
    local navigation = rawget(addon, "Navigation")
    local getter = type(navigation) == "table" and rawget(navigation, "ProbeGeometry")
    local snapshots = {}
    local function current()
        local ok, same = pcall(function()
            if not rawequal(rawget(addon, "Clean"), clean) or not rawequal(rawget(addon, "Read"), read) or
                not rawequal(rawget(_G, "issecretvalue"), checker) or not rawequal(rawget(addon, "Navigation"), navigation) or
                (type(navigation) == "table" and not rawequal(rawget(navigation, "ProbeGeometry"), getter)) then return false end
            for _, snapshot in ipairs(snapshots) do
                for _, key in ipairs(snapshot.keys) do
                    -- A conclusively ordinary NaN contributes only "unknown". Do not
                    -- inspect or compare its possibly restricted replacement in this raw tail.
                    if not snapshot.nan[key] and not rawequal(rawget(snapshot.object, key), snapshot.values[key]) then return false end
                end
            end
            return true
        end)
        return ok and same == true
    end
    local function sanitized(value, kind)
        local result = clean(value, kind)
        if not current() then error("retired diagnostic snapshot") end
        return result
    end
    local function capture(value, keys)
        if not sanitized(value, "table") then return nil end
        local values, nan = {}, {}
        for _, key in ipairs(keys) do values[key] = rawget(value, key) end
        for _, key in ipairs(keys) do
            local field = values[key]
            if type(field) == "number" then
                local ordinary = true
                if type(checker) == "function" then
                    local ok, restricted = pcall(checker, field)
                    ordinary = ok and restricted == false
                end
                if not current() then error("retired diagnostic field") end
                -- Classified NaN stays an individual unknown, rather than invalidating every row.
                if ordinary then nan[key] = field ~= field end
            end
        end
        snapshots[#snapshots + 1] = { object = value, keys = keys, values = values, nan = nan }
        if not current() then error("changed diagnostic fields") end
        return values
    end
    local ok, lines = pcall(function()
        if type(clean) ~= "function" or type(read) ~= "function" or not current() then return nil end
        local source = sanitized(navigation, "table")
        local method = source and sanitized(getter, "function")
        local report = read(method, "table")
        if not current() then return nil end
        local reportFields = capture(report, { "status", "frames" })
        if not reportFields or sanitized(reportFields.status, "string") ~= "known" then return nil end
        local frameFields = capture(reportFields.frames, { "hud", "planner", "worldMap" })
        local strata = { BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true,
            FULLSCREEN = true, FULLSCREEN_DIALOG = true, TOOLTIP = true }
        local output = {}
        for _, key in ipairs({ "hud", "planner", "worldMap" }) do
            local fields = { "status", "shown", "visible", "strata", "level", "scale", "left", "bottom", "width", "height" }
            if key == "worldMap" then fields[#fields + 1] = "displayedMapID" end
            local row = frameFields and capture(frameFields[key], fields)
            local prefix = "Dungeon Pro nav/" .. key .. ": "
            local known = row and sanitized(row.status, "string") == "known"
            if not known then
                output[#output + 1] = prefix .. "unknown"
            else
                local function flag(field)
                    local value = sanitized(row[field], "boolean")
                    if value == nil then return "unknown" end
                    return value and "true" or "false"
                end
                local function number(field, format)
                    local value = sanitized(row[field], "number")
                    if not value or value < -1000000 or value > 1000000 or
                        ((field == "width" or field == "height" or field == "level") and value < 0) or
                        (field == "level" and value % 1 ~= 0) or (field == "scale" and value <= 0) then return "unknown" end
                    return string.format(format, value)
                end
                local layer = sanitized(row.strata, "string")
                layer = layer and strata[layer] and layer or "unknown"
                output[#output + 1] = prefix .. "shown=" .. flag("shown") .. " visible=" .. flag("visible") ..
                    " strata=" .. layer .. " level=" .. number("level", "%.0f") .. " scale=" .. number("scale", "%.3f") ..
                    " uiUnit=(" .. number("left", "%.2f") .. "," .. number("bottom", "%.2f") ..
                    "," .. number("width", "%.2f") .. "," .. number("height", "%.2f") .. ")"
            end
            if key == "worldMap" then
                local mapID = known and sanitized(row.shown, "boolean") == true and sanitized(row.displayedMapID, "number")
                local displayed = "unknown"
                if mapID and mapID > 0 and mapID <= 9007199254740991 and mapID % 1 == 0 then displayed = string.format("%.0f", mapID) end
                output[#output] = output[#output] .. " mapID=" .. displayed
            end
        end
        -- All formatting callbacks precede this final callback-free ownership proof.
        return current() and output or nil
    end)
    if not ok or not lines then print("Dungeon Pro nav: snapshot unknown"); return end
    for _, line in ipairs(lines) do print(line) end
end

local function probeMinimap()
    local ok, lines = pcall(function()
        local function object(value)
            return addon.Clean(value, "table") or addon.Clean(value, "userdata")
        end
        local manager, parent, checker = addon.Clean(addon.Minimap, "table"), object(Minimap), issecretvalue
        local button = manager and object(manager.button)
        local database = addon.Clean(addon.db, "table")
        local config = database and addon.Clean(database.minimap, "table")
        local hidden = config and addon.Clean(config.hide, "boolean")
        local rawButton = manager and rawget(manager, "button")
        local rawConfig = database and rawget(database, "minimap")
        local rawHidden = config and rawget(config, "hide")
        local function flag(value)
            if value == nil then return "unknown" end
            return value and "true" or "false"
        end
        local output = { "Dungeon Pro minimap: created=" .. flag(button ~= nil) .. " hide=" .. flag(hidden) }
        local strata = { BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true,
            FULLSCREEN = true, FULLSCREEN_DIALOG = true, TOOLTIP = true }
        local bindings = {}
        for _, role in ipairs({ { "button", button }, { "parent", parent } }) do
            local owner, getters, slots = role[2], {}, {}
            local function read(key, kind)
                if type(owner) == "table" then slots[key] = {value = rawget(owner, key)} end
                local getter = owner and addon.Read(function() return owner[key] end, "function")
                getters[key] = getter
                return addon.Read(getter, kind, owner)
            end
            local shown, visible = read("IsShown", "boolean"), read("IsVisible", "boolean")
            local layer = read("GetFrameStrata", "string")
            layer = layer and strata[layer] and layer or "unknown"
            local function number(key, minimum, maximum, integral)
                local value = read(key, "number")
                if not value or value < minimum or value > maximum or (integral and value % 1 ~= 0) then return "unknown" end
                return string.format(integral and "%.0f" or "%.2f", value)
            end
            output[#output + 1] = "Dungeon Pro minimap/" .. role[1] .. ": shown=" .. flag(shown) ..
                " visible=" .. flag(visible) .. " strata=" .. layer .. " level=" .. number("GetFrameLevel", 0, 100000, true) ..
                " alpha=" .. number("GetAlpha", 0, 1) .. " uiUnit=(" .. number("GetLeft", -1000000, 1000000) ..
                "," .. number("GetBottom", -1000000, 1000000) .. "," .. number("GetWidth", 0, 1000000) ..
                "," .. number("GetHeight", 0, 1000000) .. ")"
            bindings[#bindings + 1] = { owner = owner, getters = getters, slots = slots }
        end
        for _, binding in ipairs(bindings) do
            for key, getter in pairs(binding.getters) do
                if addon.Read(function() return binding.owner[key] end, "function") ~= getter then return end
            end
        end
        if addon.Minimap ~= manager or object(Minimap) ~= parent or issecretvalue ~= checker or
            (manager and object(manager.button) ~= button) or addon.db ~= database or
            (database and addon.Clean(database.minimap, "table") ~= config) or
            (config and addon.Clean(config.hide, "boolean") ~= hidden) then return end
        -- Final raw checks call no getters or restriction checks that could replace an earlier binding.
        if not rawequal(rawget(addon, "Minimap"), manager) or not rawequal(rawget(_G, "Minimap"), parent) or
            not rawequal(rawget(_G, "issecretvalue"), checker) or not rawequal(rawget(addon, "db"), database) or
            (manager and not rawequal(rawget(manager, "button"), rawButton)) or
            (database and not rawequal(rawget(database, "minimap"), rawConfig)) or
            (config and not rawequal(rawget(config, "hide"), rawHidden)) then return end
        for _, binding in ipairs(bindings) do
            for key, slot in pairs(binding.slots) do
                if not rawequal(rawget(binding.owner, key), slot.value) then return end
            end
        end
        return output
    end)
    if not ok or not lines then print("Dungeon Pro minimap: snapshot unknown"); return end
    for _, line in ipairs(lines) do print(line) end
end

addon.Diagnostics = { Navigation = probeNavigation, Minimap = probeMinimap }
