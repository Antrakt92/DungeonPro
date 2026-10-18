local cases=0
for _,objects in ipairs({false,true})do
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
 local key=objects and "SetFontObject"or"SetFont"
 local native=ui.heading[key];local fired,depth,maxDepth=false,0,0
 ui.heading[key]=function(self,value,...)
  depth=depth+1;maxDepth=math.max(maxDepth,depth);assert(depth<5,"font repair bounded")
  local path=objects and value:GetFont()or value
  if not fired and path:find("NotoSans",1,true)then fired=true;a.db.locale="zhCN";ui:Refresh(true)end
  local result=native(self,value,...);depth=depth-1;return result
 end
 a.db.locale="enUS";ui:Refresh(true)
 assert(fired and a.db.locale=="zhCN","font setter must reenter a newer Chinese view")
 assert(ui.heading:GetFont()=="Fonts\\ARKai_T.ttf","late older font setter cannot replace the newer CJK font")
 assert(depth==0 and maxDepth<=3,"bounded native font setter depth")
 local writes=0
 ui.heading[key]=function(self,...)writes=writes+1;return native(self,...)end
 ui:Refresh(true);assert(writes==0,"same-context repaint retains the current native font without duplicate setter")
 cases=cases+1
 if objects then
  local input=CreateFrame("EditBox")
  a.db.locale="zhCN";a.Theme.ApplyInputFont(input)
  assert(input:GetFont()=="Fonts\\ARKai_T.ttf")
  local set=input.SetFontObject;local fired=false
  input.SetFontObject=function(self,value)
   if not fired and value:GetFont():find("NotoSans",1,true)then
    fired=true;a.db.locale="zhCN";a.Theme.ApplyInputFont(input)
   end
   return set(self,value)
  end
  a.db.locale="enUS";a.Theme.ApplyInputFont(input)
  assert(fired and input:GetFont()=="Fonts\\ARKai_T.ttf","input font object retains newer script")
  local button=CreateFrame("Button");button.roles={Normal=font(),Highlight=font(),Disabled=font()}
  for _,role in ipairs({"Normal","Highlight","Disabled"})do
   local name=role
   button["Get"..name.."FontObject"]=function(self)return self.roles[name]end
   button["Set"..name.."FontObject"]=function(self,value)self.roles[name]=value end
  end
  a.db.locale="zhCN";assert(a.Theme.StyleButtonFonts(button))
  local normal=button.SetNormalFontObject;local fired=false
  button.SetNormalFontObject=function(self,value)
   if not fired and value:GetFont():find("NotoSans",1,true)then
    fired=true;a.db.locale="zhCN";a.Theme.StyleButtonFonts(button)
   end
   return normal(self,value)
  end
  a.db.locale="enUS";a.Theme.StyleButtonFonts(button)
  assert(fired,"template font setter reentry fires")
  for _,role in ipairs({"Normal","Highlight","Disabled"})do
   assert(button.roles[role]:GetFont()=="Fonts\\ARKai_T.ttf","all template roles retain newer CJK font")
  end
  assert(a.Theme.StyleLanguageRow(button,"koKR"))
  a.db.locale="enUS";a.Theme.RefreshFonts()
  for _,role in ipairs({"Normal","Highlight","Disabled"})do assert(button.roles[role]:GetFont()=="Fonts\\2002.ttf")end
  local label=ui.detail:CreateFontString()
  a.db.locale="enUS";a.Theme.ApplyFont(label,14)
  local set=label.SetFontObject;local fired=false
  label.SetFontObject=function(self,value)
   local _,size=value:GetFont()
   if not fired and size==16 then fired=true;a.Theme.ApplyLanguageFont(label,"koKR",18)end
   return set(self,value)
  end
  a.Theme.ApplyFont(label,16)
  local path,size=label:GetFont()
  assert(fired and path=="Fonts\\2002.ttf"and size==18,"newer explicit language and size own the text font")
  a.db.locale="frFR";a.Theme.RefreshFonts()
  local path,size=label:GetFont();assert(path=="Fonts\\2002.ttf"and size==18,"fixed-language text remains independent of main UI locale")
  local label=ui.detail:CreateFontString()
  a.db.locale="enUS";a.Theme.ApplyFont(label,14)
  local localeGetter=GetLocale;local armed,fired=true,false
  GetLocale=function()
   if armed then armed=false;fired=true;a.Theme.ApplyLanguageFont(label,"koKR",18)end
   return localeGetter()
  end
  a.Theme.ApplyFont(label,16);GetLocale=localeGetter
  local path,size=label:GetFont()
  assert(fired and path=="Fonts\\2002.ttf"and size==18,"context getter cannot replace a newer explicit font request")
  cases=cases+4
 end
end
print("Font ownership UI checks passed: "..cases.." native font paths")
