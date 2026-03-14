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

RegisterCommand("testhud", function()
  toggleNuiFrame(true)
end)

local Framework = Config.Framework.framework
local Inventory = Config.Framework.inventory
local Notify = Config.Framework.notify
local Target = Config.Framework.target
local VehicleKeys = Config.Framework.vehicleKeys
local Banking = Config.Framework.banking

local QBCore = nil
local ESX = nil
local TMC = nil
if Framework == "QB" then
    QBCore = exports['qb-core']:GetCoreObject()
elseif Framework == "ESX" then
    ESX = exports['es_extended']:getSharedObject()
elseif Framework == "TMC" then
    TMC = exports.core:getCoreObject()
else
    debugPrint("No framework set in Config.Framework")
end

local QBCore = exports['qb-core']:GetCoreObject()
local isInVehicle = false
local isRadioActive = false
local radarInitialized = false

AddEventHandler('pma-voice:radioActive', function(radioTalking)
    isRadioActive = radioTalking
end)

for _, component in ipairs(Config.HudComponents) do
    local compName = component.name
    local eventName = component.event
    AddEventHandler(eventName, function(value)
        SendReactMessage('setPlayerData', { [compName] = value })
    end)
end

AddStateBagChangeHandler('hunger', ('player:%s'):format(cache.serverId), function(_, _, value)
    if not value then return end
    TriggerEvent('CHud:UpdateHunger', math.floor(value))
end)

AddStateBagChangeHandler('thirst', ('player:%s'):format(cache.serverId), function(_, _, value)
    if not value then return end
    TriggerEvent('CHud:UpdateThirst', math.floor(value))
end)

AddStateBagChangeHandler('stress', ('player:%s'):format(cache.serverId), function(_, _, value)
    if not value then return end
    TriggerEvent('CHud:UpdateStress', math.floor(value))
end)

AddStateBagChangeHandler('seatbelt', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value == nil then return end
    TriggerEvent('CHud:UpdateSeatbelt', value)
    SendReactMessage('setSeatbelt', value)
end)

local function initRadar()
    if radarInitialized then return end
    DisplayRadar(true)
    SetRadarZoom(1100)
    HideHudComponentThisFrame(1)  
    radarInitialized = true
end

function loadHud()
    HideHudComponentThisFrame(6)
    HideHudComponentThisFrame(8)
    HideHudComponentThisFrame(9)
    HideHudComponentThisFrame(20)
    local ped = PlayerPedId()
    local playerId = PlayerId()
    local isTalking = NetworkIsPlayerTalking(playerId)
    local isUnderWater = IsPedSwimmingUnderWater(ped)

    SendReactMessage('setPlayerData', { isUnderwater = isUnderWater })

    if isUnderWater then
        local oxygenRemaining = GetPlayerUnderwaterTimeRemaining(playerId) * 10
        TriggerEvent('CHud:UpdateOxygen', math.floor(oxygenRemaining))
    end

    local health = GetEntityHealth(ped) - 100
    local maxHealth = GetEntityMaxHealth(ped) - 100
    local healthPercent = math.floor((health / maxHealth) * 100)
    local armor = GetPedArmour(ped)
    local stamina = math.floor(100 - GetPlayerSprintStaminaRemaining(playerId))

    TriggerEvent('CHud:UpdateHealth', healthPercent)
    TriggerEvent('CHud:UpdateArmor', armor)
    TriggerEvent('CHud:UpdateStamina', stamina)

    SendReactMessage('setMicrophone', {
        isActive = isTalking and not isRadioActive,
        volume = isTalking and 75 or 0
    })
end
local lastStreetUpdate = 0

