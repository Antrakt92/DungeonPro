-- Scarlet wing planning and unresolved complex discovery are different views.
local f=assert(loadfile("tests/client_ui.lua"))("fixture")
local a,u=f.addon,f.addon.UI
issecretvalue=function()return false end;GetLocale=function()return"enUS"end;C_Timer={After=function()end}
f.eventFrame.scripts.OnEvent(f.eventFrame,"ADDON_LOADED","DungeonPro");u:Toggle();a.db.locale="enUS"
a.Context=function()return{level=60,faction="Alliance",class="MAGE",completed=function()return false end,active=function()return false end}end
local wings={};for _,d in ipairs(a.dungeons)do if d.complexKey=="sm"then wings[#wings+1]=d end end
assert(#wings==4 and #a.dungeons==32,"four real wing cards, no fifth complex dungeon")
local function rows(field)
 local out={};for _,row in ipairs(u.rows)do if row:IsShown()and row[field]then out[#out+1]=row end end;return out
end
local function draw(d,all)
 u.search="";u.dungeon,u.quest=d,nil;a.char.selectedDungeon=d.key;u.includeUnavailable=all
 u.questTreeRoot,u.questTreeDungeon=nil,nil;u:RefreshQuests()
end
local carried=a.CarriedItemCount;local inventory=0
for _,all in ipairs({false,true})do for _,d in ipairs(wings)do
 draw(d,all)
 assert(#rows("sharedDiscovery")==0,"a wing must not repeat unresolved complex quest rows")
 local own={};for _,id in ipairs(d.quests)do own[id]=true end
 for _,row in ipairs(u.rows)do if row:IsShown()and row.questID then assert(own[row.questID],"wing list contains only evidenced own roots")end end
 local links=rows("sharedOverview");assert(#links==1 and links[1].enabled and links[1].scripts.OnClick,"each wing exposes one explicit complex discovery link")
 local old=links[1].scripts.OnClick
 local savedShared=d.sharedQuests[1];d.sharedQuests[1]=995900
 old();assert(u.dungeon==d and a.char.selectedDungeon==d.key and u.quest==nil,"shared source mutation retires an old wing link")
 d.sharedQuests[1]=savedShared;u:RefreshQuests();links=rows("sharedOverview");assert(#links==1);old=links[1].scripts.OnClick
 assert(u.currentPlan and u.currentPlan.unknown and not u.currentPlan.ready,"partial wing never claims fully prepared")
 a.CarriedItemCount=function()inventory=inventory+1;return 0 end
 old();a.CarriedItemCount=carried
 assert(u.dungeon==nil and a.char.selectedDungeon=="sm"and u.quest==nil and u.questTreeRoot==nil,"link opens complex context without wing assignment")
 assert(u.includeUnavailable==all and u.currentPlan==nil,"character filter is preserved; discovery is not a preparation plan")
 local discovered=rows("sharedDiscovery");assert(#discovered==#d.sharedQuests,"complex overview preserves the complete shared discovery index")
 local seen={};for _,row in ipairs(discovered)do assert(not seen[row.questID]);seen[row.questID]=true end
 for _,id in ipairs(d.sharedQuests)do assert(seen[id],"every shared quest remains inspectable once")end
 local count=#discovered;old();assert(u.dungeon==nil and #rows("sharedDiscovery")==count,"retained old wing link is inert")
end end
assert(inventory==0,"opening complex discovery never inspects carried-item counts")
-- Legacy saved complex selection continues to expose the same single discovery view.
u.dungeon,u.quest=nil,nil;a.char.selectedDungeon="sm";u:RefreshQuests()
local shared=rows("sharedDiscovery");assert(#shared==9 and #rows("sharedOverview")==0)
local selected=shared[1].questID;shared[1].scripts.OnClick()
assert(u.quest==selected and u.renderedQuest==selected and u.dungeon==nil and a.char.selectedDungeon=="sm","ordinary inspection retains exact quest identity in complex context")
-- Numeric shared search remains discoverable, but its inspect action never assigns a wing.
local unrelated;for _,d in ipairs(a.dungeons)do for _,id in ipairs(d.quests)do if id==166 then unrelated=d end end end
assert(unrelated and unrelated.complexKey~="sm","unrelated Deadmines target is required for a real search transition")
u.search="";u.dungeon,u.quest=unrelated,166;a.char.selectedDungeon=unrelated.key
u.questTreeRoot,u.questTreeDungeon=nil,nil;u:Refresh()
assert(u.dungeon==unrelated and u.quest==166 and u.renderedQuest==166,"numeric inspection begins on a different actual quest and dungeon")
u.search="96800";u:RefreshDungeons();local inspect
for _,button in ipairs(u.catalogInspectButtons)do if button:IsShown()and button.questID==96800 then inspect=button;break end end
assert(inspect and inspect.scripts.OnClick,"exact unresolved numeric quest remains discoverable")
inspect.scripts.OnClick()
assert(u.quest==96800 and u.dungeon==nil and a.char.selectedDungeon=="sm"and not u.questTreeRoot,"shared search inspection belongs to the complex, not a wing")
local old=inspect.scripts.OnClick;draw(wings[2],false);old();assert(u.dungeon==wings[2]and u.quest==nil,"stale search inspect cannot replace a newer wing")
assert(#a.dungeons==32,"view changes never create a fifth catalogue member")
print("Scarlet discovery view: PASS (four wings, own roots, one link, shared index once, filters, exact search identity, retired callbacks, no inventory reads)")

-- Callback-capable history reset cannot retire a newer context or substitute helpers.
do
 local reset=u.ResetHistoryReading
 local destination;for _,d in ipairs(a.dungeons)do if d.key=="dalaran"then destination=d end end
 assert(destination)
 local function selectedClick(kind)
  draw(wings[1],true)
  if kind=="link"then return assert(rows("sharedOverview")[1].scripts.OnClick)end
  u.search="96800";u:RefreshDungeons()
  for _,button in ipairs(u.catalogInspectButtons)do if button:IsShown()and button.questID==96800 then return assert(button.scripts.OnClick)end end
  error("actual shared search inspect control missing")
 end
 for _,kind in ipairs({"link","search"})do
  local fired=false;local freshHistory={92458}
  u.ResetHistoryReading=function(self,...)
   local result=reset(self,...)
   if not fired then
    fired=true;self.dungeon,self.quest=destination,92459;a.char.selectedDungeon=destination.key
    self.questTreeRoot,self.questTreeDungeon=nil,nil;self.detailHistory=freshHistory;self:Refresh()
   end
   return result
  end
  local click=selectedClick(kind)
  click();u.ResetHistoryReading=reset
  assert(fired and u.dungeon==destination and u.quest==92459 and a.char.selectedDungeon==destination.key,
   "retired "..kind.." cannot overwrite the newer selected context after history-reset reentry")
  assert(u.detailHistory==freshHistory,"retired "..kind.." cannot replace newer reading history")
  local retained=selectedClick(kind);local beforeDungeon,beforeQuest,beforeSaved=u.dungeon,u.quest,a.char.selectedDungeon
  local foreign=0;u.ResetHistoryReading=function()foreign=foreign+1;error("replacement history reset called by an old control")end
  local ok,err=pcall(retained);u.ResetHistoryReading=reset
  assert(ok and foreign==0 and u.dungeon==beforeDungeon and u.quest==beforeQuest and a.char.selectedDungeon==beforeSaved,
   "old "..kind.." retains only its original reset capability: "..tostring(err))
  for _,mode in ipairs({"detail-refresh","history"})do
   local invoked=false;local callbackGeneration;local newerHistory={92459}
   u.ResetHistoryReading=function(self,...)
    local result=reset(self,...)
    if not invoked then
     invoked=true
     if mode=="detail-refresh"then self:RefreshDetail();callbackGeneration=self.rewardGeneration
     else self.detailHistory=newerHistory end
    end
    return result
   end
   local retained=selectedClick(kind)
   local previousDungeon,previousQuest,previousSaved=u.dungeon,u.quest,a.char.selectedDungeon
   retained();u.ResetHistoryReading=reset
   assert(invoked and u.dungeon==previousDungeon and u.quest==previousQuest and a.char.selectedDungeon==previousSaved,
    "retired "..kind.." cannot supersede "..mode.." in the same selected context")
   if mode=="detail-refresh"then assert(u.rewardGeneration==callbackGeneration,"newer detail render generation remains owned")
   else assert(u.detailHistory==newerHistory,"newer same-context reading history remains owned")end
  end
 end
end
print("PASS Scarlet link/search reset reentry, helper replacement, same-context detail refresh and history retirement")
