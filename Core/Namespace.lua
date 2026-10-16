local name, addon = ...
addon.name = name
addon.version = "0.1.0"
addon.quests, addon.dungeons = {}, {}
addon.listeners = {}

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

function addon.Notify()
    for _, callback in ipairs(addon.listeners) do callback() end
end
