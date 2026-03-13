--- Clamp a number between min and max
function math.clamp(val, minVal, maxVal)
    return math.max(minVal, math.min(maxVal, val))
end

--- Yield until an animation dictionary is loaded
function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    local t = 5000
    while not HasAnimDictLoaded(dict) and t > 0 do t = t - 100; Wait(100) end
end

--- Yield until a model is loaded
function LoadModel(hash)
    if HasModelLoaded(hash) then return end
    RequestModel(hash)
    local t = 5000
    while not HasModelLoaded(hash) and t > 0 do t = t - 100; Wait(100) end
end

--- Debug print
function DebugPrint(msg)
    if Config.Debug then
        print('^3[nl-lockers] ' .. tostring(msg) .. '^7')
    end
end

--- Table length for non-sequential tables
function TableLength(t)
    local c = 0
    for _ in pairs(t) do c = c + 1 end
    return c
end

-- ═══════════════════════════════════════════════════════════════════════════
--  LOCALIZATION
-- ═══════════════════════════════════════════════════════════════════════════

local Locales = {}

--- Load locale file
CreateThread(function()
    local locale = GetConvar('nl_lockers:locale', 'en')
    local path = ('locales/%s.json'):format(locale)
    local data = LoadResourceFile(GetCurrentResourceName(), path)
    if data then
        Locales = json.decode(data) or {}
        DebugPrint('Loaded locale: ' .. locale)
    else
        print('^1[nl-lockers] Failed to load locale: ' .. locale .. '^7')
    end
end)

--- Get localized string with optional formatting
---@param key string
---@param ... any Format arguments
---@return string
function L(key, ...)
    local str = Locales[key] or key
    if ... then
        return string.format(str, ...)
    end
    return str
end

-- ═══════════════════════════════════════════════════════════════════════════
--  INPUT VALIDATION
-- ═══════════════════════════════════════════════════════════════════════════

--- Validate and sanitize locker label
---@param label string
---@return boolean valid
---@return string|nil sanitized
---@return string|nil error
function ValidateLabel(label)
    if not label or type(label) ~= 'string' then
        return false, nil, L('invalid_label', Config.MaxLabelLength)
    end
    
    local sanitized = label:gsub('[<>]', ''):sub(1, Config.MaxLabelLength)
    if #sanitized == 0 then
        return false, nil, L('invalid_label', Config.MaxLabelLength)
    end
    
    return true, sanitized, nil
end

--- Validate locker price
---@param price number
---@return boolean valid
---@return string|nil error
function ValidatePrice(price)
    local num = tonumber(price)
    if not num or num < Config.MinPrice or num > Config.MaxPrice then
        return false, L('invalid_price', Config.MinPrice, Config.MaxPrice)
    end
    return true, nil
end

--- Validate access code
---@param code string
---@return boolean valid
---@return string|nil sanitized
function ValidateCode(code)
    if not code or code == '' then
        return true, nil  -- Empty code is valid (no code)
    end
    
    if type(code) ~= 'string' then
        return false, nil
    end
    
    local sanitized = tostring(code):sub(1, Config.MaxCodeLength)
    return true, sanitized
end

--- Validate citizen ID format
---@param cid string
---@return boolean valid
function ValidateCitizenId(cid)
    if not cid or type(cid) ~= 'string' then
        return false
    end
    -- Basic validation: alphanumeric, 3-50 chars
    return #cid >= 3 and #cid <= 50 and cid:match('^[%w]+$') ~= nil
end

