local _, addon = ...
local function payment(id, ownerCurrent)
    local checker, rawQuest, rawCurrency, localeGetter = issecretvalue, C_QuestLog, C_CurrencyInfo, GetLocale
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
    local function read(fn, kind, ...)
        if not clean(fn, "function") then return nil end
        local ok, value = pcall(fn, ...)
        if ok then return clean(value, kind) end
    end
    id = positive(id)
    local catalog, character = clean(addon.quests, "table"), clean(addon.char, "table")
    local definition = id and catalog and clean(rawget(catalog, id), "table")
    local quest, currency = clean(rawQuest, "table"), clean(rawCurrency, "table")
    local held = quest and clean(rawget(quest, "IsOnQuest"), "function")
    local indexGetter = quest and clean(rawget(quest, "GetLogIndexForQuestID"), "function")
    local moneyGetter = quest and clean(rawget(quest, "GetRequiredMoney"), "function")
    local rawFormatter = currency and rawget(currency, "GetCoinTextureString")
    local formatter = clean(rawFormatter, "function")
    local scope = clean(ownerCurrent, "function")
    if not id or not catalog or not character or not definition or positive(rawget(definition, "id")) ~= id or
        not quest or not held or not indexGetter or not moneyGetter or not clean(localeGetter, "function") or
        (type(ownerCurrent) ~= "nil" and not scope) then return nil end
    local function identities()
        local ok, same = pcall(function()
            return addon.HeldQuestPayment == payment and addon.quests == catalog and rawget(catalog, id) == definition and
                rawget(definition, "id") == id and addon.char == character and issecretvalue == checker and
                C_QuestLog == rawQuest and rawget(quest, "IsOnQuest") == held and
                rawget(quest, "GetLogIndexForQuestID") == indexGetter and rawget(quest, "GetRequiredMoney") == moneyGetter and
                GetLocale == localeGetter and C_CurrencyInfo == rawCurrency and
                (not currency or rawget(currency, "GetCoinTextureString") == rawFormatter)
        end)
        return ok and same == true
    end
    if not identities() or read(held, "boolean", id) ~= true or not identities() then return nil end
    local index = positive(read(indexGetter, "number", id))
    if not index or not identities() then return nil end
    local locale = read(localeGetter, "string")
    if not locale or #locale > 64 or not locale:find("%S") or not identities() then return nil end
    local function current()
        if not identities() then return false end
        if scope and read(scope, "boolean") ~= true then return false end
        if not identities() then return false end
        local active = read(held, "boolean", id)
        if not identities() or active ~= true then return false end
        local liveIndex = positive(read(indexGetter, "number", id))
        if not identities() or liveIndex ~= index then return false end
        local language = read(localeGetter, "string")
        if not identities() or language ~= locale then return false end
        -- Index/locale readers can reenter and release the quest after the first
        -- held check. Finish with fresh held evidence, then raw identities.
        if read(held, "boolean", id) ~= true then return false end
        -- The native ownership readers can also expire only the caller's view.
        if scope and read(scope, "boolean") ~= true then return false end
        -- Caller checks and sanitizers can replace a formerly absent formatter.
        return identities()
    end
    if not current() then return nil end
    -- The explicit argument is the quest ID; the log index proves ownership only.
    local amount = positive(read(moneyGetter, "number", id))
    if not amount or not current() then return nil end
    local formatted
    if formatter then
        formatted = read(formatter, "string", amount, 14)
        if not current() then return nil end
        if formatted and (#formatted > 4096 or not formatted:find("%S")) then formatted = nil end
    end
    if not current() then return nil end
    return { amount = amount, formatted = formatted }
end
addon.HeldQuestPayment = payment
