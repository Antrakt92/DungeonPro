local _, addon = ...
local Cache = {}
addon.RewardCache = Cache
local owners = setmetatable({}, { __mode = "k" })
local delays = { .2, .6, 1.2 }

local function snapshot()
    local language = addon.Clean(addon.Language, "table")
    local getter = language and addon.Clean(language.GetSelection, "function")
    return { char = addon.char, db = addon.db, quests = addon.quests,
        provider = addon.CachedQuestRewards, checker = issecretvalue, localeGetter = GetLocale,
        locale = addon.Read(GetLocale, "string"), language = language, selectionGetter = getter,
        selection = addon.Read(getter, "string", language),
        committed = addon.Clean(addon.db, "table") and addon.Clean(addon.db.locale, "string") }
end

local function same(a, b)
    for _, key in ipairs({ "char", "db", "quests", "provider", "checker", "localeGetter", "locale",
        "language", "selectionGetter", "selection", "committed" }) do
        if a[key] ~= b[key] then return false end
    end
    return true
end

local function sameBudget(a, b)
    for _, key in ipairs({ "char", "db", "quests", "provider", "checker", "localeGetter", "locale" }) do
        if a[key] ~= b[key] then return false end
    end
    return true
end

local function current(owner, state, binding)
    if owners[owner] ~= state or state.binding ~= binding then return false end
    if addon.Read(binding.current, "boolean") ~= true then return false end
    if owners[owner] ~= state or state.binding ~= binding then return false end
    local frame = owner.frame or owner
    if frame ~= binding.frame then return false end
    local visible = addon.Clean(frame.IsVisible, "function") or addon.Clean(frame.IsShown, "function")
    if visible and addon.Read(visible, "boolean", frame) ~= true then return false end
    local context = snapshot()
    for _, id in ipairs(binding.ids) do
        if not state.entries[id] or context.quests ~= state.context.quests or
            context.quests[id] ~= state.entries[id].quest then return false end
    end
    return owners[owner] == state and state.binding == binding and same(state.context, context)
end

local schedule
schedule = function(owner, state)
    if state.pending or state.scheduling then return end
    local binding = state.binding
    if not current(owner, state, binding) then return end
    local attempt
    for _, id in ipairs(binding.ids) do
        local entry = state.entries[id]
        if not entry.done and entry.attempts < 3 then attempt = math.min(attempt or 3, entry.attempts + 1) end
    end
    if not attempt then return end
    local timer = addon.Clean(C_Timer, "table")
    local after = timer and addon.Clean(timer.After, "function")
    if not after then return end
    local token, armed, immediate = {}, false, false
    state.pending, state.scheduling = token, true
    local ok, result = pcall(after, delays[attempt], function()
        if not armed then immediate = true; return end
        if owners[owner] ~= state or state.pending ~= token then return end
        state.pending = nil
        local latest = state.binding
        if not current(owner, state, latest) then return end
        local changed = false
        for _, id in ipairs(latest.ids) do
            local entry = state.entries[id]
            if not entry.done and entry.attempts < 3 and state.context.quests[id] == entry.quest then
                entry.attempts = entry.attempts + 1
                local value = addon.Read(state.context.provider, "table", id)
                if not current(owner, state, latest) or state.entries[id] ~= entry then
                    schedule(owner, state); return
                end
                if value and addon.Clean(value.source, "string") == "cache" and
                    addon.Clean(value.items, "table") and addon.Clean(value.choices, "table") then
                    entry.done, changed = true, true
                end
            end
        end
        if changed and current(owner, state, latest) then pcall(latest.refresh) end
        if owners[owner] == state then schedule(owner, state) end
    end)
    state.scheduling = nil
    armed = true
    if not ok or addon.Clean(result, "boolean") == false or immediate then
        if state.pending == token then state.pending = nil end
        -- A synchronous or rejected scheduler cannot safely provide deferred work.
        if state.binding == binding then
            for _, id in ipairs(binding.ids) do
                local entry = state.entries[id]
                if entry then entry.attempts = 3 end
            end
        end
    end
end

function Cache.Watch(owner, coldIDs, ownerCurrent, refreshCallback)
    owner = addon.Clean(owner, "table") or addon.Clean(owner, "userdata")
    coldIDs = addon.Clean(coldIDs, "table")
    if not owner or not coldIDs or not addon.Clean(ownerCurrent, "function") or
        not addon.Clean(refreshCallback, "function") then return end
    local context = snapshot()
    if not addon.Clean(context.quests, "table") or not addon.Clean(context.provider, "function") or not context.locale then return end
    local state = owners[owner]
    if not state then
        state = { context = context, entries = {} }; owners[owner] = state
    elseif not same(state.context, context) then
        -- Keep the scheduling slot: its callback reads the newest binding.
        -- UI language previews do not change the native reward cache.
        if not sameBudget(state.context, context) then state.entries = {} end
        state.context = context
    end
    local binding = { ids = {}, current = ownerCurrent, refresh = refreshCallback, frame = owner.frame or owner }
    state.binding = binding
    local seen = {}
    for index = 1, math.min(#coldIDs, 600) do
        local id = addon.Clean(coldIDs[index], "number")
        if id and id > 0 and id % 1 == 0 and not seen[id] and addon.Clean(context.quests[id], "table") then
            seen[id] = true; binding.ids[#binding.ids + 1] = id
            local entry = state.entries[id]
            if not entry or entry.quest ~= context.quests[id] then
                state.entries[id] = { quest = context.quests[id], attempts = 0 }
            end
        end
    end
    schedule(owner, state)
end
