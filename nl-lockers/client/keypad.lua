-- ═══════════════════════════════════════════════════════════════════════════
--  KEYPAD SYSTEM (Integrated from colbss_keypad)
--  Uses native FiveM DUI API for reliability
-- ═══════════════════════════════════════════════════════════════════════════

local txReplaceDict, txReplaceName = 'ch_prop_casino_keypads', 'prop_ld_keypad'
local keypadCam = nil
local keypadDuiObj = nil
local keypadDuiDictName = nil
local keypadDuiTxtName = nil
local prevButtonID = -1
local codeInput = ''
local currentKeypadCallback = nil
local buttonThreshold = 2.5

-- Define button rotations (relative to initial rotation)
local buttonCamRots = {
    [1] = vec3(-3.52, 0.0, 8.06),
    [2] = vec3(-3.52, 0.0, 2.70),
    [3] = vec3(-3.52, 0.0, -2.58),
    [4] = vec3(-8.56, 0.0, 8.06),
    [5] = vec3(-8.56, 0.0, 2.58),
    [6] = vec3(-8.56, 0.0, -2.64),
    [7] = vec3(-13.48, 0.0, 8.0),
    [8] = vec3(-13.51, 0.0, 2.77),
    [9] = vec3(-13.51, 0.0, -2.7),
    [10] = vec3(-18.0, 0.0, 8.06), -- Cancel
    [11] = vec3(-18.1, 0.0, 2.7), -- 0
    [12] = vec3(-18.2, 0.0, -2.58)  -- #
}

-- ─── DUI Init (native API) ────────────────────────────────────────────────

function CreateKeypadDUI()
    if keypadDuiObj then return end

    local url = ('nui://%s/keypad/ui.html'):format(GetCurrentResourceName())
    keypadDuiObj = CreateDui(url, 512, 1024)

    CreateThread(function()
        -- Wait until the DUI browser reports it is ready
        local timeout = 10000
        while not IsDuiAvailable(keypadDuiObj) and timeout > 0 do
            Wait(100)
            timeout = timeout - 100
        end

        if not IsDuiAvailable(keypadDuiObj) then
            print('^1[nl-lockers] Keypad DUI failed to initialise within 10s^7')
            return
        end

        local handle  = GetDuiHandle(keypadDuiObj)
        local dictName = GetCurrentResourceName() .. '_keypad_dui'
        local txd      = CreateRuntimeTxd(dictName)
        local txtName  = 'keypad_tex'
        CreateRuntimeTextureFromDuiHandle(txd, txtName, handle)

        -- Small extra wait so the HTML page itself finishes rendering before
        -- we apply the texture — this fixes the 'blank on first start' bug
        Wait(1000)

        AddReplaceTexture(txReplaceDict, txReplaceName, dictName, txtName)

        keypadDuiDictName = dictName
        keypadDuiTxtName  = txtName

        SendKeypadDuiMessage({ action = 'KEYPAD', value = true })
        DebugPrint('Keypad DUI ready')
    end)
end

--- Re-apply the texture replacement on a freshly-spawned keypad prop.
--- Call this after CreateObject() so the DUI shows immediately.
function RefreshKeypadTexture()
    if not keypadDuiDictName or not keypadDuiTxtName then return end
    RemoveReplaceTexture(txReplaceDict, txReplaceName)
    AddReplaceTexture(txReplaceDict, txReplaceName, keypadDuiDictName, keypadDuiTxtName)
end

-- Send message to keypad DUI
function SendKeypadDuiMessage(data)
    if not keypadDuiObj then return end
    SendDuiMessage(keypadDuiObj, json.encode(data))
end

-- ─── Prop Creation ────────────────────────────────────────────────────────

function CreateKeypadProp(x, y, z, w)
    local hash = GetHashKey(Config.KeypadProp)
    LoadModel(hash)
    local prop = CreateObject(hash, x, y, z, true, false, false)
    SetEntityHeading(prop, w or 0.0)
    FreezeEntityPosition(prop, true)
    SetModelAsNoLongerNeeded(hash)
    return prop
end

function CalculateInitialCameraRotation(keypadHeading)
    local heading = (keypadHeading + 360.0) % 360.0
    return vec3(0.0, 0.0, heading)
end

-- ─── Open / Close Keypad ──────────────────────────────────────────────────

function OpenKeypad(prop, callback)
    if not DoesEntityExist(prop) then return end

    -- Guard: only one keypad interaction at a time
    if currentKeypadCallback then
        DebugPrint('OpenKeypad called while already open — ignoring')
        return
    end

    currentKeypadCallback = callback
    codeInput = ''

    -- Ensure the DUI texture is applied on this prop
    RefreshKeypadTexture()
    
    local keypadCoords = GetEntityCoords(prop)
    local camOffset = GetOffsetFromEntityInWorldCoords(prop, 0.0, -0.25, 0.0)
    keypadCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(keypadCam, camOffset.x, camOffset.y, camOffset.z)
    local initialRot = CalculateInitialCameraRotation(GetEntityHeading(prop))
    SetCamRot(keypadCam, initialRot.x, initialRot.y, initialRot.z, 2)
    SetCamActive(keypadCam, true)
    RenderScriptCams(true, true, 1000, true, true)
    
    FreezeEntityPosition(cache.ped, true)

    CreateThread(function()
        Wait(1000)
        SendNUIMessage({
            action = 'KEYPAD_MOUSE',
            value = true
        })
    end)

    local camRot = initialRot
    local btnLookingAt = -1

    CreateThread(function()
        while DoesCamExist(keypadCam) and IsCamActive(keypadCam) do
            DisableAllControlActions(0)

            xMouse = GetDisabledControlNormal(0, 1) * 8.0
            yMouse = GetDisabledControlNormal(0, 2) * 8.0
            camRot = vector3(
                math.clamp(camRot.x - yMouse, initialRot.x - 22.0, initialRot.x + 15.0),
                camRot.y,
                math.clamp(camRot.z - xMouse, initialRot.z - 15.0, initialRot.z + 15.0) 
            )
            
            SetCamRot(keypadCam, camRot.x, camRot.y, camRot.z, 2)

            for buttonId, buttonRot in pairs(buttonCamRots) do
                if IsCameraLookingAtButton(camRot, buttonRot, initialRot) then
                    btnLookingAt = buttonId
                end
            end

            if btnLookingAt ~= -1 then 
                HighlightKeypadButton(btnLookingAt)
            else
                HighlightKeypadButton(0)
            end

            if IsDisabledControlJustPressed(0, 24) and btnLookingAt > 0 then
                ClickKeypadButton(btnLookingAt)
            end

            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 177) then
                CloseKeypad(false)
                break
            end

            btnLookingAt = -1
            Wait(0)
        end
    end)
