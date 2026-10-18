local _, addon = ...
local Cache = {}
addon.RewardCache = Cache
local owners = setmetatable({}, { __mode = "k" })
local requests = setmetatable({}, { __mode = "k" })
local delays = { .2, .6, 1.2 }

local function snapshot()
    local language = addon.Clean(addon.Language, "table")
    local getter = language and addon.Clean(language.GetSelection, "function")
    return { char = addon.char, db = addon.db, quests = addon.quests,
        provider = addon.CachedQuestRewards, checker = issecretvalue, localeGetter = GetLocale,
        hydrator = addon.RequestQuestRewardData, rewardLoaded = HaveQuestRewardData,
        itemHydrator = addon.RequestQuestRewardItems,
        task = C_TaskQuest, preload = addon.Clean(C_TaskQuest, "table") and C_TaskQuest.RequestPreloadRewardData,
        locale = addon.Read(GetLocale, "string"), language = language, selectionGetter = getter,
        selection = addon.Read(getter, "string", language),
        committed = addon.Clean(addon.db, "table") and addon.Clean(addon.db.locale, "string") }
end

local function same(a, b)
    for _, key in ipairs({ "char", "db", "quests", "provider", "checker", "localeGetter", "locale",
        "language", "selectionGetter", "selection", "committed", "hydrator", "itemHydrator", "rewardLoaded", "task", "preload" }) do
        if a[key] ~= b[key] then return false end
    end
    return true
end

local function sameBudget(a, b)
    for _, key in ipairs({ "char", "db", "quests", "provider", "checker", "localeGetter", "locale",
        "hydrator", "itemHydrator", "rewardLoaded", "task", "preload" }) do
        if a[key] ~= b[key] then return false end
    end
    return true
end

local function current(owner, state, binding, id, entry)
    if owners[owner] ~= state or state.binding ~= binding then return false end
    if addon.Read(binding.current, "boolean") ~= true then return false end
    if owners[owner] ~= state or state.binding ~= binding then return false end
    local frame = owner.frame or owner
    if frame ~= binding.frame then return false end
    local visible = addon.Clean(frame.IsVisible, "function") or addon.Clean(frame.IsShown, "function")
    if visible and addon.Read(visible, "boolean", frame) ~= true then return false end
    local context = snapshot()
    if id and (state.entries[id] ~= entry or context.quests ~= state.context.quests or
        context.quests[id] ~= entry.quest) then return false end
    return owners[owner] == state and state.binding == binding and same(state.context, context)
end

local function eligible(state, binding, id)
    local entry = state.entries[id]
    return entry and not entry.done and (entry.attempts < 3 or
        (type(state.context.itemHydrator) == "function" and entry.itemEpoch ~= binding.itemEpoch))
end

