local _, addon = ...
local UI = {}
addon.PreparationOverviewUI = UI

-- Pooled physical write records survive; their obsolete render lease does not.
function UI:ReleasePreparationOverview()
    local previous = self.overviewBinding
    self.overviewBinding = nil
    if previous then
        previous.released = true
        for _, key in ipairs({ "model", "modelCurrent", "modelRaw", "base", "listCurrent", "listRaw", "engine", "plan", "titles", "presentation" }) do previous[key] = nil end
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
    local portraitCardCurrent, contentWidth, y = ownerCurrent, width, offset
    local plan, provider = self.currentPlan, addon.DungeonOverview
    local get = type(provider) == "table" and provider.Get
    local listCurrent, listRaw = plan and plan.current, plan and plan.rawCurrent
    if type(get) == "function" and type(listCurrent) == "function" and type(listRaw) == "function" and
        plan.engine == renderEngine and plan.dungeon == renderDungeon and plan.includeUnavailable == renderIncludeUnavailable then
        local binding = { presentation = presentation, plan = plan, engine = renderEngine, base = portraitCardCurrent, listCurrent = listCurrent, listRaw = listRaw, titles = {} }
        local localize, read, clean, checker = addon.L, addon.Read, addon.Clean, issecretvalue
        local inspect, keyGetter, dictionaryGetter = self.InspectQuest, self.CatalogLanguageKey, addon.GetNameTranslations
        local database, language, frame = addon.db, addon.Language, self.frame
        local choice = type(database) == "table" and rawget(database,"locale")
        local preview = type(language) == "table" and rawget(language,"GetSelection")
        local native, gameGetter, guidGetter = C_QuestLog, GetLocale, UnitGUID
        local nativeTitle = type(native) == "table" and rawget(native,"GetTitleForQuestID")
        local titleGetter, definitions = addon.CachedQuestName, addon.quests
        local locale = read(keyGetter,"string",self)
        if locale == "enGB" then locale = "enUS" elseif locale == "esMX" then locale = "esES" end
        local function base()
            return not binding.released and self.overviewBinding == binding and binding.base and binding.base() and
                addon.PreparationOverviewUI == UI and UI.RenderPreparationOverview == renderer and self.RenderPreparationOverview == renderer and
                self.ReleasePreparationOverview == release and self.ResetPreparationOverviewControls == reset and
                self.QuestListWrite == writer and self.MakeRow == makeRow and self.LayoutRow == layoutRow and
                binding.presentation and rawget(binding.presentation,"label") == label and rawget(binding.presentation,"setFont") == setFont and
                rawget(binding.presentation,"measuredHeight") == measuredHeight and rawget(binding.presentation,"styles") == DETAIL_STYLES and
                addon.UI == self and self.frame == frame and self.currentPlan == binding.plan and binding.plan.current == binding.listCurrent and binding.plan.rawCurrent == binding.listRaw and
                addon.DungeonOverview == provider and provider.Get == get and addon.L == localize and addon.Read == read and
                addon.Clean == clean and issecretvalue == checker and self.InspectQuest == inspect and self.CatalogLanguageKey == keyGetter and
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
            return binding.listRaw() and (not binding.modelRaw or binding.modelRaw()) and base()
        end
        binding.current = function()
            if not binding.rawProof() or read(binding.listCurrent,"boolean") ~= true or not binding.rawProof() then return false end
            if binding.modelCurrent and read(binding.modelCurrent,"boolean") ~= true then return false end
            local selected = read(keyGetter,"string",self)
            if selected == "enGB" then selected = "enUS" elseif selected == "esMX" then selected = "esES" end
            return selected == locale and binding.rawProof()
        end
        local ok, model, proof, raw = pcall(get,plan,renderDungeon,renderEngine,binding.current)
        if not base() then return end
        if ok and type(model)=="table" and type(proof)=="function" and type(raw)=="function" then
            binding.model, binding.modelCurrent, binding.modelRaw = model, proof, raw
            if not binding.current() then return end
            if locale ~= "enUS" and type(dictionaryGetter)=="function" then read(dictionaryGetter,"table",locale,binding.current) end
            if not binding.current() then return end
            for _, step in ipairs(model.steps) do
                local definition = rawget(definitions,step.id)
                if type(definition) ~= "table" then return end
                local root = addon.nameTranslations
                local dictionary = type(root)=="table" and rawget(root,locale)
                local entries = type(dictionary)=="table" and rawget(dictionary,"quests")
                local entry = type(entries)=="table" and rawget(entries,step.id)
                local title = { id=step.id,definition=definition,source=rawget(definition,"name"),definitionID=rawget(definition,"id"),root=root,dictionary=dictionary,entries=entries,entry=entry,
                    original=type(entry)=="table" and rawget(entry,"source"), translated=type(entry)=="table" and rawget(entry,"name") }
                binding.titles[#binding.titles+1]=title
                title.text=read(titleGetter,"string",step.id)
                if not binding.current() then return end
                title.text=title.text and #title.text<=1024 and title.text:find("%S") and title.text or clean(title.source,"string") or ("#"..step.id)
            end
            local titleCounts={}
            for _, title in ipairs(binding.titles) do titleCounts[title.text]=(titleCounts[title.text] or 0)+1 end
            for _, title in ipairs(binding.titles) do if titleCounts[title.text]>1 then title.text=title.text.." #"..title.id end end
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
                if not summaryLine(localize("OVERVIEW_KNOWN_STEPS"),"caption") then return end
            elseif not summaryLine(localize("OVERVIEW_NO_KNOWN_STEPS")) then return end
            for index, step in ipairs(model.steps) do
                local stepID=step.id
                local row=self:MakeRow(self.detail,self.actionInspectButtons,index,48,binding.current,true)
                if not binding.current() then return end
                local listedTarget=step.listedTarget
                row.questID,row.overviewStep=step.id,step
                local function owned() return binding.rawProof() and self.actionInspectButtons[index]==row and row.questID==stepID and row.overviewStep==binding.model.steps[index] end
                local function write(object,method,...) return self:QuestListWrite(object,method,owned,...) end
                setFont(row.title,15);setFont(row.note,13)
                local note=localize(step.status).." · "..localize("BRANCH_INSPECT")
                if not binding.current() then return end
                if listedTarget == false then note=localize("OVERVIEW_SUPPORTING_QUEST").." · "..note end
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
        else
            binding.released=true
            self.overviewBinding=nil
        end
    end
    return y
end
