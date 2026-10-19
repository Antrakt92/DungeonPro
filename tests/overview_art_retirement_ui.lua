-- Existing catalogue artwork; controlled native widget tails, no native-client pixels or map coverage claim.
local total = 0
local function check(name, test)
    if arg and arg[1] and arg[1] ~= name then return end
    test(); total = total + 1; print("PASS " .. name)
end
local function fixture()
    local f = assert(loadfile("tests/client_ui.lua"))("fixture")
    local a, ui = f.addon, f.addon.UI
    local pins, routes, selections, accepts, opens, opened = 0, 0, 0, 0, 0
    issecretvalue = function() return false end
    GetLocale = function() return "enUS" end
    UnitLevel = function() return 60 end
    UnitClass = function() return "Mage", "MAGE", 8 end
    UnitFactionGroup = function() return "Alliance" end
    C_Timer = { After = function() end }
    C_QuestLog.IsOnQuest = function() return false end
    C_QuestLog.ReadyForTurnIn = function() return false end
    C_QuestLog.GetTitleForQuestID = function(id) return a.quests[id] and a.quests[id].name end
    C_QuestLog.SetSelectedQuest = function() selections = selections + 1 end
    AcceptQuest = function() accepts = accepts + 1 end
    -- Missing native map-art APIs are modeled honestly; catalogue artwork is not a UiMap join.
    C_EncounterJournal, EJ_GetInstanceInfo = nil, nil
    C_Map.SetUserWaypoint = function() pins = pins + 1 end
    local navigation = a.Navigation.Start
    a.Navigation.Start = function(...) routes = routes + 1; return navigation(...) end
    local opener = ui.OpenDungeonMap
    ui.OpenDungeonMap = function(self, dungeon, ...)
        opens, opened = opens + 1, dungeon
        return opener(self, dungeon, ...)
    end
    local painter, artProvider = a.PaintDungeonArt, a.DungeonArt
    f.eventFrame.scripts.OnEvent(f.eventFrame, "ADDON_LOADED", "DungeonPro")
    ui:Toggle(); a.db.locale = "enUS"; ui.range, ui.includeUnavailable = false, true; ui:Refresh()
    local dungeons = {}
    for _, d in ipairs(a.dungeons) do dungeons[d.key] = d end
    local function select(key)
        for _, card in ipairs(ui.cards) do
            if card:IsShown() and card.entranceDungeon == dungeons[key] then
                assert(card.scripts.OnClick); card.scripts.OnClick(card)
                assert(ui.dungeon == dungeons[key] and ui.quest == nil)
                return
            end
        end
        error("actual ordinary dungeon card missing: " .. key)
    end
    local function noEffects()
        assert(routes == 0 and pins == 0 and selections == 0 and accepts == 0,
            "overview artwork cannot route, select or accept quests")
        assert(a.PaintDungeonArt == painter and a.DungeonArt == artProvider, "real artwork providers stay unchanged")
    end
    local function imageFor(key)
        return ui.overviewArt and ui.overviewArt:IsShown() and ui.overviewArt.texture == dungeons[key].art.fileID
    end
    local function currentMap(key, expectedBinding)
        local binding, control = ui.overviewMapBinding, ui.overviewMapControl
        assert(binding and (not expectedBinding or binding == expectedBinding) and binding.owner and binding.owner(),
            "newest map binding must retain its exact live overview owner")
        assert(ui.dungeon == dungeons[key] and ui.quest == nil and control:IsShown() and control.enabled and control.scripts.OnClick)
        return control.scripts.OnClick
    end
    local function manual(key)
        local click = currentMap(key); local before = opens
        click()
        assert(opens == before + 1 and opened == dungeons[key], "explicit map click opens exactly the selected real dungeon")
        assert(ui.dungeonMapState and ui.dungeonMapState.dungeon == dungeons[key] and ui.dungeonMapState.model == nil)
        assert(ui.dungeonMap and ui.dungeonMap:IsShown() and ui.dungeonMap.message.text == a.L("DUNGEON_MAP_UNAVAILABLE"),
            "missing native map-art data stays unavailable, without a guessed map or artwork-based join")
        noEffects()
    end
    select("dm")
    assert(imageFor("dm") and opens == 0)
    currentMap("dm")
    return a, ui, select, dungeons, noEffects, imageFor, currentMap, manual, function() return opens end
