-- Framework functions (FW_*) are provided by server/framework.lua, loaded first in fxmanifest.

-- ═══════════════════════════════════════════════════════════════════════════
--  DATABASE INIT
-- ═══════════════════════════════════════════════════════════════════════════

local lockers        = {}  -- [id] = { id, label, x, y, z, price, created_by }
local rentals        = {}  -- [locker_id] = { locker_id, owner, code, rented_at, expires_at, weight, slots, invites }
local adminCooldowns = {}  -- [src] = timestamp
local playerCooldowns = {} -- [src_action] = timestamp  (rate limiting)
local pendingEntry   = {}  -- [src] = { lockerId, expires }  (secure enterBucket)
local sentWarnings   = {}  -- [lockerId] = { h24=bool, h1=bool }
local playersInside  = {}  -- [src] = lockerId  (tracks who is inside a locker)

--- Remove expired rentals from memory and database.
--- Declared here (before CreateThread) so it can be called from the DB-init thread.
local function cleanExpiredRentals()
    local now   = os.time()
    local count = 0
    for lockerId, rental in pairs(rentals) do
        if rental.expires_at < now then
            MySQL.query('DELETE FROM nl_locker_rentals WHERE locker_id = ?', { lockerId })
            rentals[lockerId]      = nil
            sentWarnings[lockerId] = nil
            -- getClientLockerById won't crash: locker still exists, rental is nil = available
            TriggerClientEvent('nl-lockers:updated', -1, {
                id        = lockerId,
                label     = lockers[lockerId] and lockers[lockerId].label or '',
                coords    = lockers[lockerId] and lockers[lockerId].coords or vector3(0,0,0),
                price     = lockers[lockerId] and lockers[lockerId].price or 0,
                available = true,
                owner     = nil,
                has_code  = false,
                expires_at = nil,
                keypad    = lockers[lockerId] and lockers[lockerId].keypad or nil,
            })
            count = count + 1
        end
    end
    if count > 0 then
        print(('[nl-lockers] Auto-cleaned %d expired rental(s)'):format(count))
    end
end

CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `nl_lockers` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `label`      VARCHAR(100) NOT NULL,
            `x`          FLOAT NOT NULL,
            `y`          FLOAT NOT NULL,
            `z`          FLOAT NOT NULL,
            `price`      INT NOT NULL DEFAULT 5000,
            `created_by` VARCHAR(50) DEFAULT NULL,
            `keypad_x`   FLOAT DEFAULT NULL,
            `keypad_y`   FLOAT DEFAULT NULL,
            `keypad_z`   FLOAT DEFAULT NULL,
            `keypad_h`   FLOAT DEFAULT NULL
        )
    ]])

    -- Ensure keypad columns exist (if table was created before keypad support)
    pcall(function() MySQL.query.await('ALTER TABLE `nl_lockers` ADD COLUMN `keypad_x` FLOAT DEFAULT NULL') end)
    pcall(function() MySQL.query.await('ALTER TABLE `nl_lockers` ADD COLUMN `keypad_y` FLOAT DEFAULT NULL') end)
    pcall(function() MySQL.query.await('ALTER TABLE `nl_lockers` ADD COLUMN `keypad_z` FLOAT DEFAULT NULL') end)
    pcall(function() MySQL.query.await('ALTER TABLE `nl_lockers` ADD COLUMN `keypad_h` FLOAT DEFAULT NULL') end)

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `nl_locker_rentals` (
            `locker_id`  INT NOT NULL PRIMARY KEY,
            `owner`      VARCHAR(50) NOT NULL,
            `code`       VARCHAR(20) DEFAULT NULL,
            `rented_at`  BIGINT NOT NULL,
            `expires_at` BIGINT NOT NULL,
            `weight`     INT NOT NULL DEFAULT 50000,
            `slots`      INT NOT NULL DEFAULT 50,
            `invites`    TEXT DEFAULT NULL,
            FOREIGN KEY (`locker_id`) REFERENCES `nl_lockers`(`id`) ON DELETE CASCADE
        )
    ]])

    -- Ensure upgrade_level column exists (added for storage upgrade props)
    pcall(function() MySQL.query.await('ALTER TABLE `nl_locker_rentals` ADD COLUMN `upgrade_level` INT NOT NULL DEFAULT 0') end)

    -- Admin action log table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `nl_locker_logs` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `timestamp`  BIGINT NOT NULL,
            `admin_cid`  VARCHAR(50) NOT NULL,
            `action`     VARCHAR(50) NOT NULL,
            `locker_id`  INT DEFAULT NULL,
            `details`    TEXT DEFAULT NULL
        )
    ]])

    -- Load lockers
    local rows = MySQL.query.await('SELECT * FROM nl_lockers')
    if rows then
        for _, r in ipairs(rows) do
            lockers[r.id] = {
                id         = r.id,
                label      = r.label,
                coords     = vector3(r.x, r.y, r.z),
                price      = r.price,
                created_by = r.created_by,
                keypad     = r.keypad_x and {
                    coords = vector3(r.keypad_x, r.keypad_y, r.keypad_z),
                    heading = r.keypad_h
                } or nil,
            }
        end
    end

    -- Load rentals
    local rrows = MySQL.query.await('SELECT * FROM nl_locker_rentals')
    if rrows then
        for _, r in ipairs(rrows) do
            rentals[r.locker_id] = {
                locker_id     = r.locker_id,
                owner         = r.owner,
                code          = r.code,
                rented_at     = r.rented_at,
                expires_at    = r.expires_at,
                weight        = r.weight,
                slots         = r.slots,
                invites       = r.invites and json.decode(r.invites) or {},
                upgrade_level = r.upgrade_level or 0,
            }
        end
    end

    -- Register stashes for all rented lockers
    for lid, rental in pairs(rentals) do
        registerStashes(lid, rental.slots, rental.weight, rental.upgrade_level)
    end

    print('^2[nl-lockers] Loaded ' .. TableLength(lockers) .. ' lockers, ' .. TableLength(rentals) .. ' rentals.^7')

    -- Clean any rentals that expired while the server was offline
    cleanExpiredRentals()
