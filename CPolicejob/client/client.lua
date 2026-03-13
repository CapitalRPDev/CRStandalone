local QBCore = exports['qb-core']:GetCoreObject()
local isCuffing = false 
local isFrontCuffed = false 
local isCuffed = false
local cuffProp = 0
local isCuffVisible = false

CreateThread(function()
    InitScript()
end)

function InitScript()
    for i, coords in pairs(Config.Police.toggleDuty) do
        exports['CInteraction']:createZone(
            coords,
            vector3(2.0, 2.0, 5.0),
            {
                id = ('police_toggle_duty_%s'):format(i),
                hideOnSelect = false,
                prompts = {
                    {
                        label = "Toggle Duty",
                        sublabel = "Clock On/Off duty",
                        icon = "fa-solid fa-shield",
                        action = function()
                            exports['CHud']:CProgressbar("Typing on computer", "fa-keyboard", "#00A7DC", 2000, false, true, function()
                                TriggerServerEvent("CPolice:Server:ToggleDuty")
                            end)
                        end,
                        canInteract = function()
                            return QBCore.Functions.GetPlayerData().job.name == 'police'
                        end
                    },
                }
            }
        )
    end
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local startTime = GetGameTimer()
    while not HasAnimDictLoaded(dict) do
        Wait(0)
        if GetGameTimer() - startTime > 5000 then return false end
    end
    return true
end

local function playCuffAnim(dict, name)
    if not loadAnimDict(dict) then return end
    TaskPlayAnim(PlayerPedId(), dict, name, 
        Config.CuffSettings.animBlendIn, 
        Config.CuffSettings.animBlendOut, 
        -1, 0, 0, false, false, false)
end

local function stopCuffAnim()
    ClearPedTasks(PlayerPedId())
    RemoveAnimDict(Config.Anims.backCuff.dict)
    RemoveAnimDict(Config.Anims.frontCuff.dict)
end

local function isPolice()
    local playerData = QBCore.Functions.GetPlayerData()
    local job = playerData.job.name 
    local duty = true
    if Config.Police.requireDuty then 
        duty = playerData.job.onduty
    end
    if job == Config.Police.job and duty then 
        return true
    end
    Notify("You are not on duty", 4000)
    return false
end

CreateThread(function()
    while true do
        Wait(0)
        if isCuffed then
            local playerPed = PlayerPedId()
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 36, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 47, true)
            DisableControlAction(0, 58, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 143, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 157, true)
            DisableControlAction(0, 158, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(0, 194, true)
            DisableControlAction(0, 170, true)
            DisableControlAction(0, 167, true)
            DisableControlAction(0, 168, true)
            SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
        end
    end
end)

local function GetClosestPlayer(maxDistance)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local closestPlayer, closestDistance = -1, maxDistance or 10.0
    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetCoords = GetEntityCoords(GetPlayerPed(playerId))
            local distance = #(coords - targetCoords)
            if distance < closestDistance then
                closestPlayer = playerId
                closestDistance = distance
            end
        end
    end
    return closestPlayer, closestDistance
end

local function playIdleCuffAnim()
    if isFrontCuffed then
        if not loadAnimDict(Config.Anims.frontCuff.dict) then return end
        TaskPlayAnim(PlayerPedId(), Config.Anims.frontCuff.dict, Config.Anims.frontCuff.name,
            Config.CuffSettings.animBlendIn, Config.CuffSettings.animBlendOut, -1, 49, 0, false, false, false)
    else
        if not loadAnimDict(Config.Anims.backCuff.dict) then return end
        TaskPlayAnim(PlayerPedId(), Config.Anims.backCuff.dict, Config.Anims.backCuff.name,
            Config.CuffSettings.animBlendIn, Config.CuffSettings.animBlendOut, -1, 49, 0, false, false, false)
    end
