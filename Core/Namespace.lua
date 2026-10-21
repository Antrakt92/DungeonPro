local name, addon = ...
addon.name = name
addon.version = "0.3.0"
addon.quests, addon.dungeons = {}, {}
addon.listeners = {}
-- Keep unverified interior-map controls out of the normal planner.
addon.experimentalDungeonMaps = false

-- Unknown and restricted values cannot authorize availability or map decisions.
function addon.Clean(value, expected)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret ~= false then return nil end
    end
    if type(value) ~= expected then return nil end
    if expected == "number" and (value ~= value or value == math.huge or value == -math.huge) then return nil end
    return value
end

function addon.Read(fn, expected, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok then return nil end
    return addon.Clean(value, expected)
end

function addon.Notify(reason)
    -- One throwing listener cannot abort the update for the rest; the first
    -- error still surfaces after every listener ran. Refresh callers keep
    -- their pcall/rethrow handling unchanged.
    -- Snapshot first: a listener that unregisters a later listener leaves a
    -- nil hole that stops ipairs, and an appended listener would otherwise
    -- receive the in-flight reason.
    local failed, first = false, nil
    local snapshot = {}
    for i, callback in ipairs(addon.listeners) do snapshot[i] = callback end
    for _, callback in ipairs(snapshot) do
        local ok, message = pcall(callback, reason)
        if not ok and not failed then failed, first = true, message end
    end
    if failed then error(first) end
end
