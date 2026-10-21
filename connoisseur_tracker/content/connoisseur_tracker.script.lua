-- ==============================================================================
-- Connoisseur Tracker HUD Plugin, Window & Vehicle Store Hook
-- 鑑賞家追蹤器 介面擴充與載具商店標記
-- ==============================================================================

local react = ug_require and ug_require("::/gui/main/react.lua") or require("/gui/main/react.lua")
local builtin = ug_require and ug_require("::/gui/main/builtin.lua") or require("/gui/main/builtin.lua")
local main_mod_button_area = ug_require and ug_require("::/gui/main/main_mod_button_area.tl") or require("/gui/main/main_mod_button_area.tl")
local game_react_globals = ug_require and ug_require("::/gui/main/game_react_globals.tl") or require("/gui/main/game_react_globals.tl")

local styleutil = nil
pcall(function()
    styleutil = ug_require and ug_require("::/gui/main/styleutil.tl") or require("/gui/main/styleutil.tl")
end)

local lang_util = nil
pcall(function()
    lang_util = ug_require and ug_require("/scripts/lang_util.tl") or require("/scripts/lang_util.tl")
end)

local WINDOW_ID = "connoisseur_tracker_window"

-- Helper to safely load backend core
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
            if ok and res and type(res) == "table" and res.getProgressData then
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

-- ==============================================================================
-- Vehicle Store Integration: Hook VehicleName, DetailsTitle & VehicleNameCell
-- ==============================================================================

local hookedRecipeIds = {}

local function getRecipeMaps()
    local fnToId = nil
    local fnToName = nil

    if debug and debug.getupvalue then
        if react and react.GetRecipeId then
            local _, v = debug.getupvalue(react.GetRecipeId, 1)
            if type(v) == "table" then fnToId = v end
        end
        if react and react.GetRecipeName then
            local _, v = debug.getupvalue(react.GetRecipeName, 1)
            if type(v) == "table" then fnToName = v end
        end

        if not fnToId or not fnToName then
            local visited = {}
            local function search(fn)
                if not fn or type(fn) ~= "function" or visited[fn] then return end
                visited[fn] = true
                local i = 1
                while true do
                    local n, v = debug.getupvalue(fn, i)
                    if not n then break end
                    if type(v) == "table" then
                        local firstK, firstV = next(v)
                        if type(firstK) == "function" then
                            if type(firstV) == "string" and not fnToName then
                                fnToName = v
                            elseif type(firstV) == "number" and not fnToId then
                                fnToId = v
                            end
                        end
                    elseif type(v) == "function" then
                        search(v)
                    end
                    if fnToId and fnToName then return end
                    i = i + 1
                end
            end

            for _, f in pairs({
                react.CallOriginalRecipe,
                react.GloballyReplaceRecipeBeforeInitInternal,
                react.RegisterRecipe,
                react.RegisterWrapperRecipe
            }) do
                search(f)
                if fnToId and fnToName then break end
            end
        end
    end

    return fnToId, fnToName
end

local isStoreHooked = false

