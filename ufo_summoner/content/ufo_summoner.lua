-- ==============================================================================
-- UFO Summoner Core / 幽浮召喚與物理運動控制核心
-- ==============================================================================

local M = {}

local UFO_MODEL = "::/game_mechanics/fun_elements/ufo/ufo.mdl"
local COW_CONSTRUCTION = "::/industries/livestock_farm/livestock_farm.con"
local COW_MODELS = {
    "::/animal/cow/cow_2_idle.mdl",
    "::/animal/cow/cow_2_prod_high.mdl",
    "::/animal/cow/cow_2_prod_low.mdl",
    "::/animal/cow/cow_2.mdl",
    "::/animal/cow/cow_idle.mdl",
    "::/animal/cow/cow_prod_low.mdl",
    "::/animal/cow/cow_prod_high.mdl",
    "::/animal/cow/cow.mdl",
}

-- Movement parameters
local UFO_SPAWN_OFFSET_XY = 500
local ABDUCT_ACCEL = 2
local ABDUCT_MAX_SPEED = 6
local ABDUCT_HEIGHT = 25
local FLY_HEIGHT = 100
local MIN_HEIGHT_ABOVE_TERRAIN = 30
local STEERING = 1.5
local MAX_SPEED = 100
local MIN_SPEED = 4
local ACCELERATION = 80
local DECELERATION = 40

-- Active summoned UFOs
local myUfos = {}
local lastNotice = nil
local lastTickTime = nil

-- Entity & Model Helpers
local function toEntityId(ent)
    if type(ent) == "table" and ent.entity then
        return ent.entity
    elseif type(ent) == "number" then
        return ent
    end
    return nil
end

local function findModelId(path)
    if not api or not api.res or not api.res.modelRep then return -1 end
    local id = api.res.modelRep.find(path)
    if id and id >= 0 then return id end
    if path:sub(1, 3) == "::/" then
        id = api.res.modelRep.find(path:sub(4))
        if id and id >= 0 then return id end
    else
        id = api.res.modelRep.find("::/" .. path)
        if id and id >= 0 then return id end
    end
    return -1
end

-- Math Helpers
local function approach(current, target, shift)
    shift = math.abs(shift)
    if current < target then
        return math.min(current + shift, target)
    else
        return math.max(current - shift, target)
    end
end

local function approachVec3f(current, target, shift)
    local delta = target - current
    local norm = api.type.Vec3f.normalize(delta)
    local x = approach(current.x, target.x, math.abs(norm.x) * shift)
    local y = approach(current.y, target.y, math.abs(norm.y) * shift)
    local z = approach(current.z, target.z, math.abs(norm.z) * shift)
    return api.type.Vec3f.new(x, y, z)
end

local function vec2fToYaw(v)
    return math.atan2(v.y, v.x)
end

local function yawToVec2f(angle)
    return api.type.Vec2f.rotate(api.type.Vec2f.new(1, 0), angle)
end

local function approachAngularVec2f(current, target, shift)
    if api.type.Vec2f.distance(target, current) < 0.01 then
        return target
    end
    local yaw1 = math.deg(vec2fToYaw(current))
    local yaw2 = math.deg(vec2fToYaw(target))
    local diff = ((((yaw2 - yaw1) % 360) + 540) % 360) - 180
    local endYaw = yaw1 + (diff * shift) % 360
    return yawToVec2f(math.rad(endYaw))
end

local function approachAngularVec3f(current, target, shift)
    local v2 = approachAngularVec2f(api.type.Vec2f.new(current.x, current.y), api.type.Vec2f.new(target.x, target.y), shift)
    local z = approach(current.z, target.z, shift)
    return api.type.Vec3f.normalize(api.type.Vec3f.new(v2.x, v2.y, z))
end

local function getEntityTransf(entity)
    local id = toEntityId(entity)
    if not id then return nil end
    local mil = api.engine.getComponent(id, api.type.ComponentType.MODEL_INSTANCE_LIST)
    if mil and mil.fatInstances and mil.fatInstances[1] then
        return mil.fatInstances[1].transf
    end
    return nil
end

local function setEntityTransf(entity, transf)
    local id = toEntityId(entity)
    if not id then return end
    local cmd = api.cmd.makeCustomEntityUpdateTransformationCmd(id, transf)
    api.cmd.sendCommand(cmd)