end)

-- ── Expiry warning + periodic cleanup loop ──────────────────────────────────
CreateThread(function()
    Wait(120000) -- wait 2 minutes after resource start before first check
    while true do
        cleanExpiredRentals()
        local now = os.time()
        for lockerId, rental in pairs(rentals) do
            if not sentWarnings[lockerId] then sentWarnings[lockerId] = {} end
            local timeLeft = rental.expires_at - now
            if timeLeft > 0 then
                for _, hours in ipairs(Config.ExpiryWarnHours or { 24, 1 }) do
                    local threshold = hours * 3600
                    local warnKey   = 'h' .. hours
                    if timeLeft <= threshold and not sentWarnings[lockerId][warnKey] then
                        sentWarnings[lockerId][warnKey] = true
                        for _, pid in ipairs(GetPlayers()) do
                            local src = tonumber(pid)
                            local p   = FW_GetPlayer(src)
                            if p and FW_GetIdentifier(p) == rental.owner then
                                FW_Notify( src,
                                    ('Your locker #%d expires in less than %s hour(s)! Renew it now.'):format(lockerId, hours),
                                    'warning', 10000)
                            end
                        end
                    end
                end
            else
                -- Rental just went stale — clear warning flags so they reset if re-rented
                sentWarnings[lockerId] = nil
            end
        end
        Wait(300000) -- check every 5 minutes
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

--- Rate-limit helper. Returns true if the action is allowed.
local function checkPlayerCooldown(src, action, seconds)
    local key = ('%d_%s'):format(src, action)
    local now = os.time()
    if playerCooldowns[key] and (now - playerCooldowns[key]) < seconds then
        return false
    end
    playerCooldowns[key] = now
    return true
end

--- Broadcast admin panel data to every online player with the admin ace.
local function broadcastAdminData()
    local data = getAdminLockers()
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        if IsPlayerAceAllowed(src, Config.AdminAce) then
            TriggerClientEvent('nl-lockers:admin:data', src, data)
        end
    end
end

--- Remove expired rentals from memory and database.
-- (moved earlier in file, before CreateThread — see top of file)

--- Log admin action to database
local function logAdminAction(adminCid, action, lockerId, details)
    MySQL.insert('INSERT INTO nl_locker_logs (timestamp, admin_cid, action, locker_id, details) VALUES (?, ?, ?, ?, ?)',
        { os.time(), adminCid, action, lockerId, details })
    DebugPrint(('Admin %s: %s (locker #%s)'):format(adminCid, action, lockerId or 'N/A'))
end

function registerStashes(lockerId, slots, weight, upgradeLevel)
    -- Register default stash zones (Storage A, Storage B) — works with ox_inventory, qb-inventory, qs-inventory
    if Config.Stashes then
        for _, stash in ipairs(Config.Stashes) do
            local stashId = ('locker_%d_%s'):format(lockerId, stash.name)
            Inv_RegisterStash(stashId, stash.label, slots or Config.DefaultSlots, weight or Config.DefaultWeight)
        end
    end

    -- Register upgrade crate stashes
    upgradeLevel = upgradeLevel or 0
    if Config.StorageUpgrades then
        for i = 1, upgradeLevel do
            local upg = Config.StorageUpgrades[i]
            if upg then
                local stashId = ('locker_%d_upgrade_%d'):format(lockerId, i)
                Inv_RegisterStash(stashId, upg.label, upg.slots, upg.weight)
            end
        end
    end
end

--- Build client-safe locker data (no sensitive info)
local function getClientLocker(locker)
    local rental = rentals[locker.id]
    local now = os.time()
    local rented = rental ~= nil
    local expired = rented and rental.expires_at < now
    local available = (not rented) or expired

    return {
        id        = locker.id,
        label     = locker.label,
        coords    = locker.coords,
        price     = locker.price,
        available = available,
        owner     = rented and rental.owner or nil,
        has_code  = rented and (rental.code ~= nil and rental.code ~= '') or false,
        expires_at = rented and rental.expires_at or nil,
        keypad    = locker.keypad,  -- Include keypad position and heading
    }
end

local function getClientLockerById(id)
    if not lockers[id] then return nil end
    return getClientLocker(lockers[id])
end

local function getAllClientLockers()
    local result = {}
    for id, locker in pairs(lockers) do
        result[id] = getClientLocker(locker)
    end
    return result
end

--- Get admin data (full info for NUI panel)
local function getAdminLockers()
    local result = {}
    for id, locker in pairs(lockers) do
        local rental = rentals[id]
        result[#result + 1] = {
            id         = id,
            label      = locker.label,
            coords     = { x = locker.coords.x, y = locker.coords.y, z = locker.coords.z },
            price      = locker.price,
            created_by = locker.created_by,
            rental     = rental and {
                owner      = rental.owner,
                has_code   = (rental.code and rental.code ~= '') or false,
                rented_at  = rental.rented_at,
                expires_at = rental.expires_at,
                weight     = rental.weight,
                slots      = rental.slots,
                invites    = rental.invites or {},
            } or nil,
        }
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end

-- ═══════════════════════════════════════════════════════════════════════════
--  SYNC: Send data to clients on join / resource start
-- ═══════════════════════════════════════════════════════════════════════════

-- Sync locker data when a player's character is loaded
-- Handles both QBCore (QBCore:Server:OnPlayerLoaded) and ESX (esx:playerLoaded)
local function onPlayerReady()
    local src = source
    Wait(2000)
    TriggerClientEvent('nl-lockers:sync', src, getAllClientLockers())
end
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', onPlayerReady)
RegisterNetEvent('esx:playerLoaded',            onPlayerReady)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(3000)
    TriggerClientEvent('nl-lockers:sync', -1, getAllClientLockers())
end)

