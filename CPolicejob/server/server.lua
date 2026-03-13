local QBCore = exports['qb-core']:GetCoreObject()
local cuffedPlayers = {}
local draggingPlayers = {}

RegisterNetEvent("CPolice:Server:ToggleDuty", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.onduty then 
        Player.Functions.SetJobDuty(false)
        TriggerClientEvent('QBCore:Notify', src, "You are now off duty", "info")
    else 
        Player.Functions.SetJobDuty(true)
        TriggerClientEvent('QBCore:Notify', src, "You are now on duty. Welcome!", "info")
    end
end)

RegisterNetEvent("CPoliceJob:Server:RequestCuff", function(targetServerId, frontCuffed)
    local src = source
    targetServerId = tonumber(targetServerId)
    frontCuffed = frontCuffed or false

    if not targetServerId then return end
    if src == targetServerId then return end

    local srcPlayer = QBCore.Functions.GetPlayer(src)
    if not srcPlayer then return end
    if srcPlayer.PlayerData.job.name ~= Config.Police.job then return end
    if Config.Police.requireDuty and not srcPlayer.PlayerData.job.onduty then return end

    local targetPlayer = QBCore.Functions.GetPlayer(targetServerId)
    if not targetPlayer then return end

    if cuffedPlayers[targetServerId] then
        TriggerClientEvent("CPoliceJob:Client:Notify", src, "This person is already cuffed", 4000)
        return
    end

    cuffedPlayers[targetServerId] = { cuffedBy = src, frontCuffed = frontCuffed }

    TriggerClientEvent("CPoliceJob:Client:PlayCuffAnim", src, targetServerId, frontCuffed)
    TriggerClientEvent("CPoliceJob:Client:PlayCuffedAnim", targetServerId, frontCuffed)
    TriggerClientEvent("CPoliceJob:Client:SetCuffed", targetServerId, true, src)
end)

RegisterNetEvent("CPoliceJob:Server:RequestUncuff", function(targetServerId)
    local src = source
    targetServerId = tonumber(targetServerId)

    if not targetServerId then return end
    if src == targetServerId then return end

    if draggingPlayers[src] == targetServerId then
        TriggerClientEvent("CPoliceJob:Client:Notify", src, "Stop dragging first", 4000)
        return
    end


    local srcPlayer = QBCore.Functions.GetPlayer(src)
    if not srcPlayer then return end
    if srcPlayer.PlayerData.job.name ~= Config.Police.job then return end
    if Config.Police.requireDuty and not srcPlayer.PlayerData.job.onduty then return end

    local targetPlayer = QBCore.Functions.GetPlayer(targetServerId)
    if not targetPlayer then return end

    local data = cuffedPlayers[targetServerId]
    local frontCuffed = data and data.frontCuffed or false
    cuffedPlayers[targetServerId] = nil

    TriggerClientEvent("CPoliceJob:Client:PlayUncuffAnim", src, targetServerId, frontCuffed)
    TriggerClientEvent("CPoliceJob:Client:PlayUncuffedAnim", targetServerId)
    TriggerClientEvent("CPoliceJob:Client:SetCuffed", targetServerId, false, src)
end)

RegisterNetEvent("CPoliceJob:Server:RequestDrag", function(targetServerId)
    local src = source
    targetServerId = tonumber(targetServerId)

    if not targetServerId then return end
    if src == targetServerId then return end

    local srcPlayer = QBCore.Functions.GetPlayer(src)
    if not srcPlayer then return end
    if srcPlayer.PlayerData.job.name ~= Config.Police.job then return end
    if Config.Police.requireDuty and not srcPlayer.PlayerData.job.onduty then return end

    TriggerClientEvent("CPoliceJob:Client:CheckCuffStatus", targetServerId, src)
end)

RegisterNetEvent("CPoliceJob:Server:HandleDragRequest", function(isHandcuffed, sourcePlayerId)
    local targetServerId = source

    if not isHandcuffed then
        TriggerClientEvent("CPoliceJob:Client:Notify", sourcePlayerId, "This person is not cuffed", 4000)
        return
    end

    if draggingPlayers[sourcePlayerId] then
        TriggerClientEvent("CPoliceJob:Client:Undrag", targetServerId)
        draggingPlayers[sourcePlayerId] = nil
    else
        TriggerClientEvent("CPoliceJob:Client:Drag", targetServerId, sourcePlayerId)
        draggingPlayers[sourcePlayerId] = targetServerId
    end
end)

RegisterNetEvent("CPoliceJob:Server:PutInVehicle", function(targetServerId, vehicleNetId)
    local src = source

    if draggingPlayers[src] and draggingPlayers[src] == targetServerId then
        TriggerClientEvent("CPoliceJob:Client:Undrag", targetServerId)
        draggingPlayers[src] = nil
    end

    TriggerClientEvent("CPoliceJob:Client:PutInVehicle", targetServerId, vehicleNetId)
end)

RegisterNetEvent("CPoliceJob:Server:TakeOutOfVehicle", function(targetServerId)
    TriggerClientEvent("CPoliceJob:Client:TakeOutOfVehicle", targetServerId)
end)

AddEventHandler('playerDropped', function()
    local src = source
    cuffedPlayers[src] = nil
    if draggingPlayers[src] then
        TriggerClientEvent("CPoliceJob:Client:Undrag", draggingPlayers[src])
        draggingPlayers[src] = nil
    end
end)