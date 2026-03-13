-- Framework functions (FW_*) are provided by client/framework.lua, loaded first in fxmanifest.

-- ═══════════════════════════════════════════════════════════════════════════
--  HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

local function RotationToDirection(rotation)
    local adjustedRotation = vec3(
        (math.pi / 180) * rotation.x,
        (math.pi / 180) * rotation.y,
        (math.pi / 180) * rotation.z
    )
    local direction = vec3(
        -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.sin(adjustedRotation.x)
    )
    return direction
end

local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════════════════════

local lockerData    = {}  -- [id] = { id, label, coords, price, available, owner, has_code }
local lockerTargets = {}  -- [id] = ox_target zone id
local keypadProps   = {}  -- [id] = prop handle

local insideLocker    = nil   -- locker id we're currently inside, or nil
local insidePrevPos   = nil   -- coords before teleporting in
local exitZone        = nil   -- ox_target zone id for exit door
local stashZones      = {}    -- active stash ox_target zone ids
local upgradeProps    = {}    -- spawned upgrade crate entities
local upgradeZones    = {}    -- ox_target ids on upgrade crate entities
local laptopObj       = nil   -- spawned laptop prop handle
local laptopTargetId  = nil   -- ox_target id on laptop

local isLaptopOpen    = false
local isLaptopTyping  = false  -- true while NUI has keyboard focus for DUI input
local cursorX         = 0.5
local cursorY         = 0.5
local scriptCam       = nil

-- ═══════════════════════════════════════════════════════════════════════════
--  DUI INIT
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function() DUI_Init() end)

-- Open storage (no fade, no sound — those only happen on locker entry)
local function openStorageWithEffect(stashId)
    Inv_OpenStash(stashId)
end

