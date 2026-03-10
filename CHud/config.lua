Config = {}
Config.Debug = true
Config.Framework = { 
    framework = "QB", --- "QB" -- do "QB" for QBOX
    inventory = "ox-inventory", -- "qs-inventory" -- "qb-inventory" -- "ox-inventory" -- "custom"
    notify = "QB", -- "QB" -- "OX" -- "custom"
    target = "OX", -- "OX" -- "QB"
    progressbar = "QB",
    vehicleKeys = "cd_garage"
}


Config.HudComponents = {
    {
        name = "health",
        icon = "fa-solid fa-heart",
        defaultValue = 100,
        color = "#ff0000",
        event = "CHud:UpdateHealth",
        order = 1,
        row = 1
    },
    {
        name = "thirst",
        icon = "fa-solid fa-droplet",
        defaultValue = 100,
        color = "#00ffcc",
        event = "CHud:UpdateThirst",
        order = 2,
        row = 1
    },
    {
        name = "hunger",
        icon = "fa-solid fa-utensils",
        defaultValue = 100,
        color = "#ff9100",
        event = "CHud:UpdateHunger",
        order = 3,
        row = 1
    },
    {
        name = "stamina",
        icon = "fa-solid fa-bolt",
        defaultValue = 100,
        color = "#fbff00",
        event = "CHud:UpdateStamina",
        order = 4,
        row = 1
    },
    {
        name = "armor",
        icon = "fa-solid fa-shield-halved",
        defaultValue = 0,
        color = "#00ff73",
        event = "CHud:UpdateArmor",
        order = 5,
        row = 1,
        hideWhenZero = true
    },
    {
        name = "oxygen",
        icon = "fa-solid fa-wind",
        defaultValue = 100,
        color = "#00b7ff",
        event = "CHud:UpdateOxygen",
        order = 6,
        row = 1,
        showOnlyUnderwater = true
    },
    {
        name = "fuel",
        icon = "fa-sharp fa-solid fa-gas-pump",
        defaultValue = 100,
        color = "#00ff40",
        event = "CHud:ShowFuelHud",
        order = 7,
        row = 2,
        showOnlyInCar = true
    },
    {
        name = "engineHealth",
        icon = "fa-solid fa-oil-can",
        defaultValue = 100,
        color = "#ff6b00",
        event = "CHud:UpdateEngineHealth",
        order = 8,
        row = 2,
        showOnlyInCar = true
    }
}