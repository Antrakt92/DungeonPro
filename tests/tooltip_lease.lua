local addon = {}
assert(loadfile("UI/TooltipLease.lua"))("DungeonPro", addon)
local leases = addon.TooltipLease
local function count(table)
    local result = 0; for _ in pairs(table) do result = result + 1 end; return result
end
local function collect()
    collectgarbage("collect"); collectgarbage("collect")
end
local watched = setmetatable({}, { __mode = "k" })
do
    local tooltip = {}; local lease = { tip = tooltip }; watched[tooltip] = true
    leases.Retain(tooltip, lease, function() return tooltip end)
end
collect(); assert(count(watched) == 0, "the registry must not root an unreachable tooltip through its lease")
do
    local tooltip, lease, restores = {}, {}, 0
    watched[tooltip] = true
    leases.Retain(tooltip, lease, function() restores = restores + 1 end)
    collect(); leases.Restore(tooltip, {})
    assert(restores == 1, "a live producer lease must retain its completed entry across collection")
    local replacement = {}
    leases.Retain(tooltip, replacement, function() restores = restores + 10 end)
    leases.Retire(tooltip, lease); leases.Restore(tooltip, lease)
    assert(restores == 11 and lease.sharedTooltipEntry == nil, "old retirement preserves only the replacement entry")
    leases.Retire(tooltip, replacement); leases.Restore(tooltip, lease)
    assert(restores == 11 and replacement.sharedTooltipEntry == nil)
end
collect(); assert(count(watched) == 0, "retired entries must not retain native tooltip identities")
do
    local tooltip, lease, restores = {}, {}, 0
    leases.Retain(tooltip, lease, function()
        restores = restores + 1; leases.Restore(tooltip, {})
    end)
    leases.Restore(tooltip, {}); assert(restores == 1, "restoration recursion must remain bounded")
    leases.Retain(tooltip, lease, function() error("unavailable tooltip") end)
    leases.Restore(tooltip, {})
    leases.Retain(tooltip, lease, function() restores = restores + 1 end)
    leases.Restore(tooltip, {}); assert(restores == 2, "a failed restore cannot poison the next repair")
end
print("Tooltip lease checks passed: orphan collection, live ownership, retirement and bounded restoration")
