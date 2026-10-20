-- Existing catalogue portrait references and controlled selected-log display values.
-- No source facts or portrait provider implementation is replaced.
local cases = 0
local function check(name, test)
    if arg and arg[1] and arg[1] ~= name then return end
    test()
    cases = cases + 1
    print("PASS " .. name)
end
local function fixture(native, unavailable)
    local f = assert(loadfile("tests/client_ui.lua"))("fixture")
    local a, ui = f.addon, f.addon.UI
    local selected, routes, mapCalls, portraitReads = 166, {}, 0, 0
    local controlled = { [166] = 610166, [214] = 610214 }
    issecretvalue = function() return false end
    GetLocale = function() return "enUS" end
    UnitLevel = function() return 60 end
    UnitClass = function() return "Mage", "MAGE", 8 end
    UnitFactionGroup = function() return "Alliance" end
    C_Timer = { After = function() end }
    C_QuestLog.IsOnQuest = function(id) return native and controlled[id] ~= nil end
    C_QuestLog.ReadyForTurnIn = function() return false end
    C_QuestLog.IsQuestFlaggedCompleted = function() return false end
    C_QuestLog.GetTitleForQuestID = function(id) return a.quests[id] and a.quests[id].name end
    C_QuestLog.GetSelectedQuest = function() return selected end
    C_QuestLog.GetLogIndexForQuestID = function(id)
        if native and controlled[id] then return id == 166 and 1 or 2 end
    end
    C_QuestLog.GetQuestLogPortraitGiver = function(index, ...)
        assert(native and select("#", ...) == 0)
        assert(index == (selected == 166 and 1 or 2), "native portrait uses the selected quest's explicit log index")
        portraitReads = portraitReads + 1
        return controlled[selected], "Controlled native prose", "Controlled native speaker"
    end
    C_QuestLog.SetSelectedQuest = function() error("portrait rendering must not select native quests") end
    HaveQuestRewardData = function() return true end
    GetNumQuestLogRewards = function() return 0 end
    GetNumQuestLogChoices = function() return 0 end
    GetQuestLogRewardMoney = function() return 0 end
    C_Item = { GetItemNameByID = function(id) return "Item " .. id end,
        GetItemIconByID = function() return 134400 end, GetItemCount = function() return 0 end,
        IsItemDataCachedByID = function() return true end }
    if unavailable then
        SetPortraitTextureFromCreatureDisplayID = nil
    else
        SetPortraitTextureFromCreatureDisplayID = function(texture, id) texture:SetTexture("display:" .. id) end
    end
    a.DialoguePortrait, a.DialogueTurnInPortrait = nil, nil
    if not native then a.QuestPortrait = nil end
    a.Navigation.Start = function(action) routes[#routes + 1] = action; return true end
    a.Navigation.Map = function() mapCalls = mapCalls + 1; return true end
    f.eventFrame.scripts.OnEvent(f.eventFrame, "ADDON_LOADED", "DungeonPro")
    ui:Toggle()
    a.db.locale, ui.includeUnavailable, ui.range = "enUS", true, false
    for _, d in ipairs(a.dungeons) do if d.key == "dm" then ui.dungeon = d end end
    ui.quest = 166
    ui:Refresh()
    if not native then assert(ui:SetDetailTab("sources")) end
    local function draw(id)
        selected = id
        assert(ui:InspectQuest(id, true))
        assert(ui:SetDetailTab(native and "quest" or "sources"))
        assert(ui.quest == id and ui.renderedQuest == id)
    end
    local function expected(id)
        return native and controlled[id] or a.quests[id].start.creatureDisplayID
    end
    local function caption(id)
        return native and a.L("QUEST_PORTRAIT") or a.L("GIVER_REFERENCE_PORTRAIT", a.quests[id].start.name)
    end
    local function hasCaption(id)
        for _, line in ipairs(ui.details) do
            if line:IsShown() and line.text == caption(id) then return true end
        end
        return false
    end
    local function noEffects() assert(#routes == 0 and mapCalls == 0, "portrait cleanup cannot guide or open a map") end
    local function visit(id)
        local before = #routes
        local contact=assert(ui.detailContactRows[1]);local binding=assert(contact.detailContactBinding)
        assert(contact:IsShown()and contact.enabled and contact.scripts.OnClick and binding.current()and binding.endpoint==a.quests[id].start)
        assert(not ui.giver:IsShown()and not ui.giver.enabled and ui.giver.scripts.OnClick==nil)
        local click=contact.scripts.OnClick;click()
        assert(#routes == before + 1 and routes[#routes].id == id and routes[#routes].place == a.quests[id].start,
            "fresh explicit pickup keeps its actual selected source")
        click();assert(#routes==before+1,"retired portrait-era contact click stays inert")
    end
    return a, ui, draw, expected, hasCaption, noEffects, visit, function() return portraitReads end
end
for _,native in ipairs({false,true}) do
    for _,method in ipairs({"Hide","Show"}) do
        for _,phase in ipairs({"before","after"}) do
            for _,target in ipairs({214,2933}) do
                local name = (native and "native" or "source") .. "-" .. method .. "-" .. phase .. "-" .. target
                check(name, function()
                    local a, ui, draw, expected, hasCaption, noEffects, visit, reads = fixture(native)
                    local field = native and "portrait" or "giverPortrait"
                    local image = assert(ui[field], "actual portrait must exist before the tested native boundary")
                    assert(image:IsShown() and image.texture == "display:" .. expected(166) and hasCaption(166))
                    if native then assert(reads() > 0, "actual Client selected-log reader must run") end
                    local setter, fired, completed = image[method], false, false
                    local function replace()
                        fired = true
                        draw(target)
                        completed = true
                        if target == 214 then
                            assert(image:IsShown() and image.texture == "display:" .. expected(214) and hasCaption(214),
                                "replacement must positively paint its own current portrait and caption")
                        else
                            assert(not image:IsShown(), "item/alternative source must positively retire the former portrait")
                        end
                    end
                    image[method] = function(self, ...)
                        local hit = not fired
                        if hit and phase == "before" then replace() end
                        local result = setter(self, ...)
                        if hit and phase == "after" then replace() end
                        return result
                    end
                    ui:RefreshDetail()
                    image[method] = setter
                    assert(fired and completed and ui.quest == target and ui.renderedQuest == target)
                    noEffects()
                    if target == 214 then
                        assert(image:IsShown() and image.texture == "display:" .. expected(214) and hasCaption(214),
                            "retired initial cleanup or publication cannot hide/clear/replace the newer portrait")
                        visit(214)
                    else
                        assert(not image:IsShown() and image.texture == nil,
                            "retired publication must not revive an image over a source without a portrait")
                    end
                end)
            end
        end
    end
end
for _,native in ipairs({false,true}) do
    check((native and "native" or "source") .. "-unavailable-setter", function()
        local a, ui, draw, expected, hasCaption, noEffects, visit = fixture(native, true)
        local image = ui[native and "portrait" or "giverPortrait"]
        assert(not image or not image:IsShown(), "optional missing native setter does not manufacture an image")
        draw(214)
        image = ui[native and "portrait" or "giverPortrait"]
        assert(not image or not image:IsShown())
        noEffects()
        visit(214)
    end)
end
check("source-retired-owner-gc", function()
    local a, ui, draw, expected, hasCaption, noEffects = fixture(false)
    local image = assert(ui.giverPortrait)
    local registry = assert(image.questListWrites)
    local record = assert(registry.visibility)
    assert(record.current(), "current owned portrait publication must have a usable proof")
    local weak = setmetatable({ui.engine}, { __mode = "v" })
    draw(214)
    ui.frame:Hide(); ui.frame.scripts.OnHide(); ui.frame:Show(); ui:Refresh()
    collectgarbage("collect"); collectgarbage("collect")
    assert(weak[1] == nil and image.questListWrites == registry and not record.current(),
        "retired portrait records must release their old engine without dropping the physical writer registry")
    local clean, reads = a.Clean, 0
    a.Clean = function(...) reads = reads + 1; return clean(...) end
    assert(not record.current() and reads == 0, "released image owner cannot call former source providers")
    a.Clean = clean
    noEffects()
end)
print("Portrait initial cleanup/publication: PASS " .. cases .. " controlled native and actual source cases; no native-client proof")
