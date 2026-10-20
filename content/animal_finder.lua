-- ==============================================================================
-- Animal Radar Core Engine / 動物雷達 核心運算與 ECS 資料提取
-- ==============================================================================

local AnimalFinder = {}

-- Mod Configuration and State
local config = {
    followMode = true, -- true = Follow & Track, false = Focus Only
}

local state = {
    animals = {},            -- Cached list of animal data tables
    lastScanTime = 0,
    selectedEntity = nil,
}

-- Safe i18n translation using TF engine global _() backed by strings.json
local function tr(key)
    if not key or key == "" then return "" end
    if _ and type(_) == "function" then
        local ok, val = pcall(_, key)
        if ok and val and #val > 0 then
            return val
        end
    end
    return key
end

-- Resolve species display name using game engine API first, then i18n
local function resolveSpeciesName(modelId, modelPath)
    -- 1. Query modelRep metadata via Engine API
    if modelId and api and api.res and api.res.modelRep and api.res.modelRep.get then
        local ok, modelDesc = pcall(api.res.modelRep.get, modelId)
        if ok and modelDesc and modelDesc.metadata then
            local meta = modelDesc.metadata
            -- Check flockName in animal metadata (e.g. "Discus Fish School", "Salmon School", "Cranes Flock")
            if meta.animal and meta.animal.flockName and #meta.animal.flockName > 0 then
                return tr(meta.animal.flockName)
            end
            -- Check standard model description name (e.g. "Deer", "Bear", "Fox", "Wolf", "Eagle", "Crane", "Cougar")
            if meta.description and meta.description.name and #meta.description.name > 0 then
                return tr(meta.description.name)
            end
            -- Check idForAchievement (e.g. "animal/cr_fish")
            if meta.animal and meta.animal.idForAchievement and #meta.animal.idForAchievement > 0 then
                local achKey = string.match(meta.animal.idForAchievement, "([^/\\]+)$") or meta.animal.idForAchievement
                return tr(achKey)
            end
        end
    end

    -- 2. Derive species identifier from actual model path
    if modelPath and #modelPath > 0 then
        local p = modelPath:gsub("\\", "/"):lower()

        if p:find("wildlife_bear") or p:find("/bear") then return tr("Bear") end
        if p:find("wildlife_deer") or p:find("/deer") then return tr("Deer") end
        if p:find("wildlife_fox") or p:find("/fox") then return tr("Fox") end
        if p:find("/wolf") then return tr("Wolf") end
        if p:find("bird_eagle") or p:find("/eagle") then return tr("Eagle") end
        if p:find("bird_crane") or p:find("/crane") then return tr("Crane") end
        if p:find("bird_gull") or p:find("/gull") then return tr("Gull") end
        if p:find("/seagull") then return tr("Seagull") end
        if p:find("/cougar") then return tr("Cougar") end
        if p:find("/draft_horse") then return tr("Draft Horse") end
        if p:find("/horse") then return tr("Horse") end
        if p:find("/cow") then return tr("Cow") end
        if p:find("/sheep") then return tr("Sheep") end
        if p:find("fish_salmon") or p:find("/salmon") then return tr("Salmon") end
        if p:find("cr_fish") or p:find("/discus") then return tr("Discus Fish") end

        local parentDir = string.match(p, "animal/([^/]+)")
        if parentDir then
            return tr(parentDir)
        end

        local baseName = string.match(p, "([^/]+)%.mdl$") or p
        local normalized = baseName:gsub("_%d+$", ""):gsub("_idle$", ""):gsub("_prod_%a+$", "")
        return tr(normalized)
    end

    return tr("Animal")
end

-- Safe helper to get ComponentType enum from either api.type or api.engine
local function getComponentType()
    if api then
        if api.type and api.type.ComponentType then return api.type.ComponentType end
        if api.engine and api.engine.ComponentType then return api.engine.ComponentType end
        if api.ComponentType then return api.ComponentType end
    end
    if ComponentType then return ComponentType end
    return nil
end

-- Helper to safely extract modelId from ModelInstanceList component
local function extractModelId(mdlList)
    if not mdlList then return nil end

    -- 1. Check fatInstances table
    local ok1, id1 = pcall(function()
        if mdlList.fatInstances and mdlList.fatInstances[1] then
            return mdlList.fatInstances[1].modelId
        end
    end)
    if ok1 and id1 and type(id1) == "number" and id1 >= 0 then
        return id1
    end

    -- 2. Check thinInstances table
    local ok2, id2 = pcall(function()
        if mdlList.thinInstances and mdlList.thinInstances[1] then
            return mdlList.thinInstances[1].modelId
        end
    end)
    if ok2 and id2 and type(id2) == "number" and id2 >= 0 then
        return id2
    end

    -- 3. Check native vector fatInstances_native
    local ok3, id3 = pcall(function()
        if mdlList.fatInstances_native and mdlList.fatInstances_native.size and mdlList.fatInstances_native:size() > 0 then
            local inst = mdlList.fatInstances_native:get(0)
            return inst and inst.modelId
        end
    end)
    if ok3 and id3 and type(id3) == "number" and id3 >= 0 then
        return id3
    end

    -- 4. Check native vector thinInstances_native
    local ok4, id4 = pcall(function()
        if mdlList.thinInstances_native and mdlList.thinInstances_native.size and mdlList.thinInstances_native:size() > 0 then
            local inst = mdlList.thinInstances_native:get(0)
            return inst and inst.modelId
        end
    end)
    if ok4 and id4 and type(id4) == "number" and id4 >= 0 then
        return id4
    end

    return nil
