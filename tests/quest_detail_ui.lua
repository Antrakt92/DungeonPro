local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui = fixture.addon
function fixture.methods:SetFont(path, size, flags) self.fontPath, self.fontSize, self.fontFlags = path, size, flags; return true end
function fixture.methods:GetFont() return self.fontPath, self.fontSize, self.fontFlags end
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
SlashCmdList.DUNGEONPRO("")
ui = addon.UI
local dungeon
for _, value in ipairs(addon.dungeons) do if value.key == "dm" then dungeon = value end end
assert(dungeon)
-- Exercise a source-listed cost independently from positive reward currency.
local definition = {}
for key, value in pairs(addon.quests[166]) do definition[key] = value end
definition.requiredMoney = 123
addon.quests[166] = definition
local description, rewardDTO = "A short complete story.", nil
addon.Description = function() return description end
addon.DialogueText = function() return nil end
addon.DialogueRewards = function() return nil end
addon.QuestRewards = function() return nil end
addon.CachedQuestRewards = function() return rewardDTO end
addon.QuestPayment = function() return {amount=123,formatted="PAYMENT123"} end
GetCoinTextureString = function(value) return "COINS" .. value end
local function render(id, locale)
 addon.db.locale = locale or "enUS"
 ui.dungeon, ui.quest = dungeon, id or 166
 ui:Refresh()
end
local function lines()
 local result={}
 for _, fs in ipairs(ui.details) do if fs:IsShown() then result[#result+1]=fs end end
 return result
end
local function exact(value)
 for _,fs in ipairs(lines())do if fs.text==value then return fs end end
end
local function contains(value)
 for _,fs in ipairs(lines())do if fs.text and fs.text:find(value,1,true)then return fs end end
end
local function count(value)
 local n=0;for _,fs in ipairs(lines())do if fs.text==value then n=n+1 end end;return n
end
local function storyBody()
 local heading=exact(addon.L("DETAIL_STORY"));assert(heading,"separate story caption")
 local list=lines();for index,fs in ipairs(list)do if fs==heading then return list[index+1]end end
 error("missing story body")
end
local function validUTF8(text)
 local offset=1
 while offset<=#text do
  local lead=text:byte(offset)
  local size=lead<128 and 1 or (lead>=194 and lead<=223 and 2) or (lead>=224 and lead<=239 and 3) or (lead>=240 and lead<=244 and 4)
  if not size then return false end
  for index=offset+1,offset+size-1 do local byte=text:byte(index);if not byte or byte<128 or byte>191 then return false end end
  offset=offset+size
 end
 return true
end
render()
assert(exact(addon.QuestName(166)).fontSize==22,"quest title uses distinct display size")
assert(contains(addon.L("DETAIL_LEVEL",addon.quests[166].level)).fontSize==13)
assert(contains(addon.L("DETAIL_MIN_LEVEL",addon.quests[166].minLevel)).fontSize==13)
assert(exact(addon.L("DETAIL_GIVER")) and count(addon.L("DETAIL_GIVER"))==1)
assert(exact(addon.L("DETAIL_GIVER")).fontSize==13)
assert(storyBody().text==description and storyBody().fontSize==14)
assert(not ui.narrativeToggle or not ui.narrativeToggle:IsShown(),"short story is complete without disclosure")
assert(not contains(addon.L("REWARD_UNAVAILABLE")) and not contains(addon.L("NO_TEXT")))

rewardDTO={source="cache",items={{id=7001,name="Guaranteed blade",texture=134400,count=2}},
 choices={{id=8001,name="Choose staff",texture=134401,count=1},{id=8002,name="Choose wand",texture=134402,count=1}},xp=777,money=456}
render()
assert(exact(addon.L("DETAIL_REWARDS")) and count(addon.L("DETAIL_REWARDS"))==1)
assert(exact(addon.L("DETAIL_REWARDS")).fontSize==13)
assert(contains("Guaranteed blade") and contains("Choose staff") and contains("Choose wand"))
assert(exact(addon.L("REWARD_CHOICES")),"choose-one group remains explicit")
assert(contains("777") and contains("COINS456"))
assert(contains("PAYMENT123") and not contains("PAYMENT123").text:find("COINS456",1,true),"cost stays separate from rewards")
local rewardCount=0;for _,button in ipairs(ui.rewardButtons)do if button:IsShown()then rewardCount=rewardCount+1 end end
assert(rewardCount==3 and ui.quest==166,"all reward items survive compact presentation")

local stale
for _,locale in ipairs({"ruRU","zhCN","koKR"})do
 local unit=locale=="ruRU" and "История " or locale=="zhCN" and "冒险故事" or "모험이야기"
 description=string.rep(unit,100)
 render(166,locale)
 local body=storyBody();assert(body.text~=description and body.text:sub(-3)=="…" and #body.text<#description)
 assert(validUTF8(body.text),"excerpt ends at a complete UTF-8 codepoint")
 assert(not body.text:find("\239\191\189",1,true),"excerpt never introduces replacement characters")
 assert(ui.narrativeToggle and ui.narrativeToggle:IsShown())
 stale=ui.narrativeToggle.scripts.OnClick
 stale();assert(ui.quest==166 and storyBody().text==description)
 ui.narrativeToggle.scripts.OnClick();assert(storyBody().text~=description)
end
render(214,"enUS");stale();assert(ui.quest==214 and not ui.detailNarrativeExpanded,"stale disclosure cannot expand another quest")
render(166)
ui.narrativeToggle.scripts.OnClick();assert(ui.detailNarrativeExpanded)
local priorDungeon=dungeon
for _,candidate in ipairs(addon.dungeons)do if candidate~=priorDungeon then ui.dungeon=candidate;break end end
ui:Refresh()
assert(not ui.detailNarrativeExpanded,"the same quest in a different dungeon starts collapsed")
render(166)
ui.narrativeToggle.scripts.OnClick();assert(ui.detailNarrativeExpanded)
ui.frame:Hide();ui.frame.scripts.OnHide(ui.frame);ui.frame:Show();ui:Refresh()
assert(not ui.detailNarrativeExpanded,"closing the window resets expanded narrative reading")

description="|cffffffff" .. string.rep("Markup-safe story ",50) .. "|r"
render(166)
assert(storyBody().text==description,"markup is retained whole instead of broken by truncation")
description=nil;rewardDTO={source="cache",items={},choices={},xp=0,money=0}
render()
assert(not exact(addon.L("DETAIL_STORY_EMPTY")) and not exact(addon.L("DETAIL_STORY")), "unavailable lore does not create an empty section")
assert(not exact(addon.L("NO_TEXT")) and not exact(addon.L("REWARD_NO_ITEMS")) and not exact(addon.L("REWARD_UNAVAILABLE")))
assert(not ui.narrativeToggle:IsShown())
assert(not ui.referenceToggle or not ui.referenceToggle:IsShown(), "decorative portraits do not create an acquisition disclosure")
assert(not ui.storyToggle or not ui.storyToggle:IsShown(), "story chains are not duplicated in the detail pane")
assert(ui.quest==166)
print("Actual quest detail: PASS (hierarchy, metadata, grouped rewards, safe narrative disclosure, stale state, quiet empty data)")
