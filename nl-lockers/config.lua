Config = {}

-- ─── Debug ─────────────────────────────────────────────────────────────────
Config.Debug = false  -- Set to true to enable debug logging and commands

-- ─── Framework Detection ───────────────────────────────────────────────────
-- 'auto' will detect ESX or QBCore automatically. Or force: 'qb' / 'esx'
Config.Framework = 'auto'

-- ─── Inventory ─────────────────────────────────────────────────────────────
-- 'ox' = ox_inventory | 'qb' = qb-inventory | 'qs' = qs-inventory (Quasar)
-- 'auto' = detect first available (ox > qb > qs)
Config.Inventory = 'auto'

-- ─── Admin ─────────────────────────────────────────────────────────────────
Config.AdminAce = 'command' -- ace permission for /managelockers

-- ─── Locker Defaults ───────────────────────────────────────────────────────
Config.DefaultPrice    = 5000   -- base rent price
Config.RentDays        = 7      -- rental duration in days
Config.DefaultWeight   = 50000  -- 50kg in grams (ox_inventory)
Config.DefaultSlots    = 50     -- inventory slots
Config.MaxWeight       = 200000 -- 200kg max after upgrades

-- ─── Storage Upgrades (bought from laptop) ──────────────────────────────────
-- Each upgrade level spawns a crate prop inside the interior with its own stash.
-- Upgrades are sequential: level 1 must be bought before level 2, etc.
Config.StorageUpgrades = {
    { prop = 'prop_boxpile_06b',    loc = vector4(1088.7007, -3096.2437, -40.0000, 1.8227),   label = 'Crate 1', weight = 50000, slots = 50, price = 3000  },
    { prop = 'prop_boxpile_06b', loc = vector4(1091.2141, -3096.6941, -39.9999, 357.8739), label = 'Crate 2', weight = 50000, slots = 50, price = 5000  },
    { prop = 'prop_boxpile_06b',          loc = vector4(1095.0951, -3096.8997, -39.9999, 357.5524), label = 'Crate 3', weight = 50000, slots = 50, price = 8000  },
    { prop = 'prop_boxpile_06b',         loc = vector4(1097.7412, -3097.0847, -39.9999, 0.8478),   label = 'Crate 4', weight = 50000, slots = 50, price = 12000 },
    { prop = 'prop_boxpile_06b',      loc = vector4(1101.3965, -3096.7812, -39.9999, 356.3791), label = 'Crate 5', weight = 50000, slots = 50, price = 16000 },
    { prop = 'prop_boxpile_06b',        loc = vector4(1103.9249, -3096.8760, -39.9999, 356.1726), label = 'Crate 6', weight = 50000, slots = 50, price = 20000 },
}
Config.MaxUpgradeLevel = #Config.StorageUpgrades

-- ─── Interior (instanced per-player) ──────────────────────────────────────
Config.Interior = {
    coords  = vec3(1105.08, -3099.37, -40.0 ),
    heading = 93.86,
}

-- ─── Exit Door (box zone inside interior) ──────────────────────────────────
Config.ExitDoor = {
    coords   = vec3(1105.35, -3099.45, -38.5),
    size     = vec3(0.3, 3.4, 3.0),
    rotation = 0.0,
}

-- ─── Stash Zones (inside interior) ─────────────────────────────────────────
Config.Stashes = {
    {
        name     = 'stash_a',
        label    = 'Storage A',
        coords   = vec3(1104.0, -3102.9, -39.0),
        size     = vec3(2.6, 0.6, 1.8),
        rotation = 0.0,
    },
    {
        name     = 'stash_b',
        label    = 'Storage B',
        coords   = vec3(1101.1, -3103.0, -39.0),
        size     = vec3(2.75, 0.75, 1.8),
        rotation = 0.0,
    },
}

-- ─── Laptop UI (theme for Storage Manager; server owners can match their brand)
Config.LaptopUI = {
    accent   = '#0ea5e9',  -- Primary buttons, links, active tab (e.g. '#10b981' green, '#8b5cf6' purple)
    currency = '$',        -- Symbol for prices (e.g. '$', '€', '£')
}

-- ─── Storage Open Effect (sound + screen fade when player opens a stash)
Config.StorageOpenSound = 'sound/garagesound.ogg'  -- Path relative to nui folder
Config.StorageOpenFadeMs = 500                      -- Screen fade duration in ms

-- ─── Laptop Prop (management terminal inside interior) ─────────────────────
Config.LaptopProp      = 'prop_laptop_lester2'
Config.LaptopTexDict   = 'prop_laptop_lester2'
Config.LaptopScreenTextures = {
    'script_rt_tvscreen',       -- Correct texture name for prop_laptop_lester2
}
Config.LaptopCoords    = vec3(1087.7031, -3101.2183, -39.2197)
Config.LaptopHeading   = 89.4

-- ─── DUI ───────────────────────────────────────────────────────────────────
Config.DuiWidth  = 1024
Config.DuiHeight = 512

Config.ScreenBounds = {
    L = 0.36,
    T = 0.10,
    R = 0.88,
    B = 0.55,
}

-- ─── Interaction ───────────────────────────────────────────────────────────
Config.TargetDistance = 2.0  -- ox_target interaction distance
Config.MouseSensitivity = 0.06

-- ─── Zone Selector (admin visual picker) ───────────────────────────────────
Config.ZoneSphereColor = { 30, 144, 255, 100 }
Config.ZonePreviewSize = 2.0  -- size of the flat square zone preview marker

-- ─── Validation ────────────────────────────────────────────────────────────
Config.MaxLabelLength = 100
Config.MaxCodeLength = 20
Config.MinPrice = 100
Config.MaxPrice = 1000000
Config.AdminCooldown = 5       -- seconds between admin locker creations
Config.RentCooldown   = 5       -- seconds between player rent attempts
Config.LaptopCooldown = 2       -- seconds between laptop actions (code, invite, etc.)
Config.MaxRentDistance = 10.0   -- max metres a player can be from a locker to rent it
Config.ExpiryWarnHours = { 24, 1 } -- hours before expiry to notify the owner

-- ─── Keypad ────────────────────────────────────────────────────────────────
Config.KeypadProp = 'ch_prop_casino_keypad_01'
Config.KeypadOffset = vec3(0.0, 0.0, 1.0)  -- Default offset from locker coords for keypad placement
