-- A retired icon reset cannot clear a newer pooled reward or objective presentation.
local total = 0
local function setup(kind)
    local f = assert(loadfile("tests/client_ui.lua"))("fixture")
    local a, ui = f.addon, f.addon.UI
    issecretvalue = function() return false end
    GetLocale = function() return "enUS" end
    C_Timer = { After = function() end }
    HaveQuestRewardData = function(id) return id == 166 or id == 214 end
    GetNumQuestLogRewards = function(id) return (id == 166 or id == 214) and 1 or 0 end
    GetNumQuestLogChoices = function() return 0 end
    GetQuestLogRewardInfo = function(index, id)
        assert(index == 1 and (id == 166 or id == 214))
        return "Native reward " .. id, 134400 + id, 1, 2, true, 7000 + id
    end
    GetQuestLogRewardMoney = function() return 0 end
    f.eventFrame.scripts.OnEvent(f.eventFrame, "ADDON_LOADED", "DungeonPro")
    ui:Toggle(); a.db.locale = "enUS"
    a.ItemIcon = function(id) return id + 1000 end
    local dungeon
    for _, d in ipairs(a.dungeons) do
        for _, id in ipairs(d.quests) do if id == (kind == "reward" and 166 or 4764) then dungeon = d end end
    end
    ui.dungeon, ui.quest = assert(dungeon), kind == "reward" and 166 or 4764
    ui:Refresh()
    local button = assert(kind == "reward" and ui.rewardButtons[1] or ui.objectiveButtons[1])
    assert(button:IsShown() and button.icon:IsShown())
    return f, a, ui, button
end
local function scenario(kind, method, moment, script)
    local _, a, ui, button = setup(kind)
    local bindingKey = kind .. "Binding"
    local previous = assert(button[bindingKey])
    local target = (method == "SetTexture" or method == "IconHide") and button.icon or button
    local nativeMethod = method == "IconHide" and "Hide" or method
    local original, armed, fired = target[nativeMethod], true, false
    local nextBinding, nextTexture, nextHeight, requests, routes = nil, nil, nil, 0, 0
    C_QuestLog.RequestLoadQuestByID = function() requests = requests + 1 end
    a.Navigation.Start = function() routes = routes + 1; return false end
    local tip = {}
    function tip:SetOwner(owner) self.owner = owner end
    function tip:IsOwned(owner) return self.owner == owner end
    function tip:SetItemByID(id) self.item, self.shown = id, true; return true end
    function tip:AddLine(text) self.context = text end
    function tip:Show() self.shown = true end
    function tip:Hide() self.shown = false end
    GameTooltip = tip
    local function supersede()
        armed, fired = false, true
        if kind == "reward" then ui.quest = 214 end
        ui:Refresh()
        nextHeight, nextBinding = ui.detail.height, button[bindingKey]
        if method == "SetTexture" then
            assert(ui.rewardTextureBusy and not nextBinding and not button:IsShown(), "busy nested render deliberately keeps text without icons")
        else
            assert(nextBinding and nextBinding ~= previous and button:IsShown() and button.icon:IsShown(), "new real composition must precede the retired native tail")
            nextTexture = button.icon.texture
            button.scripts.OnEnter()
            assert(tip.shown and tip.owner == button, "new native hover must own the pooled icon")
        end
    end
    target[nativeMethod] = function(self, ...)
        local hit = armed and (method ~= "SetScript" or (select(1, ...) == script and select(2, ...) == nil)) and
            (method ~= "SetTexture" or select(1, ...) == nil)
        if hit and moment == "before" then supersede() end
        local result = original(self, ...)
        if hit and moment == "after" then supersede() end
        return result
    end
    local accepted = ui:ResetRewardPresentation()
    target[nativeMethod] = original
    assert(fired and accepted == nil and ui.detail.height == nextHeight, "retired reset must stop without replacing the new card")
    assert(routes == 0 and requests == 0, "reset retirement cannot navigate or hydrate")
    if method == "SetTexture" then
        assert(not ui.rewardTextureBusy and not button:IsShown() and not button[bindingKey])
        ui:RefreshDetail()
        assert(button:IsShown() and button.icon:IsShown() and button[bindingKey], "ordinary redraw recovers icons after the busy setter")
    else
        assert(button[bindingKey] == nextBinding and button:IsShown() and button.icon:IsShown() and button.icon.texture == nextTexture,
            "retired reset must preserve new binding, visibility and artwork")
        assert(tip.shown and type(button.scripts.OnEnter) == "function" and type(button.scripts.OnHide) == "function")
        assert(type(button.scripts.OnLeave) == "function", "late old OnLeave clear must restore the current hover's cleanup")
        button.scripts.OnLeave(); assert(not tip.shown, "current hover still releases its tooltip lease")
    end
    total = total + 1
end
for _, kind in ipairs({ "reward", "objective" }) do
    for _, moment in ipairs({ "before", "after" }) do
        for _, script in ipairs({ "OnEnter", "OnLeave", "OnHide" }) do scenario(kind, "SetScript", moment, script) end
        scenario(kind, "Hide", moment)
        scenario(kind, "IconHide", moment)
        scenario(kind, "SetTexture", moment)
    end
end
-- Ordinary clearing and native texture failure remain bounded and recoverable.
for _, kind in ipairs({ "reward", "objective" }) do
    local _, _, ui, button = setup(kind)
    local generation = ui:ResetRewardPresentation()
    assert(generation == ui.rewardGeneration and not button:IsShown() and not button.icon:IsShown() and button.icon.texture == nil)
    assert(not button.rewardBinding and not button.objectiveBinding and not button.scripts.OnEnter and not button.scripts.OnLeave and not button.scripts.OnHide)
    local setter = button.icon.SetTexture
    for _, result in ipairs({ "false", "nil", "throw" }) do
        button.icon.SetTexture = function()
            if result == "throw" then error("modeled native texture failure") end
            if result == "false" then return false end
        end
        ui:RefreshDetail(); assert(not ui.rewardTextureBusy and not button:IsShown(), "missing native acknowledgement cannot publish an icon")
    end
    button.icon.SetTexture = setter
    ui:RefreshDetail(); assert(button:IsShown() and button.icon:IsShown())
end
print("PASS reward reset retirement: " .. total .. " fired native script/visibility/texture interleavings plus normal clear/throw recovery")
