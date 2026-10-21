-- ==============================================================================
-- Connoisseur Tracker Vehicle Store Replacement & Hook
-- 鑑賞家追蹤器 載具商店標記替換機制
-- ==============================================================================

local react = ug_require and ug_require("::/gui/main/react.lua") or require("/gui/main/react.lua")
local builtin = ug_require and ug_require("::/gui/main/builtin.lua") or require("/gui/main/builtin.lua")

local M = {}

-- Backend core loader
local core = nil
local function getCore()
    if core == nil then
        for _, path in ipairs({
            "aliangliang_connoisseur_tracker::/connoisseur_tracker.lua",
            "/connoisseur_tracker.lua",
            "content.connoisseur_tracker",
            "connoisseur_tracker.lua",
        }) do
            local ok, res = pcall(function()
                if ug_require then return ug_require(path) end
                return require(path)
            end)
            if ok and res and type(res) == "table" and res.isStoreElementUsed then
                core = res
                break
            end
        end
    end
    return core
end

-- Safe gettext translation helper querying TF3 strings.json
local function _tr(key, default)
    if _ and type(_) == "function" then
        local ok, res = pcall(_, key)
        if ok and res and res ~= key and #res > 0 then
            return res
        end
    end
    return default or key
end

-- Track hooked recipe IDs to prevent double hooking
local hookedRecipeIds = {}

-- Scan _react.recipes for recipe names and IDs via closure upvalue inspection
local function scanRecipeIds()
    local nameToId = {}
    if _react and _react.recipes and debug and debug.getupvalue then
        for id, closure in pairs(_react.recipes) do
            if type(closure) == "function" then
                local i = 1
                while true do
                    local n, v = debug.getupvalue(closure, i)
                    if not n then break end
                    if n == "name" and type(v) == "string" then
                        nameToId[v] = id
                        break
                    end
                    i = i + 1
                end
            end
        end
    end
    return nameToId
end

-- Tag all unused official vehicles in repId2elementStatic
local function tagStaticVehicles(repId2elementStatic)
    if not repId2elementStatic then return end
    local c = getCore()
    local usedMap = c and c.getUsedVehicleMap() or {}
    local badge = _tr("BADGE_NOT_USED", "[未使用過]")

    for repId, elemStatic in pairs(repId2elementStatic) do
        local isUsed = true
        if c then
            isUsed = c.isStoreElementUsed(elemStatic, usedMap)
        end
        local origName = elemStatic.name or ""
        if not isUsed then
            if not origName:find(badge, 1, true) then
                elemStatic.name = origName .. " " .. badge
            end
        else
            elemStatic.name = origName:gsub("%s*%[未使用過%]", ""):gsub("%s*%[未鑑賞%]", ""):gsub("%s*%[Unused%]", ""):gsub("%s*%[Uncollected%]", "")
        end
    end
end

