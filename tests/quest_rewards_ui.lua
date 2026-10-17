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
local ui, loaded, reads = addon.UI, false, 0
GetLocale = function() return "enUS" end
addon.db.locale = "enUS"
for _, dungeon in ipairs(addon.dungeons) do if dungeon.key == "dm" then ui.dungeon = dungeon end end
HaveQuestRewardData = function(id) reads = reads + 1; return id == 166 and loaded end
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
function tip:Show() self.shown = true end
function tip:Hide() self.shown = false end
GameTooltip = tip
local timer, pending = C_Timer, {}
C_Timer = { After = function(delay, callback)
    if delay < 3 then pending[#pending + 1] = callback end
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
loaded = true
assert(#pending == 1, "cold rows share one deferred cache check")
pending[1]()
C_Timer = timer
local row = questRow()
local buttons = icons(row)
assert(#buttons == 3, "deferred cache arrival repaints without requiring an event")
assert(buttons[3].overflowLabel and buttons[3].overflowLabel:GetText() == "+3")
local before, selected, root = reads, ui.quest, ui.questTreeRoot
for _, button in ipairs(buttons) do
    button.scripts.OnEnter()
    assert(tip.shown and tip.owner == button and tip.text:find("Guaranteed reward", 1, true))
    assert(tip.text:find(addon.L("REWARD_ITEMS"), 1, true) and tip.text:find(addon.L("REWARD_CHOICES"), 1, true))
    for index = 1, 5 do assert(tip.text:find("Choice reward " .. index, 1, true), "every choice is visible in the hover preview") end
    button.scripts.OnLeave(); assert(not tip.shown)
end
assert(reads == before and ui.quest == selected and ui.questTreeRoot == root, "hover does not query rewards or select quests")
local enter = buttons[1].scripts.OnEnter
loaded = false
event.scripts.OnEvent(event, "QUEST_DATA_LOAD_RESULT", 166, false)
assert(#icons(questRow()) == 0)
enter(); assert(not tip.shown, "a recycled reward cannot revive the previous quest tooltip")
print("Actual quest reward previews: PASS (cold event, compact icons, all choices, hover work, stale callbacks)")
