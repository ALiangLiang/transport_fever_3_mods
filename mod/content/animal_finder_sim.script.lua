-- ==============================================================================
-- Animal Radar Simulation Script (Engine Thread Safe)
-- No GUI or React dependencies here to ensure 100% stability on sim threads
-- ==============================================================================

local sim = {}

function sim.update(userParams, state, dt)
end

function sim.handleEvent(userParams, state, src, id, name, param)
end

function sim.save(state)
    return {}
end

function sim.load(state, loadedData)
end

function data()
    return sim
end

return sim
