-- ═══════════════════════════════════════════════════════════════════════════
--  CLIENT FRAMEWORK BRIDGE  (QBCore / ESX)
--  Functions defined first so they are never nil regardless of detection.
-- ═══════════════════════════════════════════════════════════════════════════

local _QB, _ESX

-- ─── Functions ─────────────────────────────────────────────────────────────

function FW_Notify(msg, notifType, ms)
    if _QB then
        _QB.Functions.Notify(msg, notifType or 'error', ms or 5000)
    elseif _ESX then
        _ESX.ShowNotification(tostring(msg))
    else
        -- Fallback: plain lib notify so the player always sees something
        if lib then lib.notify({ title = 'nl-lockers', description = tostring(msg), type = notifType or 'error' })
        else print('[nl-lockers] Notify (no framework): ' .. tostring(msg)) end
    end
end

function FW_TriggerCallback(name, cb, ...)
    if _QB then
        _QB.Functions.TriggerCallback(name, cb, ...)
    elseif _ESX then
        _ESX.TriggerServerCallback(name, cb, ...)
    else
        print('[nl-lockers] FW_TriggerCallback: no framework for callback "' .. name .. '"')
    end
end

function FW_GetPlayerData()
    if _QB  then return _QB.Functions.GetPlayerData()
    elseif _ESX then return _ESX.GetPlayerData() end
    return {}
end

-- ─── Detection ─────────────────────────────────────────────────────────────

local fw = ((Config and Config.Framework) or 'auto'):lower()

if fw == 'qb' or fw == 'auto' then
    local state = GetResourceState('qb-core')
    if state ~= 'missing' and state ~= 'stopped' then
        local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
        if ok and obj then _QB = obj end
    end
end

if not _QB and (fw == 'esx' or fw == 'auto') then
    local state = GetResourceState('es_extended')
    if state ~= 'missing' and state ~= 'stopped' then
        local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
        if ok and obj then _ESX = obj end
    end
end
