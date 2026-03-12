local QBCore = exports['qb-core']:GetCoreObject()


local function isPolice()

    local playerData = QBCore.Functions.GetPlayerData()
    local job = playerData.job.name 
    local grade = playerData.job.grade.level

    if job == Config.Police.job then 
        return true
    end
    return false


end

RegisterCommand("cuff", function(source, args, rawCommand)

    if not isPolice() then return end 

    



end, false)