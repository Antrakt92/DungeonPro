local cases=0
for _,objects in ipairs({true})do
 local f=assert(loadfile("tests/client_ui.lua"))("fixture")
 local a,event,m=f.addon,f.eventFrame,f.methods
 function m:SetFont(path,size,flags)self.fontPath,self.fontSize,self.fontFlags=path,size,flags;if self.kind~="FontObject"then return true end end
 function m:GetFont()
  if self.fontPath then return self.fontPath,self.fontSize,self.fontFlags end
  if self.fontObject then local path,size,flags=self.fontObject:GetFont();return path,self.fontSize or size,flags end
 end
 function m:SetFontObject(font)self.fontObject,self.fontPath,self.fontSize,self.fontFlags=font,nil,nil,nil end
 function m:GetFontObject()return self.fontObject end
 function m:SetFontHeight(size)self.fontSize=size end
 local function font()
  return setmetatable({kind="FontObject",fontPath="Fonts\\ARIALN.TTF",fontSize=14,fontFlags=""},{__index=m})
 end
 ChatFontNormal,GameFontHighlight=font(),nil
 CreateFont=objects and function()return font()end or nil
 event.scripts.OnEvent(event,"ADDON_LOADED","DungeonPro")
 SlashCmdList.DUNGEONPRO("")
 local ui=a.UI;ui.dungeon=a.dungeons[1];a.db.locale="zhCN";ui:Refresh()
 assert(ui.heading:GetFont()=="Fonts\\ARKai_T.ttf")

 local input=CreateFrame("EditBox");a.Theme.ApplyInputFont(input)
 local button=CreateFrame("Button");button.roles={Normal=font(),Highlight=font(),Disabled=font()}
 for _,role in ipairs({"Normal","Highlight","Disabled"})do
  local name=role
  button["Get"..name.."FontObject"]=function(self)return self.roles[name]end
  button["Set"..name.."FontObject"]=function(self,value)self.roles[name]=value end
 end
 assert(a.Theme.StyleButtonFonts(button))
 local function corrupt(object)
  local _,size=object:GetFont();object:SetFont("Fonts\\ARIALN.TTF",size,"")
  assert(object:GetFont()=="Fonts\\ARIALN.TTF","corruption actually changed native owned asset")
 end
 local function expected(region)
  assert(region:GetFont()=="Fonts\\ARKai_T.ttf","refresh restores the owned Chinese font asset")
 end
 corrupt(ui.heading:GetFontObject());ui:Refresh();expected(ui.heading);cases=cases+1
 corrupt(input:GetFontObject());a.Theme.RefreshFonts();expected(input);cases=cases+1
 for _,role in ipairs({"Normal","Highlight","Disabled"})do
  corrupt(button.roles[role]);a.Theme.RefreshFonts()
  for _,name in ipairs({"Normal","Highlight","Disabled"})do expected(button.roles[name])end
  cases=cases+1
 end
 -- A failed region setter must not make the repaired cache count as applied.
 for _,region in ipairs({ui.heading,input})do
  corrupt(region:GetFontObject())
  local setter,direct=region.SetFontObject,region.SetFont;local fired=false
  region.SetFontObject=function()fired=true;error("native setter unavailable")end
  region.SetFont=function()error("native direct setter unavailable")end
  if region==input then a.Theme.ApplyInputFont(region)else a.Theme.ApplyFont(region,26)end
  assert(fired and region:GetFont()=="Fonts\\ARIALN.TTF","failed setter was exercised and did not claim successful repair")
  region.SetFontObject,region.SetFont=setter,direct;a.Theme.RefreshFonts();expected(region);cases=cases+1
 end
 corrupt(button.roles.Highlight)
 local setter=button.SetHighlightFontObject;local fired=false
 button.SetHighlightFontObject=function()fired=true;error("native role setter unavailable")end
 assert(not a.Theme.StyleButtonFonts(button)and fired,"failed native role setter rejects styling")
 button.SetHighlightFontObject=setter;a.Theme.RefreshFonts()
 for _,name in ipairs({"Normal","Highlight","Disabled"})do expected(button.roles[name])end
 cases=cases+1
 local broken=input:GetFontObject();local read=broken.GetFont;local fired=false
 broken.GetFont=function()fired=true;error("native font readback unavailable")end
 a.Theme.RefreshFonts();assert(fired and input:GetFontObject()~=broken,"unreadable owned cache is rebuilt rather than trusted")
 broken.GetFont=read;expected(input);cases=cases+1
 local writes=0;local native=m.SetFontObject
 m.SetFontObject=function(self,...)writes=writes+1;return native(self,...)end
 local direct=m.SetFont
 m.SetFont=function(self,...)writes=writes+1;return direct(self,...)end
 for _,role in ipairs({"Normal","Highlight","Disabled"})do
  local name=role;local native=button["Set"..name.."FontObject"]
  button["Set"..name.."FontObject"]=function(self,...)writes=writes+1;return native(self,...)end
 end
 a.Theme.RefreshFonts();a.Theme.ApplyFont(ui.heading,26);a.Theme.ApplyInputFont(input);a.Theme.StyleButtonFonts(button)
 assert(writes==0,"healthy same-context refresh and explicit calls perform zero native font assignments")
 cases=cases+1
 local label=ui.detail:CreateFontString();a.Theme.ApplyFont(label,26)
 local read=label.GetFont;local fired=false
 label.GetFont=function(self)
  if not fired then fired=true;a.Theme.ApplyLanguageFont(label,"koKR",18)end
  return read(self)
 end
 a.Theme.RefreshFonts();label.GetFont=read
 local path,size=label:GetFont()
 assert(fired and path=="Fonts\\2002.ttf"and size==18,"old refresh readback cannot replace newer explicit text intent")
 cases=cases+1
 local read=button.GetNormalFontObject;local fired=false
 button.GetNormalFontObject=function(self)
  if not fired then fired=true;assert(a.Theme.StyleLanguageRow(button,"koKR"))end
  return read(self)
 end
 a.Theme.RefreshFonts();button.GetNormalFontObject=read
 for _,name in ipairs({"Normal","Highlight","Disabled"})do
  assert(button.roles[name]:GetFont()=="Fonts\\2002.ttf","old refresh readback cannot replace newer explicit button intent")
 end
 assert(fired,"button native readback actually completed newer font intent");cases=cases+1
 local read=input.GetFont;local fired=false
 input.GetFont=function(self)
  if not fired then fired=true;a.db.locale="koKR";a.Theme.ApplyInputFont(input)end
  return read(self)
 end
 a.Theme.RefreshFonts();input.GetFont=read
 assert(fired and input:GetFont()=="Fonts\\2002.ttf","input readback retains newer locale font intent")
 cases=cases+1
end
print("Font cache drift UI checks passed: "..cases)
