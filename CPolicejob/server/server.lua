local QBCore = exports['qb-core']:GetCoreObject()
local cuffedPlayers = {}
local draggingPlayers = {}

local webhook = "https://discord.com/api/webhooks/1481972728876761222/fEzgz-3G24pP_7ufjJW5CUwgCPC8Wgep7lQ-BihjgqrpdLDZ6uk7DVBvrY7727WPAe-w"

function LogToDiscord(color, title, description)
    local embed = {
        {
            ["color"] = color,
            ["title"] = title,
            ["description"] = description,
            ["footer"] = {
                ["text"] = "CapitalRP | Logs - " .. os.date("%x %X %p")
            }
        }
    }
    PerformHttpRequest(webhook, function(err, text, headers) end, "POST", json.encode({username = "CapitalRP", embeds = embed}), {["Content-Type"] = "application/json"})
end

local function getPlayerName(src)
    return GetPlayerName(src) or "Unknown"
end

RegisterNetEvent("CPolice:Server:ToggleDuty", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.onduty then 
        Player.Functions.SetJobDuty(false)
        TriggerClientEvent('QBCore:Notify', src, "You are now off duty", "info")
        LogToDiscord(15158332, "🔴 Officer Off Duty", "**Officer:** " .. getPlayerName(src) .. " `[" .. src .. "]`")
    else 
        Player.Functions.SetJobDuty(true)
        TriggerClientEvent('QBCore:Notify', src, "You are now on duty. Welcome!", "info")
        LogToDiscord(3066993, "🟢 Officer On Duty", "**Officer:** " .. getPlayerName(src) .. " `[" .. src .. "]`")
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

    local cuffType = frontCuffed and "Front Cuffed" or "Back Cuffed"
    LogToDiscord(3447003, "🔒 Player Cuffed", "**Officer:** " .. getPlayerName(src) .. " `[" .. src .. "]`\n**Suspect:** " .. getPlayerName(targetServerId) .. " `[" .. targetServerId .. "]`\n**Type:** " .. cuffType)

    TriggerClientEvent("CPoliceJob:Client:PlayCuffAnim", src, targetServerId, frontCuffed)
    TriggerClientEvent("CPoliceJob:Client:PlayCuffedAnim", targetServerId, frontCuffed)
    TriggerClientEvent("CPoliceJob:Client:SetCuffed", targetServerId, true, src)
end)

RegisterNetEvent("CPoliceJob:Server:RequestUncuff", function(targetServerId)
    local src = source
    targetServerId = tonumber(targetServerId)

    if not targetServerId then return end
    if src == targetServerId then return end

        if not cuffedPlayers[targetServerId] then
        TriggerClientEvent("CPoliceJob:Client:Notify", src, "This person is not cuffed", 4000)
        return
    end

    if draggingPlayers[src] == targetServerId then
        TriggerClientEvent("CPoliceJob:Client:Notify", src, "Stop dragging first", 4000)
        return
    end

    for draggerId, draggedId in pairs(draggingPlayers) do
        if draggedId == targetServerId then
            TriggerClientEvent("CPoliceJob:Client:Notify", src, "This person is being dragged", 4000)
            return
        end
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

    LogToDiscord(15105570, "🔓 Player Uncuffed", "**Officer:** " .. getPlayerName(src) .. " `[" .. src .. "]`\n**Suspect:** " .. getPlayerName(targetServerId) .. " `[" .. targetServerId .. "]`")

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
        LogToDiscord(16776960, "🚶 Player Undragged", "**Officer:** " .. getPlayerName(sourcePlayerId) .. " `[" .. sourcePlayerId .. "]`\n**Suspect:** " .. getPlayerName(targetServerId) .. " `[" .. targetServerId .. "]`")
    else
        TriggerClientEvent("CPoliceJob:Client:Drag", targetServerId, sourcePlayerId)
        draggingPlayers[sourcePlayerId] = targetServerId
        LogToDiscord(10181046, "🫳 Player Dragged", "**Officer:** " .. getPlayerName(sourcePlayerId) .. " `[" .. sourcePlayerId .. "]`\n**Suspect:** " .. getPlayerName(targetServerId) .. " `[" .. targetServerId .. "]`")
    end
end)