-- Debug: /testsound — test sound playback via NUI and DUI
RegisterCommand('testsound', function()
    local soundFile = Config.StorageOpenSound or 'sound/garagesound.ogg'
    print('[SOUND] Testing sound via NUI: ' .. soundFile)
    SendNUIMessage({ action = 'playStorageSound', file = soundFile, volume = 0.7 })
    print('[SOUND] Testing sound via DUI: ' .. soundFile)
    DUI_Send({ type = 'playSound', file = soundFile, volume = 0.7 })
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
--  LOCKER TARGETS — Create ox_target sphere zones at locker locations
-- ═══════════════════════════════════════════════════════════════════════════

local function spawnKeypadProp(lockerId, data)
    if not data.keypad then return end

    -- Remove old prop if exists
    if keypadProps[lockerId] and DoesEntityExist(keypadProps[lockerId]) then
        DeleteEntity(keypadProps[lockerId])
    end

    local kpHash = GetHashKey(Config.KeypadProp)
    if not IsModelInCdimage(kpHash) then
        DebugPrint('Keypad model not found in cdimage: ' .. Config.KeypadProp)
        return
    end
    LoadModel(kpHash)
    if not HasModelLoaded(kpHash) then
        DebugPrint('Failed to load keypad model: ' .. Config.KeypadProp)
        return
    end
    -- Networked prop (required by ox_target:addLocalEntity)
    -- It is deleted before entering the locker bucket and re-spawned on exit.
    local prop = CreateObject(kpHash, data.keypad.coords.x, data.keypad.coords.y, data.keypad.coords.z, true, false, false)
    SetEntityHeading(prop, data.keypad.heading or 0.0)
    FreezeEntityPosition(prop, true)
    SetModelAsNoLongerNeeded(kpHash)

    if not prop or prop == 0 then return end
    keypadProps[lockerId] = prop

    -- Prevent GTA streaming from culling this prop when the player moves away
    SetEntityAsMissionEntity(prop, true, true)

    -- Re-apply DUI texture so newly spawned prop shows the keypad UI immediately
    RefreshKeypadTexture()

    -- Add ox_target to keypad
    exports.ox_target:addLocalEntity(prop, {
        {
            name = 'keypad_locker_' .. lockerId,
            icon = data.available and 'fas fa-lock-open' or 'fas fa-lock',
            label = data.available
                and ('Set Your Password — $' .. (data.price or Config.DefaultPrice))
                or 'Enter Password',
            onSelect = function()
                if data.available then
                    rentLockerViaKeypad(lockerId, data)
                else
                    enterLockerViaKeypad(lockerId, data)
                end
            end,
            distance = 1.5
        }
    })
end

local function removeAllKeypadProps()
    for id, prop in pairs(keypadProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    keypadProps = {}
end

local function createLockerTarget(data)
    if not data or not data.id or not data.coords then return end

    -- Remove old target
    if lockerTargets[data.id] then
        pcall(function() exports.ox_target:removeZone(lockerTargets[data.id]) end)
        lockerTargets[data.id] = nil
    end

    local options = {}

    if data.available then
        options[#options + 1] = {
            icon     = 'fa-solid fa-lock-open',
            label    = ('Set Your Password — $%s'):format(data.price or Config.DefaultPrice),
            onSelect = function()
                rentLockerViaKeypad(data.id, data)
            end,
            distance = Config.TargetDistance,
        }
    else
        options[#options + 1] = {
            icon     = 'fa-solid fa-lock',
            label    = 'Enter Password',
            onSelect = function()
                enterLockerViaKeypad(data.id, data)
            end,
            distance = Config.TargetDistance,
        }
    end

    local ok, result = pcall(function()
        return exports.ox_target:addSphereZone({
            coords  = data.coords,
            radius  = Config.TargetDistance,
            debug   = Config.Debug,
            options = options,
        })
    end)

    if ok and result then
        lockerTargets[data.id] = result
    else
        print('^1[nl-lockers] ERROR creating target for locker #' .. data.id .. ': ' .. tostring(result) .. '^7')
    end
end

local function removeAllTargets()
    for id, zoneId in pairs(lockerTargets) do
        pcall(function() exports.ox_target:removeZone(zoneId) end)
    end
    lockerTargets = {}
end

local function rebuildAllTargets()
    removeAllTargets()
    removeAllKeypadProps()
    for id, data in pairs(lockerData) do
        createLockerTarget(data)
        if data.keypad then
            spawnKeypadProp(id, data)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  RENT LOCKER VIA KEYPAD
-- ═══════════════════════════════════════════════════════════════════════════

function rentLockerViaKeypad(lockerId, data)
    if not keypadProps[lockerId] or not DoesEntityExist(keypadProps[lockerId]) then
        FW_Notify('Keypad not found', 'error')
        return
    end
    
    -- Update DUI display to show password setup mode
    SendKeypadDuiMessage({ action = 'DISPLAY', value = 'SET PASSWORD' })
    
    OpenKeypad(keypadProps[lockerId], function(success, code)
        if success and code and #code >= 4 then
            TriggerServerEvent('nl-lockers:rent', lockerId, code)
        else
            FW_Notify('Cancelled', 'error')
            SendKeypadDuiMessage({ action = 'DISPLAY', value = 'ENTER CODE' })
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
--  ENTER LOCKER VIA KEYPAD
-- ═══════════════════════════════════════════════════════════════════════════

function enterLockerViaKeypad(lockerId, data)
    if insideLocker then return end
    
    if not keypadProps[lockerId] or not DoesEntityExist(keypadProps[lockerId]) then
        FW_Notify('Keypad not found', 'error')
        return
    end
    
    -- If locker has a code, require keypad entry
    if data.has_code then
        OpenKeypad(keypadProps[lockerId], function(success, code)
            if success and code then
                doEnterLocker(lockerId, code)
            else
                FW_Notify('Access cancelled', 'error')
            end
        end)
    else
        -- No code required
        doEnterLocker(lockerId, nil)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  ENTER LOCKER (direct, no code required)
-- ═══════════════════════════════════════════════════════════════════════════

function doEnterLocker(lockerId, code)
    FW_TriggerCallback('nl-lockers:canEnter', function(allowed, reason)
        if not allowed then
            FW_Notify(reason or L('no_access'), 'error')
            return
        end

        local ped = PlayerPedId()
        insidePrevPos = GetEntityCoords(ped)

        -- Play garage sound when entering locker
        local soundFile = Config.StorageOpenSound or 'sound/garagesound.ogg'
        SendNUIMessage({ action = 'playStorageSound', file = soundFile, volume = 0.7 })

        DoScreenFadeOut(500)
        Wait(600)

        -- Delete the keypad prop before entering so the networked entity
        -- doesn't follow the player into the private routing bucket
        if keypadProps[lockerId] then
            pcall(function() exports.ox_target:removeLocalEntity(keypadProps[lockerId]) end)
            if DoesEntityExist(keypadProps[lockerId]) then
                SetEntityAsMissionEntity(keypadProps[lockerId], true, true)
                DeleteEntity(keypadProps[lockerId])
            end
            keypadProps[lockerId] = nil
        end

        -- Move to private routing bucket before teleporting
        TriggerServerEvent('nl-lockers:enterBucket', lockerId)
        Wait(200)

        SetEntityCoords(ped, Config.Interior.coords.x, Config.Interior.coords.y, Config.Interior.coords.z, false, false, false, false)
        SetEntityHeading(ped, Config.Interior.heading)
        insideLocker = lockerId

        Wait(500)
        DoScreenFadeIn(500)

        FW_Notify(L('entered_locker', lockerId), 'success')

        createInteriorZones(lockerId)
    end, lockerId, code)
end

-- ═══════════════════════════════════════════════════════════════════════════
--  INTERIOR ZONES — Exit door, stashes, laptop
-- ═══════════════════════════════════════════════════════════════════════════

function createInteriorZones(lockerId)
    cleanupInteriorZones()

    -- Exit door
    exitZone = exports.ox_target:addBoxZone({
        coords   = Config.ExitDoor.coords,
        size     = Config.ExitDoor.size,
        rotation = Config.ExitDoor.rotation,
        debug    = Config.Debug,
        options  = {
            {
                icon     = 'fa-solid fa-door-open',
                label    = 'Exit Locker',
                onSelect = function() exitLocker() end,
                distance = Config.TargetDistance,
            },
        },
    })

    -- Stash zones
    if Config.Stashes then
        for _, stash in ipairs(Config.Stashes) do
            local stashId = ('locker_%d_%s'):format(lockerId, stash.name)
            local zoneId = exports.ox_target:addBoxZone({
                coords   = stash.coords,
                size     = stash.size,
                rotation = stash.rotation or 0.0,
                debug    = Config.Debug,
                options  = {
                    {
                        icon     = 'fa-solid fa-box-open',
                        label    = stash.label,
                        onSelect = function()
                            openStorageWithEffect(stashId)
                        end,
                        distance = Config.TargetDistance,
                    },
                },
            })
            stashZones[#stashZones + 1] = zoneId
        end
    end

    -- Upgrade crate props — request upgrade_level then spawn props
    FW_TriggerCallback('nl-lockers:getUpgradeLevel', function(upgradeLevel)
        if not upgradeLevel or upgradeLevel < 1 then return end
        for i = 1, upgradeLevel do
            spawnUpgradeCrate(lockerId, i)
        end
    end, lockerId)

    -- Laptop prop
    spawnLaptop(lockerId)
end

function cleanupInteriorZones()
    -- Exit zone
    if exitZone then
        pcall(function() exports.ox_target:removeZone(exitZone) end)
        exitZone = nil
    end

    -- Stash zones
    for _, zoneId in ipairs(stashZones) do
        pcall(function() exports.ox_target:removeZone(zoneId) end)
    end
    stashZones = {}

    -- Upgrade crate props + targets
    for _, tid in ipairs(upgradeZones) do
        pcall(function() exports.ox_target:removeZone(tid) end)
    end
    upgradeZones = {}
    for _, ent in ipairs(upgradeProps) do
        if DoesEntityExist(ent) then
            SetEntityAsMissionEntity(ent, true, true)
            DeleteEntity(ent)
        end
    end
    upgradeProps = {}

    -- Laptop
    destroyLaptop()
end

-- ═══════════════════════════════════════════════════════════════════════════
--  UPGRADE CRATE PROPS — Spawn crate at interior location with stash target
-- ═══════════════════════════════════════════════════════════════════════════

function spawnUpgradeCrate(lockerId, level)
    local upg = Config.StorageUpgrades[level]
    if not upg then return end

    local hash = GetHashKey(upg.prop)
    if not IsModelInCdimage(hash) then
        print('^1[nl-lockers] Upgrade crate model not found: ' .. upg.prop .. '^7')
        return
    end
    LoadModel(hash)
    if not HasModelLoaded(hash) then
        print('^1[nl-lockers] Failed to load upgrade crate model: ' .. upg.prop .. '^7')
        return
    end

    local loc = upg.loc
    local prop = CreateObject(hash, loc.x, loc.y, loc.z, false, true, false)
    SetEntityHeading(prop, loc.w)
    FreezeEntityPosition(prop, true)
    SetEntityInvincible(prop, true)
    SetEntityCollision(prop, true, true)
    SetEntityAsMissionEntity(prop, true, true)
    SetModelAsNoLongerNeeded(hash)

    if not prop or prop == 0 then return end

    upgradeProps[#upgradeProps + 1] = prop

    -- Add ox_target on the crate prop entity
    local stashId = ('locker_%d_upgrade_%d'):format(lockerId, level)
    local targetId = exports.ox_target:addLocalEntity(prop, {
        {
            icon     = 'fa-solid fa-box-open',
            label    = upg.label,
            distance = Config.TargetDistance,
            onSelect = function()
                openStorageWithEffect(stashId)
            end,
        },
    })
    upgradeZones[#upgradeZones + 1] = targetId
end

-- Server triggers this after a successful upgrade purchase
RegisterNetEvent('nl-lockers:spawnUpgradeProp', function(lockerId, level)
    if insideLocker == lockerId then
        spawnUpgradeCrate(lockerId, level)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
--  EXIT LOCKER
-- ═══════════════════════════════════════════════════════════════════════════

function exitLocker()
    if not insideLocker then return end

    local lockerId = insideLocker  -- save before any state is cleared

    -- Close laptop if open
    if isLaptopOpen then closeLaptop() end

    DoScreenFadeOut(500)
    Wait(600)

    local ped = PlayerPedId()

    -- Teleport back to the real world position WHILE still in the private bucket.
    -- The player is invisible to bucket-0 players until exitBucket fires,
    -- so they will appear at the correct street position instead of the interior.
    if insidePrevPos then
        SetEntityCoords(ped, insidePrevPos.x, insidePrevPos.y, insidePrevPos.z, false, false, false, false)
    end

    -- NOW switch back to the public bucket — player appears at street coords for everyone
    TriggerServerEvent('nl-lockers:exitBucket')
    Wait(300)

    cleanupInteriorZones()

    insideLocker  = nil
    insidePrevPos = nil

    Wait(400)
    DoScreenFadeIn(500)

    -- Re-spawn the keypad prop (it was deleted before entering the bucket)
    if lockerData[lockerId] and lockerData[lockerId].keypad then
        spawnKeypadProp(lockerId, lockerData[lockerId])
    end

    FW_Notify(L('left_locker'), 'success')
end

-- ═══════════════════════════════════════════════════════════════════════════
--  LAPTOP — Spawn, interact, camera, DUI mouse
-- ═══════════════════════════════════════════════════════════════════════════

function spawnLaptop(lockerId)
    destroyLaptop()

    local hash = joaat(Config.LaptopProp)
    LoadModel(hash)

    local c = Config.LaptopCoords
    laptopObj = CreateObject(hash, c.x, c.y, c.z, false, true, false)
    SetEntityHeading(laptopObj, Config.LaptopHeading)
    FreezeEntityPosition(laptopObj, true)
    SetEntityInvincible(laptopObj, true)
    SetEntityCollision(laptopObj, true, true)
    
    if Config.Debug then
        print('[LAPTOP] Spawned laptop prop:', laptopObj, 'at', c)
        print('[LAPTOP] Model hash:', hash, 'Entity model:', GetEntityModel(laptopObj))
    end
    
    Wait(200)
    
    if Config.Debug then print('[LAPTOP] Laptop ready for interaction') end

    laptopTargetId = exports.ox_target:addLocalEntity(laptopObj, {
        {
            label    = 'Use Storage Manager',
            icon     = 'fas fa-laptop',
            distance = Config.TargetDistance,
            onSelect = function()
                if isLaptopOpen then return end
                openLaptop(lockerId)
            end,
        },
    })
end

function destroyLaptop()
    if laptopTargetId and laptopObj then
        pcall(function() exports.ox_target:removeLocalEntity(laptopObj, laptopTargetId) end)
        laptopTargetId = nil
    end
    if laptopObj and DoesEntityExist(laptopObj) then
        SetEntityAsMissionEntity(laptopObj, true, true)
        DeleteObject(laptopObj)
    end
    laptopObj = nil
end

-- ─── Camera ────────────────────────────────────────────────────────────────

local function attachCam(prop)
    scriptCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    AttachCamToEntity(scriptCam, prop, 0.0, -0.65, 0.42, true)
    PointCamAtEntity(scriptCam, prop, 0.0, 0.08, 0.05, true)
    SetCamFov(scriptCam, 40.0)
    RenderScriptCams(true, true, 600, true, false)
end

local function releaseCam()
    if not scriptCam then return end
    RenderScriptCams(false, true, 400, true, false)
    Wait(400)
    DestroyCam(scriptCam, false)
    scriptCam = nil
end

-- ─── DUI coordinate mapping ────────────────────────────────────────────────

local function screenToDui(nx, ny)
    local b = Config.ScreenBounds
    local w = b.R - b.L; if w <= 0 then w = 0.01 end
    local h = b.B - b.T; if h <= 0 then h = 0.01 end
    local dx = math.clamp((nx - b.L) / w, 0.0, 1.0) * Config.DuiWidth
    local dy = math.clamp((ny - b.T) / h, 0.0, 1.0) * Config.DuiHeight
    return dx, dy
end

-- ─── Raw mouse input loop ──────────────────────────────────────────────────

local function startMouseLoop()
    CreateThread(function()
        while isLaptopOpen do
            Wait(0)
            DisableControlAction(0, 1, true)   -- Mouse X
            DisableControlAction(0, 2, true)   -- Mouse Y
            DisableControlAction(0, 24, true)  -- Left Click
            DisableControlAction(0, 25, true)  -- Right Click
            DisableControlAction(0, 106, true) -- VEH_MOUSE_CONTROL_OVERRIDE
            DisableControlAction(0, 14, true)  -- Scroll Down (weapon wheel next)
            DisableControlAction(0, 15, true)  -- Scroll Up (weapon wheel prev)

            local dx = GetDisabledControlNormal(0, 1)
            local dy = GetDisabledControlNormal(0, 2)

            if dx ~= 0.0 or dy ~= 0.0 then
                cursorX = math.clamp(cursorX + dx * Config.MouseSensitivity, 0.0, 1.0)
                cursorY = math.clamp(cursorY + dy * Config.MouseSensitivity, 0.0, 1.0)
                local duiX, duiY = screenToDui(cursorX, cursorY)
                DUI_MouseMove(duiX, duiY)
            end

            -- Left click
            if IsDisabledControlJustPressed(0, 24) then
                local duiX, duiY = screenToDui(cursorX, cursorY)
                DUI_MouseButton(0, true, duiX, duiY)
            end
            if IsDisabledControlJustReleased(0, 24) then
                local duiX, duiY = screenToDui(cursorX, cursorY)
                DUI_MouseButton(0, false, duiX, duiY)
            end

            -- Right click
            if IsDisabledControlJustPressed(0, 25) then
                local duiX, duiY = screenToDui(cursorX, cursorY)
                DUI_MouseButton(1, true, duiX, duiY)
            end
            if IsDisabledControlJustReleased(0, 25) then
                local duiX, duiY = screenToDui(cursorX, cursorY)
                DUI_MouseButton(1, false, duiX, duiY)
            end

            -- Scroll wheel (14=down, 15=up) — use GetDisabledControlNormal for reliable capture
            local scrollDown = GetDisabledControlNormal(0, 14)
            local scrollUp   = GetDisabledControlNormal(0, 15)
            if scrollDown > 0 or scrollUp > 0 then
                local duiX, duiY = screenToDui(cursorX, cursorY)
                local dy = (scrollUp > 0) and 1 or -1
                DUI_MouseWheel(duiX, duiY, dy)
            end

            -- ESC to close laptop (only when not typing — Escape while typing blurs)
            if not isLaptopTyping and IsControlJustPressed(0, 200) then
                closeLaptop()
                break  -- Exit the loop immediately
            end
        end
    end)
end



-- ─── Open / Close Laptop ───────────────────────────────────────────────────

function openLaptop(lockerId)
    if Config.Debug then
        print('[LAPTOP] openLaptop called, lockerId:', lockerId)
        print('[LAPTOP] isLaptopOpen:', isLaptopOpen, 'laptopObj:', laptopObj)
        print('[LAPTOP] DUI ready:', DUI_IsReady())
    end
    
    if isLaptopOpen or not laptopObj then 
        if Config.Debug then print('[LAPTOP] Cannot open - already open or no laptop object') end
        return 
    end

    isLaptopOpen = true
    cursorX = 0.5
    cursorY = 0.5

    if Config.Debug then print('[LAPTOP] Attaching camera to laptop') end
    attachCam(laptopObj)

    -- Request locker info from server, then send to DUI
    if Config.Debug then print('[LAPTOP] Requesting locker info from server...') end
    FW_TriggerCallback('nl-lockers:laptop:getInfo', function(info)
        if Config.Debug then print('[LAPTOP] Received locker info:', json.encode(info or {})) end
        local ui = (Config.LaptopUI and (Config.LaptopUI.accent or Config.LaptopUI.currency)) and Config.LaptopUI or {}
        if info then
            if Config.Debug then print('[LAPTOP] Sending open message to DUI with locker data') end
            DUI_Send({ type = 'open', locker = info, ui = ui })
        else
            if Config.Debug then print('[LAPTOP] Sending open message to DUI without locker data') end
            DUI_Send({ type = 'open', locker = nil, ui = ui })
        end
    end, lockerId)

    if Config.Debug then print('[LAPTOP] Starting mouse loop') end
    startMouseLoop()
end

function closeLaptop()
    if not isLaptopOpen then return end
    isLaptopOpen = false
    
    -- Force clear typing state and NUI focus
    if isLaptopTyping then
        isLaptopTyping = false
        SendNUIMessage({ action = 'laptopTyping', value = false })
    end
    
    SetNuiFocus(false, false)  -- Clear NUI focus
    DUI_Send({ type = 'close' })
    releaseCam()
end

-- ═══════════════════════════════════════════════════════════════════════════
--  ADMIN: Zone selector + NUI panel
-- ═══════════════════════════════════════════════════════════════════════════

local zoneSelecting = false

local function rotationToDirection(rotation)
    local adj = vec3(
        (math.pi / 180) * rotation.x,
        (math.pi / 180) * rotation.y,
        (math.pi / 180) * rotation.z
    )
    return vec3(
        -math.sin(adj.z) * math.cos(adj.x),
         math.cos(adj.z) * math.cos(adj.x),
         math.sin(adj.x)
    )
end

local function raycastFromCamera(distance)
    local camRot   = GetGameplayCamRot()
    local camCoord = GetGameplayCamCoord()
    local dir      = rotationToDirection(camRot)
    local dest     = camCoord + dir * distance
    local ray = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, dest.x, dest.y, dest.z, 17, PlayerPedId(), 7)
    local _, hit, endCoords, surfaceNormal = GetShapeTestResult(ray)
    return hit, endCoords, surfaceNormal or vector3(0, 0, 1)
end

local function normalToRotation(normal)
    local x = math.deg(math.asin(-normal.y))
    local y = math.deg(math.asin(normal.x))
    local z = 0.0
    if math.abs(normal.z) < 0.5 then
        z = math.deg(math.atan(normal.y, normal.x)) - 90.0
        x = 90.0
    end
    return vec3(x, y, z)
end

local function drawZonePreview(coords, normal, col, radius)
    -- Calculate rotation from surface normal
    local rot = normalToRotation(normal)
    
    -- Draw flat rectangular zone on the surface (the actual interaction area)
    -- This represents the ox_target sphere zone projected onto the surface
    local zoneSize = radius * 2
    DrawMarker(43,
        coords.x + normal.x * 0.01,
        coords.y + normal.y * 0.01,
        coords.z + normal.z * 0.01,
        0, 0, 0,
        rot.x, rot.y, rot.z,
        zoneSize, zoneSize, 0.05,
        col[1], col[2], col[3], 150,
        false, false, 2, false, nil, nil, false)
    
    -- Draw border outline of the interaction zone
    local halfSize = radius
    local right = vector3(math.cos(math.rad(rot.z)), math.sin(math.rad(rot.z)), 0)
    local up = vector3(0, 0, 1)
    
    -- Calculate corner points of the zone quad
    local corners = {
        coords + right * halfSize + up * halfSize,
        coords - right * halfSize + up * halfSize,
        coords - right * halfSize - up * halfSize,
        coords + right * halfSize - up * halfSize,
    }
    
    -- Draw border lines
    for i = 1, 4 do
        local next = (i % 4) + 1
        DrawLine(
            corners[i].x, corners[i].y, corners[i].z,
            corners[next].x, corners[next].y, corners[next].z,
            col[1], col[2], col[3], 255
        )
    end
    
    -- Draw center point marker
    DrawMarker(28, coords.x, coords.y, coords.z,
        0, 0, 0, 0, 0, 0, 0.1, 0.1, 0.1,
        255, 255, 255, 255,
        false, false, 2, false, nil, nil, false)
    
    -- Draw coordinate text above the zone
    if Config.Debug then
        local textPos = coords + vector3(0, 0, radius + 0.5)
        local onScreen, _x, _y = GetScreenCoordFromWorldCoord(textPos.x, textPos.y, textPos.z)
        if onScreen then
            SetTextScale(0.35, 0.35)
            SetTextFont(4)
            SetTextProportional(1)
            SetTextColour(255, 255, 255, 255)
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(true)
            AddTextComponentString(('Zone: %.1fm radius\nX: %.1f Y: %.1f Z: %.1f'):format(radius, coords.x, coords.y, coords.z))
            DrawText(_x, _y)
        end
    end
end

local zoneClickCommandRegistered = false

-- Calculate right and up vectors from surface normal using proper cross products
local function calculateSurfaceAxes(surfaceNormal)
    local worldUp = vector3(0, 0, 1)
    
    -- Calculate right vector: cross(worldUp, surfaceNormal)
    local right = vector3(
        worldUp.y * surfaceNormal.z - worldUp.z * surfaceNormal.y,
        worldUp.z * surfaceNormal.x - worldUp.x * surfaceNormal.z,
        worldUp.x * surfaceNormal.y - worldUp.y * surfaceNormal.x
    )
    
    -- Normalize right vector
    local rightLen = math.sqrt(right.x * right.x + right.y * right.y + right.z * right.z)
    if rightLen < 0.001 then
        -- Surface is horizontal, use alternative
        right = vector3(1, 0, 0)
    else
        right = right / rightLen
    end
    
    -- Calculate up vector: cross(surfaceNormal, right)
    local up = vector3(
        surfaceNormal.y * right.z - surfaceNormal.z * right.y,
        surfaceNormal.z * right.x - surfaceNormal.x * right.z,
        surfaceNormal.x * right.y - surfaceNormal.y * right.x
    )
    
    -- Normalize up vector
    local upLen = math.sqrt(up.x * up.x + up.y * up.y + up.z * up.z)
    up = up / upLen
    
    return right, up
end

-- Project a 3D point onto a plane defined by a point and normal
local function projectOntoPlane(point, planePoint, planeNormal)
    local diff = point - planePoint
    local distance = diff.x * planeNormal.x + diff.y * planeNormal.y + diff.z * planeNormal.z
    return point - planeNormal * distance
end

-- Calculate distance along a vector
local function distanceAlongVector(from, to, direction)
    local diff = to - from
    return diff.x * direction.x + diff.y * direction.y + diff.z * direction.z
end

-- Draw solid rectangle with both winding orders to prevent culling
local function drawSolidRectangle(pt1, pt2, pt3, pt4, r, g, b, a)
    -- First winding order
    DrawPoly(pt1.x, pt1.y, pt1.z, pt2.x, pt2.y, pt2.z, pt3.x, pt3.y, pt3.z, r, g, b, a)
    DrawPoly(pt1.x, pt1.y, pt1.z, pt3.x, pt3.y, pt3.z, pt4.x, pt4.y, pt4.z, r, g, b, a)
    
    -- Reversed winding order (prevents invisible from other angles)
    DrawPoly(pt1.x, pt1.y, pt1.z, pt3.x, pt3.y, pt3.z, pt2.x, pt2.y, pt2.z, r, g, b, a)
    DrawPoly(pt1.x, pt1.y, pt1.z, pt4.x, pt4.y, pt4.z, pt3.x, pt3.y, pt3.z, r, g, b, a)
end

-- Draw 3D text at world position
local function draw3DText(x, y, z, text)
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

local function selectPoint()
    zoneSelecting = true
    _G.zoneSelectingActive = true
    local result = nil
    local startCoords = nil
    local surfaceNormal = nil
    local rightVector = nil
    local upVector = nil
    local isDragging = false
    local isMouseDown = false

    lib.showTextUI('[LMB] Click on Surface to Start  \n[ESC] Cancel', { position = 'left-center' })

    while zoneSelecting do
        Wait(0)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisablePlayerFiring(cache.playerId, true)

        -- Get current raycast hit
        local hit, currentCoords, normal = raycastFromCamera(50.0)

        -- STATE: IDLE HOVER (Pre-click cursor)
        if not isDragging then
            if hit and currentCoords then
                -- Draw blue cursor sphere at hover point
                DrawMarker(28, currentCoords.x, currentCoords.y, currentCoords.z, 
                    0, 0, 0, 0, 0, 0, 
                    0.1, 0.1, 0.1, 
                    0, 150, 255, 200, 
                    false, false, 2, false, nil, nil, false)
            end

            -- Initiate drag on LMB press
            if IsDisabledControlJustPressed(0, 24) and hit and currentCoords and normal then
                startCoords = currentCoords
                surfaceNormal = normal
                rightVector, upVector = calculateSurfaceAxes(surfaceNormal)
                isDragging = true
                isMouseDown = true
                lib.showTextUI('[LMB] Drag to Define Zone  \n[Release] Confirm', { position = 'left-center' })
            end
        end

        -- STATE: DRAGGING (Drawing rectangle)
        if isDragging and startCoords and surfaceNormal then
            -- Track button state
            local buttonPressed = IsDisabledControlPressed(0, 24)
            
            -- Button was released (was down, now not pressed)
            if isMouseDown and not buttonPressed then
                -- Finalize the zone
                if hit and currentCoords then
                    -- Project final position onto plane
                    local projectedCoords = projectOntoPlane(currentCoords, startCoords, surfaceNormal)
                    
                    -- Calculate final distances
                    local distX = distanceAlongVector(startCoords, projectedCoords, rightVector)
                    local distY = distanceAlongVector(startCoords, projectedCoords, upVector)
                    
                    -- Calculate the 4 corners
                    local pt1 = startCoords
                    local pt3 = startCoords + rightVector * distX + upVector * distY
                    
                    -- Calculate exact center point between pt1 and pt3
                    local centerCoords = vector3(
                        (pt1.x + pt3.x) / 2,
                        (pt1.y + pt3.y) / 2,
                        (pt1.z + pt3.z) / 2
                    )
                    
                    -- Strict dimension mapping for upright wall zone
                    local width = math.abs(distX)    -- Horizontal distance along wall (X)
                    local depth = 0.5                -- Small thickness perpendicular to wall (Y)
                    local height = math.abs(distY)   -- Vertical distance up wall (Z)
                    
                    -- Calculate heading from surface normal
                    local heading = math.deg(math.atan2(surfaceNormal.y, surfaceNormal.x))
                    
                    -- Validate minimum size
                    if width < 0.1 or height < 0.1 then
                        FW_Notify('Zone too small. Minimum 0.1m x 0.1m', 'error')
                        PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                    else
                        -- Output ox_lib zone code
                        print('^2========== OX_LIB ZONE CODE ==========^7')
                        print('local zone = lib.zones.box({')
                        print(string.format('    coords = vec3(%.2f, %.2f, %.2f),', centerCoords.x, centerCoords.y, centerCoords.z))
                        print(string.format('    size = vec3(%.2f, %.2f, %.2f),', width, depth, height))
                        print(string.format('    rotation = %.2f,', heading))
                        print('    debug = true,')
                        print('    distance = 2.0,')
                        print('    inside = function()')
                        print('        -- Player is inside zone')
                        print('    end,')
                        print('    onExit = function()')
                        print('        -- Player exited zone')
                        print('    end')
                        print('})')
                        print('^2======================================^7')
                        print(string.format('^3Zone: %.2fm (W) x %.2fm (D) x %.2fm (H)^7', width, depth, height))
                        print(string.format('^3Center: %.2f, %.2f, %.2f^7', centerCoords.x, centerCoords.y, centerCoords.z))

                        -- Alternative: ox_target format
                        print('^2========== OX_TARGET ZONE CODE ==========^7')
                        print('local zone = exports.ox_target:addBoxZone({')
                        print(string.format('    coords = vec3(%.2f, %.2f, %.2f),', centerCoords.x, centerCoords.y, centerCoords.z))
                        print(string.format('    size = vec3(%.2f, %.2f, %.2f),', width, depth, height))
                        print(string.format('    rotation = %.2f,', heading))
                        print('    debug = true,')
                        print('    options = {')
                        print('        {')
                        print('            icon = "fa-solid fa-hand",')
                        print('            label = "Interact",')
                        print('            distance = 2.0,')
                        print('            onSelect = function()')
                        print('                -- Interaction code')
                        print('            end')
                        print('        }')
                        print('    }')
                        print('})')
                        print('^2==========================================^7')

                        result = { coords = centerCoords, normal = surfaceNormal }
                        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                        zoneSelecting = false  -- Exit the loop after successful creation
                    end
                end
                
                -- Exit dragging state
                isDragging = false
                startCoords = nil
                surfaceNormal = nil
                isMouseDown = false
                
                -- Only show hover UI again if we're still selecting (zone was too small)
                if zoneSelecting then
                    lib.showTextUI('[LMB] Click on Surface to Start  \n[ESC] Cancel', { position = 'left-center' })
                end
            elseif buttonPressed then
                -- Button is still pressed - continue dragging
                isMouseDown = true
                
                -- Draw the rectangle
                if hit and currentCoords then
                    -- Project current position onto the surface plane
                    local projectedCoords = projectOntoPlane(currentCoords, startCoords, surfaceNormal)
                    
                    -- Calculate distances along surface axes
                    local distX = distanceAlongVector(startCoords, projectedCoords, rightVector)
                    local distY = distanceAlongVector(startCoords, projectedCoords, upVector)
                    
                    -- Calculate the 4 perfect corners
                    local pt1 = startCoords
                    local pt2 = startCoords + rightVector * distX
                    local pt3 = startCoords + rightVector * distX + upVector * distY
                    local pt4 = startCoords + upVector * distY
                    
                    -- Offset slightly from surface to prevent z-fighting
                    local offset = surfaceNormal * 0.01
                    pt1 = pt1 + offset
                    pt2 = pt2 + offset
                    pt3 = pt3 + offset
                    pt4 = pt4 + offset
                    
                    -- Draw solid semi-transparent blue rectangle
                    drawSolidRectangle(pt1, pt2, pt3, pt4, 0, 150, 255, 100)
                    
                    -- Draw blue cursor indicator at dragged corner (pt3)
                    DrawMarker(28, pt3.x, pt3.y, pt3.z, 0, 0, 0, 0, 0, 0, 
                        0.1, 0.1, 0.1, 0, 150, 255, 200, false, false, 2, false, nil, nil, false)
                    
                    -- Calculate center point
                    local center = (pt1 + pt3) / 2
                    
                    -- Draw live size display
                    local absWidth = math.abs(distX)
                    local absHeight = math.abs(distY)
                    local textPos = center + surfaceNormal * 0.3
                    draw3DText(textPos.x, textPos.y, textPos.z, 
                        string.format('Size: %.2fm x %.2fm', absWidth, absHeight))
                end
            end
        end

        -- Cancel with ESC
        if IsDisabledControlJustPressed(0, 200) then
            DisableControlAction(0, 200, true)  -- prevent ESC opening pause menu
            result = nil
            zoneSelecting = false
            PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
        end
    end

    lib.hideTextUI()
    _G.zoneSelectingActive = false
    return result
end

-- ─── /managelockers command ─────────────────────────────────────────────────

RegisterCommand('managelockers', function()
    TriggerServerEvent('nl-lockers:admin:requestData')
    Wait(200)
    SendNUIMessage({ action = 'showAdmin' })
    SetNuiFocus(true, true)
end, false)



-- ═══════════════════════════════════════════════════════════════════════════
--  NUI CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

-- Admin: close panel
RegisterNUICallback('closeUI', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Admin: zone picker + keypad gizmo, then create locker
RegisterNUICallback('admin:pickZone', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')

    -- Step 1: Select locker zone
    lib.showTextUI('[INFO] Select Locker Zone Location', { position = 'top-center' })
    local result = selectPoint()
    lib.hideTextUI()

    if not result then
        SendNUIMessage({ action = 'showAdmin' })
        SetNuiFocus(true, true)
        FW_Notify(L('cancelled'), 'error')
        return
    end

    local lockerCoords = result.coords or result

    -- Step 2: Smart wall-snapping keypad placement
    local kpHash = GetHashKey(Config.KeypadProp)
    if not IsModelInCdimage(kpHash) then
        FW_Notify('Keypad model not found: ' .. Config.KeypadProp, 'error')
        SendNUIMessage({ action = 'showAdmin' })
        SetNuiFocus(true, true)
        return
    end
    LoadModel(kpHash)
    if not HasModelLoaded(kpHash) then
        FW_Notify('Failed to load keypad model', 'error')
        SendNUIMessage({ action = 'showAdmin' })
        SetNuiFocus(true, true)
        return
    end
    
    -- Create keypad prop
    local keypadProp = CreateObject(kpHash, lockerCoords.x, lockerCoords.y, lockerCoords.z + 1.0, false, false, false)
    SetEntityCollision(keypadProp, false, false)
    SetEntityAlpha(keypadProp, 150, false)
    SetModelAsNoLongerNeeded(kpHash)

    if not keypadProp or keypadProp == 0 or not DoesEntityExist(keypadProp) then
        FW_Notify('Failed to create keypad prop', 'error')
        SendNUIMessage({ action = 'showAdmin' })
        SetNuiFocus(true, true)
        return
    end

    -- Ultra-smart automatic placement system with perfect wall alignment
    lib.showTextUI('[Look Around] Auto-snap  [E] Cycle Rotation  [ENTER] Confirm  [ESC] Cancel', { position = 'top-center' })
    
    local placing = true
    local cancelled = false
    local maxRayDistance = 5.0
    local lastValidPlacement = nil
    
    -- Rotation mode for testing different axis configurations
    local rotationMode = 0 -- 0, 1, 2, 3 = 0°, 90°, 180°, 270°
    local rotationModeNames = { "0°", "90°", "180°", "270°" }
    
    -- Get keypad model dimensions for precise placement
    local modelMin, modelMax = GetModelDimensions(kpHash)
    local keypadWidth = math.abs(modelMax.x - modelMin.x)
    local keypadHeight = math.abs(modelMax.z - modelMin.z)
    local keypadDepth = math.abs(modelMax.y - modelMin.y)
    
    -- Calculate proper wall offset using model depth
    -- The hitCoords is on the wall surface
    -- We need to offset by the keypad's depth so the BACK sits on the wall
    -- and the FRONT sticks out
    local wallOffset = keypadDepth * 0.5 + 0.005 -- Half depth plus small clearance
    
    while placing do
        Wait(0)
        
        -- Get camera info
        local camCoords = GetGameplayCamCoord()
        local camRot = GetGameplayCamRot(2)
        local camForward = RotationToDirection(camRot)
        
        -- Cast ray from camera to find nearest surface
        local rayEnd = camCoords + (camForward * maxRayDistance)
        local rayHandle = StartShapeTestRay(
            camCoords.x, camCoords.y, camCoords.z,
            rayEnd.x, rayEnd.y, rayEnd.z,
            -1, -- Hit everything
            cache.ped,
            7 -- Precise test
        )
        
        local _, hit, hitCoords, surfaceNormal, materialHash, entityHit = GetShapeTestResult(rayHandle)
        
        if hit == 1 and surfaceNormal and hitCoords then
            -- Normalize the surface normal vector
            local normalLength = math.sqrt(surfaceNormal.x^2 + surfaceNormal.y^2 + surfaceNormal.z^2)
            if normalLength > 0 then
                surfaceNormal = vec3(
                    surfaceNormal.x / normalLength,
                    surfaceNormal.y / normalLength,
                    surfaceNormal.z / normalLength
                )
            end
            
            -- Determine surface type
            local surfaceAngle = math.abs(surfaceNormal.z)
            local isWall = surfaceAngle < 0.5 -- Vertical surface
            local isFloor = surfaceNormal.z > 0.7
            local isCeiling = surfaceNormal.z < -0.7
            
            -- Position keypad flush against the surface
            local placementPos = vec3(
                hitCoords.x + (surfaceNormal.x * wallOffset),
                hitCoords.y + (surfaceNormal.y * wallOffset),
                hitCoords.z + (surfaceNormal.z * wallOffset)
            )
            
            -- Simple and robust: Calculate heading from wall normal
            -- The surface normal points away from the wall
            
            -- Calculate heading so keypad faces away from wall
            local heading = GetHeadingFromVector_2d(-surfaceNormal.x, -surfaceNormal.y)
            
            -- Apply model-specific axis correction based on rotation mode
            local correctionAngles = { 0.0, 90.0, 180.0, 270.0 }
            heading = heading + correctionAngles[rotationMode + 1]
            
            -- Normalize heading to 0-360
            while heading < 0.0 do
                heading = heading + 360.0
            end
            while heading >= 360.0 do
                heading = heading - 360.0
            end
            
            -- DEBUG: Print values
            print("=== KEYPAD PLACEMENT DEBUG ===")
            print(string.format("Rotation Mode: %s", rotationModeNames[rotationMode + 1]))
            print(string.format("Hit Position: %.3f, %.3f, %.3f", hitCoords.x, hitCoords.y, hitCoords.z))
            print(string.format("Surface Normal: %.3f, %.3f, %.3f", surfaceNormal.x, surfaceNormal.y, surfaceNormal.z))
            print(string.format("Calculated Heading: %.2f", heading))
            print(string.format("Placement Pos: %.3f, %.3f, %.3f", placementPos.x, placementPos.y, placementPos.z))
            print("==============================")
            
            -- Apply position and rotation (keep keypad upright)
            SetEntityCoords(keypadProp, placementPos.x, placementPos.y, placementPos.z, false, false, false, false)
            SetEntityRotation(keypadProp, 0.0, 0.0, heading, 2, true)
            
            -- Visual feedback
            if isWall then
                SetEntityAlpha(keypadProp, 230, false)
                lastValidPlacement = { pos = placementPos, heading = heading }
            elseif isFloor or isCeiling then
                SetEntityAlpha(keypadProp, 150, false)
            else
                SetEntityAlpha(keypadProp, 200, false)
                lastValidPlacement = { pos = placementPos, heading = heading }
            end
            
            -- Draw visual guides
            DrawMarker(
                28,
                hitCoords.x, hitCoords.y, hitCoords.z,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                0.03, 0.03, 0.03,
                isWall and 0 or 255, isWall and 255 or 100, 0, 200,
                false, false, 2, false, nil, nil, false
            )
            
            -- Draw surface normal
            local normalEnd = hitCoords + (surfaceNormal * 0.2)
            DrawLine(
                hitCoords.x, hitCoords.y, hitCoords.z,
                normalEnd.x, normalEnd.y, normalEnd.z,
                isWall and 0 or 255, isWall and 255 or 100, 0, 200
            )
            
            -- Show hints for non-ideal surfaces
            if not isWall then
                if isFloor then
                    DrawText3D(placementPos.x, placementPos.y, placementPos.z + 0.15, '~o~Floor detected~s~\n~w~Aim at a wall')
                elseif isCeiling then
                    DrawText3D(placementPos.x, placementPos.y, placementPos.z - 0.15, '~o~Ceiling detected~s~\n~w~Aim at a wall')
                end
            end
            
        else
            -- No surface detected
            local farPos = camCoords + (camForward * 100.0)
            SetEntityCoords(keypadProp, farPos.x, farPos.y, farPos.z, false, false, false, false)
            SetEntityAlpha(keypadProp, 50, false)
            
            local searchPos = camCoords + (camForward * 2.0)
            DrawText3D(searchPos.x, searchPos.y, searchPos.z, '~r~No surface detected~s~\n~w~Look at a wall')
        end
        
        -- Cycle rotation mode
        if IsControlJustPressed(0, 38) then -- E key
            rotationMode = (rotationMode + 1) % 4
            FW_Notify('Rotation: ' .. rotationModeNames[rotationMode + 1], 'info')
        end
        
        -- Confirm placement
        if IsControlJustPressed(0, 191) then -- ENTER
            if lastValidPlacement then
                -- Set final position and rotation
                SetEntityCoords(keypadProp, lastValidPlacement.pos.x, lastValidPlacement.pos.y, lastValidPlacement.pos.z, false, false, false, false)
                SetEntityRotation(keypadProp, 0.0, 0.0, lastValidPlacement.heading, 2, true)
                placing = false
            else
                FW_Notify('Aim at a wall to place the keypad', 'error')
            end
        end
        
        -- Cancel placement
        if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 177) then -- ESC
            placing = false
            cancelled = true
        end
    end
    
    lib.hideTextUI()
    
    if cancelled then
        if DoesEntityExist(keypadProp) then
            DeleteEntity(keypadProp)
        end
        FW_Notify('Keypad placement cancelled', 'error')
        SendNUIMessage({ action = 'showAdmin' })
        SetNuiFocus(true, true)
        return
    end
    
    -- Finalize placement
    SetEntityAlpha(keypadProp, 255, false)
    SetEntityCollision(keypadProp, true, true)
    FreezeEntityPosition(keypadProp, true)
    local finalPos = GetEntityCoords(keypadProp)
    local finalHeading = GetEntityHeading(keypadProp)

    if DoesEntityExist(keypadProp) then
        SetEntityAsMissionEntity(keypadProp, true, true)
        DeleteEntity(keypadProp)
    end

    -- Step 3: Send coords back to NUI — panel reopens with inline form
    SendNUIMessage({
        action = 'showCreateInline',
        coords = { x = tonumber(lockerCoords.x), y = tonumber(lockerCoords.y), z = tonumber(lockerCoords.z) },
        keypad = {
            x = tonumber(finalPos.x),
            y = tonumber(finalPos.y),
            z = tonumber(finalPos.z),
            h = tonumber(finalHeading)
        }
    })
    SetNuiFocus(true, true)
end)

-- Admin: confirm create (after inline form is filled)
RegisterNUICallback('admin:confirmCreate', function(data, cb)
    TriggerServerEvent('nl-lockers:admin:create', {
        label  = data.label or 'Locker',
        coords = data.coords,
        price  = tonumber(data.price) or Config.DefaultPrice,
        keypad = data.keypad
    })
    cb('ok')
    
    -- Wait for server to process, then refresh admin panel
    CreateThread(function()
        Wait(500)
        TriggerServerEvent('nl-lockers:admin:requestData')
        Wait(300)
        SendNUIMessage({ action = 'showAdmin' })
        SetNuiFocus(true, true)
    end)
end)


-- Admin: delete locker
RegisterNUICallback('admin:delete', function(data, cb)
    TriggerServerEvent('nl-lockers:admin:delete', tonumber(data.id))
    cb('ok')
end)



-- ═══════════════════════════════════════════════════════════════════════════
--  LAPTOP DUI CALLBACKS (from DUI via SendDuiMessage → NUI fetch bridge)
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNUICallback('laptop:openStorage', function(_, cb)
    if not insideLocker then cb('err') return end
    local firstStash = Config.Stashes and Config.Stashes[1]
    if firstStash then
        local stashId = ('locker_%d_%s'):format(insideLocker, firstStash.name)
        openStorageWithEffect(stashId)
    end
    cb('ok')
end)

RegisterNUICallback('laptop:upgrade', function(data, cb)
    if not insideLocker then cb('err') return end
    TriggerServerEvent('nl-lockers:laptop:upgrade', insideLocker)
    cb('ok')
end)

RegisterNUICallback('laptop:setCode', function(data, cb)
    if not insideLocker then cb('err') return end
    TriggerServerEvent('nl-lockers:laptop:setCode', insideLocker, data.code)
    cb('ok')
end)

RegisterNUICallback('laptop:addInvite', function(data, cb)
    if not insideLocker then cb('err') return end
    TriggerServerEvent('nl-lockers:laptop:addInvite', insideLocker, data.citizenid)
    cb('ok')
end)

RegisterNUICallback('laptop:removeInvite', function(data, cb)
    if not insideLocker then cb('err') return end
    TriggerServerEvent('nl-lockers:laptop:removeInvite', insideLocker, data.citizenid)
    cb('ok')
end)

RegisterNUICallback('laptop:renew', function(data, cb)
    if not insideLocker then cb('err') return end
    TriggerServerEvent('nl-lockers:laptop:renew', insideLocker, data and data.days or nil)
    cb('ok')
end)

-- User clicked an input field/button in the DUI → show GTA's native on-screen
-- keyboard (works 100% reliably, no NUI focus tricks needed).
-- ─── Keyboard relay: click input in DUI → NUI captures keys → DUI gets them ─

-- Step 1: DUI tells Lua an input was clicked → give NUI keyboard focus
RegisterNUICallback('laptop:inputFocused', function(_, cb)
    cb('ok')
    if not isLaptopOpen then return end
    isLaptopTyping = true
    
    -- Give NUI overlay keyboard events without showing any cursor overlay
    SetNuiFocus(true, false)
    
    -- Tell NUI JS to start capturing and relaying keydown events
    SendNUIMessage({ action = 'laptopTyping', value = true })
end)

-- Step 2: NUI JS sends each typed character here → forward to DUI
RegisterNUICallback('laptop:keyPress', function(data, cb)
    cb('ok')
    if not isLaptopTyping then return end
    local key = tostring(data.key or '')
    if key ~= '' then
        DUI_KeyPress(key)
    end
end)

-- Step 3: Enter/Escape in NUI JS (or DUI sends submit) → restore focus
RegisterNUICallback('laptop:inputDone', function(_, cb)
    cb('ok')
    isLaptopTyping = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'laptopTyping', value = false })
end)

RegisterNUICallback('laptop:close', function(_, cb)
    closeLaptop()
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════════════════
--  SYNC EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Only accept sync from our own resource (server); reject if another resource triggered this (anti-cheat)
local function isSyncAllowed()
    local inv = GetInvokingResource()
    if not inv or inv == '' then return true end
    return inv == GetCurrentResourceName()
end

RegisterNetEvent('nl-lockers:sync', function(data)
    if not isSyncAllowed() then return end
    lockerData = data or {}

    -- Clear existing zones and props first
    removeAllTargets()
    removeAllKeypadProps()

    -- Build targets incrementally (yield every 5) to avoid single-frame freeze
    -- when a server has many lockers
    CreateThread(function()
        local count = 0
        for id, locker in pairs(lockerData) do
            createLockerTarget(locker)
            if locker.keypad then
                spawnKeypadProp(id, locker)
            end
            count = count + 1
            if count % 5 == 0 then Wait(0) end
        end
    end)

    DebugPrint('Synced ' .. TableLength(lockerData) .. ' lockers')
end)

-- ── Keypad prop watchdog ─────────────────────────────────────────────────────
-- GTA streaming can cull networked props when the player moves far away.
-- This thread re-spawns any missing props for lockers within 150 m.
CreateThread(function()
    while true do
        Wait(5000)
        if not lockerData then goto continue end

        local ped = cache.ped
        if not ped or not DoesEntityExist(ped) then goto continue end
        local playerPos = GetEntityCoords(ped)

        for lockerId, data in pairs(lockerData) do
            if data.keypad then
                local kp   = data.keypad.coords
                local dist = #(playerPos - vector3(kp.x, kp.y, kp.z))

                -- Only care about lockers within streaming range
                if dist < 150.0 then
                    local existing = keypadProps[lockerId]
                    if not existing or not DoesEntityExist(existing) then
                        DebugPrint(('Keypad prop for locker #%d missing — re-spawning'):format(lockerId))
                        spawnKeypadProp(lockerId, data)
                    end
                end
            end
        end

        ::continue::
    end
end)

RegisterNetEvent('nl-lockers:added', function(data)
    if not isSyncAllowed() then return end
    lockerData[data.id] = data
    createLockerTarget(data)
    if data.keypad then
        spawnKeypadProp(data.id, data)
    end
    DebugPrint('Locker #' .. data.id .. ' added')
end)

RegisterNetEvent('nl-lockers:removed', function(lockerId)
    if not isSyncAllowed() then return end
    lockerData[lockerId] = nil
    -- Remove keypad prop
    if keypadProps[lockerId] and DoesEntityExist(keypadProps[lockerId]) then
        DeleteEntity(keypadProps[lockerId])
    end
    keypadProps[lockerId] = nil
    -- Remove target zone
    if lockerTargets[lockerId] then
        pcall(function() exports.ox_target:removeZone(lockerTargets[lockerId]) end)
        lockerTargets[lockerId] = nil
    end
    DebugPrint('Locker #' .. lockerId .. ' removed')
end)

RegisterNetEvent('nl-lockers:updated', function(data)
    if not isSyncAllowed() then return end
    lockerData[data.id] = data
    createLockerTarget(data)
    if data.keypad then
        spawnKeypadProp(data.id, data)
    end
    DebugPrint('Locker #' .. data.id .. ' updated')
end)

-- Admin panel data
RegisterNetEvent('nl-lockers:admin:data', function(data)
    if not isSyncAllowed() then return end
    SendNUIMessage({ action = 'adminData', lockers = data })
end)

-- ═══════════════════════════════════════════════════════════════════════════
--  CLEANUP
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isLaptopOpen then closeLaptop() end
    -- Reset routing bucket in case player is inside a locker when resource stops
    if insideLocker then
        TriggerServerEvent('nl-lockers:exitBucket')
    end
    cleanupInteriorZones()
    removeAllKeypadProps()
    removeAllTargets()
    DUI_Destroy()
end)


-- ═══════════════════════════════════════════════════════════════════════════
--  DEBUG COMMANDS
-- ═══════════════════════════════════════════════════════════════════════════

if Config.Debug then
    RegisterCommand('laptopdebug', function()
        print('═══════════════════════════════════════════════════════════')
        print('[LAPTOP DEBUG] Status Report')
        print('═══════════════════════════════════════════════════════════')
        print('[LAPTOP] Laptop Object:', laptopObj)
        print('[LAPTOP] Laptop Exists:', laptopObj and DoesEntityExist(laptopObj) or false)
        if laptopObj and DoesEntityExist(laptopObj) then
            local coords = GetEntityCoords(laptopObj)
            print('[LAPTOP] Laptop Coords:', coords)
            print('[LAPTOP] Laptop Heading:', GetEntityHeading(laptopObj))
            print('[LAPTOP] Laptop Model:', GetEntityModel(laptopObj))
        end
        print('[LAPTOP] Is Open:', isLaptopOpen)
        print('[LAPTOP] Inside Locker:', insideLocker)
        print('[LAPTOP] DUI Ready:', DUI_IsReady())
        print('═══════════════════════════════════════════════════════════')
    end, false)
end