local function ensureStoreHooks(replacementApi)
    if isStoreHooked then return true end

    pcall(function()
        if ug_require then
            ug_require("/gui/line_vehicle_mgmt/vehicle_store_window.tl")
            ug_require("/gui/line_vehicle_mgmt/vehicle_store_table.tl")
        else
            require("/gui/line_vehicle_mgmt/vehicle_store_window.tl")
            require("/gui/line_vehicle_mgmt/vehicle_store_table.tl")
        end
    end)

    local fnToId, fnToName = getRecipeMaps()
    if not fnToId or not fnToName then
        return false
    end

    local targets = {}
    for fn, name in pairs(fnToName) do
        if name == "VehicleName" or name == "DetailsTitle" or name == "VehicleNameCell" then
            targets[name] = { fn = fn, id = fnToId[fn] }
        end
    end

    local badge = _tr("BADGE_NOT_USED", "[未使用過]")

    -- 1. Hook VehicleName (Left panel vehicle card in store)
    if targets["VehicleName"] and not hookedRecipeIds[targets["VehicleName"].id] then
        local t = targets["VehicleName"]
        local origId = t.id
        local origFn = t.fn

        local VehicleNameReplacement = react.RegisterRecipe("ConnoisseurVehicleNameReplacement", function(param)
            local c = getCore()
            local isUsed = true
            if c and param and param.elemStatic then
                isUsed = c.isStoreElementUsed(param.elemStatic)
            end

            if not isUsed and param and param.elemStatic then
                local origName = param.elemStatic.name or ""
                if not origName:find(badge, 1, true) then
                    local modifiedStatic = {}
                    for k, v in pairs(param.elemStatic) do modifiedStatic[k] = v end
                    modifiedStatic.name = origName .. " " .. badge

                    local modifiedParam = {}
                    for k, v in pairs(param) do modifiedParam[k] = v end
                    modifiedParam.elemStatic = modifiedStatic

                    return react.CallOriginalRecipe(origFn, modifiedParam)
                end
            end

            return react.CallOriginalRecipe(origFn, param)
        end)

        if replacementApi and replacementApi.ReplaceRecipe then
            pcall(function() replacementApi.ReplaceRecipe(origFn, VehicleNameReplacement) end)
        end
        if _react and _react.recipeReplace then
            _react.recipeReplace[origId] = VehicleNameReplacement
        end
        hookedRecipeIds[origId] = true
        print("[Connoisseur Tracker] Successfully hooked VehicleName")
    end

    -- 2. Hook DetailsTitle (Right details pane in store)
    if targets["DetailsTitle"] and not hookedRecipeIds[targets["DetailsTitle"].id] then
        local t = targets["DetailsTitle"]
        local origId = t.id
        local origFn = t.fn

        local DetailsTitleReplacement = react.RegisterRecipe("ConnoisseurDetailsTitleReplacement", function(elemStatic)
            local c = getCore()
            local isUsed = true
            if c and elemStatic then
                isUsed = c.isStoreElementUsed(elemStatic)
            end

            if not isUsed and elemStatic then
                local origName = elemStatic.name or ""
                if not origName:find(badge, 1, true) then
                    local modifiedStatic = {}
                    for k, v in pairs(elemStatic) do modifiedStatic[k] = v end
                    modifiedStatic.name = origName .. " " .. badge

                    return react.CallOriginalRecipe(origFn, modifiedStatic)
                end
            end

            return react.CallOriginalRecipe(origFn, elemStatic)
        end)

        if replacementApi and replacementApi.ReplaceRecipe then
            pcall(function() replacementApi.ReplaceRecipe(origFn, DetailsTitleReplacement) end)
        end
        if _react and _react.recipeReplace then
            _react.recipeReplace[origId] = DetailsTitleReplacement
        end
        hookedRecipeIds[origId] = true
        print("[Connoisseur Tracker] Successfully hooked DetailsTitle")
    end

    -- 3. Hook VehicleNameCell (Table view cell in store)
    if targets["VehicleNameCell"] and not hookedRecipeIds[targets["VehicleNameCell"].id] then
        local t = targets["VehicleNameCell"]
        local origId = t.id
        local origFn = t.fn

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

                    return react.CallOriginalRecipe(origFn, modifiedParams)
                end
            end

            return react.CallOriginalRecipe(origFn, params)
        end)

        if replacementApi and replacementApi.ReplaceRecipe then
            pcall(function() replacementApi.ReplaceRecipe(origFn, VehicleNameCellReplacement) end)
        end
        if _react and _react.recipeReplace then
            _react.recipeReplace[origId] = VehicleNameCellReplacement
        end
        hookedRecipeIds[origId] = true
        print("[Connoisseur Tracker] Successfully hooked VehicleNameCell")
    end

    if targets["VehicleName"] and targets["DetailsTitle"] and targets["VehicleNameCell"] then
        isStoreHooked = true
        print("[Connoisseur Tracker] All vehicle store recipes successfully hooked with name badges!")
    end

    return true
end

-- Attempt hook on initial script load
pcall(ensureStoreHooks)

-- ==============================================================================
-- Window Management & State
-- ==============================================================================

local isWindowOpen = false
local ConnoisseurTrackerWindow = nil

local function windowOpen()
    return isWindowOpen
end

