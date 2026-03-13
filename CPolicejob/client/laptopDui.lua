-- ─── laptopDui.lua ─────────────────────────────────────────────────────────

local _duiObj  = nil
local _txdName = GetCurrentResourceName() .. '_dui'
local _isReady = false
local _spawnedLaptops = {}
-- ═══════════════════════════════════════════════════════════════════════════
--  DUI CORE
-- ═══════════════════════════════════════════════════════════════════════════

local function DUI_Init()
    if _duiObj then return end
    if Config.Debug then print('[DUI] Starting initialization...') end

    local hash = GetHashKey(Config.LaptopProp)
    RequestModel(hash)
    local attempts = 0
    while not HasModelLoaded(hash) and attempts < 100 do
        Wait(10); attempts = attempts + 1
    end
    if not HasModelLoaded(hash) then
        print('^1[DUI] ERROR: Failed to load model ' .. Config.LaptopProp .. '^7')
        return
    end
    if Config.Debug then print('[DUI] Model loaded after ' .. attempts * 10 .. 'ms') end

    local url = ('https://cfx-nui-%s/web/build/index.html?mode=dui'):format(GetCurrentResourceName())
    if Config.Debug then
        url = url .. '&debug=true'
        print('[DUI] URL: ' .. url)
        print('[DUI] Dimensions: ' .. Config.DuiWidth .. 'x' .. Config.DuiHeight)
    end

    _duiObj = CreateDui(url, Config.DuiWidth, Config.DuiHeight)
    if Config.Debug then print('[DUI] DUI object: ' .. tostring(_duiObj)) end

    CreateThread(function()
        local wait = 0
        while not IsDuiAvailable(_duiObj) and wait < 100 do
            Wait(10); wait = wait + 1
        end
        if not IsDuiAvailable(_duiObj) then
            print('^1[DUI] ERROR: DUI failed to become available^7')
            return
        end
        if Config.Debug then print('[DUI] Available after ' .. wait * 10 .. 'ms') end

        local handle = GetDuiHandle(_duiObj)
        local txd    = CreateRuntimeTxd(_txdName)
        CreateRuntimeTextureFromDuiHandle(txd, 'screen', handle)

        for _, texName in ipairs(Config.LaptopScreenTextures) do
            AddReplaceTexture(Config.LaptopTexDict, texName, _txdName, 'screen')
            if Config.Debug then
                print('[DUI] Replaced: ' .. Config.LaptopTexDict .. '/' .. texName .. ' -> ' .. _txdName .. '/screen')
            end
        end

        Wait(100)
        _isReady = true
        if Config.Debug then print('^2[DUI] ✓ Ready^7') end
    end)
end

local function DUI_IsReady()
    return _isReady and _duiObj ~= nil and IsDuiAvailable(_duiObj)
end

local function DUI_Send(data)
    if not DUI_IsReady() then return end
    if Config.Debug then print('[DUI] Sending: ' .. json.encode(data)) end
    SendDuiMessage(_duiObj, json.encode(data))
end

local function DUI_MouseMove(x, y)
    if not DUI_IsReady() then return end
    SendDuiMessage(_duiObj, json.encode({ type = 'cursor', x = math.floor(x), y = math.floor(y) }))
end

local function DUI_MouseButton(button, pressed, x, y)
    if not DUI_IsReady() then return end
    SendDuiMessage(_duiObj, json.encode({ type = 'click', x = math.floor(x), y = math.floor(y), button = button, pressed = pressed }))
end

local function DUI_MouseWheel(x, y, dy)
    if not DUI_IsReady() then return end
    SendDuiMessage(_duiObj, json.encode({ type = 'scroll', x = math.floor(x), y = math.floor(y), dy = dy }))
end

local function DUI_KeyPress(key)
    if not DUI_IsReady() then return end
    if Config.Debug then print('[DUI] KeyPress: ' .. key) end
    SendDuiMessage(_duiObj, json.encode({ type = 'key', key = key }))
end

local function DUI_Destroy()
    if not _duiObj then return end
    DestroyDui(_duiObj)
    _duiObj  = nil
    _isReady = false
end

CreateThread(function() DUI_Init() end)

-- ═══════════════════════════════════════════════════════════════════════════
--  NUI KEY RELAY
--  NUI overlay receives keydown events (SetNuiFocus) and sends here via fetchNui
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNUICallback('duiKey', function(data, cb)
    print('[TESTDUI] duiKey callback fired, key: ' .. tostring(data.key))
    cb('ok')
    if not _testOpen then 
        print('[TESTDUI] duiKey: _testOpen is false, dropping')
        return 
    end
    local key = tostring(data.key or '')
    if key ~= '' then
        if Config.Debug then print('[TESTDUI] Key from NUI: ' .. key) end
        DUI_KeyPress(key)
    end
end)





