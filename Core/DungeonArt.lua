local _, addon = ...
local dungeonArtCache, dungeonArtReading
local function artInteger(value)
    value = addon.Clean(value, "number")
    return value and value > 0 and value % 1 == 0 and value or nil
end
local function lfgDungeonArt(mapID)
    local enumerate, info = GetLFDChoiceOrder, GetLFGDungeonInfo
    if type(enumerate) ~= "function" or type(info) ~= "function" or dungeonArtReading then return nil end
    if dungeonArtCache and dungeonArtCache.enumerate == enumerate and dungeonArtCache.info == info then
        return dungeonArtCache.images[mapID] or nil
    end
    dungeonArtReading = true
    local ok, images = pcall(function()
        local list = addon.Read(enumerate, "table")
        if not list then return {} end
        -- Validate the whole dense sequence before reading any native dungeon IDs.
        local count, last = 0, 0
        for key in next, list do
            count = count + 1
            key = artInteger(key)
            if count > 500 or not key or key > 500 then return {} end
            if key > last then last = key end
        end
        if last ~= count then return {} end
        local ids, seen = {}, {}
        for i = 1, count do
            local id = addon.Clean(rawget(list, i), "number")
            if not id or id % 1 ~= 0 then return {} end
            -- Nonpositive entries represent headings, not image sources.
            if id > 0 and not seen[id] then ids[#ids + 1], seen[id] = id, true end
        end
        local found = {}
        for _, id in ipairs(ids) do
            local values = { pcall(info, id) }
            if not values[1] then return {} end
            local instanceID = artInteger(values[23])
            local texture = artInteger(values[12]) or addon.Clean(values[12], "string")
            if type(texture) == "string" and (texture == "" or #texture > 1024) then texture = nil end
            if instanceID and texture then
                if found[instanceID] == nil then found[instanceID] = texture
                elseif found[instanceID] ~= texture then found[instanceID] = false end
            end
        end
        return found
    end)
    dungeonArtReading = nil
    -- Native callbacks may replace capabilities while a scan is in progress.
    if GetLFDChoiceOrder ~= enumerate or GetLFGDungeonInfo ~= info then return nil end
    dungeonArtCache = { enumerate = enumerate, info = info, images = ok and images or {} }
    return dungeonArtCache.images[mapID] or nil
end

function addon.DungeonArt(d)
    local checker = issecretvalue
    d = addon.Clean(d, "table") or {}
    local art = addon.Clean(d.art, "table")
    local fileID = art and artInteger(art.fileID)
    local artMap = art and artInteger(art.gameMapID)
    local mapID = artInteger(d.instanceID)
    local generic = "Interface\\Icons\\INV_Misc_Map_01"
    local function current()
        return issecretvalue == checker and addon.Clean(d.art, "table") == art and
            artInteger(d.instanceID) == mapID and (not art or
                (artInteger(art.fileID) == fileID and artInteger(art.gameMapID) == artMap))
    end
    if not current() then return generic end
    if fileID and artMap and (not mapID or mapID == artMap) then return fileID end
    local journal = addon.Clean(C_EncounterJournal, "table")
    local lookup = journal and addon.Clean(journal.GetInstanceForGameMap, "function")
    local info = addon.Clean(EJ_GetInstanceInfo, "function")
    local function journalCurrent()
        return current() and addon.Clean(C_EncounterJournal, "table") == journal and
            (not journal or addon.Clean(journal.GetInstanceForGameMap, "function") == lookup) and
            addon.Clean(EJ_GetInstanceInfo, "function") == info
    end
    local journalID = mapID and artInteger(addon.Read(lookup, "number", mapID))
    if not journalCurrent() then return generic end
    if journalID and info then
        local values = { pcall(info, journalID) }
        local texture = values[1] and (artInteger(values[7]) or addon.Clean(values[7], "string"))
        if type(texture) == "string" and (texture == "" or #texture > 1024) then texture = nil end
        if not journalCurrent() then return generic end
        if texture then return texture end
    end
    local image = mapID and lfgDungeonArt(mapID)
    return current() and image or generic
end

local dungeonArtPaints = setmetatable({}, { __mode = "k" })
function addon.PaintDungeonArt(texture, dungeon, mode, showOwned)
    local token = {}
    dungeonArtPaints[texture] = token
    local checker = issecretvalue
    if type(checker) == "function" then
        local ok, restricted = pcall(checker, showOwned)
        if not ok or restricted ~= false then return false end
    end
    if issecretvalue ~= checker or dungeonArtPaints[texture] ~= token then return false end
    if type(showOwned) ~= "nil" then
        showOwned = addon.Clean(showOwned, "function")
        if not showOwned then return false end
    end
    if issecretvalue ~= checker or dungeonArtPaints[texture] ~= token then return false end
    local overview = addon.Clean(mode, "string") == "overview"
    dungeon = addon.Clean(dungeon, "table") or {}
    local art = addon.Clean(dungeon.art, "table")
    local fileID, mapID = art and artInteger(art.fileID), artInteger(dungeon.instanceID)
    local artMap = art and artInteger(art.gameMapID)
    local previewWidth = art and artInteger(art.previewWidth)
    local previewHeight = art and artInteger(art.previewHeight)
    if previewWidth and previewWidth > 16384 then previewWidth = nil end
    if previewHeight and previewHeight > 16384 then previewHeight = nil end
    local generic = "Interface\\Icons\\INV_Misc_Map_01"
    local image = addon.DungeonArt(dungeon)
    local resolved = artInteger(image) or addon.Clean(image, "string")
    if type(resolved) == "string" and (resolved == "" or #resolved > 1024) then resolved = nil end
    local kind = resolved and (resolved == generic and "generic" or "art")
    local function owned() return dungeonArtPaints[texture] == token end
    local function current()
        local width = art and artInteger(art.previewWidth)
        local height = art and artInteger(art.previewHeight)
        if width and width > 16384 then width = nil end
        if height and height > 16384 then height = nil end
        return owned() and issecretvalue == checker and addon.Clean(dungeon.art, "table") == art and
            artInteger(dungeon.instanceID) == mapID and (not art or
                (artInteger(art.fileID) == fileID and artInteger(art.gameMapID) == artMap and
                    width == previewWidth and height == previewHeight))
    end
    local function abandon()
        if owned() then
            pcall(texture.SetTexture, texture, nil)
            if owned() then pcall(texture.Hide, texture) end
        end
        return false
    end
    if not current() then return abandon() end
    local function paint(value)
        local ok, accepted = pcall(texture.SetTexture, texture, value)
        return ok and addon.Clean(accepted, "boolean") == true
    end
    local accepted = paint(image)
    if not current() then return abandon() end
    if not accepted and image ~= generic then
        accepted = paint(generic)
        image, kind = generic, "generic"
        if not current() then return abandon() end
    end
    if not accepted then
        return abandon()
    end
    local coordinates = addon.Clean(texture.SetTexCoord, "function")
    if coordinates then
        local inset = not overview and type(image) == "number" and 0.18 or 0
        local left, right, top, bottom = inset, 1 - inset, inset, 1 - inset
        if not overview and image == fileID and artMap and (not mapID or mapID == artMap) and previewWidth and previewHeight then
            local widthGetter = addon.Clean(texture.GetWidth, "function")
            local heightGetter = addon.Clean(texture.GetHeight, "function")
            if widthGetter and heightGetter then
                local function geometryCurrent()
                    return current() and addon.Clean(texture.GetWidth, "function") == widthGetter and
                        addon.Clean(texture.GetHeight, "function") == heightGetter
                end
                local width = addon.Read(widthGetter, "number", texture)
                if not geometryCurrent() then return abandon() end
                local height = addon.Read(heightGetter, "number", texture)
                if not geometryCurrent() then return abandon() end
                local ratio = width and height and width > 0 and height > 0 and addon.Clean(width / height, "number")
                if ratio and ratio > 0 then
                    local sourceRatio = previewWidth / previewHeight
                    if sourceRatio > ratio then
                        local span = (1 - 2 * inset) * ratio / sourceRatio
                        local first, last = (1 - span) / 2, (1 + span) / 2
                        if last > first then left, right = first, last end
                    elseif sourceRatio < ratio then
                        local span = (1 - 2 * inset) * sourceRatio / ratio
                        local first, last = (1 - span) / 2, (1 + span) / 2
                        if last > first then top, bottom = first, last end
                    end
                end
            end
        end
        pcall(coordinates, texture, left, right, top, bottom)
        if not current() then return abandon() end
    end
    if showOwned then
        local ok, shown = pcall(showOwned, texture)
        if not ok or addon.Clean(shown, "boolean") ~= true then return false end
    else texture:Show() end
    local success = current()
    local aspect = overview and kind == "art" and image == fileID and artMap and
        (not mapID or mapID == artMap) and previewWidth and previewHeight and previewWidth / previewHeight or nil
    return success, success and kind or nil, success and aspect or nil
end
