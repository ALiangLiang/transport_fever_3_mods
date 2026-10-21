-- ==============================================================================
-- UFO Summoner HUD Plugin & Window / 幽浮召喚器 介面擴充插件
-- ==============================================================================

local react = ug_require and ug_require("::/gui/main/react.lua") or require("/gui/main/react.lua")
local builtin = ug_require and ug_require("::/gui/main/builtin.lua") or require("/gui/main/builtin.lua")
local main_mod_button_area = ug_require and ug_require("::/gui/main/main_mod_button_area.tl") or require("/gui/main/main_mod_button_area.tl")
local game_react_globals = ug_require and ug_require("::/gui/main/game_react_globals.tl") or require("/gui/main/game_react_globals.tl")

local styleutil = nil
pcall(function()
    styleutil = ug_require and ug_require("::/gui/main/styleutil.tl") or require("/gui/main/styleutil.tl")
end)

local WINDOW_ID = "ufo_summoner_window"

-- Helper to safely load backend core
local core = nil
local function getCore()
    if core == nil then
        for _, path in ipairs({
            "aliangliang_ufo_summoner::/ufo_summoner.lua",
            "/ufo_summoner.lua",
            "content.ufo_summoner",
            "ufo_summoner.lua",
        }) do
            local ok, res = pcall(function()
                if ug_require then return ug_require(path) end
                return require(path)
            end)
            if ok and res and type(res) == "table" and res.summonUfo then
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
    "aliangliang_ufo_summoner::/ui_util.lua",
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

local isWindowOpen = false
local UfoSummonerWindow = nil

local function windowOpen()
    return isWindowOpen
end

local function closeWindow()
    isWindowOpen = false
    local wa = game_react_globals and game_react_globals.getDefaultWindowApi and game_react_globals.getDefaultWindowApi()
    if wa ~= nil and UfoSummonerWindow ~= nil then
        pcall(function()
            wa.removeAllWindows(UfoSummonerWindow)
        end)
    end
end