end
local function spawnCuffProp()
    if DoesEntityExist(cuffProp) then
        DeleteEntity(cuffProp)
        cuffProp = 0
    end

    local model = GetHashKey(Config.Props.cuffs)
    RequestModel(model)

    local startTime = GetGameTimer()
    while not HasModelLoaded(model) do
        Wait(0)
        if GetGameTimer() - startTime > 5000 then
            print("[CUFFS] Failed to load model")
            return
        end
    end

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)

    cuffProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)
    if not DoesEntityExist(cuffProp) then
        print("[CUFFS] Failed to create object")
        return
    end

    local cuffConfig = isFrontCuffed and Config.Anims.frontCuff or Config.Anims.backCuff
    local pos = cuffConfig.boneOffset.pos
    local rot = cuffConfig.boneOffset.rot
    local boneIndex = GetPedBoneIndex(playerPed, cuffConfig.attachBone)

    print("[CUFFS] isFrontCuffed:", isFrontCuffed)
    print("[CUFFS] attachBone:", cuffConfig.attachBone)
    print("[CUFFS] boneIndex:", boneIndex)
    print("[CUFFS] prop exists:", DoesEntityExist(cuffProp))

    SetEntityCollision(cuffProp, false, false)
    SetEntityAsMissionEntity(cuffProp, true, true)

    AttachEntityToEntity(
        cuffProp,
        playerPed,
        boneIndex,
        pos[1], pos[2], pos[3],
        rot[1], rot[2], rot[3],
        false, false, false, false, 2, true
    )

    Wait(0)
    print("[CUFFS] attached:", IsEntityAttached(cuffProp))

    isCuffVisible = true
    SetModelAsNoLongerNeeded(model)
end

local function deleteCuffProp()
    if DoesEntityExist(cuffProp) then
        DetachEntity(cuffProp, true, true)
        DeleteEntity(cuffProp)
    end
    cuffProp = 0
    isCuffVisible = false
end

RegisterNetEvent("CPoliceJob:Client:PlayCuffAnim", function(targetServerId, frontCuffed)
    isCuffing = true
    isFrontCuffed = frontCuffed

    if frontCuffed then
        if not loadAnimDict(Config.Anims.cuffing.officerFront.dict) then isCuffing = false return end
        local targetPed = GetPlayerPed(GetPlayerFromServerId(targetServerId))
        local o = Config.Anims.cuffing.officerFront.attachOffset
        AttachEntityToEntity(PlayerPedId(), targetPed, 11816, o.x, o.y, o.z, o.rotX, o.rotY, o.rotZ, false, false, false, false, 20, false)
        TaskPlayAnim(PlayerPedId(), Config.Anims.cuffing.officerFront.dict, Config.Anims.cuffing.officerFront.name,
            Config.CuffSettings.animBlendIn, Config.CuffSettings.animBlendOut, -1, 0, 0, false, false, false)
        Wait(Config.CuffSettings.cuffingDuration)
        DetachEntity(PlayerPedId(), true, false)
        RemoveAnimDict(Config.Anims.cuffing.officerFront.dict)
    else
        if not loadAnimDict(Config.Anims.cuffing.officer.dict) then isCuffing = false return end
        local targetPed = GetPlayerPed(GetPlayerFromServerId(targetServerId))
        local o = Config.Anims.cuffing.officer.attachOffset
        AttachEntityToEntity(PlayerPedId(), targetPed, 11816, o.x, o.y, o.z, o.rotX, o.rotY, o.rotZ, false, false, false, false, 20, false)
        TaskPlayAnim(PlayerPedId(), Config.Anims.cuffing.officer.dict, Config.Anims.cuffing.officer.name,
            Config.CuffSettings.animBlendIn, Config.CuffSettings.animBlendOut, -1, 0, 0, false, false, false)
        Wait(Config.CuffSettings.cuffingDuration)
        DetachEntity(PlayerPedId(), true, false)
        RemoveAnimDict(Config.Anims.cuffing.officer.dict)
    end

    isCuffing = false
end)

RegisterNetEvent("CPoliceJob:Client:PlayCuffedAnim", function(frontCuffed)
    isCuffing = true
    isFrontCuffed = frontCuffed

    if frontCuffed then
        if not loadAnimDict(Config.Anims.cuffing.criminalFront.dict) then isCuffing = false return end
        TaskPlayAnim(PlayerPedId(), Config.Anims.cuffing.criminalFront.dict, Config.Anims.cuffing.criminalFront.name,
            Config.CuffSettings.animBlendIn, Config.CuffSettings.animBlendOut, -1, 0, 0, false, false, false)
        Wait(Config.CuffSettings.cuffingDuration)
        RemoveAnimDict(Config.Anims.cuffing.criminalFront.dict)
    else
        if not loadAnimDict(Config.Anims.cuffing.criminal.dict) then isCuffing = false return end
        TaskPlayAnim(PlayerPedId(), Config.Anims.cuffing.criminal.dict, Config.Anims.cuffing.criminal.name,
            Config.CuffSettings.animBlendIn, Config.CuffSettings.animBlendOut, -1, 0, 0, false, false, false)
        Wait(Config.CuffSettings.cuffingDuration)
        RemoveAnimDict(Config.Anims.cuffing.criminal.dict)
    end

    isCuffing = false
    playIdleCuffAnim()
    spawnCuffProp()
end)

