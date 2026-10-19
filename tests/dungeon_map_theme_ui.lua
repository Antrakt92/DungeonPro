-- Actual theme behavior on custom map captions; not native pixel/font acceptance.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,ui=f.addon,f.addon.UI
function f.methods:IsEnabled()return self.enabled~=false end
function f.methods:SetTextColor(...)self.textColor={...}end
function f.methods:SetAlpha(value)self.alpha=value end
local create=CreateFrame
CreateFrame=function(...)
 local button=create(...)
 if (...)=="Button"then
  button.Left=button:CreateTexture();button.Middle=button:CreateTexture();button.Right=button:CreateTexture()
 end
 return button
end
C_Timer={After=function()end};issecretvalue=function()return false end;GetLocale=function()return "enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro")
ui:Toggle();a.db.locale="enUS";ui.detailScroll:SetSize(400,622)
local dungeon=a.dungeons[1];ui.dungeon,ui.quest=dungeon,nil
local theme=a.Theme;local style,font=theme.StyleFilter,theme.ApplyFont
theme.ApplyFont=function(region,size,...)
 region.mapFontLocale=a.db.locale;region.mapFontSize=size
 return font(region,size,...)
end
local available=true
a.DungeonMapSnapshot=function(d,id,owner)
 assert(d==dungeon and owner())
 if not available then return nil end
 local model={gameMapID=d.instanceID,journalID=900,baseMapID=901,mapID=id or 901,artID=902,layerIndex=1,
 name="Controlled complex",width=256,height=256,tileWidth=256,tileHeight=256,columns=1,rows=1,
 textures={71},shared=false,floors={{mapID=901,name="Ground",relativeHeightIndex=0},{mapID=903,name="Upper",relativeHeightIndex=1}}}
 return model,function()return true end,function()return true end
end
local function reference(enabled)
 local b=CreateFrame("Button");b.filterCaption=b:CreateFontString();b:SetEnabled(enabled)
 assert(style(b,false));return b.filterCaption.textColor
end
local enabledColor,disabledColor=reference(true),reference(false)
local function sameColor(got,expected)
 if not got or not expected or #got~=#expected then return false end
 for i,v in ipairs(expected)do if got[i]~=v then return false end end;return true
end
local total=0
local function open(id)assert(ui:OpenDungeonMap(dungeon,id));return ui.dungeonMap end
local function test(name,fn)
 theme.StyleFilter=style;ui:CloseDungeonMap(true);ui.frame:Show();a.db.locale="enUS"
 fn();total=total+1;print("PASS "..name)
end

test("First and last floor custom captions immediately match actual enabled theme colors",function()
 local b=open()
 assert(not b.previous.enabled and sameColor(b.previous.label.textColor,disabledColor),"disabled custom map caption must receive actual theme quiet color")
 assert(b.next.enabled and sameColor(b.next.label.textColor,enabledColor))
 assert(b.previous.filterCaption==b.previous.label and b.next.filterCaption==b.next.label)
 assert(b.previous.Left.alpha==0 and b.previous.Middle.alpha==0 and b.previous.Right.alpha==0,"native button artwork is quieted")
 assert(not b.previous.HookScript,"fixture deliberately has no enable/disable hooks")
 b.next.scripts.OnClick()
 assert(b.previous.enabled and sameColor(b.previous.label.textColor,enabledColor))
 assert(not b.next.enabled and sameColor(b.next.label.textColor,disabledColor))
 b.back.scripts.OnClick();b=open()
 assert(sameColor(b.previous.label.textColor,disabledColor)and sameColor(b.next.label.textColor,enabledColor))
end)

test("Back and unavailable Retry share the same enabled caption style",function()
 local b=open();assert(b.back.enabled and sameColor(b.back.label.textColor,enabledColor))
 available=false
 assert(not ui:OpenDungeonMap(dungeon));b=ui.dungeonMap
 assert(b.shown and b.retry.shown and b.retry.enabled and sameColor(b.retry.label.textColor,enabledColor))
 assert(b.back.shown and sameColor(b.back.label.textColor,enabledColor))
 available=true;b.retry.scripts.OnClick();assert(ui.dungeonMapState.model)
end)

test("Ten selected locales retain localized captions and per-render font refresh",function()
 for _,locale in ipairs({"enUS","ruRU","deDE","frFR","esES","itIT","ptBR","koKR","zhCN","zhTW"})do
  a.db.locale=locale;local b=open()
  assert(b.back.label.text==a.L("DUNGEON_MAP_BACK")and b.previous.label.text==a.L("DUNGEON_MAP_PREVIOUS")and b.next.label.text==a.L("DUNGEON_MAP_NEXT"))
  for _,control in ipairs({b.back,b.previous,b.next})do
   assert(control.label.mapFontLocale==locale and control.label.mapFontSize==12)
  end
  assert(sameColor(b.previous.label.textColor,disabledColor)and sameColor(b.next.label.textColor,enabledColor))
 end
end)

test("Missing, failed or throwing optional styling does not hide a verified map",function()
 local restricted={};local checker=issecretvalue
 issecretvalue=function(value)return value==restricted end
 for _,helper in ipairs({false,function()return false end,function()error("optional theme failure")end,
  function()return "not a boolean"end,function()return restricted end})do
  theme.StyleFilter=helper or nil;local b=open()
  assert(b.shown and not b.previous.enabled and b.next.enabled)
  assert(b.previous.label.alpha< b.next.label.alpha,"fallback still distinguishes disabled custom caption")
 end
 theme.StyleFilter=style;local b=open();assert(b.previous.label.alpha==1 and sameColor(b.previous.label.textColor,disabledColor))
 issecretvalue=checker
end)

test("A theme callback opening a newer floor cannot publish the retired paint",function()
 local b=open();local fired=false
 theme.StyleFilter=function(button,...)
  if button==b.previous and not fired then fired=true;assert(ui:OpenDungeonMap(dungeon,903))end
  return style(button,...)
 end
 assert(not ui:OpenDungeonMap(dungeon))
 assert(fired and ui.dungeonMap.shown and ui.dungeonMapState.model.mapID==903)
 assert(b.previous.enabled and sameColor(b.previous.label.textColor,enabledColor))
 assert(not b.next.enabled and sameColor(b.next.label.textColor,disabledColor))
end)

test("A late native caption color write repairs the newest floor appearance",function()
 local b=open();local label=b.previous.label;local original=label.SetTextColor;local fired=false
 label.SetTextColor=function(self,...)
  if not fired then fired=true;assert(ui:OpenDungeonMap(dungeon,903))end
  return original(self,...)
 end
 assert(not ui:OpenDungeonMap(dungeon));label.SetTextColor=original
 assert(fired and ui.dungeonMap.shown and ui.dungeonMapState.model.mapID==903)
 assert(b.previous.enabled and sameColor(label.textColor,enabledColor))
 assert(not b.next.enabled and sameColor(b.next.label.textColor,disabledColor))
end)

test("Replacing the style provider retires an in-progress old control paint",function()
 local b=open();local fired=false
 theme.StyleFilter=function(button,...)
  if button==b.back and not fired then fired=true;theme.StyleFilter=function()return false end end
  return style(button,...)
 end
 assert(not ui:OpenDungeonMap(dungeon)and fired and not b.shown)
 theme.StyleFilter=style;b=open();assert(b.shown and sameColor(b.previous.label.textColor,disabledColor))
end)

print("Dungeon map theme: PASS "..total.." groups (controlled widgets, no native visual acceptance)")
