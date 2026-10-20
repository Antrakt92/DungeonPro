local _, addon = ...
local UI = {}
addon.QuestHistory = UI

function UI:ResetHistoryReading()
    self.detailNavigationRevision = {}
    self.detailOffsets, self.detailOffsetsOwner, self.detailOffsetsDungeon = nil, nil, nil
end

function UI:HistoryOffsets()
    if self.detailOffsetsOwner ~= self.detailHistory or self.detailOffsetsDungeon ~= self.dungeon then
        self.detailOffsets = {}
        self.detailOffsetsOwner, self.detailOffsetsDungeon = self.detailHistory, self.dungeon
    end
    return self.detailOffsets
end

function UI:SetDetailTab(key)
    key = addon.Clean(key,"string")
    if key ~= "quest" and key ~= "sources" and key ~= "story" then return false end
    local quest, dungeon, character, engine, frame = self.quest, self.dungeon, addon.char, self.engine, self.frame
    local previous, revision, refresh, renderGeneration = self.detailTab, self.detailTabRevision, self.RefreshDetail, self.rewardGeneration
    local offsets, scroll, reader = self.detailTabOffsets, self.detailScroll, addon.Read
    local definition = quest and addon.quests[quest]
    local getter, currentGetter = scroll and scroll.GetVerticalScroll, engine and engine.Current
    local function current()
        return addon.UI == self and self.quest == quest and self.dungeon == dungeon and addon.char == character and self.engine == engine and
            self.frame == frame and self.rewardGeneration == renderGeneration and self.detailTab == previous and self.detailTabRevision == revision and self.RefreshDetail == refresh and
            self.detailTabOffsets == offsets and self.detailScroll == scroll and scroll.GetVerticalScroll == getter and addon.Read == reader and
            addon.quests[quest] == definition and engine.Current == currentGetter
    end
    if not quest or not frame or not engine or not scroll or not current() then return false end
    if previous == key then return true end
    local intent = {}; revision = intent; self.detailTabRevision = intent
    if reader(frame.IsShown,"boolean",frame) ~= true or not current() then return false end
    if currentGetter and reader(currentGetter,"boolean",engine) ~= true then return false end
    local offset = reader(getter,"number",scroll)
    if not current() then return false end
    if offset and offset >= 0 and type(offsets) == "table" then offsets[previous] = offset end
    self.detailTab = key
    local generation = refresh(self)
    local function fresh()
        return addon.UI == self and self.quest == quest and self.dungeon == dungeon and addon.char == character and self.engine == engine and
            self.frame == frame and self.detailTab == key and self.detailTabRevision == intent and self.RefreshDetail == refresh and
            self.detailTabOffsets == offsets and self.detailScroll == scroll and self.rewardGeneration == generation
    end
    if not generation or not fresh() then return false end
    local desired = offsets and addon.Clean(offsets[key],"number") or 0
    local content, viewport = reader(self.detail.GetHeight,"number",self.detail), reader(scroll.GetHeight,"number",scroll)
    if not fresh() then return false end
    if content and content >= 0 and viewport and viewport > 0 then
        return self:WriteDetailScroll(scroll,math.min(math.max(0,desired or 0),math.max(0,content-viewport)),fresh)
    end
    return fresh()
end

