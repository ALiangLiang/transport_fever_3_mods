-- ==============================================================================
-- UFO Summoner Simulation Script (Engine Simulation & GUI Bridge)
-- Pure official ufo_util integration with no GUI dependencies
-- ==============================================================================

local sim = {}

local ufo_util = nil
local liveUfosGui = {}

local function getUfoUtil()
    if ufo_util then return ufo_util end
    for _, path in ipairs({
        "::/game_mechanics/fun_elements/ufo_util.tl",
        "game_mechanics/fun_elements/ufo_util.tl",
        "/game_mechanics/fun_elements/ufo_util.tl",
        "ufo_util.tl",
    }) do
        pcall(function()
            if ug_require then ufo_util = ug_require(path) end
            if not ufo_util and require then ufo_util = require(path) end
        end)
        if ufo_util then break end
    end
    return ufo_util
end

local function spawnOfficialUfo(state)
    local uu = getUfoUtil()
    if not uu or not uu.spawnNew then
        local warn = "[UfoSummoner] Failed to load official ufo_util module"
        if log and log.warning then log.warning(warn) else print(warn) end
        return false
    end

    local spawned = false
    local ok, res = pcall(function()
        return uu.spawnNew(function(ufoData)
            local s = state:get() or {}
            s.ufos = s.ufos or {}
            table.insert(s.ufos, ufoData)
            state:set(s)

            local uId = (type(ufoData.ufoEntity) == "table" and ufoData.ufoEntity.entity) or ufoData.ufoEntity
            local cId = (type(ufoData.cowEntity) == "table" and ufoData.cowEntity.entity) or ufoData.cowEntity
            local msg = string.format("[UfoSummoner] Official UFO spawned: UFO=%s, Cow=%s, totalActive=%d", tostring(uId), tostring(cId), #s.ufos)
            if log and log.message then log.message(msg) else print(msg) end

            -- Attach CustomState so GUI can immediately query and display active UFO
            pcall(function()
                if uId and api and api.cmd and api.cmd.makeCustomEntityUpdateStateCmd then
                    api.cmd.sendCommand(
                        api.cmd.makeCustomEntityUpdateStateCmd(uId, {
                            state = {
                                type = "Ufo",
                                ufoEntity = uId,
                                cowEntity = cId,
                                state = ufoData.state or "Approach",
                            }
                        })
                    )
                end
            end)
        end)
    end)

    if not ok then
        local warn = "[UfoSummoner] Error calling official spawnNew: " .. tostring(res)
        if log and log.warning then log.warning(warn) else print(warn) end
    elseif res == false then
        local warn = "[UfoSummoner] Official spawnNew returned false: No pasture with cattle found on map!"
        if log and log.warning then log.warning(warn) else print(warn) end
    else
        spawned = true
        local msg = "[UfoSummoner] Official UFO successfully spawned at cow pasture!"
        if log and log.message then log.message(msg) else print(msg) end
    end

    return spawned
end

function sim.update(userParams, state, dt)
    if not state:hasEventSubscriptions() then
        state:subscribeToEvent("spawnUfo")
    end
    if dt == 0.0 then return end

    local s = state:get()
    if s and s.ufos and #s.ufos > 0 then
        local uu = getUfoUtil()
        local toRemove = {}
        for i = 1, #s.ufos do
            local despawn = false
            local uEntry = s.ufos[i]
            if uu and uu.update and uEntry and uEntry.ufoEntity then
                local uId = (type(uEntry.ufoEntity) == "table" and uEntry.ufoEntity.entity) or uEntry.ufoEntity
                if uId and api and api.engine and api.engine.entityExists and not api.engine.entityExists(uId) then
                    despawn = true
                else
                    local oldState = uEntry.state
                    local ok, res = pcall(uu.update, uEntry, dt)
                    if ok then
                        despawn = res
                        if uEntry.state ~= oldState and uId and api.cmd.makeCustomEntityUpdateStateCmd then
                            pcall(function()
                                api.cmd.sendCommand(
                                    api.cmd.makeCustomEntityUpdateStateCmd(uId, {
                                        state = {
                                            type = "Ufo",
                                            ufoEntity = uId,
                                            cowEntity = (type(uEntry.cowEntity) == "table" and uEntry.cowEntity.entity) or uEntry.cowEntity,
                                            state = uEntry.state,
                                        }
                                    })
                                )
                            end)
                        end
                    else
                        despawn = true
                    end
                end
            else
                despawn = true
            end
            if despawn then
                table.insert(toRemove, i)
            end
        end
        if #toRemove > 0 then
            for i = #toRemove, 1, -1 do
                table.remove(s.ufos, toRemove[i])
            end
        end
        state:set(s)
    end
end

local cachedCoreModule = nil
local function getCoreModule()
    if cachedCoreModule ~= nil then return cachedCoreModule end
    for _, path in ipairs({
        "aliangliang_ufo_summoner::/ufo_summoner.lua",
        "/ufo_summoner.lua",
        "ufo_summoner.lua",
    }) do
        local ok, m = pcall(function()
            if ug_require then return ug_require(path) end
            return require(path)
        end)
        if ok and m and type(m) == "table" and m.setLiveUfos then
            cachedCoreModule = m
            return cachedCoreModule
        end
    end
    return nil
end

-- Called every frame by engine on the GUI thread to sync simulation state to GUI
function sim.guiUpdate(userParams, state, guiState)
    pcall(function()
        local s = (state and state.get and state:get()) or nil
        local ufos = (s and s.ufos) or {}
        liveUfosGui = ufos

        local c = getCoreModule()
        if c and c.setLiveUfos then
            c.setLiveUfos(ufos)
        end
    end)
end

function sim.getLiveUfos()
    return liveUfosGui or {}
end

function sim.handleEvent(userParams, state, src, id, name, param)
    if name == "spawnUfo" or (id == "UfoSummoner" and name == "summon") then
        local msg = "[UfoSummoner] Received summon command, invoking official ufo_util.spawnNew..."
        if log and log.message then log.message(msg) else print(msg) end
        spawnOfficialUfo(state)
    end
end

function sim.save(state)
    return state:get() or {}
end

function sim.load(state, loadedData)
    if loadedData then
        state:set(loadedData)
    end
end

function data()
    return sim
end

return sim
