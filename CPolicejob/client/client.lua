local QBCore = exports['qb-core']:GetCoreObject()
local cuffObject = 0
local isCuffing = false 
local isFrontCuffed = false 
local isCuffed = false

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
    local grade = playerData.job.grade.level
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


CreateThread(function()
    while true do
        Wait(0)
        if isCuffed then
            disableControls()
        end
    end
end)

local function playIdleCuffAnim()
    local playerPed = PlayerPedId()
    if isFrontCuffed then
        SetEnableHandcuffs(playerPed, false)  
        if not loadAnimDict(Config.Anims.frontCuff.dict) then return end
        TaskPlayAnim(playerPed, Config.Anims.frontCuff.dict, Config.Anims.frontCuff.name,
            Config.CuffSettings.animBlendIn, Config.CuffSettings.animBlendOut, -1, 49, 0, false, false, false)
    else
        SetEnableHandcuffs(playerPed, true)  
        if not loadAnimDict(Config.Anims.backCuff.dict) then return end
        TaskPlayAnim(playerPed, Config.Anims.backCuff.dict, Config.Anims.backCuff.name,
            Config.CuffSettings.animBlendIn, Config.CuffSettings.animBlendOut, -1, 49, 0, false, false, false)
    end
end



function disableControls()
    if isCuffed then
        local playerPed = PlayerPedId()

        -- Movement
        DisableControlAction(0, 21, true)   -- Sprint
        DisableControlAction(0, 22, true)   -- Jump
        DisableControlAction(0, 36, true)   -- Stealth mode toggle

        -- Combat
        DisableControlAction(0, 24, true)   -- Attack
        DisableControlAction(0, 25, true)   -- Aim
        DisableControlAction(0, 47, true)   -- Weapon
        DisableControlAction(0, 58, true)   -- Weapon 2
        DisableControlAction(0, 263, true)  -- Melee attack
        DisableControlAction(0, 264, true)  -- Melee attack alt
        DisableControlAction(0, 257, true)  -- Melee attack 2
        DisableControlAction(0, 140, true)  -- Melee block
        DisableControlAction(0, 141, true)  -- Melee dodge
        DisableControlAction(0, 142, true)  -- Melee lock on
        DisableControlAction(0, 143, true)  -- Melee lock on alt
        DisableControlAction(0, 37, true)   -- Select weapon
        DisableControlAction(0, 157, true)  -- Melee aim
        DisableControlAction(0, 158, true)  -- Melee aim alt

        -- Vehicle
        DisableControlAction(0, 23, true)   -- Enter vehicle
        DisableControlAction(0, 75, true)   -- Exit vehicle
        DisableControlAction(0, 194, true)  -- Enter vehicle alt

        -- Phone/other
        DisableControlAction(0, 170, true)  -- Phone
        DisableControlAction(0, 167, true)  -- Phone left
        DisableControlAction(0, 168, true)  -- Phone right

        SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
        SetPedStealthMovement(playerPed, true, "")

        if not isCuffing then
            if isFrontCuffed then
                if not IsEntityPlayingAnim(playerPed, Config.Anims.frontCuff.dict, Config.Anims.frontCuff.name, 3) then
                    playIdleCuffAnim()
                end
            else
                if not IsEntityPlayingAnim(playerPed, Config.Anims.backCuff.dict, Config.Anims.backCuff.name, 3) then
                    playIdleCuffAnim()
                end
            end
        end
    end
end



RegisterNetEvent("CPoliceJob:Client:PlayCuffAnim", function(targetServerId, frontCuffed)
    isCuffing = true
    isFrontCuffed = frontCuffed

    local animConfig = frontCuffed and Config.Anims.cuffing.officerFront or Config.Anims.cuffing.officer

    if not loadAnimDict(animConfig.dict) then isCuffing = false return end
    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetServerId))

    local o = animConfig.attachOffset
    AttachEntityToEntity(PlayerPedId(), targetPed, 11816, o.x, o.y, o.z, o.rotX, o.rotY, o.rotZ, false, false, false, false, 20, false)

    TaskPlayAnim(PlayerPedId(), animConfig.dict, animConfig.name,
        Config.CuffSettings.animBlendIn, Config.CuffSettings.animBlendOut, -1, 0, 0, false, false, false)

    Wait(Config.CuffSettings.cuffingDuration)
    DetachEntity(PlayerPedId(), true, false)
    RemoveAnimDict(animConfig.dict)
    isCuffing = false
end)

RegisterNetEvent("CPoliceJob:Client:PlayCuffedAnim", function(frontCuffed)
    isCuffing = true
    isFrontCuffed = frontCuffed

    local playerPed = PlayerPedId()

    if frontCuffed then
        SetEnableHandcuffs(playerPed, false)
        SetPedCanPlayGestureAnims(playerPed, true)
        if loadAnimDict("anim@move_m@prisoner_cuffed") then
            TaskPlayAnim(playerPed, "anim@move_m@prisoner_cuffed", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
        end
    else
        SetEnableHandcuffs(playerPed, true)
    end

    local animConfig = frontCuffed and Config.Anims.cuffing.criminalFront or Config.Anims.cuffing.criminal

    if not loadAnimDict(animConfig.dict) then isCuffing = false return end

    TaskPlayAnim(playerPed, animConfig.dict, animConfig.name,
        Config.CuffSettings.animBlendIn, Config.CuffSettings.animBlendOut, -1, 0, 0, false, false, false)

    Wait(Config.CuffSettings.cuffingDuration)
    RemoveAnimDict(animConfig.dict)
    isCuffing = false
    playIdleCuffAnim()
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
    isCuffed = false
    isFrontCuffed = false
    isCuffing = false
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

    TriggerServerEvent("CPoliceJob:Server:RequestFrontCuff", targetServerId)
end, false)





function Notify(text, duration)

exports['CHud']:CNotification(text, "fa-duotone fa-solid fa-user-police", "#1B4F72", duration or 3000)

end



RegisterNetEvent("CPoliceJob:Client:Notify", function(text, duration)
    Notify(text, duration)
end)





local function applyCuffs(value)
    if value then
        isCuffed = true
    else
        isCuffed = false
        isFrontCuffed = false
        SetEnableHandcuffs(PlayerPedId(), false)
        SetPedStealthMovement(PlayerPedId(), false, "")
        stopCuffAnim()
    end
end


RegisterNetEvent("CPoliceJob:Client:SetCuffed", function(value, cuffedBy)
    print("received cuff state:", value, "by:", cuffedBy)
    applyCuffs(value)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for i, _ in pairs(Config.Police.toggleDuty) do
        exports['CInteraction']:removeZone(('cpolice_toggle_duty_%s'):format(i))
    end
end)