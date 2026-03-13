-- ═══════════════════════════════════════════════════════════════════════════
--  SERVER INVENTORY BRIDGE — ox_inventory | qb-inventory | qs-inventory
--  Single API: Inv_RegisterStash, Inv_OpenStash (via event), Inv_GetStashUsedWeight
-- ═══════════════════════════════════════════════════════════════════════════

local InvType = nil  -- 'ox' | 'qb' | 'qs'

local function detect()
    local cfg = (Config and Config.Inventory) and Config.Inventory:lower() or 'auto'
    if cfg == 'ox' then InvType = 'ox' return end
    if cfg == 'qb' then InvType = 'qb' return end
    if cfg == 'qs' then InvType = 'qs' return end
    -- auto
    if GetResourceState('ox_inventory') == 'started' then
        InvType = 'ox'
        return
    end
    if GetResourceState('qb-inventory') == 'started' then
        InvType = 'qb'
        return
    end
    if GetResourceState('qs-inventory') == 'started' then
        InvType = 'qs'
        return
    end
    InvType = 'ox'  -- default fallback
end

detect()
if not InvType then InvType = 'ox' end

if Config and Config.Debug then
    print(('[nl-lockers] Inventory: %s'):format(InvType))
end

-- ─── Normalize stash ID for inventory that uses a prefix (e.g. qs uses Stash_) ─
local function stashIdFor(stashId)
    if InvType == 'qs' then
        return 'Stash_' .. stashId
    end
    return stashId
end

--- Register a stash. Safe to call multiple times (idempotent where supported).
--- @param stashId string  Internal id (e.g. locker_1_stash_a)
--- @param label string   Display label
--- @param slots number   Max slots
--- @param weight number  Max weight (grams)
function Inv_RegisterStash(stashId, label, slots, weight)
    if InvType == 'ox' then
        pcall(function()
            exports.ox_inventory:RegisterStash(stashId, label, slots, weight)
        end)
        return
    end

    if InvType == 'qb' then
        pcall(function()
            exports['qb-inventory']:CreateInventory(stashId, {
                label = label,
                maxweight = weight,
                slots = slots,
            })
        end)
        return
    end

    if InvType == 'qs' then
        local qsId = stashIdFor(stashId)
        -- qs RegisterStash(playerSource, stashID, stashSlots, stashWeight); use 0 for global stash
        pcall(function()
            exports['qs-inventory']:RegisterStash(0, qsId, slots, weight)
        end)
        return
    end
end

--- Open stash for a player (called from server when client requests open for qb; ox/qs open from client).
--- @param src number   Player source
--- @param stashId string  Internal stash id
function Inv_OpenStash(src, stashId)
    if not src or not stashId then return end

    if InvType == 'qb' then
        pcall(function()
            exports['qb-inventory']:OpenInventory(src, stashId)
        end)
        return
    end

    -- ox: client opens via export; qs: client opens via TriggerServerEvent to qs. Nothing to do here for ox/qs.
end

--- Optional: get total used weight for a stash (for laptop display). Returns 0 if not supported.
--- @param stashId string
--- @return number usedWeight grams
function Inv_GetStashUsedWeight(stashId)
    if InvType == 'ox' then
        local ok, inv = pcall(function()
            return exports.ox_inventory:GetInventory(stashId, false)
        end)
        if ok and inv and inv.weight then
            return inv.weight
        end
        return 0
    end

    if InvType == 'qs' then
        local qsId = stashIdFor(stashId)
        local ok, items = pcall(function()
            return exports['qs-inventory']:GetStashItems(qsId)
        end)
        if not ok or not items then return 0 end
        local itemList = exports['qs-inventory']:GetItemList()
        local total = 0
        for _, item in pairs(items) do
            local weight = 0
            if itemList and itemList[item.name] and itemList[item.name].weight then
                weight = itemList[item.name].weight
            end
            total = total + (weight * (item.amount or 1))
        end
        return math.floor(total)
    end

    -- qb-inventory: no standard export for stash total weight in common docs; return 0
    return 0
end

--- Clear a stash (e.g. when locker is deleted). No-op if inventory doesn't support it.
--- @param stashId string
function Inv_ClearStash(stashId)
    if InvType == 'qb' then
        pcall(function()
            exports['qb-inventory']:ClearStash(stashId)
        end)
        return
    end
    if InvType == 'qs' then
        local qsId = stashIdFor(stashId)
        pcall(function()
            exports['qs-inventory']:ClearOtherInventory('stash', qsId)
        end)
        return
    end
    -- ox_inventory: no ClearStash in standard API; leave as-is or document
end

-- Client requests stash open (used by qb-inventory; ox/qs open from client)
RegisterNetEvent('nl-lockers:requestOpenStash', function(stashId)
    local src = source
    if not stashId or type(stashId) ~= 'string' then return end
    Inv_OpenStash(src, stashId)
end)

-- Export for other server scripts
_G.Inv_RegisterStash = Inv_RegisterStash
_G.Inv_OpenStash = Inv_OpenStash
_G.Inv_GetStashUsedWeight = Inv_GetStashUsedWeight
_G.Inv_ClearStash = Inv_ClearStash
_G.Inv_Type = function() return InvType end
