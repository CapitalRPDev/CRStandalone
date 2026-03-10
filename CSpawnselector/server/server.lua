local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('QBCore:Server:PlayerLoaded', function(player)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        if Player.PlayerData.metadata["firstspawn"] == nil then
        end
    end
end)

RegisterNetEvent('CSpawnselector:server:setFirstSpawn', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        Player.Functions.SetMetaData("firstspawn", true)
    end
end)

function LogToDiscord(color, title, description, webhook)
    local embed = {
        {
            ["color"] = color,
            ["title"] = title,
            ["description"] = description,
            ["footer"] = {
                ["text"] = "TLD | Spawn Selector - " .. os.date("%x %X %p")
            }
        }
    }
    PerformHttpRequest(webhook, function(err, text, headers) end, "POST", json.encode({username = "TLD Spawn Selector", embeds = embed}), {["Content-Type"] = "application/json"} )
end
local webhook = "https://discord.com/api/webhooks/1418611705931501754/gkXGAI0wOA1mtSQ9EiZ-yj-xlqgmulaJbOjBGSAfEz6QdGJ0YwxwmfM85D8V63lBVyf5"

RegisterNetEvent('CSpawnselector:server:logSpawn', function(locationData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        local playerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
        local playerId = src
        local citizenId = Player.PlayerData.citizenid
        local locationName = locationData.label or "Unknown Location"
        local locationKey = locationData.key or "unknown"
        
        local description = string.format(
            "**Player:** %s\n**ID:** %s\n**Citizen ID:** %s\n**Location:** %s\n**Location Key:** %s",
            playerName,
            playerId,
            citizenId,
            locationName,
            locationKey
        )
        
        LogToDiscord(65280, "Player Spawn", description, webhook)
    end
end)