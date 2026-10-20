-- Selected quest roles and direct contacts preserve source ownership and UI state.
do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local q={id=995901,name="Contact selected",minLevel=1,requirementsKnown=true,start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20},finish={npcID=82,name="Finish actor",zoneName="Stormwind City",mapID=1453,x=30,y=40}}
a.quests[q.id]=q;local d={key="contacts",name="Contacts",minLevel=1,maxLevel=60,quests={q.id}};a.dungeons={d};u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,q.id,q.id,d
local ctx={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end};a.Context=function()return ctx end
local calls={};a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={action=action,purpose=purpose};return true end,Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}
u:Refresh()
local rows=assert(u.detailContactRows,"full row pool missing");local s,t=assert(rows[1],"start row absent"),assert(rows[2],"finish row absent")
assert(s:IsShown()and t:IsShown()and s.enabled and t.enabled,"both actual contacts visible and navigable")
assert(s.title.text:find("Pickup actor",1,true)and s.note.text=="Westfall","start owns name+zone")
assert(t.title.text:find("Finish actor",1,true)and t.note.text=="Stormwind City","finish owns name+zone")
assert(s.width==u.detail:GetWidth()-8 and t.width==s.width and s.height>=52,"whole rows have measured layout")
local selected,tree=u.quest,u.questTreeRoot;s.scripts.OnClick();assert(#calls==1 and calls[1].action.place==q.start and calls[1].purpose=="quest-start")
t.scripts.OnClick();assert(#calls==2 and calls[2].action.place==q.finish and calls[2].action.kind=="visit"and calls[2].purpose==nil,"finish visits neutrally")
assert(u.quest==selected and u.questTreeRoot==tree,"row clicks preserve selected quest/root")
assert(not u.giver:IsShown(),"no duplicate oldgiver arrow")
print("PASS two own-name/zone full-width rows; neutral finish and quest-start; selected identity retained; old arrow absent")
local typed=q.start
q.start={name="Legacy location",zoneName="Westfall",mapID=1436,x=12,y=22};u:Refresh()
local legacy=assert(u.giver.scripts.OnClick);assert(u.giver:IsShown()and u.giver.enabled)
q.start=typed;u:Refresh()
assert(not u.giver:IsShown()and not u.giver.enabled and u.giver.scripts.OnClick==nil,"old control is hidden disabled inert")
assert(u.giverAction and u.giverAction.place==typed and u.giverBinding.current(),"internal pickup data retained")
local destination,giver=u:NavigationDestination(false);assert(destination and destination.place==typed and giver,"legacy NavigationDestination retains exactpickup")
local count=#calls;legacy();assert(#calls==count,"retained oldclick cannot redirect to newcontact")
q.start={itemID=880001,name="Canonical item"};a.ItemName=function(id)assert(id==880001);return "Localized item"end;a.ItemIcon=function()return 135001 end;u:Refresh()
assert(not u.detailContactRows[1]:IsShown()and u.detailContactRows[2]:IsShown()and u.detailContactRows[2].enabled,"item starter readonly; finish independent")
local label=false;for _,fs in ipairs(u.details)do if fs:IsShown()and fs.text==a.L("ITEM_STARTER","Localized item")then label=true end end;assert(label,"item localized existing label preserved")
local starter=false;for _,button in ipairs(u.objectiveButtons)do if button:IsShown()and button.objectiveBinding.role=="starter"then starter=true end end;assert(starter,"item starter inventory tooltip role preserved")
print("PASS legacy pickup data retained; hidden click nil; old lease inert; item localized readonly/tooltip and independentfinish")

end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local q={id=995901,name="Contact selected",minLevel=1,requirementsKnown=true,start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20},finish={npcID=82,name="Finish actor",zoneName="Stormwind City",mapID=1453,x=30,y=40}}
a.quests[q.id]=q;local d={key="contacts",name="Contacts",minLevel=1,maxLevel=60,quests={q.id}};a.dungeons={d};u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,q.id,q.id,d
local ctx={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end};a.Context=function()return ctx end
local calls={};a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={action=action,purpose=purpose};return true end,Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}
u:Refresh();local other={id=995902,name="Fresh selected",minLevel=1,requirementsKnown=true,start={npcID=83,name="Fresh pickup",zoneName="Ironforge",mapID=1455,x=25,y=35},finish=q.finish};a.quests[other.id]=other;d.quests[2]=other.id
local l=a.L;local german=a.locales.deDE.DETAIL_GIVER;local english=a.locales.enUS.DETAIL_GIVER
local function draw(active,key,mutate,want)
 a.db.locale=active;u.quest=q.id;u:Refresh();u.quest=other.id
 local fired=false;a.L=function(k,...)if k==key and not fired then fired=true;mutate()end;return l(k,...)end
 u:RefreshDetail();a.L=l
 assert(fired,"contact localization actually ran")
 local row=u.detailContactRows[1];local fresh=row and row:IsShown()and row.title.text:find("Fresh pickup",1,true)
 assert((fresh and true or false)==want,"fresh contact locale publication "..active)
 a.locales.deDE.DETAIL_GIVER=german;a.locales.enUS.DETAIL_GIVER=english
