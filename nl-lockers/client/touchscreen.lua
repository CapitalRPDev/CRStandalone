-- ═══════════════════════════════════════════════════════════════════════════
--  3D TOUCHSCREEN INTERACTION SYSTEM
--  Uses ox_lib zones + camera raycasting + UV mapping for accurate DUI clicks
-- ═══════════════════════════════════════════════════════════════════════════

local activeScreen = nil
local isInteracting = false
local lastHitUV = nil

-- ─── Plane Intersection Math ───────────────────────────────────────────────

--- Calculate intersection point between ray and plane
---@param rayOrigin vector3 Camera position
---@param rayDir vector3 Normalized ray direction
---@param planePoint vector3 Point on the plane
---@param planeNormal vector3 Plane normal vector
---@return vector3|nil hitPoint World space hit position
local function rayPlaneIntersection(rayOrigin, rayDir, planePoint, planeNormal)
    local denom = planeNormal.x * rayDir.x + planeNormal.y * rayDir.y + planeNormal.z * rayDir.z
    
    -- Ray is parallel to plane
    if math.abs(denom) < 0.0001 then
        return nil
    end
    
    local diff = planePoint - rayOrigin
    local t = (diff.x * planeNormal.x + diff.y * planeNormal.y + diff.z * planeNormal.z) / denom
    
    -- Intersection is behind camera
    if t < 0 then
        return nil
    end
    
    return rayOrigin + rayDir * t
end

--- Convert world space hit point to local UV coordinates (0-1 range)
---@param hitPoint vector3 World space intersection point
---@param planeCenter vector3 Center of the interaction plane
---@param planeRight vector3 Right vector of the plane
---@param planeUp vector3 Up vector of the plane
---@param planeWidth number Physical width of the plane
---@param planeHeight number Physical height of the plane
---@return number|nil u Horizontal coordinate (0-1)
---@return number|nil v Vertical coordinate (0-1)
local function worldToUV(hitPoint, planeCenter, planeRight, planeUp, planeWidth, planeHeight)
    -- Get local offset from plane center
    local offset = hitPoint - planeCenter
    
    -- Project onto plane axes
    local u = (offset.x * planeRight.x + offset.y * planeRight.y + offset.z * planeRight.z) / planeWidth
    local v = (offset.x * planeUp.x + offset.y * planeUp.y + offset.z * planeUp.z) / planeHeight
    
    -- Normalize to 0-1 range (center origin to corner origin)
    u = u + 0.5
    v = 0.5 - v  -- Flip V because screen coords go top-down
    
    -- Check if hit is within bounds
    if u < 0 or u > 1 or v < 0 or v > 1 then
        return nil, nil
    end
    
    return u, v
end

--- Convert UV coordinates to DUI pixel coordinates
---@param u number Horizontal UV (0-1)
---@param v number Vertical UV (0-1)
---@param duiWidth number DUI resolution width
---@param duiHeight number DUI resolution height
---@return number x Pixel X coordinate
---@param number y Pixel Y coordinate
local function uvToPixels(u, v, duiWidth, duiHeight)
    return math.floor(u * duiWidth), math.floor(v * duiHeight)
end

-- ─── Camera Raycasting ─────────────────────────────────────────────────────

--- Cast ray from camera forward and check plane intersection
---@param screen table Screen configuration
---@return number|nil x DUI pixel X
---@return number|nil y DUI pixel Y
local function raycastToScreen(screen)
    local camRot = GetGameplayCamRot(2)
    local camPos = GetGameplayCamCoord()
    
    -- Convert camera rotation to direction vector
    local radX = math.rad(camRot.x)
    local radZ = math.rad(camRot.z)
    local rayDir = vector3(
        -math.sin(radZ) * math.cos(radX),
        math.cos(radZ) * math.cos(radX),
        math.sin(radX)
    )
    
    -- Calculate plane vectors from rotation
    local rot = screen.rotation
    local radRotX = math.rad(rot.x)
    local radRotY = math.rad(rot.y)
    local radRotZ = math.rad(rot.z)
    
    -- Plane normal (forward vector)
    local normal = vector3(
        -math.sin(radRotZ) * math.cos(radRotX),
        math.cos(radRotZ) * math.cos(radRotX),
        math.sin(radRotX)
    )
    
    -- Plane right vector
    local right = vector3(
        math.cos(radRotZ),
        math.sin(radRotZ),
        0
    )
    
    -- Plane up vector
    local up = vector3(
        -math.sin(radRotZ) * math.sin(radRotX),
        math.cos(radRotZ) * math.sin(radRotX),
        math.cos(radRotX)
    )
    
    -- Check ray-plane intersection
    local hitPoint = rayPlaneIntersection(camPos, rayDir, screen.center, normal)
    if not hitPoint then
        return nil, nil
    end
    
    -- Convert to UV coordinates
    local u, v = worldToUV(hitPoint, screen.center, right, up, screen.width, screen.height)
    if not u or not v then
        return nil, nil
    end
    
    -- Convert to pixel coordinates
    return uvToPixels(u, v, screen.duiWidth, screen.duiHeight)
