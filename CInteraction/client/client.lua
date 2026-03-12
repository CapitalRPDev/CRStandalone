local activeInteraction = false
local selectedIndex = 1
local currentOptions = {}
local hideOnSelect = true

local function showInteraction(options, shouldHide)
    activeInteraction = true
    selectedIndex = 1
    currentOptions = options
    hideOnSelect = shouldHide ~= false

    local sendOptions = {}
    for _, opt in ipairs(options) do
        sendOptions[#sendOptions+1] = {
            label = opt.label,
            sublabel = opt.sublabel,
            icon = opt.icon
        }
    end

    SendReactMessage('show3DInteraction', {
        options = sendOptions,
        selectedIndex = selectedIndex
    })
end

local function hideInteraction()
    activeInteraction = false
    currentOptions = {}
    print("^2[CInteraction]^7 Hiding interaction")
    SendReactMessage('hide3DInteraction', {})
end

RegisterCommand("testinteraction", function()
    showInteraction({
        { label = "Rob ATM", sublabel = "Steal the cash", icon = "fa-money-bill", action = function()
            print("Robbing ATM!")
        end},
        { label = "Check Balance", sublabel = "View your funds", icon = "fa-eye", action = function()
            print("Checking balance!")
        end},
    })
end, false)

CreateThread(function()
    Wait(1000)
    SendReactMessage('setVisible', true)
end)

local function scrollInteraction(direction)
    if not activeInteraction then return end
    selectedIndex = selectedIndex + direction
    if selectedIndex < 1 then selectedIndex = #currentOptions end
    if selectedIndex > #currentOptions then selectedIndex = 1 end

    local sendOptions = {}
    for _, opt in ipairs(currentOptions) do
        sendOptions[#sendOptions+1] = {
            label = opt.label,
            sublabel = opt.sublabel,
            icon = opt.icon
        }
    end

    SendReactMessage('update3DInteraction', {
        options = sendOptions,
        selectedIndex = selectedIndex
    })
end

local zone = lib.zones.box({
    coords = vector3(200.4, -934.1, 29.4),
    size = vector3(5.0, 5.0, 5.0),
    rotation = 0.0,
    debug = true,
    onEnter = function()
        print("entered")
        showInteraction({
            { label = "Rob ATM", sublabel = "Steal the cash", icon = "fa-money-bill", action = function()
                hideInteraction()
                print("Robbing ATM!")
            end},
            { label = "Check Balance", sublabel = "View your funds", icon = "fa-eye", action = function()
                hideInteraction()
                print("Checking balance!")
            end},
        })
    end,
    onExit = function()
        hideInteraction()
    end
})

CreateThread(function()
    while true do
        Wait(0)
        if activeInteraction then
            DisableControlAction(0, 14, true)
            DisableControlAction(0, 15, true)
            DisableControlAction(0, 38, true)

            if IsDisabledControlJustPressed(0, 14) then
                scrollInteraction(-1)
            elseif IsDisabledControlJustPressed(0, 15) then
                scrollInteraction(1)
            elseif IsDisabledControlJustPressed(0, 38) then
                local selected = currentOptions[selectedIndex]
                if hideOnSelect then
                    activeInteraction = false
                    currentOptions = {}
                    SendReactMessage('hide3DInteraction', false)
                    Wait(100)
                end
                if selected and selected.action then
                    selected.action()
                end
            end
        else
            Wait(500)
        end
    end
end)

exports('showInteraction', showInteraction)
exports('hideInteraction', hideInteraction)

exports('createZone', function(coords, size, options)
    local zone = lib.zones.box({
        coords = coords,
        size = size,
        rotation = 0.0,
        debug = Config.Debug,
        onEnter = function()
            if options.onEnter then
                options.onEnter()
            end
            if options.prompts then
                local filtered = {}
                for _, prompt in ipairs(options.prompts) do
                    if not prompt.canInteract or prompt.canInteract() then
                        filtered[#filtered + 1] = prompt
                    end
                end
                if #filtered > 0 then
                    showInteraction(filtered, options.hideOnSelect)
                end
            end
        end,
        onExit = function()
            hideInteraction()
            if options.onExit then
                options.onExit()
            end
        end
    })
    return zone
end)

exports('createSphereZone', function(coords, radius, options)
    local zone = lib.zones.sphere({
        coords = coords,
        radius = radius,
        debug = Config.Debug,
        onEnter = function()
            if options.onEnter then
                options.onEnter()
            end
            if options.prompts then
                local filtered = {}
                for _, prompt in ipairs(options.prompts) do
                    if not prompt.canInteract or prompt.canInteract() then
                        filtered[#filtered + 1] = prompt
                    end
                end
                if #filtered > 0 then
                    showInteraction(filtered, options.hideOnSelect)
                end
            end
        end,
        onExit = function()
            hideInteraction()
            if options.onExit then
                options.onExit()
            end
        end
    })
    return zone
end)