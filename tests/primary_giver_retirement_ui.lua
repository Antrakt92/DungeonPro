-- Primary giver rendering must preserve a newer real quest card after native callbacks.
local total = 0
local function fixture()
    local f = assert(loadfile("tests/client_ui.lua"))("fixture")
    local a, u = f.addon, f.addon.UI
    issecretvalue = function() return false end
    GetLocale = function() return "enUS" end
    UnitLevel = function() return 60 end
    UnitClass = function() return "Mage", "MAGE", 8 end
    UnitFactionGroup = function() return "Alliance" end
    C_QuestLog.IsOnQuest = function() return false end
    C_QuestLog.ReadyForTurnIn = function() return false end
    C_Timer = { After = function() end }
    local visits = {}
    a.Navigation.Start = function(action) visits[#visits + 1] = action; return true end
    f.eventFrame.scripts.OnEvent(f.eventFrame, "ADDON_LOADED", "DungeonPro")
    u:Toggle(); a.db.locale = "enUS"
    local dm
    for _, dungeon in ipairs(a.dungeons) do if dungeon.key == "dm" then dm = dungeon end end
    assert(dm)
    u.dungeon, u.quest, u.range = dm, 166, false; u:Refresh()
    local contact=assert(u.detailContactRows[1]);assert(contact:IsShown()and contact.enabled and contact.detailContactBinding.current()and u.giverBinding.current())
    assert(not u.giver:IsShown()and not u.giver.enabled and u.giver.scripts.OnClick==nil)
    return a,u,visits,contact.scripts.OnClick
end
local function snapshot(u)
    local control,point=assert(u.detailContactRows[1]),{}
    for index, value in ipairs(control.point or {}) do point[index] = value end
    return { shown = control:IsShown(), enabled = control.enabled, footerEnabled = control.footerEnabled,
        pressed = control.footerPressed, hovered = control.footerHovered, point = point,
        key=u.giverUnavailableKey,label=control.title.text,note=control.note.text,binding=control.detailContactBinding,
        legacyBinding=u.giverBinding,action=u.giverAction,width=control.width,height=control.height,
        oldFooterEnabled=u.giver.footerEnabled,oldPressed=u.giver.footerPressed,oldHovered=u.giver.footerHovered,oldLabel=u.giver.footerLabelKey }
end
local function same(a,u,expected,target,visits,retained)
    local control=assert(u.detailContactRows[1])
    assert(u.quest == target and u.detailTab == "quest" and u.frame:IsShown())
    assert(control:IsShown() == expected.shown, "older primary-giver native tail must preserve newer visibility")
    assert(control.enabled == expected.enabled and control.footerEnabled == expected.footerEnabled,
        "native enabled state and footer state must both belong to the newer card")
    assert(control.footerPressed == expected.pressed and control.footerHovered == expected.hovered)
    assert(u.giverUnavailableKey==expected.key and control.title.text==expected.label and control.note.text==expected.note,
        "retired giver cleanup cannot reset a newer own source warning or label")
    assert(control.detailContactBinding==expected.binding and u.giverBinding==expected.legacyBinding and u.giverAction==expected.action)
    assert(control.width==expected.width and control.height==expected.height,"new full contact measured geometry survives old native tail")
    assert(u.giver.footerEnabled==expected.oldFooterEnabled and u.giver.footerPressed==expected.oldPressed and u.giver.footerHovered==expected.oldHovered and u.giver.footerLabelKey==expected.oldLabel,"legacy footer state belongs to newer render")
    if expected.shown then
        assert(control.point, "new visible primary giver must retain its anchor")
        for index, value in ipairs(expected.point) do assert(control.point[index] == value, "newer primary-giver anchor remains intact") end
    end
    assert(type(retained)=="function");retained()
    assert(#visits==0,"rendering and retained previous contact cannot navigate automatically")
    if target==214 then assert(control:IsShown()and control.enabled and control.scripts.OnClick);control.scripts.OnClick()end
    if target == 214 then
        assert(#visits == 1 and visits[1].id == 214 and visits[1].kind == "visit" and visits[1].place == a.quests[214].start)
        assert(u.detailContactRows[1].detailContactBinding.current()and u.giverBinding.current(),"fresh known giver remains current and separate from turn-in")
    else
        assert(not control:IsShown()and not control.enabled and control.scripts.OnClick==nil,"item replacement retires the old full-row pickup capability")
        assert(#visits==0 and not u.giverAction and not u.giverBinding,"item starter has no invented NPC pickup route")
    end
end
local cases = {
    { method = "Show", stage = "publication", target = 6981 },
    { method = "Hide", stage = "cleanup", target = 214 },
    { method = "SetEnabled", stage = "cleanup", target = 214 },
    { method = "SetEnabled", stage = "publication", target = 6981 },
    { method = "ClearAllPoints", stage = "publication", target = 214 },
    { method = "SetPoint", stage = "publication", target = 214 },
}
for _, case in ipairs(cases) do for _, phase in ipairs({ "before", "after" }) do
    local a,u,visits,retained=fixture()
    local control,fired,completed,expected=assert(u.detailContactRows[1]),false,false
    local setter = control[case.method]
    local function replace()
        fired = true
        assert(u:InspectQuest(case.target, true)); assert(u:SetDetailTab("sources"))
        expected = snapshot(u); completed = true
    end
    control[case.method] = function(self, ...)
        local value = ...
        local hit = not fired and (case.method ~= "SetEnabled" or value == (case.stage == "publication"))
        if hit and phase == "before" then replace() end
        local result = setter(self, ...)
        if hit and phase == "after" then replace() end
        return result
    end
    u:RefreshDetail(); control[case.method] = setter
    assert(fired and completed, "native giver callback must actually complete replacement")
    same(a,u,expected,case.target,visits,retained)
    total = total + 1
end end
-- Label, localization and the existing footer-icon API are callback boundaries too.
for _, boundary in ipairs({ "label", "localizer", "icon" }) do
    for _, target in ipairs({ 214, 6981 }) do for _, phase in ipairs({ "before", "after" }) do
        local a,u,visits,retained=fixture()
        local control,fired,completed,expected=assert(u.detailContactRows[1]),false,false
        local function replace()
            fired = true
            assert(u:InspectQuest(target, true)); assert(u:SetDetailTab("sources"))
            expected = snapshot(u); completed = true
        end
        local owner,method=control.title,"SetText"
        if boundary=="localizer"then owner,method=a,"L"
        elseif boundary=="icon"then owner,method=u,"RefreshFooterIcon"end
        local original = owner[method]
        owner[method] = function(...)
            local first, second = ...
            local hit = not fired and (boundary=="label"and first==control.title and type(second)=="string" or
                boundary == "localizer" and first == "DETAIL_GIVER" or
                boundary=="icon"and first==u and second==u.giver)
            if hit and phase == "before" then replace() end
            local result = original(...)
            if hit and phase == "after" then replace() end
            return result
        end
        u:RefreshDetail()
        assert(fired and completed, "the intended giver " .. boundary .. " callback must actually complete")
        same(a,u,expected,target,visits,retained)
        owner[method] = original
        total = total + 1
    end end
end
-- The last pending-giver coordinate read must not publish old action metadata after a fresh card.
for _, target in ipairs({ 214, 6981 }) do
    local a,u,visits,retained=fixture()
    local clean, theme = a.Clean, u.ApplyTheme
    local run, armed, fired, completed, expected = false, false, false, false
    local previousY = a.quests[166].start.y
    a.Clean = function(value, kind)
        if armed and not fired and kind == "number" and value == previousY then
            fired = true
            assert(u:InspectQuest(target, true)); assert(u:SetDetailTab("sources"))
            expected = snapshot(u); completed = true
        end
        return clean(value, kind)
    end
    u.ApplyTheme = function(self, ...)
        local result = theme(self, ...)
        if run and not fired and self.quest == 166 then armed = true end
        return result
    end
    u:RefreshQuests(); run = true; u:RefreshDetail()
    assert(fired and completed, "the final pending-giver coordinate callback must actually replace the card")
    same(a,u,expected,target,visits,retained)
    a.Clean, u.ApplyTheme = clean, theme
    total = total + 1
end
-- Optional native caption support uses the same owner and cannot resume an old label after reentry.
for _, phase in ipairs({ "before", "after" }) do
    local a,u,visits,retained=fixture()
    local control = u.giver
    control.caption = control:CreateFontString()
    local caption, fired, completed, expected = control.caption, false, false
    local setter = caption.SetText
    local function replace()
        fired = true
        assert(u:InspectQuest(6981, true)); assert(u:SetDetailTab("sources"))
        expected = snapshot(u); completed = true
    end
    caption.SetText = function(self, value)
        local hit = not fired
        if hit and phase == "before" then replace() end
        local result = setter(self, value)
        if hit and phase == "after" then replace() end
        return result
    end
    u:RefreshDetail(); caption.SetText = setter
    assert(fired and completed)
    same(a,u,expected,6981,visits,retained)
    total = total + 1
end
-- The component must not introduce retained render state through its native ownership records.
do
    local a, u, visits = fixture()
    local weak = setmetatable({ u.engine }, { __mode = "v" })
    assert(u:InspectQuest(6981, true)); assert(u:SetDetailTab("sources"))
    u.frame:Hide(); u.frame.scripts.OnHide(u.frame); u.frame:Show(); u:Refresh()
    collectgarbage("collect"); collectgarbage("collect")
    assert(weak[1] == nil and #visits == 0)
    total = total + 1
end
print("PASS primary giver native ownership: " .. total .. " actual replacement/route/metadata/anchor/GC cases")
