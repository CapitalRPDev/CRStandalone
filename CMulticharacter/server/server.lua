local QBCore = exports['qb-core']:GetCoreObject()
local hasDonePreloading = {}
local MySQL = {
    query = { await = function(q, p) return exports.oxmysql:executeSync(q, p) end },
    single = { await = function(q, p) return exports.oxmysql:singleSync(q, p) end },
}



CreateThread(function()
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `multichar_slots` (
            `license` VARCHAR(60) NOT NULL,
            `slots` INT NOT NULL DEFAULT 3,
            PRIMARY KEY (`license`)
        )
    ]], {})
end)


local function GiveStarterItems(source)
    local Player = QBCore.Functions.GetPlayer(source)

    for _, v in pairs(QBCore.Shared.StarterItems) do
        if v.item == 'id_card' then
            local metadata = {
                type = string.format('%s %s', Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname),
                description = string.format('CID: %s  \nBirth date: %s  \nSex: %s  \nNationality: %s',
                Player.PlayerData.citizenid, Player.PlayerData.charinfo.birthdate, Player.PlayerData.charinfo.gender == 0 and 'Male' or 'Female', Player.PlayerData.charinfo.nationality)
            }
            exports.ox_inventory:AddItem(source, v.item, v.amount, metadata)
        elseif v.item == 'driver_license' then
            local metadata = {
                type = 'Class C Driver License',
                description = string.format('First name: %s  \nLast name: %s  \nBirth date: %s',
                Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname, Player.PlayerData.charinfo.birthdate)
            }
            exports.ox_inventory:AddItem(source, v.item, v.amount, metadata)
        else
            exports.ox_inventory:AddItem(source, v.item, v.amount)
        end
    end
end

lib.addCommand('logout', {
    help = 'Logs you out of your current character',
    restricted = 'admin',
}, function(source)
    QBCore.Player.Logout(source)
    TriggerClientEvent('qb-multicharacter:client:chooseChar', source)
end)

lib.addCommand('deletechar', {
    help = 'Delete a players character',
    restricted = 'admin',
    params = {
        { name = 'id', help = 'Player ID', type = 'number' },
    }
}, function(source, args)
    local Player = QBCore.Functions.GetPlayer(args.id)
    if not Player then return end
    local CID = Player.PlayerData.citizenid
    QBCore.Player.ForceDeleteCharacter(CID)
    TriggerClientEvent("QBCore:Notify", source, 'Character ' .. tostring(CID) .. ' deleted', "success")
end)
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    Wait(1000) -- 1 second should be enough to do the preloading in other resources
    hasDonePreloading[Player.PlayerData.source] = true
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    hasDonePreloading[src] = false
end)

RegisterNetEvent('qb-multicharacter:server:loadUserData', function(cData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        exports['qbx_core']:Logout(src)
        Wait(500)
    end
    if QBCore.Player.Login(src, cData.citizenid) then
        repeat Wait(0) until hasDonePreloading[src]
        print('^2[qbx-core]^7 '..GetPlayerName(src)..' loaded!')
        TriggerClientEvent('CSpawnselector:client:openUI', src)
        SetPlayerRoutingBucket(src, 0)
    end
end)

RegisterNetEvent('qb-multicharacter:server:createCharacter', function(data)
    local src = source
    local newData = {}
    newData.charinfo = data
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        exports['qbx_core']:Logout(src)
        Wait(500)
    end
    if QBCore.Player.Login(src, false, newData) then
        repeat Wait(0) until hasDonePreloading[src]
        GiveStarterItems(src)
        print('^2[qbx-core]^7 '..GetPlayerName(src)..' created a character!')
        TriggerClientEvent('CMulticharacter:client:openAppearance', src, data.gender)
    end
end)



RegisterNetEvent('CMulticharacter:server:saveAppearance', function(appearance)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    exports.oxmysql:executeSync(
        'INSERT INTO playerskins (citizenid, skin, model) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE skin = ?, model = ?',
        {
            Player.PlayerData.citizenid,
            json.encode(appearance),
            appearance.model or 'mp_m_freemode_01',
            json.encode(appearance),
            appearance.model or 'mp_m_freemode_01'
        }
    )
    print('^2[CMulticharacter]^7 Saved appearance for ' .. Player.PlayerData.citizenid)
end)

RegisterNetEvent('qb-multicharacter:server:deleteCharacter', function(citizenid)
    TriggerClientEvent('QBCore:Notify', source, 'Character deleted', "success")
    QBCore.Player.DeleteCharacter(source, citizenid)
end)

lib.callback.register('qb-multicharacter:callback:GetNumberOfCharacters', function(source)
    local license = QBCore.Functions.GetIdentifier(source, 'license')
    local result = exports.oxmysql:singleSync('SELECT slots FROM multichar_slots WHERE license = ?', { license })
    if result then
        return result.slots
    end
    return Config.DefaultNumberOfCharacters
end)


lib.addCommand('setcharslots', {
    help = 'Set character slots for a player',
    restricted = 'admin',
    params = {
        { name = 'id', help = 'Player ID', type = 'number' },
        { name = 'slots', help = 'Number of slots', type = 'number' },
    }
}, function(source, args)
    local target = QBCore.Functions.GetPlayer(args.id)
    if not target then
        TriggerClientEvent('QBCore:Notify', source, 'Player not found', 'error')
        return
    end
    local license = QBCore.Functions.GetIdentifier(args.id, 'license')
    exports.oxmysql:execute(
        'INSERT INTO multichar_slots (license, slots) VALUES (?, ?) ON DUPLICATE KEY UPDATE slots = ?',
        { license, args.slots, args.slots }
    )
    TriggerClientEvent('QBCore:Notify', source, 'Set ' .. GetPlayerName(args.id) .. ' to ' .. args.slots .. ' character slots', 'success')
end)



lib.callback.register('qb-multicharacter:callback:GetCurrentCharacters', function(source)
    local Characters = {}
    local Result = exports.oxmysql:fetchSync('SELECT * FROM players WHERE license = ? OR license = ?', {QBCore.Functions.GetIdentifier(source, 'license2'), QBCore.Functions.GetIdentifier(source, 'license')})
    for i = 1, #Result do
        Result[i].charinfo = json.decode(Result[i].charinfo)
        Result[i].money = json.decode(Result[i].money)
        Result[i].job = json.decode(Result[i].job)
        Characters[#Characters+1] = Result[i]
    end
    return Characters
end)

lib.callback.register('qb-multicharacter:callback:UpdatePreviewPed', function(source, CitizenID)
    local Ped = exports.oxmysql:singleSync('SELECT * FROM playerskins WHERE citizenid = ?', {CitizenID})
    local PlayerData = exports.oxmysql:singleSync('SELECT * FROM players WHERE citizenid = ?', {CitizenID})
    if not Ped or not PlayerData then return end
    local Charinfo = json.decode(PlayerData.charinfo)
    return Ped.skin, joaat(Ped.model), Charinfo.gender
end)

AddEventHandler('playerJoining', function()
    SetPlayerRoutingBucket(source, source)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(100)
    for _, playerId in ipairs(GetPlayers()) do
        playerId = tonumber(playerId)
        if not playerId then return end
        SetPlayerRoutingBucket(tostring(playerId), playerId)
    end
end)