function UI:InspectQuest(id, refreshList, sourceFocus)
    id = addon.Clean(id, "number")
    if not id or id <= 0 or id % 1 ~= 0 then return false end
    local history, dungeon = self.detailHistory, self.dungeon
    local offsets = self:HistoryOffsets()
    local revision = {}
    self.detailNavigationRevision = revision
    if self.quest ~= id then
        local previous = addon.Clean(self.quest, "number")
        if previous and previous > 0 and previous % 1 == 0 then
            local scroll, generation, checker = self.detailScroll, self.rewardGeneration, issecretvalue
            local tab, tabRevision, tabOffsets, character = self.detailTab, self.detailTabRevision, self.detailTabOffsets, addon.char
            local getter = scroll.GetVerticalScroll
            local offset = addon.Read(getter, "number", scroll)
            if self.detailNavigationRevision ~= revision or self.quest ~= previous or self.dungeon ~= dungeon or
                self.detailHistory ~= history or self.rewardGeneration ~= generation or addon.char ~= character or
                self.detailTab ~= tab or self.detailTabRevision ~= tabRevision or self.detailTabOffsets ~= tabOffsets or
                scroll.GetVerticalScroll ~= getter or issecretvalue ~= checker then return false end
            history[#history + 1] = previous
            offsets[#history] = { quest = previous, offset = offset and offset >= 0 and offset or nil, tab = tab,
                tabOffsets = tabOffsets, character = character }
            if #history > 20 then
                table.remove(history, 1)
                for index = 1, #history do offsets[index] = offsets[index + 1] end
                offsets[#history + 1] = nil
            end
        end
        self.quest = id
    end
    if refreshList then
        self:RefreshQuests()
        if self.quest ~= id or self.dungeon ~= dungeon or self.detailHistory ~= history or self.detailNavigationRevision ~= revision then return false end
    end
    self:RefreshDetail(sourceFocus)
    return true
end

function UI:CanReturnToOverview()
    local id = addon.Clean(self.quest, "number")
    return id ~= nil and id > 0 and id % 1 == 0 and addon.Clean(self.dungeon, "table") ~= nil
end

function UI:BackQuest()
    local history, dungeon, character = self.detailHistory, self.dungeon, addon.char
    local offsets, index = self:HistoryOffsets(), #history
    local previous = history[index]
    if not previous and not self:CanReturnToOverview() then return false end
    local saved = offsets[index]
    local currentQuest = self.quest
    local currentTab, currentTabOffsets, currentTabRevision = self.detailTab, self.detailTabOffsets, self.detailTabRevision
    local currentTabQuest, currentTabDungeon, currentTabCharacter = self.detailTabQuest, self.detailTabDungeon, self.detailTabCharacter
    local currentRevision = self.detailNavigationRevision
    offsets[index] = nil
    table.remove(history)
    local revision = {}
    self.detailNavigationRevision = revision
    self.quest = previous
    local savedTab = saved and saved.quest == previous and saved.character == character and
        (saved.tab == "quest" or saved.tab == "sources" or saved.tab == "story") and saved.tab or "quest"
    self.detailTabQuest, self.detailTabDungeon, self.detailTabCharacter = previous, dungeon, character
    self.detailTab, self.detailTabOffsets, self.detailTabRevision = savedTab, saved and savedTab == saved.tab and saved.tabOffsets or {}, {}
    local tab, tabRevision = self.detailTab, self.detailTabRevision
    local frame, scroll, tabOffsets = self.frame, self.detailScroll, self.detailTabOffsets
    local preparation, includeUnavailable, range, search = self.preparation, self.includeUnavailable, self.range, self.search
    local layoutRevision, refreshList, refreshDetail = self.layoutRevision, self.RefreshQuests, self.RefreshDetail
    local function owned()
        return addon.UI == self and self.detailNavigationRevision == revision and self.quest == previous and
            self.dungeon == dungeon and self.detailHistory == history and addon.char == character and self.frame == frame and
            self.detailScroll == scroll and self.detailTab == tab and self.detailTabRevision == tabRevision and
            self.detailTabOffsets == tabOffsets and self.preparation == preparation and self.includeUnavailable == includeUnavailable and
            self.range == range and self.search == search and self.layoutRevision == layoutRevision and
            self.RefreshQuests == refreshList and self.RefreshDetail == refreshDetail
    end
    refreshList(self)
    -- History has already advanced; a newer view owns any remaining painting.
    if not owned() then
        if addon.UI == self and self.detailNavigationRevision == revision and self.quest == previous and
            self.dungeon == dungeon and self.detailHistory == history and #history == index - 1 and
            self.frame == frame and self.detailScroll == scroll and self.detailTab == tab and
            self.detailTabRevision == tabRevision and self.detailTabOffsets == tabOffsets and
            self.layoutRevision == layoutRevision and self.RefreshQuests == refreshList and self.RefreshDetail == refreshDetail then
            -- Same-destination filter/context drift: the newer list already owns
            -- painting, so roll back the tentative navigation instead of
            -- silently spending the history entry. Repaint the middle list
            -- once more so row selection follows the restored quest under
            -- the drifted filters; the detail pane still shows it.
            history[#history + 1] = previous
            if offsets[index] == nil then offsets[index] = saved end
            self.quest = currentQuest
            self.detailTabQuest, self.detailTabDungeon, self.detailTabCharacter = currentTabQuest, currentTabDungeon, currentTabCharacter
            self.detailTab, self.detailTabOffsets, self.detailTabRevision = currentTab, currentTabOffsets, currentTabRevision
            self.detailNavigationRevision = currentRevision
            refreshList(self)
        end
        return true
    end
    local engine = self.engine
    local rendered = refreshDetail(self)
    if not owned() or self.engine ~= engine or not rendered or self.rewardGeneration ~= rendered then return true end
    local offset = saved and saved.quest == previous and saved.character == character and addon.Clean(saved.offset, "number")
    if previous and offset and offset >= 0 and owned() and addon.Read(frame.IsShown, "boolean", frame) == true then
        local generation, checker, scroll = self.rewardGeneration, issecretvalue, self.detailScroll
        local content = addon.Read(self.detail.GetHeight, "number", self.detail)
        local viewport = addon.Read(scroll.GetHeight, "number", scroll)
        local function current()
            return owned() and self.engine == engine and self.rewardGeneration == generation and issecretvalue == checker and
                addon.char == character and self.detailTab == tab and self.detailTabRevision == tabRevision and self.quest == previous and self.dungeon == dungeon and self.detailHistory == history and self.detailScroll == scroll
        end
        if current() and content and viewport and content >= 0 and viewport > 0 then
            self:WriteDetailScroll(scroll, math.min(offset, math.max(0, content - viewport)), current)
        end
    end
    return true
end