local function closeWindow()
    isWindowOpen = false
    local wa = game_react_globals and game_react_globals.getDefaultWindowApi and game_react_globals.getDefaultWindowApi()
    if wa ~= nil and ConnoisseurTrackerWindow ~= nil then
        pcall(function()
            wa.removeAllWindows(ConnoisseurTrackerWindow)
        end)
    end
end

local function openWindow()
    pcall(ensureStoreHooks)
    local wa = game_react_globals and game_react_globals.getDefaultWindowApi and game_react_globals.getDefaultWindowApi()
    if wa == nil then
        return
    end
    isWindowOpen = true
    if ConnoisseurTrackerWindow ~= nil then
        pcall(function()
            wa.addSingletonWindow(ConnoisseurTrackerWindow, {
                onClose = closeWindow,
                initialX = 180,
                initialY = 120,
            })
            wa.moveSingletonWindowToFront(ConnoisseurTrackerWindow)
        end)
    end
end

local function toggleWindow()
    if isWindowOpen then
        closeWindow()
    else
        openWindow()
    end
end

-- ==============================================================================
-- Window Content Recipe
-- ==============================================================================

-- Helper layout spacers
local function makeHSpacer(w)
    local meta = nil
    if styleutil and styleutil.makeStyle then
        pcall(function()
            meta = { styleSheet = styleutil.makeStyle{ size = { w, 1 } } }
        end)
    end
    return builtin.Component{ meta = meta }
end

local function makeVSpacer(h)
    local meta = nil
    if styleutil and styleutil.makeStyle then
        pcall(function()
            meta = { styleSheet = styleutil.makeStyle{ size = { 1, h } } }
        end)
    end
    return builtin.Component{ meta = meta }
end

local function makeExpandingSpacer()
    return builtin.Component{ meta = { class = "horizontal-spacer" } }
end

-- Safely retrieve current calendar year
local function getCurrentYear()
    local ok, yr = pcall(function()
        if api and api.engine and api.engine.getComponent and api.engine.util and api.engine.util.getWorld and api.type and api.type.ComponentType and api.type.ComponentType.GAME_TIME then
            local gameTime = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
            if gameTime and gameTime.gameTime and api.engine.util.getCalendarDate then
                local date = api.engine.util.getCalendarDate(gameTime.gameTime)
                if date and date.year then
                    return date.year
                end
            end
        end
        return nil
    end)
    if ok and yr then return yr end
    return nil
end

