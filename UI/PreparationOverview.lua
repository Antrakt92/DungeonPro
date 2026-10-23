local _, addon = ...
local UI = {}
addon.PreparationOverviewUI = UI

-- Pooled physical write records survive; their obsolete render lease does not.
function UI:ReleasePreparationOverview()
    if self.overviewControlReset then self.overviewControlReset.current = nil; self.overviewControlReset = nil end
    local previous = self.overviewBinding
    self.overviewBinding = nil
    if previous then
        previous.released = true
        for _, key in ipairs({ "model", "modelCurrent", "modelRaw", "base", "listCurrent", "listRaw", "engine", "plan", "titles", "starters", "presentation", "geometryWrite", "formatStatus" }) do previous[key] = nil end
    end
end

function UI:ResetPreparationOverviewControls(ownerCurrent)
    local reset, writer = UI.ResetPreparationOverviewControls, self.QuestListWrite
    local function supported()
        return addon.PreparationOverviewUI == UI and self.ResetPreparationOverviewControls == reset and
            UI.ResetPreparationOverviewControls == reset and type(writer) == "function" and self.QuestListWrite == writer
    end
    if not supported() or type(ownerCurrent) ~= "function" or not ownerCurrent() or not supported() then return false end
    for index, row in ipairs(self.actionInspectButtons) do
        local function current()
            return supported() and ownerCurrent() and supported() and self.actionInspectButtons[index] == row
        end
        if not writer(self,row,"Hide",current) or not writer(self,row,"SetEnabled",current,false) or
            not writer(self,row,"SetScript",current,"OnClick",nil) then return false end
        row.overviewStep, row.questID = nil, nil
    end
    self.overviewTexts = self.overviewTexts or {}
    for index, fs in ipairs(self.overviewTexts) do
        local function current()
            return supported() and ownerCurrent() and supported() and self.overviewTexts[index] == fs
        end
        if not writer(self,fs,"Hide",current) then return false end
    end
    local scope = { current = ownerCurrent }
    self.overviewControlReset = scope
    for _, key in ipairs({"overviewMoreButton","overviewFewerButton"}) do
        local control = self[key]
        if control then
            local function current()
                if not scope.current or not supported() then return false end
                local value = scope.current()
                return value == true and scope.current ~= nil and supported() and self[key] == control
            end
            if not writer(self,control,"Hide",current) or not writer(self,control,"SetEnabled",current,false) or
                not writer(self,control,"SetScript",current,"OnClick",nil) then return false end
        end
    end
    return supported() and ownerCurrent() and supported()
end

