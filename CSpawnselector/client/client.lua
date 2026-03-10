local function toggleNuiFrame(shouldShow)
  SendReactMessage('setVisible', shouldShow)
end

RegisterCommand('show-nui', function()
  toggleNuiFrame(true)
  debugPrint('Show NUI frame')
end)

RegisterNUICallback('hideFrame', function(_, cb)
  toggleNuiFrame(false)
  debugPrint('Hide NUI frame')
  cb({})
end)

local QBCore = exports['qb-core']:GetCoreObject()
local inSpawnSelection = false
local firstTime = false
local hasSpawned = false


RegisterCommand("testspawn", function()
    TriggerEvent('CSpawnselector:client:openUI')
end, false)

--[[ AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    local PData = QBCore.Functions.GetPlayerData()

    if PData.metadata["firstspawn"] == nil then
        firstTime = true
    else
        firstTime = false
    end

    if not hasSpawned then
        hasSpawned = true
        TriggerEvent('CSpawnselector:client:openUI')
    end
end) ]]

AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    hasSpawned = false
end)


    RegisterNUICallback('lastLocation', function(data, cb)
        local PlayerData = QBCore.Functions.GetPlayerData()
        local lastPos = PlayerData.position

        if not lastPos then
            SendReactMessage('notify', {
                id = tostring(GetGameTimer()),
                text = "No last location found",
                icon = "fa-location-dot",
                iconColor = "#ff1744",
                duration = 4000
            })
            cb({ success = false })
            return
        end

        if cam then
            RenderScriptCams(false, true, 1000, true, true)
            DestroyCam(cam, true)
            cam = nil
        end

        toggleNuiFrame(false)
        SetNuiFocus(false, false)
        inSpawnSelection = false
        DisplayRadar(true)
        DisplayHud(true)

        SetEntityCoords(PlayerPedId(), lastPos.x, lastPos.y, lastPos.z, false, false, false, true)
        SetEntityHeading(PlayerPedId(), lastPos.a or 0.0)

        TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
        TriggerEvent('QBCore:Client:OnPlayerLoaded')

        SetEntityVisible(PlayerPedId(), true)
        DoScreenFadeIn(1000)
        TriggerEvent("CSpawnselector:Client:PlayerSpawned")

        cb({ success = true })
    end)
        
       
       
RegisterNetEvent('CSpawnselector:client:openUI', function()
    debug("Received open UI trigger")
    
    if Config.ForceLastLocation then
        QBCore.Functions.GetPlayerData(function(PlayerData)
            local lastPos = PlayerData.position
            
            if not lastPos or (lastPos.x == 0 and lastPos.y == 0 and lastPos.z == 0) then
                debug("New player detected, using default spawn")
                DoScreenFadeOut(250)
                while not IsScreenFadedOut() do Wait(0) end
                
                SetEntityCoords(PlayerPedId(), Config.DefaultSpawn.x, Config.DefaultSpawn.y, Config.DefaultSpawn.z, false, false, false, true)
                SetEntityHeading(PlayerPedId(), Config.DefaultSpawn.w or 0.0)
                SetEntityVisible(PlayerPedId(), true)
                
                TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
                TriggerEvent('QBCore:Client:OnPlayerLoaded')
                
                DoScreenFadeIn(1000)
                TriggerEvent("CSpawnselector:Client:PlayerSpawned")
                return
            end
            
            DoScreenFadeOut(250)
            while not IsScreenFadedOut() do Wait(0) end
            
            SetEntityCoords(PlayerPedId(), lastPos.x, lastPos.y, lastPos.z, false, false, false, true)
            SetEntityHeading(PlayerPedId(), lastPos.a or 0.0)
            SetEntityVisible(PlayerPedId(), true)
            
            TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
            TriggerEvent('QBCore:Client:OnPlayerLoaded')
            
            DoScreenFadeIn(1000)
            TriggerEvent("CSpawnselector:Client:PlayerSpawned")
        end)
        return
    end
    
    setCamera()
    DisplayRadar(false)
    DisplayHud(false)
    inSpawnSelection = true
end)


        function setCamera()
            QBCore.Functions.GetPlayerData(function(PlayerData)
                local lastPos = PlayerData.position
                debug("set camera")
                local coords = Config.CamCoords
                SetEntityVisible(PlayerPedId(), false)
                DoScreenFadeOut(250)
                Wait(1000)
                DoScreenFadeIn(250)
                cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", coords.x, coords.y, coords.z, -85.00, 0.00, 0.00, 100.00, false, 0)
                SetCamActive(cam, true)
                RenderScriptCams(true, false, 1, true, true)
                Wait(500)

                SetNuiFocus(true, true)
                toggleNuiFrame(true)
                SendReactMessage('setupSpawns', {
                    spawns = (function()
                        local result = {}
                        for i, loc in ipairs(Config.Locations) do
                            result[#result+1] = {
                                label = loc.label,
                                index = i,
                                jobLock = loc.jobLock,
                                coords = loc.coords
                            }
                        end
                        return result
                    end)(),
                    playerJob = PlayerData.job.name,
                    lastPos = lastPos,
                    newPlayer = firstTime
                })
            end)
        end


