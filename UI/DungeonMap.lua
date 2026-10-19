local _, addon = ...
local UI = {}
addon.DungeonMapUI = UI

-- Map artwork is requested only by an explicit open or floor change.
local function paint(self, dungeon, requestedMapID, inputCurrent)
    local intent = {}; self.dungeonMapIntent = intent
    local frame, scroll, quest, selected, character = self.frame, self.detailScroll, self.quest, self.dungeon, addon.char
    local db, locale, language = addon.db, addon.db and addon.db.locale, addon.Language
    local session = language and language.session
    local preview = session and session.preview
    local localeGetter = GetLocale
    local theme, writer = addon.Theme, self.QuestListWrite
    local font = theme and theme.ApplyFont
    local provider, clean, read, checker, localizer = addon.DungeonMapSnapshot, addon.Clean, addon.Read, issecretvalue, addon.L
    local state = { dungeon = dungeon, requestedMapID = requestedMapID, elapsed = 0 }
    self.dungeonMapState = state
    local function same()
        return inputCurrent() and addon.UI == self and self.dungeonMapIntent == intent and self.dungeonMapState == state and
            self.frame == frame and self.detailScroll == scroll and self.quest == quest and self.dungeon == selected and
            addon.char == character and addon.db == db and (not db or db.locale == locale) and addon.Language == language and
            (not language or language.session == session) and (not session or session.preview == preview) and addon.DungeonMapSnapshot == provider and
            addon.Clean == clean and addon.Read == read and issecretvalue == checker and addon.L == localizer and
            GetLocale == localeGetter and addon.Theme == theme and (not theme or theme.ApplyFont == font) and
            self.QuestListWrite == writer and (not state.overlay or self.dungeonMap == state.overlay)
    end
    state.same = same
    local function raw()
        if not same() then return false end
        if state.raw then
            local ok, fresh = pcall(state.raw)
            if not ok or fresh ~= true then return false end
        end
        return same()
    end
    local function current()
        if not raw() or read(frame.IsShown, "boolean", frame) ~= true or not raw() then return false end
        if state.proof and read(state.proof, "boolean") ~= true then return false end
        return raw()
    end
    state.current = current
    local function write(object, method, ...)
        return object and writer(self, object, method, raw, ...)
    end
    if not frame or not scroll or dungeon ~= selected or not same() then return false end
    local overlay = self.dungeonMap
    if not overlay then
        overlay = CreateFrame("Frame", nil, frame)
        if not same() then overlay:Hide(); return false end
        overlay.tiles = {}
        overlay.background = overlay:CreateTexture(nil,"BACKGROUND")
        overlay.background:SetAllPoints(overlay)
        overlay.background:SetColorTexture(.035,.05,.055,1)
        local function label(size)
            local fs = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetJustifyH("LEFT"); fs:SetWidth(360)
            return fs
        end
        overlay.title, overlay.shared, overlay.floor, overlay.message = label(16), label(12), label(13), label(13)
        local function button()
            local b = CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
            b:SetSize(170, 26); b.label = b:CreateFontString(nil,"OVERLAY","GameFontNormal")
            b.label:SetAllPoints(b); b.label:SetJustifyH("CENTER")
            return b
        end
        overlay.back, overlay.retry, overlay.previous, overlay.next = button(), button(), button(), button()
        overlay:EnableMouse(true)
        overlay:Hide()
        if not same() then return false end
        self.dungeonMap = overlay
    end
    state.overlay = overlay
    if not raw() then return false end
    if not write(overlay,"Hide") then return false end
    if not write(overlay,"ClearAllPoints") or not write(overlay,"SetPoint","TOPLEFT",scroll,"TOPLEFT",0,0) then return false end
    local width, height = read(scroll.GetWidth,"number",scroll), read(scroll.GetHeight,"number",scroll)
    if not raw() then return false end
    if not width or not height or width < 80 or height < 180 then self:CloseDungeonMap(true); return false end
    if not write(overlay,"SetSize",width,height) then return false end
    for _, texture in ipairs(overlay.tiles) do
        if not write(texture,"Hide") or not write(texture,"SetTexture",nil) then return false end
    end
    for _, control in ipairs({overlay.back,overlay.retry,overlay.previous,overlay.next}) do
        if not write(control,"Hide") or not write(control,"SetScript","OnClick",nil) then return false end
    end
    for _, fs in ipairs({overlay.title,overlay.shared,overlay.floor,overlay.message}) do
        if not write(fs,"SetText","") or not write(fs,"Hide") then return false end
    end
    local function text(fs,value,x,y,size)
        if not raw() then return false end
        if font then pcall(font,fs,size) end
        if not raw() then return false end
        return write(fs,"ClearAllPoints") and write(fs,"SetPoint","TOPLEFT",overlay,"TOPLEFT",x,-y) and
            write(fs,"SetWidth",width-x-12) and write(fs,"SetText",value) and write(fs,"Show")
    end
    local function measured(fs, minimum)
        local height = read(fs.GetStringHeight,"number",fs)
        if not raw() then return nil end
        return height and height >= 0 and math.max(minimum,height) or minimum
    end
    local function caption(key,...)
        local value = read(localizer,"string",key,...)
        if raw() then return value or key end
    end
    local function control(b,key,x,y,fn,enabled,clickCurrent)
        if not write(b,"ClearAllPoints") or not write(b,"SetPoint","TOPLEFT",overlay,"TOPLEFT",x,-y) or
            not write(b,"SetWidth",(width-36)/2) then return false end
        local value = caption(key)
        if not value or not write(b.label,"SetText",value) then return false end
        if font then pcall(font,b.label,12) end
        if not raw() or not write(b,"SetScript","OnClick",function() if (clickCurrent or current)() then fn() end end) or
            not write(b,"SetEnabled",enabled) then return false end
        return write(b,"Show")
    end
    local function backCurrent()
        return addon.UI==self and self.dungeonMapIntent==intent and self.dungeonMapState==state and
            self.dungeonMap==overlay and self.frame==frame and self.detailScroll==scroll
    end
    if not control(overlay.back,"DUNGEON_MAP_BACK",12,8,function() self:CloseDungeonMap() end,true,backCurrent) then return false end
    local model, proof, rawProof
    if clean(provider,"function") and current() then
        local ok; ok,model,proof,rawProof = pcall(provider,dungeon,requestedMapID,current)
        if not ok then model=nil end
    end
    if not same() then return false end
    local valid = clean(model,"table") and clean(proof,"function") and clean(rawProof,"function")
    if valid then
        state.proof, state.raw = proof, rawProof
        valid = current()
    end
    local function integer(value)
        local n = clean(value,"number")
        return n and n > 0 and n % 1 == 0 and n <= 9007199254740991 and n or nil
    end
    local w,h,tw,th,cols,rows,tiles,floors,mapID
    local tileView, floorView = {}, {}
    if valid then
        w,h,tw,th = integer(model.width),integer(model.height),integer(model.tileWidth),integer(model.tileHeight)
        cols,rows = integer(model.columns),integer(model.rows)
        tiles,floors = clean(model.textures,"table"),clean(model.floors,"table")
        mapID = integer(model.mapID)
        valid = mapID and w and h and tw and th and cols and rows and cols*rows <= 256 and
            math.ceil(w/tw)==cols and math.ceil(h/th)==rows and tiles and floors and #tiles==cols*rows and #floors<=32
        if valid then
            for i=1,#tiles do
                tileView[i]=integer(tiles[i]);if not tileView[i] then valid=false;break end
            end
            for i=1,#floors do
                local f=clean(floors[i],"table")
                local id=f and integer(f.mapID)
                if not id then valid=false;break end
                floorView[i]={mapID=id,name=clean(f.name,"string")}
            end
        end
        valid = valid and current()
    end
    if not valid then
        if not same() then return false end
        state.proof, state.raw = nil,nil
        if not control(overlay.retry,"DUNGEON_MAP_RETRY",width/2+6,8,function() self:OpenDungeonMap(dungeon,requestedMapID) end,true) or
            not text(overlay.title,caption("DUNGEON_MAP_OPEN"),12,44,16) or
            not text(overlay.message,caption("DUNGEON_MAP_UNAVAILABLE"),12,80,13) or
            not write(overlay,"SetScript","OnUpdate",nil) or not write(scroll,"Hide") or not write(overlay,"Show") then return false end
        state.complete = raw()
        return false
    end
    state.model = model
    local title = clean(model.name,"string")
    if not title or not title:find("%S") then title=caption("DUNGEON_MAP_OPEN") end
    if not text(overlay.title,title,12,44,16) then return false end
    local titleHeight=measured(overlay.title,20)
    if not titleHeight then return false end
    local top = 44+titleHeight+8
    if clean(model.shared,"boolean") == true then
        if not text(overlay.shared,caption("DUNGEON_MAP_SHARED"),12,top,12) then return false end
        local sharedHeight=measured(overlay.shared,16)
        if not sharedHeight then return false end
        top=top+sharedHeight+8
    end
    local index
    for i=1,#floorView do if floorView[i].mapID==mapID then index=i end end
    if not index and not (#floorView==0 and integer(model.baseMapID)==mapID) then self:CloseDungeonMap(true); return false end
    if #floorView>1 then
        local name=floorView[index].name
        if not name or not name:find("%S") then name=caption("DUNGEON_MAP_FLOOR",index) end
        if not text(overlay.floor,name,12,top,13) then return false end
        local floorHeight=measured(overlay.floor,18)
        if not floorHeight then return false end
        top=top+floorHeight+6
        if not control(overlay.previous,"DUNGEON_MAP_PREVIOUS",12,top,function() self:OpenDungeonMap(dungeon,floorView[index-1].mapID) end,index>1) or
            not control(overlay.next,"DUNGEON_MAP_NEXT",width/2+6,top,function() self:OpenDungeonMap(dungeon,floorView[index+1].mapID) end,index<#floorView) then return false end
        top=top+36
    end
    local scale=math.min((width-24)/w,(height-top-12)/h)
    if scale<=0 then self:CloseDungeonMap(true);return false end
    local left=12+((width-24)-w*scale)/2
    local artTop=top+((height-top-12)-h*scale)/2
    for i=1,#tileView do
        local texture=overlay.tiles[i]
        if not texture then
            texture=overlay:CreateTexture(nil,"ARTWORK")
            if not raw() then return false end
            overlay.tiles[i]=texture
        end
        local col,row=(i-1)%cols,math.floor((i-1)/cols)
        local cw,ch=math.min(tw,w-col*tw),math.min(th,h-row*th)
        if not write(texture,"ClearAllPoints") or not write(texture,"SetPoint","TOPLEFT",overlay,"TOPLEFT",left+col*tw*scale,-artTop-row*th*scale) or
            not write(texture,"SetSize",cw*scale,ch*scale) or not write(texture,"SetTexCoord",0,cw/tw,0,ch/th) or
            not write(texture,"SetTexture",tileView[i]) or not write(texture,"Show") then return false end
    end
    if not current() then if same() then self:CloseDungeonMap(true) end;return false end
    if not write(overlay,"SetScript","OnUpdate",function(_,elapsed)
        if self.dungeonMapState ~= state then return end
        if not same() then self:CloseDungeonMap(true); return end
        local delta=clean(elapsed,"number")
        if not delta or delta<=0 then return end
        state.elapsed=state.elapsed+math.min(delta,.5)
        if state.elapsed>=.5 then
            state.elapsed=0
            if not current() and same() then self:CloseDungeonMap(true) end
        end
    end) or not write(scroll,"Hide") or not write(overlay,"Show") then return false end
    state.complete = current()
    return state.complete
end

function UI:OpenDungeonMap(dungeon, requestedMapID)
    local selected, previous, clean = self.dungeon, self.dungeonMapIntent, addon.Clean
    if type(dungeon) ~= "table" or dungeon ~= selected then return false end
    -- Capture request identity before even the cleaner can invoke client callbacks.
    local instanceID, name, key = rawget(dungeon,"instanceID"), rawget(dungeon,"name"), rawget(dungeon,"key")
    local frame, scroll, quest, tab, character = self.frame, self.detailScroll, self.quest, self.detailTab, addon.char
    local function inputCurrent()
        return addon.UI == self and self.dungeon == selected and self.quest == quest and self.detailTab == tab and
            self.frame == frame and self.detailScroll == scroll and addon.char == character and
            rawequal(rawget(dungeon,"instanceID"),instanceID) and rawequal(rawget(dungeon,"name"),name) and
            rawequal(rawget(dungeon,"key"),key)
    end
    local target = clean(dungeon,"table")
    if not inputCurrent() or addon.Clean ~= clean or self.dungeonMapIntent ~= previous or
        not target or target ~= selected or not frame or not scroll then return false end
    local request = {}; self.dungeonMapRequest = request
    local ok, result = pcall(paint, self, dungeon, requestedMapID, inputCurrent)
    local state = self.dungeonMapState
    if self.dungeonMapRequest == request and state and not state.complete then self:CloseDungeonMap(true) end
    return ok and result == true
end

function UI:CloseDungeonMap(skipRefresh)
    local intent={};self.dungeonMapIntent=intent;self.dungeonMapState=nil
    local overlay,scroll=self.dungeonMap,self.detailScroll
    local function current()return addon.UI==self and self.dungeonMapIntent==intent and self.dungeonMapState==nil and
        self.dungeonMap==overlay and self.detailScroll==scroll end
    local function write(object,method,...)
        if object then return self:QuestListWrite(object,method,current,...) end
        return true
    end
    if overlay then
        if not write(overlay,"Hide") or not write(overlay,"SetScript","OnUpdate",nil) then return false end
        for _,texture in ipairs(overlay.tiles)do
            if not write(texture,"Hide") or not write(texture,"SetTexture",nil)then return false end
        end
        for _,b in ipairs({overlay.back,overlay.retry,overlay.previous,overlay.next})do
            if not write(b,"Hide") or not write(b,"SetScript","OnClick",nil)then return false end
        end
    end
    return write(scroll,"Show")
end

function UI:SyncDungeonMapContext()
    local state=self.dungeonMapState
    if not state then return end
    local fresh=state.same()
    if fresh and state.raw then
        local ok,value=pcall(state.raw)
        fresh=ok and value==true and state.same()
    end
    if not fresh and self.dungeonMapState==state then self:CloseDungeonMap(true) end
end
