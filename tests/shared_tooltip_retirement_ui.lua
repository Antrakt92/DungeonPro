local f = assert(loadfile("tests/client_ui.lua"))("fixture")
local a, event = f.addon, f.eventFrame
local create = CreateFrame
CreateFrame = function(kind, name, parent, template)
    local object = create(kind, name, parent, template); object.parent = parent; return object
end
Minimap = CreateFrame("Frame"); Minimap.width = 200
local tip = { shows = 0 }
function tip:SetOwner(button) self.owner = button end
function tip:IsOwned(button) return self.owner == button end
function tip:SetText(text) self.text = text end
function tip:AddLine(text) self.body = text end
function tip:SetItemByID(id) self.item = id; self.shown = true; return true end
function tip:SetHyperlink(link) self.link = link end
function tip:Show() self.shown = true; self.shows = self.shows + 1 end
function tip:Hide() self.shown = false end
GameTooltip = tip
event.scripts.OnEvent(event, "ADDON_LOADED", "DungeonPro")
SlashCmdList.DUNGEONPRO("")
local ui, m = a.UI, a.Minimap
ui.rangeButton:Show(); m.button:Show()
local data = { source = "cache", items = { { id = 7083, name = "Purified Kor Gem", texture = 134400, count = 1 } }, choices = {} }
a.DialogueRewards = function() return nil end
a.QuestRewards = function() return nil end
a.CachedQuestRewards = function() return data end
C_Item = {}
C_Item.GetItemIconByID = function() return 134400 end
C_Item.GetItemNameByID = function(id) return "Native material " .. id end
for _, dungeon in ipairs(a.dungeons) do
    for _, id in ipairs(dungeon.quests) do if id == 1654 then ui.dungeon = dungeon end end
end
ui.quest, ui.includeUnavailable = 1654, true; ui:Refresh()
assert(ui.detailTab=="quest", "reward and objective tooltips stay on the practical Quest view")
local reward, objective = ui.rewardButtons[1], ui.objectiveButtons[1]
assert(reward and reward.shown and objective and objective.shown)
local list
for _, row in ipairs(ui.rows) do if row.shown and row.questID then
    for _, object in ipairs(f.objects) do
        if object.parent == row and object.icon and object.width == 20 and object.height == 20 and object.shown then list = object; break end
    end
    if list then break end
end end
assert(list, "actual cached list reward icon must exist")
local surfaces = {
    { name = "navigation", button = ui.rangeButton, enter = function() ui.rangeButton.scripts.OnEnter() end,
        release = function() ui:HideNavigationHint() end },
    { name = "minimap", button = m.button, enter = function() m:Tooltip() end,
        release = function() m:ReleaseTooltip() end },
    { name = "reward", button = reward, enter = function() reward.scripts.OnEnter() end,
        release = function() ui:ReleaseRewardTooltip() end },
    { name = "objective", button = objective, enter = function() objective.scripts.OnEnter() end,
        release = function() ui:ReleaseObjectiveTooltip() end },
    { name = "list-reward", button = list, enter = function() list.scripts.OnEnter() end,
        release = function() list.scripts.OnLeave() end },
}
local hide = tip.Hide
local function clear()
    tip.Hide = hide
    for _, surface in ipairs(surfaces) do surface.release() end
    tip.owner = nil; hide(tip)
end
local cases = 0
for _, old in ipairs(surfaces) do for _, next in ipairs(surfaces) do if old ~= next then
    clear()
    local armed, fired, depth, maxDepth = false, false, 0, 0
    tip.Hide = function(self)
        depth = depth + 1; maxDepth = math.max(maxDepth, depth)
        assert(depth <= 4, "shared tooltip cleanup must stay bounded")
        if armed then armed = false; fired = true; next.enter() end
        hide(self); depth = depth - 1
    end
    old.enter(); assert(tip.shown and tip.owner == old.button, "old hint completed: " .. old.name)
    armed = true; old.release()
    assert(fired, "native late Hide must run: " .. old.name .. " to " .. next.name)
    assert(tip.shown and tip.owner == next.button,
        "late " .. old.name .. " Hide suppressed completed " .. next.name .. " hint")
    assert(depth == 0 and maxDepth <= 3)
    cases = cases + 1