-- ═══════════════════════════════════════════════════════════════════════════
--  ADMIN: Create / Delete lockers
-- ═══════════════════════════════════════════════════════════════════════════

--- Admin creates a new locker
RegisterNetEvent('nl-lockers:admin:create', function(data)
    local src = source
    
    print('^3[nl-lockers] Admin create request from player ' .. src .. '^7')
    
    if not IsPlayerAceAllowed(src, Config.AdminAce) then
        print('^1[nl-lockers] Player ' .. src .. ' lacks admin ace^7')
        FW_Notify(src, L('no_permission'), 'error')
        return
    end

    local now = os.time()
    if adminCooldowns[src] and (now - adminCooldowns[src]) < Config.AdminCooldown then
        local remaining = Config.AdminCooldown - (now - adminCooldowns[src])
        print('^1[nl-lockers] Player ' .. src .. ' on cooldown (' .. remaining .. 's remaining)^7')
        FW_Notify(src, L('admin_cooldown', remaining), 'error')
        return
    end

    if not data or not data.label or not data.coords or not data.price then
        print('^1[nl-lockers] Invalid data received: ' .. json.encode(data or {}) .. '^7')
        FW_Notify(src, 'Invalid data received', 'error')
        return
    end

    -- Normalize coords (x, y, z as numbers)
    local x = tonumber(data.coords.x)
    local y = tonumber(data.coords.y)
    local z = tonumber(data.coords.z)
    if not x or not y or not z then
        print('^1[nl-lockers] Invalid coords: ' .. json.encode(data.coords) .. '^7')
        FW_Notify(src, 'Invalid locker position.', 'error')
        return
    end
    data.coords = { x = x, y = y, z = z }

    -- Normalize keypad if present
    if data.keypad and (data.keypad.x ~= nil or data.keypad.h ~= nil) then
        local kx = tonumber(data.keypad.x)
        local ky = tonumber(data.keypad.y)
        local kz = tonumber(data.keypad.z)
        local kh = tonumber(data.keypad.h)
        if not kx or not ky or not kz then
            print('^1[nl-lockers] Invalid keypad coords, ignoring keypad^7')
            data.keypad = nil
        else
            data.keypad = { x = kx, y = ky, z = kz, h = kh or 0 }
        end
    else
        data.keypad = nil
    end

    local validLabel, sanitizedLabel, labelError = ValidateLabel(data.label)
    if not validLabel then
        print('^1[nl-lockers] Label validation failed: ' .. tostring(labelError) .. '^7')
        FW_Notify(src, labelError, 'error')
        return
    end

    local validPrice, priceError = ValidatePrice(data.price)
    if not validPrice then
        print('^1[nl-lockers] Price validation failed: ' .. tostring(priceError) .. '^7')
        FW_Notify(src, priceError, 'error')
        return
    end

    local player = FW_GetPlayer(src)
    local cid = player and FW_GetIdentifier(player) or 'unknown'

    print('^2[nl-lockers] Creating locker: label=' .. tostring(sanitizedLabel) .. ', coords=' .. x .. '/' .. y .. '/' .. z .. ', price=' .. tostring(data.price) .. '^7')

    local ok, id
    if data.keypad then
        ok, id = pcall(function()
            return MySQL.insert.await(
                'INSERT INTO nl_lockers (label, x, y, z, price, created_by, keypad_x, keypad_y, keypad_z, keypad_h) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                { sanitizedLabel, data.coords.x, data.coords.y, data.coords.z, tonumber(data.price), cid, 
                  data.keypad.x, data.keypad.y, data.keypad.z, data.keypad.h }
            )
        end)
    else
        ok, id = pcall(function()
            return MySQL.insert.await(
                'INSERT INTO nl_lockers (label, x, y, z, price, created_by) VALUES (?, ?, ?, ?, ?, ?)',
                { sanitizedLabel, data.coords.x, data.coords.y, data.coords.z, tonumber(data.price), cid }
            )
        end)
    end

    if not ok or not id then
        print('^1[nl-lockers] Database insert failed: ' .. tostring(id) .. '^7')
        FW_Notify(src, 'Failed to create locker. Check server console.', 'error')
        return
    end

    print('^2[nl-lockers] Locker created successfully with ID: ' .. id .. '^7')

    lockers[id] = {
        id         = id,
        label      = sanitizedLabel,
        coords     = vector3(data.coords.x, data.coords.y, data.coords.z),
        price      = tonumber(data.price),
        created_by = cid,
        keypad     = data.keypad and {
            coords = vector3(data.keypad.x, data.keypad.y, data.keypad.z),
            heading = data.keypad.h
        } or nil,
    }

    adminCooldowns[src] = now
    logAdminAction(cid, 'create', id, ('Label: %s, Price: $%s'):format(sanitizedLabel, data.price))

    TriggerClientEvent('nl-lockers:added', -1, getClientLocker(lockers[id]))
    FW_Notify(src, L('locker_created', id), 'success')
    broadcastAdminData()
