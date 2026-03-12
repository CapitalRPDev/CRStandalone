--[[ -- client.lua
local function SendConfigToNUI()
    -- Wait for the DOM to be ready
    Wait(500)
    
    -- Convert Lua table to JSON-like structure that JS can understand
    local configData = {
        lang = Config.lang,
        useVideo = Config.UseVideo,
        videoURL = Config.VideoURL,
        image = Config.Image, 
        useStaffBoxes = Config.UseStaffBoxes,
        staffBoxes = {},
        useInfoBoxes = Config.UseInfoBoxes,
        infoBoxes = {},
        musicFiles = {} -- Initialize empty array
    }
    
    -- Convert staff boxes from Lua format to array format for JS
    for k, v in pairs(Config.StaffBoxes) do
        table.insert(configData.staffBoxes, {
            name = v.name,
            title = v.title,
            image = v.image 
        })
    end
    
    -- Convert info boxes from Lua format to array format for JS
    for k, v in pairs(Config.InformationBoxes) do
        table.insert(configData.infoBoxes, {
            title = v.title,
            content = v.content
        })
    end
    
    -- Process music files
-- Process music files
for k, v in ipairs(Config.MusicFiles) do
    -- Make sure to add the full path with html/music prefix
    -- If the file doesn't already include "music/" in its path, add it
    if not string.find(v, "music/") then
        table.insert(configData.musicFiles, "html/music/" .. v)
    else
        table.insert(configData.musicFiles, "html/" .. v)
    end
end

-- Debug: Print each music file path for verification
for i, file in ipairs(configData.musicFiles) do
    print("Music file " .. i .. ": " .. file)
end
    
    -- Debug: Print what we're sending to verify music files are included
    print("Sending config to NUI with " .. #configData.musicFiles .. " music files")
    
    -- Send config to the NUI (HTML/JS)
    SendNUIMessage({
        type = "loadConfig",
        config = configData
    })
end

-- Register event handler for when the resource starts
RegisterNetEvent('onClientResourceStart')
AddEventHandler('onClientResourceStart', function(resourceName)
    if(GetCurrentResourceName() ~= resourceName) then
        return
    end
    
    -- Display the loading screen
    DisplayHud(false)
    DisplayRadar(false)
    SetNuiFocus(true, true)

    -- Send configuration to the NUI
    SendConfigToNUI()
end)

-- Register NUI callback for when loading is complete
RegisterNUICallback('loadingComplete', function(data, cb)
    -- Hide the loading screen and restore HUD
    DisplayHud(true)
    DisplayRadar(true)
    SetNuiFocus(false, false)
    
    -- Acknowledge the callback
    cb('ok')
end)

-- Register command to test loading screen
--[[ RegisterCommand('testloading', function()
    SendConfigToNUI()
end, false)
 ]]

--[[ CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(500) -- Wait until session starts
    end
    SetNuiFocus(true, true)

    -- Once loaded, send message to the UI to hide loading screen
    SendNUIMessage({
        action = "hideLoadingScreen"
    })
end) ]]

-- In your server.lua or client.lua
--[[ AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    -- Defer the connection while we check for Config.lua
    deferrals.defer()
    
    -- Tell the player we're checking resources
    deferrals.update('Checking config files...')
    
    -- Check if Config.lua exists and load it
    local configExists = LoadResourceFile(GetCurrentResourceName(), "Config.lua")
    
    if configExists then
        -- Config exists, load it
        local config = json.encode(Config) -- Assuming Config is global after loading
        
        -- Send to loading screen
        TriggerEvent('loadingscreen:configLoaded', config)
        
        -- Allow the connection to proceed
        deferrals.done()
    else
        -- Config doesn't exist, you might want to kick the player or use defaults
        deferrals.done('Config.lua not found!')
    end
end) ]]
--[[ 
-- In your loadingscreen resource
RegisterNetEvent('loadingscreen:configLoaded')
AddEventHandler('loadingscreen:configLoaded', function(config)
    -- Send to NUI (your loading screen)
    SendNUIMessage({
        type = 'configLoaded',
        config = config
    })
end) ]] 


local spawn1 = false
AddEventHandler("playerSpawned", function()

    if not spawn1 then
        ShutdownLoadingScreen()
        print("Player has spawned - Shuttind won loading screen")
        spawn1 = true


    end


end)