local function openWindow()
    local wa = game_react_globals and game_react_globals.getDefaultWindowApi and game_react_globals.getDefaultWindowApi()
    if wa == nil then
        return
    end
    isWindowOpen = true
    if UfoSummonerWindow ~= nil then
        pcall(function()
            wa.addSingletonWindow(UfoSummonerWindow, {
                onClose = closeWindow,
                initialX = 220,
                initialY = 140,
            })
            wa.moveSingletonWindowToFront(UfoSummonerWindow)
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

local UfoSummonerContent = react.RegisterRecipe("UfoSummonerContent", function()
    local c = getCore()
    local tabState = react.useState("ufos")
    local refreshTick = react.useState(0)
    local notificationState = react.useState("")
    local lastCheckTime = react.useRef(0)

    -- Step physics & auto-refresh status every frame / interval
    react.onStep(function()
        if c and c.update then
            c.update()
        end
        local now = os.clock()
        if now - lastCheckTime:get() >= 0.5 then
            lastCheckTime:set(now)
            refreshTick:transform(function(v) return v + 1 end)
        end
    end)

    local activeUfos = {}
    local farms = {}
    local hasFarms = false
    if c then
        activeUfos = c.getActiveUfos() or {}
        farms = (c.getLivestockFarms and c.getLivestockFarms()) or {}
        hasFarms = #farms > 0 or c.hasLivestockFarmsWithCows()
    end

    local hasActiveUfo = #activeUfos > 0

    -- 1. Header Toolbar
    local statusText = hasActiveUfo and string.format(_tr("AIRSPACE_STATUS_ACTIVE", "空域狀態：%d 架活躍幽浮"), #activeUfos)
                                   or _tr("AIRSPACE_STATUS_IDLE", "空域狀態：目前無活躍幽浮")

    local farmNotice = nil
    if not hasFarms then
        farmNotice = builtin.TextView{
            meta = { class = "font-scale-caption" },
            text = _tr("NO_COWS_DETECTED", "提醒：地圖上尚未發現養牛場。建造牲畜農場後飛碟即可吸牛！"),
        }
    else
        farmNotice = builtin.TextView{
            meta = { class = "font-scale-caption" },
            text = _tr("COWS_DETECTED", "地圖上的牲畜農場已就緒，可觸發外星光束吸牛彩蛋"),
        }
    end

    local header = builtin.BoxLayout{
        meta = { class = "horizontal-spacer" },
        orientation = builtin.type.Orientation.Horizontal,
        children = {
            makeHSpacer(16),
            builtin.BoxLayout{
                orientation = builtin.type.Orientation.Vertical,
                children = {
                    builtin.TextView{
                        meta = { class = "font-scale-headline" },
                        text = statusText,
                    },
                    makeVSpacer(4),
                    farmNotice,
                },
            },
            makeExpandingSpacer(),
            builtin.Button{
                meta = {
                    class = "secondary",
                    tooltip = _tr("REFRESH_TIP", "重新掃描活躍幽浮與牲畜農場"),
                },
                content = builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = _tr("REFRESH", "重新整理"),
                },
                onClick = function()
                    refreshTick:transform(function(v) return v + 1 end)
                end,
            },
            makeHSpacer(8),
            builtin.Button{
                meta = {
                    class = "primary",
                    tooltip = _tr("TOOLTIP_SUMMON_BTN", "立即手動召喚神秘幽浮進入空域"),
                },
                content = builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = _tr("BTN_SUMMON", "召喚飛碟"),
                },
                onClick = function()
                    if c then
                        notificationState:set(_tr("SUMMON_SENDING", "召喚指令已發送！飛碟正在高速進場..."))
                        c.summonUfo(function(ufoData)
                            notificationState:set(_tr("SUMMON_SUCCESS", "召喚成功！鏡頭已自動聚焦現場。"))
                            if ufoData then
                                local entToFocus = ufoData.cowEntity or ufoData.ufoEntity
                                if entToFocus then
                                    c.focusEntity(entToFocus)
                                end
                            end
                            refreshTick:transform(function(v) return v + 1 end)
                        end)
                        refreshTick:transform(function(v) return v + 1 end)
                    end
                end,
            },
            makeHSpacer(16),
        },
    }

    -- 2. Build Scrollable List of Active UFOs
    local function makeUfoList(ufos)
        if #ufos == 0 then
            return builtin.BoxLayout{
                meta = { class = "horizontal-spacer" },
                orientation = builtin.type.Orientation.Horizontal,
                children = {
                    makeHSpacer(16),
                    builtin.TextView{
                        meta = { class = "font-scale-body" },
                        text = _tr("NO_ACTIVE_UFOS", "目前空中沒有活躍飛碟。點擊右上角「召喚飛碟」即可召喚！"),
                    },
                    makeExpandingSpacer(),
                    makeHSpacer(16),
                },
            }
        end

        local rows = {}
        table.insert(rows, makeVSpacer(6))

        for _, ufo in ipairs(ufos) do
            local stateLabel = ufo.state or "Unknown"
            if stateLabel == "Approach" then
                stateLabel = _tr("STATE_APPROACH", "正在高速進場")
            elseif stateLabel == "Target" then
                stateLabel = _tr("STATE_TARGET", "鎖定目標牛隻")
            elseif stateLabel == "Abduct" then
                stateLabel = _tr("STATE_ABDUCT", "光束牽引吸牛中！")
            elseif stateLabel == "Leave" then
                stateLabel = _tr("STATE_LEAVE", "正在加速撤離")
            elseif stateLabel == "Despawn" then
                stateLabel = _tr("STATE_DESPAWN", "即將消失")
            end

            local cowText = ufo.cowEntity and string.format(_tr("TARGET_COW_LABEL", "目標：牛隻 #%d"), ufo.cowEntity)
                                          or _tr("NO_COW", "無目標")

            local actionButtons = {
                builtin.Button{
                    meta = { class = "secondary", tooltip = _tr("BTN_FOLLOW_UFO", "追蹤飛碟") },
                    content = builtin.TextView{
                        meta = { class = "font-scale-body" },
                        text = _tr("BTN_FOLLOW_UFO", "追蹤飛碟"),
                    },
                    onClick = function()
                        if c and ufo.ufoEntity then
                            c.focusEntity(ufo.ufoEntity)
                        end
                    end,
                },
            }

            if ufo.cowEntity then
                table.insert(actionButtons, makeHSpacer(8))
                table.insert(actionButtons, builtin.Button{
                    meta = { class = "secondary", tooltip = _tr("BTN_FOLLOW_COW", "追蹤牛隻") },
                    content = builtin.TextView{
                        meta = { class = "font-scale-body" },
                        text = _tr("BTN_FOLLOW_COW", "追蹤牛隻"),
                    },
                    onClick = function()
                        if c and ufo.cowEntity then
                            c.focusEntity(ufo.cowEntity)
                        end
                    end,
                })
            end

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
                                    local ok, s = pcall(styleutil.makeStyle, { size = { 160, 28 } })
                                    if ok then return s end
                                end
                                return nil
                            end)(),
                        },
                        text = string.format("%s #%d", _tr("UFO_ENTITY", "飛碟編號"), ufo.ufoEntity),
                    },
                    builtin.TextView{
                        meta = {
                            class = "font-scale-caption",
                            styleSheet = (function()
                                if styleutil and styleutil.makeStyle then
                                    local ok, s = pcall(styleutil.makeStyle, { size = { 180, 28 } })
                                    if ok then return s end
                                end
                                return nil
                            end)(),
                        },
                        text = string.format("%s: %s", _tr("STATE_LABEL", "當前階段"), stateLabel),
                    },
                    builtin.TextView{
                        meta = {
                            class = "font-scale-caption",
                            styleSheet = (function()
                                if styleutil and styleutil.makeStyle then
                                    local ok, s = pcall(styleutil.makeStyle, { size = { 150, 28 } })
                                    if ok then return s end
                                end
                                return nil
                            end)(),
                        },
                        text = cowText,
                    },
                    makeExpandingSpacer(),
                    builtin.BoxLayout{
                        orientation = builtin.type.Orientation.Horizontal,
                        children = actionButtons,
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

    -- 3. Build Scrollable List of Livestock Farms
    local function makeFarmList(farmList)
        if #farmList == 0 then
            return builtin.BoxLayout{
                meta = { class = "horizontal-spacer" },
                orientation = builtin.type.Orientation.Horizontal,
                children = {
                    makeHSpacer(16),
                    builtin.TextView{
                        meta = { class = "font-scale-body" },
                        text = _tr("NO_FARMS_DETECTED", "地圖上尚未發現養牛場。建造牲畜農場後可在此指定目標！"),
                    },
                    makeExpandingSpacer(),
                    makeHSpacer(16),
                },
            }
        end

        local rows = {}
        table.insert(rows, makeVSpacer(6))

        for _, farm in ipairs(farmList) do
            local coordStr = ""
            if farm.pos then
                coordStr = string.format(_tr("COORDINATES", "座標：(%.0f, %.0f)"), farm.pos.x, farm.pos.y)
            end

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
                                    local ok, s = pcall(styleutil.makeStyle, { size = { 220, 28 } })
                                    if ok then return s end
                                end
                                return nil
                            end)(),
                        },
                        text = string.format(_tr("FARM_NAME", "養牛牧場 #%d"), farm.entity),
                    },
                    builtin.TextView{
                        meta = {
                            class = "font-scale-caption",
                            styleSheet = (function()
                                if styleutil and styleutil.makeStyle then
                                    local ok, s = pcall(styleutil.makeStyle, { size = { 200, 28 } })
                                    if ok then return s end
                                end
                                return nil
                            end)(),
                        },
                        text = coordStr,
                    },
                    makeExpandingSpacer(),
                    builtin.Button{
                        meta = {
                            class = "primary",
                            tooltip = _tr("TOOLTIP_SUMMON_BTN", "立即手動召喚神秘幽浮進入空域"),
                        },
                        content = builtin.TextView{
                            meta = { class = "font-scale-body" },
                            text = _tr("SUMMON_HERE", "在此召喚"),
                        },
                        onClick = function()
                            if c then
                                notificationState:set(_tr("SUMMON_SENDING", "召喚指令已發送！飛碟正在高速進場..."))
                                c.summonUfo(function(ufoData)
                                    notificationState:set(_tr("SUMMON_SUCCESS", "召喚成功！鏡頭已自動聚焦現場。"))
                                    if ufoData then
                                        local entToFocus = ufoData.cowEntity or ufoData.ufoEntity
                                        if entToFocus then
                                            c.focusEntity(entToFocus)
                                        end
                                    end
                                    refreshTick:transform(function(v) return v + 1 end)
                                end, farm.pos)
                                refreshTick:transform(function(v) return v + 1 end)
                            end
                        end,
                    },
                    makeHSpacer(8),
                    builtin.Button{
                        meta = {
                            class = "secondary",
                            tooltip = _tr("FOCUS_FARM", "觀察農場"),
                        },
                        content = builtin.TextView{
                            meta = { class = "font-scale-body" },
                            text = _tr("FOCUS_FARM", "觀察農場"),
                        },
                        onClick = function()
                            if c and farm.pos then
                                c.focusPosition(farm.pos, 25)
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

    -- 4. Tab Construction
    local function makeTabChild(key, label, contentWidget)
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
                    children = { contentWidget },
                },
            },
        }
    end

    local tabChildren = {
        makeTabChild("ufos", string.format("%s (%d)", _tr("TAB_ACTIVE_UFOS", "活躍幽浮"), #activeUfos), makeUfoList(activeUfos)),
        makeTabChild("farms", string.format("%s (%d)", _tr("TAB_COW_FARMS", "牲畜農場"), #farms), makeFarmList(farms)),
    }

    local tabWidget = builtin.TabWidget{
        orientation = builtin.type.TabOrientation.North,
        deselectAllowed = false,
        indicatorsScrollable = false,
        value = tabState:old() or "ufos",
        onValueChange = function(newTab)
            if newTab ~= nil then
                tabState:set(newTab)
            end
        end,
        tabs = tabChildren,
    }

    -- 5. Notification feedback area
    local currentNotification = notificationState:old()
    local notificationRow = nil
    if currentNotification and #currentNotification > 0 then
        notificationRow = builtin.BoxLayout{
            meta = { class = "horizontal-spacer" },
            orientation = builtin.type.Orientation.Horizontal,
            children = {
                makeHSpacer(16),
                builtin.TextView{
                    meta = { class = "font-scale-caption" },
                    text = currentNotification,
                },
                makeExpandingSpacer(),
                makeHSpacer(16),
            },
        }
    else
        notificationRow = makeVSpacer(0)
    end

    -- 6. Footer Tip
    local footer = builtin.BoxLayout{
        meta = { class = "horizontal-spacer" },
        orientation = builtin.type.Orientation.Horizontal,
        children = {
            makeHSpacer(16),
            builtin.TextView{
                meta = { class = "font-scale-annotation" },
                text = _tr("FOOTER_TIP", "提示：點擊「召喚飛碟」或「在此召喚」進場吸牛。提醒：必須在畫面上點擊幽浮本體才會觸發解鎖成就！"),
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
        notificationRow,
        makeVSpacer(4),
        footer,
        makeVSpacer(10),
    }, 760, 480)
end)

-- Window Wrapper Recipe
UfoSummonerWindow = react.RegisterWrapperRecipe("UfoSummonerWindow", builtin.Window, function(params)
    local winParams = {
        id = WINDOW_ID,
        title = _tr("UFO_SUMMONER", "幽浮召喚器"),
        closable = true,
        movable = true,
        onClose = params.onClose,
        initialX = params.initialX or 180,
        initialY = params.initialY or 120,
        content = UfoSummonerContent(),
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

local UfoSummonerHudPlugin = react.RegisterPluginRecipe(main_mod_button_area.MainModButtonAreaExtension, "UfoSummonerHudPlugin", function()
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
        local c = getCore()
        if c and c.update then
            c.update()
        end
    end)

    if isMapEditorRef:get() then
        return nil
    end

    local btn = builtin.ToggleButton{
        meta = {
            class = "primary",
            tooltip = _tr("TOOLTIP_OPEN_UFO", "幽浮召喚器\n手動召喚神秘外星飛碟與鏡頭追蹤"),
        },
        content = builtin.BoxLayout{
            orientation = builtin.type.Orientation.Horizontal,
            children = {
                builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = _tr("UFO_SUMMONER", "幽浮"),
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
    UfoSummonerHudPlugin = UfoSummonerHudPlugin,
    ToolbarButtonPlugin = UfoSummonerHudPlugin,
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
