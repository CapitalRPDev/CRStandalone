-- ═══════════════════════════════════════════════════════════════════════════
--  SERVER FRAMEWORK BRIDGE  (QBCore / ESX)
--  All FW_* functions are defined unconditionally so they're never nil.
--  Detection runs last and sets _QB / _ESX, which the functions close over.
-- ═══════════════════════════════════════════════════════════════════════════

local _QB, _ESX  -- set by detection below; functions read them at call-time

-- ─── Functions (always defined regardless of detection result) ──────────────

function FW_GetPlayer(src)
    if _QB  then return _QB.Functions.GetPlayer(src)
    elseif _ESX then return _ESX.GetPlayerFromId(src) end
end

function FW_GetIdentifier(player)
    if _QB  then return player and player.PlayerData.citizenid
    elseif _ESX then return player and player.getIdentifier() end
end

function FW_GetMoney(player, moneyType)
    if _QB then
        return player.PlayerData.money[moneyType] or 0
    elseif _ESX then
        local acc = player.getAccount(moneyType == 'bank' and 'bank' or 'money')
        return acc and acc.money or 0
    end
    return 0
end

function FW_RemoveMoney(player, moneyType, amount, reason)
    if _QB then
        player.Functions.RemoveMoney(moneyType, amount, reason or 'nl-lockers')
    elseif _ESX then
        player.removeAccountMoney(moneyType == 'bank' and 'bank' or 'money', amount)
    end
end

function FW_Notify(src, msg, notifType, ms)
    if _QB then
        TriggerClientEvent('QBCore:Notify', src, msg, notifType or 'error', ms or 5000)
    elseif _ESX then
        TriggerClientEvent('esx:showNotification', src,
            '[' .. (notifType or 'error') .. '] ' .. tostring(msg))
    end
end

function FW_CreateCallback(name, cb)
    if _QB  then _QB.Functions.CreateCallback(name, cb)
    elseif _ESX then _ESX.RegisterServerCallback(name, cb)
    else print('^1[nl-lockers] FW_CreateCallback: no framework loaded for callback "' .. name .. '"^7') end
end

function FW_SavePosition(src, coords)
    local player = FW_GetPlayer(src)
    if not player then return end
    local posJson = json.encode({ x = coords.x, y = coords.y, z = coords.z, w = 0.0 })
    if _QB then
        MySQL.query('UPDATE players SET position = ? WHERE citizenid = ?',
            { posJson, FW_GetIdentifier(player) })
    elseif _ESX then
        MySQL.query('UPDATE users SET coords = ? WHERE identifier = ?',
            { posJson, FW_GetIdentifier(player) })
    end
end

-- ─── Detection (runs after functions are defined) ───────────────────────────

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

if _QB then
    print('^2[nl-lockers] Framework: QBCore^7')
elseif _ESX then
    print('^2[nl-lockers] Framework: ESX^7')
else
    print('^1[nl-lockers] WARNING: Framework not detected. Set Config.Framework = "qb" or "esx".^7')
end