end

local function destroyEntity(entity)
    local id = toEntityId(entity)
    if id and id >= 0 then
        local cmd = api.cmd.makeCustomEntityDestroyCmd(id)
        api.cmd.sendCommand(cmd)
    end
end

local function spawnCustomModel(modelPath, transf, callback)
    local modelId = findModelId(modelPath)
    if not modelId or modelId < 0 then
        return
    end

    local cmd = api.cmd.makeCustomEntityCreateCmd(modelId)
    api.cmd.sendCommand(cmd, function(res, success)
        if not success or not res or not res.resultEntity then return end
        local ent = res.resultEntity
        setEntityTransf(ent, transf)
        if callback then
            callback(ent)
        end
    end)
end

local function findSpawnPointOffMap(pos, xyOffset, zOffset)
    local box = api.engine.terrain.getBoundingBox()
    local xMinOff = math.abs(box.min.x - pos.x)
    local xMaxOff = math.abs(box.max.x - pos.x)
    local yMinOff = math.abs(box.min.y - pos.y)
    local yMaxOff = math.abs(box.max.y - pos.y)

    local edgePos = nil
    local xyOffsetVec = nil

    if math.min(xMinOff, xMaxOff) < math.min(yMinOff, yMaxOff) then
        if xMinOff < xMaxOff then
            edgePos = api.type.Vec2f.new(box.min.x, pos.y)
            xyOffsetVec = api.type.Vec2f.new(-xyOffset, 0)
        else
            edgePos = api.type.Vec2f.new(box.max.x, pos.y)
            xyOffsetVec = api.type.Vec2f.new(xyOffset, 0)
        end
    else
        if yMinOff < yMaxOff then
            edgePos = api.type.Vec2f.new(pos.x, box.min.y)
            xyOffsetVec = api.type.Vec2f.new(0, -xyOffset)
        else
            edgePos = api.type.Vec2f.new(pos.x, box.max.y)
            xyOffsetVec = api.type.Vec2f.new(0, xyOffset)
        end
    end

    local height = api.engine.terrain.getHeightAt(edgePos)
    local spawnPos = api.type.Vec3f.new(edgePos.x + xyOffsetVec.x, edgePos.y + xyOffsetVec.y, height + zOffset)
    return spawnPos
end

-- Find all livestock farm fields with cows
local function findCowFields()
    local cowModelIds = {}
    for _, mdl in ipairs(COW_MODELS) do
        local id = findModelId(mdl)
        if id and id >= 0 then
            cowModelIds[id] = true
        end
    end

    local fields = {}
    api.engine.forEachEntityWithComponent(function(industryEntity)
        local industry = api.engine.getComponent(industryEntity, api.type.ComponentType.INDUSTRY)
        if not industry or not industry.construction then return end
        local construction = api.engine.getComponent(industry.construction, api.type.ComponentType.CONSTRUCTION)
        if not construction then return end

        local fn = construction.fileName or ""
        if fn == COW_CONSTRUCTION or string.find(fn, "livestock_farm") then
            if construction.subconstructions then
                for _, subEntity in ipairs(construction.subconstructions) do
                    local mil = api.engine.getComponent(subEntity, api.type.ComponentType.MODEL_INSTANCE_LIST)
                    if mil and mil.fatInstances then
                        for _, inst in ipairs(mil.fatInstances) do
                            if inst.modelId and cowModelIds[inst.modelId] then
                                table.insert(fields, subEntity)
                                break
                            end
                        end
                    end
                end
            end
        end
    end, api.type.ComponentType.INDUSTRY)

    return fields
end

-- Check if cow farm exists
function M.hasLivestockFarmsWithCows()
    local ok, res = pcall(findCowFields)
    if ok and res and #res > 0 then
        return true
    end
    return false
end

-- Move and focus camera to world position
function M.focusPosition(pos, zoom)
    if not pos then return end
    pcall(function()
        if not (api and api.gui and api.gui.camera) then return end
        local z = zoom or 25
        if api.gui.camera.focusPosition then
            api.gui.camera.focusPosition(pos, z)
        elseif api.gui.camera.lookAt then
            api.gui.camera.lookAt(pos)
        end
    end)
