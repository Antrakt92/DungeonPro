local _, addon = ...
local paints = setmetatable({}, { __mode = "k" })
local sequence = 0
local atlases = { ACTIVE = "Quest-In-Progress-Icon-yellow", READY = "UI-QuestIcon-TurnIn-Normal" }

function addon.PaintQuestStatus(texture, status, ownerCurrent, compact, reason)
    -- Validation can call a restriction checker that starts a newer paint.
    sequence = sequence + 1
    local token = { sequence = sequence }
    local checker = issecretvalue
    local function clean(value, kind)
        if type(checker) == "function" then
            local ok, secret = pcall(checker, value)
            if not ok or secret ~= false then return nil end
        end
        if type(value) == kind then return value end
    end
    local target = clean(texture, "table") or clean(texture, "userdata")
    if issecretvalue ~= checker or not target then return false end
    local newer = paints[target]
    if newer and newer.sequence > token.sequence then return false end
    paints[target] = token
    local function owned() return paints[target] == token end
    local function method(name)
        local ok, value = pcall(function() return target[name] end)
        return ok and clean(value, "function") or nil
    end
    local hide, show, reset, set = method("Hide"), method("Show"), method("SetTexture"), method("SetAtlas")
    local scope = clean(ownerCurrent, "function")
    local validScope = type(ownerCurrent) == "nil" or scope ~= nil
    local namespace = clean(C_Texture, "table")
    local ok, rawGetter = pcall(function() return namespace and namespace.GetAtlasInfo end)
    local getter = ok and clean(rawGetter, "function") or nil
    status = clean(status, "string")
    compact = clean(compact, "boolean") == true
    reason = clean(reason, "string")
    if not owned() then return false end
    local atlas = status and atlases[status]
    local asset, color
    if compact then
        color = { 1, 1, 1 }
        if status == "COMPLETED" then asset = "Interface\\RaidFrame\\ReadyCheck-Ready"
        elseif status == "AVAILABLE" then asset, color = "Interface\\GossipFrame\\AvailableQuestIcon", { 1, 1, 0 }
        elseif status == "LOCKED" or status == "UNKNOWN" or status == "UNAVAILABLE" then
            asset = "Interface\\GossipFrame\\AvailableQuestIcon"
            color = status == "LOCKED" and reason == "level" and { 1, .2, .2 } or { .55, .55, .55 }
        end
    end
    local vertex = compact and method("SetVertexColor")
    local desaturate = compact and method("SetDesaturated")
    local gray = compact and (status == "UNKNOWN" or status == "UNAVAILABLE" or (status == "LOCKED" and reason ~= "level"))
    local function scopeCurrent()
        if not validScope then return false end
        if not scope then return true end
        local success, result = pcall(scope)
        local answer = success and clean(result, "boolean")
        return owned() and answer == true
    end
    local function methodsCurrent()
        if not owned() or issecretvalue ~= checker then return false end
        local same = method("Hide") == hide and method("Show") == show and
            method("SetTexture") == reset and method("SetAtlas") == set and (not compact or (method("SetVertexColor") == vertex and method("SetDesaturated") == desaturate))
        return owned() and issecretvalue == checker and same
    end
    local function rawCurrent()
        -- No callback-capable sanitizers after this final identity check. Keep
        -- comparisons protected in case a replaced capability is restricted.
        local success, same = pcall(function()
            if not owned() or issecretvalue ~= checker or C_Texture ~= namespace then return false end
            if target.Hide ~= hide or target.Show ~= show or target.SetTexture ~= reset or target.SetAtlas ~= set or (compact and (target.SetVertexColor ~= vertex or target.SetDesaturated ~= desaturate)) then return false end
            if namespace and namespace.GetAtlasInfo ~= getter then return false end
            if not owned() or issecretvalue ~= checker or C_Texture ~= namespace then return false end
            return true
        end)
        return success and same == true
    end
    local function current()
        if not methodsCurrent() then return false end
        local ns = clean(C_Texture, "table")
        local success, value = pcall(function() return ns and ns.GetAtlasInfo end)
        local fresh = success and clean(value, "function") or nil
        if not owned() or issecretvalue ~= checker or ns ~= namespace or fresh ~= getter then return false end
        return scopeCurrent() and rawCurrent()
    end
    local function abandon()
        -- Only this texture's own paint may clear it. A nested paint wins even
        -- when it used the same atlas or deliberately hid the texture.
        local function clear(name, fn, ...)
            if not owned() or not fn then return end
            scopeCurrent()
            local success, same = pcall(function()
                if not owned() or target[name] ~= fn or not owned() then return false end
                return true
            end)
            if success and same == true then pcall(fn, target, ...) end
        end
        clear("Hide", hide)
        clear("SetTexture", reset, nil)
        return false
    end
    if not current() or not hide then return abandon() end
    local hidden = pcall(hide, target)
    if not hidden or not current() then return abandon() end
    if not reset then return abandon() end
    local cleared = pcall(reset, target, nil)
    if not cleared or not current() then return abandon() end
    if not show or (not asset and (not atlas or not getter or not set)) then return false end
    if asset then
        local success, accepted = pcall(reset, target, asset)
        local acceptedBoolean = clean(accepted, "boolean")
        if not success or acceptedBoolean == false or not current() then return abandon() end
    else
        local success, info = pcall(getter, atlas)
        if not current() then return abandon() end
        info = success and clean(info, "table") or nil
        if not info or not current() then return abandon() end
        -- Native Texture:SetAtlas returns no value; reset coordinates explicitly.
        local painted = pcall(set, target, atlas, false, nil, true)
        if not painted or not current() then return abandon() end
    end
    token.current = current
    token.visuals = { color = vertex and color and { setter = vertex, args = color },
        desaturate = desaturate and { setter = desaturate, args = { gray == true } } }
    for _, key in ipairs({ "desaturate", "color" }) do
        local visual = token.visuals[key]
        if visual then
            local applied = pcall(visual.setter, target, unpack(visual.args))
            if not applied or not current() then
                local latest = paints[target]
                local newer = latest and latest.visuals and latest.visuals[key]
                if latest and latest ~= token and newer and latest.current and not latest.repairing and latest.current() then
                    latest.repairing = true
                    if paints[target] == latest and latest.current() then pcall(newer.setter, target, unpack(newer.args)) end
                    latest.repairing = nil
                end
                return abandon()
            end
        end
    end
    local shown = pcall(show, target)
    if not shown or not current() then return abandon() end
    return true
end

function addon.PaintCompactQuestStatus(texture, status, reason, ownerCurrent)
    local painter = addon.Clean(addon.PaintQuestStatus, "function")
    if not painter then return false end
    return addon.Read(painter, "boolean", texture, status, ownerCurrent, true, reason) == true
end
