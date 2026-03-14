Config = {}
Config.Debug = true


Config.MouseSensitivity = 0.15

Config.Police = {
    job = "police",
    requireDuty = true,
    toggleDuty = {
        vector3(441.7707, -981.1050, 30.6894)
    },
    evidenceStash = {
        [1] = {
            label = "Main Evidence",
            grade = 0,
            requireLogging = true,
            coords = vector3(478.9845, -985.0586, 24.9159)
        },
        [2] = {
            label = "CID Evidence",
            grade = 2,
            requireLogging = false,
            coords = vector3(481.6060, -989.4913, 24.9159)
        },
    }
}

Config.Keybinds = {
    backCuff = 12,
    frontCuff = 13,
    drag = 14,
    putInVehicle = 15,
    outOfVehicle = 16,
    tackle = 17,
}

Config.Items = {
    cuffs = "handcuffs",
    legRestraints = "leg_restraints",
    gloves = "gloves",
    bodycam = "bodycam",
    evidenceBag = "evidence_bag",
    evidencePack = "evidence_pack"
}

Config.Props = {
    cuffs = "p_cs_cuffs_02_s",
    legRestraints = ""
}



Config.Anims = {
    frontCuff = {
        dict = "anim@move_m@prisoner_cuffed",
        name = "idle",
        attachBone = 60309,
        boneOffset = { pos = {-0.058, 0.005, 0.090}, rot = {290.0, 95.0, 120.0} }
    },
    backCuff = {
        dict = "mp_arresting",
        name = "idle",
        attachBone = 60309,
        boneOffset = { pos = {-0.03, 0.03, 0.02}, rot = {275.0, 165.0, 95.0} }
    },
    cuffing = {
        officer = { 
            dict = "mp_arrest_paired", 
            name = "cop_p2_back_left",
            attachOffset = { x = 0.0, y = -0.6, z = 0.0, rotX = 0.0, rotY = 0.0, rotZ = 0.0 }
        },
        officerFront = {
            dict = "mp_arresting",
            name = "a_uncuff",
            attachOffset = { x = 0.0, y = 0.6, z = 0.0, rotX = 0.0, rotY = 0.0, rotZ = 180.0 }
        },
        criminal = { dict = "mp_arrest_paired", name = "crook_p2_back_left" },
        criminalFront = { dict = "anim@move_m@prisoner_cuffed", name = "idle" }
    },
    uncuff = {
        officer = { 
            dict = "mp_arresting", 
            name = "a_uncuff",
            attachOffset = { x = -0.1, y = -0.45, z = 0.0, rotX = 0.0, rotY = 0.0, rotZ = 0.0 },
            attachOffsetFront = { x = 0.0, y = 0.6, z = 0.0, rotX = 0.0, rotY = 0.0, rotZ = 180.0 }
        },
        criminal = { dict = "mp_arresting", name = "b_uncuff" }
    },
}

Config.CuffSettings = {
    cuffingDuration = 5500,
    uncuffDuration = 6000,
    animBlendIn = 8.0,
    animBlendOut = -8.0,
}









Config.LaptopProp      = 'prop_laptop_lester2'
Config.LaptopTexDict   = 'prop_laptop_lester2'
Config.LaptopScreenTextures = {
    'script_rt_tvscreen',       -- Correct texture name for prop_laptop_lester2
}
Config.LaptopCoords = {
    vector4(439.7604, -981.3269, 30.5678, 90.0000),
    vector4(451.6620, -976.1751, 30.5803, 95.0000),
    vector4(473.5229, -983.7916, 24.8164, -180.0000)
}
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