RegisterNUICallback('moveCamera', function(data, cb)
    debug("Moving camera to location: " .. (data.locationKey or "unknown"))
    
    local coords = data.coords
    if coords then
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, true)
        local camX = coords.x - 10.0
        local camY = coords.y - 10.0  
        local camZ = coords.z + 15.0
        
        if cam then
            local currentCoords = GetCamCoord(cam)
            local targetCoords = vector3(camX, camY, camZ)
            local distance = #(targetCoords - currentCoords)
            
            local safeHeight = math.max(currentCoords.z, camZ) + (distance > 100 and 300.0 or 200.0)
            
            local duration = math.max(1500, math.min(3500, distance * 2))
            
            local startCoords = currentCoords
            local endCoords = targetCoords
            
            Citizen.CreateThread(function()
                local startTime = GetGameTimer()
                
                while GetGameTimer() - startTime < duration do
                    local progress = (GetGameTimer() - startTime) / duration
                    
                    local currentX, currentY, currentZ
                    
                    if progress < 0.15 then
                        local phaseProgress = progress / 0.15
                        local easedUp = 1 - math.pow(1 - phaseProgress, 2)
                        currentX = startCoords.x
                        currentY = startCoords.y
                        currentZ = startCoords.z + (safeHeight - startCoords.z) * easedUp
                        
                    elseif progress < 0.75 then
                        local phaseProgress = (progress - 0.15) / 0.6
                        local easedAcross = phaseProgress < 0.5 and 2 * phaseProgress * phaseProgress or 1 - math.pow(-2 * phaseProgress + 2, 3) / 2
                        currentX = startCoords.x + (endCoords.x - startCoords.x) * easedAcross
                        currentY = startCoords.y + (endCoords.y - startCoords.y) * easedAcross
                        currentZ = safeHeight
                        
                    else
                        local phaseProgress = (progress - 0.75) / 0.25
                        local easedDown = phaseProgress < 0.5 and 2 * phaseProgress * phaseProgress or 1 - math.pow(-2 * phaseProgress + 2, 3) / 2
                        currentX = endCoords.x
                        currentY = endCoords.y
                        currentZ = safeHeight + (endCoords.z - safeHeight) * easedDown
                    end
                    
                    SetCamCoord(cam, currentX, currentY, currentZ)
                    PointCamAtCoord(cam, coords.x, coords.y, coords.z)
                    
                    Wait(0)
                end
                
                SetCamCoord(cam, camX, camY, camZ)
                PointCamAtCoord(cam, coords.x, coords.y, coords.z)
            end)
            
        else
            cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camX, camY, camZ, -45.00, 0.00, coords.w or 0.00, 100.00, false, 0)
            PointCamAtCoord(cam, coords.x, coords.y, coords.z)
            SetCamActive(cam, true)
            RenderScriptCams(true, true, 1000, true, true)
        end
    end
    
    cb('ok')
end)

Citizen.CreateThread(function()
    while inSpawnSelection do 
        DisplayRadar(false)
        
        for i = 1, 22 do
            HideHudComponentThisFrame(i)
        end
        
        Wait(0)
    end
end)



RegisterNUICallback('selectSpawn', function(data, cb)
    local locationIndex = data.index
    local location = Config.Locations[locationIndex]

    if not location then
        cb({ success = false })
        return
    end

    local coords = location.coords
    local PlayerData = QBCore.Functions.GetPlayerData()
    local insideMeta = PlayerData.metadata["inside"]

    if location.jobLock and location.jobLock ~= false then
        debug("Checking job requirement: " .. location.jobLock)
        if PlayerData.job.name ~= location.jobLock or not PlayerData.job.onduty then
            SendReactMessage('notify', {
                id = tostring(GetGameTimer()),
                text = "This location is job locked",
                icon = "fa-lock",
                iconColor = "#ff1744",
                duration = 4000
            })
            cb({ success = false })
            return
        end
    end

    debug("Spawning player at: " .. location.label)

    TriggerServerEvent('CSpawnselector:server:logSpawn', {
        label = location.label,
        key = tostring(locationIndex),
        coords = coords
    })

    if cam then
        RenderScriptCams(false, true, 1000, true, true)
        DestroyCam(cam, true)
        cam = nil
    end

    toggleNuiFrame(false)
    SetNuiFocus(false, false)
    inSpawnSelection = false
    DisplayRadar(true)
    DisplayHud(true)

    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(PlayerPedId(), coords.w or 0.0)

    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')

    SetEntityVisible(PlayerPedId(), true)
    DoScreenFadeIn(1000)
    TriggerEvent("CSpawnselector:Client:PlayerSpawned")

    cb({ success = true })
end)



RegisterNUICallback('closeUI', function(data, cb)
    debug("Closing spawn UI")
    
    if cam then
        RenderScriptCams(false, true, 1000, true, true)
        DestroyCam(cam, true)
        cam = nil
    end
    
    SetNuiFocus(false, false)
    inSpawnSelection = false
    DisplayRadar(true)
    DisplayHud(true)
    
    SetEntityVisible(PlayerPedId(), true)
    DoScreenFadeIn(1000)
    
    cb('ok')
end)

RegisterNUICallback('showNotification', function(data, cb)
    QBCore.Functions.Notify(data.message, data.type or "error")
    cb('ok')
end)


        function closeUI()
            SendNUIMessage({
                type = "closeUI"
            })

        end

function debug(message)
    if Config.Debug then
    print("^1[CSpawnselectorSelector]- ^3" .. message)
    end
end


RegisterNetEvent("CSpawnselector:Client:PlayerSpawned", function()
    hasSpawned = false
    
    if firstTime then
        local Player = QBCore.Functions.GetPlayerData()
        if Player then
            TriggerServerEvent('CSpawnselector:server:setFirstSpawn')
            firstTime = false 
        end
    end
end)



function jobCheck(job)
    local PData = QBCore.Functions.GetPlayerData()

    if PData then
        if PData.job.name == job and PData.job.onduty then 
            return true 
        else
            QBCore.Functions.Notify("This location is job locked", "info")
            return false
        end
    else 
        debug("Error getting player data")
    end


end