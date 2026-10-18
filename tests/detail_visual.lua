-- Offline native-shaped layout capture. Sample prose/rewards are fixture data.
local checking = arg and arg[1] == "check"
local questID, locale, metricsPath = tonumber(arg and arg[1]) or 4764, arg and arg[2] or "enUS", arg and arg[3]
if metricsPath == "" then metricsPath = nil end
local metrics = metricsPath and assert(loadfile(metricsPath))() or {}
local fixture = assert(loadfile("tests/client_ui.lua"))("fixture")
local addon, ui, methods = fixture.addon, fixture.addon.UI, fixture.methods
local requests = {}
local function plain(value)
    return (value or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "[coin]"):gsub("|A.-|a", "")
end
local function metric(self)
    local text, size, width = plain(self.text), self.fontSize or 14, self.width or 340
    local key = size .. "|" .. width .. "|" .. text
    requests[key] = { text = text, size = size, width = width }
    return metrics[key], text, size, width
end
function methods:SetFont(path, size, flags) self.fontPath, self.fontSize, self.fontFlags = path, size, flags; return true end
function methods:GetFont() return self.fontPath or "Media/Fonts/NotoSans-Regular.ttf", self.fontSize or 14, self.fontFlags end
function methods:GetStringHeight()
    local result, text, size, width = metric(self)
    return result and result.height or math.max(size * 1.4, math.ceil(#text * size * .5 / math.max(1, width)) * size * 1.4)
end
function methods:GetStringWidth()
    local result, text, size = metric(self)
    return result and result.width or #text * size * .5
end
function methods:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = {...}; self.point = {...} end
function methods:ClearAllPoints() self.points, self.point = {}, nil end
function methods:SetAllPoints(relative) self.allPoints = relative or self.parent end
function methods:SetTextColor(...) self.textColor = {...} end
function methods:SetColorTexture(...) self.fill = {...} end
function methods:SetBackdropColor(...) self.fill = {...} end
function methods:SetBackdropBorderColor(...) self.border = {...} end
local nativeCreate = CreateFrame
local nativeHide, nativeShow = methods.Hide, methods.Show
function methods:Hide() self.hiddenExplicit = true; return nativeHide(self) end
function methods:Show() self.hiddenExplicit = false; return nativeShow(self) end
CreateFrame = function(kind, name, parent, ...)
    local object = nativeCreate(kind, name, parent, ...); object.parent = parent; return object
end
for _, key in ipairs({"CreateFontString", "CreateTexture"}) do
    local original = methods[key]
    methods[key] = function(self, ...) local object = original(self, ...); object.parent = self; object.shown = true; return object end
end
C_Timer = {After = function() end}
issecretvalue = function() return false end
GetScreenHeight = function() return 900 end
UIParent.width, UIParent.height = 1920, 900
fixture.eventFrame.scripts.OnEvent(fixture.eventFrame, "ADDON_LOADED", "DungeonPro")
addon.db.locale = locale
addon.Description = function()
    if locale == "ruRU" then return string.rep("Отправляйтесь в подземелье, найдите пропавшую реликвию и верните её владельцу. Это пример длинного текста для проверки переноса строк. ", 5) end
    return string.rep("Enter the dungeon, recover the missing relic, and return it to its owner. This sample narrative checks line wrapping and the reading disclosure. ", 5)
end
addon.DialogueText, addon.DialogueRewards, addon.QuestRewards = function() end, function() end, function() end
addon.CachedQuestRewards = function()
    return {source = "cache", items = {{id=7001,name=locale=="ruRU" and "Гарантированная награда" or "Guaranteed reward",count=1,texture=134400}},
        choices = {{id=7002,name=locale=="ruRU" and "Первый вариант награды" or "First reward choice",count=1,texture=134401},
            {id=7003,name=locale=="ruRU" and "Второй вариант награды" or "Second reward choice",count=1,texture=134402}},xp=3450,money=12000}
end
local mapNames = {}
for _, definition in pairs(addon.quests) do
    for _, key in ipairs({"start", "finish"}) do
        local source = definition[key]
        if source and source.mapID and source.zoneName then mapNames[source.mapID] = source.zoneName end
    end
end
C_Map.GetMapInfo = function(id) return {name=mapNames[id] or "Map "..id} end
GetCoinTextureString = function(amount) return amount .. " copper" end
ui:Toggle()
for _, dungeon in ipairs(addon.dungeons) do
    for _, id in ipairs(dungeon.quests) do if id == questID then ui.dungeon = dungeon end end
end
if not ui.dungeon then
    for _, dungeon in ipairs(addon.dungeons) do
        for _, id in ipairs(dungeon.quests) do
            for _, related in ipairs(addon.quests[id].storyline or {}) do if related == questID then ui.dungeon = dungeon end end
        end
    end
end
assert(ui.dungeon and addon.quests[questID], "capture requires a listed quest")
ui.quest = questID; ui:Refresh()
if arg and arg[4] == "collapsed" then
    assert(ui:SetCatalogCollapsed(true) ~= false)
    assert(ui.catalogCollapsed == true and ui.quest == questID)
end
assert(ui.quest == questID and ui.detailScroll:GetWidth() > 300 and ui.detailScroll:GetHeight() > 0)
local visibleRewards = 0
for _, button in ipairs(ui.rewardButtons) do
    if button:IsShown() then
        visibleRewards = visibleRewards + 1
        assert(button.rewardLabel and button.rewardLabel:GetWidth() > 0 and button.rewardTileWidth > 40)
        local raw = button.point
        assert(raw and raw[1] == "TOPLEFT" and type(raw[2]) == "number" and raw[2] >= 0)
        assert(raw[2] + button.rewardTileWidth <= ui.detail:GetWidth() + 8, "reward tile stays within the real content width")
    end
end
assert(visibleRewards == 3, "both choices and the guaranteed reward remain present")
if checking then print("Offline detail geometry: PASS (actual anchors, three reward tiles; native rendering unverified)"); return end
local ids = {}; for index, object in ipairs(fixture.objects) do ids[object] = index end
local function point(raw, owner)
    local relative, anchor, x, y
    if type(raw[2]) == "table" then relative, anchor, x, y = raw[2], raw[3], raw[4], raw[5]
    elseif type(raw[2]) == "number" then relative, anchor, x, y = owner.parent, raw[1], raw[2], raw[3]
    else relative, anchor, x, y = owner.parent, raw[3] or raw[1], raw[4], raw[5] end
    return {anchor=raw[1],relative=ids[relative],relativeAnchor=anchor,x=x or 0,y=y or 0}
end
local objects = {}
for index, object in ipairs(fixture.objects) do
    local row = {id=index,parent=ids[object.parent],kind=object.kind,shown=object.shown==true,width=object.width,height=object.height,
        text=object.text,size=object.fontSize,color=object.textColor,fill=object.fill,border=object.border,texture=object.texture,
        allPoints=ids[object.allPoints],hidden=object.hiddenExplicit==true,points={}}
    for _, raw in ipairs(object.points or {}) do row.points[#row.points+1]=point(raw,object) end
    objects[#objects+1]=row
end
local roles = {}
for _, key in ipairs({"frame","catalogScroll","questScroll","detailScroll","detail","narrativeToggle","referenceToggle","title","giver","source","catalogToggle"}) do roles[key]=ids[ui[key]] end
local function quote(value)
    return '"' .. value:gsub('[%z\1-\31\\"]',function(char)
        local escapes = {['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
        return escapes[char] or string.format('\\u%04x',char:byte())
    end) .. '"'
end
local function json(value)
    if type(value)=="string" then return quote(value) end
    if type(value)=="number" or type(value)=="boolean" then return tostring(value) end
    if type(value)~="table" then return "null" end
    local array = #value>0; local fields={}
    if array then for _,item in ipairs(value)do fields[#fields+1]=json(item)end
    else for key,item in pairs(value)do fields[#fields+1]=quote(tostring(key))..":"..json(item)end;table.sort(fields)end
    return (array and "[" or "{")..table.concat(fields,",")..(array and "]" or "}")
end
print(json({questID=questID,locale=locale,fixtureRewards=true,offline=true,catalogCollapsed=ui.catalogCollapsed==true,objects=objects,roles=roles,metrics=requests}))
