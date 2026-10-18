local _, addon = ...
-- The live region anchors its paint; registry values must not retain their weak keys.
local paints = setmetatable({}, { __mode = "kv" })
local repairs = setmetatable({}, { __mode = "k" })
local anchorDepths = setmetatable({}, { __mode = "k" })
local sequence = 0
local atlases = { ACTIVE = "Quest-In-Progress-Icon-yellow", READY = "UI-QuestIcon-TurnIn-Normal" }

local function restoreLatest(target, retired)
    local latest, depth = paints[target], repairs[target] or 0
    if not latest or latest == retired or not latest.restore or depth >= 3 then return end
    repairs[target] = depth + 1
    pcall(latest.restore)
    repairs[target] = depth > 0 and depth or nil
end

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
    local function anchor(value)
        if type(target) == "table" then rawset(target, "_dungeonProQuestStatusPaint", value); return true end
        local depth = anchorDepths[target] or 0
        if depth >= 3 then return false end
        anchorDepths[target] = depth + 1
        local ok, same = pcall(function()
            target._dungeonProQuestStatusPaint = value
            return rawequal(target._dungeonProQuestStatusPaint, value)
        end)
        anchorDepths[target] = depth > 0 and depth or nil
        return ok and same == true
    end
    local anchored = anchor(token)
    if paints[target] ~= token then
        -- Assigning a native field can itself start another paint. Recheck
        -- both the registry owner and readback after each bounded repair.
        for _ = 1, 3 do
            local latest = paints[target]
            if not latest then break end
            local retained = anchor(latest)
            if paints[target] == latest then
                if retained then break end
                -- A failed native assignment cannot be made authoritative.
                break
            end
        end
        return false
    end
    if not anchored then paints[target] = nil; return false end
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
    local function restoreHidden()
        -- Only this texture's own paint may clear it. A nested paint wins even
        -- when it used the same atlas or deliberately hid the texture.
        local function clear(name, fn, ...)
            if not owned() or not fn then return false end
            scopeCurrent()
            local success, same = pcall(function()
                if not owned() or target[name] ~= fn or not owned() then return false end
                return true
            end)
            if success and same == true then
                local applied = pcall(fn, target, ...)
                return applied and owned()
            end
            return false
        end
        local hidden = clear("Hide", hide)
        local cleared = clear("SetTexture", reset, nil)
        if not owned() then restoreLatest(target, token) end
        return hidden and cleared and owned()
    end
    local function abandon()
        if restoreHidden() then token.restore = restoreHidden end
        return false
    end
    if not current() or not hide then return abandon() end
    local hidden = pcall(hide, target)
    if not hidden or not current() then return abandon() end
    if not reset then return abandon() end
    local cleared = pcall(reset, target, nil)
    if not cleared or not current() then return abandon() end
    if not show or (not asset and (not atlas or not getter or not set)) then
        token.restore = restoreHidden
        return false
    end
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
                return abandon()
            end
        end
    end
    local shown = pcall(show, target)
    if not shown or not current() then return abandon() end
    -- Restore the complete latest visual after an older native setter resumes.
    -- Reusing its token preserves scope/method checks and avoids a new paint request.
    token.restore = function()
        local function apply(fn, ...)
            if not current() then return false end
            local ok, result = pcall(fn, target, ...)
            local accepted = fn ~= reset or clean(result, "boolean") ~= false
            return ok and accepted and current()
        end
        if not apply(hide) or not apply(reset, nil) then return abandon() end
        if asset then
            if not apply(reset, asset) then return abandon() end
        elseif not apply(set, atlas, false, nil, true) then return abandon() end
        for _, key in ipairs({ "desaturate", "color" }) do
            local visual = token.visuals[key]
            if visual and not apply(visual.setter, unpack(visual.args)) then return abandon() end
        end
        if not apply(show) then return abandon() end
        return true
    end
    return true
end

function addon.PaintCompactQuestStatus(texture, status, reason, ownerCurrent)
    local painter = addon.Clean(addon.PaintQuestStatus, "function")
    if not painter then return false end
    return addon.Read(painter, "boolean", texture, status, ownerCurrent, true, reason) == true
end