local ConnoisseurTrackerContent = react.RegisterRecipe("ConnoisseurTrackerContent", function()
    local c = getCore()
    local refreshTick = react.useState(0)
    local tabState = react.useState("all")
    local unusedOnlyState = react.useState(true) -- Default to show unused vehicles first
    local currentEraOnlyState = react.useState(false) -- Filter for current game era

    local currentYear = getCurrentYear()

    local progressData = {
        vehicles = {},
        total = 0,
        usedCount = 0,
        unusedCount = 0,
        percent = 0,
        isUnlocked = false,
    }

    if c and c.getProgressData then
        progressData = c.getProgressData()
    end

    -- 1. Header with Progress Display
    local progressText = string.format(
        _tr("PROGRESS_FORMAT", "已鑑賞 %d / %d 種運具 (%s%%)"),
        progressData.usedCount,
        progressData.total,
        tostring(progressData.percent)
    )

    local headerChildren = {
        builtin.TextView{
            meta = { class = "font-scale-headline" },
            text = progressText,
        },
    }

    if progressData.isUnlocked then
        table.insert(headerChildren, makeVSpacer(4))
        table.insert(headerChildren, builtin.TextView{
            meta = { class = "font-scale-caption" },
            text = _tr("ACHIEVEMENT_UNLOCKED", "成就已達成！所有運具皆已鑑賞完成。"),
        })
    end

    local header = builtin.BoxLayout{
        orientation = builtin.type.Orientation.Horizontal,
        children = {
            makeHSpacer(16),
            builtin.BoxLayout{
                orientation = builtin.type.Orientation.Vertical,
                children = headerChildren,
            },
            makeExpandingSpacer(),
            makeHSpacer(16),
        },
    }

    -- 2. Filter Toolbar
    local eraButtonText = _tr("FILTER_CURRENT_ERA", "過濾當前年代")
    if currentYear then
        if currentEraOnlyState:old() then
            eraButtonText = string.format(_tr("FILTER_CURRENT_ERA_ON", "當前年代 (%d)"), currentYear)
        else
            eraButtonText = string.format(_tr("FILTER_CURRENT_ERA_OFF", "過濾當前年代 (%d)"), currentYear)
        end
    end

    local filterBar = builtin.BoxLayout{
        orientation = builtin.type.Orientation.Horizontal,
        children = {
            makeHSpacer(16),
            builtin.Button{
                meta = {
                    class = unusedOnlyState:old() and "primary" or "secondary",
                    tooltip = _tr("FILTER_UNUSED_ONLY", "過濾未使用過"),
                },
                content = builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = unusedOnlyState:old() and _tr("FILTER_UNUSED_ONLY", "過濾未使用過") or _tr("FILTER_ALL", "顯示全部"),
                },
                onClick = function()
                    unusedOnlyState:set(not unusedOnlyState:old())
                end,
            },
            makeHSpacer(8),
            builtin.Button{
                meta = {
                    class = currentEraOnlyState:old() and "primary" or "secondary",
                    tooltip = currentYear
                        and string.format(_tr("TOOLTIP_CURRENT_ERA_YEAR", "僅顯示當前遊戲年份（%d 年）可購買/使用的運具"), currentYear)
                        or _tr("TOOLTIP_CURRENT_ERA_ALL", "僅顯示當前遊戲年份可購買/使用的運具"),
                },
                content = builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = eraButtonText,
                },
                onClick = function()
                    currentEraOnlyState:set(not currentEraOnlyState:old())
                end,
            },
            makeHSpacer(8),
            builtin.Button{
                meta = { class = "secondary", tooltip = _tr("REFRESH", "重新整理") },
                content = builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = _tr("REFRESH", "重新整理"),
                },
                onClick = function()
                    if c and c.getAllDefaultVehicles then
                        c.getAllDefaultVehicles(true)
                    end
                    refreshTick:transform(function(v) return v + 1 end)
                end,
            },
            makeExpandingSpacer(),
            makeHSpacer(16),
        },
    }

    -- 3. Vehicle List Builder
    local function makeVehicleList(vehicles)
        local onlyUnused = unusedOnlyState:old()
        local onlyCurrentEra = currentEraOnlyState:old()
        local rows = {}

        table.insert(rows, makeVSpacer(8))

        for _, v in ipairs(vehicles) do
            local show = true
            if onlyUnused and v.isUsed then
                show = false
            end
            if show and onlyCurrentEra and currentYear then
                local fromOk = (v.yearFrom == nil) or (v.yearFrom <= currentYear)
                local toOk = (v.yearTo == nil) or (v.yearTo <= 0) or (v.yearTo >= currentYear)
                if not (fromOk and toOk) then
                    show = false
                end
            end

            if show then
                local yearStr = ""
                if v.yearTo and v.yearTo > 0 then
                    yearStr = string.format(_tr("YEARS_RANGE", "%d 年 - %d 年"), v.yearFrom, v.yearTo)
                else
                    yearStr = string.format(_tr("YEARS_FROM", "%d 年起"), v.yearFrom)
                end

                local statusText = v.isUsed and _tr("STATUS_USED", "已鑑賞") or _tr("STATUS_NOT_USED", "未使用過")
                local statusClass = "font-scale-caption"

                local itemRow = builtin.BoxLayout{
                    meta = { class = "horizontal-spacer" },
                    orientation = builtin.type.Orientation.Horizontal,
                    children = {
                        makeHSpacer(16),
                        builtin.TextView{
                            meta = {
                                class = "font-scale-body",
                                styleSheet = (function()
                                    if styleutil and styleutil.makeStyle then
                                        local ok, s = pcall(styleutil.makeStyle, { size = { 260, 26 } })
                                        if ok then return s end
                                    end
                                    return nil
                                end)(),
                            },
                            text = v.name,
                        },
                        makeExpandingSpacer(),
                        builtin.TextView{
                            meta = {
                                class = "font-scale-caption",
                                styleSheet = (function()
                                    if styleutil and styleutil.makeStyle then
                                        local ok, s = pcall(styleutil.makeStyle, { size = { 150, 26 } })
                                        if ok then return s end
                                    end
                                    return nil
                                end)(),
                            },
                            text = yearStr,
                        },
                        makeHSpacer(14),
                        builtin.TextView{
                            meta = {
                                class = statusClass,
                                styleSheet = (function()
                                    if styleutil and styleutil.makeStyle then
                                        local ok, s = pcall(styleutil.makeStyle, { size = { 80, 26 } })
                                        if ok then return s end
                                    end
                                    return nil
                                end)(),
                            },
                            text = statusText,
                        },
                        makeHSpacer(16),
                    },
                }
                table.insert(rows, itemRow)
                table.insert(rows, makeVSpacer(4))
            end
        end

        table.insert(rows, makeVSpacer(8))

        local scrollMeta = {
            class = "horizontal-spacer",
        }
        if styleutil and styleutil.makeStyle then
            pcall(function()
                scrollMeta.styleSheet = styleutil.makeStyle{
                    size = { -1, 330 },
                }
            end)
        end

        return builtin.ScrollArea{
            meta = scrollMeta,
            horizontalPolicy = builtin.type.ScrollBarPolicy.AlwaysOff,
            verticalPolicy = builtin.type.ScrollBarPolicy.AsNeeded,
            content = builtin.Component{
                meta = { class = "horizontal-spacer" },
                layout = builtin.BoxLayout{
                    meta = { class = "horizontal-spacer" },
                    orientation = builtin.type.Orientation.Vertical,
                    children = rows,
                },
            },
        }
    end

    -- 4. Group Vehicles by Category
    local categories = {
        { key = "all", label = _tr("TAB_ALL", "全部") },
        { key = "RAIL", label = _tr("TAB_RAIL", "鐵路") },
        { key = "ROAD", label = _tr("TAB_ROAD", "公路") },
        { key = "TRAM", label = _tr("TAB_TRAM", "電車") },
        { key = "WATER", label = _tr("TAB_WATER", "水運") },
        { key = "AIR", label = _tr("TAB_AIR", "航空") },
    }

    local vehiclesByCategory = {}
    for _, cat in ipairs(categories) do
        vehiclesByCategory[cat.key] = {}
    end

    for _, v in ipairs(progressData.vehicles) do
        table.insert(vehiclesByCategory["all"], v)
        if vehiclesByCategory[v.category] then
            table.insert(vehiclesByCategory[v.category], v)
        end
    end

    -- 5. Construct Native Tabs
    local function makeTabChild(key, label, vehicles)
        local onlyCurrentEra = currentEraOnlyState:old()
        local matchingVehicles = {}
        for _, v in ipairs(vehicles) do
            local eraOk = true
            if onlyCurrentEra and currentYear then
                local fromOk = (v.yearFrom == nil) or (v.yearFrom <= currentYear)
                local toOk = (v.yearTo == nil) or (v.yearTo <= 0) or (v.yearTo >= currentYear)
                eraOk = fromOk and toOk
            end
            if eraOk then
                table.insert(matchingVehicles, v)
            end
        end

        local count = #matchingVehicles
        local unusedCount = 0
        for _, v in ipairs(matchingVehicles) do
            if not v.isUsed then unusedCount = unusedCount + 1 end
        end

        local displayLabel = string.format("%s (%d/%d)", label, count - unusedCount, count)

        return builtin.TabWidgetChild{
            localKey = "tab_" .. tostring(key),
            value = key,
            indicator = builtin.TextView{
                meta = { class = "font-scale-tab-widget-indicator" },
                text = displayLabel,
            },
            item = builtin.Component{
                meta = { class = "horizontal-spacer" },
                layout = builtin.BoxLayout{
                    meta = { class = "horizontal-spacer" },
                    orientation = builtin.type.Orientation.Vertical,
                    children = {
                        makeVSpacer(6),
                        makeVehicleList(vehicles),
                        makeVSpacer(6),
                    },
                },
            },
        }
    end

    local tabChildren = {}
    for _, cat in ipairs(categories) do
        local catVehicles = vehiclesByCategory[cat.key] or {}
        table.insert(tabChildren, makeTabChild(cat.key, cat.label, catVehicles))
    end

    local tabWidget = builtin.TabWidget{
        orientation = builtin.type.TabOrientation.North,
        deselectAllowed = false,
        indicatorsScrollable = true,
        value = tabState:old() or "all",
        onValueChange = function(newTab)
            if newTab ~= nil then
                tabState:set(newTab)
            end
        end,
        tabs = tabChildren,
    }

    local boxMeta = nil
    if styleutil and styleutil.makeStyle then
        pcall(function()
            local s = styleutil.makeStyle{
                size = { -1, 480 },
            }
            if s and api and api.type and api.type.Vec4f and api.type.Vec4f.new then
                pcall(function()
                    s.padding = api.type.Vec4f.new(12, 16, 12, 16)
                end)
            end
            boxMeta = { styleSheet = s }
        end)
    end

    return builtin.BoxLayout{
        meta = boxMeta,
        orientation = builtin.type.Orientation.Vertical,
        children = {
            builtin.Component{
                meta = (function()
                    if styleutil and styleutil.makeStyle then
                        local ok, s = pcall(styleutil.makeStyle, { size = { 760, 0 } })
                        if ok then return { styleSheet = s } end
                    end
                    return nil
                end)(),
            },
            makeVSpacer(12),
            header,
            makeVSpacer(10),
            filterBar,
            makeVSpacer(12),
            tabWidget,
            makeVSpacer(10),
        },
    }
