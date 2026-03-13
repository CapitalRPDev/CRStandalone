local QBCore = exports['qb-core']:GetCoreObject()
local cuffObject = 0
local isCuffing = false 
local isFrontCuffed = false 


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
RegisterNetEvent("CPoliceJob:Client:PlayCuffAnim", function(targetServerId, frontCuffed)
    isCuffing = true
    isFrontCuffed = frontCuffed

    if not loadAnimDict(Config.Anims.cuffing.officer.dict) then isCuffing = false return end
    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetServerId))

    if not frontCuffed then
        AttachEntityToEntity(PlayerPedId(), targetPed, 11816, -0.1, -0.45, 0.0, 0.0, 0.0, 20.0, false, false, false, false, 20, false)
    end

    TaskPlayAnim(PlayerPedId(), Config.Anims.cuffing.officer.dict, Config.Anims.cuffing.officer.name,
        Config.CuffSettings.animBlendIn, Config.CuffSettings.animBlendOut, -1, 0, 0, false, false, false)

    Wait(Config.CuffSettings.cuffingDuration)

    if not frontCuffed then
        DetachEntity(PlayerPedId(), true, false)
    end

    RemoveAnimDict(Config.Anims.cuffing.officer.dict)
    isCuffing = false
end)

RegisterNetEvent("CPoliceJob:Client:PlayCuffedAnim", function(frontCuffed)
    isCuffing = true
    isFrontCuffed = frontCuffed

    if not loadAnimDict(Config.Anims.cuffing.criminal.dict) then isCuffing = false return end

    TaskPlayAnim(PlayerPedId(), Config.Anims.cuffing.criminal.dict, Config.Anims.cuffing.criminal.name,
        Config.CuffSettings.animBlendIn, Config.CuffSettings.animBlendOut, -1, 0, 0, false, false, false)

    Wait(Config.CuffSettings.cuffingDuration)

    RemoveAnimDict(Config.Anims.cuffing.criminal.dict)
    isCuffing = false
    playIdleCuffAnim()
end)


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






function Notify(text, duration)

exports['CHud']:CNotification(text, "fa-duotone fa-solid fa-user-police", "#1B4F72", duration or 3000)

end







local function applyCuffs(value)
    print(value)



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