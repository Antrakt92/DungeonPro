-- Selected-quest stream composition; native rendering remains user acceptance.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return "enUS" end
UnitLevel=function()return 60 end;UnitFactionGroup=function()return "Alliance" end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true
local dungeon;for _,d in ipairs(a.dungeons)do if d.key=="dalaran"then dungeon=d end end
assert(dungeon and a.quests[92458] and a.quests[92459])
local names={[251961]="Arcane Mote",[277507]="Dalaran Sewer Key",[9326]="Grime-Encrusted Ring"}
a.ItemName=function(id)return names[id]or("Item "..id)end;a.ItemIcon=function()return 134400 end;a.CarriedItemCount=function()return 0 end
local description="Controlled native-adapter description for the selected quest. "..string.rep("Long authentic-adapter fixture text. ",32)
local progress="Controlled native-adapter progress-stage fixture text."
a.Description=function(id)if id==92458 then return description end end
a.DialogueText=function(id)if id==92458 then return{source="dialogue",stage="progress",text=progress,current=function()return true end}end end
a.QuestObjectives=function()return nil end
local routes={};a.Navigation={Start=function(action)routes[#routes+1]=action;return true end,Map=function(point)routes[#routes+1]=point;return true end}
local function visible(text)
 local found={};for _,v in ipairs(u.details or{})do if v:IsShown()and v:GetText()==text then found[#found+1]=v end end;return found
end
local function noDuplicateControls()
 for _,control in pairs(u.detailTabButtons or{})do assert(not control:IsShown(),"single stream must not leave visible Quest/Sources/Story modes")end
 assert(not u.detailBackButton or not u.detailBackButton:IsShown(),"accepted layout has no universal Back button")
 assert(not u.narrativeToggle or not u.narrativeToggle:IsShown(),"native prose must not require an original-text drawer")
 assert(not u.ancestorActionButton or not u.ancestorActionButton:IsShown(),"central tree remains the quest selector")
 for _,control in pairs(u.materialButtons or{})do assert(not control:IsShown(),"no duplicate selectable material-quest list")end
end
local function roles(role,id)
 local found={};for _,v in ipairs(u.objectiveButtons or{})do local p=v.objectiveBinding
  if v:IsShown()and p and p.role==role and p.id==id then assert(p.current());found[#found+1]=v end
 end;return found
end
u.dungeon,u.quest=dungeon,92458;u:Refresh();noDuplicateControls()
assert(u.quest==92458 and u.renderedQuest==92458)
assert(#roles("objective",251961)==1 and #roles("provided",277507)==1,"objective and supplied item retain separate own roles exactly once")
assert(a.quests[92458].objectiveItems[1].quantity==nil and a.quests[92458].providedItems[1].quantity==nil and not a.quests[92458].requirementsKnown)
assert(#visible("Arcane Mote ×? · "..a.L("ITEM_CARRIED",0))==1,"unknown objective quantity remains unknown independently of bags")
assert(#visible("Dalaran Sewer Key ×? · "..a.L("ITEM_CARRIED",0))==1,"provided quantity cannot become one from a unique-key property")
assert(#visible(description)==1 and #visible(progress)==1,"base description and authenticated dialogue stage are both visible without tabs")
local prose=visible(description)[1];local objective=roles("objective",251961)[1];local supplied=roles("provided",277507)[1]
local function offsetY(object)
 local p=assert(object.point,"actual measured placement required");local y=type(p[5])=="number"and p[5]or p[3]
 assert(type(y)=="number"and y==y and y~=math.huge and y~=-math.huge,"finite actual layout offset required")
 return y
end
assert(offsetY(prose)<offsetY(objective)and offsetY(prose)<offsetY(supplied),"practical items precede long native prose")
assert(#visible(a.L("DETAIL_STORY_UNAVAILABLE"))==0,"no empty Story section")
local old=assert(u.detailContactRows and u.detailContactRows[1]);local own=assert(old.detailContactBinding)
assert(old:IsShown()and old.enabled and own.questID==92458 and own.field=="start"and own.endpoint==a.quests[92458].start and own.current())
local click=assert(old.scripts.OnClick);assert(type(click)=="function","actual old pickup callback must be retained")
assert(u:InspectQuest(92459,true));noDuplicateControls();assert(u.quest==92459 and #visible(description)==0 and #visible(progress)==0)
local finish=u.detailContactRows and u.detailContactRows[2];assert(finish and finish:IsShown() and finish.detailContactBinding and finish.detailContactBinding.questID==92459 and finish.detailContactBinding.field=="finish"and finish.detailContactBinding.endpoint==a.quests[92459].finish and finish.detailContactBinding.current()and finish.detailContactBinding.action.kind=="visit"and finish.detailContactBinding.purpose==nil,"story member has its own distinct turn-in endpoint")
assert(a.quests[92459].start.npcID==269127 and a.quests[92459].finish.npcID==252085)
local before=#routes;click();assert(#routes==before,"retained old selected-quest contact cannot navigate")
local fired=false
a.Description=function(id)
 if id==92458 and not fired then fired=true;assert(u:InspectQuest(92459,true));return "STALE DESCRIPTION MUST NOT PAINT"end
end
u.quest=92458;u:RefreshDetail();assert(fired and u.quest==92459 and #visible("STALE DESCRIPTION MUST NOT PAINT")==0,"description callback reentry preserves newer selected quest")
print("PASS selected actual Dalaran stream roles, unknown quantities, practical/prose order, independent native text stages, no duplicate selectors, distinct contacts and stale description retirement")

do
local originalRawEqual,originalSecretCheck=rawequal,issecretvalue

local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return "enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true
local dungeon;for _,d in ipairs(a.dungeons)do if d.key=="dalaran"then dungeon=d end end
assert(dungeon)
a.QuestObjectives=function()return nil end;a.DialogueText=nil;a.Description=function()return "PEER DESCRIPTION"end
local function draw(id)u.dungeon,u.quest=dungeon,id or 92458;u:Refresh()end
local function visible(text)local n=0;for _,v in ipairs(u.details)do if v:IsShown()and v:GetText()==text then n=n+1 end end;return n end

local foreign=0;a.DialogueText=function()a.Clean=function()foreign=foreign+1;error("FOREIGN CLEAN")end;return{source="dialogue",stage="progress",text="PEER PROGRESS",current=function()return true end}end;local ok,err=pcall(draw);print("OBS",ok,foreign,err);assert(ok and foreign==0,"dialogue callback must not invoke substituted Clean")
rawequal,issecretvalue=originalRawEqual,originalSecretCheck
print("PASS strict stream guard: dialogue_clean_swap")
end

do
local originalRawEqual,originalSecretCheck=rawequal,issecretvalue

local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return "enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true
local dungeon;for _,d in ipairs(a.dungeons)do if d.key=="dalaran"then dungeon=d end end
assert(dungeon)
a.QuestObjectives=function()return nil end;a.DialogueText=nil;a.Description=function()return "PEER DESCRIPTION"end
local function draw(id)u.dungeon,u.quest=dungeon,id or 92458;u:Refresh()end
local function visible(text)local n=0;for _,v in ipairs(u.details)do if v:IsShown()and v:GetText()==text then n=n+1 end end;return n end

local secret={};local old=rawequal;local attempts=0;issecretvalue=function(v)return old(v,secret)end;rawequal=function(x,y)if old(x,secret)or old(y,secret)then attempts=attempts+1;error("SECRET COMPARED")end;return old(x,y)end;a.locales.enUS.NO_TEXT=secret;local ok,err=pcall(draw);print("OBS",ok,attempts,err);assert(ok and attempts==0,"NO_TEXT must be readable before raw comparison")
rawequal,issecretvalue=originalRawEqual,originalSecretCheck
print("PASS strict stream guard: initial_no_text_secret")
end

do
local originalRawEqual,originalSecretCheck=rawequal,issecretvalue

local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return "enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true
local dungeon;for _,d in ipairs(a.dungeons)do if d.key=="dalaran"then dungeon=d end end
assert(dungeon)
a.QuestObjectives=function()return nil end;a.DialogueText=nil;a.Description=function()return "PEER DESCRIPTION"end
local function draw(id)u.dungeon,u.quest=dungeon,id or 92458;u:Refresh()end
local function visible(text)local n=0;for _,v in ipairs(u.details)do if v:IsShown()and v:GetText()==text then n=n+1 end end;return n end

local secret={};local old=rawequal;local attempts=0;issecretvalue=function(v)return old(v,secret)end;rawequal=function(x,y)if old(x,secret)or old(y,secret)then attempts=attempts+1;error("SECRET COMPARED")end;return old(x,y)end;a.Description=function()a.locales.enUS.NO_TEXT=secret;return "PEER DESCRIPTION"end;local ok,err=pcall(draw);print("OBS",ok,attempts,err);assert(ok and attempts==0,"live NO_TEXT secret must retire before raw comparison")
rawequal,issecretvalue=originalRawEqual,originalSecretCheck
print("PASS strict stream guard: live_no_text_secret")
end

do
local originalRawEqual,originalSecretCheck=rawequal,issecretvalue

local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return "enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true
local dungeon;for _,d in ipairs(a.dungeons)do if d.key=="dalaran"then dungeon=d end end
assert(dungeon)
a.QuestObjectives=function()return nil end;a.DialogueText=nil;a.Description=function()return "PEER DESCRIPTION"end
local function draw(id)u.dungeon,u.quest=dungeon,id or 92458;u:Refresh()end
local function visible(text)local n=0;for _,v in ipairs(u.details)do if v:IsShown()and v:GetText()==text then n=n+1 end end;return n end

local foreign=0;a.Description=function()a.Clean=function()foreign=foreign+1;error("FOREIGN CLEAN")end;return "PEER DESCRIPTION"end;local ok,err=pcall(draw);print("OBS",ok,foreign,err);assert(ok and foreign==0,"description must not invoke substituted Clean")
rawequal,issecretvalue=originalRawEqual,originalSecretCheck
print("PASS strict stream guard: description_clean_swap")
end

do
local originalRawEqual,originalSecretCheck=rawequal,issecretvalue

local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return "enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true
local dungeon;for _,d in ipairs(a.dungeons)do if d.key=="dalaran"then dungeon=d end end
assert(dungeon)
a.QuestObjectives=function()return nil end;a.DialogueText=nil;a.Description=function()return "PEER DESCRIPTION"end
local function draw(id)u.dungeon,u.quest=dungeon,id or 92458;u:Refresh()end
local function visible(text)local n=0;for _,v in ipairs(u.details)do if v:IsShown()and v:GetText()==text then n=n+1 end end;return n end

local foreign=0;local localize=a.L;a.L=function(key,...)local result=localize(key,...);if key=="NO_TEXT"then a.Clean=function()foreign=foreign+1;error("FOREIGN CLEAN")end;a.Read=function()foreign=foreign+1;error("FOREIGN READ")end end;return result end;local ok,err=pcall(draw);print("OBS",ok,foreign,err);assert(ok and foreign==0,"NO_TEXT localizer must not invoke substituted helpers")
rawequal,issecretvalue=originalRawEqual,originalSecretCheck
print("PASS strict stream guard: localizer_read_clean_swap")
end

do
local originalRawEqual,originalSecretCheck=rawequal,issecretvalue

local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return "enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true
local dungeon;for _,d in ipairs(a.dungeons)do if d.key=="dalaran"then dungeon=d end end
assert(dungeon)
a.QuestObjectives=function()return nil end;a.DialogueText=nil;a.Description=function()return "PEER DESCRIPTION"end
local function draw(id)u.dungeon,u.quest=dungeon,id or 92458;u:Refresh()end
local function visible(text)local n=0;for _,v in ipairs(u.details)do if v:IsShown()and v:GetText()==text then n=n+1 end end;return n end

draw();local fs;for _,v in ipairs(u.details)do if v:IsShown()and v:GetText()=="PEER DESCRIPTION"then fs=v end end;assert(fs);local secret={};local old=rawequal;local attempts=0;issecretvalue=function(v)return old(v,secret)end;rawequal=function(x,y)if old(x,secret)or old(y,secret)then attempts=attempts+1;error("SECRET COMPARED")end;return old(x,y)end;local method=fs.SetText;local armed=true;fs.SetText=function(self,text)if armed and text=="PEER DESCRIPTION"then armed=false;a.locales.enUS.NO_TEXT=secret end;return method(self,text)end;local ok,err=pcall(draw);print("OBS",ok,armed,attempts,err);assert(ok and not armed and attempts==0,"native SetText must retire live restricted labels before raw comparison")
rawequal,issecretvalue=originalRawEqual,originalSecretCheck
print("PASS strict stream guard: native_text_no_text_secret")
end

do
local originalRawEqual,originalSecretCheck=rawequal,issecretvalue

local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return "enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true
local dungeon;for _,d in ipairs(a.dungeons)do if d.key=="dalaran"then dungeon=d end end
assert(dungeon)
a.QuestObjectives=function()return nil end;a.DialogueText=nil;a.Description=function()return "PEER DESCRIPTION"end
local function draw(id)u.dungeon,u.quest=dungeon,id or 92458;u:Refresh()end
local function visible(text)local n=0;for _,v in ipairs(u.details)do if v:IsShown()and v:GetText()==text then n=n+1 end end;return n end

local foreign=0;a.DialogueText=function()return{source="dialogue",stage="progress",text="PEER PROGRESS",current=function()a.Clean=function()foreign=foreign+1;error("FOREIGN CLEAN")end;return true end}end;local ok,err=pcall(draw);print("OBS",ok,foreign,err);assert(ok and foreign==0,"dialogue proof must not invoke substituted Clean")
rawequal,issecretvalue=originalRawEqual,originalSecretCheck
print("PASS strict stream guard: dialogue_proof_clean_swap")
end

do
local originalRawEqual,originalSecretCheck=rawequal,issecretvalue

local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return "enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true
local dungeon;for _,d in ipairs(a.dungeons)do if d.key=="dalaran"then dungeon=d end end
assert(dungeon)
a.QuestObjectives=function()return nil end;a.DialogueText=nil;a.Description=function()return "PEER DESCRIPTION"end
local function draw(id)u.dungeon,u.quest=dungeon,id or 92458;u:Refresh()end
local function visible(text)local n=0;for _,v in ipairs(u.details)do if v:IsShown()and v:GetText()==text then n=n+1 end end;return n end

local old=a.quests[92458];a.Description=function()local changed={};for k,v in pairs(old)do changed[k]=v end;a.quests[92458]=changed;return "RETIRED SOURCE DESCRIPTION"end;local ok=pcall(draw);assert(ok and visible("RETIRED SOURCE DESCRIPTION")==0,"replacement of canonical selected definition retires old prose")
rawequal,issecretvalue=originalRawEqual,originalSecretCheck
print("PASS strict stream guard: canonical_definition_replaced")
end

do
local originalRawEqual,originalSecretCheck=rawequal,issecretvalue

local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;C_Timer={After=function()end};GetLocale=function()return "enUS"end
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS";u.includeUnavailable=true
local dungeon;for _,d in ipairs(a.dungeons)do if d.key=="dalaran"then dungeon=d end end
assert(dungeon)
a.QuestObjectives=function()return nil end;a.DialogueText=nil;a.Description=function()return "PEER DESCRIPTION"end
local function draw(id)u.dungeon,u.quest=dungeon,id or 92458;u:Refresh()end
local function visible(text)local n=0;for _,v in ipairs(u.details)do if v:IsShown()and v:GetText()==text then n=n+1 end end;return n end

a.Description=function()a.quests[92458]=nil;return "REMOVED SOURCE DESCRIPTION"end;local ok=pcall(draw);assert(ok and visible("REMOVED SOURCE DESCRIPTION")==0,"removal of canonical selected definition retires old prose")
rawequal,issecretvalue=originalRawEqual,originalSecretCheck
print("PASS strict stream guard: canonical_definition_removed")
end
