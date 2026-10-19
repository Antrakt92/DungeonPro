-- Existing catalogue artwork; controlled native widget tails, no native-client pixels or map coverage claim.
local total = 0
local function check(name, test)
    if arg and arg[1] and arg[1] ~= name then return end
    test(); total = total + 1; print("PASS " .. name)
end
local function fixture()
    local f = assert(loadfile("tests/client_ui.lua"))("fixture")
    local a, ui = f.addon, f.addon.UI
-- Controlled component opt-in; not native map availability.
    a.experimentalDungeonMaps = true
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
for _,phase in ipairs({"before","after"})do
 for _,kind in ipairs({"overview","quest"})do
 check("finalShow-"..phase.."-"..kind,function()
  local a,ui,select,dungeons,noEffects,imageFor,currentMap,manual,opens=fixture()
  local art=ui.overviewArt;local native,fired=art.Show,false;local newest;local calls=0
  art.Show=function(self,...)
   calls=calls+1;local hit=not fired and calls==1
   local function replace()
    fired=true
    if kind=="overview"then select("rfc");newest=ui.overviewMapBinding
    else assert(ui:InspectQuest(166,true));assert(ui:SetDetailTab("story"))end
   end
   if hit and phase=="before"then replace()end
   local result=native(self,...)
   if hit and phase=="after"then replace()end
   return result
  end
  ui:RefreshDetail();art.Show=native
  assert(fired and opens()==0)
  if kind=="overview"then assert(imageFor("rfc"));currentMap("rfc",newest);manual("rfc")
  else assert(ui.quest==166 and ui.detailTab=="story"and not art:IsShown()and ui.overviewMapBinding==nil)end
  noEffects()
 end)
 end
end
print("Independent final owned art Show tails: PASS "..total)

local a={}
assert(loadfile("Core/Namespace.lua"))("DungeonPro",a)
assert(loadfile("Core/Client.lua"))("DungeonPro",a)
assert(loadfile("Core/DungeonArt.lua"))("DungeonPro",a)
local function canvas()
 return {shows=0,SetTexture=function(self,v)self.texture=v;return true end,
 SetTexCoord=function(self,...)self.coords={...}end,
 Show=function(self)self.shows=self.shows+1;self.shown=true end,
 Hide=function(self)self.shown=false end}
end
local dungeon={instanceID=36,art={fileID=131833,gameMapID=36}}
local function pure(name,fn)
 issecretvalue=function()return false end
 C_EncounterJournal,EJ_GetInstanceInfo,GetLFDChoiceOrder,GetLFGDungeonInfo=nil,nil,nil,nil
 fn();total=total+1;print("PASS "..name)
end
pure("omitted and explicit nil preserve legacy Show",function()
 for i=1,2 do local t=canvas();local ok,k
  if i==1 then ok,k=a.PaintDungeonArt(t,dungeon,"overview")else ok,k=a.PaintDungeonArt(t,dungeon,"overview",nil)end
  assert(ok and k=="art"and t.shows==1 and t.texture==131833)
 end
end)
pure("invalid optional callbacks never fall back to raw Show",function()
 for _,v in ipairs({false,true,1,"show",{}})do
  local t=canvas();local ok,k,ratio=a.PaintDungeonArt(t,dungeon,"overview",v)
  assert(ok==false and k==nil and ratio==nil and t.shows==0 and t.texture==nil)
 end
end)
pure("restricted callback or failed classification never reaches paint",function()
 local fn=function()error("restricted callback invoked")end
 for _,mode in ipairs({"restricted","throw"})do
  issecretvalue=function(v)if v==fn then if mode=="throw"then error("classifier unavailable")end;return true end;return false end
  local t=canvas();assert(a.PaintDungeonArt(t,dungeon,"overview",fn)==false and t.shows==0 and t.texture==nil)
 end
end)
pure("rejected callback results have no direct fallback or positive kind",function()
 for _,mode in ipairs({"false","nil","string","number","throw"})do
  local t=canvas();local calls=0
  local ok,k,ratio=a.PaintDungeonArt(t,dungeon,"overview",function(texture)
   assert(texture==t);calls=calls+1
   if mode=="throw"then error("unavailable")elseif mode=="false"then return false elseif mode=="string"then return "true"elseif mode=="number"then return 1 end
  end)
  assert(ok==false and k==nil and ratio==nil and calls==1 and t.shows==0)
 end
end)
pure("accepted owned writer runs exactly once",function()
 local t=canvas();local calls=0
 local ok,k=a.PaintDungeonArt(t,dungeon,"overview",function(texture)assert(texture==t);calls=calls+1;texture:Show();return true end)
 assert(ok and k=="art"and calls==1 and t.shows==1 and t.texture==131833 and t.coords[1]==0)
end)
pure("rejected writer cannot abandon a newer paint",function()
 for _,mode in ipairs({"false","throw"})do
  local t=canvas()
  local ok,k=a.PaintDungeonArt(t,dungeon,"overview",function(texture)
   assert(a.PaintDungeonArt(texture,{},"overview"))
   if mode=="throw"then error("old writer retired")end;return false
  end)
  assert(ok==false and k==nil and t.texture=="Interface\\Icons\\INV_Misc_Map_01"and t.shown and t.shows==1)
 end
end)
pure("newer token during owned Show remains winner",function()
 local t=canvas();local ok,k=a.PaintDungeonArt(t,dungeon,"overview",function(texture)
  assert(a.PaintDungeonArt(texture,{},"overview"));return true
 end)
 assert(ok==false and k==nil and t.texture=="Interface\\Icons\\INV_Misc_Map_01"and t.shown and t.shows==1)
end)
pure("checker replacement during callback classification rejects supplied owner",function()
 local fn=function()error("must not run")end
 issecretvalue=function(v)if v==fn then issecretvalue=function()return false end end;return false end
 local t=canvas();assert(a.PaintDungeonArt(t,dungeon,"overview",fn)==false and t.shows==0 and t.texture==nil)
end)
print("Owned art painter checks passed: "..total)