RegisterNetEvent("CPoliceJob:Server:PutInVehicle", function(targetServerId, vehicleNetId)
    local src = source

    if draggingPlayers[src] and draggingPlayers[src] == targetServerId then
        TriggerClientEvent("CPoliceJob:Client:Undrag", targetServerId)
        draggingPlayers[src] = nil
    end

    LogToDiscord(1752220, "🚔 Player Put In Vehicle", "**Officer:** " .. getPlayerName(src) .. " `[" .. src .. "]`\n**Suspect:** " .. getPlayerName(targetServerId) .. " `[" .. targetServerId .. "]`")

    TriggerClientEvent("CPoliceJob:Client:PutInVehicle", targetServerId, vehicleNetId)
end)

RegisterNetEvent("CPoliceJob:Server:TakeOutOfVehicle", function(targetServerId)
    local src = source
    LogToDiscord(16744272, "🚗 Player Taken Out Of Vehicle", "**Officer:** " .. getPlayerName(src) .. " `[" .. src .. "]`\n**Suspect:** " .. getPlayerName(targetServerId) .. " `[" .. targetServerId .. "]`")
    TriggerClientEvent("CPoliceJob:Client:TakeOutOfVehicle", targetServerId)
end)


RegisterNetEvent("CPoliceJob:Server:EscapeCuffs", function()
    local src = source

    local data = cuffedPlayers[src]
    if not data then return end

    local officerId = data.cuffedBy
    local frontCuffed = data.frontCuffed or false
    cuffedPlayers[src] = nil

    LogToDiscord(15105570, "🔓 Player Escaped Cuffs", "**Suspect:** " .. getPlayerName(src) .. " `[" .. src .. "]` escaped from cuffs")

    TriggerClientEvent("CPoliceJob:Client:EscapedCuffs", src)
    TriggerClientEvent("CPoliceJob:Client:SuspectEscaped", officerId, src)
end)




RegisterServerEvent('CPoliceJob:Server:tryTackle')
AddEventHandler('CPoliceJob:Server:tryTackle', function(id)
    local source = source
    local user_id = QBCore.Functions.GetPlayer(source)
    TriggerClientEvent('CPoliceJob:Server:playTackle', source)
    TriggerClientEvent('CPoliceJob:Server:getTackled', id, source)
end)

AddEventHandler('playerDropped', function()
    local src = source
    cuffedPlayers[src] = nil
    if draggingPlayers[src] then
        TriggerClientEvent("CPoliceJob:Client:Undrag", draggingPlayers[src])
        draggingPlayers[src] = nil
    end
end)

exports.ox_inventory:registerHook('swapItems', function(payload)
    if not payload.fromSlot then return end
    for i, stash in pairs(Config.Police.evidenceStash) do
        local stashId = 'evidence_stash_' .. i
        if payload.toInventory == stashId or payload.fromInventory == stashId then
            local action = payload.toInventory == stashId and 'Added' or 'Removed'
            local playerName = GetPlayerName(payload.source)
            LogToDiscord(3447003, "🔍 Evidence Stash Activity",
                "**Officer:** " .. playerName .. " `[" .. payload.source .. "]`\n" ..
                "**Action:** " .. action .. "\n" ..
                "**Item:** " .. payload.count .. "x " .. payload.fromSlot.label .. "\n" ..
                "**Stash:** " .. stash.label
            )
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for i, stash in pairs(Config.Police.evidenceStash) do
        exports.ox_inventory:RegisterStash('evidence_stash_' .. i, stash.label, 50, 100000)
    end
end)