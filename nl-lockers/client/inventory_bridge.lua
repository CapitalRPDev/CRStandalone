-- ═══════════════════════════════════════════════════════════════════════════
--  CLIENT INVENTORY BRIDGE — ox_inventory | qb-inventory | qs-inventory
--  Single API: Inv_OpenStash(stashId)
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
    InvType = 'ox'
end

detect()
if not InvType then InvType = 'ox' end

--- Open a stash by internal id. Safe to call from target/zone onSelect.
--- @param stashId string  e.g. locker_1_stash_a or locker_1_upgrade_1
function Inv_OpenStash(stashId)
    if not stashId or type(stashId) ~= 'string' then return end

    if InvType == 'ox' then
        pcall(function()
            exports.ox_inventory:openInventory('stash', stashId)
        end)
        return
    end

    if InvType == 'qb' then
        TriggerServerEvent('nl-lockers:requestOpenStash', stashId)
        return
    end

    if InvType == 'qs' then
        -- qs-inventory: stash id must include Stash_ prefix (per their docs)
        local qsStashId = 'Stash_' .. stashId
        TriggerServerEvent('inventory:server:OpenInventory', 'stash', qsStashId)
        TriggerEvent('inventory:client:SetCurrentStash', qsStashId)
        return
    end
end

_G.Inv_OpenStash = Inv_OpenStash
_G.Inv_Type = function() return InvType end
