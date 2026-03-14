local QBCore = exports['qb-core']:GetCoreObject()
local isCuffing = false 
local isFrontCuffed = false 
local isCuffed = false
local cuffProp = 0
local isCuffVisible = false
local isBeingDragged = false 
local dragger = nil
local escapedDuringCuff = false
CreateThread(function()
    InitScript()
end) 

function InitScript()
    for i, coords in pairs(Config.LaptopCoords) do
    exports['CInteraction']:createZone(
        coords,
        vector3(2.0, 2.0, 5.0),
        {
            id = ('police_laptop_%s'):format(i),
            hideOnSelect = false,
            prompts = {
                {
                    label = "Police Laptop",
                    sublabel = "Access police database",
                    icon = "fa-solid fa-laptop",
                    action = function()
                        OpenTestDui()
                    end,
                    canInteract = function()
                        return QBCore.Functions.GetPlayerData().job.name == 'police'
                    end
                },
            }
        }
    )
end
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
for i, stash in pairs(Config.Police.evidenceStash) do
exports['CInteraction']:createZone(
    stash.coords,
    vector3(2.0, 2.0, 5.0),
    {
        id = ('police_evidence_stash_%s'):format(i),
        hideOnSelect = true,
        prompts = {
            {
                label = stash.label,
                sublabel = "Open stash",
                icon = "fa-solid fa-magnifying-glass",
                action = function()
                    local input = lib.inputDialog('Evidence Stash', {
                        { type = 'input', label = 'Evidence Code', placeholder = 'EV-XXXXXXXX', required = true }
                    })

                    if not input or not input[1] then return end

                    local code = input[1]:upper():gsub('%s+', '')

                    lib.callback('CPolicejob:validateEvidenceCode', false, function(valid)
                        if valid then
                            TriggerServerEvent('CPolicejob:Server:SetActiveEvidenceCode', code, 'evidence_stash_' .. i)
                            exports.ox_inventory:openInventory('stash', 'evidence_stash_' .. i)
                        else
                            lib.notify({ title = 'Evidence', description = 'Invalid evidence code', type = 'error' })
                        end
                    end, code)
                end,
                canInteract = function()
                    local playerData = QBCore.Functions.GetPlayerData()
                    return playerData.job.name == 'police' and playerData.job.grade.level >= stash.grade
                end
            },
            {
                label = "Evidence Pack",
                sublabel = "Check Pack ID",
                icon = "fa-solid fa-box",
                action = function()
                    local items = exports.ox_inventory:GetPlayerItems()
                    local pack = nil

                    for _, v in pairs(items) do
                        if v.name == 'evidence_pack' then
                            pack = v
                            break
                        end
                    end

                    if not pack then
                        lib.notify({ title = 'Evidence', description = 'You do not have an evidence pack', type = 'error' })
                        return
                    end

                    local packId = pack.metadata and pack.metadata.pack_id

                    if not packId then
                        lib.notify({ title = 'Evidence', description = 'This pack has no ID assigned', type = 'error' })
                        return
                    end

                    exports.ox_inventory:openInventory('stash', packId)
                    exports['CHud']:CNotification(
                        'Pack ID: ' .. packId,
                        "fa-duotone fa-solid fa-box",
                        "#1B4F72",
                        20000
                    )
                end,
                canInteract = function()
                    local playerData = QBCore.Functions.GetPlayerData()
                    return playerData.job.name == 'police' and playerData.job.grade.level >= stash.grade
                end
            },
        }
    }
)
end
end



RegisterNetEvent("CPolice:Client:UseCuffItem", function()
    local model = GetHashKey(Config.Props.cuffs)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local cuff = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)
    AttachEntityToEntity(cuff, playerPed, GetPedBoneIndex(playerPed, 57005),
        0.09, 0.06, 0.0, -6.0, 24.0, -36.0, true, true, false, false, 1, true)
    SetEntityCollision(cuff, false, false)
    SetModelAsNoLongerNeeded(model)
end)

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