-- Install hooks on vehicle store recipes
function M.installHooks(replacementApi)
    print("[Connoisseur Tracker] Installing vehicle store hooks...")

    -- 1. Ensure target vehicle store modules are loaded
    local vehicle_store_window = nil
    pcall(function()
        if ug_require then
            vehicle_store_window = ug_require("/gui/line_vehicle_mgmt/vehicle_store_window.tl")
            ug_require("/gui/line_vehicle_mgmt/vehicle_store_table.tl")
        else
            vehicle_store_window = require("/gui/line_vehicle_mgmt/vehicle_store_window.tl")
            require("/gui/line_vehicle_mgmt/vehicle_store_table.tl")
        end
    end)

    -- 2. Wrap vehicle_store_window.VehicleStoreWindow via replacementApi if available
    if vehicle_store_window and vehicle_store_window.VehicleStoreWindow and replacementApi and replacementApi.ReplaceRecipe then
        pcall(function()
            local ConnoisseurVehicleStoreWindow = react.RegisterWrapperRecipe("ConnoisseurVehicleStoreWindow", builtin.Window, function(params)
                if params and params.vehiclesStaticData and params.vehiclesStaticData.repId2elementStatic then
                    tagStaticVehicles(params.vehiclesStaticData.repId2elementStatic)
                end
                return react.CallOriginalRecipe(vehicle_store_window.VehicleStoreWindow, params)
            end)
            replacementApi.ReplaceRecipe(vehicle_store_window.VehicleStoreWindow, ConnoisseurVehicleStoreWindow)
            print("[Connoisseur Tracker] Successfully replaced VehicleStoreWindow via replacementApi")
        end)
    end

    -- 3. Dynamic scan of _react.recipes for VehicleName, DetailsTitle, VehicleNameCell, and VehicleStoreWindow
    local nameToId = scanRecipeIds()

    -- Hook "VehicleName" (Split View vehicle card name on the left list)
    if nameToId["VehicleName"] and not hookedRecipeIds[nameToId["VehicleName"]] then
        local id = nameToId["VehicleName"]
        local origFn = _react.originalRecipeFn[id]
        if origFn then
            local VehicleNameReplacement = react.RegisterRecipe("ConnoisseurVehicleNameReplacement", function(param)
                local c = getCore()
                local isUsed = true
                if c and param and param.elemStatic then
                    isUsed = c.isStoreElementUsed(param.elemStatic)
                end

                if not isUsed and param and param.elemStatic then
                    local badge = _tr("BADGE_NOT_USED", "[未使用過]")
                    local origName = param.elemStatic.name or ""
                    if not origName:find(badge, 1, true) then
                        local modifiedStatic = {}
                        for k, v in pairs(param.elemStatic) do
                            modifiedStatic[k] = v
                        end
                        modifiedStatic.name = origName .. " " .. badge

                        local modifiedParam = {}
                        for k, v in pairs(param) do
                            modifiedParam[k] = v
                        end
                        modifiedParam.elemStatic = modifiedStatic

                        return origFn(modifiedParam)
                    end
                end

                return origFn(param)
            end)

            if _react and _react.recipeReplace then
                _react.recipeReplace[id] = VehicleNameReplacement
            end
            hookedRecipeIds[id] = true
            print(string.format("[Connoisseur Tracker] Successfully hooked VehicleName (recipeId: %s)", tostring(id)))
        end
    end

    -- Hook "DetailsTitle" (Split View vehicle details title on the right pane)
    if nameToId["DetailsTitle"] and not hookedRecipeIds[nameToId["DetailsTitle"]] then
        local id = nameToId["DetailsTitle"]
        local origFn = _react.originalRecipeFn[id]
        if origFn then
            local DetailsTitleReplacement = react.RegisterRecipe("ConnoisseurDetailsTitleReplacement", function(elemStatic)
                local c = getCore()
                local isUsed = true
                if c and elemStatic then
                    isUsed = c.isStoreElementUsed(elemStatic)
                end

                if not isUsed and elemStatic then
                    local badge = _tr("BADGE_NOT_USED", "[未使用過]")
                    local origName = elemStatic.name or ""
                    if not origName:find(badge, 1, true) then
                        local modifiedStatic = {}
                        for k, v in pairs(elemStatic) do
                            modifiedStatic[k] = v
                        end
                        modifiedStatic.name = origName .. " " .. badge

                        return origFn(modifiedStatic)
                    end
                end

                return origFn(elemStatic)
            end)

            if _react and _react.recipeReplace then
                _react.recipeReplace[id] = DetailsTitleReplacement
            end
            hookedRecipeIds[id] = true
            print(string.format("[Connoisseur Tracker] Successfully hooked DetailsTitle (recipeId: %s)", tostring(id)))
        end
    end

    -- Hook "VehicleNameCell" (Table View vehicle name column)
    if nameToId["VehicleNameCell"] and not hookedRecipeIds[nameToId["VehicleNameCell"]] then
        local id = nameToId["VehicleNameCell"]
        local origFn = _react.originalRecipeFn[id]
        if origFn then
            local VehicleNameCellReplacement = react.RegisterRecipe("ConnoisseurVehicleNameCellReplacement", function(params)
                local dataEntry = params and params.userParam
                local elements = dataEntry and dataEntry.elements
                local elem = elements and elements[params.rowKey]

                local c = getCore()
                local isUsed = true
                if c and elem then
                    isUsed = c.isStoreElementUsed(elem)
                end

                if not isUsed and elem and elem.static then
                    local badge = _tr("BADGE_NOT_USED", "[未使用過]")
                    local origName = elem.static.name or ""
                    if not origName:find(badge, 1, true) then
                        local modifiedStatic = {}
                        for k, v in pairs(elem.static) do modifiedStatic[k] = v end
                        modifiedStatic.name = origName .. " " .. badge

                        local modifiedElem = {}
                        for k, v in pairs(elem) do modifiedElem[k] = v end
                        modifiedElem.static = modifiedStatic

                        local modifiedElements = {}
                        for k, v in pairs(elements) do modifiedElements[k] = v end
                        modifiedElements[params.rowKey] = modifiedElem

                        local modifiedDataEntry = {}
                        for k, v in pairs(dataEntry) do modifiedDataEntry[k] = v end
                        modifiedDataEntry.elements = modifiedElements

                        local modifiedParams = {}
                        for k, v in pairs(params) do modifiedParams[k] = v end
                        modifiedParams.userParam = modifiedDataEntry

                        return origFn(modifiedParams)
                    end
                end

                return origFn(params)
            end)

            if _react and _react.recipeReplace then
                _react.recipeReplace[id] = VehicleNameCellReplacement
            end
            hookedRecipeIds[id] = true
            print(string.format("[Connoisseur Tracker] Successfully hooked VehicleNameCell (recipeId: %s)", tostring(id)))
        end
    end

    -- Hook "VehicleStoreWindow" directly in _react.recipeReplace (runtime or fallback)
    if nameToId["VehicleStoreWindow"] and not hookedRecipeIds[nameToId["VehicleStoreWindow"]] then
        local id = nameToId["VehicleStoreWindow"]
        local existingReplace = _react.recipeReplace and _react.recipeReplace[id]
        local origFn = _react.originalRecipeFn[id]
        local nextFn = existingReplace or origFn

        if nextFn then
            local ConnoisseurVehicleStoreWindowDynamic = react.RegisterWrapperRecipe("ConnoisseurVehicleStoreWindowDynamic", builtin.Window, function(params)
                if params and params.vehiclesStaticData and params.vehiclesStaticData.repId2elementStatic then
                    tagStaticVehicles(params.vehiclesStaticData.repId2elementStatic)
                end
                return nextFn(params)
            end)

            if _react and _react.recipeReplace then
                _react.recipeReplace[id] = ConnoisseurVehicleStoreWindowDynamic
            end
            hookedRecipeIds[id] = true
            print(string.format("[Connoisseur Tracker] Successfully hooked VehicleStoreWindow via recipeReplace (recipeId: %s)", tostring(id)))
        end
    end

    return true
end

-- Official react-replacement-config entrypoint called by bootstrap_game.tl
function M.doReplaceFn(replacementApi)
    local ok, err = pcall(function()
        M.installHooks(replacementApi)
    end)
    if not ok then
        if log and log.warning then
            log.warning("Connoisseur replacement warning: " .. tostring(err))
        end
    end
end

-- Required by TF3 loaderHelper:useFn
function data()
    return {
        doReplaceFn = M.doReplaceFn,
        installHooks = M.installHooks,
    }
end

return {
    doReplaceFn = M.doReplaceFn,
    installHooks = M.installHooks,
}