end
draw("enUS","DETAIL_GIVER",function()a.locales.deDE.DETAIL_GIVER="Unused changed"end,true)
draw("enUS","DETAIL_GIVER",function()a.locales.enUS.DETAIL_GIVER="Active changed"end,false)
a.locales.deDE.DETAIL_GIVER="Eigen";german="Eigen"
draw("deDE","DETAIL_GIVER",function()a.locales.enUS.DETAIL_GIVER="Unused English changed"end,true)
a.locales.deDE.DETAIL_GIVER=nil;german=nil
draw("deDE","DETAIL_GIVER",function()a.locales.enUS.DETAIL_GIVER="Fallback changed"end,false)
print("PASS fresh contact copy owns only selected locale and actually consulted English fallback")

end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local q={id=995901,name="Contact selected",minLevel=1,requirementsKnown=true,start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20},finish={npcID=82,name="Finish actor",zoneName="Stormwind City",mapID=1453,x=30,y=40}}
a.quests[q.id]=q;local d={key="contacts",name="Contacts",minLevel=1,maxLevel=60,quests={q.id}};a.dungeons={d};u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,q.id,q.id,d
local ctx={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end};a.Context=function()return ctx end
local calls={};a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={action=action,purpose=purpose};return true end,Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}
local other={id=995902,name="Newer selected",minLevel=1,requirementsKnown=true,start={npcID=83,name="Newer pickup",zoneName="Ironforge",mapID=1455,x=25,y=35},finish=q.finish};a.quests[other.id]=other;d.quests[2]=other.id
local creator=CreateFrame;local orphan,fired;local armed=true
CreateFrame=function(kind,name,parent,...)
 local object=creator(kind,name,parent,...)
 if kind=="Button"and parent==u.detail then
  local setter=object.SetSize
  object.SetSize=function(self,w,h,...)
   if armed and h==52 then
    armed=false;orphan=object;object:Show();fired=true;u.quest=other.id;u:Refresh()
   end
   return setter(self,w,h,...)
  end
 end
 return object
end
u:Refresh()
assert(fired and orphan and not orphan:IsShown(),"detached retired contact creation must be hidden")
assert(u.quest==other.id and u.detailContactRows[1]:IsShown()and u.detailContactRows[1].title.text:find("Newer pickup",1,true),"newer row survives initial creation reentry")
print("PASS detached source creation retires orphan and preserves newer selection")

