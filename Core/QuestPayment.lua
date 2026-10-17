local _, addon = ...
local function payment(id, ownerCurrent)
    local checker = issecretvalue
    local rawNamespace = C_CurrencyInfo
    local function clean(value, kind)
        if type(checker) == "function" then
            local ok, secret = pcall(checker, value)
            if not ok or secret ~= false then return nil end
        end
        if type(value) == kind then return value end
    end
    local function positive(value)
        value = clean(value, "number")
        if value and value > 0 and value <= 9007199254740991 and value % 1 == 0 then return value end
    end
    local function field(object, key)
        local ok, value = pcall(function() return object and object[key] end)
        if ok then return value end
    end
    id = positive(id)
    local catalog = clean(addon.quests, "table")
    local definition = id and catalog and clean(field(catalog, id), "table")
    local sourceID = definition and positive(field(definition, "id"))
    local amount = definition and positive(field(definition, "requiredMoney"))
    local scope = clean(ownerCurrent, "function")
    if not id or sourceID ~= id or not amount or (type(ownerCurrent) ~= "nil" and not scope) then return nil end
    local namespace = clean(rawNamespace, "table")
    local rawGetter = namespace and rawget(namespace, "GetCoinTextureString")
    local getter = clean(rawGetter, "function")
    local function current()
        local freshCatalog = clean(addon.quests, "table")
        local freshDefinition = freshCatalog and clean(field(freshCatalog, id), "table")
        local freshID = freshDefinition and positive(field(freshDefinition, "id"))
        local freshAmount = freshDefinition and positive(field(freshDefinition, "requiredMoney"))
        local ns = clean(C_CurrencyInfo, "table")
        local formatter = clean(field(ns, "GetCoinTextureString"), "function")
        if freshCatalog ~= catalog or freshDefinition ~= definition or freshID ~= id or freshAmount ~= amount or
            ns ~= namespace or formatter ~= getter or issecretvalue ~= checker then return false end
        if scope then
            local ok, answer = pcall(scope)
            answer = ok and clean(answer, "boolean")
            if answer ~= true then return false end
        end
        -- Re-prove identities after callback-capable validation and the caller
        -- scope. A missing formatter only affects formatting, never known cost.
        local ok, same = pcall(function()
            if rawget(addon, "QuestPayment") ~= payment or rawget(addon, "quests") ~= catalog or rawget(catalog, id) ~= definition or
                rawget(definition, "id") ~= id or rawget(definition, "requiredMoney") ~= amount or issecretvalue ~= checker then return false end
            if C_CurrencyInfo ~= rawNamespace then return false end
            if namespace and rawget(namespace, "GetCoinTextureString") ~= rawGetter then return false end
            return true
        end)
        return ok and same == true
    end
    if not current() then return nil end
    local formatted
    if getter then
        local ok, value = pcall(getter, amount, 14)
        if not current() then return nil end
        formatted = ok and clean(value, "string") or nil
        if formatted and (#formatted > 4096 or not formatted:find("%S")) then formatted = nil end
        if not current() then return nil end
    end
    if not current() then return nil end
    return { amount = amount, formatted = formatted }
end
addon.QuestPayment = payment
