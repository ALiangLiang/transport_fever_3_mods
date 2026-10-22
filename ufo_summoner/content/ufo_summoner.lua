-- ==============================================================================
-- UFO Summoner Helper Module / 幽浮召喚輔助工具庫
-- Pure helper utilities for camera tracking and UFO state retrieval
-- ==============================================================================

local M = {}

local cachedHasFarm = nil
local lastFarmCheckTime = 0

-- Fast check if any livestock farm exists on the map (cached for 10s, early-exit)
function M.hasLivestockFarm()
    local now = os.clock()
    if cachedHasFarm ~= nil and (now - lastFarmCheckTime < 10.0) then
        return cachedHasFarm
    end
    lastFarmCheckTime = now
    local found = false
    if api and api.engine and api.engine.forEachEntityWithComponent then
        pcall(function()
            api.engine.forEachEntityWithComponent(function(industryEntity)
                if found then return end
                local industry = api.engine.getComponent(industryEntity, api.type.ComponentType.INDUSTRY)
                if industry and industry.construction then
                    local construction = api.engine.getComponent(industry.construction, api.type.ComponentType.CONSTRUCTION)
                    if construction and construction.fileName and string.find(construction.fileName, "livestock_farm") then
                        found = true
                    end
                end
            end, api.type.ComponentType.INDUSTRY)
        end)
    end
    cachedHasFarm = found
    return found
end

local function toEntityId(ent)
    if type(ent) == "table" and ent.entity then
        return ent.entity
    elseif type(ent) == "number" then
        return ent
    end
    return nil
end

local function getEntityTransf(entity)
    local id = toEntityId(entity)
    if not id or id <= 0 then return nil end
    local transf = nil
    pcall(function()
        local mil = api.engine.getComponent(id, api.type.ComponentType.MODEL_INSTANCE_LIST)
        if mil and mil.fatInstances and mil.fatInstances[1] then
            transf = mil.fatInstances[1].transf
        end
    end)
    return transf
end

-- Move and focus camera to world position
function M.focusPosition(pos, zoom)
    if not pos then return end
    pcall(function()
        if not (api and api.gui and api.gui.camera) then return end
        local z = zoom or 50
        if api.gui.camera.focusPosition then
            api.gui.camera.focusPosition(pos, z)
        elseif api.gui.camera.lookAt then
            api.gui.camera.lookAt(pos)
        end
    end)
end

local liveUfosFromGui = {}
local pendingSummons = {}

function M.setLiveUfos(ufos)
    liveUfosFromGui = ufos or {}
end

function M.recordPendingSummon()
    table.insert(pendingSummons, {
        time = os.clock(),
        state = "Approach",
    })
end

local function isEntityValid(entId)
    if not entId or entId < 0 then return false end
    if entId == 0 then return true end
    if api and api.engine and api.engine.entityExists then
        local ok, exists = pcall(api.engine.entityExists, entId)
        if ok then return exists end
    end
    if api and api.engine and api.engine.getComponent then
        local ok, comp = pcall(api.engine.getComponent, entId, api.type.ComponentType.MODEL_INSTANCE_LIST)
        if ok and comp ~= nil then return true end
    end
    return true
end

-- Focus camera on entity
function M.focusEntity(entity)
    local id = toEntityId(entity)
    if not id or id <= 0 then return end
    pcall(function()
        if not (api and api.gui and api.gui.camera) then return end

        local transf = getEntityTransf(id)
        if transf then
            local pos = transf:getTransl()
            if api.gui.camera.focusPosition then
                api.gui.camera.focusPosition(pos, 50)
            elseif api.gui.camera.lookAt then
                api.gui.camera.lookAt(pos)
            end
        end
    end)
end

local cachedActiveUfos = {}
local lastActiveUfosScan = 0
local cachedGsEntity = nil
local cachedGsName = nil
local cachedSimModule = false
local cachedFeUtil = false