end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local q={id=995901,name="Contact selected",minLevel=1,requirementsKnown=true,start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20},finish={npcID=82,name="Finish actor",zoneName="Stormwind City",mapID=1453,x=30,y=40}}
a.quests[q.id]=q;local d={key="contacts",name="Contacts",minLevel=1,maxLevel=60,quests={q.id}};a.dungeons={d};u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,q.id,q.id,d
local ctx={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end};a.Context=function()return ctx end
local calls={};a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={action=action,purpose=purpose};return true end,Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}
u:Refresh()
local rows=assert(u.detailContactRows,"full row pool missing");local s,t=assert(rows[1],"start row absent"),assert(rows[2],"finish row absent")
assert(s:IsShown()and t:IsShown()and s.enabled and t.enabled,"both actual contacts visible and navigable")
assert(s.title.text:find("Pickup actor",1,true)and s.note.text=="Westfall","start owns name+zone")
assert(t.title.text:find("Finish actor",1,true)and t.note.text=="Stormwind City","finish owns name+zone")
assert(s.width==u.detail:GetWidth()-8 and t.width==s.width and s.height>=52,"whole rows have measured layout")
local selected,tree=u.quest,u.questTreeRoot;s.scripts.OnClick();assert(#calls==1 and calls[1].action.place==q.start and calls[1].purpose=="quest-start")
t.scripts.OnClick();assert(#calls==2 and calls[2].action.place==q.finish and calls[2].action.kind=="visit"and calls[2].purpose==nil,"finish visits neutrally")
assert(u.quest==selected and u.questTreeRoot==tree,"row clicks preserve selected quest/root")
assert(not u.giver:IsShown(),"no duplicate oldgiver arrow")
print("PASS two own-name/zone full-width rows; neutral finish and quest-start; selected identity retained; old arrow absent")
q.start.zoneName=nil;q.finish.zoneName=nil
local maps={};C_Map.GetMapInfo=function(id)maps[id]=true;if id==1436 then return {name="Own Westfall"}elseif id==1453 then return {name="Own Stormwind"}else return {name="Other native map"}end end
u:Refresh()
assert(u.detailContactRows[1].note.text=="Own Westfall"and u.detailContactRows[2].note.text=="Own Stormwind","native fallback uses each ownsource map")
assert(maps[1436]and maps[1453],"both ownmap lookups ran")
print("PASS exact ownmap nativefallback preserved without cross-contact borrowing")

end


-- Each contact needs its captured method; the opposite method grants no action.
do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local q={id=995901,name="Contact selected",minLevel=1,requirementsKnown=true,start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20},finish={npcID=82,name="Finish actor",zoneName="Stormwind City",mapID=1453,x=30,y=40}}
a.quests[q.id]=q;local d={key="contacts",name="Contacts",minLevel=1,maxLevel=60,quests={q.id}};a.dungeons={d};u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,q.id,q.id,d
local ctx={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end};a.Context=function()return ctx end
local calls={};a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={action=action,purpose=purpose};return true end,Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}
q.start.x=nil;q.start.y=nil;
a.Navigation.Start=nil;
u:Refresh();local row=assert(u.detailContactRows[1]);local model=assert(row.detailContactBinding);assert(row:IsShown());assert(model.action and row.enabled and row.scripts.OnClick);row.scripts.OnClick();assert(#calls==1);print("PASS start_Map_present")
end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local q={id=995901,name="Contact selected",minLevel=1,requirementsKnown=true,start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20},finish={npcID=82,name="Finish actor",zoneName="Stormwind City",mapID=1453,x=30,y=40}}
a.quests[q.id]=q;local d={key="contacts",name="Contacts",minLevel=1,maxLevel=60,quests={q.id}};a.dungeons={d};u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,q.id,q.id,d
local ctx={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end};a.Context=function()return ctx end
local calls={};a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={action=action,purpose=purpose};return true end,Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}
q.start.x=nil;q.start.y=nil;
a.Navigation.Map=nil;
u:Refresh();local row=assert(u.detailContactRows[1]);local model=assert(row.detailContactBinding);assert(row:IsShown());assert(model.action==nil and model.purpose==nil and model.reason=="NAVIGATION_UNAVAILABLE" and not row.enabled and row.scripts.OnClick==nil);assert(not model.dispatch() and #calls==0);print("PASS start_Map_missing")
end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local q={id=995901,name="Contact selected",minLevel=1,requirementsKnown=true,start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20},finish={npcID=82,name="Finish actor",zoneName="Stormwind City",mapID=1453,x=30,y=40}}
a.quests[q.id]=q;local d={key="contacts",name="Contacts",minLevel=1,maxLevel=60,quests={q.id}};a.dungeons={d};u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,q.id,q.id,d
local ctx={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end};a.Context=function()return ctx end
local calls={};a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={action=action,purpose=purpose};return true end,Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}
a.Navigation.Map=nil;
u:Refresh();local row=assert(u.detailContactRows[1]);local model=assert(row.detailContactBinding);assert(row:IsShown());assert(model.action and row.enabled and row.scripts.OnClick);row.scripts.OnClick();assert(#calls==1);print("PASS start_Start_present")
end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local q={id=995901,name="Contact selected",minLevel=1,requirementsKnown=true,start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20},finish={npcID=82,name="Finish actor",zoneName="Stormwind City",mapID=1453,x=30,y=40}}
a.quests[q.id]=q;local d={key="contacts",name="Contacts",minLevel=1,maxLevel=60,quests={q.id}};a.dungeons={d};u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,q.id,q.id,d
local ctx={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end};a.Context=function()return ctx end
local calls={};a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={action=action,purpose=purpose};return true end,Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}
a.Navigation.Start=nil;
u:Refresh();local row=assert(u.detailContactRows[1]);local model=assert(row.detailContactBinding);assert(row:IsShown());assert(model.action==nil and model.purpose==nil and model.reason=="NAVIGATION_UNAVAILABLE" and not row.enabled and row.scripts.OnClick==nil);assert(not model.dispatch() and #calls==0);print("PASS start_Start_missing")
end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local q={id=995901,name="Contact selected",minLevel=1,requirementsKnown=true,start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20},finish={npcID=82,name="Finish actor",zoneName="Stormwind City",mapID=1453,x=30,y=40}}
a.quests[q.id]=q;local d={key="contacts",name="Contacts",minLevel=1,maxLevel=60,quests={q.id}};a.dungeons={d};u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,q.id,q.id,d
local ctx={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end};a.Context=function()return ctx end
local calls={};a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={action=action,purpose=purpose};return true end,Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}
q.finish.x=nil;q.finish.y=nil;
a.Navigation.Start=nil;
u:Refresh();local row=assert(u.detailContactRows[2]);local model=assert(row.detailContactBinding);assert(row:IsShown());assert(model.action and row.enabled and row.scripts.OnClick);row.scripts.OnClick();assert(#calls==1);print("PASS finish_Map_present")
end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local q={id=995901,name="Contact selected",minLevel=1,requirementsKnown=true,start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20},finish={npcID=82,name="Finish actor",zoneName="Stormwind City",mapID=1453,x=30,y=40}}
a.quests[q.id]=q;local d={key="contacts",name="Contacts",minLevel=1,maxLevel=60,quests={q.id}};a.dungeons={d};u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,q.id,q.id,d
local ctx={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end};a.Context=function()return ctx end
local calls={};a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={action=action,purpose=purpose};return true end,Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}
q.finish.x=nil;q.finish.y=nil;
a.Navigation.Map=nil;
u:Refresh();local row=assert(u.detailContactRows[2]);local model=assert(row.detailContactBinding);assert(row:IsShown());assert(model.action==nil and model.purpose==nil and model.reason=="NAVIGATION_UNAVAILABLE" and not row.enabled and row.scripts.OnClick==nil);assert(not model.dispatch() and #calls==0);print("PASS finish_Map_missing")
end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local q={id=995901,name="Contact selected",minLevel=1,requirementsKnown=true,start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20},finish={npcID=82,name="Finish actor",zoneName="Stormwind City",mapID=1453,x=30,y=40}}
a.quests[q.id]=q;local d={key="contacts",name="Contacts",minLevel=1,maxLevel=60,quests={q.id}};a.dungeons={d};u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,q.id,q.id,d
local ctx={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end};a.Context=function()return ctx end
local calls={};a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={action=action,purpose=purpose};return true end,Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}
a.Navigation.Map=nil;
u:Refresh();local row=assert(u.detailContactRows[2]);local model=assert(row.detailContactBinding);assert(row:IsShown());assert(model.action and row.enabled and row.scripts.OnClick);row.scripts.OnClick();assert(#calls==1);print("PASS finish_Start_present")
end

do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local q={id=995901,name="Contact selected",minLevel=1,requirementsKnown=true,start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20},finish={npcID=82,name="Finish actor",zoneName="Stormwind City",mapID=1453,x=30,y=40}}
a.quests[q.id]=q;local d={key="contacts",name="Contacts",minLevel=1,maxLevel=60,quests={q.id}};a.dungeons={d};u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,q.id,q.id,d
local ctx={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end};a.Context=function()return ctx end
local calls={};a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={action=action,purpose=purpose};return true end,Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}
a.Navigation.Start=nil;
u:Refresh();local row=assert(u.detailContactRows[2]);local model=assert(row.detailContactBinding);assert(row:IsShown());assert(model.action==nil and model.purpose==nil and model.reason=="NAVIGATION_UNAVAILABLE" and not row.enabled and row.scripts.OnClick==nil);assert(not model.dispatch() and #calls==0);print("PASS finish_Start_missing")
end

-- Native names remain available in the supported getter fallback.
do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local q={id=995901,name="Contact selected",minLevel=1,requirementsKnown=true,start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20},finish={npcID=82,name="Finish actor",zoneName="Stormwind City",mapID=1453,x=30,y=40}}
a.quests[q.id]=q;local d={key="contacts",name="Contacts",minLevel=1,maxLevel=60,quests={q.id}};a.dungeons={d};u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,q.id,q.id,d
local ctx={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end};a.Context=function()return ctx end
local calls={};a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={action=action,purpose=purpose};return true end,Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}
a.SourceName=nil
local names={[81]="Native pickup",[82]="Native finish"};local objectCalls,itemCalls=0,0
local getter=function(point)
 if point.objectID then objectCalls=objectCalls+1 end
 if point.itemID then itemCalls=itemCalls+1 end
 return names[point.npcID]
