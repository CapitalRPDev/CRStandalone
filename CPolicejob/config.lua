Config = {}
Config.Debug = true

Config.Police = {
    job = "police",
    requireDuty = true,
    toggleDuty = {
        vector3(441.7707, -981.1050, 30.6894)
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
    bodycam = "bodycam"
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
        boneOffset = { pos = {-0.055, 0.06, 0.04}, rot = {265.0, 155.0, 80.0} }
    },
    cuffing = {
        officer = { 
            dict = "mp_arrest_paired", 
            name = "cop_p2_back_left",
            attachOffset = { x = -0.1, y = -0.45, z = 0.0, rotX = 0.0, rotY = 0.0, rotZ = 180.0 }
        },
        criminal = { dict = "mp_arrest_paired", name = "crook_p2_back_left" }
    },
    uncuff = {
        officer = { 
            dict = "mp_arresting", 
            name = "a_uncuff",
            attachOffset = { x = -0.1, y = -0.45, z = 0.0, rotX = 0.0, rotY = 0.0, rotZ = 0.0 }
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