RegisterNetEvent("CPoliceJob:Client:PlayUncuffAnim", function(targetServerId, frontCuffed)
    isCuffing = true

    if not loadAnimDict(Config.Anims.uncuff.officer.dict) then isCuffing = false return end
    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetServerId))

    local o = frontCuffed and Config.Anims.uncuff.officer.attachOffsetFront or Config.Anims.uncuff.officer.attachOffset
    AttachEntityToEntity(PlayerPedId(), targetPed, 11816, o.x, o.y, o.z, o.rotX, o.rotY, o.rotZ, false, false, false, false, 20, false)

    TaskPlayAnim(PlayerPedId(), Config.Anims.uncuff.officer.dict, Config.Anims.uncuff.officer.name,
        Config.CuffSettings.animBlendIn, Config.CuffSettings.animBlendOut, -1, 0, 0, false, false, false)

    Wait(Config.CuffSettings.uncuffDuration)
    DetachEntity(PlayerPedId(), true, false)
    RemoveAnimDict(Config.Anims.uncuff.officer.dict)
    isCuffing = false
end)

RegisterNetEvent("CPoliceJob:Client:PlayUncuffedAnim", function()
    isCuffing = true

    if not loadAnimDict(Config.Anims.uncuff.criminal.dict) then isCuffing = false return end

    TaskPlayAnim(PlayerPedId(), Config.Anims.uncuff.criminal.dict, Config.Anims.uncuff.criminal.name,
        Config.CuffSettings.animBlendIn, Config.CuffSettings.animBlendOut, -1, 0, 0, false, false, false)

    Wait(Config.CuffSettings.uncuffDuration)
    RemoveAnimDict(Config.Anims.uncuff.criminal.dict)
    stopCuffAnim()
    deleteCuffProp()
    isCuffed = false
    isFrontCuffed = false
    isCuffing = false
end)

RegisterNetEvent("CPoliceJob:Client:SetCuffed", function(value, cuffedBy)
    print("received cuff state:", value, "by:", cuffedBy)
    if not value then
        isCuffed = false
        isFrontCuffed = false
    else
        isCuffed = true
    end
end)

RegisterNetEvent("CPoliceJob:Client:Notify", function(text, duration)
    Notify(text, duration)
end)

RegisterCommand("uncuff", function(source, args, rawCommand)
    if not isPolice() then return end
    local playerId, distance = GetClosestPlayer(5.0)
    if playerId == -1 then
        Notify("No one is close to you...", 4000)
        return
    end
    local targetServerId = GetPlayerServerId(playerId)
    if not targetServerId or targetServerId <= 0 then
        print("[Error] - Could not find target server Id")
        return
    end
    TriggerServerEvent("CPoliceJob:Server:RequestUncuff", targetServerId)
end, false)

RegisterCommand("cuff", function(source, args, rawCommand)
    if not isPolice() then return end
    local playerId, distance = GetClosestPlayer(5.0)
    if playerId == -1 then
        Notify("No one is close to you...", 4000)
        return
    end
    local targetServerId = GetPlayerServerId(playerId)
    if not targetServerId or targetServerId <= 0 then
        print("[Error] - Could not find target server Id")
        return
    end
    TriggerServerEvent("CPoliceJob:Server:RequestCuff", targetServerId, false)
end, false)

RegisterCommand("frontcuff", function(source, args, rawCommand)
    if not isPolice() then return end
    local playerId, distance = GetClosestPlayer(5.0)
    if playerId == -1 then
        Notify("No one is close to you...", 4000)
        return
    end
    local targetServerId = GetPlayerServerId(playerId)
    if not targetServerId or targetServerId <= 0 then
        print("[Error] - Could not find target server Id")
        return
    end
    TriggerServerEvent("CPoliceJob:Server:RequestCuff", targetServerId, true)
end, false)

function Notify(text, duration)
    exports['CHud']:CNotification(text, "fa-duotone fa-solid fa-user-police", "#1B4F72", duration or 3000)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for i, _ in pairs(Config.Police.toggleDuty) do
        exports['CInteraction']:removeZone(('police_toggle_duty_%s'):format(i))
    end
end)