end

function NormalizeAngle(angle)
    return ((angle + 180) % 360) - 180
end

function IsCameraLookingAtButton(camRot, buttonRot, initialRot)
    local relativeRot = vector3(
        NormalizeAngle(camRot.x - initialRot.x), 
        NormalizeAngle(camRot.y - initialRot.y), 
        NormalizeAngle(camRot.z - initialRot.z)
    )
    local deltaX = math.abs(relativeRot.x - buttonRot.x)
    local deltaY = math.abs(relativeRot.y - buttonRot.y)
    local deltaZ = math.abs(relativeRot.z - buttonRot.z)
    return deltaX <= buttonThreshold and deltaY <= buttonThreshold and deltaZ <= buttonThreshold
end

function CloseKeypad(success)
    if DoesCamExist(keypadCam) then
        RenderScriptCams(false, true, 1000, true, true)
        DestroyCam(keypadCam, false)
        keypadCam = nil
    end
    HighlightKeypadButton(0)
    FreezeEntityPosition(cache.ped, false)
    SendNUIMessage({
        action = 'KEYPAD_MOUSE',
        value = false
    })
    
    if currentKeypadCallback then
        currentKeypadCallback(success, codeInput)
        currentKeypadCallback = nil
    end
    
    codeInput = ''
    SendKeypadDuiMessage({
        action = "DISPLAY",
        value = 'ENTER CODE'
    })
end

-- ─── Button Interactions ──────────────────────────────────────────────────

function PlayKeypadSound(sType)
    local sounds = {
        [1] = { name = "Press", ref = "DLC_SECURITY_BUTTON_PRESS_SOUNDS" },
        [2] = { name = "Hack_Fail", ref = "DLC_sum20_Business_Battle_AC_Sounds" },
        [3] = { name = "Keypad_Access", ref = "DLC_Security_Data_Leak_2_Sounds" }
    }
    local sid = GetSoundId()
    PlaySoundFrontend(sid, sounds[sType].name, sounds[sType].ref, 1)
    ReleaseSoundId(sid)
end

function ClickKeypadButton(buttonId)
    PlayKeypadSound(1)

    if ((buttonId > 0 and buttonId < 10) or buttonId == 11) and #codeInput < (Config.MaxCodeLength or 20) then
        if buttonId == 11 then buttonId = 0 end
        codeInput = tostring(codeInput) .. tostring(buttonId)
        SendKeypadDuiMessage({
            action = "DISPLAY",
            value = codeInput
        })
    elseif buttonId == 10 then -- Cancel
        codeInput = ''
        SendKeypadDuiMessage({
            action = "DISPLAY",
            value = 'ENTER CODE'
        })
    elseif buttonId == 12 then -- Submit
        if #codeInput >= 4 then
            PlayKeypadSound(3)
            SendKeypadDuiMessage({
                action = "DISPLAY",
                value = 'PROCESSING'
            })
            Wait(500)
            CloseKeypad(true)
        else
            codeInput = ''
            PlayKeypadSound(2)
            SendKeypadDuiMessage({
                action = "DISPLAY",
                value = 'TOO SHORT'
            })
        end
    end
end

function HighlightKeypadButton(buttonId)
    if prevButtonID ~= buttonId then
        SendKeypadDuiMessage({
            action = "BUTTON",
            value = buttonId
        })
        prevButtonID = buttonId
    end
end

-- ─── Initialize on resource start ─────────────────────────────────────────

CreateThread(function()
    CreateKeypadDUI()
end)

-- ─── Cleanup on resource stop ─────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- Fully close keypad (unfreezes ped, destroys cam, clears callback)
    if currentKeypadCallback or DoesCamExist(keypadCam) then
        if DoesCamExist(keypadCam) then
            RenderScriptCams(false, false, 0, true, true)
            DestroyCam(keypadCam, false)
            keypadCam = nil
        end
        FreezeEntityPosition(cache.ped, false)
        SendNUIMessage({ action = 'KEYPAD_MOUSE', value = false })
        currentKeypadCallback = nil
        codeInput = ''
    end

    if keypadDuiDictName and keypadDuiTxtName then
        RemoveReplaceTexture(txReplaceDict, txReplaceName)
    end
    if keypadDuiObj then
        DestroyDui(keypadDuiObj)
        keypadDuiObj      = nil
        keypadDuiDictName = nil
        keypadDuiTxtName  = nil
    end
end)
