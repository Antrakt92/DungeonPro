-- Journal styling owns only the selected detail surface and keeps native font selection.
local addon = {}
assert(loadfile("Core/Namespace.lua"))("DungeonPro", addon)
local methods, all = {}, {}
local function region()
 local value=setmetatable({shown=true,points={},textures={}}, {__index=methods});all[#all+1]=value;return value
end
function methods:SetColorTexture(...)self.color={...}end
function methods:SetTextColor(...)self.ink={...}end
function methods:SetFont(path,size,flags)self.fontPath,self.fontSize,self.fontFlags=path,size,flags;return true end
function methods:GetFont()return self.fontPath,self.fontSize,self.fontFlags end
function methods:SetShadowOffset()end
function methods:SetText(v)self.text=v end
function methods:SetSize(w,h)self.width,self.height=w,h end
function methods:SetWidth(w)self.width=w end
function methods:SetHeight(h)self.height=h end
function methods:SetTexture(v)self.texture=v;return true end
function methods:SetAllPoints(v)self.allPoints=v end
function methods:SetPoint(...)self.points[#self.points+1]={...}end
function methods:ClearAllPoints()self.points={}end
function methods:Show()self.shown=true end
function methods:Hide()self.shown=false end
function methods:SetShown(v)self.shown=v end
function methods:SetBackdrop(v)self.backdrop=v end
function methods:CreateTexture()local v=region();self.textures[#self.textures+1]=v;return v end
function methods:CreateFontString()return region()end
function methods:GetHighlightTexture()return self.highlight end
function methods:GetParent()return self.parent end
local locale="enUS";GetLocale=function()return locale end
STANDARD_TEXT_FONT="Fonts\\ARIALN.TTF";issecretvalue=function()return false end
addon.db={locale="enUS"}
assert(loadfile("UI/Theme.lua"))("DungeonPro",addon)
local t=addon.Theme
assert(type(t.StyleDetailText)=="function"and type(t.StyleDetailContact)=="function"and type(t.StyleDetailSection)=="function","journal APIs are required")
local function rgb(actual,r,g,b,a)
 assert(actual and math.abs(actual[1]-r/255)<1e-9 and math.abs(actual[2]-g/255)<1e-9 and math.abs(actual[3]-b/255)<1e-9)
 assert(actual[4]==(a or 1))
end
for role,size in pairs({title=27,body=16,caption=11,section=12,contactName=15,contactPurpose=11,zone=11})do
 local v=region();assert(t.StyleDetailText(v,role));assert(v.fontSize==size,"actual native font setter receives requested role size")
 if role=="title"or role=="body"then rgb(v.ink,232,226,215)
 elseif role=="section"or role=="contactName"then rgb(v.ink,227,195,136)
 else rgb(v.ink,170,166,164)end
end
local text=region();assert(not t.StyleDetailText(text,"invalid")and not text.fontSize)
addon.db.locale="zhCN";assert(t.StyleDetailText(text,"body"));assert(text.fontPath=="Fonts\\ARKai_T.ttf"and text.fontSize==16,"native Chinese font selection remains available")
addon.db.locale="enUS"
-- A returning native color setter must not overwrite a newer complete style.
local setter=text.SetTextColor;local armed=true
text.SetTextColor=function(self,...)
 if armed then armed=false;assert(t.StyleDetailText(self,"section"))end
 return setter(self,...)
end
assert(not t.StyleDetailText(text,"title"));assert(text.fontSize==12);rgb(text.ink,227,195,136)
text.SetTextColor=setter
local live=false;assert(not t.StyleDetailText(text,"title",function()return live end)and text.fontSize==12)
local row=region();row.title,row.note,row.bg,row.highlight=region(),region(),region(),region()
local click=function()end;row.OnClick=click;assert(t.StyleRow(row,{kind="quest"}));assert(t.StyleDetailContact(row))
assert(row.purpose==row.detailPurpose and row.avatar==row.detailAvatar and row.detailName==row.title and row.detailZone==row.note)
assert(row.avatar.width==36 and row.avatar.height==36 and row.avatar.shown)
assert(row.avatar.texture=="Interface\\GossipFrame\\AvailableQuestIcon","unresolved actor or object uses a neutral quest glyph, never an invented human portrait")
assert(row.title.fontSize==15 and row.note.fontSize==11 and row.purpose.fontSize==11)
assert(row.bg.color[4]==0 and row.highlight.color[4]==0 and row.OnClick==click,"contact styling removes heavy fill and never changes navigation")
rgb(row.detailSeparator.color,60,56,57);assert(row.detailSeparator.height==1)
local before=#all;assert(t.StyleDetailContact(row));assert(#all==before,"contact decoration is pooled")
-- First-time optional decoration creation may synchronously paint a newer contact.
for _,capability in ipairs({"CreateFontString","CreateTexture"})do
 local fresh=region();fresh.title,fresh.note,fresh.bg=region(),region(),region()
 local original=methods[capability];local trigger=true;local newest
 fresh[capability]=function(self,...)
  local created=original(self,...)
  if trigger then trigger=false;assert(t.StyleDetailContact(self));newest=self.detailPurpose end
  return created
 end
 assert(not t.StyleDetailContact(fresh));assert(fresh.detailPurpose==newest and fresh.purpose==newest,"retired creation cannot publish an older purpose object")
 assert(fresh.detailAvatar==fresh.avatar and fresh.avatar.width==36 and fresh.avatar.height==36)
end
local frame=region();assert(t.StyleDetailSection(frame,"objectives"));local surface=frame.detailJournalSurface
rgb(surface.background.color,35,36,44);rgb(surface.left.color,227,195,136);assert(surface.background.shown and surface.left.width==2 and surface.left.shown and not surface.top.shown)
before=#all;assert(t.StyleDetailSection(frame,"reward"));assert(#all==before and not surface.background.shown and not surface.left.shown and surface.top.shown);rgb(surface.top.color,60,56,57)
local paint=surface.background.SetColorTexture;armed=true
surface.background.SetColorTexture=function(self,...)
 if armed then armed=false;assert(t.StyleDetailSection(frame,"narrative"))end
 return paint(self,...)
end
assert(not t.StyleDetailSection(frame,"objectives"));assert(not surface.background.shown and not surface.left.shown and surface.top.shown,"new divider survives older objective paint tail")
surface.background.SetColorTexture=paint
local ui={frame=region(),catalogScroll=region(),questScroll=region(),detailScroll=region()};assert(t.Apply(ui))
rgb(ui.detailJournalBackground.color,26,25,30);rgb(ui.detailJournalBorder.color,60,56,57)
local ordinary=0
for _,v in ipairs(ui.frame.textures)do if v.color and v.color[1]==.041 and v.color[2]==.058 and v.color[3]==.071 then ordinary=ordinary+1 end end
assert(ordinary==2,"catalogue and chain keep their existing panel palette")
print("Journal theme: PASS (seven native typography roles, CJK, retained reentry, contact pooling, objectives/dividers, detail-only palette)")