end

-- ─── Interaction Loop ──────────────────────────────────────────────────────

local function startInteraction(screen)
    if isInteracting then return end
    
    activeScreen = screen
    isInteracting = true
    lastHitUV = nil
    
    CreateThread(function()
        while isInteracting and activeScreen do
            Wait(0)
            
            -- Disable game controls
            DisableControlAction(0, 1, true)   -- Mouse X
            DisableControlAction(0, 2, true)   -- Mouse Y
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisablePlayerFiring(cache.playerId, true)
            
            -- Raycast to screen
            local x, y = raycastToScreen(activeScreen)
            
            if x and y then
                -- Valid hit - send mouse move
                DUI_MouseMove(x, y)
                lastHitUV = {x = x, y = y}
                
                -- Draw debug marker at hit point
                if Config.Debug then
                    local u = x / activeScreen.duiWidth
                    local v = y / activeScreen.duiHeight
                    
                    -- Convert UV back to world for debug visualization
                    local rot = activeScreen.rotation
                    local radRotZ = math.rad(rot.z)
                    local right = vector3(math.cos(radRotZ), math.sin(radRotZ), 0)
                    local up = vector3(0, 0, 1)
                    
                    local offsetU = (u - 0.5) * activeScreen.width
                    local offsetV = (0.5 - v) * activeScreen.height
                    local worldPos = activeScreen.center + right * offsetU + up * offsetV
                    
                    DrawMarker(28, worldPos.x, worldPos.y, worldPos.z,
                        0, 0, 0, 0, 0, 0, 0.02, 0.02, 0.02,
                        0, 255, 0, 200,
                        false, false, 2, false, nil, nil, false)
                end
                
                -- Handle mouse buttons
                if IsDisabledControlJustPressed(0, 24) then
                    DUI_MouseButton(0, true, x, y)
                end
                if IsDisabledControlJustReleased(0, 24) then
                    DUI_MouseButton(0, false, x, y)
                end
                
                -- Right click
                if IsDisabledControlJustPressed(0, 25) then
                    DUI_MouseButton(1, true, x, y)
                end
                if IsDisabledControlJustReleased(0, 25) then
                    DUI_MouseButton(1, false, x, y)
                end
            else
                -- No hit - cursor outside bounds
                lastHitUV = nil
            end
            
            -- Exit on ESC
            if IsControlJustPressed(0, 200) then
                stopInteraction()
            end
        end
    end)
end

local function stopInteraction()
    isInteracting = false
    activeScreen = nil
    lastHitUV = nil
end

-- ─── Screen Registration ───────────────────────────────────────────────────

---@class TouchScreen
---@field center vector3 Center point of the interaction plane
---@field rotation vector3 Rotation of the plane (pitch, roll, yaw)
---@field width number Physical width of the plane in world units
---@field height number Physical height of the plane in world units
---@field duiWidth number DUI resolution width
---@field duiHeight number DUI resolution height
---@field zoneSize vector3 ox_lib zone size
---@field zoneRotation number ox_lib zone rotation
---@field onEnter function|nil Callback when entering zone
---@field onExit function|nil Callback when exiting zone

--- Register a touchscreen with ox_lib zone
---@param screen TouchScreen
---@return number zoneId ox_lib zone ID
function RegisterTouchScreen(screen)
    local zone = lib.zones.box({
        coords = screen.center,
        size = screen.zoneSize or vec3(2, 2, 2),
        rotation = screen.zoneRotation or 0,
        debug = Config.Debug,
        inside = function()
            -- Show help text
            if not isInteracting then
                lib.showTextUI('[E] Use Touchscreen  \n[ESC] Exit', { position = 'left-center' })
            end
            
            -- Start interaction on E press
            if IsControlJustPressed(0, 38) and not isInteracting then
                lib.hideTextUI()
                if screen.onEnter then screen.onEnter() end
                startInteraction(screen)
            end
        end,
        onExit = function()
            lib.hideTextUI()
            if isInteracting then
                stopInteraction()
                if screen.onExit then screen.onExit() end
            end
        end
    })
    
    return zone
end

-- ─── Exports ───────────────────────────────────────────────────────────────

exports('RegisterTouchScreen', RegisterTouchScreen)
exports('StopInteraction', stopInteraction)

_G.RegisterTouchScreen = RegisterTouchScreen
_G.StopTouchScreen = stopInteraction