end)

--- Admin deletes a locker
RegisterNetEvent('nl-lockers:admin:delete', function(lockerId)
    local src = source
    if not IsPlayerAceAllowed(src, Config.AdminAce) then
        FW_Notify( src, L('no_permission'), 'error')
        return
    end

    if not lockers[lockerId] then
        FW_Notify( src, L('locker_not_found'), 'error')
        return
    end

    local player = FW_GetPlayer(src)
    local cid = player and FW_GetIdentifier(player) or 'unknown'
    local lockerLabel = lockers[lockerId].label

    local ok = pcall(function()
        MySQL.query('DELETE FROM nl_lockers WHERE id = ?', { lockerId })
    end)

    if not ok then
        FW_Notify( src, 'Failed to delete locker.', 'error')
        return
    end

    logAdminAction(cid, 'delete', lockerId, ('Label: %s'):format(lockerLabel))

    -- Clear stash data when supported (qb-inventory, qs-inventory); ox_inventory has no ClearStash
    if Inv_ClearStash then
        if Config.Stashes then
            for _, stash in ipairs(Config.Stashes) do
                Inv_ClearStash(('locker_%d_%s'):format(lockerId, stash.name))
            end
        end
        for i = 1, (Config.MaxUpgradeLevel or 6) do
            Inv_ClearStash(('locker_%d_upgrade_%d'):format(lockerId, i))
        end
    end

    lockers[lockerId] = nil
    rentals[lockerId] = nil

    TriggerClientEvent('nl-lockers:removed', -1, lockerId)
    FW_Notify( src, L('locker_deleted', lockerId), 'success')
    broadcastAdminData()
end)

