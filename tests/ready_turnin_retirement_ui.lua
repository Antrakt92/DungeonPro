-- Retained turn-in hints and late native tooltip writes belong to their exact READY action.
local f = assert(loadfile("tests/client_ui.lua"))("fixture")
local a, ui = f.addon, f.addon.UI
C_Timer = { After = function() end }
issecretvalue = function() return false end
GetLocale = function() return "enUS" end
f.eventFrame.scripts.OnEvent(f.eventFrame, "ADDON_LOADED", "DungeonPro")
ui:Toggle(); ui.includeUnavailable = true; a.db.locale = "enUS"
local dungeon
for _, d in ipairs(a.dungeons) do if d.key == "rfc" then dungeon = d end end
assert(dungeon)
local token, ready = {}, true
a.Context = function()
    local owner = token
    return { level = 60, faction = "Horde", class = "MAGE", current = function() return owner == token end,
        completed = function() return false end, active = function(id) return id == 5724 end,
        ready = function(id) return ready and id == 5724 end }
end
local visits = 0
a.Navigation = { Start = function(action)
    assert(action.id == 5724 and action.kind == "turnin" and action.place == a.quests[5724].finish)
    visits = visits + 1; return true
end, Map = function() error("precise Rahauro finish must not become a map-only action") end }
local tip = { shown = false }
function tip:SetOwner(owner) self.owner = owner end
function tip:IsOwned(owner) return self.owner == owner end
function tip:SetText(text) self.text = text end
function tip:AddLine(text) self.line = text end
function tip:Show() self.shown = true end
function tip:Hide() self.shown = false end
GameTooltip = tip
local function render(status)
    token, ready = {}, status == "READY"
    ui.questTreeRoot, ui.questTreeDungeon = nil, nil
    ui.dungeon, ui.quest = dungeon, 5724
    ui:Refresh()
    assert(ui.quest == 5724 and ui.renderedQuest == 5724 and ui.engine:State(5724).status == status)
end
local function control()
    local button = ui.turnin
    assert(button and button:IsShown() and button.enabled and button.scripts.OnClick and button.scripts.OnEnter,
        "actual READY finisher needs its compact action and destination hint")
    return button
end
local function hidden()
    assert(not ui.turnin or not ui.turnin:IsShown() or not ui.turnin.enabled,
        "a stale turn-in route must stay unavailable")
end
local function retireHint() ui:HideNavigationHint(); tip.shown, tip.text, tip.line = false, nil, nil end
render("READY")
local button = control()
button.scripts.OnEnter(button)
assert(tip.shown and tip.owner == button and tip.line and tip.line:find("Rahauro", 1, true),
    "the hint identifies the actual distinct finish NPC")
assert(visits == 0, "hover never starts navigation")
retireHint()

-- Action identity and current engine context are live proof, not a cached READY label.
for _, mode in ipairs({ "kind", "place", "engine", "context" }) do
    render("READY"); button = control()
    local enter, click = button.scripts.OnEnter, button.scripts.OnClick
    local action, engine = ui.action, ui.engine
    local kind, place, engineCurrent = action.kind, action.place, engine.Current
    if mode == "kind" then action.kind = "visit"
    elseif mode == "place" then action.place = a.quests[5724].start
    elseif mode == "engine" then engine.Current = function() return false end
    else token = {} end
    retireHint(); enter(button); click(button)
    assert(not tip.shown and visits == 0, "retired " .. mode .. " cannot show or dispatch the former finisher")
    action.kind, action.place, engine.Current = kind, place, engineCurrent
end

-- A finisher that becomes alternatives or a created object is no longer a direct route.
local quest = a.quests[5724]
local finish = quest.finish
for _, mode in ipairs({ "alternatives", "summon" }) do
    render("READY"); button = control()
    local enter, click = button.scripts.OnEnter, button.scripts.OnClick
    if mode == "alternatives" then quest.finish, quest.finishAlternatives = nil, { finish }
    else quest.finish = assert(a.quests[2201].finish); assert(quest.finish.summonItem) end
    retireHint(); enter(button); click(button)
    assert(not tip.shown and visits == 0, "former direct source cannot survive " .. mode)
    quest.finish, quest.finishAlternatives = finish, nil
end

-- Native tooltip publication can synchronously expose a newer quest state or locale provider.
for _, mode in ipairs({ "active", "localizer" }) do
    render("READY"); button = control(); retireHint()
    local setter, localize = tip.SetText, a.L
    local armed, fired = true, false
    tip.SetText = function(self, text)
        if armed then
            armed, fired = false, true
            if mode == "active" then render("ACTIVE")
            else a.L = function(key, ...) return localize(key, ...) end end
        end
        return setter(self, text)
    end
    button.scripts.OnEnter(button)
    tip.SetText, a.L = setter, localize
    assert(fired and not tip.shown and visits == 0,
        "retired native tooltip setter tail cannot show the old " .. mode .. " hint")
    if mode == "active" then hidden() end
end
-- A replaced physical control must not make the old hint fall back to another role.
render("READY"); button = control(); retireHint()
local originalTurnin, setter, fired = ui.turnin, tip.SetText, false
tip.SetText = function(self, text)
    if not fired then fired = true; ui.turnin = {} end
    return setter(self, text)
end
button.scripts.OnEnter(button)
tip.SetText, ui.turnin = setter, originalTurnin
assert(fired and not tip.shown and visits == 0,
    "replacing the turn-in control during native tooltip publication must retire the old hint")
render("READY"); button = control(); button.scripts.OnClick(button)
assert(visits == 1, "fresh current action recovers after retired hints without changing source facts")
print("READY turn-in retirement: PASS (actual finisher, action/context/source expiry and fired tooltip tails)")
