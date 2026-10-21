-- ==============================================================================
-- Animal Radar HUD Plugin & Window / 動物雷達 介面擴充插件
-- Modeled on square_problem_radar and TF3 base game React UI conventions
-- ==============================================================================

local react = ug_require and ug_require("::/gui/main/react.lua") or require("/gui/main/react.lua")
local builtin = ug_require and ug_require("::/gui/main/builtin.lua") or require("/gui/main/builtin.lua")
local main_mod_button_area = ug_require and ug_require("::/gui/main/main_mod_button_area.tl") or require("/gui/main/main_mod_button_area.tl")
local game_react_globals = ug_require and ug_require("::/gui/main/game_react_globals.tl") or require("/gui/main/game_react_globals.tl")

local styleutil = nil
pcall(function()
    styleutil = ug_require and ug_require("::/gui/main/styleutil.tl") or require("/gui/main/styleutil.tl")
end)

local WINDOW_ID = "animal_radar_window"

-- Helper to safely load backend core
local core = nil
local function getCore()
    if core == nil then
        for _, path in ipairs({
            "aliangliang_animal_radar::/animal_finder.lua",
            "/animal_finder.lua",
            "content.animal_finder",
            "animal_finder.lua",
        }) do
            local ok, res = pcall(function()
                if ug_require then return ug_require(path) end
                return require(path)
            end)
            if ok and res and type(res) == "table" and res.scanAnimals then
                core = res
                break
            end
        end
    end
    return core
end

-- Helper to safely load UI utility
local ui = nil
for _, path in ipairs({
    "aliangliang_animal_radar::/ui_util.lua",
    "/ui_util.lua",
    "content.ui_util",
    "ui_util.lua",
}) do
    local ok, res = pcall(function()
        if ug_require then return ug_require(path) end
        return require(path)
    end)
    if ok and res and type(res) == "table" and res.createWindowBox then
        ui = res
        break
    end
end

-- Safe gettext translation helper querying TF3 strings.json
local function _tr(key, default)
    if ui and ui.tr then return ui.tr(key, default) end
    if _ and type(_) == "function" then
        local ok, res = pcall(_, key)
        if ok and res and res ~= key and #res > 0 then
            return res
        end
    end
    return default or key
end

local function makeHSpacer(w)
    if ui and ui.makeHSpacer then return ui.makeHSpacer(w) end
    local meta = nil
    if styleutil and styleutil.makeStyle then
        pcall(function() meta = { styleSheet = styleutil.makeStyle{ size = { w, 1 } } } end)
    end
    return builtin.Component{ meta = meta }
end

local function makeVSpacer(h)
    if ui and ui.makeVSpacer then return ui.makeVSpacer(h) end
    local meta = nil
    if styleutil and styleutil.makeStyle then
        pcall(function() meta = { styleSheet = styleutil.makeStyle{ size = { 1, h } } } end)
    end
    return builtin.Component{ meta = meta }
end

local function makeExpandingSpacer()
    if ui and ui.makeExpandingSpacer then return ui.makeExpandingSpacer() end
    return builtin.Component{ meta = { class = "horizontal-spacer" } }
end

local function createScrollArea(rows, height)
    if ui and ui.createScrollArea then return ui.createScrollArea(rows, height) end
    local scrollMeta = { class = "horizontal-spacer" }
    if styleutil and styleutil.makeStyle then
        pcall(function() scrollMeta.styleSheet = styleutil.makeStyle{ size = { -1, height or 330 } } end)
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

local function createWindowBox(children, width, height)
    if ui and ui.createWindowBox then return ui.createWindowBox(children, width, height) end
    local boxMeta = nil
    if styleutil and styleutil.makeStyle then
        pcall(function()
            local s = styleutil.makeStyle{ size = { -1, height or 480 } }
            if s and api and api.type and api.type.Vec4f and api.type.Vec4f.new then
                pcall(function() s.padding = api.type.Vec4f.new(12, 16, 12, 16) end)
            end
            boxMeta = { styleSheet = s }
        end)
    end
    local allChildren = {
        builtin.Component{
            meta = (function()
                if styleutil and styleutil.makeStyle then
                    local ok, s = pcall(styleutil.makeStyle, { size = { width or 760, 0 } })
                    if ok then return { styleSheet = s } end
                end
                return nil
            end)(),
        },
    }
    for _, ch in ipairs(children) do table.insert(allChildren, ch) end
    return builtin.BoxLayout{
        meta = boxMeta,
        orientation = builtin.type.Orientation.Vertical,
        children = allChildren,
    }