-- ═══════════════════════════════════════════════════════════════════════════
--  TEST LAPTOP STATE
-- ═══════════════════════════════════════════════════════════════════════════

_testLaptop = nil
_testCam    = nil
_testOpen = false
_cursorX    = 0.5
 _cursorY    = 0.5

-- ═══════════════════════════════════════════════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

local function LoadPropModel(hash)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do
        Wait(10); t = t + 1
    end
    return HasModelLoaded(hash)
end

local function SpawnLaptopInFront()
    local ped     = PlayerPedId()
    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad     = math.rad(heading)

    local spawnPos = vec3(
        coords.x + (-math.sin(rad) * 1.2),
        coords.y + ( math.cos(rad) * 1.2),
        coords.z - 0.85
    )

    local hash = joaat(Config.LaptopProp)
    if not LoadPropModel(hash) then
        print('^1[TESTDUI] Failed to load model: ' .. Config.LaptopProp .. '^7')
        return nil
    end

    local prop = CreateObject(hash, spawnPos.x, spawnPos.y, spawnPos.z, false, true, false)
    SetEntityHeading(prop, heading - 180.0)
    FreezeEntityPosition(prop, true)
    SetEntityInvincible(prop, true)
    SetEntityCollision(prop, true, true)
    SetModelAsNoLongerNeeded(hash)

    print('^2[TESTDUI] Laptop spawned — handle: ' .. tostring(prop) .. '^7')
    return prop
end

-- ═══════════════════════════════════════════════════════════════════════════
--  CAMERA
-- ═══════════════════════════════════════════════════════════════════════════

local function AttachTestCam(prop)
    _testCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    AttachCamToEntity(_testCam, prop, 0.0, -0.65, 0.42, true)
    PointCamAtEntity(_testCam, prop, 0.0, 0.08, 0.05, true)
    SetCamFov(_testCam, 40.0)
    RenderScriptCams(true, true, 600, true, false)
    if Config.Debug then print('[TESTDUI] Camera attached') end
end

local function ReleaseTestCam()
    if not _testCam then return end
    RenderScriptCams(false, true, 400, true, false)
    Wait(400)
    DestroyCam(_testCam, false)
    _testCam = nil
end

-- ═══════════════════════════════════════════════════════════════════════════
--  DUI COORDINATE MAPPING
-- ═══════════════════════════════════════════════════════════════════════════

local function ScreenToDui(nx, ny)
    local b = Config.ScreenBounds
    local w = b.R - b.L; if w <= 0 then w = 0.01 end
    local h = b.B - b.T; if h <= 0 then h = 0.01 end
    local dx = math.clamp((nx - b.L) / w, 0.0, 1.0) * Config.DuiWidth
    local dy = math.clamp((ny - b.T) / h, 0.0, 1.0) * Config.DuiHeight
    return dx, dy
end

-- ═══════════════════════════════════════════════════════════════════════════
--  INTERACTION LOOP
-- ═══════════════════════════════════════════════════════════════════════════

