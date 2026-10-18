-- Actual catalogue workload and publication safety; not native frame timing.
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui = fixture.addon, fixture.addon.UI
local queue, counts = {}, {}
C_Timer = { After = function(delay, callback) queue[#queue + 1] = { delay, callback } end }
issecretvalue = function() return false end
for _, key in ipairs({ "Clean", "Read" }) do
    local original = addon[key]
    addon[key] = function(...) counts[key] = (counts[key] or 0) + 1; return original(...) end
end
local status = addon.DungeonStatus.Get
addon.DungeonStatus.Get = function(...) counts.status = (counts.status or 0) + 1; return status(...) end
local build = addon.QuestTree.Build
addon.QuestTree.Build = function(...)
    local tree, reason = build(...)
    if tree then
        local current = tree.current
        tree.current = function(...) counts.tree = (counts.tree or 0) + 1; return current(...) end
    end
    return tree, reason
end
local paint = addon.PaintDungeonArt
addon.PaintDungeonArt = function(...) counts.art = (counts.art or 0) + 1; return paint(...) end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
ui:Toggle()
local brd, dm
for _, dungeon in ipairs(addon.dungeons) do
    if dungeon.key == "brd" then brd = dungeon elseif dungeon.key == "dm" then dm = dungeon end
end
assert(brd and #brd.quests == 42 and dm)
ui.dungeon, ui.quest, ui.includeUnavailable = brd, nil, true
ui:Refresh()
local function rows()
    local result = {}
    for _, row in ipairs(ui.rows) do if row:IsShown() and row.questID then result[#result + 1] = row end end
    return result
end
assert(#rows() == 42, "the workload exercises every actual BRD target")
counts = {}
ui:RefreshQuests()
assert(#rows() == 42)
assert((counts.Clean or 0) < 120000 and (counts.Read or 0) < 100000,
    "row publication/cache ownership must not multiply every row's source proof by every later callback")
print("BRD42 row work: Clean=" .. counts.Clean .. " Read=" .. counts.Read)

counts = {}
ui:Refresh(nil, true)
assert(not counts.status and (counts.art or 0) <= 1, "item/title data refresh reuses catalogue status/art; only the selected overview may repaint")
assert(#rows() == 42)
local cardCounts = { text = 0, measure = 0, anchor = 0, style = 0 }
for _, result in ipairs(ui.catalogLanguageView.results) do
    for _, object in ipairs({ result.row, result.row.title, result.row.note }) do
        for method, counter in pairs({ SetText = "text", GetStringHeight = "measure", SetPoint = "anchor" }) do
            local original = object[method]
            object[method] = function(self, ...)
                cardCounts[counter] = cardCounts[counter] + 1
                return original(self, ...)
            end
        end
    end
end
local rowStyle = addon.Theme.StyleRow
addon.Theme.StyleRow = function(row, options)
    if options.kind == "dungeon" then cardCounts.style = cardCounts.style + 1 end
    return rowStyle(row, options)
end
counts = {}
ui:Refresh(nil, true)
assert(cardCounts.text == 0 and cardCounts.measure == 0 and cardCounts.anchor == 0 and cardCounts.style == 0 and not counts.status,
    "unchanged data arrivals perform no native catalogue painting or measurement")
local dmCard
for _, result in ipairs(ui.catalogLanguageView.results) do if result.dungeon == dm then dmCard = result.row end end
dmCard.scripts.OnClick()
assert(ui.dungeon == dm and cardCounts.style == 2 and cardCounts.text == 0 and cardCounts.anchor == 0 and not counts.status,
    "selecting another card only restyles old and new selection")
ui.frame:Hide(); ui.frame.scripts.OnHide()
cardCounts.style = 0
ui.frame:Show()
assert(not counts.status and cardCounts.text == 0 and cardCounts.measure == 0 and cardCounts.anchor == 0 and cardCounts.style == 0,
    "warm reopen retains validated catalogue geometry and character status")
ui.frame:Hide(); ui.frame.scripts.OnHide()
addon.InvalidateContext()
counts = {}
ui.frame:Show()
assert(counts.status == #addon.dungeons, "a hidden quest-state change prevents warm status reuse")
addon.db.locale = "enUS"
ui:Refresh()
addon.Language:Open(ui)
addon.Language:Preview(addon.Language.session, "ruRU")
assert(ui.catalogLanguageView.uiLanguage == "ruRU")
ui.frame:Hide(); ui.frame.scripts.OnHide()
counts, cardCounts.text = {}, 0
ui.frame:Show()
assert(ui.catalogLanguageView.uiLanguage == "enUS" and cardCounts.text > 0 and not counts.status,
    "reopening after a cancelled hover restores committed UI language without new aggregation")
ui.dungeon = brd
ui:Refresh(nil, true)
addon.Theme.StyleRow = rowStyle
local wc, dmRow
for _, result in ipairs(ui.catalogLanguageView.results) do
    if result.dungeon == dm then dmRow = result.row end
    if result.dungeon.key == "wc" then wc = result.dungeon end
end
assert(wc and dmRow)
local marks, replace = {}, true
addon.Theme.StyleRow = function(row, options)
    if options.kind == "dungeon" and row == dmRow and options.selected and replace then
        replace = false; ui.dungeon = wc; ui:Refresh(nil, true)
    end
    local value = rowStyle(row, options)
    if options.kind == "dungeon" then marks[row] = options.selected end
    return value
end
ui.dungeon = dm
ui:Refresh(nil, true)
assert(not replace and ui.dungeon == wc and marks[dmRow] == false,
    "a pending selection style cannot survive a newer dungeon selection")
addon.Theme.StyleRow = rowStyle
ui.dungeon = brd; ui:Refresh(nil, true)
ui.preparation = true
ui:Refresh(nil, true)
assert(ui.preparation, "data arrivals preserve the player's current preparation view")
ui.preparation = false
ui:Refresh(nil, true)
addon.InvalidateContext()
counts = {}
ui:Refresh(nil, true)
assert(counts.status == #addon.dungeons, "expired character evidence requires a complete fresh catalogue")

local visible = rows()
local first, other = visible[1], visible[2]
local definition = addon.quests[other.questID]
local factions, native, armed = definition.factions, first.Show, true
first.Show = function(self, ...)
    if armed then armed = false; definition.factions = { "Horde" } end
    return native(self, ...)
end
ui:RefreshQuests()
assert(not armed)
for _, row in ipairs(ui.rows) do assert(not row:IsShown(), "a changed sibling source retires the entire staged publication") end
definition.factions, first.Show = factions, native
ui:RefreshQuests()
assert(#rows() == 42)
local saved = rows()[2]
local prior = addon.quests[saved.questID].factions
addon.quests[saved.questID].factions = { "Alliance", "Horde" }
saved.scripts.OnClick()
assert(ui.quest == nil, "retained row callbacks still validate their own source")
addon.quests[saved.questID].factions = prior
ui:RefreshQuests()

local cacheWatch, cacheOwner, mutate = addon.RewardCache.Watch, nil, false
local firstID = brd.quests[1]
addon.RewardCache.Watch = function(_, _, ownerCurrent)
    cacheOwner = ownerCurrent
    if mutate then brd.quests[1] = brd.quests[2] end
end
ui:RefreshQuests()
assert(cacheOwner and cacheOwner())
brd.quests[1] = brd.quests[2]
assert(not cacheOwner(), "a same-length target edit revokes the deferred hydration view")
brd.quests[1] = firstID
mutate = true
ui:RefreshQuests()
for _, row in ipairs(ui.rows) do assert(not row:IsShown(), "late registration source loss retires published rows") end
brd.quests[1], addon.RewardCache.Watch = firstID, cacheWatch
ui:RefreshQuests()

first = rows()[1]
native, armed = first.Show, true
first.Show = function(self, ...)
    if armed then armed = false; ui.dungeon = dm; ui:RefreshQuests() end
    return native(self, ...)
end
ui:RefreshQuests()
assert(not armed and ui.dungeon == dm and #rows() > 0)
local members = {}; for _, id in ipairs(dm.quests) do members[id] = true end
for _, row in ipairs(rows()) do assert(members[row.questID], "late BRD publication cannot hide or replace the newer dungeon") end
first.Show = native

ui.dungeon, ui.quest, ui.questTreeDungeon, ui.questTreeRoot = brd, 4241, brd, 4241
counts = {}
ui:RefreshQuests()
assert(#rows() == 49 and (counts.tree or 0) < 30, "expanded BRD tree is proved at publication boundaries, not every native setter")
local child
for _, row in ipairs(rows()) do if row.questTreeNode and row.questID ~= 4241 then child = row; break end end
assert(child)
local savedClick, required = child.scripts.OnClick, addon.quests[4241].requires
addon.quests[4241].requires = { { ids = { 65 } } }
savedClick()
assert(ui.quest == 4241, "retained expanded-tree callbacks still prove the complete relation source")
addon.quests[4241].requires = required
ui:RefreshQuests()
child = rows()[1]
local nativeText, savedSource = child.title.SetText, addon.quests[4241].requires
child.title.SetText = function() error("native title failure") end
local success = pcall(ui.RefreshQuests, ui)
assert(not success)
child.title.SetText = nativeText
addon.quests[4241].requires = { { ids = { 65 } } }
for _, row in ipairs(ui.rows) do assert(not row:IsShown(), "native failure retires staged rows") end
assert(not child.questListCurrent(), "exception restores full retained tree validation")
addon.quests[4241].requires = savedSource
ui:RefreshQuests()

print("BRD UI workload: PASS (42 targets, bounded proofs, data reuse, invalidation and reentrant publication)")