CreateThread(function()
    while true do
        Wait(0)
        if isBeingDragged then
            local playerPed = PlayerPedId()
            local draggerPed = GetPlayerPed(GetPlayerFromServerId(dragger))
            AttachEntityToEntity(playerPed, draggerPed, 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
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

local function GetClosestVehicleToCoords(coords)
    local vehicles = GetGamePool('CVehicle')
    local closestVehicle = nil
    local closestDistance = -1
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vehicleCoords = GetEntityCoords(vehicle)
            local distance = #(coords - vehicleCoords)
            if closestDistance == -1 or distance < closestDistance then
                closestVehicle = vehicle
                closestDistance = distance
            end
        end
    end
    return closestVehicle, closestDistance
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
        if GetGameTimer() - startTime > 5000 then return end
    end

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    cuffProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)
    if not DoesEntityExist(cuffProp) then return end

    local cuffConfig = isFrontCuffed and Config.Anims.frontCuff or Config.Anims.backCuff
    local pos = cuffConfig.boneOffset.pos
    local rot = cuffConfig.boneOffset.rot
    local boneIndex = GetPedBoneIndex(playerPed, cuffConfig.attachBone)

    SetEntityCollision(cuffProp, false, false)
    SetEntityAsMissionEntity(cuffProp, true, true)

    AttachEntityToEntity(
        cuffProp, playerPed, boneIndex,
        pos[1], pos[2], pos[3],
        rot[1], rot[2], rot[3],
        false, false, false, false, 2, true
    )

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

local function ejectVehicle(playerPed)
    if IsPedSittingInAnyVehicle(playerPed) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        TaskLeaveVehicle(playerPed, vehicle, 256)
        Wait(2000)
    end
end

local function putInVehicleAsPassenger(playerPed, vehicle)
    if IsEntityAVehicle(vehicle) then
        for i = 1, math.max(GetVehicleMaxNumberOfPassengers(vehicle), 3) do
            if IsVehicleSeatFree(vehicle, i) then
                SetPedIntoVehicle(playerPed, vehicle, i)
                return true
            end
        end
    end
    return false
end

RegisterNetEvent("CPoliceJob:Client:PlayCuffAnim", function(targetServerId, frontCuffed)
    isCuffing = true
    isFrontCuffed = frontCuffed
    
    TriggerServerEvent("InteractSound_SV:PlayWithinDistance", 10.0, "handcuff", 1.0)
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

    if escapedDuringCuff then
        escapedDuringCuff = false
        return
    end

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
    if not value then
        isCuffed = false
        isFrontCuffed = false
    else
        isCuffed = true
        escapedDuringCuff = false

        exports['CHud']:startSliderMinigame({
            speed = 1,
            required = 1,
            maxFaults = 1,
            time = 5,
            onSuccess = function()
                escapedDuringCuff = true
                TriggerServerEvent("CPoliceJob:Server:EscapeCuffs")
                Notify("You broke free from the cuffs!", 4000)

                local ped = PlayerPedId()
                StopAnimTask(ped, Config.Anims.backCuff.dict, Config.Anims.backCuff.name, 1.0)
                StopAnimTask(ped, Config.Anims.frontCuff.dict, Config.Anims.frontCuff.name, 1.0)
                ClearPedTasksImmediately(ped)
                deleteCuffProp()

                SetTimeout(1000, function()
                    if DoesEntityExist(cuffProp) then
                        DetachEntity(cuffProp, true, true)
                        DeleteEntity(cuffProp)
                        cuffProp = 0
                        isCuffVisible = false
                    end
                end)
            end,
            onFail = function()
                Notify("You couldn't break free...", 4000)
            end
        })
    end
end)

RegisterNetEvent("CPoliceJob:Client:Notify", function(text, duration)
    Notify(text, duration)
end)

RegisterNetEvent("CPoliceJob:Client:Drag", function(draggerId)
    isBeingDragged = true
    dragger = draggerId
end)

RegisterNetEvent("CPoliceJob:Client:Undrag", function()
    isBeingDragged = false
    dragger = nil
    ClearPedTasks(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
end)

RegisterNetEvent("CPoliceJob:Client:CheckCuffStatus", function(sourcePlayerId)
    local isHandcuffed = isCuffed
    TriggerServerEvent("CPoliceJob:Server:HandleDragRequest", isHandcuffed, sourcePlayerId)
end)

RegisterNetEvent("CPoliceJob:Client:PutInVehicle", function(vehicleNetId)
    local playerPed = PlayerPedId()
    local vehicle = NetToVeh(vehicleNetId)
    isBeingDragged = false
    dragger = nil
    DetachEntity(playerPed, true, false)
    putInVehicleAsPassenger(playerPed, vehicle)
    if DoesEntityExist(cuffProp) then
        SetEntityVisible(cuffProp, false, false)
    end
end)

RegisterNetEvent("CPoliceJob:Client:TakeOutOfVehicle", function()
    ejectVehicle(PlayerPedId())
    Wait(2100)
    if isCuffed then
        if DoesEntityExist(cuffProp) then
            SetEntityVisible(cuffProp, true, false)
        end
        playIdleCuffAnim()
    end
end)

RegisterCommand("uncuff", function()
    if not isPolice() then return end
    local playerId, distance = GetClosestPlayer(5.0)
    if playerId == -1 then Notify("No one is close to you...", 4000) return end
    local targetServerId = GetPlayerServerId(playerId)
    if not targetServerId or targetServerId <= 0 then return end
    TriggerServerEvent("CPoliceJob:Server:RequestUncuff", targetServerId)
end, false)

RegisterCommand("cuff", function()
    if not isPolice() then return end
    local playerId, distance = GetClosestPlayer(5.0)
    if playerId == -1 then Notify("No one is close to you...", 4000) return end
    local targetServerId = GetPlayerServerId(playerId)
    if not targetServerId or targetServerId <= 0 then return end
    TriggerServerEvent("CPoliceJob:Server:RequestCuff", targetServerId, false)
end, false)

RegisterCommand("frontcuff", function()
    if not isPolice() then return end
    local playerId, distance = GetClosestPlayer(5.0)
    if playerId == -1 then Notify("No one is close to you...", 4000) return end
    local targetServerId = GetPlayerServerId(playerId)
    if not targetServerId or targetServerId <= 0 then return end
    TriggerServerEvent("CPoliceJob:Server:RequestCuff", targetServerId, true)
end, false)

RegisterCommand("drag", function()
    if not isPolice() then return end
    local playerId, distance = GetClosestPlayer(3.0)
    if playerId == -1 then Notify("No one is close to you...", 4000) return end
    local targetServerId = GetPlayerServerId(playerId)
    if not targetServerId or targetServerId <= 0 then return end
    TriggerServerEvent("CPoliceJob:Server:RequestDrag", targetServerId)
end, false)

RegisterCommand("putinvehicle", function()
    if not isPolice() then return end
    local playerCoords = GetEntityCoords(PlayerPedId())
    local playerId, playerDistance = GetClosestPlayer(3.0)
    if playerId == -1 then Notify("No one is close to you...", 4000) return end
    local closestVehicle, vehicleDistance = GetClosestVehicleToCoords(playerCoords)
    if not closestVehicle or vehicleDistance > 5.0 then Notify("No vehicle nearby", 4000) return end
    local targetServerId = GetPlayerServerId(playerId)
    if not targetServerId or targetServerId <= 0 then return end
    local vehicleNetId = VehToNet(closestVehicle)
    TriggerServerEvent("CPoliceJob:Server:PutInVehicle", targetServerId, vehicleNetId)
end, false)

RegisterCommand("outofvehicle", function()
    if not isPolice() then return end
    local playerId, distance = GetClosestPlayer(5.0)
    if playerId == -1 then Notify("No one is close to you...", 4000) return end
    local targetServerId = GetPlayerServerId(playerId)
    if not targetServerId or targetServerId <= 0 then return end
    TriggerServerEvent("CPoliceJob:Server:TakeOutOfVehicle", targetServerId)
end, false)



RegisterNetEvent("CPoliceJob:Client:EscapedCuffs", function()
    isCuffed = false
    isFrontCuffed = false
    isCuffing = false

    local ped = PlayerPedId()
    StopAnimTask(ped, Config.Anims.backCuff.dict, Config.Anims.backCuff.name, 1.0)
    StopAnimTask(ped, Config.Anims.frontCuff.dict, Config.Anims.frontCuff.name, 1.0)
    ClearPedTasks(ped)
    RemoveAnimDict(Config.Anims.backCuff.dict)
    RemoveAnimDict(Config.Anims.frontCuff.dict)
    RemoveAnimDict(Config.Anims.cuffing.criminal.dict)
    RemoveAnimDict(Config.Anims.cuffing.criminalFront.dict)
    deleteCuffProp()

    SetTimeout(500, function()
        if DoesEntityExist(cuffProp) then
            DetachEntity(cuffProp, true, true)
            DeleteEntity(cuffProp)
            cuffProp = 0
            isCuffVisible = false
        end
    end)
end)


RegisterNetEvent("CPoliceJob:Client:SuspectEscaped", function(suspectServerId)
    isCuffing = false
    ClearPedTasks(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
    RemoveAnimDict(Config.Anims.cuffing.officer.dict)
    RemoveAnimDict(Config.Anims.cuffing.officerFront.dict)
    Notify("Your suspect broke free from the cuffs!", 4000)
end)



RegisterKeyMapping("cuff", "Back Cuff Player", "keyboard", "UP")

RegisterKeyMapping("uncuff", "Uncuff Player", "keyboard", "DOWN")

RegisterKeyMapping("frontcuff", "Front Cuff Player", "keyboard", "PERIOD")

RegisterKeyMapping("drag", "Drag/Undrag Player", "keyboard", "LEFT")

RegisterKeyMapping("putinvehicle", "Put Player In Vehicle", "keyboard", "RIGHT")

RegisterKeyMapping("outofvehicle", "Take Player Out Of Vehicle", "keyboard", "RIGHT")
function Notify(text, duration)
    exports['CHud']:CNotification(text, "fa-duotone fa-solid fa-user-police", "#1B4F72", duration or 3000)
end





local keyCodes = {
    ["ESC"] = 322,
    ["F1"] = 288,
    ["F2"] = 289,
    ["F3"] = 170,
    ["F5"] = 166,
    ["F6"] = 167,
    ["F7"] = 168,
    ["F8"] = 169,
    ["F9"] = 56,
    ["F10"] = 57,
    ["~"] = 243,
    ["1"] = 157,
    ["2"] = 158,
    ["3"] = 160,
    ["4"] = 164,
    ["5"] = 165,
    ["6"] = 159,
    ["7"] = 161,
    ["8"] = 162,
    ["9"] = 163,
    ["-"] = 84,
    ["="] = 83,
    ["BACKSPACE"] = 177,
    ["TAB"] = 37,
    ["Q"] = 44,
    ["W"] = 32,
    ["E"] = 38,
    ["R"] = 45,
    ["T"] = 245,
    ["Y"] = 246,
    ["U"] = 303,
    ["P"] = 199,
    ["["] = 39,
    ["]"] = 40,
    ["ENTER"] = 18,
    ["CAPS"] = 137,
    ["A"] = 34,
    ["S"] = 8,
    ["D"] = 9,
    ["F"] = 23,
    ["G"] = 47,
    ["H"] = 74,
    ["K"] = 311,
    ["L"] = 182,
    ["LEFTSHIFT"] = 21,
    ["Z"] = 20,
    ["X"] = 73,
    ["C"] = 26,
    ["V"] = 0,
    ["B"] = 29,
    ["N"] = 249,
    ["M"] = 244,
    [","] = 82,
    ["."] = 81,
    ["LEFTCTRL"] = 36,
    ["LEFTALT"] = 19,
    ["SPACE"] = 22,
    ["RIGHTCTRL"] = 70,
    ["HOME"] = 213,
    ["PAGEUP"] = 10,
    ["PAGEDOWN"] = 11,
    ["DELETE"] = 178,
    ["LEFT"] = 174,
    ["RIGHT"] = 175,
    ["TOP"] = 27,
    ["DOWN"] = 173,
    ["NENTER"] = 201,
    ["N4"] = 108,
    ["N5"] = 60,
    ["N6"] = 107,
    ["N+"] = 96,
    ["N-"] = 97,
    ["N7"] = 117,
    ["N8"] = 61,
    ["N9"] = 118
}
local isTackling = false;
local isBeingTackled = false;
local animDict = "missmic2ig_11"
local animTackled = "mic_2_ig_11_intro_goon"
local animTackler = "mic_2_ig_11_intro_p_one"
local lastTackleTime = 0;

RegisterNetEvent("CPoliceJob:Server:getTackled", function(tacklerServerId)
    isBeingTackled = true;
    local playerPed = PlayerPedId()
    local tacklerPed = GetPlayerPed(GetPlayerFromServerId(tacklerServerId))
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(10)
    end
    AttachEntityToEntity(playerPed, tacklerPed, 11816, 0.25, 0.5, 0.0, 0.5, 0.5, 180.0, false, false, false, false, 2, false)
    TaskPlayAnim(playerPed, animDict, animTackler, 8.0, -8.0, 3000, 0, 0, false, false, false)
    RemoveAnimDict(animDict)
    Citizen.Wait(1500)
    DetachEntity(playerPed, true, false)
    SetPedToRagdoll(playerPed, 2000, 2000, 0, false, false, false)
    Citizen.Wait(3000)
    isBeingTackled = false
end)

RegisterNetEvent("CPoliceJob:Server:playTackle", function()
    local playerPed = PlayerPedId()
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(10)
    end
    TaskPlayAnim(playerPed, animDict, animTackled, 8.0, -8.0, 3000, 0, 0, false, false, false)
    RemoveAnimDict(animDict)
    Citizen.Wait(3000)
    isTackling = false
end)
local function getClosestPlayerServerId()
    local minDistance = 3.0;
    local closestServerId = nil;
    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local serverId = GetPlayerServerId(playerId)
                local playerCoords = GetEntityCoords(GetPlayerPed(playerId), true)
                local distance = #(playerCoords - GetEntityCoords(PlayerPedId()))
                if distance < minDistance then
                    minDistance = distance;
                    closestServerId = serverId
                end
            end
        end
    return closestServerId
end



function func_tackleManagement() -- This is left shift
    if IsControlPressed(0, 21) then
        local PData = QBCore.Functions.GetPlayerData()
        if PData.job.name == "police" and PData.job.onduty then
            if not isTackling and GetGameTimer() - lastTackleTime > 10 * 1000 and GetEntityHealth(PlayerPedId()) > 102 then
                local targetServerId = getClosestPlayerServerId()
                if targetServerId then
                    if not isTackling and not isBeingTackled and not IsPedInAnyVehicle(PlayerPedId()) and
                        not IsPedInAnyVehicle(GetPlayerPed(targetServerId)) then
                        isTackling = true
                        lastTackleTime = GetGameTimer()
                        TriggerServerEvent("CPoliceJob:Server:tryTackle", targetServerId)
                    end
                end
            end
        end
    end
end

RegisterCommand("tackle", function(source, args, rawCommand)
    func_tackleManagement()
end, false)

RegisterKeyMapping('tackle', 'Tackle Player (SHIFT + )', 'keyboard', 'G')








RegisterNUICallback('CPolicejob:Client:ToggleDuty', function(data, cb)
    cb({ success = true })
    print("Received toggle duty")
    TriggerServerEvent("CPolice:Server:ToggleDuty")

end)



RegisterNetEvent('CPolicejob:Client:BossActionResult', function(result)
    if result.success then
        lib.callback('CPolicejob:getAllOfficers', false, function(officers)
            DUI_Send({ type = 'setAllOfficers', data = officers or {} })
        end)
    end
end)


RegisterNetEvent("CPolice:Client:UseEvidenceBag", function(data)
    local slot = data.slot
    local items = exports.ox_inventory:GetPlayerItems()
    local item = nil

    for _, v in pairs(items) do
        if v.slot == slot then
            item = v
            break
        end
    end

    local metadata = item and item.metadata

    if metadata and metadata.stash_id then
        lib.callback('CPolicejob:openEvidenceBagStash', false, function(success)
            if success then
                exports.ox_inventory:openInventory('stash', metadata.stash_id)
            else
                lib.notify({ title = 'Evidence', description = 'Stash unavailable', type = 'error' })
            end
        end, metadata.stash_id)
    else
        TriggerServerEvent("CPolicejob:Server:RegisterEvidenceBagStash", slot)
    end
end)


RegisterNetEvent("CPolice:Client:UseEvidencePack", function(data)
    local slot = data.slot
    local items = exports.ox_inventory:GetPlayerItems()
    local item = nil

    for _, v in pairs(items) do
        if v.slot == slot then
            item = v
            break
        end
    end

    print('[CLIENT] evidence_pack found: ' .. json.encode(item))

    local metadata = item and item.metadata

    if metadata and metadata.pack_id then
        print('[CLIENT] Opening existing pack stash: ' .. metadata.pack_id)
        exports.ox_inventory:openInventory('stash', metadata.pack_id)
    else
        print('[CLIENT] No pack ID, creating new pack stash')
        TriggerServerEvent("CPolicejob:Server:RegisterEvidencePackStash", slot)
    end
end)

RegisterNetEvent("CPolicejob:Client:OpenEvidencePackStash", function(packId)
    exports.ox_inventory:openInventory('stash', packId)
end)

RegisterNetEvent("CPolicejob:Client:OpenEvidenceStash", function(stashId)
    exports.ox_inventory:openInventory('stash', stashId)
end)


AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for i, _ in pairs(Config.Police.toggleDuty) do
        exports['CInteraction']:removeZone(('police_toggle_duty_%s'):format(i))
    end
end)