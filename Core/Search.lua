local _, addon = ...
local fold = addon.searchCaseFold

-- Only search keys are folded. Display strings and their UTF-8 byte sequences stay intact.
function addon.SearchFold(value)
    value = addon.Clean(value, "string")
    if not value or #value > 16384 then return nil end
    local result, i, bytes = {}, 1, 0
    while i <= #value do
        local start, byte = i, value:byte(i)
        local size = byte < 128 and 1 or byte >= 194 and byte <= 223 and 2 or
            byte >= 224 and byte <= 239 and 3 or byte >= 240 and byte <= 244 and 4
        if not size or i + size - 1 > #value then return nil end
        local point = byte % (size == 1 and 128 or 2 ^ (7 - size))
        for offset = 1, size - 1 do
            local nextByte = value:byte(i + offset)
            if nextByte < 128 or nextByte > 191 then return nil end
            if offset == 1 and ((byte == 224 and nextByte < 160) or (byte == 237 and nextByte > 159) or
                (byte == 240 and nextByte < 144) or (byte == 244 and nextByte > 143)) then return nil end
            point = point * 64 + nextByte - 128
        end
        i = i + size
        local folded = fold[point] or value:sub(start, i - 1)
        bytes = bytes + #folded
        if bytes > 16384 then return nil end
        result[#result + 1] = folded
    end
    return table.concat(result)
end