pure("restricted callback acknowledgement cannot authorize success",function()
 local result={};issecretvalue=function(v)return v==result end
 local t=canvas();local ok,k=a.PaintDungeonArt(t,dungeon,"overview",function()return result end)
 assert(ok==false and k==nil and t.shows==0)
end)
for _,phase in ipairs({"before","after"})do
 check("painter-identity-replacement-"..phase,function()
  local a,ui,select,dungeons,noEffects=fixture()
  local art,native,fired=ui.overviewArt,ui.overviewArt.Show,false
  local painter=a.PaintDungeonArt
  art.Show=function(self,...)
   local hit=not fired
   local function replace()
    fired=true;a.PaintDungeonArt=function(...)return painter(...)end
    assert(ui:InspectQuest(166,true));assert(ui:SetDetailTab("story"))
   end
   if hit and phase=="before"then replace()end
   local result=native(self,...)
   if hit and phase=="after"then replace()end
   return result
  end
  ui:RefreshDetail();art.Show=native
  assert(fired and ui.quest==166 and ui.detailTab=="story"and not art:IsShown()and ui.overviewMapBinding==nil)
  a.PaintDungeonArt=painter
  noEffects()
 end)
end
print("Owned art painter FINAL checks passed: "..total)

for _,optional in ipairs({false,true})do
 pure("first classifier newer paint wins "..tostring(optional),function()
  local t=canvas();local armed=true;local nested=false
  local newer={art={fileID=7963781,gameMapID=3065}}
  issecretvalue=function()
   if armed then armed=false;assert(a.PaintDungeonArt(t,newer,"overview"));nested=true end
   return false
  end
  local writer=optional and function(texture)texture:Show();return true end or nil
  local ok,k=a.PaintDungeonArt(t,dungeon,"overview",writer)
  assert(nested and not armed and ok==false and k==nil and t.texture==7963781 and t.shown and t.shows==1,
   "earlier invocation cannot assign ownership after a callback published a newer paint")
 end)
end
pure("nil callback classification cannot adopt replacement checker",function()
 local t=canvas();local armed=true
 issecretvalue=function()
  if armed then armed=false;issecretvalue=function()return false end end
  return false
 end
 local ok,k=a.PaintDungeonArt(t,dungeon,"overview")
 assert(not armed and ok==false and k==nil and t.texture==nil and t.shows==0)
end)
print("Owned art painter classification checks passed: "..total)

pure("checker replacement during callback Clean rejects supplied owner",function()
 local fn=function()error("retired owner must not run")end
 local calls=0
 issecretvalue=function(v)
  if v==fn then calls=calls+1;if calls==2 then issecretvalue=function()return false end end end
  return false
 end
 local t=canvas();local ok,k=a.PaintDungeonArt(t,dungeon,"overview",fn)
 assert(calls==2 and ok==false and k==nil and t.texture==nil and t.shows==0)
end)
print("Owned art painter FINAL repaired checks passed: "..total)
