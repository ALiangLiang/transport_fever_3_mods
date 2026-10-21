-- ==============================================================================
-- Connoisseur Tracker Core / 鑑賞家成就追蹤與載具數據核心
-- ==============================================================================

local M = {}

local STAT_KEY = "STAT_USED_VEHICLE_TYPES"
local ACH_KEY = "ACH_ALL_VEHICLES"

local allVehiclesCache = nil
local lastScanTime = 0

-- Check if a resource name represents an official base game vehicle
local function isDefaultVehicle(resName)
    if not resName or type(resName) ~= "string" then return false end
    local clean = resName:gsub("\\", "/")
    if clean:sub(1, 10) == "::/vehicle" then return true end
    if clean:sub(1, 8) == "vehicle/" then return true end
    if clean:sub(1, 9) == "/vehicle/" then return true end
    if clean:sub(1, 3) == "::/" and clean:sub(4, 11) == "vehicle/" then return true end
    if not clean:find("::", 1, true) and clean:find("^/?vehicle/") then return true end
    return false
end

local function normalizeResName(resName)
    if not resName or type(resName) ~= "string" then return "" end
    local clean = resName:gsub("\\", "/")
    if clean:sub(1, 10) == "::/vehicle" then return clean end
    if clean:sub(1, 9) == "/vehicle/" then return "::" .. clean end
    if clean:sub(1, 8) == "vehicle/" then return "::/" .. clean end
    return clean
end

M.isDefaultVehicle = isDefaultVehicle
M.normalizeResName = normalizeResName

-- Map carrier enum to category key
local function getCarrierCategory(carrier)
    if not carrier then return "OTHER" end
    if api and api.type and api.type["enum"] and api.type["enum"].Carrier then
        local C = api.type["enum"].Carrier
        if carrier == C.RAIL then return "RAIL" end
        if carrier == C.ROAD then return "ROAD" end
        if carrier == C.TRAM then return "TRAM" end
        if carrier == C.WATER then return "WATER" end
        if carrier == C.AIR then return "AIR" end
    end
    local s = tostring(carrier):upper()
    if s:find("RAIL") then return "RAIL"
    elseif s:find("ROAD") then return "ROAD"
    elseif s:find("TRAM") then return "TRAM"
    elseif s:find("WATER") then return "WATER"
    elseif s:find("AIR") then return "AIR"
    end
    return "OTHER"
end

-- Get current dictionary of all used vehicles from achievements persistent extra data
function M.getUsedVehicleMap()
    local usedMap = {}
    pcall(function()
        if api and api.gui and api.gui.achievements and api.gui.achievements.getStatExtraData then
            local data = api.gui.achievements.getStatExtraData(STAT_KEY)
            if data and type(data) == "table" then
                usedMap = data
            end
        end
    end)
    return usedMap
end