end end end
-- A completed lease must still own the native tooltip and its source when repaired.
local rejected = 0
for _, mode in ipairs({ "borrowed", "hidden", "invalid" }) do
for _, old in ipairs(surfaces) do for _, next in ipairs(surfaces) do if old ~= next then
    clear()
    local armed, fired = false, false
    local char, provider, session, unavailable = a.char, a.CachedQuestRewards, m.session, ui.includeUnavailable
    local rewardBinding, objectiveBinding = reward.rewardBinding, objective.objectiveBinding
    tip.Hide = function(self)
        if armed then
            armed = false; fired = true; next.enter()
            assert(self.owner == next.button and self.shown, "replacement hint completed before retirement")
            if mode == "borrowed" then self.owner = {}
            elseif mode == "hidden" then next.button:Hide()
            elseif next.name == "navigation" then ui.includeUnavailable = not unavailable
            elseif next.name == "minimap" then m.session = {}
            elseif next.name == "reward" then reward.rewardBinding = nil
            elseif next.name == "objective" then objective.objectiveBinding = nil
            else a.CachedQuestRewards = function() return data end end
        end
        hide(self)
    end
    old.enter(); armed = true; old.release()
    assert(fired and not tip.shown, "no resurrection: " .. mode .. " " .. old.name .. " to " .. next.name)
    a.char, a.CachedQuestRewards, m.session, ui.includeUnavailable = char, provider, session, unavailable
    reward.rewardBinding, objective.objectiveBinding = rewardBinding, objectiveBinding
    next.button:Show(); rejected = rejected + 1
end end end end
-- An ordinary release cannot hide a foreign native owner that already took over.
for _, surface in ipairs(surfaces) do
    clear(); surface.enter(); local foreign = {}; tip.owner = foreign
    surface.release()
    assert(tip.shown and tip.owner == foreign, "preserve borrowed tooltip: " .. surface.name)
end
-- Failed, partially painted replacements never publish a completed repair lease.
local partials = 0
for _, old in ipairs(surfaces) do for _, next in ipairs(surfaces) do if old ~= next then
    clear()
    local show, item = tip.Show, tip.SetItemByID
    local armed, painting, fired, failed = false, false, false, false
    tip.Show = function(self)
        if painting and self.owner == next.button then failed = true; error("replacement show failed") end
        return show(self)
    end
    tip.SetItemByID = function(self, id)
        if painting and self.owner == next.button then failed = true; self.shown = true; return false end
        return item(self, id)
    end
    tip.Hide = function(self)
        if armed then armed = false; fired = true; painting = true; next.enter(); painting = false end
        hide(self)
    end
    old.enter(); armed = true; old.release()
    assert(fired and failed and not tip.shown, "partial replacement must remain hidden: " .. old.name .. " to " .. next.name)
    tip.Show, tip.SetItemByID = show, item
    partials = partials + 1
end end end
clear()
-- Malformed saved config deliberately uses a valid ephemeral launcher session.
local config = a.db.minimap
a.db.minimap = true
assert(m:Initialize() and m.persisted == nil and m:Current(), "malformed config retains supported ephemeral controls")
m.button:Show(); ui.rangeButton:Show()
local armed, fired, completed = false, false, false
tip.Hide = function(self)
    if armed then
        armed = false; fired = true; m:Tooltip()
        completed = m.tooltip ~= nil and self.owner == m.button and self.shown == true
    end
    hide(self)
end
ui.rangeButton.scripts.OnEnter(); armed = true; ui:HideNavigationHint()
assert(fired and completed and tip.shown and tip.owner == m.button and a.db.minimap == true,
    "a completed ephemeral minimap hint survives older native Hide without rewriting config")
clear(); a.db.minimap = config; assert(m:Initialize())
print("Shared tooltip retirement UI checks passed: " .. cases .. " cross-owner native Hide interleavings, " .. rejected .. " stale repairs rejected, " .. partials .. " partial replacements rejected")
