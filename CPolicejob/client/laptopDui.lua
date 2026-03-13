local duiObject = nil
local duiProp = 0

RegisterCommand("testdui", function()
    if DoesEntityExist(duiProp) then
        DestroyDui(duiObject)
        DeleteEntity(duiProp)
        duiProp = 0
        duiObject = nil
        return
    end

    local model = GetHashKey("ba_prop_battle_club_computer_01")
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local coords = GetEntityCoords(PlayerPedId())
    duiProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    FreezeEntityPosition(duiProp, true)

    if not IsNamedRendertargetRegistered("club_computer") then
        RegisterNamedRendertarget("club_computer", false)
    end
    if not IsNamedRendertargetLinked(model) then
        LinkNamedRendertarget("ba_prop_battle_club_computer_01")
    end
    local renderId = GetNamedRendertargetRenderId("club_computer")

    duiObject = CreateDui("nui://CPolicejob/web/build/index.html", 512, 256)
    while not IsDuiAvailable(duiObject) do Wait(0) end

local duiHandle = GetDuiHandle(duiObject)
print("duiHandle:", duiHandle)
local txd = CreateRuntimeTxd("testcomputer")
print("txd:", txd)
CreateRuntimeTextureFromDuiHandle(txd, "screendui", duiHandle)
    CreateRuntimeTextureFromDuiHandle(txd, "screendui", duiHandle)

    print("rendertarget registered:", IsNamedRendertargetRegistered("club_computer"))
    print("rendertarget linked:", IsNamedRendertargetLinked("ba_prop_battle_club_computer_01"))
    print("renderId:", GetNamedRendertargetRenderId("club_computer"))
    print("dui available:", IsDuiAvailable(duiObject))

    RequestStreamedTextureDict("testcomputer", true)
while not HasStreamedTextureDictLoaded("testcomputer") do
    Wait(0)
end
print("texture dict loaded")

CreateThread(function()
    while DoesEntityExist(duiProp) do
        SetTextRenderId(renderId)
        SetScriptGfxDrawOrder(4)
        SetScriptGfxDrawBehindPausemenu(true)
        DrawSprite("testcomputer", "screendui", 0.5, 0.5, 1.0, 1.0, 0.0, 255, 255, 255, 255)
        SetTextRenderId(GetDefaultScriptRendertargetRenderId())
        SetScriptGfxDrawBehindPausemenu(false)
        Wait(0)
    end
end)
end, false)