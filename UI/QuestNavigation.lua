local _, addon = ...
local UI = {}
addon.QuestNavigation = UI

function UI:NavigationDestination(coordinates)
    local frame, quest, dungeon, engine, character, generation, giver = self.frame, self.quest, self.dungeon, self.engine,
        addon.char, self.rewardGeneration, self.giverAction
    local function current()
        return addon.UI == self and self.frame == frame and self.quest == quest and self.dungeon == dungeon and
            self.engine == engine and addon.char == character and self.rewardGeneration == generation and self.giverAction == giver
    end
    local function usable(action)
        local place = action and addon.Clean(action.place, "table")
        local map = place and addon.Clean(place.mapID, "number")
        if not map or map <= 0 or map > 9007199254740991 or map % 1 ~= 0 then return false end
        local x, y = addon.Clean(place.x, "number"), addon.Clean(place.y, "number")
        local hasCoordinates = x ~= nil and y ~= nil and x >= 0 and x <= 100 and y >= 0 and y <= 100
        if coordinates and not hasCoordinates then return false end
        local navigation = addon.Clean(addon.Navigation, "table")
        local method = navigation and addon.Clean(navigation[hasCoordinates and "Start" or "Map"], "function")
        if not method then return false end
        return true
    end
    local binding = self.giverBinding
    local fresh = not binding or addon.Read(binding.current, "boolean") == true
    if not current() or not fresh or self.giverBinding ~= binding then return end
    local available = usable(giver)
    if current() and available then return giver, true end
end

function UI:DispatchDetail(action, mapOnly, giver, ownerCurrent, markerPurpose)
    if not action then return false end
    local frame, quest, dungeon, engine, character, generation = self.frame, self.quest, self.dungeon, self.engine, addon.char, self.rewardGeneration
    local navigation = addon.Clean(addon.Navigation, "table")
    local method = navigation and addon.Clean(navigation[mapOnly and "Map" or "Start"], "function")
    if not frame or not method then return false end
    local shown, getter = frame.IsShown, engine and engine.Current
    local place, id, kind = action.place, action.id, action.kind
    local coordinates, checker = self.giverHasCoordinates, issecretvalue
    local giverBinding = giver and self.giverBinding
    local purposeClean, purposeRead = addon.Clean, addon.Read
    local slot = giver and "giverAction" or "action"
    local function current()
        local fresh = not getter or addon.Read(getter, "boolean", engine) == true
        local owned = ownerCurrent == nil or addon.Read(ownerCurrent, "boolean") == true
        local giverFresh = not giverBinding or addon.Read(giverBinding.current, "boolean") == true
        return fresh and owned and giverFresh and (not giver or self.giverBinding == giverBinding) and addon.UI == self and self.frame == frame and self.quest == quest and self.dungeon == dungeon and
            self.engine == engine and addon.char == character and self.rewardGeneration == generation and
            addon.Navigation == navigation and navigation[mapOnly and "Map" or "Start"] == method and
            frame.IsShown == shown and (not engine or engine.Current == getter) and
            (ownerCurrent ~= nil or self[slot] == action) and action.place == place and action.id == id and action.kind == kind and
            (not giver or self.giverHasCoordinates == coordinates) and issecretvalue == checker and addon.Clean == purposeClean and addon.Read == purposeRead
    end
    if not current() or addon.Read(shown, "boolean", frame) ~= true or not current() then return false end
    if giverBinding then markerPurpose = purposeClean(giverBinding.markerPurpose, "string")
    else markerPurpose = purposeClean(markerPurpose, "string") end
    if not current() then return false end
    if mapOnly then return pcall(method, place, markerPurpose, id, current) end
    return pcall(method, action, markerPurpose, current)
end

