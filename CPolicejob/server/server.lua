local QBCore = exports['qb-core']:GetCoreObject()
local cuffedPlayers = {}



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

    if not targetServerId then return end
    if src == targetServerId then return end

    local srcPlayer = QBCore.Functions.GetPlayer(src)
    if not srcPlayer then return end
    if srcPlayer.PlayerData.job.name ~= Config.Police.job then return end
    if Config.Police.requireDuty and not srcPlayer.PlayerData.job.onduty then return end

    local targetPlayer = QBCore.Functions.GetPlayer(targetServerId)
    if not targetPlayer then return end

    if cuffedPlayers[targetServerId] then
        TriggerClientEvent("CPoliceJob:Client:Notify", src, "This player is already cuffed", 4000)
        return
    end

    cuffedPlayers[targetServerId] = { cuffedBy = src, frontCuffed = frontCuffed }
    local targetPlayer = QBCore.Functions.GetPlayer(targetServerId)
    targetPlayer.Functions.SetMetaData("ishandcuffed", true)
    targetPlayer.Functions.SetMetaData("isfrontcuffed", frontCuffed)


    TriggerClientEvent("CPoliceJob:Client:PlayCuffAnim", src, targetServerId, frontCuffed)
    TriggerClientEvent("CPoliceJob:Client:PlayCuffedAnim", targetServerId, frontCuffed)
    TriggerClientEvent("CPoliceJob:Client:SetCuffed", targetServerId, true, src)
end)

RegisterNetEvent("CPoliceJob:Server:RequestFrontCuff", function(targetServerId)
    local src = source
    targetServerId = tonumber(targetServerId)

    if not targetServerId then return end
    if src == targetServerId then return end

    local srcPlayer = QBCore.Functions.GetPlayer(src)
    if not srcPlayer then return end
    if srcPlayer.PlayerData.job.name ~= Config.Police.job then return end
    if Config.Police.requireDuty and not srcPlayer.PlayerData.job.onduty then return end

    local targetPlayer = QBCore.Functions.GetPlayer(targetServerId)
    if not targetPlayer then return end

    if cuffedPlayers[targetServerId] then
        TriggerClientEvent("CPoliceJob:Client:Notify", src, "This player is already cuffed", 4000)
        return
    end

    cuffedPlayers[targetServerId] = { cuffedBy = src, frontCuffed = true }
    local targetPlayer = QBCore.Functions.GetPlayer(targetServerId)
    targetPlayer.Functions.SetMetaData("ishandcuffed", true)
    targetPlayer.Functions.SetMetaData("isfrontcuffed", true)

    TriggerClientEvent("CPoliceJob:Client:PlayCuffAnim", src, targetServerId, true)
    TriggerClientEvent("CPoliceJob:Client:PlayCuffedAnim", targetServerId, true)
    TriggerClientEvent("CPoliceJob:Client:SetCuffed", targetServerId, true, src)
end)

RegisterNetEvent("CPoliceJob:Server:RequestUncuff", function(targetServerId)
    local src = source
    targetServerId = tonumber(targetServerId)

    if not targetServerId then return end
    if src == targetServerId then return end

    local srcPlayer = QBCore.Functions.GetPlayer(src)
    if not srcPlayer then return end
    if srcPlayer.PlayerData.job.name ~= Config.Police.job then return end
    if Config.Police.requireDuty and not srcPlayer.PlayerData.job.onduty then return end

    local targetPlayer = QBCore.Functions.GetPlayer(targetServerId)
    if not targetPlayer then return end

    if not cuffedPlayers[targetServerId] then
        TriggerClientEvent("CPoliceJob:Client:Notify", src, "This player is not cuffed", 4000)
        return
    end

    local frontCuffed = cuffedPlayers[targetServerId].frontCuffed
    cuffedPlayers[targetServerId] = nil
    local targetPlayer = QBCore.Functions.GetPlayer(targetServerId)
    targetPlayer.Functions.SetMetaData("ishandcuffed", false)
    targetPlayer.Functions.SetMetaData("isfrontcuffed", false)

    TriggerClientEvent("CPoliceJob:Client:PlayUncuffAnim", src, targetServerId, frontCuffed)
    TriggerClientEvent("CPoliceJob:Client:PlayUncuffedAnim", targetServerId)
    TriggerClientEvent("CPoliceJob:Client:SetCuffed", targetServerId, false, src)
end)

-- Clean up if player disconnects while cuffed
AddEventHandler("playerDropped", function()
    local src = source
    cuffedPlayers[src] = nil
end)