end
a.GiverName=getter;u:Refresh()
assert(u.detailContactRows[1].title.text:find("Native pickup",1,true)and u.detailContactRows[2].title.text:find("Native finish",1,true),"missing SourceName retains live native GiverName labels")
names[81],names[82]="Updated pickup","Updated finish";u:RefreshDetail()
assert(u.detailContactRows[1].title.text:find("Updated pickup",1,true)and u.detailContactRows[2].title.text:find("Updated finish",1,true),"native labels refresh without replacing sourcepoints")
q.finish.npcID=nil;q.finish.objectID=82;u:RefreshDetail();assert(objectCalls==0 and u.detailContactRows[2].title.text:find("Finish actor",1,true),"objects never call NPC getter")
q.start={itemID=880001,name="Starter item"};a.ItemName=function()return "Item label"end;u:RefreshDetail();assert(itemCalls==0 and not u.detailContactRows[1]:IsShown(),"item starts never call NPC getter")
q.start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20};q.finish.objectID=nil;q.finish.npcID=82
local preferredCalls=0;a.SourceName=function(point)return "Preferred "..point.name,function()return true end,function()return true end end
a.GiverName=function(point)preferredCalls=preferredCalls+1;return getter(point)end;u:RefreshDetail()
assert(u.detailContactRows[1].title.text:find("Preferred Pickup actor",1,true)and preferredCalls==0,"usable SourceName remains preferred")
a.SourceName=nil;a.GiverName=getter;u:RefreshDetail();local retained=u.detailContactRows[1].scripts.OnClick
local clean,read=a.Clean,a.Read;local foreign=0;local fired=false
local bad=function()foreign=foreign+1;error("replaced helper invoked")end
a.GiverName=function(point)if not fired then fired=true;a.Clean=bad;a.Read=bad end;return "Retired native label"end
local ok=pcall(u.RefreshDetail,u);a.Clean,a.Read=clean,read;a.GiverName=getter
assert(ok and fired and foreign==0,"native getter callback cannot invoke replaced helpers")
local n=#calls;retained();assert(#calls==n,"native getter refresh retires previous row clicks")
u:RefreshDetail();assert(u.detailContactRows[1]:IsShown()and u.detailContactRows[1].title.text:find("Updated pickup",1,true),"fresh native fallback recovers")
print("PASS preferred SourceName, absentSourceName live native fallback, object/item isolation and callback helper replacement")