-- Presentation supplies only the window's existing static formatting helpers.
function UI:RenderPreparationOverview(ownerCurrent, width, offset, presentation)
    local renderDungeon, renderEngine, renderIncludeUnavailable = self.dungeon, self.engine, self.includeUnavailable
    local renderer, release, reset = UI.RenderPreparationOverview, self.ReleasePreparationOverview, self.ResetPreparationOverviewControls
    local writer, makeRow, layoutRow = self.QuestListWrite, self.MakeRow, self.LayoutRow
    if type(ownerCurrent) ~= "function" or not ownerCurrent() then return nil end
    if type(width) ~= "number" or width ~= width or width <= 0 or width >= 2000 or
        type(offset) ~= "number" or offset ~= offset or offset < 0 or offset == math.huge then return nil end
    if type(presentation) ~= "table" then return offset end
    local label, setFont, measuredHeight, DETAIL_STYLES = rawget(presentation,"label"), rawget(presentation,"setFont"),
        rawget(presentation,"measuredHeight"), rawget(presentation,"styles")
    if type(label) ~= "function" or type(setFont) ~= "function" or type(measuredHeight) ~= "function" or type(DETAIL_STYLES) ~= "table" or
        type(rawget(DETAIL_STYLES,"body")) ~= "table" or type(rawget(DETAIL_STYLES,"caption")) ~= "table" or type(rawget(DETAIL_STYLES,"warning")) ~= "table" then return offset end
    if self.RenderPreparationOverview ~= renderer or addon.PreparationOverviewUI ~= UI or type(writer) ~= "function" or
        type(makeRow) ~= "function" or type(layoutRow) ~= "function" or type(release) ~= "function" or type(reset) ~= "function" then return offset end
    if rawget(presentation,"geometryWrite") ~= nil and type(rawget(presentation,"geometryWrite")) ~= "function" then return offset end
    if type(rawget(presentation,"formatStatus")) ~= "nil" and type(rawget(presentation,"formatStatus")) ~= "function" then return offset end
    local portraitCardCurrent, contentWidth, y = ownerCurrent, width, offset
    local plan, provider = self.currentPlan, addon.DungeonOverview
    local get = type(provider) == "table" and provider.Get
    local listCurrent, listRaw = plan and plan.current, plan and plan.rawCurrent
    if type(get) == "function" and type(listCurrent) == "function" and type(listRaw) == "function" and
        plan.engine == renderEngine and plan.dungeon == renderDungeon and plan.includeUnavailable == renderIncludeUnavailable then
        local limits = self.overviewStepLimits
        if type(limits) ~= "table" then limits = {}; self.overviewStepLimits = limits end
        local limitState = rawget(limits,renderDungeon)
        if type(limitState) ~= "table" then limitState = { limit = 6 }; limits[renderDungeon] = limitState end
        local limitCleaner = addon.Clean
        local stepLimit = limitCleaner(rawget(limitState,"limit"),"number")
        if not portraitCardCurrent() or addon.Clean ~= limitCleaner or self.currentPlan ~= plan or self.dungeon ~= renderDungeon or self.engine ~= renderEngine then return end
        if not stepLimit or stepLimit % 1 ~= 0 or stepLimit < 6 or stepLimit > 1024 then return offset end
        local refresh = self.RefreshDetail
        local binding = { formatStatus = rawget(presentation,"formatStatus"), geometryWrite = rawget(presentation,"geometryWrite"), presentation = presentation, plan = plan, engine = renderEngine, base = portraitCardCurrent, listCurrent = listCurrent, listRaw = listRaw, titles = {}, starters = {} }
        local localize, read, clean, checker = addon.L, addon.Read, addon.Clean, issecretvalue
        local inspect, keyGetter, dictionaryGetter = self.InspectQuest, self.CatalogLanguageKey, addon.GetNameTranslations
        -- Shared pickup-shape authority lives on the earlier QuestNavigation
        -- module (TOC order), so list grouping and these labels cannot diverge.
        local questSources = addon.QuestNavigation
        local database, language, frame = addon.db, addon.Language, self.frame
        local choice = type(database) == "table" and rawget(database,"locale")
        local preview = type(language) == "table" and rawget(language,"GetSelection")
        local native, gameGetter, guidGetter = C_QuestLog, GetLocale, UnitGUID
        local nativeTitle = type(native) == "table" and rawget(native,"GetTitleForQuestID")
        local titleGetter, definitions = addon.CachedQuestName, addon.quests
        local locale = read(keyGetter,"string",self)
        if locale == "enGB" then locale = "enUS" elseif locale == "esMX" then locale = "esES" end
        local function base()
            return not binding.released and self.overviewBinding == binding and self.overviewStepLimits == limits and
                rawequal(rawget(limits,renderDungeon),limitState) and rawequal(rawget(limitState,"limit"),stepLimit) and
                self.RefreshDetail == refresh and binding.base and binding.base() and
                addon.PreparationOverviewUI == UI and UI.RenderPreparationOverview == renderer and self.RenderPreparationOverview == renderer and
                self.ReleasePreparationOverview == release and self.ResetPreparationOverviewControls == reset and
                self.QuestListWrite == writer and self.MakeRow == makeRow and self.LayoutRow == layoutRow and
                binding.presentation and rawget(binding.presentation,"label") == label and rawget(binding.presentation,"setFont") == setFont and
                rawget(binding.presentation,"measuredHeight") == measuredHeight and rawget(binding.presentation,"styles") == DETAIL_STYLES and
                rawequal(rawget(binding.presentation,"geometryWrite"),binding.geometryWrite) and
                rawequal(rawget(binding.presentation,"formatStatus"),binding.formatStatus) and
                addon.UI == self and self.frame == frame and self.currentPlan == binding.plan and binding.plan.current == binding.listCurrent and binding.plan.rawCurrent == binding.listRaw and
                addon.DungeonOverview == provider and provider.Get == get and addon.L == localize and addon.Read == read and
                addon.Clean == clean and issecretvalue == checker and self.InspectQuest == inspect and self.CatalogLanguageKey == keyGetter and
                addon.QuestNavigation == questSources and
                addon.GetNameTranslations == dictionaryGetter and addon.CachedQuestName == titleGetter and addon.quests == definitions and
                addon.db == database and (type(database) ~= "table" or rawequal(rawget(database,"locale"),choice)) and
                addon.Language == language and (type(language) ~= "table" or rawequal(rawget(language,"GetSelection"),preview)) and
                GetLocale == gameGetter and UnitGUID == guidGetter and C_QuestLog == native and
                (type(native) ~= "table" or rawequal(rawget(native,"GetTitleForQuestID"),nativeTitle))
        end
        self.overviewBinding = binding
        binding.rawProof = function()
            if not base() then return false end
            for _, title in ipairs(binding.titles) do
                if not rawequal(rawget(definitions,title.id),title.definition) or
                    not rawequal(rawget(title.definition,"name"),title.source) or not rawequal(rawget(title.definition,"id"),title.definitionID) or not rawequal(addon.nameTranslations,title.root) or
                    (type(title.root)=="table" and not rawequal(rawget(title.root,locale),title.dictionary)) or
                    (type(title.dictionary)=="table" and not rawequal(rawget(title.dictionary,"quests"),title.entries)) or
                    (type(title.entries)=="table" and not rawequal(rawget(title.entries,title.id),title.entry)) or
                    (type(title.entry)=="table" and (not rawequal(rawget(title.entry,"source"),title.original) or
                        not rawequal(rawget(title.entry,"name"),title.translated))) then return false end
            end
            for _, starter in ipairs(binding.starters) do
                if not rawequal(rawget(definitions,starter.id),starter.definition) then return false end
                if type(starter.definition) == "table" then
                    if not rawequal(rawget(starter.definition,"start"),starter.start) then return false end
                    if not rawequal(rawget(starter.definition,"startAlternatives"),starter.alternatives) then return false end
                elseif starter.start ~= nil or starter.alternatives ~= nil then return false end
                if type(starter.start) == "table" then
                    if not rawequal(rawget(starter.start,"itemID"),starter.itemID) then return false end
                    if not rawequal(rawget(starter.start,"npcID"),starter.npcID) then return false end
                    if not rawequal(rawget(starter.start,"objectID"),starter.objectID) then return false end
                    if not rawequal(rawget(starter.start,"summonItem"),starter.summonItem) then return false end
                    if not rawequal(rawget(starter.start,"mapID"),starter.mapID) then return false end
                    if not rawequal(rawget(starter.start,"x"),starter.x) then return false end
                    if not rawequal(rawget(starter.start,"y"),starter.y) then return false end
                    if not rawequal(rawget(starter.start,"reportedLocations"),starter.reportedLocations) then return false end
                    local currentSummon = rawget(starter.start,"summonItem")
                    local currentSummonID
                    if type(currentSummon) == "table" then currentSummonID = rawget(currentSummon,"itemID") end
                    if not rawequal(currentSummonID,starter.summonItemID) then return false end
                elseif starter.itemID ~= nil or starter.npcID ~= nil or starter.objectID ~= nil or starter.summonItem ~= nil or
                    starter.mapID ~= nil or starter.x ~= nil or starter.y ~= nil or starter.reportedLocations ~= nil or starter.summonItemID ~= nil then return false end
            end
            return binding.listRaw() and (not binding.modelRaw or binding.modelRaw()) and base()
        end
        binding.current = function()
            if not binding.rawProof() or read(binding.listCurrent,"boolean") ~= true or not binding.rawProof() then return false end
            if binding.modelCurrent and read(binding.modelCurrent,"boolean") ~= true then return false end
            local selected = read(keyGetter,"string",self)
            if selected == "enGB" then selected = "enUS" elseif selected == "esMX" then selected = "esES" end
            return selected == locale and binding.rawProof()
        end
        local ok, model, proof, raw = pcall(get,plan,renderDungeon,renderEngine,binding.current,stepLimit)
        if not base() then return end
        if ok and type(model)=="table" and type(proof)=="function" and type(raw)=="function" then
            binding.model, binding.modelCurrent, binding.modelRaw = model, proof, raw
            if not binding.current() then return end
            if locale ~= "enUS" and type(dictionaryGetter)=="function" then read(dictionaryGetter,"table",locale,binding.current) end
            if not binding.current() then return end
            local rawSteps, rawCounts, rawRemaining = rawget(model,"steps"), rawget(model,"counts"), rawget(model,"remainingSteps")
            local function finiteCount(value)
                return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
            end
            local countsClosed = type(rawCounts) == "table"
            if countsClosed then
                for _, key in ipairs({ "READY", "ACTIVE", "COMPLETED", "UNKNOWN", "LOCKED", "AVAILABLE", "UNAVAILABLE" }) do
                    if not finiteCount(rawget(rawCounts,key)) then countsClosed = false; break end
                end
            end
            -- Malformed producer shapes fail closed with the input offset and
            -- no binding, mirroring the invalid-model branch below; every
            -- neighboring input is already shape-validated the same way.
            local function closed()
                binding.released = true
                self.overviewBinding = nil
                return offset
            end
            if type(rawSteps) ~= "table" or not countsClosed or not finiteCount(rawRemaining) then return closed() end
            for _, step in ipairs(rawSteps) do
                if type(step) ~= "table" then return closed() end
                local stepID = rawget(step,"id")
                if type(stepID) ~= "number" or stepID ~= stepID or stepID == math.huge or stepID == -math.huge or stepID % 1 ~= 0 then return closed() end
                local definition = rawget(definitions,step.id)
                if type(definition) ~= "table" then return end
                local root = addon.nameTranslations
                local dictionary = type(root)=="table" and rawget(root,locale)
                local entries = type(dictionary)=="table" and rawget(dictionary,"quests")
                local entry = type(entries)=="table" and rawget(entries,step.id)
                local title = { id=step.id,definition=definition,source=rawget(definition,"name"),definitionID=rawget(definition,"id"),root=root,dictionary=dictionary,entries=entries,entry=entry,
                    original=type(entry)=="table" and rawget(entry,"source"), translated=type(entry)=="table" and rawget(entry,"name") }
                binding.titles[#binding.titles+1]=title
                local rawStart = rawget(definition,"start")
                local rawAlternatives = rawget(definition,"startAlternatives")
                local rawItemID, rawNpcID, rawObjectID, rawSummonItem, rawMapID, rawX, rawY, rawReported, rawSummonItemID
                if type(rawStart) == "table" then
                    rawItemID = rawget(rawStart,"itemID")
                    rawNpcID = rawget(rawStart,"npcID")
                    rawObjectID = rawget(rawStart,"objectID")
                    rawSummonItem = rawget(rawStart,"summonItem")
                    rawMapID = rawget(rawStart,"mapID")
                    rawX = rawget(rawStart,"x")
                    rawY = rawget(rawStart,"y")
                    rawReported = rawget(rawStart,"reportedLocations")
                    if type(rawSummonItem) == "table" then rawSummonItemID = rawget(rawSummonItem,"itemID") end
                end
                binding.starters[#binding.starters+1] = { id=step.id,definition=definition,start=rawStart,alternatives=rawAlternatives,itemID=rawItemID,npcID=rawNpcID,objectID=rawObjectID,summonItem=rawSummonItem,mapID=rawMapID,x=rawX,y=rawY,reportedLocations=rawReported,summonItemID=rawSummonItemID }
                title.text=read(titleGetter,"string",step.id)
                if not binding.current() then return end
                title.text=title.text and #title.text<=1024 and title.text:find("%S") and title.text or clean(title.source,"string") or ("#"..step.id)
            end
            local titleCounts={}
            for _, title in ipairs(binding.titles) do titleCounts[title.text]=(titleCounts[title.text] or 0)+1 end
            for _, title in ipairs(binding.titles) do if titleCounts[title.text]>1 then title.text=title.text.." #"..title.id end end
            local starterById = {}
            for _, starter in ipairs(binding.starters) do starterById[starter.id] = starter end
            local function sharedEmpty(value)
                local helper = questSources and questSources.IsEmptyAlternatives
                if type(helper) ~= "function" then return nil end
                return helper(questSources, value)
            end
            local function sharedPickupKind(start, alternatives)
                local classifier = questSources and questSources.PickupStartKind
                if type(classifier) ~= "function" then return nil end
                return classifier(questSources, start, alternatives)
            end
            -- Snapshot/ownership gates stay local; the shape verdict is single-sourced
            -- from the shared classifier so overview labels and list grouping agree.
            local function isItemOnlyPickup(stepID)
                local starter = starterById[stepID]
                if not starter then return false end
                if starter.alternatives ~= nil then
                    local alternativeList = clean(starter.alternatives,"table")
                    if not alternativeList or not sharedEmpty(alternativeList) then return false end
                end
                if starter.npcID ~= nil or starter.objectID ~= nil then return false end
                if type(starter.start) ~= "table" then return false end
                if not clean(starter.start,"table") then return false end
                if type(checker) == "function" then
                    if read(checker,"boolean",starter.start) ~= false then return false end
                    if read(checker,"boolean",starter.itemID) ~= false then return false end
                    if read(checker,"boolean",starter.alternatives) ~= false then return false end
                end
                return sharedPickupKind(starter.start, starter.alternatives) == "item"
            end
            local function isSummonPickup(stepID)
                local starter = starterById[stepID]
                if not starter then return false end
                if starter.alternatives ~= nil then
                    local alternativeList = clean(starter.alternatives,"table")
                    if not alternativeList then return false end
                    if sharedEmpty(alternativeList) then
                        for _ in pairs(alternativeList) do return false end
                    end
                end
                if type(starter.start) ~= "table" then return false end
                if not clean(starter.start,"table") then return false end
                if type(checker) == "function" then
                    if read(checker,"boolean",starter.start) ~= false then return false end
                    if read(checker,"boolean",starter.summonItem) ~= false then return false end
                    if read(checker,"boolean",starter.alternatives) ~= false then return false end
                end
                return sharedPickupKind(starter.start, starter.alternatives) == "uncertain"
            end
            local textIndex=0
            local function summaryLine(value,style)
                if not binding.current() then return false end
                textIndex=textIndex+1
                local slot=textIndex
                local fs=self.overviewTexts[slot]
                if not fs then fs=label(self.detail,"",4,0,contentWidth,13); self.overviewTexts[slot]=fs end
                local function owned() return binding.rawProof() and self.overviewTexts[slot]==fs end
                local format=DETAIL_STYLES[style or "body"]
                setFont(fs,format.size)
                if not binding.current() then return false end
                y=y+(format.before or 0)
                if not self:QuestListWrite(fs,"SetTextColor",owned,unpack(format.color)) or
                    not self:QuestListWrite(fs,"SetWidth",owned,contentWidth) or not self:QuestListWrite(fs,"ClearAllPoints",owned) or
                    not self:QuestListWrite(fs,"SetPoint",owned,"TOPLEFT",4,-y) or not self:QuestListWrite(fs,"SetText",owned,value) or
                    not self:QuestListWrite(fs,"Show",owned) then return false end
                y=y+math.max(format.minimum,measuredHeight(fs,format.minimum))+(format.after or 0)
                return binding.current()
            end
            if not summaryLine(localize("OVERVIEW_PREPARATION"),"caption") or
                not summaryLine(localize("OVERVIEW_STATUS_ACTIVE",model.counts.READY,model.counts.ACTIVE)) or
                not summaryLine(localize("OVERVIEW_STATUS_RECORDED",model.counts.COMPLETED,model.counts.UNKNOWN)) then return end
            for _, status in ipairs({"LOCKED","AVAILABLE","UNAVAILABLE"}) do
                if model.counts[status]>0 and not summaryLine(localize("OVERVIEW_STATUS_COUNT",localize(status),model.counts[status])) then return end
            end
            if model.unknown and not summaryLine(localize("OVERVIEW_UNCERTAIN"),"warning") then return end
            if #model.steps>0 then
                local heldSteps = 0
                for _, grouped in ipairs(model.steps) do
                    if type(grouped) == "table" and (grouped.status == "READY" or grouped.status == "ACTIVE") then
                        heldSteps = heldSteps + 1
                    end
                end
                if heldSteps > 0 and not summaryLine(localize("OVERVIEW_KNOWN_STEPS"),"caption") then return end
            elseif not summaryLine(localize("OVERVIEW_NO_KNOWN_STEPS")) then return end
            local nextHeaderShown = false
            for index, step in ipairs(model.steps) do
                if type(step) ~= "table" or (step.status ~= "READY" and step.status ~= "ACTIVE") then
                    if not nextHeaderShown then
                        nextHeaderShown = true
                        if not summaryLine(localize("OVERVIEW_NEXT_STEPS"),"caption") then return end
                    end
                end
                local stepID=step.id
                local row=self:MakeRow(self.detail,self.actionInspectButtons,index,48,binding.current,true)
                if not binding.current() then return end
                local listedTarget, stepStatus=step.listedTarget, step.status
                row.questID,row.overviewStep=step.id,step
                local function owned() return binding.rawProof() and self.actionInspectButtons[index]==row and row.questID==stepID and row.overviewStep==binding.model.steps[index] end
                local function write(object,method,...) return self:QuestListWrite(object,method,owned,...) end
                setFont(row.title,15);setFont(row.note,13)
                local statusText=localize(stepStatus)
                if not binding.current() then return end
                if binding.formatStatus then
                    statusText=read(binding.formatStatus,"string",stepStatus,statusText)
                    if not binding.current() or not statusText then return end
                end
                local kindKey = nil
                if stepStatus ~= "READY" and stepStatus ~= "ACTIVE" then
                    if stepStatus == "UNKNOWN" then kindKey = "PREP_uncertain"
                    elseif step.kind == "pickup" then
                        if isSummonPickup(step.id) then kindKey = "PREP_uncertain"
                        elseif isItemOnlyPickup(step.id) then kindKey = "PREP_item"
                        else
                            -- Start-less records carry no place; row/detail stay
                            -- honest with unknown-start, so the label does too.
                            local starter = starterById[step.id]
                            kindKey = (starter and starter.start ~= nil) and "PREP_outside" or "PREP_uncertain"
                        end
                    elseif step.kind == "inside" then
                        if isSummonPickup(step.id) then kindKey = "PREP_uncertain" else kindKey = "PREP_inside" end
                    elseif step.kind == "level" then kindKey = "PREP_level"
                    end
                end
                local kindLabel = nil
                if kindKey then
                    kindLabel = localize(kindKey)
                    if not binding.current() then return end
                end
                local supportingLabel = nil
                if listedTarget == false then
                    supportingLabel = localize("OVERVIEW_SUPPORTING_QUEST")
                    if not binding.current() then return end
                end
                local inspectLabel = localize("BRANCH_INSPECT")
                if not binding.current() then return end
                -- Supporting steps keep the fixed SUPPORTING·KIND·STATUS·INSPECT
                -- order; every mark is composed once from existing strings.
                local noteParts = {}
                local function pushNote(part)
                    if type(part) == "string" and part:find("%S") then
                        for _, kept in ipairs(noteParts) do if kept == part then return end end
                        noteParts[#noteParts + 1] = part
                    end
                end
                pushNote(supportingLabel); pushNote(kindLabel); pushNote(statusText); pushNote(inspectLabel)
                local note = table.concat(noteParts, " · ")
                if not binding.current() or not write(row,"SetWidth",contentWidth) or not write(row.title,"SetWidth",contentWidth-16) or
                    not write(row.note,"SetWidth",contentWidth-16) or not write(row.title,"SetText",binding.titles[index].text) or
                    not write(row.note,"SetText",note) then return end
                local offset=self:LayoutRow(row,48,y,owned,write)
                if not offset or not binding.current() then return end
                y=offset
                if not write(row,"SetEnabled",true) or not write(row,"SetScript","OnClick",function()
                    if not binding.current() or not owned() then return end
                    local shown=read(frame.IsShown,"boolean",frame)
                    local visible=read(row.IsShown,"boolean",row)
                    if shown==true and visible==true and binding.current() and owned() then inspect(self,stepID,true) end
                end) or not write(row,"Show") then return end
            end
            if model.remainingSteps>0 and not summaryLine(localize("OVERVIEW_MORE_STEPS",model.remainingSteps)) then return end
            local controls = {}
            if model.remainingSteps > 0 then controls[#controls+1] = {key="overviewMoreButton",caption="OVERVIEW_SHOW_MORE",amount=math.min(6,model.remainingSteps),limit=math.min(1024,stepLimit+6)} end
            if #model.steps > 6 then controls[#controls+1] = {key="overviewFewerButton",caption="OVERVIEW_SHOW_FEWER",limit=6} end
            if #controls > 0 and type(refresh) ~= "function" then return end
            local controlHeight, controlY = 26, y
            for index, entry in ipairs(controls) do
                if not binding.current() then return end
                local key, nextLimit = entry.key, entry.limit
                local control = self[key]
                if not control then
                    local okCreate, fresh = pcall(CreateFrame, "Button", nil, self.detail)
                    if not okCreate then binding.released = true; self.overviewBinding = nil; return end
                    control = addon.Clean(fresh, "table") or addon.Clean(fresh, "userdata")
                    if not control then binding.released = true; self.overviewBinding = nil; return end
                    if not binding.current() then return end
                    self[key]=control
                    control.label=label(control,"",4,-4,contentWidth-8,13)
                    if not binding.current() then return end
                end
                local function owned() return binding.rawProof() and self[key]==control end
                local function write(object,method,...)
                    if method == "ClearAllPoints" and binding.geometryWrite then return binding.geometryWrite(owned,object,method,...) end
                    return writer(self,object,method,owned,...)
                end
                local caption=entry.amount and localize(entry.caption,entry.amount) or localize(entry.caption)
                if not binding.current() then return end
                setFont(control.label,13)
                local buttonWidth=(contentWidth-(#controls-1)*4)/#controls
                if not binding.current() or not write(control.label,"SetWidth",buttonWidth-8) or
                    not write(control.label,"SetText",caption) then return end
                controlHeight=math.max(controlHeight,measuredHeight(control.label,18)+8)
                if not binding.current() then return end
                local theme, style=addon.Theme, addon.Theme and addon.Theme.StyleRow
                if type(style)=="function" then read(style,"boolean",control,{kind="control",selected=false}) end
                if not binding.current() or addon.Theme~=theme or (theme and theme.StyleRow~=style) then return end
                if not write(control,"SetSize",buttonWidth,controlHeight) or not write(control,"ClearAllPoints") or
                    not write(control,"SetPoint","TOPLEFT",4+(index-1)*(buttonWidth+4),-controlY) or
                    not write(control,"SetEnabled",true) or not write(control,"SetScript","OnClick",function()
                        if not binding.current() or not owned() then return end
                        local shownGetter, visibleGetter=frame.IsShown, control.IsShown
                        local shown=read(shownGetter,"boolean",frame)
                        local visible=read(visibleGetter,"boolean",control)
                        if shown~=true or visible~=true or frame.IsShown~=shownGetter or control.IsShown~=visibleGetter or not binding.current() or not owned() then return end
                        limitState.limit=nextLimit
                        refresh(self)
                    end) or not write(control,"Show") then return end
            end
            for _, entry in ipairs(controls) do
                local control=self[entry.key]
                local function owned() return binding.rawProof() and self[entry.key]==control end
                if not writer(self,control,"SetHeight",owned,controlHeight) then return end
            end
            if #controls>0 then y=controlY+controlHeight+8 end
        else
            binding.released=true
            self.overviewBinding=nil
        end
    end
    return y
end