end
for _,phase in ipairs({"before","after"}) do
    check("new-overview-" .. phase, function()
        local a, ui, select, dungeons, noEffects, imageFor, currentMap, manual, opens = fixture()
        local image = assert(ui.overviewArt); local hide, fired, newest = image.Hide, false
        image.Hide = function(self, ...)
            local hit = not fired
            local function replace()
                fired = true; select("rfc")
                assert(imageFor("rfc"), "replacement positively paints its nonnil actual RFC catalogue asset")
                currentMap("rfc"); newest = ui.overviewMapBinding
            end
            if hit and phase == "before" then replace() end
            local result = hide(self, ...)
            if hit and phase == "after" then replace() end
            return result
        end
        ui:RefreshDetail(); image.Hide = hide
        assert(fired and ui.dungeon == dungeons.rfc and ui.quest == nil and opens() == 0)
        assert(imageFor("rfc"), "retired initial Hide must preserve current nonnil artwork visibility")
        currentMap("rfc", newest)
        noEffects(); manual("rfc")
    end)
    check("new-quest-no-overview-" .. phase, function()
        local a, ui, select, dungeons, noEffects, imageFor, currentMap, manual, opens = fixture()
        local image, control = ui.overviewArt, ui.overviewMapControl
        local oldClick = control.scripts.OnClick
        local hide, fired = image.Hide, false
        image.Hide = function(self, ...)
            local hit = not fired
            local function replace()
                fired = true; assert(ui:InspectQuest(166, true)); assert(ui:SetDetailTab("sources"))
                assert(ui.quest == 166 and ui.renderedQuest == 166 and not image:IsShown())
            end
            if hit and phase == "before" then replace() end
            local result = hide(self, ...)
            if hit and phase == "after" then replace() end
            return result
        end
        ui:RefreshDetail(); image.Hide = hide
        assert(fired and ui.quest == 166 and ui.detailTab == "sources" and not image:IsShown())
        assert(not control:IsShown() and not control.enabled and ui.overviewMapBinding == nil)
        oldClick(); assert(opens() == 0); noEffects()
        -- A hidden region may retain an old asset; this case claims visibility/action retirement only.
    end)
    check("physical-art-replacement-" .. phase, function()
        local a, ui, select, dungeons, noEffects, imageFor, currentMap, manual, opens = fixture()
        local old = ui.overviewArt; local hide, fired, newest, binding = old.Hide, false
        old.Hide = function(self, ...)
            local hit = not fired
            local function replace()
                fired = true; ui.overviewArt = nil; select("rfc")
                newest, binding = assert(ui.overviewArt), assert(ui.overviewMapBinding)
                assert(newest ~= old and imageFor("rfc")); currentMap("rfc", binding)
            end
            if hit and phase == "before" then replace() end
            local result = hide(self, ...)
            if hit and phase == "after" then replace() end
            return result
        end
        ui:RefreshDetail(); old.Hide = hide
        assert(fired and ui.overviewArt == newest and imageFor("rfc") and opens() == 0)
        currentMap("rfc", binding); noEffects(); manual("rfc")
    end)
end
check("normal-missing-native-map-capabilities", function()
    local a, ui, select, dungeons, noEffects, imageFor, currentMap, manual, opens = fixture()
    select("rfc")
    assert(imageFor("rfc") and opens() == 0)
    currentMap("rfc"); noEffects(); manual("rfc")
end)
-- Post-fix owned-publication regression, not a second independently claimed baseline GC defect.
check("retired-art-visibility-owner-gc", function()
    local a, ui, select, dungeons, noEffects, imageFor, currentMap, manual, opens = fixture()
    local image = ui.overviewArt; local registry = assert(image.questListWrites)
    local record = assert(registry.visibility); assert(record.current())
    local weak = setmetatable({ui.engine}, { __mode = "v" })
    select("rfc")
    ui.frame:Hide(); ui.frame.scripts.OnHide(); ui.frame:Show(); ui:Refresh()
    collectgarbage("collect"); collectgarbage("collect")
    assert(weak[1] == nil and image.questListWrites == registry and not record.current(),
        "obsolete art visibility records release their former engine while keeping the physical registry")
    local read, reads = a.Read, 0
    a.Read = function(...) reads = reads + 1; return read(...) end
    assert(not record.current() and reads == 0, "retired overview visibility proof cannot call old providers")
    a.Read = read
    assert(opens() == 0 and imageFor("rfc")); currentMap("rfc"); noEffects(); manual("rfc")
end)
print("Overview art lifecycle: PASS " .. total .. " ordinary artwork/map/visibility/retirement cases; no native pixels or runtime map coverage claimed")