end
do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local q={id=995901,name="Contact selected",minLevel=1,requirementsKnown=true,start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20},finish={npcID=82,name="Finish actor",zoneName="Stormwind City",mapID=1453,x=30,y=40}}
a.quests[q.id]=q;local d={key="contacts",name="Contacts",minLevel=1,maxLevel=60,quests={q.id}};a.dungeons={d};u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,q.id,q.id,d
local ctx={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end};a.Context=function()return ctx end
local calls={};a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={action=action,purpose=purpose};return true end,Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}

q.start.reportedLocations={{mapID=1436,x=11,y=21},{mapID=1436,x=12,y=22},{mapID=1436,x=13,y=23}}
q.finish.reportedLocations={{mapID=1453,x=31,y=41},{mapID=1453,x=32,y=42}}
local function count()local n=0;for _,b in ipairs(u.reportedRows or{})do if b:IsShown()then n=n+1 end end;return n end
local function toggle(k)for _,b in ipairs(u.reportedToggles or{})do if b:IsShown()and b.locationKey==k then return b end end;error('missing toggle')end
u:Refresh();local selected,root=u.quest,u.questTreeRoot
u.detailContactRows[1].scripts.OnClick();assert(count()==3,'own pickup3')
local stale=toggle('start').scripts.OnClick
stale();assert(count()==0 and u.reportedExpanded.start==false,'minus must preserve collapsed own reports')
u:RefreshDetail();assert(count()==0,'redraw preserves minus')
for i=1,2 do toggle('start').scripts.OnClick();assert(count()==3,'plus');toggle('start').scripts.OnClick();assert(count()==0,'minus')end
toggle('start').scripts.OnClick();u.detailContactRows[2].scripts.OnClick();assert(count()==2 and u.detailContactExpanded=='finish','own finish2')
stale();assert(count()==2,'stale minus inert');assert(u.quest==selected and u.questTreeRoot==root,'selected identity')
a.Navigation.Start=function()return false end;u.reportedExpanded.start=false;u:RefreshDetail();u.detailContactRows[1].scripts.OnClick();assert(u.detailContactExpanded=='finish'and u.reportedExpanded.start==false and count()==2,'failed dispatch cannot expand')
local oldclick=u.detailContactRows[2].scripts.OnClick
local q2={id=995902,name='Other',minLevel=1,requirementsKnown=true,start={npcID=83,name='Other start',mapID=1436,x=14,y=24}}
a.quests[q2.id]=q2;d.quests={q.id,q2.id};u.quest,u.questTreeRoot=q2.id,q2.id;u:RefreshDetail();assert(u.detailContactExpanded==nil and count()==0,'quest reset')
oldclick();assert(u.quest==q2.id and u.detailContactExpanded==nil and count()==0,'stale contact inert')
print('PASS minus/plus/redraw/endpoint/quest/failed dispatch/stale controls')

