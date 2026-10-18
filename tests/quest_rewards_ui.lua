local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, event = fixture.addon, fixture.eventFrame
function fixture.methods:SetFont(path, size, flags)
    self.fontPath, self.fontSize, self.fontFlags = path, size, flags
    return true
end
function fixture.methods:GetFont() return self.fontPath, self.fontSize, self.fontFlags end
local create = CreateFrame
CreateFrame = function(kind, name, parent, template)
    local object = create(kind, name, parent, template)
    object.parent = parent
    return object
end
event.scripts.OnEvent(event, "ADDON_LOADED", "DungeonPro")
SlashCmdList.DUNGEONPRO("")
local ui, loaded, reads, preloads = addon.UI, false, 0, 0
GetLocale = function() return "enUS" end
addon.db.locale = "enUS"
for _, dungeon in ipairs(addon.dungeons) do if dungeon.key == "dm" then ui.dungeon = dungeon end end
HaveQuestRewardData = function(id) reads = reads + 1; return id == 166 and loaded end
C_TaskQuest = { RequestPreloadRewardData = function(id)
    assert(id > 0 and addon.quests[id], "only catalogue quest rewards are requested")
    if id == 166 then preloads = preloads + 1 end
end }
GetNumQuestLogRewards = function(id) assert(id == 166); reads = reads + 1; return 1 end
GetNumQuestLogChoices = function(id) assert(id == 166); reads = reads + 1; return 5 end
GetQuestLogRewardInfo = function(index, id)
    assert(index == 1 and id == 166); reads = reads + 1
    return "Guaranteed reward", 134400, 1, 2, true, 7001
end
GetQuestLogChoiceInfo = function(index, id)
    assert(id == 166); reads = reads + 1
    return "Choice reward " .. index, 134400 + index, 1, 2, true, 8000 + index
end
local tip = {}
function tip:SetOwner(owner) self.owner = owner end
function tip:IsOwned(owner) return self.owner == owner end
function tip:SetText(text) self.text = text end
function tip:SetHyperlink(link)
    self.link, self.text, self.lines = link, "Native item statistics", {}
end
function tip:AddLine(text) self.lines[#self.lines + 1] = text end
function tip:Show() self.shown = true end
function tip:Hide() self.shown = false end
GameTooltip = tip
local timer, pending = C_Timer, {}
C_Timer = { After = function(delay, callback)
    if delay < 3 then pending[#pending + 1] = {delay=delay, callback=callback} end
end }
ui.quest = nil; ui:Refresh()
local function questRow()
    for _, row in ipairs(ui.rows) do if row:IsShown() and row.questID == 166 then return row end end
    error("quest row missing")
end
local function icons(row)
    local result = {}
    for _, object in ipairs(fixture.objects) do
        if object.parent == row and object.kind == "Button" and object.icon and object:IsShown() then result[#result + 1] = object end
    end
    return result
end
assert(#icons(questRow()) == 0, "cold reward data must not invent an item")
assert(#pending == 1, "cold rows share one deferred cache check")
table.remove(pending, 1).callback()
assert(preloads == 1 and #icons(questRow()) == 0, "cold rewards request hydration without inventing items")
loaded = true
local ticks = 0
while #pending > 0 do
    ticks = ticks + 1; assert(ticks < 200, "deferred reward slices must settle")
    table.remove(pending, 1).callback()
end
local row = questRow()
local buttons = icons(row)
assert(#buttons == 3, "deferred cache arrival repaints without requiring an event")
assert(buttons[3].overflowLabel and buttons[3].overflowLabel:GetText() == "+3")
local before, selected, root = reads, ui.quest, ui.questTreeRoot
for index, button in ipairs(buttons) do
    button.scripts.OnEnter()
    assert(tip.shown and tip.owner == button and tip.text == "Native item statistics", "native item statistics survive supplemental reward text")
    assert(tip.link == "item:" .. (index == 1 and 7001 or 7999 + index), "each icon opens its own item tooltip")
    local supplemental = table.concat(tip.lines, "\n")
    assert(supplemental:find("Guaranteed reward", 1, true))
    assert(supplemental:find(addon.L("REWARD_ITEMS"), 1, true) and supplemental:find(addon.L("REWARD_CHOICES"), 1, true))
    for choice = 1, 5 do assert(supplemental:find("Choice reward " .. choice, 1, true), "every choice is visible in the hover preview") end
    button.scripts.OnLeave(); assert(not tip.shown)
end
assert(reads == before and ui.quest == selected and ui.questTreeRoot == root, "hover does not query rewards or select quests")
assert(preloads == 1, "hover never requests quest reward data again")
local enter = buttons[1].scripts.OnEnter
loaded = false
event.scripts.OnEvent(event, "QUEST_DATA_LOAD_RESULT", 166, false)
ticks = 0
while #pending > 0 do
    ticks = ticks + 1; assert(ticks < 200, "cache invalidation must settle")
    table.remove(pending, 1).callback()
end
assert(#icons(questRow()) == 0)
enter(); assert(not tip.shown, "a recycled reward cannot revive the previous quest tooltip")
local itemReady, itemRequests, itemReads = false, 0, 0
HaveQuestRewardData = function(id) return id == 166 end
GetQuestLogRewardInfo = function(index, id)
    assert(index == 1 and id == 166)
    return itemReady and "Guaranteed reward" or nil, itemReady and 134400 or nil, 1, 2, true, 7001
end
GetQuestLogChoiceInfo = function(index, id)
    assert(id == 166)
    return itemReady and "Choice reward " .. index or nil, itemReady and 134400 + index or nil, 1, 2, true, 8000 + index
end
C_Item = {
    GetItemNameByID = function() itemReads = itemReads + 1; return itemReady and "Cached reward" or nil end,
    IsItemDataCachedByID = function() return itemReady end,
    RequestLoadItemDataByID = function() itemRequests = itemRequests + 1 end,
}
pending = {}
C_Timer = { After = function(delay, callback) pending[#pending + 1] = {delay=delay, callback=callback} end }
ui:Refresh()
assert(itemRequests == 0 and #icons(questRow()) == 0, "opening the list defers native item hydration")
local hydrate = table.remove(pending, 1)
assert(hydrate and hydrate.delay == .2, "cold item work has a bounded deferred first slice")
hydrate.callback()
assert(itemRequests == 6 and #icons(questRow()) == 0, "a deferred slice hydrates all six known items without placeholder icons")
itemReady = true
event.scripts.OnEvent(event, "ITEM_DATA_LOAD_RESULT", 7001, true)
local painted = false
for _, entry in ipairs(pending) do
    if entry.delay == .1 then entry.callback(); painted = true; break end
end
assert(painted and #icons(questRow()) == 3, "item arrival event repaints compact rewards in the actual UI")
local requested, queried = itemRequests, itemReads
buttons = icons(questRow())
buttons[1].scripts.OnEnter(); assert(tip.shown and tip.link == "item:7001")
buttons[1].scripts.OnLeave()
assert(itemRequests == requested and itemReads == queried, "native reward hover never hydrates items")
C_Timer = timer
print("Actual quest reward previews: PASS (cold event, compact icons, all choices, hover work, stale callbacks)")
