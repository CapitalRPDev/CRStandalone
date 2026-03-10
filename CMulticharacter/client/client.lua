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
local PreviewCam
local RandomLocation = Config.Locations[math.random(1, #Config.Locations)]

local function SetupPreviewCam(bool)
    if bool then
        DoScreenFadeIn(1000)
        SetTimecycleModifier('hud_def_blur')
        SetTimecycleModifierStrength(1.0)
        FreezeEntityPosition(cache.ped, false)
        PreviewCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', RandomLocation.CamCoords.x, RandomLocation.CamCoords.y, RandomLocation.CamCoords.z, -6.0, 0.0, RandomLocation.CamCoords.w, 40.0, false, 0)
        SetCamActive(PreviewCam, true)
        SetCamUseShallowDofMode(PreviewCam, true)
        SetCamNearDof(PreviewCam, 0.4)
        SetCamFarDof(PreviewCam, 1.8)
        SetCamDofStrength(PreviewCam, 0.7)
        RenderScriptCams(true, false, 1, true, true)
        while DoesCamExist(PreviewCam) do
            SetUseHiDof()
            Wait(0)
        end
    else
        SetTimecycleModifier('default')
        SetCamActive(PreviewCam, false)
        DestroyCam(PreviewCam, true)
        RenderScriptCams(false, false, 1, true, true)
        FreezeEntityPosition(cache.ped, false)
    end
end

local function toggleUI(bool)
    print('^3[CMulticharacter]^7 toggleUI called with: ' .. tostring(bool))
    local Amount = lib.callback.await('qb-multicharacter:callback:GetNumberOfCharacters', false)
    print('^3[CMulticharacter]^7 Got nChar: ' .. tostring(Amount))
    SetNuiFocus(bool, bool)
    print('^3[CMulticharacter]^7 Sending ReactMessage ui toggle: ' .. tostring(bool))
    toggleNuiFrame(true)
    SendReactMessage('ui', {
        toggle = bool,
        nChar = Amount,
        enableDeleteButton = Config.EnableDeleteButton,
    })
    print('^3[CMulticharacter]^7 SetupPreviewCam starting')
    SetupPreviewCam(bool)
    print('^3[CMulticharacter]^7 toggleUI done')
end

local function RandomClothes(Entity)
    for i = 0, 11 do
        SetPedComponentVariation(Entity, i, 0, 0, 0)
    end
    for i = 0, 7 do
        ClearPedProp(Entity, i)
    end
    SetPedHeadBlendData(Entity, math.random(0, 45), math.random(0, 45), 0, math.random(0, 15), math.random(0, 15), 0, (math.random(0, 100) / 100), (math.random(0, 100) / 100), 0, true)
    SetPedComponentVariation(Entity, 4, math.random(0, 110), 0, 0)
    SetPedComponentVariation(Entity, 2, math.random(0, 45), 0, 0)
    SetPedHairColor(Entity, math.random(0, 45), math.random(0, 45))
    SetPedHeadOverlay(Entity, 2, math.random(0, 34), 1.0)
    SetPedHeadOverlayColor(Entity, 2, 1, math.random(0, 45), 0)
    SetPedComponentVariation(Entity, 3, math.random(0, 160), 0, 2)
    SetPedComponentVariation(Entity, 8, math.random(0, 160), 0, 2)
    SetPedComponentVariation(Entity, 11, math.random(0, 340), 0, 2)
    SetPedComponentVariation(Entity, 6, math.random(0, 78), 0, 2)
end

RegisterNetEvent('qb-multicharacter:client:closeNUIdefault', function() -- This event is only for no starting apartments
    SetNuiFocus(false, false)
    DoScreenFadeOut(500)
    Wait(2000)
    SetEntityCoords(PlayerPedId(), Config.DefaultSpawn.x, Config.DefaultSpawn.y, Config.DefaultSpawn.z)
    SetEntityHeading(PlayerPedId(), Config.DefaultSpawn.w)
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    Wait(500)
    toggleUI()
    SetEntityVisible(PlayerPedId(), true)
    Wait(500)
    DoScreenFadeIn(250)
    TriggerEvent('qb-weathersync:client:EnableSync')
    TriggerEvent('qb-clothes:client:CreateFirstCharacter')
end)

lib.callback.register('qb-multicharacter:callback:defaultSpawn', function()
    SetNuiFocus(false, false)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    toggleUI(false)
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    pcall(function()
        exports.spawnmanager:spawnPlayer({
            x = Config.DefaultSpawn.x,
            y = Config.DefaultSpawn.y,
            z = Config.DefaultSpawn.z,
            heading = Config.DefaultSpawn.w,
            model = 'mp_m_freemode_01'
        }, function()
            DoScreenFadeIn(500)
        end)
    end)
    while not IsScreenFadedIn() do Wait(0) end
    return true
end)

RegisterNetEvent('qb-multicharacter:client:chooseChar', function()
    print('^3[CMulticharacter]^7 chooseChar event fired')
    SetNuiFocus(false, false)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    FreezeEntityPosition(cache.ped, true)
    Wait(1000)
    SetEntityCoords(cache.ped, RandomLocation.PedCoords.x, RandomLocation.PedCoords.y, RandomLocation.PedCoords.z, false, false, false, false)
    SetEntityHeading(cache.ped, RandomLocation.PedCoords.w)
    RandomClothes(cache.ped)
    Wait(1500)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    toggleUI(true)
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    local cData = data.cData
    DoScreenFadeOut(10)
    TriggerServerEvent('qb-multicharacter:server:loadUserData', cData)
    toggleUI(false)
    cb('ok')
end)

RegisterNUICallback('setupCharacters', function(_, cb)
    print('^3[CMulticharacter]^7 setupCharacters NUI callback fired')
    local Result = lib.callback.await('qb-multicharacter:callback:GetCurrentCharacters', false)
    print('^3[CMulticharacter]^7 Got ' .. tostring(Result and #Result or 0) .. ' characters')
    SendReactMessage('setupCharacters', {
        characters = Result
    })
    cb('ok')
end)

RegisterNUICallback('removeBlur', function(_, cb)
    SetTimecycleModifier('default')
    cb('ok')
end)

RegisterNUICallback('reapplyBlur', function(_, cb)
    SetTimecycleModifier('hud_def_blur')
    SetTimecycleModifierStrength(1.0)
    cb('ok')
end)


RegisterNUICallback('previewPed', function(Ped, cb)
    local CID = Ped.Data and Ped.Data.citizenid or nil
    Clothing, Model, Gender = lib.callback.await('qb-multicharacter:callback:UpdatePreviewPed', false, CID)
    if Model then
        local CurrentModel = GetEntityModel(cache.ped)
        if CurrentModel ~= `mp_m_freemode_01` and Gender == 0 then
            while not HasModelLoaded(Model) do RequestModel(Model) Wait(0) end
            SetPlayerModel(cache.playerId, Model)
        elseif CurrentModel ~= `mp_f_freemode_01` and Gender == 1 then
            while not HasModelLoaded(Model) do RequestModel(Model) Wait(0) end
            SetPlayerModel(cache.playerId, Model)
        end
        SetModelAsNoLongerNeeded(Model)
        cache:set('ped', PlayerPedId())
    end
    if Clothing then
        exports["illenium-appearance"]:setPedAppearance(cache.ped, json.decode(Clothing))
    else
        RandomClothes(cache.ped)
    end
    cb('ok')
end)

RegisterNUICallback('createNewCharacter', function(data, cb)
    local cData = data
    DoScreenFadeOut(150)
    if cData.gender == 'Male' then
        cData.gender = 0
    elseif cData.gender == 'Female' then
        cData.gender = 1
    end
    TriggerServerEvent('qb-multicharacter:server:createCharacter', cData)
    cb('ok')
end)

RegisterNetEvent('CMulticharacter:client:openAppearance', function(gender)
    toggleNuiFrame(false)
    SetNuiFocus(false, false)

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    -- Set model based on gender
    local model = gender == 1 and `mp_f_freemode_01` or `mp_m_freemode_01`
    lib.requestModel(model)
    SetPlayerModel(cache.playerId, model)
    cache:set('ped', PlayerPedId())
    SetModelAsNoLongerNeeded(model)

    -- Set a clean default appearance
    SetPedDefaultComponentVariation(cache.ped)
    SetPedHeadBlendData(cache.ped, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0, true)
    for i = 0, 12 do
        SetPedHeadOverlay(cache.ped, i, 0, 0.0)
    end
    SetPedComponentVariation(cache.ped, 2, 0, 0, 0)  -- hair
    SetPedComponentVariation(cache.ped, 3, 15, 0, 0) -- torso
    SetPedComponentVariation(cache.ped, 4, 14, 0, 0) -- legs
    SetPedComponentVariation(cache.ped, 6, 1, 0, 0)  -- shoes
    SetPedComponentVariation(cache.ped, 8, 15, 0, 0) -- shirt
    SetPedComponentVariation(cache.ped, 11, 15, 0, 0) -- jacket

    SetEntityCoords(cache.ped, Config.DefaultSpawn.x, Config.DefaultSpawn.y, Config.DefaultSpawn.z)
    SetEntityHeading(cache.ped, Config.DefaultSpawn.w)
    SetEntityVisible(PlayerPedId(), true)
    SetTimecycleModifier('default')

    DoScreenFadeIn(500)
    while not IsScreenFadedIn() do Wait(0) end

    Wait(500)

    exports['illenium-appearance']:startPlayerCustomization(function(appearance)
        if appearance then
            TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
        end
        TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
        TriggerEvent('QBCore:Client:OnPlayerLoaded')
        TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
        TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    end, {
        components = true,
        componentConfig = {
            masks = true, upperBody = true, lowerBody = true, bags = true,
            shoes = true, scarfAndChains = true, bodyArmor = true,
            shirts = true, decals = true, jackets = true
        },
        props = true,
        propConfig = {
            hats = true, glasses = true, ear = true,
            watches = true, bracelets = true
        },
        headBlend = true,
        faceFeatures = true,
        headOverlays = true,
        hairColor = true,
        eyeColor = true,
        enableExit = true,
    })
end)



RegisterNUICallback('removeCharacter', function(data, cb)
    TriggerServerEvent('qb-multicharacter:server:deleteCharacter', data.citizenid)
    TriggerEvent('qb-multicharacter:client:chooseChar')
    cb('ok')
end)

CreateThread(function()
	local modelHash = `mp_m_freemode_01`
	while true do
		Wait(0)
		if NetworkIsSessionStarted() then
	            pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
	            Wait(250)
	            TriggerEvent('qb-multicharacter:client:chooseChar')
	            lib.requestModel(modelHash)
	            while GetEntityModel(cache.ped) ~= modelHash do
	                SetPlayerModel(cache.playerId, modelHash)
	                Wait(0)
	            end
	            break
	        end
	end
end)



AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set('isLoggedIn', true, false)
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set('isLoggedIn', false, false)
end)