-- Get list of all active official UFOs currently in the game world
function M.getActiveUfos(force)
    local now = os.clock()
    if not force and (now - lastActiveUfosScan < 0.3) then
        return cachedActiveUfos
    end
    lastActiveUfosScan = now

    local result = {}
    local seen = {}

    local function addUfo(ufoData, src)
        if not ufoData then return end
        local uId = toEntityId(ufoData.ufoEntity) or (ufoData.isPending and 0)
        local cId = toEntityId(ufoData.cowEntity)
        if uId and (uId == 0 or (not seen[uId] and isEntityValid(uId))) then
            if uId > 0 then seen[uId] = true end
            table.insert(result, {
                ufoEntity = uId,
                cowEntity = cId,
                state = ufoData.state or "Approach",
                isPending = (uId == 0 or ufoData.isPending == true),
                source = src or "official",
            })
        end
    end

    -- 1. Check live UFOs pushed directly via sim.guiUpdate
    if liveUfosFromGui and #liveUfosFromGui > 0 then
        for _, u in ipairs(liveUfosFromGui) do
            addUfo(u, "gui_update_push")
        end
    end

    -- 2. Query GameScript component via GameScriptSystem (Urban Games official pattern)
    pcall(function()
        if not (api and api.engine and api.engine.system and api.engine.system.gameScriptSystem) then return end
        if cachedGsEntity and cachedGsEntity >= 0 then
            local comp = api.engine.getComponent(cachedGsEntity, api.type.ComponentType.GAME_SCRIPT)
            if comp and comp.state and comp.state.ufos and #comp.state.ufos > 0 then
                for _, u in ipairs(comp.state.ufos) do
                    addUfo(u, "gs_cached")
                end
                return
            end
        end

        local gsNames = {
            "aliangliang_ufo_summoner::/ufo_summoner.gs",
            "::/ufo_summoner.gs",
            "aliangliang_ufo_summoner::ufo_summoner.gs",
            "aliangliang_ufo_summoner::/content/ufo_summoner.gs",
            "ufo_summoner.gs",
            "aliangliang_ufo_summoner::/ufo_summoner.gs.lua",
            "::/game_mechanics/fun_elements/fun_elements.gs",
        }
        for _, name in ipairs(gsNames) do
            local ok, gsEnt = pcall(api.engine.system.gameScriptSystem.getEntityForGameScript, name)
            if ok and gsEnt and gsEnt >= 0 then
                cachedGsEntity = gsEnt
                cachedGsName = name
                local comp = api.engine.getComponent(gsEnt, api.type.ComponentType.GAME_SCRIPT)
                if comp and comp.state and comp.state.ufos and #comp.state.ufos > 0 then
                    for _, u in ipairs(comp.state.ufos) do
                        addUfo(u, "gs_system:" .. name)
                    end
                end
                break
            end
        end
    end)

    -- 3. Check live UFOs synced via module export (cached once)
    if cachedSimModule == false then
        cachedSimModule = nil
        pcall(function()
            for _, path in ipairs({
                "aliangliang_ufo_summoner::/ufo_summoner_sim.script",
                "ufo_summoner_sim.script",
            }) do
                local ok, m = pcall(function()
                    if ug_require then return ug_require(path) end
                    return require(path)
                end)
                if ok and m and type(m) == "table" and m.getLiveUfos then
                    cachedSimModule = m
                    break
                end
            end
        end)
    end
    if cachedSimModule and cachedSimModule.getLiveUfos then
        local ufos = cachedSimModule.getLiveUfos()
        if ufos and #ufos > 0 then
            for _, u in ipairs(ufos) do
                addUfo(u, "module_sync")
            end
        end
    end

    -- 4. Check official fun_elements_util (cached once)
    if cachedFeUtil == false then
        cachedFeUtil = nil
        pcall(function()
            for _, path in ipairs({
                "::/game_mechanics/fun_elements/fun_elements_util.tl",
                "game_mechanics/fun_elements/fun_elements_util.tl",
            }) do
                pcall(function()
                    if ug_require then cachedFeUtil = ug_require(path) end
                    if not cachedFeUtil and require then cachedFeUtil = require(path) end
                end)
                if cachedFeUtil then break end
            end
        end)
    end
    if cachedFeUtil and cachedFeUtil.externalGetFunElementsState then
        local feState = cachedFeUtil.externalGetFunElementsState()
        if feState and feState.ufos and #feState.ufos > 0 then
            for _, u in ipairs(feState.ufos) do
                addUfo(u, "fun_elements_util")
            end
        end
    end

    -- 5. If real UFO entities are active, clear pending list
    if #result > 0 then
        pendingSummons = {}
    else
        -- Check pending summons (within 10 seconds of summon button click)
        local validPending = {}
        for _, p in ipairs(pendingSummons) do
            if now - p.time <= 10.0 then
                table.insert(validPending, p)
            end
        end
        pendingSummons = validPending
        if #pendingSummons > 0 then
            table.insert(result, {
                ufoEntity = 0,
                cowEntity = nil,
                state = "Approach",
                isPending = true,
                source = "pending_summon",
            })
        end
    end

    cachedActiveUfos = result
    return result
end

return M