end)

-- Window Wrapper Recipe
ConnoisseurTrackerWindow = react.RegisterWrapperRecipe("ConnoisseurTrackerWindow", builtin.Window, function(params)
    local winParams = {
        id = WINDOW_ID,
        title = _tr("CONNOISSEUR_TRACKER", "鑑賞家追蹤器"),
        closable = true,
        movable = true,
        onClose = params.onClose,
        initialX = params.initialX or 180,
        initialY = params.initialY or 120,
        content = ConnoisseurTrackerContent(),
    }
    return builtin.Window(winParams)
end)

-- ==============================================================================
-- Toolbar Plugin for MainModButtonAreaExtension
-- ==============================================================================

local function pluginRoot(child)
    return builtin.BoxLayout{
        orientation = builtin.type.Orientation.Horizontal,
        children = { child },
    }
end

local ConnoisseurTrackerHudPlugin = react.RegisterPluginRecipe(main_mod_button_area.MainModButtonAreaExtension, "ConnoisseurTrackerHudPlugin", function()
    local isMapEditorRef = react.useRefLazy(function()
        if api and api.gui and api.gui.game and api.gui.game.isMapEditor then
            return api.gui.game.isMapEditor()
        end
        return false
    end)

    local openState = react.useState(false)

    local function syncOpen()
        local isOpen = windowOpen()
        if isOpen ~= openState:old() then
            openState:set(isOpen)
        end
    end

    react.onStep(function()
        syncOpen()
        if not isStoreHooked then
            pcall(ensureStoreHooks)
        end
    end)

    if isMapEditorRef:get() then
        return nil
    end

    local btn = builtin.ToggleButton{
        meta = {
            class = "primary",
            tooltip = _tr("TOOLTIP_OPEN_TRACKER", "鑑賞家追蹤器\n追蹤所有運具使用進度，並在載具商店中標記未使用的運具"),
        },
        content = builtin.BoxLayout{
            orientation = builtin.type.Orientation.Horizontal,
            children = {
                builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = _tr("CONNOISSEUR_SHORT", "鑑賞家"),
                },
            },
        },
        value = openState:old() and 1 or 0,
        onValueChange = function()
            toggleWindow()
            syncOpen()
        end,
    }

    return pluginRoot(btn)
end)

local exports = {
    ConnoisseurTrackerHudPlugin = ConnoisseurTrackerHudPlugin,
    ToolbarButtonPlugin = ConnoisseurTrackerHudPlugin,
    openWindow = openWindow,
    closeWindow = closeWindow,
    toggleWindow = toggleWindow,
    update = function(userParams, state, dt) end,
    guiUpdate = function(userParams, stateRO, guiState) end,
    handleEvent = function(userParams, state, src, id, name, param) end,
    guiHandleEvent = function(userParams, stateRO, guiState, src, id, name, param) end,
    save = function(state) return {} end,
    load = function(state, loadedData) end,
}

function data()
    return exports
end

return exports
