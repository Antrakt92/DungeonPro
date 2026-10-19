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
    C_QuestLog.IsOnQuest = function(id) return id==155 end
    C_QuestLog.ReadyForTurnIn = function(id) return id==155 end
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
local failures,passed=0,0
local function samePoint(a,b)
 for k,v in pairs(a or {})do if not b or b[k]~=v then return false end end
 for k,v in pairs(b or {})do if not a or a[k]~=v then return false end end
 return true
end
for _,physical in ipairs({false,true})do for _,stage in ipairs({1,2})do
 for _,method in ipairs({"SetPoint","ClearAllPoints","SetSize"})do for _,phase in ipairs({"before","after"})do
 local ok,err=pcall(function()
  local a,ui,select,dungeons,noEffects,imageFor,currentMap,manual,opens=fixture()
  local art=ui.overviewArt;local native,fired,calls=art[method],false,0;local newest
  art[method]=function(self,...)
   calls=calls+1;local hit=not fired and calls==stage
   local function replace()
    fired=true;if physical then ui.overviewArt=nil end;select("rfc")
    local target=ui.overviewArt
    newest={art=target,point=target.point,width=target.width,height=target.height,binding=ui.overviewMapBinding}
    assert(imageFor("rfc"));currentMap("rfc",newest.binding)
   end
   if hit and phase=="before"then replace()end
   local result=native(self,...)
   if hit and phase=="after"then replace()end
   return result
  end
  ui:RefreshDetail();art[method]=native
  assert(fired and imageFor("rfc")and ui.dungeon==dungeons.rfc and ui.quest==nil)
  currentMap("rfc",newest.binding);noEffects()
  local target=ui.overviewArt
  assert(target==newest.art and samePoint(target.point,newest.point)and target.width==newest.width and target.height==newest.height,
   "late artwork native tail overwrote newer RFC physical geometry")
  assert(not physical or target~=art)
  manual("rfc")
 end)
 print(ok and "PASS"or"FAIL",physical and "replacement"or"samepool",stage,method,phase,err or "")
 if ok then passed=passed+1 else failures=failures+1 end
end end end end
local ok,err=pcall(function()
 local a,ui,select,dungeons,noEffects,imageFor,currentMap,manual,opens=fixture()
 local art=ui.overviewArt;local writes=assert(art.questListWrites)
 local point,size=assert(writes.SetPoint),assert(writes.SetSize)
 assert(point.current()and size.current())
 local weak=setmetatable({ui.engine},{__mode="v"})
 select("rfc");ui.frame:Hide();ui.frame.scripts.OnHide();ui.frame:Show();ui:Refresh()
 collectgarbage("collect");collectgarbage("collect")
 assert(weak[1]==nil and art.questListWrites==writes)
 local read,clean,reads=a.Read,a.Clean,0
 a.Read=function(...)reads=reads+1;return read(...)end
 a.Clean=function(...)reads=reads+1;return clean(...)end
 assert(not point.current()and not size.current()and reads==0)
 a.Read,a.Clean=read,clean
 assert(imageFor("rfc"));currentMap("rfc");manual("rfc");noEffects()
end)
print(ok and "PASS"or"FAIL","geometry pooled record release GC",err or "")
if ok then passed=passed+1 else failures=failures+1 end
print("Art geometry lifecycle: "..passed.." PASS / "..failures.." FAIL")
assert(failures==0,"art geometry failures "..failures)