function UI:DetailContactBinding(definition, endpointField, ownerCurrent)
    local clean, read, checker, helper = addon.Clean, addon.Read, issecretvalue, self.DetailContactBinding
    local catalogue, character, ui, navigation = addon.quests, addon.char, addon.UI, addon.Navigation
    local contextKeys = { "frame", "quest", "dungeon", "engine", "rewardGeneration", "detailNavigationRevision",
        "detailTabRevision", "layoutRevision", "sourceControlsLease" }
    local context, fields, arrays, entries, points = {}, {}, {}, {}, {}
    local pointFields = { npcID="number", objectID="number", itemID="number", dropNPCID="number",
        name="string", zoneName="string", locationName="string", mapID="number", x="number", y="number",
        reportedLocations="table", summonItem="table" }
    local function capture(object, key)
        local value = rawget(object, key)
        fields[#fields+1] = {object,key,value}
        return value
    end
    local function captureArray(array)
        local members, count = {}, 0
        for key, value in next,array do
            count=count+1
            if count>100 then error("bounded contact locations") end
            members[count]={key,value}
        end
        arrays[#arrays+1]={array,members}
        return members
    end
    local function capturePoint(point)
        local values={}
        points[#points+1]=values
        for key in pairs(pointFields) do values[key]=capture(point,key) end
        if type(values.reportedLocations)=="table" then
            for _,member in ipairs(captureArray(values.reportedLocations)) do
                local report={};points[#points+1]=report
                for key in pairs(pointFields) do report[key]=capture(member[2],key) end
                if type(report.reportedLocations)~="nil" then error("nested contact reports") end
            end
        end
        return values
    end
    local branchSnapshots={}
    local rawID, starts, finishes, startAlternatives, finishAlternatives, startValues, finishValues, engineGetter, mapMethod, startMethod, shownGetter, shownRawSlot
    local ok=pcall(function()
        for _,key in ipairs(contextKeys) do context[key]=capture(self,key) end
        if type(context.engine)=="table" then
            engineGetter=capture(context.engine,"Current")
            capture(context.engine,"quests");capture(context.engine,"context")
        end
        mapMethod,startMethod=capture(navigation,"Map"),capture(navigation,"Start")
        if type(context.frame)=="table" then shownRawSlot=capture(context.frame,"IsShown") end
        rawID=capture(definition,"id")
        capture(definition,"name")
        -- Isolated pre-callback branch snapshots never validate the other contact.
        -- Only the selected branch is retained after the selector is sanitized.
        starts,finishes=rawget(definition,"start"),rawget(definition,"finish")
        startAlternatives,finishAlternatives=rawget(definition,"startAlternatives"),rawget(definition,"finishAlternatives")
        local count=0
        for key,value in next,catalogue do
            count=count+1;if count>10000 then error("bounded contact catalogue") end
            entries[count]={key,value}
        end
    end)
    if not ok or type(clean)~="function" or type(read)~="function" then return nil end
    local commonFields=fields
    for _,branch in ipairs({"start","finish"}) do
        fields,arrays,points={},{},{}
        local good=pcall(function()
            local primary=capture(definition,branch)
            local alternatives=capture(definition,branch.."Alternatives")
            local values
            if type(primary)=="table" then values=capturePoint(primary) end
            if type(alternatives)=="table" then
                for _,member in ipairs(captureArray(alternatives)) do capturePoint(member[2]) end
            end
            branchSnapshots[branch]={fields=fields,arrays=arrays,points=points,values=values}
        end)
        if not good then branchSnapshots[branch]=nil end
    end
    fields,arrays,points=commonFields,{},{}
    local selectedID, binding, action, point, mapOnly, purpose, reason, current, invoke
    local initial,readable=true,false
    local function baseCurrent()
        local ok,same=pcall(function()
            return addon.UI==ui and ui==self and addon.quests==catalogue and addon.char==character and
                addon.Clean==clean and addon.Read==read and issecretvalue==checker and
                self.DetailContactBinding==helper and addon.Navigation==navigation
        end)
        return ok and same==true
    end
    local function rawCurrent()
        local good,same=pcall(function()
            if not readable or not baseCurrent() then return false end
            for _,f in ipairs(fields) do if not rawequal(rawget(f[1],f[2]),f[3]) then return false end end
            for _,snapshot in ipairs(arrays) do
                local count=0
                for key,value in next,snapshot[1] do
                    count=count+1;local member=snapshot[2][count]
                    if not member or not rawequal(key,member[1]) or not rawequal(value,member[2]) then return false end
                end
                if count~=#snapshot[2] then return false end
            end
            if initial then
                local count=0
                for key,value in next,catalogue do
                    count=count+1;local entry=entries[count]
                    if not entry or not rawequal(key,entry[1]) or not rawequal(value,entry[2]) then return false end
                end
                if count~=#entries then return false end
            elseif not rawequal(rawget(catalogue,selectedID),definition) then return false end
            if binding then
                if not rawequal(rawget(binding,"questID"),selectedID) or not rawequal(rawget(binding,"field"),endpointField) or
                    not rawequal(rawget(binding,"endpoint"),point) or not rawequal(rawget(binding,"action"),action) or
                    not rawequal(rawget(binding,"mapOnly"),mapOnly) or not rawequal(rawget(binding,"purpose"),purpose) or
                    not rawequal(rawget(binding,"reason"),reason) or not rawequal(rawget(binding,"current"),current) or
                    not rawequal(rawget(binding,"rawCurrent"),rawCurrent) or not rawequal(rawget(binding,"dispatch"),invoke) then return false end
                if action and (not rawequal(rawget(action,"id"),selectedID) or not rawequal(rawget(action,"kind"),"visit") or not rawequal(rawget(action,"place"),point)) then return false end
            end
            return true
        end)
        return good and same==true
    end
    local function value(raw,kind)
        if not baseCurrent() then return nil end
        local good,result=pcall(clean,raw,kind)
        if not good or not baseCurrent() then return nil end
        return result
    end
    local field=value(endpointField,"string")
    if field~="start" and field~="finish" then return nil end
    endpointField=field
    local branch=branchSnapshots[field]
    if not branch then return nil end
    for _,f in ipairs(branch.fields) do fields[#fields+1]=f end
    arrays,points=branch.arrays,branch.points
    if field=="start" then startValues=branch.values else finishValues=branch.values end
    branchSnapshots=nil
    selectedID=value(rawID,"number")
    if not selectedID or selectedID<1 or selectedID>9007199254740991 or selectedID%1~=0 then return nil end
    local selected=value(context.quest,"number")
    if selected~=selectedID or not value(definition,"table") or not value(ownerCurrent,"function") or
        not value(navigation,"table") then return nil end
    if type(mapMethod)~="nil" and not value(mapMethod,"function") then return nil end
    if type(startMethod)~="nil" and not value(startMethod,"function") then return nil end
    if type(engineGetter)~="nil" and not value(engineGetter,"function") then return nil end
    local member=false
    for _,entry in ipairs(entries) do
        local entryDefinition=value(entry[2],"table")
        if not entryDefinition then return nil end
        if rawequal(entryDefinition,definition) then
            local key=value(entry[1],"number")
            if key==selectedID then member=true;break end
        end
    end
    if not member or not baseCurrent() then return nil end
    local function dense(snapshot)
        local count=#snapshot[2];local seen={}
        for _,member in ipairs(snapshot[2]) do
            local key=value(member[1],"number")
            if not key or key<1 or key>count or key%1~=0 or seen[key] or not value(member[2],"table") then return false end
            seen[key]=true
        end
        return true
    end
    for _,snapshot in ipairs(arrays) do if not dense(snapshot) then return nil end end
    for _,values in ipairs(points) do
        for key,kind in pairs(pointFields) do
            if type(values[key])~="nil" and not value(values[key],kind) then return nil end
        end
        local npc,object,item,drop=value(values.npcID,"number"),value(values.objectID,"number"),value(values.itemID,"number"),value(values.dropNPCID,"number")
        for _,number in ipairs({npc or 1,object or 1,item or 1,drop or 1}) do
            if number<1 or number>4294967295 or number%1~=0 then return nil end
        end
        if (npc and object) or (item and (npc or object)) then return nil end
        local map,x,y=value(values.mapID,"number"),value(values.x,"number"),value(values.y,"number")
        if type(values.mapID)~="nil" and (not map or map<1 or map>9007199254740991 or map%1~=0) then return nil end
        if (type(values.x)=="nil")~=(type(values.y)=="nil") or (x and (not map or x<0 or x>100 or y<0 or y>100)) then return nil end
    end
    local alternatives
    if field=="start" then alternatives=startAlternatives else alternatives=finishAlternatives end
    if type(alternatives)~="nil" and not value(alternatives,"table") then return nil end
    local values
    if field=="start" then point,values=starts,startValues else point,values=finishes,finishValues end
    if type(point)~="nil" and not value(point,"table") then return nil end
    if point then
        for key,kind in pairs(pointFields) do
            if type(values[key])~="nil" and not value(values[key],kind) then return nil end
        end
        local function typed(number) return number and number>0 and number<=4294967295 and number%1==0 end
        local npc,object,item,drop=value(values.npcID,"number"),value(values.objectID,"number"),value(values.itemID,"number"),value(values.dropNPCID,"number")
        if (npc and not typed(npc)) or (object and not typed(object)) or (item and not typed(item)) or (drop and not typed(drop)) then return nil end
        if (npc and object) or (item and (npc or object)) then return nil end
        local map,x,y=value(values.mapID,"number"),value(values.x,"number"),value(values.y,"number")
        if type(values.mapID)~="nil" and (not map or map<1 or map>9007199254740991 or map%1~=0) then return nil end
        if (type(values.x)=="nil")~=(type(values.y)=="nil") then return nil end
        if x and (x<0 or x>100 or y<0 or y>100) then return nil end
        mapOnly=not(x and y)
        -- Start-field item grants follow the shared pickup classifier so an
        -- item start with well-formed alternatives cannot claim item
        -- navigation while list/overview/detail say outside/choices. The
        -- finish field keeps its local shape logic; a missing helper keeps
        -- the legacy grant.
        local itemGrant = item
        if field == "start" then
            local classifier = self.PickupStartKind
            if type(classifier) == "function" then
                itemGrant = read(classifier, "string", self, starts, startAlternatives) == "item"
            end
        end
        if itemGrant then reason="START_ITEM_NAVIGATION"
        elseif drop or type(values.summonItem)~="nil" then reason="SOURCE_DETAILS_HINT"
        elseif not (typed(npc) or typed(object)) then reason="QUEST_START_UNKNOWN"
        elseif not map then reason="SOURCE_POSITION_UNKNOWN"
        elseif (mapOnly and not mapMethod) or (not mapOnly and not startMethod) then reason="NAVIGATION_UNAVAILABLE"
        else
            action={id=selectedID,kind="visit",place=point}
            if field=="start" then purpose="quest-start" end
        end
    else
        mapOnly=true
        reason=alternatives and next(alternatives)~=nil and "SOURCE_DETAILS_HINT" or "QUEST_START_UNKNOWN"
    end
    -- A full proof validates LIVE readability before raw equality. The raw tail
    -- alone is only a conservative proof after an ordinary snapshot was checked.
    local function liveReadable()
        if not baseCurrent() then return false end
        local function ordinary(value)
            if type(checker)~="function" then return true end
            local ok,secret=pcall(checker,value)
            return ok and baseCurrent() and type(secret)=="boolean" and secret==false
        end
        for _,f in ipairs(fields) do if not ordinary(rawget(f[1],f[2])) then return false end end
        for _,snapshot in ipairs(arrays) do
            for key,value in next,snapshot[1] do
                if not ordinary(key) or not ordinary(value) then return false end
            end
        end
        if initial then
            for key,value in next,catalogue do
                if not ordinary(key) or not ordinary(value) then return false end
            end
        end
        if binding then
            for _,key in ipairs({"questID","field","endpoint","action","mapOnly","purpose","reason","current","rawCurrent","dispatch"}) do
                if not ordinary(rawget(binding,key)) then return false end
            end
            if action then
                for _,key in ipairs({"id","kind","place"}) do if not ordinary(rawget(action,key)) then return false end end
            end
        end
        return baseCurrent()
    end
    local function checkedRaw()
        if not liveReadable() then readable=false;return false end
        readable=true
        return rawCurrent()
    end
    if not checkedRaw() then return nil end
    -- Inherited native getter resolution can execute Lua metatable code.
    -- It deliberately happens after the complete raw source snapshot.
    local good,getter=pcall(function()return context.frame.IsShown end)
    if not good or not baseCurrent() then return nil end
    shownGetter=value(getter,"function")
    if not shownGetter or not checkedRaw() then return nil end
    initial=false;entries=nil
    local proving=false
    current=function()
        if proving or not checkedRaw() then return false end
        proving=true
        local good,owned=pcall(ownerCurrent)
        if not good or not checkedRaw() then proving=false;return false end
        local valid=value(owned,"boolean")
        if valid~=true or not checkedRaw() then proving=false;return false end
        if engineGetter then
            local good,fresh=pcall(engineGetter,context.engine)
            if not good or not checkedRaw() then proving=false;return false end
            local valid=value(fresh,"boolean")
            if valid~=true or not checkedRaw() then proving=false;return false end
        end
        local good,getter=pcall(function()return context.frame.IsShown end)
        if not good or not baseCurrent() then proving=false;return false end
        getter=value(getter,"function")
        if not getter or not checkedRaw() or not rawequal(getter,shownGetter) then proving=false;return false end
        proving=false
        return checkedRaw()
    end
    binding={questID=selectedID,field=field,endpoint=point,action=action,mapOnly=mapOnly,purpose=purpose,reason=reason}
    binding.current,binding.rawCurrent=current,rawCurrent
    invoke=function()
        if not action or not current() then return false end
        local method=mapOnly and mapMethod or startMethod
        if not method then return false end
        local good,shown=pcall(shownGetter,context.frame)
        if not good or not current() then return false end
        shown=value(shown,"boolean")
        if shown~=true or not current() then return false end
        local good,result
        if mapOnly then good,result=pcall(method,point,purpose,selectedID,current)
        else good,result=pcall(method,action,purpose,current) end
        if not good or not current() then return false end
        result=value(result,"boolean")
        return result==true and current()
    end
    binding.dispatch=invoke
    if not current() then return nil end
    return binding
end

function UI:GetEntranceBinding(dungeon, ownerCurrent)
    local clean, read, checker = addon.Clean, addon.Read, issecretvalue
    local provider = clean(addon.Entrances, "table")
    local getter = provider and clean(provider.Get, "function")
    local navigation = clean(addon.Navigation, "table")
    local start = navigation and clean(navigation.StartEntrance, "function")
    local function rawOwned()
        return addon.UI == self and addon.Clean == clean and addon.Read == read and issecretvalue == checker and
            addon.Entrances == provider and provider and rawequal(rawget(provider, "Get"), getter) and
            addon.Navigation == navigation and navigation and rawequal(rawget(navigation, "StartEntrance"), start)
    end
    local function owned()
        return rawOwned() and ownerCurrent() and rawOwned()
    end
    if not dungeon or not getter or not start or not owned() then return end
    local ok, point, predicate = pcall(getter, dungeon)
    point, predicate = ok and clean(point, "table"), ok and clean(predicate, "function")
    if not owned() or not point or not predicate then return end
    local map, x, y = clean(point.mapID, "number"), clean(point.x, "number"), clean(point.y, "number")
    if not owned() or not map or map <= 0 or map > 9007199254740991 or map % 1 ~= 0 or not x or not y or x < 0 or x > 100 or y < 0 or y > 100 then return end
    local fields = { "frame", "dungeon", "quest", "engine", "catalogGeneration", "questListGeneration", "rewardGeneration",
        "layoutRevision", "detailTabRevision", "range", "includeUnavailable", "preparation", "search" }
    local function current()
        -- The catalogue may outlive selection changes; own context only for this read.
        local values, character = {}, addon.char
        for _, field in ipairs(fields) do values[field] = rawget(self, field) end
        local function finalRaw(includePoint)
            local ok, same = pcall(function()
                if not rawOwned() or addon.char ~= character then return false end
                for _, field in ipairs(fields) do
                    if not rawequal(rawget(self, field), values[field]) then return false end
                end
                return not includePoint or (rawequal(rawget(point, "mapID"), map) and rawequal(rawget(point, "x"), x) and rawequal(rawget(point, "y"), y))
            end)
            return ok and same == true
        end
        if not finalRaw() then return false end
        local valid = read(predicate, "boolean") == true
        if not valid or not owned() or not finalRaw() then return false end
        if clean(point.mapID, "number") ~= map or clean(point.x, "number") ~= x or clean(point.y, "number") ~= y then return false end
        if not owned() then return false end
        return finalRaw(true)
    end
    if current() then return { current = current, dungeon = dungeon, point = point, navigation = navigation, start = start } end
end

function UI:RefreshQuestEntrance(ownerCurrent)
    local control, dungeon, frame, character = self.questEntrance, self.dungeon, self.frame, addon.char
    local revision = {}; self.questEntranceRevision = revision
    local function current()
        return ownerCurrent() and self.questEntranceRevision == revision and self.questEntrance == control and
            self.frame == frame and self.dungeon == dungeon and addon.char == character
    end
    local function write(object, method, ...) return self:QuestListWrite(object, method, current, ...) end
    if not write(control, "Hide") or not write(control, "SetEnabled", false) or not write(control, "SetScript", "OnClick", nil) then return false end
    control.entranceBinding, control.entranceCurrent, control.entranceDungeon = nil, nil, nil
    if not dungeon then self.questEntranceCache = nil; return current() end
    local binding, found
    for _, card in ipairs(self.cards) do
        if card.entranceDungeon == dungeon and addon.Read(card.IsShown, "boolean", card) == true and
            card.entranceCurrent and card.entranceCurrent() then
            local candidate = card.entranceBinding
            if not candidate or candidate.current() then binding, found = candidate, true end
            if found then break end
        end
        if not current() then return false end
    end
    if not found then
        local cache = self.questEntranceCache
        if not cache or cache.dungeon ~= dungeon or cache.character ~= character or cache.frame ~= frame or
            addon.Entrances ~= cache.provider or addon.Navigation ~= cache.navigation or
            (cache.provider and addon.Clean(cache.provider, "table") and rawget(cache.provider, "Get") ~= cache.getter) or
            (cache.navigation and addon.Clean(cache.navigation, "table") and rawget(cache.navigation, "StartEntrance") ~= cache.start) or
            (not cache.binding and cache.catalogGeneration ~= self.catalogGeneration) or
            (cache.binding and not cache.binding.current()) then
            cache = { dungeon = dungeon, character = character, frame = frame, provider = addon.Entrances, navigation = addon.Navigation }
            cache.getter = addon.Clean(cache.provider, "table") and rawget(cache.provider, "Get")
            cache.start = addon.Clean(cache.navigation, "table") and rawget(cache.navigation, "StartEntrance")
            cache.catalogGeneration = self.catalogGeneration
            self.questEntranceCache = cache
            local function cacheCurrent()
                return addon.UI == self and self.questEntranceCache == cache and self.dungeon == dungeon and
                    self.frame == frame and addon.char == character and addon.Entrances == cache.provider and addon.Navigation == cache.navigation and
                    (not addon.Clean(cache.provider, "table") or rawget(cache.provider, "Get") == cache.getter) and
                    (not addon.Clean(cache.navigation, "table") or rawget(cache.navigation, "StartEntrance") == cache.start)
            end
            cache.binding = self:GetEntranceBinding(dungeon, cacheCurrent)
            if not current() or not cacheCurrent() then return false end
        end
        binding = cache.binding
    end
    if not current() then return false end
    control.entranceBinding, control.entranceDungeon, control.entranceCurrent = binding, dungeon, current
    control.footerEnabled = binding ~= nil
    self:RefreshFooterIcon(control)
    if not current() or not write(control, "SetEnabled", binding ~= nil) or
        not write(control, "SetScript", "OnClick", function()
            if not current() or control.entranceBinding ~= binding or not binding or not binding.current() or
                addon.Read(frame.IsShown, "boolean", frame) ~= true or not current() then return end
            pcall(binding.start, dungeon, binding.point)
        end) or not write(control, "Show") then return false end
    return current()
end

function UI:QuestRowNavigationHint(row, binding)
    local control = row.navigationControl
    if row.navigationBinding ~= binding or not binding.current() then return end
    self:HideNavigationHint()
    local tip, localize = addon.Clean(GameTooltip, "table") or addon.Clean(GameTooltip, "userdata"), addon.L
    local nameGetter, areaGetter, sourceGetter = addon.GiverName, addon.SourceAreaName, addon.SourceName
    local sourceProof, areaProof
    local frame, engine, character = self.frame, self.engine, addon.char
    local quest, dungeon, generation, listGeneration = self.quest, self.dungeon, self.rewardGeneration, self.questListGeneration
    local mapRoot = C_Map
    local mapNamespace = addon.Clean(mapRoot, "table")
    local mapGetter = mapNamespace and rawget(mapNamespace, "GetMapInfo")
    local localeGetter = GetLocale
    local gameLocale = addon.Read(localeGetter, "string")
    local database = addon.db
    local locale = database and rawget(database, "locale")
    local function current()
        local language = addon.Read(localeGetter, "string")
        return row.navigationBinding == binding and binding.current() and addon.L == localize and addon.GiverName == nameGetter and addon.SourceAreaName == areaGetter and addon.SourceName == sourceGetter and addon.db == database and
            C_Map == mapRoot and (not mapNamespace or rawget(mapNamespace, "GetMapInfo") == mapGetter) and
            GetLocale == localeGetter and language == gameLocale and
            (not database or rawget(database, "locale") == locale) and GameTooltip == tip and
            addon.Read(row.IsShown, "boolean", row) == true and addon.Read(self.frame.IsShown, "boolean", self.frame) == true and
            (not sourceProof or addon.Read(sourceProof, "boolean") == true) and addon.SourceName == sourceGetter and
            (not areaProof or addon.Read(areaProof, "boolean") == true) and addon.SourceAreaName == areaGetter and
            self.frame == frame and self.engine == engine and addon.char == character and self.quest == quest and self.dungeon == dungeon and
            self.rewardGeneration == generation and self.questListGeneration == listGeneration and row.navigationBinding == binding and GameTooltip == tip
    end
    if not tip or not current() then return end
    local title = addon.Read(localize, "string", (binding.inspect or binding.reason == "QUEST_START_UNKNOWN") and "SOURCE_DETAILS" or binding.action and (binding.mapOnly and "GIVER_MAP" or "VISIT_GIVER") or "DETAIL_GIVER")
    local text = binding.reason and addon.Read(localize, "string", binding.reason)
    if not text and binding.action then
        local point = binding.action.place
        if type(sourceGetter) == "function" then
            local ok, name, proof = pcall(sourceGetter, point, current)
            if not current() then return end
            proof = addon.Clean(proof, "function")
            if ok and proof and addon.Read(proof, "boolean") == true then
                sourceProof, text = proof, addon.Clean(name, "string")
            end
        end
        if not text or #text > 1024 or not text:find("%S") then text = addon.Read(nameGetter, "string", point) end
        if not current() then return end
        if not text or #text > 1024 or not text:find("%S") then text = addon.Clean(rawget(point, "name"), "string") end
        if not text or #text > 1024 or not text:find("%S") then text = addon.Read(localize, "string", "UNKNOWN_PLACE") end
        local canonical = addon.Clean(rawget(point, "zoneName"), "string")
        local zone
        if type(areaGetter) == "function" then
            local ok, label, proof = pcall(areaGetter, canonical, current)
            if not current() then return end
            proof = addon.Clean(proof, "function")
            if proof then
                if addon.Read(proof, "boolean") ~= true or not current() then return end
                areaProof = proof
            end
            if ok then zone = addon.Clean(label, "string") end
        end
        zone = zone or canonical or addon.Clean(rawget(point, "locationName"), "string")
        if not zone then
            local info = addon.Read(mapGetter, "table", binding.map)
            if not current() then return end
            zone = info and addon.Clean(rawget(info, "name"), "string")
        end
        if text and zone then text = text .. " — " .. zone end
        if text and not binding.mapOnly then text = text .. string.format(" (%.1f, %.1f)", binding.x, binding.y) end
    end
    if not title or not text or not current() then return end
    local held = { tip = tip, button = control }; self.navigationTooltip = held
    for _, operation in ipairs({ { "SetOwner", control, "ANCHOR_RIGHT" }, { "SetText", title }, { "AddLine", text, 1, 1, 1, true }, { "Show" } }) do
        if not current() or self.navigationTooltip ~= held then return end
        local fn = addon.Clean(tip[operation[1]], "function")
        if not fn or not pcall(fn, tip, unpack(operation, 2)) or not current() or self.navigationTooltip ~= held or
            addon.Read(tip.IsOwned, "boolean", tip, control) ~= true or not current() then
            if self.navigationTooltip == held then self:HideNavigationHint() end
            return
        end
    end
    self:RetainNavigationHint(held, current)
end

function UI:HasSummonSource(endpoint)
    endpoint = addon.Clean(endpoint, "table")
    if not endpoint then return false end
    local objectID = addon.Clean(rawget(endpoint, "objectID"), "number")
    if not objectID or objectID <= 0 or objectID > 4294967295 or objectID % 1 ~= 0 then return false end
    if rawget(endpoint, "npcID") ~= nil or rawget(endpoint, "itemID") ~= nil or rawget(endpoint, "mapID") ~= nil or rawget(endpoint, "x") ~= nil or rawget(endpoint, "y") ~= nil or rawget(endpoint, "reportedLocations") ~= nil then return false end
    local relation = rawget(endpoint, "summonItem")
    if type(issecretvalue) == "function" and addon.Read(issecretvalue, "boolean", relation) ~= false then return true end
    return relation ~= nil
end

-- Shared start-record predicates: one classification for list grouping and
-- overview labels, so summon and item-only pickups never diverge by surface.
-- A nil or non-table alternatives value counts as absent; the catalogue schema
-- rejects such input and no live record carries it.
function UI:IsEmptyAlternatives(value)
    local list = addon.Clean(value, "table")
    if list == nil then return true end
    return #list == 0
end

-- Classify a pickup start once: "uncertain" for a summon pickup, "item" for an
-- item-only starter, nil for ordinary or unshaped starts. Bounds, exclusivity
-- and secret rejection mirror the overview shape rules; start-less records
-- classify as nil and callers map a missing place to uncertain so the
-- row/detail unknown-start wording stays truthful.
function UI:PickupStartKind(start, alternatives)
    local clean, read, checker = addon.Clean, addon.Read, issecretvalue
    if type(clean) ~= "function" or type(read) ~= "function" then return nil end
    local function restricted(value)
        return type(checker) == "function" and read(checker, "boolean", value) ~= false
    end
    local function validID(value)
        value = clean(value, "number")
        if not value or value % 1 ~= 0 or value < 1 or value > 4294967295 then return nil end
        return value
    end
    start = clean(start, "table")
    if not start or restricted(start) then return nil end
    local alternativeList
    if alternatives ~= nil then
        alternativeList = clean(alternatives, "table")
        if not alternativeList then return nil end
        if self:IsEmptyAlternatives(alternativeList) then
            for _ in pairs(alternativeList) do return nil end
        else
            if restricted(alternatives) then return nil end
            local count = 0
            for key, entry in pairs(alternativeList) do
                if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then return nil end
                if not clean(entry, "table") then return nil end
                if restricted(entry) then return nil end
                count = count + 1
            end
            if count ~= #alternativeList then return nil end
        end
    end
    local hasAlternatives = alternativeList ~= nil and not self:IsEmptyAlternatives(alternativeList)
    if validID(rawget(start, "objectID")) and rawget(start, "npcID") == nil and rawget(start, "itemID") == nil and
        rawget(start, "mapID") == nil and rawget(start, "x") == nil and rawget(start, "y") == nil and
        rawget(start, "reportedLocations") == nil and not restricted(rawget(start, "summonItem")) then
        local summonItem = clean(rawget(start, "summonItem"), "table")
        -- A summon tool without a nonblank, length-bounded name agrees with
        -- SummonSource: it never classifies as uncertain on its own.
        local summonName = summonItem and clean(rawget(summonItem, "name"), "string")
        if summonItem and validID(rawget(summonItem, "itemID")) and summonName and #summonName <= 500 and
            summonName:find("%S") then return "uncertain" end
    end
    if not hasAlternatives and validID(rawget(start, "itemID")) and
        rawget(start, "npcID") == nil and rawget(start, "objectID") == nil and not restricted(rawget(start, "itemID")) then
        return "item"
    end
    return nil
end

-- Informational use-item relation for a mapless object endpoint, never a travel destination.
function UI:SummonSource(endpoint)
    local clean, reader, checker = addon.Clean, addon.Read, issecretvalue
    endpoint = clean(endpoint, "table")
    if not endpoint then return nil end
    local relation = clean(rawget(endpoint, "summonItem"), "table")
    if not relation then return nil end
    local fields = { "objectID", "npcID", "itemID", "mapID", "x", "y", "name", "summonItem", "reportedLocations" }
    local values = {}; for _,field in ipairs(fields) do values[field] = rawget(endpoint, field) end
    local itemID, name = clean(rawget(relation, "itemID"), "number"), clean(rawget(relation, "name"), "string")
    local objectID, objectName = clean(values.objectID, "number"), clean(values.name, "string")
    local function same()
        if addon.Clean ~= clean or addon.Read ~= reader or issecretvalue ~= checker or values.summonItem ~= relation then return false end
        for _,field in ipairs(fields) do if not rawequal(rawget(endpoint, field), values[field]) then return false end end
        return rawequal(rawget(relation, "itemID"), itemID) and rawequal(rawget(relation, "name"), name)
    end
    local function current()
        if not same() then return false end
        if type(checker)=="function" then
            for _,field in ipairs(fields) do if reader(checker,"boolean",rawget(endpoint,field))~=false then return false end end
            if reader(checker,"boolean",rawget(relation,"itemID"))~=false or reader(checker,"boolean",rawget(relation,"name"))~=false then return false end
        end
        return same()
    end
    if not current() then return nil end
    if not itemID or itemID<=0 or itemID>4294967295 or itemID%1~=0 or not objectID or objectID<=0 or objectID>4294967295 or objectID%1~=0 or
        not name or #name>500 or not name:find("%S") or not objectName or not objectName:find("%S") or
        values.npcID~=nil or values.itemID~=nil or values.mapID~=nil or values.x~=nil or values.y~=nil or values.reportedLocations~=nil or not current() then return nil end
    return { itemID=itemID, name=name, objectID=objectID, objectName=objectName, current=current, same=same }
end

function UI:BindQuestRowNavigation(row, id, ownerCurrent)
    local control = row.navigationControl
    local function write(object, method, ...) return self:QuestListWrite(object, method, ownerCurrent, ...) end
    if control and self.navigationTooltip and self.navigationTooltip.button == control then
        self:HideNavigationHint()
        if not ownerCurrent() then return false end
    end
    row.navigationReserve, row.navigationBinding = 0, nil
    if control and (not write(control, "Hide") or not write(control, "SetEnabled", false) or not write(control, "SetScript", "OnClick", nil)) then return false end
    if not id then return ownerCurrent() end
    if not control then
        control = CreateFrame("Button", nil, row)
        if not ownerCurrent() then return false end
        row.navigationControl = control
        control:SetSize(24, 24)
        if type(control.SetMotionScriptsWhileDisabled) == "function" then control:SetMotionScriptsWhileDisabled(true) end
        control.footerIcon = self:CreateGoldNavigationIcon(control)
        control.sourceInspect = false
    end
    local catalogue, definition, checker = addon.quests, addon.quests[id], issecretvalue
    local rawStart = definition and rawget(definition, "start")
    local start = addon.Clean(rawStart, "table")
    local sourceID = definition and rawget(definition, "id")
    local alternatives = definition and rawget(definition, "startAlternatives")
    local alternativeList = addon.Clean(alternatives, "table")
    local alternativeCount, alternativeMembers = alternativeList and #alternativeList or 0, {}
    for index = 1, math.min(alternativeCount, 100) do alternativeMembers[index] = rawget(alternativeList, index) end
    local fields = { npcID = "number", objectID = "number", itemID = "number", dropNPCID = "number", name = "string", zoneName = "string", locationName = "string", mapID = "number", x = "number", y = "number" }
    local values, rawValues, readable = {}, {}, true
    for field, kind in pairs(fields) do
        local raw = start and rawget(start, field)
        rawValues[field] = raw
        if type(checker) == "function" and addon.Read(checker, "boolean", raw) ~= false then readable = false
        elseif raw ~= nil then
            local value = addon.Clean(raw, kind)
            if value == nil then readable = false else values[field] = value end
        end
    end
    local navigationRoot = addon.Navigation
    local navigation = addon.Clean(navigationRoot, "table")
    local mapOnly = not (values.x and values.y and values.x >= 0 and values.x <= 100 and values.y >= 0 and values.y <= 100)
    local rawMethod = navigation and rawget(navigation, mapOnly and "Map" or "Start")
    local method = addon.Clean(rawMethod, "function")
    local summonGetter = self.SummonSource
    local declarationGetter = self.HasSummonSource
    local declaredSummon = addon.Read(declarationGetter,"boolean",self,start) ~= false
    local rawSummon = start and rawget(start,"summonItem")
    local summon = addon.Read(summonGetter, "table", self, start)
    local inspector = self.InspectQuest
    local inspectMethod = addon.Clean(inspector, "function")
    local binding = { mapOnly = mapOnly, map = values.mapID, x = values.x, y = values.y }
    local function current()
        if not ownerCurrent() or row.navigationBinding ~= binding or addon.quests ~= catalogue or catalogue[id] ~= definition or
            addon.Navigation ~= navigationRoot or issecretvalue ~= checker or row.navigationControl ~= control or
            self.SummonSource ~= summonGetter or self.HasSummonSource ~= declarationGetter or not rawequal(start and rawget(start,"summonItem"),rawSummon) or (summon and not summon.current()) or
            (binding.inspect and self.InspectQuest ~= inspector) then return false end
        local ok, same = pcall(function()
            if not definition or rawget(definition, "start") ~= rawStart or rawget(definition, "startAlternatives") ~= alternatives or rawget(definition, "id") ~= sourceID then return false end
            if alternativeList then
                if #alternativeList ~= alternativeCount then return false end
                for index = 1, math.min(alternativeCount, 100) do
                    if rawget(alternativeList, index) ~= alternativeMembers[index] then return false end
                end
            end
            for field, kind in pairs(fields) do
                local raw = start and rawget(start, field)
                if type(checker) == "function" and addon.Read(checker, "boolean", raw) ~= false then return false end
                if raw ~= rawValues[field] then return false end
            end
            for field in pairs(fields) do if (start and rawget(start, field)) ~= rawValues[field] then return false end end
            return ownerCurrent() and row.navigationBinding == binding and addon.quests == catalogue and catalogue[id] == definition and
                addon.Navigation == navigationRoot and issecretvalue == checker and
                (not navigation or rawget(navigation, mapOnly and "Map" or "Start") == rawMethod) and
                self.SummonSource == summonGetter and self.HasSummonSource == declarationGetter and rawequal(start and rawget(start,"summonItem"),rawSummon) and (not summon or summon.same()) and
                (not binding.inspect or self.InspectQuest == inspector)
        end)
        return ok and same == true
    end
    binding.current = current
    local markerPurpose
    -- Single shared pickup-shape authority: the row item grant follows
    -- PickupStartKind on the same raw inputs so item+alternatives shapes
    -- cannot claim item navigation while list/overview/detail say
    -- outside/choices. The legacy inline verdict stays as the fallback
    -- when the shared helper is ever unavailable.
    local pickupClassifier = self.PickupStartKind
    local itemOnly
    if type(pickupClassifier) == "function" then
        itemOnly = addon.Read(pickupClassifier, "string", self, rawStart, alternatives) == "item"
    else
        itemOnly = values.itemID and not values.npcID and not values.objectID
    end
    if summon then binding.inspect, binding.reason = true, "SOURCE_DETAILS_HINT"
    elseif declaredSummon then binding.reason = "GIVER_LOCATION_UNKNOWN"
    elseif rawSummon ~= nil and summon == nil then binding.reason = "QUEST_START_UNKNOWN"
    elseif definition and rawequal(rawStart, nil) and UI:IsEmptyAlternatives(alternatives) then binding.reason = "QUEST_START_UNKNOWN"
    elseif rawValues.itemID ~= nil then
        if itemOnly and readable and values.itemID > 0 and values.itemID <= 4294967295 and values.itemID % 1 == 0 then
            binding.inspect, binding.reason = true, "START_ITEM_NAVIGATION"
        elseif alternativeList and alternativeCount > 0 then binding.inspect, binding.reason = true, "SOURCE_DETAILS_HINT"
        else binding.reason = "QUEST_START_UNKNOWN" end
    elseif not start and alternativeList and alternativeCount > 0 then binding.inspect, binding.reason = true, "SOURCE_DETAILS_HINT"
    elseif not readable or not start or not values.mapID or values.mapID <= 0 or values.mapID > 9007199254740991 or values.mapID % 1 ~= 0 then
        local area = values.zoneName
        if not area or not area:find("%S") then area = values.locationName end
        binding.reason = readable and area and area:find("%S") and "SOURCE_POSITION_UNKNOWN" or "GIVER_LOCATION_UNKNOWN"
    elseif not method then binding.reason = "NAVIGATION_UNAVAILABLE"
    else
        binding.action = { id = id, kind = "visit", place = start }
        local npc, object = values.npcID, values.objectID
        local function typed(value) return value and value > 0 and value <= 4294967295 and value % 1 == 0 end
        if ((typed(npc) and rawValues.objectID == nil) or (typed(object) and rawValues.npcID == nil)) and rawValues.dropNPCID == nil then markerPurpose = "quest-start" end
    end
    if binding.inspect and not inspectMethod then binding.reason = "NAVIGATION_UNAVAILABLE" end
    local enabled = binding.action ~= nil or (binding.inspect == true and inspectMethod ~= nil)
    row.navigationReserve, row.navigationBinding = 32, binding
    local function leave()
        local held = self.navigationTooltip
        if held and held.button == control and row.navigationBinding == binding then self:HideNavigationHint() end
    end
    if not self:PaintQuestRowSourceIcon(control, binding.inspect == true, ownerCurrent) then return false end
    control.footerEnabled = enabled
    self:RefreshFooterIcon(control)
    if not ownerCurrent() or not write(control, "ClearAllPoints") or
        not write(control, "SetPoint", "TOPRIGHT", row, "TOPRIGHT", -4, -3) or
        not write(control, "SetEnabled", enabled) or
        not write(control, "SetScript", "OnClick", function()
            if not current() or addon.Read(row.IsShown, "boolean", row) ~= true or
                addon.Read(self.frame.IsShown, "boolean", self.frame) ~= true or not current() then return end
            if binding.inspect and inspectMethod then pcall(inspectMethod, self, id, true, true)
            elseif binding.action then self:DispatchDetail(binding.action, mapOnly, false, current, markerPurpose) end
        end) or not write(control, "SetScript", "OnEnter", function() self:QuestRowNavigationHint(row, binding) end) or
        not write(control, "SetScript", "OnLeave", leave) or not write(control, "SetScript", "OnHide", leave) or
        not write(control, "Show") then return false end
    return ownerCurrent()
end

function UI:RefreshEntrance()
    local frame, dungeon, quest, character, generation = self.frame, self.dungeon, self.quest, addon.char, self.rewardGeneration
    self.entranceBinding = nil
    if quest then return false end
    local function current()
        return addon.UI == self and self.frame == frame and self.dungeon == dungeon and self.quest == quest and
            addon.char == character and self.rewardGeneration == generation
    end
    local binding = self:GetEntranceBinding(dungeon, current)
    if current() then self.entranceBinding = binding end
    return binding ~= nil
end

function UI:CatalogEntranceHint(row)
    self:HideNavigationHint()
    local control, binding, owner = row.entranceControl, row.entranceBinding, row.entranceCurrent
    local tip = addon.Clean(GameTooltip, "table") or addon.Clean(GameTooltip, "userdata")
    local function current()
        return tip and GameTooltip == tip and row.entranceCurrent == owner and owner and owner() and
            row.entranceBinding == binding and addon.Read(row.IsShown, "boolean", row) == true and addon.Read(self.frame.IsShown, "boolean", self.frame) == true
    end
    if not current() then return end
    local text = addon.Read(addon.DungeonName, "string", row.entranceDungeon)
    if not current() or not text then return end
    local point = binding and binding.current() and binding.point
    if not current() then return end
    if point then
        local zone = addon.Clean(point.zoneName, "string") or addon.Clean(point.name, "string")
        if zone then text = text .. "\n" .. zone end
        local x, y = addon.Clean(point.x, "number"), addon.Clean(point.y, "number")
        if not x or not y or x < 0 or x > 100 or y < 0 or y > 100 or not binding.current() or not current() then return end
        text = text .. string.format(" (%.1f, %.1f)", x, y)
        if addon.Clean(point.origin, "string") == "recorded" then
            text = text .. "\n" .. addon.L("DUNGEON_ENTRANCE_RECORDED")
            local source = addon.Clean(point.source, "string")
            if source and #source <= 2048 and source:match("^https://") then text = text .. "\n" .. source end
        end
        if addon.Clean(point.kind, "string") == "approach" then text = text .. "\n" .. addon.L("DUNGEON_ENTRANCE_APPROACH") end
        if addon.Clean(point.scope, "string") == "shared" then text = text .. "\n" .. addon.L("DUNGEON_ENTRANCE_SHARED") end
    else text = text .. "\n" .. addon.L("DUNGEON_ENTRANCE_UNKNOWN") end
    if not current() then return end
    local held = { tip = tip, button = control }; self.navigationTooltip = held
    for _, call in ipairs({ { "SetOwner", control, "ANCHOR_RIGHT" }, { "SetText", addon.L("DUNGEON_ENTRANCE") },
        { "AddLine", text, 1, 1, 1, true }, { "Show" } }) do
        if not current() or self.navigationTooltip ~= held then return end
        local fn = addon.Clean(tip[call[1]], "function")
        if not fn or not pcall(fn, tip, unpack(call, 2)) then
            if self.navigationTooltip == held then self:HideNavigationHint() end
            return
        end
        if not current() or self.navigationTooltip ~= held or addon.Read(tip.IsOwned, "boolean", tip, control) ~= true or
            not current() or self.navigationTooltip ~= held then
            if self.navigationTooltip == held then self:HideNavigationHint() end
            return
        end
    end
    self:RetainNavigationHint(held, current)
end

function UI:VisitEntrance()
    local binding, frame = self.entranceBinding, self.frame
    if not binding or not frame or not binding.current() then return false end
    local shown = addon.Read(frame.IsShown, "boolean", frame)
    if shown ~= true or self.entranceBinding ~= binding or self.frame ~= frame or not binding.current() then return false end
    return pcall(binding.start, binding.dungeon, binding.point)
end

-- Only completed hints may be restored after an older native Hide returns late.
function UI:RetainTooltipHint(held, ownerCurrent, slot)
    local tip, button = held.tip or held.tooltip, held.button
    local show, owned = addon.Clean(tip.Show, "function"), addon.Clean(tip.IsOwned, "function")
    local function current()
        return self[slot] == held and GameTooltip == tip and ownerCurrent() and
            addon.Read(button.IsShown, "boolean", button) == true and
            self[slot] == held and tip.Show == show and tip.IsOwned == owned
    end
    if not show or not owned or not current() then return end
    local snapshots = {}
    local function remember(object, keys)
        object = addon.Clean(object, "table")
        if not object then return end
        for _, key in ipairs(keys) do
            snapshots[#snapshots + 1] = { object, key, rawget(object, key) }
        end
    end
    remember(addon, { "UI", "char", "db", "quests", "dungeons", "L", "Clean", "Read", "Language" })
    remember(self, { "frame", "quest", "dungeon", "engine", "rewardGeneration", "catalogGeneration", "questListGeneration",
        "range", "includeUnavailable", "detailNavigationRevision", "languageLabelRevision" })
    remember(addon.db, { "locale" })
    remember(button, { "rewardBinding", "objectiveBinding" })
    remember(held.binding, { "quest", "generation", "id", "origin", "source", "kind", "index", "current", "context" })
    local engine = addon.Clean(self.engine, "table")
    remember(engine, { "invalid", "context", "quests", "states", "Current" })
    remember(engine and rawget(engine, "context"), { "current", "level", "faction", "class", "completed", "active", "ready" })
    if not current() then return end
    local function unchanged()
        for _, snapshot in ipairs(snapshots) do
            if not rawequal(rawget(snapshot[1], snapshot[2]), snapshot[3]) then return false end
        end
        return true
    end
    held.restore = function()
        -- Complete source and visibility reads before the final native ownership
        -- check; finish with callback-free view proofs before showing anything.
        if not current() then return end
        local ours = addon.Read(owned, "boolean", tip, button) == true
        local ok, fresh = pcall(unchanged)
        if ours and ok and fresh and self[slot] == held and GameTooltip == tip and tip.Show == show and tip.IsOwned == owned then
            pcall(show, tip)
        end
    end
    if addon.TooltipLease then addon.TooltipLease.Retain(tip, held, held.restore) end
end

function UI:DetailContactHint(control, heading, name, zone, ownerCurrent)
    local read, clean = addon.Read, addon.Clean
    if read(ownerCurrent, "boolean") ~= true then return end
    self:HideNavigationHint()
    if read(ownerCurrent, "boolean") ~= true then return end
    local tip = clean(GameTooltip, "table") or clean(GameTooltip, "userdata")
    if not tip then return end
    local methods = {}
    for _, key in ipairs({ "IsOwned", "SetOwner", "SetText", "AddLine", "Show" }) do
        methods[key] = clean(tip[key], "function")
        if not methods[key] then return end
    end
    local held = { tip = tip, button = control }
    local function current()
        if addon.Read ~= read or addon.Clean ~= clean or GameTooltip ~= tip or read(ownerCurrent, "boolean") ~= true then return false end
        for key, method in pairs(methods) do if tip[key] ~= method then return false end end
        return GameTooltip == tip and addon.Read == read and addon.Clean == clean
    end
    if not current() then return end
    self.navigationTooltip = held
    for _, call in ipairs({ { "SetOwner", control, "ANCHOR_RIGHT" }, { "SetText", heading },
        { "AddLine", name, 1, .82, .35, true }, { "AddLine", zone, .7, .7, .7, true }, { "Show" } }) do
        if self.navigationTooltip ~= held or not current() then self:HideNavigationHint(held); return end
        local ok = pcall(methods[call[1]], tip, unpack(call, 2))
        if not ok or self.navigationTooltip ~= held or not current() or
            read(methods.IsOwned, "boolean", tip, control) ~= true or not current() then
            self:HideNavigationHint(held); return
        end
    end
    self:RetainNavigationHint(held, current)
    return held
end

function UI:RetainNavigationHint(held, ownerCurrent)
    self:RetainTooltipHint(held, ownerCurrent, "navigationTooltip")
end

function UI:HideNavigationHint(expected)
    local held = self.navigationTooltip
    if not held or (expected and expected ~= held and expected ~= held.button) then return end
    self.navigationTooltip = nil
    local tip = held.tip
    if addon.TooltipLease then addon.TooltipLease.Retire(tip, held) end
    local owned, hide = addon.Clean(tip.IsOwned, "function"), addon.Clean(tip.Hide, "function")
    local ours = GameTooltip == tip and addon.Read(owned, "boolean", tip, held.button) == true
    -- Ownership inspection can open another hint on the shared native tooltip.
    if ours and not self.navigationTooltip and GameTooltip == tip and tip.IsOwned == owned and tip.Hide == hide and hide then
        pcall(hide, tip)
        if addon.TooltipLease then addon.TooltipLease.Restore(tip, held); return end
        local newer = self.navigationTooltip
        if newer and newer ~= held and newer.restore and not self.navigationTooltipRepair then
            self.navigationTooltipRepair = true
            pcall(newer.restore)
            self.navigationTooltipRepair = nil
        end
    end
end

function UI:CatalogStatusHint(row)
    self:HideNavigationHint()
    local frame, dto, owned, result = self.frame, row.dungeonStatusDTO, row.dungeonStatusCurrent, row.catalogResult
    local control = row.dungeonStatusControl
    local countMode = result and result.includeUnavailable
    local tip = addon.Clean(GameTooltip, "table") or addon.Clean(GameTooltip, "userdata")
    local isOwned = tip and addon.Clean(tip.IsOwned, "function")
    local function current()
        local shown = addon.Read(frame.IsShown, "boolean", frame)
        return self.includeUnavailable == countMode and shown == true and addon.Read(row.IsShown, "boolean", row) == true and addon.UI == self and self.frame == frame and row.catalogResult == result and row.dungeonStatusDTO == dto and
            row.dungeonStatusCurrent == owned and owned and owned() and GameTooltip == tip and tip.IsOwned == isOwned
    end
    if not tip or not isOwned or not dto or not current() then return end
    local status = addon.Clean(dto.status, "string")
    local allowed = { READY=true, AVAILABLE=true, ACTIVE=true, UNKNOWN=true, LOCKED=true, COMPLETED=true, UNAVAILABLE=true }
    if not status or not allowed[status] or not current() then return end
    local name = addon.Read(addon.DungeonName, "string", row.entranceDungeon)
    if not name or not current() then return end
    local reason = addon.Clean(dto.reason, "string")
    local listed = addon.Clean(dto.listed, "number")
    local statusKey = reason == "level" and "DUNGEON_STATUS_LEVEL" or
        (listed == 0 and "DUNGEON_STATUS_EMPTY" or ("DUNGEON_STATUS_" .. status))
    local minimum = result and addon.Clean(result.minimum, "number")
    local maximum = result and addon.Clean(result.maximum, "number")
    local count = result and addon.Clean(result.count, "number")
    if not minimum or not maximum or not count or not current() then return end
    local held = { tip=tip, button=control }; self.navigationTooltip=held
    for _, call in ipairs({ { "SetOwner", control, "ANCHOR_RIGHT" }, { "SetText", name .. " — " .. addon.L("DUNGEON_STATUS") },
        { "AddLine", addon.L(statusKey), 1, 1, 1, true },
        { "AddLine", addon.L("CATALOG_LEVELS", minimum, maximum) .. " · " .. addon.L("CATALOG_QUESTS", count), .8, .8, .8, true },
        { "AddLine", addon.L("DUNGEON_STATUS_SCOPE"), .7, .7, .7, true }, { "Show" } }) do
        if not current() or self.navigationTooltip ~= held then return end
        local method = addon.Clean(tip[call[1]], "function")
        if not method or not pcall(method, tip, unpack(call, 2)) or not current() or self.navigationTooltip ~= held or
            addon.Read(isOwned, "boolean", tip, control) ~= true or not current() or self.navigationTooltip ~= held then
            if self.navigationTooltip == held then self:HideNavigationHint() end
            return
        end
    end
    self:RetainNavigationHint(held, current)
end

function UI:QuestListHint(row)
    self:HideNavigationHint()
    local owner, frame = row.questListCurrent, self.frame
    local tip = addon.Clean(GameTooltip, "table") or addon.Clean(GameTooltip, "userdata")
    local function current()
        return tip and row.questListCurrent == owner and owner and owner() and self.frame == frame and
            GameTooltip == tip and addon.Read(frame.IsShown, "boolean", frame) == true and owner()
    end
    if not current() then return end
    local title = addon.Read(row.title.GetText, "string", row.title)
    local note = addon.Read(row.note.GetText, "string", row.note)
    if not current() or not title or not note then return end
    if row.dungeonTarget then
        local dungeonName = addon.Clean(row.dungeonName, "string")
        if not current() or not dungeonName then return end
        note = note .. "\n" .. dungeonName .. " — " .. addon.L("QUESTS")
    end
    if row.chainExpandable then note = note .. "\n" .. addon.L(row.chainExpanded and "CHAIN_COLLAPSE" or "CHAIN_EXPAND") end
    local branchControl = row.branchControl
    if branchControl and addon.Read(branchControl.IsShown, "boolean", branchControl) == true then
        note = note .. "\n" .. addon.L("BRANCH_GROUP", branchControl.branchGroup) .. "\n" ..
            addon.L(branchControl.branchSelected and "BRANCH_RESET" or "BRANCH_PREFER")
    end
    if not current() then return end
    local held = { tip = tip, button = row }; self.navigationTooltip = held
    for _, call in ipairs({ { "SetOwner", row, "ANCHOR_RIGHT" }, { "SetText", title }, { "AddLine", note, 1, 1, 1, true }, { "Show" } }) do
        if not current() or self.navigationTooltip ~= held then return end
        local fn = addon.Clean(tip[call[1]], "function")
        if not fn or not pcall(fn, tip, unpack(call, 2)) or not current() or self.navigationTooltip ~= held then
            if self.navigationTooltip == held then self:HideNavigationHint() end
            return
        end
    end
    self:RetainNavigationHint(held, current)
end

function UI:RefreshFooterIcon(control)
    local icon = control.footerIcon
    if not icon or (control.footerPaintDepth or 0) >= 3 then return end
    control.footerPaintDepth = (control.footerPaintDepth or 0) + 1
    local revision = {}; control.footerPaint = revision
    local enabled, pressed, hovered, gold = control.footerEnabled == true, control.footerPressed, control.footerHovered, control.navigationGold
    local parts = control.footerIconParts
    local alpha = gold and (enabled and (pressed and .8 or hovered and 1 or .95) or .6) or
        (enabled and (pressed and .65 or hovered and 1 or .88) or .3)
    local function fresh()
        return control.footerPaint == revision and control.footerIcon == icon and control.footerIconParts == parts and
            (control.footerEnabled == true) == enabled and control.footerPressed == pressed and control.footerHovered == hovered and control.navigationGold == gold
    end
    local function finish() control.footerPaintDepth = control.footerPaintDepth - 1 end
    local function repair()
        if not control.footerPaintRepair then
            control.footerPaintRepair = true; self:RefreshFooterIcon(control); control.footerPaintRepair = nil
        end
        finish()
    end
    for _, part in ipairs(parts or { icon }) do
        if type(part.SetAlpha) == "function" then pcall(part.SetAlpha, part, alpha) end
        if not fresh() then repair(); return end
        if type(part.SetDesaturated) == "function" then pcall(part.SetDesaturated, part, not gold and not enabled) end
        if not fresh() then repair(); return end
    end
    finish()
end

function UI:CreateGoldNavigationIcon(control)
    local parts = {}
    for index, geometry in ipairs({ { 3, 14, 0, -3, 0 }, { 3, 10, -3, 3, -math.pi / 4 }, { 3, 10, 3, 3, math.pi / 4 } }) do
        local part = control:CreateTexture(nil, "ARTWORK")
        part:SetTexture("Interface\\Buttons\\WHITE8X8")
        part:SetSize(geometry[1], geometry[2]); part:SetPoint("CENTER", control, "CENTER", geometry[3], geometry[4])
        if type(part.SetRotation) == "function" then part:SetRotation(geometry[5]) end
        if type(part.SetVertexColor) == "function" then part:SetVertexColor(1, .78, .15, 1)
        else part:SetColorTexture(1, .78, .15, 1) end
        part:Show(); parts[index] = part
    end
    control.navigationGold, control.footerIconParts = true, parts
    return parts[1]
end

function UI:PaintQuestRowSourceIcon(control, inspect, current)
    local depth = control.sourceIconDepth or 0
    if depth >= 3 then return false end
    local nested = depth > 0
    control.sourceIconDepth = depth + 1
    -- Nested paints must claim visibility even when the final glyph is unchanged.
    local ok, result = pcall(function()
        local arrow = control.navigationIconParts or control.footerIconParts
        control.navigationIconParts = arrow
        local book = control.sourceIconParts
        if not nested and control.sourceInspect == inspect and control.footerIconParts == (inspect and book or arrow) then return current() end
        if inspect and not book then
            book = {}
            for _, geometry in ipairs({ {2,16,-8,0}, {2,16,8,0}, {2,16,0,0},
                {8,2,-4,7}, {8,2,4,7}, {8,2,-4,-7}, {8,2,4,-7} }) do
                local part = control:CreateTexture(nil, "ARTWORK")
                if not current() then return false end
                book[#book + 1] = part
                for _, operation in ipairs({ {"Hide"}, {"SetTexture", "Interface\\Buttons\\WHITE8X8"},
                    {"SetSize", geometry[1], geometry[2]}, {"SetPoint", "CENTER", control, "CENTER", geometry[3], geometry[4]},
                    {type(part.SetVertexColor) == "function" and "SetVertexColor" or "SetColorTexture", 1, .78, .15, 1} }) do
                    if not self:QuestListWrite(part, operation[1], current, unpack(operation, 2)) then return false end
                end
            end
            control.sourceIconParts = book
        end
        for _, part in ipairs(inspect and arrow or book or {}) do
            if not self:QuestListWrite(part, "Hide", current) then return false end
        end
        local parts = inspect and book or arrow
        for _, part in ipairs(parts) do if not self:QuestListWrite(part, "Show", current) then return false end end
        if not current() then return false end
        control.footerIconParts, control.footerIcon = parts, parts[1]
        control.sourceInspect = inspect
        return true
    end)
    control.sourceIconDepth = control.sourceIconDepth - 1
    return ok and result == true
end

function UI:SetFooterEnabled(control, enabled)
    control.footerEnabled = enabled == true
    if not control.footerEnabled then control.footerPressed, control.footerHovered = false, false end
    control:SetEnabled(enabled == true)
    self:RefreshFooterIcon(control)
end

function UI:SetFooterLabel(control, key)
    control.footerLabelKey = key
    control:SetText("")
    if control.caption then control.caption:SetText(addon.L(key)) end
end