local function StartInteractionLoop()
    CreateThread(function()
        while _testOpen do
            Wait(0)

            DisableControlAction(0, 1,   true)
            DisableControlAction(0, 2,   true)
            DisableControlAction(0, 24,  true)
            DisableControlAction(0, 25,  true)
            DisableControlAction(0, 106, true)
            DisableControlAction(0, 14,  true)
            DisableControlAction(0, 15,  true)

            -- Mouse movement
            local dx = GetDisabledControlNormal(0, 1)
            local dy = GetDisabledControlNormal(0, 2)
            if dx ~= 0.0 or dy ~= 0.0 then
                _cursorX = math.clamp(_cursorX + dx * Config.MouseSensitivity, 0.0, 1.0)
                _cursorY = math.clamp(_cursorY + dy * Config.MouseSensitivity, 0.0, 1.0)
                local duiX, duiY = ScreenToDui(_cursorX, _cursorY)
                DUI_MouseMove(duiX, duiY)
            end

            -- Left click
            if IsDisabledControlJustPressed(0, 24) then
                local duiX, duiY = ScreenToDui(_cursorX, _cursorY)
                DUI_MouseButton(0, true, duiX, duiY)
            end
            if IsDisabledControlJustReleased(0, 24) then
                local duiX, duiY = ScreenToDui(_cursorX, _cursorY)
                DUI_MouseButton(0, false, duiX, duiY)
            end

            -- Right click
            if IsDisabledControlJustPressed(0, 25) then
                local duiX, duiY = ScreenToDui(_cursorX, _cursorY)
                DUI_MouseButton(1, true, duiX, duiY)
            end
            if IsDisabledControlJustReleased(0, 25) then
                local duiX, duiY = ScreenToDui(_cursorX, _cursorY)
                DUI_MouseButton(1, false, duiX, duiY)
            end

            -- Scroll
            local scrollDown = GetDisabledControlNormal(0, 14)
            local scrollUp   = GetDisabledControlNormal(0, 15)
            if scrollDown > 0 or scrollUp > 0 then
                local duiX, duiY = ScreenToDui(_cursorX, _cursorY)
                DUI_MouseWheel(duiX, duiY, (scrollUp > 0) and 1 or -1)
            end

            -- ESC to close
            if IsControlJustPressed(0, 200) then
                CloseTestDui()
                break
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
--  OPEN / CLOSE
-- ═══════════════════════════════════════════════════════════════════════════


RegisterNUICallback('duiEscape', function(_, cb)
    cb('ok')
    if not _testOpen then return end
    CloseTestDui()
end)


local function SpawnLaptopAtCoord(coords, heading)
    local hash = joaat(Config.LaptopProp)
    if not LoadPropModel(hash) then
        print('^1[TESTDUI] Failed to load model: ' .. Config.LaptopProp .. '^7')
        return nil
    end

    local prop = CreateObject(hash, coords.x, coords.y, coords.z, false, true, false)
    SetEntityHeading(prop, heading)
    FreezeEntityPosition(prop, true)
    SetEntityInvincible(prop, true)
    SetEntityCollision(prop, true, true)
    SetModelAsNoLongerNeeded(hash)

    print('^2[TESTDUI] Laptop spawned — handle: ' .. tostring(prop) .. '^7')
    return prop
end

function OpenTestDui()
    if _testOpen then CloseTestDui() return end

    if not DUI_IsReady() then
        print('^3[TESTDUI] DUI not ready yet^7')
        return
    end

    -- Find nearest laptop coord
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local nearest, nearestDist = nil, math.huge
    for _, v4 in pairs(Config.LaptopCoords) do
        local dist = #(pedCoords - vec3(v4.x, v4.y, v4.z))
        if dist < nearestDist then
            nearest = v4
            nearestDist = dist
        end
    end

    if not nearest then return end

    _testLaptop = SpawnLaptopAtCoord(vec3(nearest.x, nearest.y, nearest.z), nearest.w)
    if not _testLaptop then return end

    Wait(150)
    _testOpen = true
    _cursorX  = 0.5
    _cursorY  = 0.5

    SetNuiFocus(true, false)
    AttachTestCam(_testLaptop)
    DUI_Send({ type = 'open', locker = nil, ui = {} })

    Wait(300)
    DUI_Send({ type = 'setCorrectLoginDetails', data = { username = '2043T', password = 'admin' } })

    print('^2[TESTDUI] Open^7')
    StartInteractionLoop()
end

function CloseTestDui()
    if not _testOpen then return end
    _testOpen = false

    -- Release NUI keyboard focus
    SetNuiFocus(false, false)

    DUI_Send({ type = 'close' })
    ReleaseTestCam()

    if _testLaptop and DoesEntityExist(_testLaptop) then
        SetEntityAsMissionEntity(_testLaptop, true, true)
        DeleteObject(_testLaptop)
    end
    _testLaptop = nil

    print('^2[TESTDUI] Closed^7')
end

-- ═══════════════════════════════════════════════════════════════════════════
--  COMMANDS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('testdui', function()
    if _testOpen then CloseTestDui() else OpenTestDui() end
end, false)

if Config.Debug then
    RegisterCommand('duidebug', function()
        print('═══════════════════════════════════════════')
        print('[DUI] Ready:        ' .. tostring(DUI_IsReady()))
        print('[DUI] Object:       ' .. tostring(_duiObj))
        print('[DUI] TXD:          ' .. _txdName)
        print('[DUI] Available:    ' .. tostring(_duiObj and IsDuiAvailable(_duiObj) or false))
        print('[DUI] Prop:         ' .. Config.LaptopProp)
        print('[DUI] TexDict:      ' .. Config.LaptopTexDict)
        print('[DUI] Textures:     ' .. json.encode(Config.LaptopScreenTextures))
        print('[DUI] Model loaded: ' .. tostring(HasModelLoaded(GetHashKey(Config.LaptopProp))))
        print('═══════════════════════════════════════════')
    end, false)
end

-- ═══════════════════════════════════════════════════════════════════════════
--  CLEANUP
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    CloseTestDui()
    DUI_Destroy()
end)