local _, addon = ...
local Leases = {}
addon.TooltipLease = Leases
local completed = setmetatable({}, { __mode = "kv" })
local repairing = setmetatable({}, { __mode = "k" })

-- Producers retain their own source, visibility and native ownership proofs.
-- This registry only connects completed hints sharing one physical tooltip.
function Leases.Retain(tooltip, lease, restore)
    if tooltip == nil or type(lease) ~= "table" then return end
    local entry = { lease = lease, restore = restore }
    -- Lua 5.1 weak keys do not break a value's reference back to its key.
    -- Only the producer's live lease keeps this weak registry entry alive.
    lease.sharedTooltipEntry = entry
    completed[tooltip] = entry
end

function Leases.Retire(tooltip, lease)
    if tooltip == nil or type(lease) ~= "table" then return end
    local entry = completed[tooltip]
    if entry and entry.lease == lease then completed[tooltip] = nil end
    lease.sharedTooltipEntry = nil
end

function Leases.Restore(tooltip, retired)
    if tooltip == nil then return end
    local newest = completed[tooltip]
    if not newest or newest.lease == retired or repairing[tooltip] then return end
    repairing[tooltip] = true
    pcall(newest.restore)
    repairing[tooltip] = nil
end