function loadVehicleHud()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then return end

    local mphSpeed = math.floor(GetEntitySpeed(vehicle) * 2.236936)
    local gear = GetVehicleCurrentGear(vehicle)
    local fuel = math.floor(GetVehicleFuelLevel(vehicle))
    local rpm = math.floor(GetVehicleCurrentRpm(vehicle) * 100)
    local engineHealth = math.floor(GetVehicleEngineHealth(vehicle) / 10)

    TriggerEvent('CHud:ShowFuelHud', fuel)
    TriggerEvent('CHud:UpdateEngineHealth', engineHealth)

    SendReactMessage('setPlayerData', {
        speed = mphSpeed,
        gear = gear,
        rpm = rpm
    })

    local now = GetGameTimer()
    if now - lastStreetUpdate > 2000 then
        lastStreetUpdate = now
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local streetHash, _ = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local streetName = GetStreetNameFromHashKey(streetHash)

        local heading = GetEntityHeading(playerPed)
        local direction = "N"
        if heading >= 337.5 or heading < 22.5 then direction = "N"
        elseif heading >= 22.5 and heading < 67.5 then direction = "NE"
        elseif heading >= 67.5 and heading < 112.5 then direction = "E"
        elseif heading >= 112.5 and heading < 157.5 then direction = "SE"
        elseif heading >= 157.5 and heading < 202.5 then direction = "S"
        elseif heading >= 202.5 and heading < 247.5 then direction = "SW"
        elseif heading >= 247.5 and heading < 292.5 then direction = "W"
        elseif heading >= 292.5 and heading < 337.5 then direction = "NW"
        end

        local locationName = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
        if locationName == "DOWNT" then locationName = "Downtown" end

        SendReactMessage('setStreetNames', {
            direction = direction,
            locationName = locationName,
            streetName = streetName
        })
    end
end

function loadStreetNames()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local streetHash, _ = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)

    local heading = GetEntityHeading(playerPed)
    local direction = "N"
    if heading >= 337.5 or heading < 22.5 then direction = "N"
    elseif heading >= 22.5 and heading < 67.5 then direction = "NE"
    elseif heading >= 67.5 and heading < 112.5 then direction = "E"
    elseif heading >= 112.5 and heading < 157.5 then direction = "SE"
    elseif heading >= 157.5 and heading < 202.5 then direction = "S"
    elseif heading >= 202.5 and heading < 247.5 then direction = "SW"
    elseif heading >= 247.5 and heading < 292.5 then direction = "W"
    elseif heading >= 292.5 and heading < 337.5 then direction = "NW"
    end

    local locationName = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))

    SendReactMessage('setStreetNames', {
        direction = direction,
        locationName = locationName,
        streetName = streetName
    })
end

RegisterNetEvent('hud:client:LoadMap', function()
    local defaultAspectRatio = 1920 / 1080
    local resolutionX, resolutionY = GetActiveScreenResolution()
    local aspectRatio = resolutionX / resolutionY
    local minimapOffset = 0
    if aspectRatio > defaultAspectRatio then
        minimapOffset = ((defaultAspectRatio - aspectRatio) / 3.6) - 0.008
    end

SetMinimapComponentPosition('minimap', 'L', 'B', 0.0 + minimapOffset, -0.047, 0.120, 0.140)  -- was 0.1638, 0.183
SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.0 + minimapOffset, 0.0, 0.095, 0.155) -- was 0.128, 0.20
SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.01 + minimapOffset, 0.025, 0.195, 0.230) -- was 0.262, 0.300
    SetBigmapActive(true, false)
    Wait(50)
    SetBigmapActive(false, false)
end)

CreateThread(function()
    SendReactMessage('setHudComponents', Config.HudComponents)
    while true do
        Wait(500)
        loadHud()
    end
end)


CreateThread(function()
    while true do
        Wait(3000)
        if not isInVehicle then
            loadStreetNames()
        end
    end
end)

CreateThread(function()
    DisplayRadar(false)
    toggleNuiFrame(false)

    while not LocalPlayer.state.isLoggedIn do
        Wait(500)
    end

    toggleNuiFrame(true)
    DisplayRadar(true)
end)


AddStateBagChangeHandler('isLoggedIn', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value then
        toggleNuiFrame(true)
        DisplayRadar(true)
    else
        toggleNuiFrame(false)
        DisplayRadar(false)
    end
end)
CreateThread(function()
    while true do
        Wait(100)
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            if not isInVehicle then
                isInVehicle = true
                SendReactMessage('setPlayerData', { isInVehicle = true })
            end
            loadVehicleHud()
        else
            if isInVehicle then
                isInVehicle = false
                SendReactMessage('setPlayerData', {
                    isInVehicle = false,
                    fuel = 0,
                    speed = 0,
                    gear = 0,
                    rpm = 0,
                    engineHealth = 0
                })
            end
        end
    end
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
    end

    Wait(1000)

    local minimap = RequestScaleformMovie("minimap")
    while not HasScaleformMovieLoaded(minimap) do
        Wait(100)
    end

    BeginScaleformMovieMethod(minimap, "SETUP_HEALTH_ARMOUR")
    ScaleformMovieMethodAddParamInt(3)
    EndScaleformMovieMethod()
end)