a.Navigation.Start=function()u.quest,u.questTreeRoot=q2.id,q2.id;u:RefreshDetail();return true end
u.quest,u.questTreeRoot=q.id,q.id;u:RefreshDetail();local click=u.detailContactRows[1].scripts.OnClick
click();assert(u.quest==q2.id and u.detailContactExpanded==nil and count()==0,'navigation reentry cannot expand old contact')
print('PASS navigation reentry keeps newer quest disclosure')

end
do
local f=assert(loadfile("tests/client_ui.lua"))("fixture");local a,u=f.addon,f.addon.UI
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
local q={id=995901,name="Contact selected",minLevel=1,requirementsKnown=true,start={npcID=81,name="Pickup actor",zoneName="Westfall",mapID=1436,x=10,y=20},finish={npcID=82,name="Finish actor",zoneName="Stormwind City",mapID=1453,x=30,y=40}}
a.quests[q.id]=q;local d={key="contacts",name="Contacts",minLevel=1,maxLevel=60,quests={q.id}};a.dungeons={d};u.dungeon,u.quest,u.questTreeRoot,u.questTreeDungeon=d,q.id,q.id,d
local ctx={level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end};a.Context=function()return ctx end
local calls={};a.Navigation={Start=function(action,purpose,owner)assert(owner());calls[#calls+1]={action=action,purpose=purpose};return true end,Map=function(point,purpose,id,owner)assert(owner());calls[#calls+1]={point=point,purpose=purpose,id=id};return true end}

q.start=nil
assert(not u.detailContactRows or next(u.detailContactRows)==nil,"finish-only fixture starts with a fresh contact pool")
u:Refresh()
assert(u.detailContactRows[1]==nil,"unknown pickup must not fabricate slot1")
local finish=assert(u.detailContactRows[2]);local binding=assert(finish.detailContactBinding)
assert(finish:IsShown()and finish.enabled and binding.current()and binding.endpoint==q.finish,"fresh slot2-only finisher owns its source")
assert(finish.title.text:find(q.finish.name,1,true)and finish.note.text==q.finish.zoneName,"slot2-only ownname and area visible")
local retained=assert(finish.scripts.OnClick);retained()
assert(#calls==1 and calls[1].action.place==q.finish and calls[1].action.kind=="visit"and calls[1].purpose==nil,"finish-only row visits neutrally")
retained();assert(#calls==1,"retained sparse-pool contact click is inert after redraw")
u.quest=nil;u:RefreshDetail()
assert(not finish:IsShown()and not finish.enabled and finish.scripts.OnClick==nil,"bounded two-slot cleanup retires finisher despite empty slot1")
retained();assert(#calls==1,"hidden sparse-pool contact cannot navigate")
u.quest,u.questTreeRoot=q.id,q.id;u:Refresh()
assert(u.detailContactRows[1]==nil and u.detailContactRows[2]:IsShown()and u.detailContactRows[2].detailContactBinding.current(),"fresh reopen restores only own finisher")
print("PASS fresh finish-only sparse contact pool, neutral route, stale click, bounded hide and reopen")

end
print("Full-row direct contact checks passed (native rendering unverified)")
