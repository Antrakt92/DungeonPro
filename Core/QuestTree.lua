local _, addon = ...
local Tree = {}
addon.QuestTree = Tree

function Tree.Build(quests, engine, rootID)
    local clean, read, checker = addon.Clean, addon.Read, issecretvalue
    local function id(value)
        value = clean(value, "number")
        if value and value > 0 and value <= 9007199254740991 and value % 1 == 0 then return value end
    end
    if not clean(quests, "table") or not clean(engine, "table") or not id(rootID) then return nil, "input" end
    local stateGetter, contextGetter = clean(engine.State, "function"), clean(engine.Current, "function")
    if not stateGetter then return nil, "engine" end
    local engineQuests, engineContext, engineChoices = rawget(engine, "quests"), rawget(engine, "context"), rawget(engine, "choices")
    if engineQuests ~= nil and engineQuests ~= quests then return nil, "engine" end
    local nodes, sources, states, seen, visiting, byID = {}, {}, {}, {}, {}, {}
    local failed, edges = nil, 0
    local function same(value, previous)
        if type(checker) == "function" and read(checker, "boolean", value) ~= false then return false end
        return value == previous
    end
    local function current()
        if addon.QuestTree ~= Tree or addon.Clean ~= clean or addon.Read ~= read or issecretvalue ~= checker or
            engine.State ~= stateGetter or engine.Current ~= contextGetter or not same(rawget(engine, "quests"), engineQuests) or
            not same(rawget(engine, "context"), engineContext) or not same(rawget(engine, "choices"), engineChoices) then return false end
        if contextGetter and read(contextGetter, "boolean", engine) ~= true then return false end
        if addon.QuestTree ~= Tree or addon.Clean ~= clean or addon.Read ~= read or issecretvalue ~= checker or
            engine.State ~= stateGetter or engine.Current ~= contextGetter or not same(rawget(engine, "quests"), engineQuests) or
            not same(rawget(engine, "context"), engineContext) or not same(rawget(engine, "choices"), engineChoices) then return false end
        for _, source in ipairs(sources) do
            if not same(rawget(quests, source.id), source.quest) then return false end
            for _, field in ipairs(source.fields) do
                if not same(rawget(field.object, field.key), field.value) then return false end
            end
        end
        for _, state in ipairs(states) do
            for _, key in ipairs({ "status", "reason", "completedHistory" }) do
                if not same(rawget(state.value, key), state[key]) then return false end
            end
        end
        return true
    end
    local function keep(source, object, key)
        local value = rawget(object, key)
        if type(checker) == "function" and read(checker, "boolean", value) ~= false then failed = "source"; return end
        source.fields[#source.fields + 1] = { object = object, key = key, value = value }
        return value
    end
    local function list(source, object, key)
        local value = keep(source, object, key)
        if value == nil then return nil end
        if not clean(value, "table") or #value > 100 then failed = "source"; return end
        keep(source, value, #value + 1)
        return value
    end
    local function capture(qid)
        local quest = rawget(quests, qid)
        if quest ~= nil and not clean(quest, "table") then failed = "source"; return end
        local source = { id = qid, quest = quest, fields = {}, groups = {} }
        sources[#sources + 1] = source
        if not quest then return source end
        local requirements = list(source, quest, "requires")
        for index = 1, requirements and #requirements or 0 do
            local group = keep(source, requirements, index)
            if not clean(group, "table") then failed = "source"; return end
            local mode = keep(source, group, "mode")
            if mode == nil then mode = "completed" end
            local members = list(source, group, "ids")
            if not members or #members == 0 or (mode ~= "completed" and mode ~= "active") then failed = "source"; return end
            local entry = { mode = mode, ids = {}, index = index }
            source.groups[#source.groups + 1] = entry
            for other = 1, #members do
                local parent = keep(source, members, other)
                if not id(parent) then failed = "source"; return end
                entry.ids[#entry.ids + 1] = parent
                edges = edges + 1
                if edges > 320 then nodes.truncated = true; return source end
            end
        end
        return source
    end
    local function append(qid, source, depth, relation, edge, root)
        if not current() then failed = "expired"; return end
        local state = read(stateGetter, "table", engine, qid)
        if not state or not clean(rawget(state, "status"), "string") or not current() then failed = "expired"; return end
        states[#states + 1] = { value = state, status = rawget(state, "status"), reason = rawget(state, "reason"),
            completedHistory = rawget(state, "completedHistory") }
        local node = { id = qid, state = state, depth = depth, relation = relation, root = root or nil, links = {},
            missing = not source.quest or nil }
        if edge then
            node.group, node.mode, node.alternatives, node.parentID = edge.group, edge.mode, edge.alternatives, edge.parentID
            node.storyIndex = edge.storyIndex
            if relation == "required" then node.links[1] = edge end
        end
        nodes[#nodes + 1] = node
        byID[qid] = node
    end
    local rootSource
    local function visit(qid, depth, edge)
        if failed then return end
        if seen[qid] then
            local node = byID[qid]
            if node and edge then
                node.links[#node.links + 1] = edge
                node.depth = math.min(node.depth, depth)
            end
            return
        end
        if visiting[qid] then nodes.cycle = true; return end
        if depth > 50 or (#sources >= 80 and qid ~= rootID) then nodes.truncated = true; return end
        visiting[qid] = true
        local source = capture(qid)
        if not source or failed then return end
        if qid == rootID then rootSource = source end
        for _, group in ipairs(source.groups) do
            for _, parent in ipairs(group.ids) do
                if not nodes.truncated then visit(parent, depth + 1, { group = group.index, mode = group.mode,
                    alternatives = #group.ids, parentID = qid }) end
                if failed then return end
            end
        end
        visiting[qid], seen[qid] = nil, true
        append(qid, source, depth, "required", edge, qid == rootID)
    end
    if not current() then return nil, "expired" end
    visit(rootID, 0)
    local function story(qid, group, index)
        if failed then return end
        if not id(qid) then failed = "source"; return end
        if seen[qid] then return end
        if #nodes >= 80 then nodes.truncated = true; return end
        local source = capture(qid)
        if not source or failed then return end
        seen[qid] = true
        append(qid, source, 1, "story", { group = group, storyIndex = index })
    end
    if rootSource and rootSource.quest then
        local ordered = list(rootSource, rootSource.quest, "storyline")
        local groups = list(rootSource, rootSource.quest, "storylineGroups")
        if ordered and groups then failed = "source" end
        for index = 1, ordered and #ordered or 0 do story(keep(rootSource, ordered, index), nil, index) end
        for index = 1, groups and #groups or 0 do
            local group = keep(rootSource, groups, index)
            if not clean(group, "table") or #group > 100 then failed = "source"; break end
            keep(rootSource, group, #group + 1)
            for other = 1, #group do story(keep(rootSource, group, other), index, other) end
        end
    end
    if failed or not current() then return nil, failed or "expired" end
    nodes.current = current
    return nodes
end
