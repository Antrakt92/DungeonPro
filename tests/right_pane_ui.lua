-- Modeled readability and ownership; native layout still requires client acceptance.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui = fixture.addon, fixture.addon.UI
C_Timer = { After = function() end }
UnitLevel = function() return 60 end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
ui:Toggle(); addon.db.locale = "enUS"
local q = { id = 990099, name = "Right pane", level = 16, minLevel = 9, requirementsKnown = true,
    start = { npcID = 1, name = "Unknown giver" } }
addon.quests[q.id] = q
local function render() ui.quest = q.id; ui:Refresh() end
local function fields(text)
    local result = {}
    for _, field in ipairs(ui.details) do if field:IsShown() and field.text == text then result[#result + 1] = field end end
    return result
end
render()
assert(ui.detailTab=="quest", "critical unknown-source warnings stay in the default Quest view")
assert(not ui.giver.caption and ui.giver.navigationGold and #ui.giver.footerIconParts == 3, "giver action is a high-contrast compact navigation icon")
assert(ui.giver.width == 24 and ui.giver.height == 24 and ui.giver:IsShown() and not ui.giver.enabled)
local warnings = fields(addon.L("GIVER_LOCATION_UNKNOWN"))
assert(#warnings == 1 and warnings[1].detailStyle == "warning", "unknown location is an explicit red warning")
local tip = {}
function tip:SetOwner(owner) self.owner = owner end
function tip:IsOwned(owner) return self.owner == owner end
function tip:SetText(text) self.text = text end
function tip:AddLine(text) self.body = text end
function tip:Show() self.shown = true end
function tip:Hide() self.shown = false end
GameTooltip = tip
ui.giver.scripts.OnEnter()
assert(tip.shown and tip.body == addon.L("GIVER_LOCATION_UNKNOWN"), "disabled navigation explains its reason on hover")
local count = 0
addon.Navigation = { Start = function() count = count + 1; return true end }
ui.giver.scripts.OnClick(); assert(count == 0)
q.start.mapID, q.start.x, q.start.y = 1, 20, 30
render(); assert(ui.giver.enabled and #fields(addon.L("GIVER_LOCATION_UNKNOWN")) == 0)
ui.giver.scripts.OnClick(); assert(count == 1)
q.start = { itemID = 801, name = "Starter" }
addon.ItemName = function() return "Starter" end
addon.ItemIcon = function() return 134400 end
addon.CarriedItemCount = function() return 0 end
render()
assert(#fields(addon.L("DETAIL_START_ITEM")) == 0 and #fields(addon.L("START_ITEM_LOCATION_UNKNOWN")) == 1)
assert(#fields(addon.L("GIVER_LOCATION_UNKNOWN")) == 0 and not ui.giver:IsShown())
assert(not ui.referenceToggle or not ui.referenceToggle:IsShown(), "empty acquisition drawer is absent")
assert(#fields(addon.L("ITEM_STARTER", "Starter")) == 1 and #fields(addon.L("ITEM_CARRIED", 0)) == 1)
addon.CachedQuestRewards, addon.DialogueRewards = nil, nil
local data = { items = {}, choices = {}, money = 12345 }
addon.QuestRewards = function() return data end
local function money(text) return #fields(addon.L("REWARD_MONEY") .. ": " .. text) == 1 end
GetCoinTextureString = nil
C_CurrencyInfo = { GetCoinTextureString = function(amount) assert(amount == 12345); return "NATIVE COINS" end }
render(); assert(money("NATIVE COINS"), "Forever namespace formatter renders the known money")
C_CurrencyInfo = true; render(); assert(money(addon.L("MONEY_COPPER", 12345)))
C_CurrencyInfo = { GetCoinTextureString = function() error("unavailable") end }
GetCoinTextureString = function() return "LEGACY COINS" end
render(); assert(money("LEGACY COINS"))
GetCoinTextureString = nil
C_CurrencyInfo.GetCoinTextureString = function() addon.db.locale = "ruRU"; return "STALE COINS" end
addon.db.locale = "enUS"; render()
assert(not money("STALE COINS"), "formatter locale reentry cannot publish stale reward text")
addon.db.locale = "enUS"
C_CurrencyInfo = nil; data.money = 12345.5; render()
assert(not money(addon.L("MONEY_COPPER", 12345.5)), "fractional copper cannot be rounded into an invented reward")
print("Right pane modeled checks passed (no native layout validation)")