CreateThread(function()
    Wait(1000)
    if Config.HudComponents then
        SendReactMessage('setHudComponents', Config.HudComponents)
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    initRadar()
    TriggerEvent('hud:client:LoadMap')
    local hunger = LocalPlayer.state.hunger
    local thirst = LocalPlayer.state.thirst
    local stress = LocalPlayer.state.stress
    if hunger then TriggerEvent('CHud:UpdateHunger', math.floor(hunger)) end
    if thirst then TriggerEvent('CHud:UpdateThirst', math.floor(thirst)) end
    if stress then TriggerEvent('CHud:UpdateStress', math.floor(stress)) end
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    radarInitialized = false --
    DisplayRadar(false)
end)
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(2000)
    initRadar()
    TriggerEvent('hud:client:LoadMap')
    local hunger = LocalPlayer.state.hunger
    local thirst = LocalPlayer.state.thirst
    local stress = LocalPlayer.state.stress
    if hunger then TriggerEvent('CHud:UpdateHunger', math.floor(hunger)) end
    if thirst then TriggerEvent('CHud:UpdateThirst', math.floor(thirst)) end
    if stress then TriggerEvent('CHud:UpdateStress', math.floor(stress)) end
end)

Citizen.CreateThread(function()
    local minimap = RequestScaleformMovie("minimap")
    SetRadarBigmapEnabled(true, false)
    Wait(0)
    SetRadarBigmapEnabled(false, false)
    while true do
        Wait(0)
        BeginScaleformMovieMethod(minimap, "SETUP_HEALTH_ARMOUR")
        ScaleformMovieMethodAddParamInt(3)
        EndScaleformMovieMethod()
    end
end)




RegisterCommand("togglehud", function(source, args, rawCommand)

    if not hidden then 
        hidden = true
        DisplayRadar(false)
        toggleNuiFrame(false)
    else 
        hidden = false
        toggleNuiFrame(true)
        DisplayRadar(true)
end

end, false)


function CNotification(message, icon, color, duration)
    SendReactMessage('notify', {
        id = tostring(GetGameTimer()),
        text = message,
        icon = icon,
        iconColor = color,
        duration = duration or 5000
    })
end

exports('CNotification', CNotification)
function CProgressbar(label, icon, color, duration, canCancel, canMove, onComplete)
    SendReactMessage('startProgressbar', {
        label = label,
        icon = icon,
        color = color,
        duration = duration,
        canCancel = canCancel,
        canMove = canMove,
    })

    if not canMove then
        FreezeEntityPosition(PlayerPedId(), true)
    end

    local cancelled = false
    local finished = false

    if canCancel then
        CreateThread(function()
            while not finished do
                Wait(0)
                if IsControlJustPressed(0, 73) then
                    cancelled = true
                    finished = true
                    CStopProgressbar()
                    FreezeEntityPosition(PlayerPedId(), false)
                    CNotification("Cancelled!", "fa-xmark", "#ff1744", 3000)
                end
            end
        end)
    end

    SetTimeout(duration, function()
        finished = true
        FreezeEntityPosition(PlayerPedId(), false)
        if not cancelled then
            if onComplete then
                onComplete()
            end
        end
    end)
end




function CStopProgressbar()
    SendReactMessage('stopProgressbar', {})
end

exports('CProgressbar', CProgressbar)
exports('CStopProgressbar', CStopProgressbar)



local activeMinigame = false
local successCallback = nil
local failCallback = nil

RegisterNUICallback("sliderMinigameResult", function(data, cb)
    activeMinigame = false
    SetNuiFocus(false, false)
    if data.success then
        if successCallback then successCallback() end
    else
        if failCallback then failCallback() end
    end
    successCallback = nil
    failCallback = nil
    cb({})
end)

exports('startSliderMinigame', function(options)
    if activeMinigame then return end
    activeMinigame = true
    successCallback = options.onSuccess
    failCallback = options.onFail

    SetNuiFocus(true, false)

    SendReactMessage('showSliderMinigame', {
        speed     = options.speed    or 2,
        required  = options.required or 3,
        maxFaults = options.maxFaults or 2,
        time      = options.time or nil,
    })
end)


RegisterCommand("testslider", function()
    exports['CHud']:startSliderMinigame({
        speed = 3,
        required = 3,
        maxFaults = 2,
        time = 5,
        onSuccess = function()
            print("success!")
        end,
        onFail = function()
            print("failed")
        end
    })
end, false)