--- Admin requests panel data
RegisterNetEvent('nl-lockers:admin:requestData', function()
    local src = source
    if not IsPlayerAceAllowed(src, Config.AdminAce) then return end
    TriggerClientEvent('nl-lockers:admin:data', src, getAdminLockers())
end)

-- ═══════════════════════════════════════════════════════════════════════════
--  PLAYER: Rent / Enter / Manage
-- ═══════════════════════════════════════════════════════════════════════════

--- Player rents a locker
RegisterNetEvent('nl-lockers:rent', function(lockerId, code)
    local src    = source
    local player = FW_GetPlayer(src)
    if not player then return end

    -- Rate limit
    if not checkPlayerCooldown(src, 'rent', Config.RentCooldown or 5) then
        FW_Notify(src, 'Please wait before trying to rent again.', 'error')
        return
    end

    local locker = lockers[lockerId]
    if not locker then
        FW_Notify(src, L('locker_not_found'), 'error')
        return
    end

    -- Proximity check
    local playerPed    = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local dist = #(vector3(playerCoords.x, playerCoords.y, playerCoords.z) - locker.coords)
    if dist > (Config.MaxRentDistance or 10.0) then
        FW_Notify(src, 'You are too far from the locker.', 'error')
        return
    end

    local rental = rentals[lockerId]
    local now    = os.time()
    if rental then
        if rental.expires_at > now then
            FW_Notify(src, L('already_rented'), 'error')
            return
        end
        MySQL.query('DELETE FROM nl_locker_rentals WHERE locker_id = ?', { lockerId })
        rentals[lockerId]      = nil
        sentWarnings[lockerId] = nil
    end

    local price = locker.price or Config.DefaultPrice
    local cash  = FW_GetMoney(player, 'cash')
    local bank  = FW_GetMoney(player, 'bank')

    if bank >= price then
        FW_RemoveMoney(player, 'bank', price, 'locker-rent')
    elseif cash >= price then
        FW_RemoveMoney(player, 'cash', price, 'locker-rent')
    else
        FW_Notify(src, L('not_enough_money', price), 'error')
        return
    end

    local expires = now + (Config.RentDays * 86400)
    local cid     = FW_GetIdentifier(player)

    local newRental = {
        locker_id     = lockerId,
        owner         = cid,
        code          = (code and code ~= '') and code or nil,
        rented_at     = now,
        expires_at    = expires,
        weight        = Config.DefaultWeight,
        slots         = Config.DefaultSlots,
        invites       = {},
        upgrade_level = 0,
    }

    MySQL.query(
        'INSERT INTO nl_locker_rentals (locker_id, owner, code, rented_at, expires_at, weight, slots, invites, upgrade_level) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { lockerId, cid, newRental.code, now, expires, newRental.weight, newRental.slots, '[]', 0 }
    )

    rentals[lockerId] = newRental
    registerStashes(lockerId, newRental.slots, newRental.weight)

    TriggerClientEvent('nl-lockers:updated', -1, getClientLockerById(lockerId))
    FW_Notify(src, L('locker_rented', Config.RentDays), 'success')
end)