-- Scan and cache all official transport vehicles in the game
function M.getAllDefaultVehicles(forceRescan)
    local now = os.clock()
    if allVehiclesCache and not forceRescan and (now - lastScanTime < 60) then
        return allVehiclesCache
    end

    local vehicles = {}
    pcall(function()
        if not (api and api.res and api.res.modelRep and api.res.modelRep.forEachModelWithMetadata) then
            return
        end

        api.res.modelRep.forEachModelWithMetadata("transportVehicle", function(resName)
            if isDefaultVehicle(resName) then
                local modelId = api.res.modelRep.find(resName)
                if modelId and modelId >= 0 then
                    local model = api.res.modelRep.get(modelId)
                    if model and model.metadata then
                        local desc = model.metadata.description
                        local avail = model.metadata.availability
                        local tv = model.metadata.transportVehicle

                        local displayName = (desc and desc.name and #desc.name > 0) and desc.name or resName
                        local icon = (desc and desc.iconSmall and #desc.iconSmall > 0) and desc.iconSmall or ""
                        local yearFrom = (avail and avail.yearFrom) and avail.yearFrom or 1850
                        local yearTo = (avail and avail.yearTo) and avail.yearTo or 0
                        local carrier = tv and tv.carrier

                        table.insert(vehicles, {
                            resName = resName,
                            name = displayName,
                            icon = icon,
                            yearFrom = yearFrom,
                            yearTo = yearTo,
                            carrier = carrier,
                            category = getCarrierCategory(carrier),
                        })
                    end
                end
            end
        end)
    end)

    -- Sort chronologically by yearFrom, then alphabetically by name
    table.sort(vehicles, function(a, b)
        if a.yearFrom ~= b.yearFrom then
            return a.yearFrom < b.yearFrom
        end
        return a.name < b.name
    end)

    allVehiclesCache = vehicles
    lastScanTime = now
    return allVehiclesCache
end

-- Get comprehensive progress data
function M.getProgressData()
    local all = M.getAllDefaultVehicles()
    local usedMap = M.getUsedVehicleMap()

    local total = #all
    local usedCount = 0
    local vehiclesWithStatus = {}

    for _, v in ipairs(all) do
        local isUsed = (usedMap[v.resName] == true) or (usedMap[M.normalizeResName(v.resName)] == true)
        if isUsed then
            usedCount = usedCount + 1
        end

        table.insert(vehiclesWithStatus, {
            resName = v.resName,
            name = v.name,
            icon = v.icon,
            yearFrom = v.yearFrom,
            yearTo = v.yearTo,
            carrier = v.carrier,
            category = v.category,
            isUsed = isUsed,
        })
    end

    local percent = total > 0 and math.floor((usedCount / total) * 1000) / 10 or 0
    local isUnlocked = false
    pcall(function()
        if api and api.gui and api.gui.achievements and api.gui.achievements.isAchievementUnlocked then
            isUnlocked = api.gui.achievements.isAchievementUnlocked(ACH_KEY)
        end
    end)

    return {
        vehicles = vehiclesWithStatus,
        total = total,
        usedCount = usedCount,
        unusedCount = total - usedCount,
        percent = percent,
        isUnlocked = isUnlocked,
    }
end

-- Check if a vehicle store item is already used
-- Accepts either full element ({ static = ... }) or elemStatic directly
-- Returns true if used or non-default, false if uncollected official vehicle
function M.isStoreElementUsed(elemOrStatic, usedMap)
    if not elemOrStatic then return true end
    local elemStatic = elemOrStatic
    if elemOrStatic.static and type(elemOrStatic.static) == "table" then
        elemStatic = elemOrStatic.static
    end
    if not elemStatic then return true end

    local map = usedMap or M.getUsedVehicleMap()
    if not map then return true end

    local cleanName = elemStatic.name
    if type(cleanName) == "string" then
        cleanName = cleanName:gsub("%s*%[未使用過%]", ""):gsub("%s*%[未使用过%]", ""):gsub("%s*%[Unused%]", ""):gsub("%s*%[未鑑賞%]", ""):gsub("%s*%[Uncollected%]", ""):gsub("%s*%[未鉴赏%]", "")
    end

    if elemStatic.multipleUnit then
        local ok, mu = pcall(function()
            return api.res.multipleUnitRep.get(elemStatic.repId)
        end)
        if ok and mu and mu.vehicles then
            local hasDefaultComponent = false
            for _, v in ipairs(mu.vehicles) do
                local vName = v.name
                if isDefaultVehicle(vName) then
                    hasDefaultComponent = true
                    local normName = normalizeResName(vName)
                    local strippedName = vName:gsub("^::/", ""):gsub("^/", "")
                    local isUsed = (map[normName] == true) or (map[vName] == true) or (map[strippedName] == true)
                    if not isUsed then
                        return false -- At least one official component has not been used!
                    end
                end
            end
            if not hasDefaultComponent then
                return true -- Pure mod multiple unit, does not affect achievement
            end
        end
        return true
    else
        local modelName = elemStatic.path
        if not modelName or modelName == "" then
            pcall(function()
                modelName = api.res.modelRep.getName(elemStatic.repId)
            end)
        end

        if modelName and isDefaultVehicle(modelName) then
            local normName = normalizeResName(modelName)
            local strippedName = modelName:gsub("^::/", ""):gsub("^/", "")
            local isUsed = (map[normName] == true) or (map[modelName] == true) or (map[strippedName] == true)
            if not isUsed and cleanName then
                isUsed = (map[cleanName] == true)
            end
            return isUsed
        end
        return true -- Non-default mod vehicles do not count toward the achievement
    end
end

return M
