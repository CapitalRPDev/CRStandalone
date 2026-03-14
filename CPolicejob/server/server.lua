local QBCore = exports['qb-core']:GetCoreObject()
local cuffedPlayers = {}
local draggingPlayers = {}
local officersOnDuty = {}
local webhook = "https://discord.com/api/webhooks/1481972728876761222/fEzgz-3G24pP_7ufjJW5CUwgCPC8Wgep7lQ-BihjgqrpdLDZ6uk7DVBvrY7727WPAe-w"
local activeEvidenceSessions = {}
function LogToDiscord(color, title, description)
    local embed = {
        {
            ["color"] = color,
            ["title"] = title,
            ["description"] = description,
            ["footer"] = {
                ["text"] = "CapitalRP | Logs - " .. os.date("%x %X %p")
            }
        }
    }
    PerformHttpRequest(webhook, function(err, text, headers) end, "POST", json.encode({username = "CapitalRP", embeds = embed}), {["Content-Type"] = "application/json"})
end

local function getPlayerName(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return "Unknown" end
    local name = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname
    return name
end

RegisterNetEvent("CPolice:Server:ToggleDuty", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.job.onduty then
        Player.Functions.SetJobDuty(false)
        officersOnDuty[src] = nil
        TriggerClientEvent('QBCore:Notify', src, "You are now off duty", "info")
        TriggerClientEvent('CPolicejob:Client:SetDutyState', src, false)
        LogToDiscord(15158332, "🔴 Officer Off Duty", "**Officer:** " .. getPlayerName(src) .. " `[" .. src .. "]`")
    else
        Player.Functions.SetJobDuty(true)
        officersOnDuty[src] = {
            name   = getPlayerName(src),
            source = src,
        }
        TriggerClientEvent('QBCore:Notify', src, "You are now on duty. Welcome!", "info")
        TriggerClientEvent('CPolicejob:Client:SetDutyState', src, true)
        LogToDiscord(3066993, "🟢 Officer On Duty", "**Officer:** " .. getPlayerName(src) .. " `[" .. src .. "]`")
    end
end)
RegisterNetEvent("CPoliceJob:Server:RequestCuff", function(targetServerId, frontCuffed)
    local src = source
    targetServerId = tonumber(targetServerId)
    frontCuffed = frontCuffed or false

    if not targetServerId then return end
    if src == targetServerId then return end

    local srcPlayer = QBCore.Functions.GetPlayer(src)
    if not srcPlayer then return end
    if srcPlayer.PlayerData.job.name ~= Config.Police.job then return end
    if Config.Police.requireDuty and not srcPlayer.PlayerData.job.onduty then return end

    local targetPlayer = QBCore.Functions.GetPlayer(targetServerId)
    if not targetPlayer then return end

    if cuffedPlayers[targetServerId] then
        TriggerClientEvent("CPoliceJob:Client:Notify", src, "This person is already cuffed", 4000)
        return
    end

    cuffedPlayers[targetServerId] = { cuffedBy = src, frontCuffed = frontCuffed }

    local cuffType = frontCuffed and "Front Cuffed" or "Back Cuffed"
    LogToDiscord(3447003, "🔒 Player Cuffed", "**Officer:** " .. getPlayerName(src) .. " `[" .. src .. "]`\n**Suspect:** " .. getPlayerName(targetServerId) .. " `[" .. targetServerId .. "]`\n**Type:** " .. cuffType)

    TriggerClientEvent("CPoliceJob:Client:PlayCuffAnim", src, targetServerId, frontCuffed)
    TriggerClientEvent("CPoliceJob:Client:PlayCuffedAnim", targetServerId, frontCuffed)
    TriggerClientEvent("CPoliceJob:Client:SetCuffed", targetServerId, true, src)
end)

RegisterNetEvent("CPoliceJob:Server:RequestUncuff", function(targetServerId)
    local src = source
    targetServerId = tonumber(targetServerId)

    if not targetServerId then return end
    if src == targetServerId then return end

        if not cuffedPlayers[targetServerId] then
        TriggerClientEvent("CPoliceJob:Client:Notify", src, "This person is not cuffed", 4000)
        return
    end

    if draggingPlayers[src] == targetServerId then
        TriggerClientEvent("CPoliceJob:Client:Notify", src, "Stop dragging first", 4000)
        return
    end

    for draggerId, draggedId in pairs(draggingPlayers) do
        if draggedId == targetServerId then
            TriggerClientEvent("CPoliceJob:Client:Notify", src, "This person is being dragged", 4000)
            return
        end
    end

    local srcPlayer = QBCore.Functions.GetPlayer(src)
    if not srcPlayer then return end
    if srcPlayer.PlayerData.job.name ~= Config.Police.job then return end
    if Config.Police.requireDuty and not srcPlayer.PlayerData.job.onduty then return end

    local targetPlayer = QBCore.Functions.GetPlayer(targetServerId)
    if not targetPlayer then return end

    local data = cuffedPlayers[targetServerId]
    local frontCuffed = data and data.frontCuffed or false
    cuffedPlayers[targetServerId] = nil

    LogToDiscord(15105570, "🔓 Player Uncuffed", "**Officer:** " .. getPlayerName(src) .. " `[" .. src .. "]`\n**Suspect:** " .. getPlayerName(targetServerId) .. " `[" .. targetServerId .. "]`")

    TriggerClientEvent("CPoliceJob:Client:PlayUncuffAnim", src, targetServerId, frontCuffed)
    TriggerClientEvent("CPoliceJob:Client:PlayUncuffedAnim", targetServerId)
    TriggerClientEvent("CPoliceJob:Client:SetCuffed", targetServerId, false, src)
end)

RegisterNetEvent("CPoliceJob:Server:RequestDrag", function(targetServerId)
    local src = source
    targetServerId = tonumber(targetServerId)

    if not targetServerId then return end
    if src == targetServerId then return end

    local srcPlayer = QBCore.Functions.GetPlayer(src)
    if not srcPlayer then return end
    if srcPlayer.PlayerData.job.name ~= Config.Police.job then return end
    if Config.Police.requireDuty and not srcPlayer.PlayerData.job.onduty then return end

    TriggerClientEvent("CPoliceJob:Client:CheckCuffStatus", targetServerId, src)
end)

RegisterNetEvent("CPoliceJob:Server:HandleDragRequest", function(isHandcuffed, sourcePlayerId)
    local targetServerId = source

    if not isHandcuffed then
        TriggerClientEvent("CPoliceJob:Client:Notify", sourcePlayerId, "This person is not cuffed", 4000)
        return
    end

    if draggingPlayers[sourcePlayerId] then
        TriggerClientEvent("CPoliceJob:Client:Undrag", targetServerId)
        draggingPlayers[sourcePlayerId] = nil
        LogToDiscord(16776960, "🚶 Player Undragged", "**Officer:** " .. getPlayerName(sourcePlayerId) .. " `[" .. sourcePlayerId .. "]`\n**Suspect:** " .. getPlayerName(targetServerId) .. " `[" .. targetServerId .. "]`")
    else
        TriggerClientEvent("CPoliceJob:Client:Drag", targetServerId, sourcePlayerId)
        draggingPlayers[sourcePlayerId] = targetServerId
        LogToDiscord(10181046, "🫳 Player Dragged", "**Officer:** " .. getPlayerName(sourcePlayerId) .. " `[" .. sourcePlayerId .. "]`\n**Suspect:** " .. getPlayerName(targetServerId) .. " `[" .. targetServerId .. "]`")
    end
end)

RegisterNetEvent("CPoliceJob:Server:PutInVehicle", function(targetServerId, vehicleNetId)
    local src = source

    if draggingPlayers[src] and draggingPlayers[src] == targetServerId then
        TriggerClientEvent("CPoliceJob:Client:Undrag", targetServerId)
        draggingPlayers[src] = nil
    end

    LogToDiscord(1752220, "🚔 Player Put In Vehicle", "**Officer:** " .. getPlayerName(src) .. " `[" .. src .. "]`\n**Suspect:** " .. getPlayerName(targetServerId) .. " `[" .. targetServerId .. "]`")

    TriggerClientEvent("CPoliceJob:Client:PutInVehicle", targetServerId, vehicleNetId)
end)

RegisterNetEvent("CPoliceJob:Server:TakeOutOfVehicle", function(targetServerId)
    local src = source
    LogToDiscord(16744272, "🚗 Player Taken Out Of Vehicle", "**Officer:** " .. getPlayerName(src) .. " `[" .. src .. "]`\n**Suspect:** " .. getPlayerName(targetServerId) .. " `[" .. targetServerId .. "]`")
    TriggerClientEvent("CPoliceJob:Client:TakeOutOfVehicle", targetServerId)
end)


RegisterNetEvent("CPoliceJob:Server:EscapeCuffs", function()
    local src = source

    local data = cuffedPlayers[src]
    if not data then return end

    local officerId = data.cuffedBy
    local frontCuffed = data.frontCuffed or false
    cuffedPlayers[src] = nil

    LogToDiscord(15105570, "🔓 Player Escaped Cuffs", "**Suspect:** " .. getPlayerName(src) .. " `[" .. src .. "]` escaped from cuffs")

    TriggerClientEvent("CPoliceJob:Client:EscapedCuffs", src)
    TriggerClientEvent("CPoliceJob:Client:SuspectEscaped", officerId, src)
end)




RegisterServerEvent('CPoliceJob:Server:tryTackle')
AddEventHandler('CPoliceJob:Server:tryTackle', function(id)
    local source = source
    local user_id = QBCore.Functions.GetPlayer(source)
    TriggerClientEvent('CPoliceJob:Server:playTackle', source)
    TriggerClientEvent('CPoliceJob:Server:getTackled', id, source)
end)

AddEventHandler('playerDropped', function()
    local src = source
    cuffedPlayers[src] = nil
    if draggingPlayers[src] then
        TriggerClientEvent("CPoliceJob:Client:Undrag", draggingPlayers[src])
        draggingPlayers[src] = nil
    end
end)



RegisterNetEvent('CPolicejob:Server:SetActiveEvidenceCode', function(code, stashId)
    local src = source
    activeEvidenceSessions[src] = {
        code    = code,
        stashId = stashId
    }
end)


exports.ox_inventory:registerHook('swapItems', function(payload)
    for i, stash in pairs(Config.Police.evidenceStash) do
        local stashId = 'evidence_stash_' .. i
        if payload.toInventory == stashId or payload.fromInventory == stashId then
            local action = payload.toInventory == stashId and 'Added' or 'Removed'
            local playerName = GetPlayerName(payload.source)
            LogToDiscord(3447003, "🔍 Evidence Stash Activity",
                "**Officer:** " .. playerName .. " `[" .. payload.source .. "]`\n" ..
                "**Action:** " .. action .. "\n" ..
                "**Item:** " .. payload.count .. "x " .. payload.fromSlot.label .. "\n" ..
                "**Stash:** " .. stash.label
            )

            if payload.toInventory == stashId then
                local itemName = payload.fromSlot and payload.fromSlot.name
                if itemName == 'evidence_pack' then
                    local session = activeEvidenceSessions[payload.source]
                    if not session then
                        debugPrintServer('[SERVER] Blocked evidence_pack: no active session for player ' .. payload.source)
                        return false
                    end

                    local packMetadata = payload.fromSlot.metadata
                    if not packMetadata or not packMetadata.pack_id then
                        debugPrintServer('[SERVER] Blocked evidence_pack: no pack_id in metadata')
                        return false
                    end

                    local result = exports.oxmysql:query_async(
                        'SELECT id FROM police_evidence WHERE code = ? AND pack_id = ?',
                        { session.code, packMetadata.pack_id }
                    )

                    if not result or not result[1] then
                        debugPrintServer('[SERVER] Blocked evidence_pack: pack_id ' .. packMetadata.pack_id .. ' not linked to code ' .. session.code)
                        return false
                    end

                    debugPrintServer('[SERVER] Allowed evidence_pack: ' .. packMetadata.pack_id .. ' linked to ' .. session.code)
                end
            end
        end
    end

    if payload.toInventory and tostring(payload.toInventory):sub(1, 4) == 'EVP-' then
        local itemName = payload.fromSlot and payload.fromSlot.name
        if itemName ~= 'evidence_bag' then
            debugPrintServer('[SERVER] Blocked non-evidence_bag item from evidence pack: ' .. tostring(itemName))
            return false
        end
    end
end)


lib.callback.register('CPolicejob:getPlayerGrade', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return 0 end
    return Player.PlayerData.job.grade.level
end)

lib.callback.register('CPolicejob:getLoginDetails', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return nil end
    local citizenid = Player.PlayerData.citizenid
    debugPrintServer('[SERVER] getLoginDetails: querying for citizenid: ' .. tostring(citizenid))
    local result = exports.oxmysql:query_async('SELECT name, password FROM police_officers WHERE citizenid = ?', { citizenid })
    debugPrintServer('[SERVER] getLoginDetails: result: ' .. json.encode(result))
    if result and result[1] then
        return { username = result[1].name, password = result[1].password }
    end
    return nil
end)

lib.callback.register('CPolicejob:getActiveOfficers', function(source)
    local result = {}
    for src, _ in pairs(officersOnDuty) do
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            local citizenid = Player.PlayerData.citizenid
            local officer = exports.oxmysql:query_async('SELECT name, callsign, division, grade FROM police_officers WHERE citizenid = ?', { citizenid })
            if officer and officer[1] then
                table.insert(result, officer[1])
            end
        end
    end
    return result
end)
lib.callback.register('CPolicejob:getAllOfficers', function(source)
    local result = exports.oxmysql:query_async('SELECT * FROM police_officers')
    return result or {}
end)


RegisterNetEvent('CPolicejob:Server:HireOfficer', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayerByCitizenId(data.cid)
    Target.Functions.SetJob("police", 1)
    if not Player then return end

    debugPrintServer('[SERVER] hireOfficer data: ' .. json.encode(data))

    local existing = exports.oxmysql:query_async('SELECT id FROM police_officers WHERE citizenid = ?', { data.cid })
    if existing and existing[1] then
        debugPrintServer('[SERVER] Officer already exists with citizenid: ' .. tostring(data.cid))
        TriggerClientEvent('CPolicejob:Client:BossActionResult', src, { success = false, message = 'Officer already exists' })
        return
    end

    exports.oxmysql:execute_async(
        'INSERT INTO police_officers (citizenid, name, callsign, division, grade, password, on_duty, hired_by) VALUES (?, ?, ?, ?, ?, ?, 0, ?)',
        { data.cid, data.name, data.callsign, data.division, data.grade, data.password, Player.PlayerData.citizenid },
        function(rowsChanged)
            if rowsChanged > 0 then
                debugPrintServer('[SERVER] Officer hired: ' .. data.name)
                TriggerClientEvent('CPolicejob:Client:BossActionResult', src, { success = true, action = 'hire' })
            end
        end
    )
end)

RegisterNetEvent('CPolicejob:Server:FireOfficer', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    exports.oxmysql:execute_async(
        'DELETE FROM police_officers WHERE id = ?',
        { data.id },
        function(rowsChanged)
            if rowsChanged > 0 then
                debugPrintServer('[SERVER] Officer fired: id ' .. tostring(data.id))
                TriggerClientEvent('CPolicejob:Client:BossActionResult', src, { success = true, action = 'fire' })
            end
        end
    )
end)

RegisterNetEvent('CPolicejob:Server:EditOfficer', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if data.password and data.password ~= '' then
        exports.oxmysql:execute_async(
            'UPDATE police_officers SET callsign = ?, division = ?, grade = ?, password = ? WHERE id = ?',
            { data.callsign, data.division, data.grade, data.password, data.id },
            function(rowsChanged)
                if rowsChanged > 0 then
                    TriggerClientEvent('CPolicejob:Client:BossActionResult', src, { success = true, action = 'edit' })
                end
            end
        )
    else
        exports.oxmysql:execute_async(
            'UPDATE police_officers SET callsign = ?, division = ?, grade = ? WHERE id = ?',
            { data.callsign, data.division, data.grade, data.id },
            function(rowsChanged)
                if rowsChanged > 0 then
                    TriggerClientEvent('CPolicejob:Client:BossActionResult', src, { success = true, action = 'edit' })
                end
            end
        )
    end
end)



RegisterNetEvent('CPolicejob:Server:LogEvidence', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    debugPrintServer('[SERVER] Evidence logged: ' .. json.encode(data))

   exports.oxmysql:execute_async(
    'INSERT INTO police_evidence (code, cad_reference, callsign, material, pack_id, comment, logged_by, logged_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())',
    { data.code, data.cadReference, data.callsign, data.material, data.packId, data.comment, Player.PlayerData.citizenid }
)

    LogToDiscord(3066993, "🔬 Evidence Logged", 
        "**Officer:** " .. GetPlayerName(src) .. "\n" ..
        "**CAD Ref:** " .. tostring(data.cadReference) .. "\n" ..
        "**Material:** " .. tostring(data.material) .. "\n" ..
        "**Pack ID:** " .. tostring(data.packId) .. "\n" ..
        "**Code:** `" .. tostring(data.code) .. "`"
    )
end)


lib.callback.register('CPolicejob:validateEvidenceCode', function(source, code)
    if code == 'admin' then return true end
    
    local result = exports.oxmysql:query_async('SELECT id FROM police_evidence WHERE code = ?', { code })
    if result and result[1] then
        return true
    end
    return false
end)


RegisterNetEvent("CPolicejob:Server:RegisterEvidenceBagStash", function(slot)
    local src = source

    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local stashId = 'EVS-'
    for i = 1, 8 do
        local randIndex = math.random(1, #chars)
        stashId = stashId .. chars:sub(randIndex, randIndex)
    end

    exports.ox_inventory:RegisterStash(stashId, 'Evidence Bag - ' .. stashId, 1, 100000)

    local inventory = exports.ox_inventory:GetInventory(src)
    debugPrintServer('[SERVER] Setting metadata for slot ' .. tostring(slot) .. ' stashId: ' .. stashId)
    
    exports.ox_inventory:SetMetadata(src, slot, { stash_id = stashId })
    
    local item = exports.ox_inventory:GetSlot(src, slot)
    debugPrintServer('[SERVER] Item after metadata set: ' .. json.encode(item))

    TriggerClientEvent("CPolicejob:Client:OpenEvidenceStash", src, stashId)
end)


RegisterNetEvent("CPolicejob:Server:RegisterEvidencePackStash", function(slot)
    local src = source

    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local packId = 'EVP-'
    for i = 1, 8 do
        local randIndex = math.random(1, #chars)
        packId = packId .. chars:sub(randIndex, randIndex)
    end

    exports.ox_inventory:RegisterStash(packId, 'Evidence Pack - ' .. packId, 50, 100000, {
        { name = 'evidence_bag', count = 50 }
    })

    exports.ox_inventory:SetMetadata(src, slot, { pack_id = packId })

    debugPrintServer('[SERVER] Evidence pack stash created: ' .. packId)

    TriggerClientEvent("CPolicejob:Client:OpenEvidencePackStash", src, packId)
end)


lib.callback.register('CPolicejob:openEvidenceBagStash', function(source, stashId)
    exports.ox_inventory:RegisterStash(stashId, 'Evidence Bag - ' .. stashId, 10, 100000)
    return true
end)

lib.callback.register('CPolicejob:Server:RegisterPackToStash', function(source, slot, stashId)
    local src = source

    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local packId = 'EVP-'
    for i = 1, 8 do
        local randIndex = math.random(1, #chars)
        packId = packId .. chars:sub(randIndex, randIndex)
    end

    exports.ox_inventory:RegisterStash(packId, 'Evidence Pack - ' .. packId, 50, 100000, {
        { name = 'evidence_bag', count = 50 }
    })

    exports.ox_inventory:SetMetadata(src, slot, { pack_id = packId })

    return packId
end)

AddEventHandler('playerDropped', function()
    local src = source
    activeEvidenceSessions[src] = nil
    if officersOnDuty[src] then
        officersOnDuty[src] = nil
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            Player.Functions.SetJobDuty(false)
        end
    end
end)


AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    Wait(3000) -- wait for ox_inventory to fully start

    debugPrintServer('[SERVER] Re-registering evidence stashes...')

    local rows = exports.oxmysql:query_async("SELECT data FROM ox_inventory WHERE data LIKE '%stash_id%'")
    debugPrintServer('[SERVER] Found rows: ' .. tostring(rows and #rows or 0))
    if rows then
        for _, v in pairs(rows) do
            local data = json.decode(v.data)
            if data then
                for _, item in pairs(data) do
                    if item and item.name == 'evidence_bag' and item.metadata and item.metadata.stash_id then
                        debugPrintServer('[SERVER] Re-registering: ' .. item.metadata.stash_id)
                        exports.ox_inventory:RegisterStash(item.metadata.stash_id, 'Evidence Bag - ' .. item.metadata.stash_id, 10, 100000)
                        debugPrintServer('[SERVER] Re-registered evidence bag stash: ' .. item.metadata.stash_id)
                    end
                end
            end
        end
    end

    local packs = exports.oxmysql:query_async("SELECT data FROM ox_inventory WHERE data LIKE '%pack_id%'")
    if packs then
        for _, v in pairs(packs) do
            local data = json.decode(v.data)
            if data then
                for _, item in pairs(data) do
                    if item and item.name == 'evidence_pack' and item.metadata and item.metadata.pack_id then
                        exports.ox_inventory:RegisterStash(item.metadata.pack_id, 'Evidence Pack - ' .. item.metadata.pack_id, 50, 100000, {
                            { name = 'evidence_bag', count = 50 }
                        })
                        debugPrintServer('[SERVER] Re-registered evidence pack stash: ' .. item.metadata.pack_id)
                    end
                end
            end
        end
    end
end)



function debugPrintServer(msg)
    if Config.Debug then 
        print("^3[Police] ^2" .. msg)
    end

end