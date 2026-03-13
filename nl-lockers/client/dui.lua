-- ─── DUI State ─────────────────────────────────────────────────────────────
-- The DUI renders the OS interface as a texture on the laptop prop's screen.
-- It uses ?mode=dui so the page knows it's the prop screen, not the NUI overlay.

local _duiObj  = nil
local _txdName = GetCurrentResourceName() .. '_dui'
local _isReady = false

-- ─── Init ──────────────────────────────────────────────────────────────────

---Create the DUI and replace the laptop screen texture. Called once on startup.
function DUI_Init()
    if _duiObj then 
        if Config.Debug then print('[DUI] Already initialized') end
        return 
    end

    if Config.Debug then print('[DUI] Starting initialization...') end

    -- Preload model so AddReplaceTexture registers on the prop correctly
    local hash = GetHashKey(Config.LaptopProp)
    if Config.Debug then print('[DUI] Loading model:', Config.LaptopProp, 'hash:', hash) end
    
    -- Request and wait for model to load
    RequestModel(hash)
    local modelLoadAttempts = 0
    while not HasModelLoaded(hash) and modelLoadAttempts < 100 do
        Wait(10)
        modelLoadAttempts = modelLoadAttempts + 1
    end
    
    if not HasModelLoaded(hash) then
        print('^1[DUI] ERROR: Failed to load model', Config.LaptopProp, '^7')
        return
    end
    
    if Config.Debug then print('[DUI] Model loaded after', modelLoadAttempts * 10, 'ms') end

    -- ?mode=dui tells the page to render the full OS UI (not the capture layer)
    local url = ('https://cfx-nui-%s/nui/index.html?mode=dui'):format(GetCurrentResourceName())
    if Config.Debug then
        url = url .. '&debug=true'
        print('[DUI] Creating DUI with URL:', url)
        print('[DUI] DUI dimensions:', Config.DuiWidth, 'x', Config.DuiHeight)
    end
    
    _duiObj = CreateDui(url, Config.DuiWidth, Config.DuiHeight)
    if Config.Debug then print('[DUI] DUI object created:', _duiObj) end

    CreateThread(function()
        local attempts = 0
        while not IsDuiAvailable(_duiObj) and attempts < 100 do 
            Wait(10)
            attempts = attempts + 1
        end
        
        if not IsDuiAvailable(_duiObj) then
            print('^1[DUI] ERROR: DUI failed to become available after', attempts * 10, 'ms^7')
            return
        end
        
        if Config.Debug then print('[DUI] DUI available after', attempts * 10, 'ms') end

        local handle = GetDuiHandle(_duiObj)
        if Config.Debug then print('[DUI] DUI handle:', handle) end
        
        local txd = CreateRuntimeTxd(_txdName)
        if Config.Debug then print('[DUI] Runtime TXD created:', _txdName, 'ID:', txd) end
        
        local textureId = CreateRuntimeTextureFromDuiHandle(txd, 'screen', handle)
        if Config.Debug then print('[DUI] Runtime texture created from DUI handle, ID:', textureId) end

        -- Apply texture replacement for all possible screen texture names
        if Config.Debug then
            print('[DUI] Applying texture replacements:')
            print('  Model:', Config.LaptopProp)
            print('  Texture Dict:', Config.LaptopTexDict)
            print('  New TXD:', _txdName)
        end
        
        local replacementCount = 0
        for _, textureName in ipairs(Config.LaptopScreenTextures) do
            if Config.Debug then
                print('[DUI] Replacing:', Config.LaptopTexDict, '/', textureName, '->', _txdName, '/screen')
            end
            AddReplaceTexture(Config.LaptopTexDict, textureName, _txdName, 'screen')
            replacementCount = replacementCount + 1
        end
        
        Wait(100)
        
        _isReady = true
        if Config.Debug then
            print('^2[DUI] ✓ Ready — texture replacement active^7')
        end
    end)
end

---@return boolean
function DUI_IsReady()
    return _isReady and _duiObj ~= nil and IsDuiAvailable(_duiObj)
end

-- ─── Messaging ─────────────────────────────────────────────────────────────

---Send a JSON message to the DUI (prop screen render).
---@param data table
function DUI_Send(data)
    if not DUI_IsReady() then 
        if Config.Debug then print('^3[DUI] Warning: Attempted to send message but DUI not ready^7') end
        return 
    end
    if Config.Debug then print('[DUI] Sending message:', json.encode(data)) end
    SendDuiMessage(_duiObj, json.encode(data))
end

---Forward a mouse move event into the DUI via SendDuiMessage.
function DUI_MouseMove(x, y)
    if not DUI_IsReady() then return end
    SendDuiMessage(_duiObj, json.encode({ type='cursor', x=math.floor(x), y=math.floor(y) }))
end

---Forward a mouse button event into the DUI via SendDuiMessage.
function DUI_MouseButton(button, pressed, x, y)
    if not DUI_IsReady() then return end
    SendDuiMessage(_duiObj, json.encode({ type='click', x=math.floor(x), y=math.floor(y), button=button, pressed=pressed }))
end

---Forward a scroll event into the DUI via SendDuiMessage.
function DUI_MouseWheel(x, y, dy)
    if not DUI_IsReady() then return end
    SendDuiMessage(_duiObj, json.encode({ type='scroll', x=math.floor(x), y=math.floor(y), dy=dy }))
end

---Forward a keyboard character or Backspace to the focused DUI input element.
---@param key string  single character or 'Backspace'
function DUI_KeyPress(key)
    if not DUI_IsReady() then return end
    SendDuiMessage(_duiObj, json.encode({ type='key', key=key }))
end

-- ─── Debug Commands ────────────────────────────────────────────────────────

if Config.Debug then
    RegisterCommand('duidebug', function()
        print('═══════════════════════════════════════════════════════════')
        print('[DUI DEBUG] Status Report')
        print('═══════════════════════════════════════════════════════════')
        print('[DUI] Ready:', DUI_IsReady())
        print('[DUI] DUI Object:', _duiObj)
        print('[DUI] TXD Name:', _txdName)
        print('[DUI] Is Available:', _duiObj and IsDuiAvailable(_duiObj) or 'N/A')
        if _duiObj and IsDuiAvailable(_duiObj) then
            print('[DUI] Handle:', GetDuiHandle(_duiObj))
        end
        print('[DUI] Laptop Prop:', Config.LaptopProp)
        print('[DUI] Texture Dict:', Config.LaptopTexDict)
        print('[DUI] Screen Textures:', json.encode(Config.LaptopScreenTextures))
        print('[DUI] Replacement TXD:', _txdName, '-> screen')
        
        local hash = GetHashKey(Config.LaptopProp)
        print('[DUI] Model Hash:', hash)
        print('[DUI] Model Loaded:', HasModelLoaded(hash))
        
        print('═══════════════════════════════════════════════════════════')
    end, false)
end

-- ─── Cleanup ───────────────────────────────────────────────────────────────

function DUI_Destroy()
    if not _duiObj then return end
    DestroyDui(_duiObj)
    _duiObj  = nil
    _isReady = false
end