end

-- ==============================================================================
-- Window Management & State
-- ==============================================================================

local isRadarWindowOpen = false
local AnimalRadarWindow = nil

local function windowOpen()
    return isRadarWindowOpen
end

local function closeWindow()
    isRadarWindowOpen = false
    local wa = game_react_globals and game_react_globals.getDefaultWindowApi and game_react_globals.getDefaultWindowApi()
    if wa ~= nil and AnimalRadarWindow ~= nil then
        pcall(function()
            wa.removeAllWindows(AnimalRadarWindow)
        end)
    end
end

local function openWindow()
    local wa = game_react_globals and game_react_globals.getDefaultWindowApi and game_react_globals.getDefaultWindowApi()
    if wa == nil then
        return
    end
    isRadarWindowOpen = true
    if AnimalRadarWindow ~= nil then
        pcall(function()
            wa.addSingletonWindow(AnimalRadarWindow, {
                onClose = closeWindow,
                initialX = 180,
                initialY = 120,
            })
            wa.moveSingletonWindowToFront(AnimalRadarWindow)
        end)
    end
end

local function toggleWindow()
    if windowOpen() then
        closeWindow()
    else
        openWindow()
    end
end

-- ==============================================================================
-- Window Content & Card Recipes
-- ==============================================================================

local AnimalRadarContent = react.RegisterRecipe("AnimalRadarContent", function(params)
    local c = getCore()
    local tabState = react.useState("all")
    local refreshTick = react.useState(0)
    local followModeState = react.useState(c and c.getFollowMode and c.getFollowMode() or true)

    local allAnimals = c and c.getAnimals() or {}

    -- Group all animals by species
    local animalsBySpecies = {}
    local speciesList = {}
    for _, a in ipairs(allAnimals) do
        local sp = a.species or _tr("Animal", "動物")
        if not animalsBySpecies[sp] then
            animalsBySpecies[sp] = {}
            table.insert(speciesList, sp)
        end
        table.insert(animalsBySpecies[sp], a)
    end
    table.sort(speciesList)

    -- 1. Header Toolbar
    local header = builtin.BoxLayout{
        meta = { class = "horizontal-spacer" },
        orientation = builtin.type.Orientation.Horizontal,
        children = {
            makeHSpacer(16),
            builtin.TextView{
                meta = { class = "font-scale-headline" },
                text = string.format(_tr("MAP_TOTAL_ANIMALS", "地圖動物: %d 隻"), #allAnimals),
            },
            makeExpandingSpacer(),
            builtin.Button{
                meta = {
                    class = "secondary",
                    tooltip = _tr("REFRESH_TIP", "重新掃描地圖上的所有動物"),
                },
                content = builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = _tr("REFRESH", "重新整理"),
                },
                onClick = function()
                    if c and c.scanAnimals then
                        c.scanAnimals()
                    end
                    refreshTick:transform(function(v) return v + 1 end)
                end,
            },
            makeHSpacer(8),
            builtin.Button{
                meta = {
                    class = followModeState:old() and "primary" or "secondary",
                    tooltip = _tr("CAM_MODE_TOOLTIP", "切換鏡頭模式：跟隨移動或原地聚焦"),
                },
                content = builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = followModeState:old() and _tr("CAM_MODE_FOLLOW", "鏡頭模式: 跟隨") or _tr("CAM_MODE_FOCUS", "鏡頭模式: 聚焦"),
                },
                onClick = function()
                    if c and c.toggleFollowMode then
                        local newMode = c.toggleFollowMode()
                        followModeState:set(newMode)
                    end
                end,
            },
            makeHSpacer(16),
        },
    }

    -- 2. Build Scrollable List of Animals for a given group
    local function makeAnimalList(animals)
        if #animals == 0 then
            return builtin.BoxLayout{
                meta = { class = "horizontal-spacer" },
                orientation = builtin.type.Orientation.Horizontal,
                children = {
                    makeHSpacer(16),
                    builtin.TextView{
                        meta = { class = "font-scale-headline" },
                        text = _tr("NO_ANIMALS_FOUND", "目前未偵測到此物種動物"),
                    },
                    makeExpandingSpacer(),
                    makeHSpacer(16),
                },
            }
        end

        local rows = {}
        table.insert(rows, makeVSpacer(6))

        for _, animal in ipairs(animals) do
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
                                    local ok, s = pcall(styleutil.makeStyle, { size = { 260, 28 } })
                                    if ok then return s end
                                end
                                return nil
                            end)(),
                        },
                        text = string.format("%s  #%s", animal.species, tostring(animal.entity)),
                    },
                    makeExpandingSpacer(),
                    builtin.Button{
                        meta = {
                            class = "primary",
                            tooltip = _tr("TOOLTIP_FOCUS_BTN", "將鏡頭移動至此動物身旁"),
                        },
                        content = builtin.TextView{
                            meta = { class = "font-scale-body" },
                            text = _tr("FOCUS_OBSERVE", "觀察聚焦"),
                        },
                        onClick = function()
                            if c and c.focusAnimal then
                                c.focusAnimal(animal.entity, animal.worldPos)
                            end
                        end,
                    },
                    makeHSpacer(16),
                },
            }
            table.insert(rows, itemRow)
            table.insert(rows, makeVSpacer(4))
        end

        table.insert(rows, makeVSpacer(6))

        return createScrollArea(rows, 320)
    end

    -- 3. Construct Tabs per Species using TF3 native TabWidgetChild
    local function makeTabChild(key, label, animals)
        return builtin.TabWidgetChild{
            localKey = "tab_" .. tostring(key),
            value = key,
            indicator = builtin.TextView{
                meta = { class = "font-scale-tab-widget-indicator" },
                text = label,
            },
            item = builtin.Component{
                layout = builtin.BoxLayout{
                    meta = { class = "horizontal-spacer" },
                    orientation = builtin.type.Orientation.Vertical,
                    children = { makeAnimalList(animals) },
                },
            },
        }
    end

    local tabChildren = {}

    -- Tab: All
    local allLabel = string.format("%s (%d)", _tr("ALL", "全部"), #allAnimals)
    table.insert(tabChildren, makeTabChild("all", allLabel, allAnimals))

    -- Tab: Each Individual Species
    for _, sp in ipairs(speciesList) do
        local spAnimals = animalsBySpecies[sp] or {}
        local tabLabel = string.format("%s (%d)", sp, #spAnimals)
        table.insert(tabChildren, makeTabChild(sp, tabLabel, spAnimals))
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

    -- 4. Footer Tip
    local footer = builtin.BoxLayout{
        meta = { class = "horizontal-spacer" },
        orientation = builtin.type.Orientation.Horizontal,
        children = {
            makeHSpacer(16),
            builtin.TextView{
                meta = { class = "font-scale-annotation" },
                text = _tr("FOOTER_TIP", "提示：點擊列表中的「觀察聚焦」，鏡頭將移動至該動物位置。"),
            },
            makeExpandingSpacer(),
            makeHSpacer(16),
        },
    }

    return createWindowBox({
        makeVSpacer(12),
        header,
        makeVSpacer(10),
        tabWidget,
        makeVSpacer(8),
        footer,
        makeVSpacer(10),
    }, 760, 480)
end)

-- Window Wrapper Recipe
AnimalRadarWindow = react.RegisterWrapperRecipe("AnimalRadarWindow", builtin.Window, function(params)
    local winParams = {
        id = WINDOW_ID,
        title = _tr("ANIMAL_RADAR", "動物雷達"),
        closable = true,
        movable = true,
        onClose = params.onClose,
        initialX = params.initialX or 180,
        initialY = params.initialY or 120,
        content = AnimalRadarContent(),
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

local AnimalRadarHudPlugin = react.RegisterPluginRecipe(main_mod_button_area.MainModButtonAreaExtension, "AnimalRadarHudPlugin", function()
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
    end)

    if isMapEditorRef:get() then
        return nil
    end

    local btn = builtin.ToggleButton{
        meta = {
            class = "primary",
            tooltip = _tr("TOOLTIP_OPEN_RADAR", "動物雷達\n查看全地圖動物物種與鏡頭追蹤"),
        },
        content = builtin.BoxLayout{
            orientation = builtin.type.Orientation.Horizontal,
            children = {
                builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = _tr("ANIMAL_RADAR", "動物雷達"),
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
    AnimalRadarHudPlugin = AnimalRadarHudPlugin,
    ToolbarButtonPlugin = AnimalRadarHudPlugin,
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