end

-- Extract animal details for a given entity
local function inspectAnimalEntity(entity)
    local item = {
        entity = entity,
        species = tr("Animal"),
        worldPos = nil,
        modelPath = nil,
        modelId = nil,
    }

    local compType = getComponentType()
    if api and api.engine and api.engine.getComponent and compType then
        -- 1. Read Animal Component for world position
        if compType.ANIMAL then
            local ok, animalComp = pcall(api.engine.getComponent, entity, compType.ANIMAL)
            if ok and animalComp and animalComp.worldPosition then
                item.worldPos = animalComp.worldPosition
            end
        end

        -- 2. Read ModelInstanceList to detect model ID and path
        if compType.MODEL_INSTANCE_LIST then
            local ok, mdlList = pcall(api.engine.getComponent, entity, compType.MODEL_INSTANCE_LIST)
            if ok and mdlList then
                local mId = extractModelId(mdlList)
                if mId then
                    item.modelId = mId
                    if api.res and api.res.modelRep and api.res.modelRep.getName then
                        local okName, path = pcall(api.res.modelRep.getName, mId)
                        if okName and path and #path > 0 then
                            item.modelPath = path
                        end
                    end
                end
            end
        end
    end

    -- 3. Resolve display name through Engine API and i18n
    item.species = resolveSpeciesName(item.modelId, item.modelPath)

    return item
end

-- Scan all animal entities across the entire map
function AnimalFinder.scanAnimals()
    local entities = {}
    local seen = {}

    -- Strategy 1: system.animalMoveSystem.forEach
    if api and api.engine and api.engine.system and api.engine.system.animalMoveSystem and api.engine.system.animalMoveSystem.forEach then
        pcall(function()
            api.engine.system.animalMoveSystem.forEach(function(e)
                if e and not seen[e] then
                    seen[e] = true
                    table.insert(entities, e)
                end
            end)
        end)
    end

    local compType = getComponentType()

    -- Strategy 2: forEachEntityWithComponent(ComponentType.ANIMAL)
    if #entities == 0 and api and api.engine and api.engine.forEachEntityWithComponent and compType and compType.ANIMAL then
        pcall(function()
            api.engine.forEachEntityWithComponent(function(e)
                if e and not seen[e] then
                    seen[e] = true
                    table.insert(entities, e)
                end
            end, compType.ANIMAL)
        end)
    end

    -- Strategy 3: getEntitiesWithComponent(ComponentType.ANIMAL, {})
    if #entities == 0 and api and api.engine and api.engine.getEntitiesWithComponent and compType and compType.ANIMAL then
        pcall(function()
            local list = api.engine.getEntitiesWithComponent(compType.ANIMAL, {})
            if list then
                for _, e in ipairs(list) do
                    if e and not seen[e] then
                        seen[e] = true
                        table.insert(entities, e)
                    end
                end
            end
        end)
    end

    local result = {}
    for _, entity in ipairs(entities) do
        local ok, data = pcall(inspectAnimalEntity, entity)
        if ok and data then
            table.insert(result, data)
        end
    end

    -- Sort by species name, then by entity ID
    table.sort(result, function(a, b)
        if a.species ~= b.species then
            return a.species < b.species
        end
        return a.entity < b.entity
    end)

    state.animals = result
    state.lastScanTime = os.clock()
    return result
end

function AnimalFinder.getAnimals()
    if #state.animals == 0 or (os.clock() - state.lastScanTime > 3.0) then
        return AnimalFinder.scanAnimals()
    end
    return state.animals
end

-- Move and focus camera to the specified animal
function AnimalFinder.focusAnimal(entity, worldPos)
    state.selectedEntity = entity

    pcall(function()
        if not (api and api.gui and api.gui.camera) then return end

        if config.followMode and api.gui.camera.followEntity then
            api.gui.camera.followEntity(entity)
        elseif worldPos and api.gui.camera.lookAt then
            api.gui.camera.lookAt(worldPos)
        elseif api.gui.camera.focusEntity then
            api.gui.camera.focusEntity(entity)
        end
    end)
end

function AnimalFinder.toggleFollowMode()
    config.followMode = not config.followMode
    return config.followMode
end

function AnimalFinder.getFollowMode()
    return config.followMode
end

return AnimalFinder