--- Player requests to enter locker
FW_CreateCallback('nl-lockers:canEnter', function(src, cb, lockerId, inputCode)
    local locker = lockers[lockerId]
    if not locker then cb(false, 'Locker not found.') return end

    local rental = rentals[lockerId]
    if not rental then cb(false, 'This locker is not rented.') return end

    local now = os.time()
    if rental.expires_at < now then cb(false, 'Rental has expired.') return end

    local player = FW_GetPlayer(src)
    if not player then cb(false, 'Error.') return end
    local cid = FW_GetIdentifier(player)

    local function grantAccess()
        pendingEntry[src] = { lockerId = lockerId, expires = os.time() + 15 }
        cb(true)
    end

    if cid == rental.owner then
        if rental.code and rental.code ~= '' then
            if inputCode == rental.code then grantAccess() else cb(false, 'Wrong password.') end
        else grantAccess() end
        return
    end

    local invited = false
    if rental.invites then
        for _, inv in ipairs(rental.invites) do
            if inv == cid then invited = true break end
        end
    end

    if invited then
        if rental.code and rental.code ~= '' then
            if inputCode == rental.code then grantAccess() else cb(false, 'Wrong code.') end
        else grantAccess() end
        return
    end

    if rental.code and rental.code ~= '' then
        if inputCode == rental.code then grantAccess() else cb(false, 'Wrong code.') end
    else
        cb(false, 'You do not have access.')
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
--  ROUTING BUCKETS — Private locker instances
-- ═══════════════════════════════════════════════════════════════════════════

local BUCKET_OFFSET = 1000  -- lockerId 1 → bucket 1001, lockerId 2 → bucket 1002, etc.

--- Put player into a private bucket for this locker.
RegisterNetEvent('nl-lockers:enterBucket', function(lockerId)
    local src   = source
    local entry = pendingEntry[src]

    if not entry or entry.lockerId ~= lockerId or entry.expires < os.time() then
        DebugPrint(('Blocked enterBucket from player %d — no valid entry token'):format(src))
        return
    end
    pendingEntry[src] = nil

    if not lockers[lockerId] then return end
    local bucketId = BUCKET_OFFSET + lockerId
    SetPlayerRoutingBucket(src, bucketId)
    playersInside[src] = lockerId  -- track for disconnect handling
    DebugPrint(('Player %d → bucket %d (locker #%d)'):format(src, bucketId, lockerId))
end)

--- Return player to the default world bucket
RegisterNetEvent('nl-lockers:exitBucket', function()
    local src = source
    SetPlayerRoutingBucket(src, 0)
    playersInside[src] = nil  -- clear so we know they left normally
    DebugPrint(('Player %d → bucket 0 (default world)'):format(src))
end)

-- ═══════════════════════════════════════════════════════════════════════════
--  LAPTOP: Storage management (upgrade weight, change code, invites, renew)
-- ═══════════════════════════════════════════════════════════════════════════

--- Get locker info for the laptop UI
FW_CreateCallback('nl-lockers:laptop:getInfo', function(src, cb, lockerId)
    local player = FW_GetPlayer(src)
    if not player then cb(nil) return end

    local rental = rentals[lockerId]
    if not rental then cb(nil) return end

    local cid = FW_GetIdentifier(player)
    if cid ~= rental.owner then cb(nil) return end

    -- Sum used weight across all locker stashes (ox/qs support; qb returns 0)
    local usedWeight = 0
    if Inv_GetStashUsedWeight then
        if Config.Stashes then
            for _, stash in ipairs(Config.Stashes) do
                local sid = ('locker_%d_%s'):format(lockerId, stash.name)
                usedWeight = usedWeight + (Inv_GetStashUsedWeight(sid) or 0)
            end
        end
        for i = 1, (rental.upgrade_level or 0) do
            local sid = ('locker_%d_upgrade_%d'):format(lockerId, i)
            usedWeight = usedWeight + (Inv_GetStashUsedWeight(sid) or 0)
        end
    end

    cb({
        locker_id     = lockerId,
        label         = lockers[lockerId] and lockers[lockerId].label or 'Locker #' .. lockerId,
        owner         = rental.owner,
        weight        = rental.weight,
        usedWeight    = usedWeight,
        maxWeight     = Config.MaxWeight,
        slots         = rental.slots,
        rented_at     = rental.rented_at,
        expires_at    = rental.expires_at,
        has_code      = (rental.code and rental.code ~= '') or false,
        invites       = rental.invites or {},
        upgrade_level = rental.upgrade_level or 0,
        upgradeConfig = Config.StorageUpgrades,
        renewPrice    = lockers[lockerId] and lockers[lockerId].price or Config.DefaultPrice,
        renewDays     = Config.RentDays,
    })
end)

--- Get upgrade level for crate prop spawning (client requests this on enter)
FW_CreateCallback('nl-lockers:getUpgradeLevel', function(src, cb, lockerId)
    local player = FW_GetPlayer(src)
    if not player then cb(0) return end

    local rental = rentals[lockerId]
    if not rental then cb(0) return end

    local cid = FW_GetIdentifier(player)
    -- Only the owner (or invited players) can see the crates
    local hasAccess = (cid == rental.owner)
    if not hasAccess and rental.invites then
        for _, inv in ipairs(rental.invites) do
            if inv == cid then hasAccess = true break end
        end
    end

    if not hasAccess then cb(0) return end
    cb(rental.upgrade_level or 0)
end)

--- Buy next storage upgrade (spawns a crate prop with its own stash)
RegisterNetEvent('nl-lockers:laptop:upgrade', function(lockerId)
    local src = source
    local player = FW_GetPlayer(src)
    if not player then return end

    local rental = rentals[lockerId]
    if not rental or rental.owner ~= FW_GetIdentifier(player) then
        FW_Notify(src, L('not_your_locker'), 'error')
        return
    end

    local currentLevel = rental.upgrade_level or 0
    local nextLevel = currentLevel + 1

    if nextLevel > (Config.MaxUpgradeLevel or #Config.StorageUpgrades) then
        FW_Notify(src, 'Maximum storage upgrades reached.', 'error')
        return
    end

    local upgrade = Config.StorageUpgrades[nextLevel]
    if not upgrade then
        FW_Notify(src, 'Invalid upgrade.', 'error')
        return
    end

    local bank = FW_GetMoney(player, 'bank')
    local cash = FW_GetMoney(player, 'cash')
    if bank >= upgrade.price then
        FW_RemoveMoney(player, 'bank', upgrade.price, 'locker-upgrade')
    elseif cash >= upgrade.price then
        FW_RemoveMoney(player, 'cash', upgrade.price, 'locker-upgrade')
    else
        FW_Notify(src, L('not_enough_money', upgrade.price), 'error')
        return
    end

    rental.upgrade_level = nextLevel
    MySQL.query('UPDATE nl_locker_rentals SET upgrade_level = ? WHERE locker_id = ?', { nextLevel, lockerId })

    -- Register the new upgrade stash
    local stashId = ('locker_%d_upgrade_%d'):format(lockerId, nextLevel)
    Inv_RegisterStash(stashId, upgrade.label, upgrade.slots, upgrade.weight)

    -- Tell the client to spawn the new crate prop
    TriggerClientEvent('nl-lockers:spawnUpgradeProp', src, lockerId, nextLevel)

    FW_Notify(src, ('Storage upgraded! Crate %d unlocked.'):format(nextLevel), 'success')
end)

--- Change code
RegisterNetEvent('nl-lockers:laptop:setCode', function(lockerId, newCode)
    local src    = source
    local player = FW_GetPlayer(src)
    if not player then return end

    if not checkPlayerCooldown(src, 'setcode', Config.LaptopCooldown or 2) then return end

    local rental = rentals[lockerId]
    if not rental or rental.owner ~= FW_GetIdentifier(player) then
        FW_Notify(src, L('not_your_locker'), 'error')
        return
    end

    local validCode, sanitized = ValidateCode(newCode)
    if not validCode then
        FW_Notify(src, 'Invalid code.', 'error')
        return
    end
    newCode = sanitized

    rental.code = (newCode and newCode ~= '') and tostring(newCode) or nil
    MySQL.query('UPDATE nl_locker_rentals SET code = ? WHERE locker_id = ?', { rental.code, lockerId })

    TriggerClientEvent('nl-lockers:updated', -1, getClientLockerById(lockerId))
    FW_Notify(src, rental.code and L('code_updated') or L('code_removed'), 'success')
end)

--- Add invite
RegisterNetEvent('nl-lockers:laptop:addInvite', function(lockerId, targetCid)
    local src    = source
    local player = FW_GetPlayer(src)
    if not player then return end

    if not checkPlayerCooldown(src, 'invite', Config.LaptopCooldown or 2) then return end

    local rental = rentals[lockerId]
    if not rental or rental.owner ~= FW_GetIdentifier(player) then
        FW_Notify(src, L('not_your_locker'), 'error')
        return
    end

    if not targetCid or not ValidateCitizenId(tostring(targetCid)) then
        FW_Notify(src, 'Invalid Citizen ID.', 'error')
        return
    end

    if targetCid == FW_GetIdentifier(player) then
        FW_Notify(src, 'You cannot invite yourself.', 'error')
        return
    end

    for _, inv in ipairs(rental.invites) do
        if inv == targetCid then
            FW_Notify(src, L('already_invited'), 'error')
            return
        end
    end

    rental.invites[#rental.invites + 1] = targetCid
    MySQL.query('UPDATE nl_locker_rentals SET invites = ? WHERE locker_id = ?', { json.encode(rental.invites), lockerId })
    FW_Notify(src, L('player_invited'), 'success')
end)

--- Remove invite
RegisterNetEvent('nl-lockers:laptop:removeInvite', function(lockerId, targetCid)
    local src    = source
    local player = FW_GetPlayer(src)
    if not player then return end

    if not checkPlayerCooldown(src, 'removeinvite', Config.LaptopCooldown or 2) then return end

    local rental = rentals[lockerId]
    if not rental or rental.owner ~= FW_GetIdentifier(player) then
        FW_Notify(src, L('not_your_locker'), 'error')
        return
    end

    if not targetCid then return end

    local newInvites = {}
    for _, inv in ipairs(rental.invites) do
        if inv ~= targetCid then newInvites[#newInvites + 1] = inv end
    end
    rental.invites = newInvites
    MySQL.query('UPDATE nl_locker_rentals SET invites = ? WHERE locker_id = ?', { json.encode(rental.invites), lockerId })
    FW_Notify(src, L('invite_removed'), 'success')
end)

--- Renew rental (optional days: 1-30, or uses Config.RentDays)
RegisterNetEvent('nl-lockers:laptop:renew', function(lockerId, days)
    local src    = source
    local player = FW_GetPlayer(src)
    if not player then return end

    if not checkPlayerCooldown(src, 'renew', Config.RentCooldown or 5) then
        FW_Notify(src, 'Please wait before renewing again.', 'error')
        return
    end

    local rental = rentals[lockerId]
    if not rental or rental.owner ~= FW_GetIdentifier(player) then
        FW_Notify(src, L('not_your_locker'), 'error')
        return
    end

    local baseDays = Config.RentDays
    local selectedDays = (days and type(days) == 'number' and days >= 1 and days <= 30) and math.floor(days) or baseDays

    local basePrice = lockers[lockerId] and lockers[lockerId].price or Config.DefaultPrice
    local price = math.floor((basePrice / baseDays) * selectedDays)
    if price < 1 then price = 1 end

    local cash  = FW_GetMoney(player, 'cash')
    local bank  = FW_GetMoney(player, 'bank')

    if bank >= price then
        FW_RemoveMoney(player, 'bank', price, 'locker-renew')
    elseif cash >= price then
        FW_RemoveMoney(player, 'cash', price, 'locker-renew')
    else
        FW_Notify(src, L('not_enough_money', price), 'error')
        return
    end

    rental.expires_at = rental.expires_at + (selectedDays * 86400)
    MySQL.query('UPDATE nl_locker_rentals SET expires_at = ? WHERE locker_id = ?', { rental.expires_at, lockerId })

    sentWarnings[lockerId] = nil

    TriggerClientEvent('nl-lockers:updated', -1, getClientLockerById(lockerId))
    FW_Notify(src, L('locker_renewed', selectedDays), 'success')
end)

-- Clean up per-player state + handle disconnect-inside-locker (single handler)
AddEventHandler('playerDropped', function()
    local src = source

    -- Always return to default bucket on disconnect
    if GetPlayerRoutingBucket(src) ~= 0 then
        SetPlayerRoutingBucket(src, 0)
    end

    -- If they were inside a locker, reset saved position to locker entrance
    local lockerId = playersInside[src]
    if lockerId and lockers[lockerId] then
        FW_SavePosition(src, lockers[lockerId].coords)
        DebugPrint(('Player %d disconnected inside locker #%d — position reset to entrance'):format(src, lockerId))
    end

    pendingEntry[src]    = nil
    playerCooldowns[src] = nil
    playersInside[src]   = nil
end)