local schedule
schedule = function(owner, state)
    if state.pending or state.scheduling then return end
    local binding = state.binding
    if not current(owner, state, binding) then return end
    local attempt
    for index = state.cursor or 1, #binding.ids do
        local id = binding.ids[index]
        local entry = state.entries[id]
        if eligible(state, binding, id) then attempt = math.min(attempt or 3, math.min(3, entry.attempts + 1)) end
    end
    if not attempt and (state.cursor or 1) > 1 then state.cursor = 1; return schedule(owner, state) end
    if not attempt then return end
    local timer = addon.Clean(C_Timer, "table")
    local after = timer and addon.Clean(timer.After, "function")
    if not after then return end
    local token, armed, immediate = {}, false, false
    state.pending, state.scheduling = token, true
    local delay = (state.cursor or 1) > 1 and .01 or delays[attempt]
    local ok, result = pcall(after, delay, function()
        if not armed then immediate = true; return end
        if owners[owner] ~= state or state.pending ~= token then return end
        state.pending = nil
        local latest = state.binding
        if not current(owner, state, latest) then return end
        local processed = 0
        for index = state.cursor or 1, #latest.ids do
            local id = latest.ids[index]
            state.cursor = index + 1
            local entry = state.entries[id]
            if eligible(state, latest, id) then
                processed = processed + 1
                local function itemCurrent() return current(owner, state, latest, id, entry) end
                if not itemCurrent() then return end
                local value
                if entry.attempts < 3 then
                    entry.attempts = entry.attempts + 1
                    value = addon.Read(state.context.provider, "table", id)
                end
                if not itemCurrent() then
                    schedule(owner, state); return
                end
                if value and addon.Clean(value.source, "string") == "cache" and
                    addon.Clean(value.items, "table") and addon.Clean(value.choices, "table") then
                    entry.done, state.changed = true, true
                elseif not value and not entry.primed and addon.Clean(state.context.hydrator, "function") then
                    -- Spending the request before dispatch also bounds synchronous reentry and errors.
                    entry.primed = true
                    pcall(state.context.hydrator, id, itemCurrent)
                    if not itemCurrent() then schedule(owner, state); return end
                end
                if not value then
                    entry.itemEpoch = latest.itemEpoch
                    if addon.Clean(state.context.itemHydrator, "function") then
                        pcall(state.context.itemHydrator, id, itemCurrent)
                        if not itemCurrent() then schedule(owner, state); return end
                    end
                end
                if processed >= 2 then break end
            end
        end
        local remaining = false
        for index = state.cursor or 1, #latest.ids do
            if eligible(state, latest, latest.ids[index]) then remaining = true; break end
        end
        if not remaining then
            state.cursor = 1
            local changed = state.changed; state.changed = nil
            if changed and current(owner, state, latest) then pcall(latest.refresh) end
        end
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
                if entry then entry.attempts, entry.itemEpoch = 3, binding.itemEpoch end
            end
        end
    end
end

function Cache.Watch(owner, coldIDs, ownerCurrent, refreshCallback)
    owner = addon.Clean(owner, "table") or addon.Clean(owner, "userdata")
    if not owner then return end
    local request = {}; requests[owner] = request
    coldIDs = addon.Clean(coldIDs, "table")
    if not owner or not coldIDs or not addon.Clean(ownerCurrent, "function") or
        not addon.Clean(refreshCallback, "function") then return end
    local context = snapshot()
    if requests[owner] ~= request then return end
    if not addon.Clean(context.quests, "table") or not addon.Clean(context.provider, "function") or not context.locale then return end
    if requests[owner] ~= request then return end
    local state = owners[owner]
    local previous, cursor = state and state.binding, state and state.cursor
    local sameWork = state and sameBudget(state.context, context)
    if not state then
        state = { context = context, entries = {}, cursor = 1 }; owners[owner] = state
    elseif not same(state.context, context) then
        -- Keep the scheduling slot: its callback reads the newest binding.
        -- UI language previews do not change the native reward cache.
        if not sameBudget(state.context, context) then state.entries, state.changed = {}, nil end
        state.context = context
    end
    local binding = { ids = {}, current = ownerCurrent, refresh = refreshCallback, frame = owner.frame or owner, itemEpoch = {} }
    if requests[owner] ~= request then return end
    state.binding = binding
    state.cursor = 1
    local seen = {}
    for index = 1, math.min(#coldIDs, 600) do
        local id = addon.Clean(coldIDs[index], "number")
        local quest = id and addon.Clean(context.quests[id], "table")
        if requests[owner] ~= request then return end
        if id and id > 0 and id % 1 == 0 and not seen[id] and quest then
            seen[id] = true; binding.ids[#binding.ids + 1] = id
            local entry = state.entries[id]
            if not entry or entry.quest ~= context.quests[id] then
                state.entries[id] = { quest = context.quests[id], attempts = 0 }
            end
        end
    end
    -- Item arrivals repaint the same list. Restarting its slices can repeatedly
    -- hydrate early cold rows while later quests never receive a first request.
    if sameWork and previous and cursor and #previous.ids == #binding.ids then
        local sameIDs = true
        for index, id in ipairs(binding.ids) do
            if previous.ids[index] ~= id then sameIDs = false; break end
        end
        if sameIDs then state.cursor = cursor end
    end
    -- Native hydration is deferred in two-quest slices; opening a large list
    -- never walks every reward tuple before returning to the frame loop.
    schedule(owner, state)
end
