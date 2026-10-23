local _, addon = ...
local Tree = {}
addon.QuestTree = Tree

function Tree.Build(quests, engine, rootID)
    local clean, read, checker, builder = addon.Clean, addon.Read, issecretvalue, Tree.Build
    local function id(value)
        value = clean(value, "number")
        if value and value > 0 and value <= 9007199254740991 and value % 1 == 0 then return value end
    end
    if not clean(quests, "table") or not clean(engine, "table") or not id(rootID) then return nil, "input" end
    local stateGetter, contextGetter = clean(engine.State, "function"), clean(engine.Current, "function")
    if not stateGetter then return nil, "engine" end
    local engineQuests, engineContext, engineChoices = rawget(engine, "quests"), rawget(engine, "context"), rawget(engine, "choices")
    local rawStateGetter, rawContextGetter = rawget(engine, "State"), rawget(engine, "Current")
    if engineQuests ~= nil and engineQuests ~= quests then return nil, "engine" end
    local nodes, sources, states, seen, visiting, byID, arrays = {}, {}, {}, {}, {}, {}, {}
    local failed, edges, building = nil, 0, true
    local function same(value, previous)
        if type(checker) == "function" and read(checker, "boolean", value) ~= false then return false end
        return value == previous
    end
    local function rawCurrent()
        local ok, valid = pcall(function()
            if not rawequal(rawget(addon, "QuestTree"), Tree) or not rawequal(rawget(Tree, "Build"), builder) or not rawequal(rawget(addon, "Clean"), clean) or
                not rawequal(rawget(addon, "Read"), read) or not rawequal(rawget(_G, "issecretvalue"), checker) or
                not rawequal(rawget(engine, "State"), rawStateGetter) or not rawequal(rawget(engine, "Current"), rawContextGetter) or
                not rawequal(rawget(engine, "quests"), engineQuests) or not rawequal(rawget(engine, "context"), engineContext) or
                not rawequal(rawget(engine, "choices"), engineChoices) then return false end
            if not building then
                for _, source in ipairs(sources) do
                    if not rawequal(rawget(quests, source.id), source.quest) then return false end
                    for _, field in ipairs(source.fields) do
                        if not rawequal(rawget(field.object, field.key), field.value) then return false end
                    end
                end
                for _, state in ipairs(states) do
                    if not rawequal(rawget(state.value, "status"), state.status) or
                        not rawequal(rawget(state.value, "reason"), state.reason) or
                        not rawequal(rawget(state.value, "completedHistory"), state.completedHistory) then return false end
                end
                -- A sparse extension can change # without touching the old nil sentinel.
                for _, array in ipairs(arrays) do
                    if #array.object ~= array.length then return false end
                end
            end
            return true
        end)
        return ok and valid == true
    end
    local function current()
        if addon.QuestTree ~= Tree or Tree.Build ~= builder or addon.Clean ~= clean or addon.Read ~= read or issecretvalue ~= checker or
            engine.State ~= stateGetter or engine.Current ~= contextGetter or not same(rawget(engine, "quests"), engineQuests) or
            not same(rawget(engine, "context"), engineContext) or not same(rawget(engine, "choices"), engineChoices) then return false end
        if contextGetter and read(contextGetter, "boolean", engine) ~= true then return false end
        if addon.QuestTree ~= Tree or Tree.Build ~= builder or addon.Clean ~= clean or addon.Read ~= read or issecretvalue ~= checker or
            engine.State ~= stateGetter or engine.Current ~= contextGetter or not same(rawget(engine, "quests"), engineQuests) or
            not same(rawget(engine, "context"), engineContext) or not same(rawget(engine, "choices"), engineChoices) then return false end
        if not building then
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
        end
        -- Callbacks may change earlier fields; end with the shared raw proof.
        return rawCurrent()
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
        arrays[#arrays + 1] = { object = value, length = #value }
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
        if requirements then
            -- A sparse requires list would silently drop AND-groups under 1..#
            -- while still publishing a partial hierarchy (fail-open). Census the
            -- integer keys via next, mirroring DungeonOverview.sequence, so a
            -- malformed/hand-edited catalogue fails closed as source. Dense
            -- arrays pass through unchanged. Sparse group.ids needs no guard:
            -- dropping OR alternatives can only omit nodes, never invent them.
            local length, count = #requirements, 0
            for key in next, requirements do
                count = count + 1
                if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > length then failed = "source"; return end
            end
            if count ~= length then failed = "source"; return end
        end
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
    local function append(qid, source, depth, relation, edge, root, storyOwner)
        if not current() then failed = "expired"; return end
        local state = read(stateGetter, "table", engine, qid)
        if not state or not clean(rawget(state, "status"), "string") or not current() then failed = "expired"; return end
        states[#states + 1] = { value = state, status = rawget(state, "status"), reason = rawget(state, "reason"),
            completedHistory = rawget(state, "completedHistory") }
        local node = { id = qid, state = state, depth = depth, relation = relation, root = root or nil, links = {},
            missing = not source.quest or nil }
        if storyOwner and relation=="required" then node.requirementScope, node.storyOwnerID = "story", storyOwner end
        if edge then
            node.group, node.mode, node.alternatives, node.parentID = edge.group, edge.mode, edge.alternatives, edge.parentID
            node.storyIndex = edge.storyIndex
            if relation == "required" then node.links[1] = edge end
        end
        nodes[#nodes + 1] = node
        byID[qid] = node
    end
    local rootSource
    local storyNodes, storySeen, storyRequirements = {}, {}, {}
    local rootStoryIndex, rootStoryGroup
    local function visit(qid, depth, edge, storyOwner, order, storyMember)
        if failed then return end
        if seen[qid] then
            local node = byID[qid]
            if node and edge and edge.parentID then
                node.links[#node.links + 1] = edge
                node.depth = math.min(node.depth, depth)
                if node.relation=="story" and storyOwner then
                    -- A story slot may be encountered before another member
                    -- proves it is an alternative prerequisite of that member.
                    node.relation, node.requirementScope, node.storyOwnerID = "required", "story", storyOwner
                    node.group, node.mode, node.alternatives, node.parentID = edge.group, edge.mode, edge.alternatives, edge.parentID
                end
            end
            if node and order then order[#order + 1] = node end
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
                    alternatives = #group.ids, parentID = qid, scope = storyOwner and "story" or nil,
                    storyOwnerID = storyOwner }, storyOwner, order) end
                if failed then return end
            end
        end
        visiting[qid], seen[qid] = nil, true
        append(qid, source, depth, storyMember and "story" or "required", edge, qid == rootID, storyOwner)
        if byID[qid] and order then order[#order + 1] = byID[qid] end
    end
    if not current() then return nil, "expired" end
    visit(rootID, 0)
    local function story(qid, group, index)
        if failed then return end
        if not id(qid) then failed = "source"; return end
        local node = byID[qid]
        if not seen[qid] then
            if #nodes >= 80 then nodes.truncated = true; return end
            local order = {}
            storyRequirements[qid] = order
            visit(qid, 1, { group = group, storyIndex = index }, qid, order, true)
            node = byID[qid]
        end
        if not node or failed or storySeen[qid] then return end
        storySeen[qid] = true
        -- Story position also belongs to an already-emitted target or required
        -- node. Its dependency relation and OR-group identity stay unchanged.
        node.storyIndex, node.storyGroup = index, group
        if node.requirementScope=="story" then node.depth=math.min(node.depth,1) end
        storyNodes[#storyNodes + 1] = node
        if qid == rootID then rootStoryIndex, rootStoryGroup = index, group end
    end
    if rootSource and rootSource.quest then
        local ordered = list(rootSource, rootSource.quest, "storyline")
        local groups = list(rootSource, rootSource.quest, "storylineGroups")
        if ordered and groups then failed = "source" end
        for index = 1, ordered and #ordered or 0 do story(keep(rootSource, ordered, index), nil, index) end
        for index = 1, groups and #groups or 0 do
            local group = keep(rootSource, groups, index)
            if not clean(group, "table") or #group > 100 then failed = "source"; break end
            arrays[#arrays + 1] = { object = group, length = #group }
            keep(rootSource, group, #group + 1)
            for other = 1, #group do story(keep(rootSource, group, other), index, other) end
        end
    end
    if failed or not current() then return nil, failed or "expired" end
    local presentation, presented = {}, {}
    local function present(node)
        if presented[node.id] then return end
        presented[node.id] = true
        presentation[#presentation + 1] = node
    end
    -- Actual requirements retain topological order and are never inferred from
    -- the optional story. The target itself appears at its recorded story slot.
    for _, node in ipairs(nodes) do
        node.onTargetPath = node.root == true or (node.relation == "required" and node.requirementScope ~= "story")
        node.presentationRelation = node.relation
        if node.relation == "required" and node.requirementScope ~= "story" and not node.root then present(node) end
    end
    local target = byID[rootID]
    if target and not storySeen[rootID] then present(target) end
    for _, node in ipairs(storyNodes) do
        if node.relation == "story" or node.root or node.requirementScope=="story" then
            node.presentationRelation = "story"
            if not node.root and node.requirementScope~="story" and rootStoryIndex then
                -- Parallel peers in the target's group have no recorded order.
                node.onTargetPath = rootStoryGroup and node.storyGroup < rootStoryGroup or
                    (not rootStoryGroup and node.storyGroup == nil and node.storyIndex < rootStoryIndex) or false
            end
            for _, ancestor in ipairs(storyRequirements[node.id] or {}) do
                -- Listed story members retain their explicit slots even when
                -- their recorded requirement edges imply another order.
                if not storySeen[ancestor.id] then present(ancestor) end
            end
            present(node)
        end
    end
    for _, node in ipairs(nodes) do present(node) end
    -- Construction owns only a private model. Re-prove every captured field
    -- after all callbacks before exposing the hierarchy or its retained guard.
    building = false
    if not current() then return nil, "expired" end
    nodes.presentation, nodes.targetID = presentation, rootID
    nodes.current, nodes.rawCurrent = current, rawCurrent
    return nodes
end