end

-- Focus camera on entity with tracking
function M.focusEntity(entity)
    local id = toEntityId(entity)
    if not id or id < 0 then return end
    pcall(function()
        if not (api and api.gui and api.gui.camera) then return end
        
        -- Center camera view on entity position
        local transf = getEntityTransf(id)
        if transf then
            local pos = transf:getTransl()
            if api.gui.camera.focusPosition then
                api.gui.camera.focusPosition(pos, 25)
            end
        end

        -- Follow entity movement
        if api.gui.camera.followEntity then
            api.gui.camera.followEntity(id, true)
        elseif api.gui.camera.focusEntity then
            api.gui.camera.focusEntity(id)
        end
    end)
end

-- Determine target position for cow & abduction
function M.getTargetPosition()
    local fields = findCowFields()
    if #fields > 0 then
        local field = fields[math.random(1, #fields)]
        local mil = api.engine.getComponent(field, api.type.ComponentType.MODEL_INSTANCE_LIST)
        if mil and mil.fatInstances and mil.fatInstances[1] then
            return mil.fatInstances[1].transf:getTransl(), true
        end
    end

    -- Fallback to camera center position if no cow farm exists
    local camData = nil
    pcall(function()
        if api and api.gui and api.gui.camera and api.gui.camera.getCameraData then
            camData = api.gui.camera.getCameraData()
        end
    end)

    if camData and camData.x and camData.y then
        local camX = camData.x
        local camY = camData.y
        local camZ = api.engine.terrain.getHeightAt(api.type.Vec2f.new(camX, camY))
        return api.type.Vec3f.new(camX, camY, camZ), false
    end

    -- Fallback to terrain center
    local box = api.engine.terrain.getBoundingBox()
    local midX = (box.min.x + box.max.x) * 0.5
    local midY = (box.min.y + box.max.y) * 0.5
    local midZ = api.engine.terrain.getHeightAt(api.type.Vec2f.new(midX, midY))
    return api.type.Vec3f.new(midX, midY, midZ), false
end

-- Update loop for active UFOs (called every frame)
function M.update(dt)
    if #myUfos == 0 then
        lastTickTime = nil
        return
    end

    local now = os.clock()
    if not dt then
        if not lastTickTime then
            lastTickTime = now
            return
        end
        dt = now - lastTickTime
        lastTickTime = now
    end

    if dt <= 0 then return end
    if dt > 0.1 then dt = 0.1 end -- clamp against sudden skips

    local toRemove = {}
    for idx, ufo in ipairs(myUfos) do
        local transf = getEntityTransf(ufo.ufoEntity)
        if not transf then
            table.insert(toRemove, idx)
        else
            local currentPos = transf:getTransl()
            local targetPos = ufo.target
            local distanceToTarget = api.type.Vec3f.distance(targetPos, currentPos)

            local minHeight = (ufo.state == "Approach" or ufo.state == "Abduct") and 0 or MIN_HEIGHT_ABOVE_TERRAIN
            local accel = (ufo.state == "Approach") and 0 or (ufo.state == "Target" and DECELERATION or ACCELERATION)

            -- Movement calculation
            local currentVelocity = ufo.velocity or api.type.Vec3f.new(100, 0, 0)
            local currentSpeed = api.type.Vec3f.distance(currentVelocity, api.type.Vec3f.new(0, 0, 0))
            local targetSpeed = distanceToTarget < 50 and MIN_SPEED or MAX_SPEED
            local nextSpeed = approach(currentSpeed, targetSpeed, accel * dt)

            local vecToTarget = api.type.Vec3f.normalize(targetPos - currentPos)
            local velNorm = api.type.Vec3f.normalize(currentVelocity)
            local nextDir = approachAngularVec3f(velNorm, vecToTarget, STEERING * dt)
            local nextVel = nextDir * nextSpeed

            local nextPos = currentPos + nextVel * dt
            local minZ = api.engine.terrain.getHeightAt(api.type.Vec2f.new(nextPos.x, nextPos.y)) + minHeight
            nextPos.z = math.max(nextPos.z, minZ)

            ufo.velocity = nextVel
            local rotAngle = vec2fToYaw(api.type.Vec2f.new(nextDir.x, nextDir.y))
            setEntityTransf(ufo.ufoEntity, api.type.Mat4f.rotZTransl(rotAngle, nextPos))

            -- State transitions
            if ufo.state == "Approach" then
                if distanceToTarget < 120 then
                    local cowTransf = ufo.cowEntity and getEntityTransf(ufo.cowEntity)
                    if cowTransf then
                        local cowPos = cowTransf:getTransl()
                        cowPos.z = cowPos.z + ABDUCT_HEIGHT
                        ufo.target = cowPos
                    end
                    ufo.state = "Target"
                end

            elseif ufo.state == "Target" then
                if distanceToTarget < 15 then
                    ufo.abductSpeed = 0
                    ufo.state = "Abduct"
                end

            elseif ufo.state == "Abduct" then
                ufo.abductSpeed = approach(ufo.abductSpeed or 0, ABDUCT_MAX_SPEED, ABDUCT_ACCEL * dt)
                if ufo.cowEntity then
                    local cowTransf = getEntityTransf(ufo.cowEntity)
                    if cowTransf then
                        local cowPos = cowTransf:getTransl()
                        cowPos = approachVec3f(cowPos, currentPos, ufo.abductSpeed * dt)

                        if math.abs(cowPos.z - currentPos.z) < 2.0 then
                            destroyEntity(ufo.cowEntity)
                            ufo.cowEntity = nil
                            local exitPos = findSpawnPointOffMap(currentPos, UFO_SPAWN_OFFSET_XY, FLY_HEIGHT)
                            ufo.target = exitPos
                            ufo.state = "Leave"
                        else
                            setEntityTransf(ufo.cowEntity, api.type.Mat4f.transl(cowPos))
                        end
                    else
                        ufo.state = "Leave"
                    end
                else
                    ufo.state = "Leave"
                end

            elseif ufo.state == "Leave" then
                if distanceToTarget < 50 then
                    destroyEntity(ufo.ufoEntity)
                    ufo.state = "Despawn"
                    table.insert(toRemove, idx)
                end
            end
        end
    end

    for i = #toRemove, 1, -1 do
        table.remove(myUfos, toRemove[i])
    end
end

-- Get list of all active UFOs
function M.getActiveUfos()
    local result = {}
    for _, u in ipairs(myUfos) do
        local ufoId = toEntityId(u.ufoEntity)
        local cowId = toEntityId(u.cowEntity)
        if ufoId and ufoId >= 0 then
            table.insert(result, {
                ufoEntity = ufoId,
                cowEntity = cowId,
                state = u.state or "Approach",
            })
        end
    end
    return result
end

-- Summon UFO
function M.summonUfo(callback)
    local cowPos, hasFarm = M.getTargetPosition()

    -- Immediately move camera to target location!
    M.focusPosition(cowPos, 25)

    local ufoSpawnPos = findSpawnPointOffMap(cowPos, UFO_SPAWN_OFFSET_XY, FLY_HEIGHT)
    local targetPos = api.type.Vec3f.new(cowPos.x, cowPos.y, cowPos.z + FLY_HEIGHT)
    local dirToTarget = api.type.Vec3f.normalize(targetPos - ufoSpawnPos)
    local yaw = vec2fToYaw(api.type.Vec2f.new(dirToTarget.x, dirToTarget.y))
    local transfUfo = api.type.Mat4f.rotZTransl(yaw, ufoSpawnPos)

    local cowModel = COW_MODELS[math.random(1, #COW_MODELS)]
    local transfCow = api.type.Mat4f.transl(cowPos)

    spawnCustomModel(cowModel, transfCow, function(cowEnt)
        spawnCustomModel(UFO_MODEL, transfUfo, function(ufoEnt)
            local ufoData = {
                ufoEntity = ufoEnt,
                cowEntity = cowEnt,
                state = "Approach",
                velocity = dirToTarget * MAX_SPEED,
                target = targetPos,
                abductSpeed = 0,
            }
            table.insert(myUfos, ufoData)

            -- Automatically focus camera and track target!
            M.focusEntity(cowEnt)

            if callback then
                callback(ufoData)
            end
        end)
    end)

    return { targetPos = cowPos, hasFarm = hasFarm }
end

function M.getLastNotice()
    return lastNotice
end

return M
