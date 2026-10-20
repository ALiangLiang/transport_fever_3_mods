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
    local hasFarms = false
    if c then
        activeUfos = c.getActiveUfos() or {}
        hasFarms = c.hasLivestockFarmsWithCows()
    end

    local hasActiveUfo = #activeUfos > 0

    -- 1. Header / Radar Status
    local statusText = hasActiveUfo and _tr("STATUS_ACTIVE", "偵測到活躍的外星飛碟！")
                                   or _tr("STATUS_IDLE", "目前空域中無活躍飛碟")

    local header = builtin.BoxLayout{
        orientation = builtin.type.Orientation.Vertical,
        children = {
            builtin.TextView{
                meta = { class = "font-scale-subheading" },
                text = statusText,
            },
        },
    }

    -- 2. Notice if cow farm exists or camera fallback
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

    -- 3. Active UFO List Cards
    local ufoCards = {}
    for _, ufo in ipairs(activeUfos) do
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

        local card = builtin.BoxLayout{
            orientation = builtin.type.Orientation.Horizontal,
            children = {
                builtin.BoxLayout{
                    orientation = builtin.type.Orientation.Vertical,
                    children = {
                        builtin.TextView{
                            text = string.format("%s #%d", _tr("UFO_ENTITY", "飛碟編號"), ufo.ufoEntity),
                            meta = { class = "font-scale-body" },
                        },
                        builtin.TextView{
                            text = string.format("%s: %s", _tr("STATE_LABEL", "當前階段"), stateLabel),
                            meta = { class = "font-scale-caption" },
                        },
                    },
                },
                builtin.BoxLayout{
                    orientation = builtin.type.Orientation.Horizontal,
                    children = actionButtons,
                },
            },
        }
        table.insert(ufoCards, card)
    end

    local ufoListSection = nil
    if #ufoCards > 0 then
        ufoListSection = builtin.BoxLayout{
            orientation = builtin.type.Orientation.Vertical,
            children = ufoCards,
        }
    end

    -- 4. Notification feedback area
    local currentNotification = notificationState:old()
    local notificationWidget = nil
    if currentNotification and #currentNotification > 0 then
        notificationWidget = builtin.TextView{
            meta = { class = "font-scale-body" },
            text = currentNotification,
        }
    end

    -- 5. Bottom Summon Action
    local summonBtn = builtin.Button{
        meta = { class = "primary" },
        content = builtin.TextView{
            meta = { class = "font-scale-subheading" },
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
    }

    local rootChildren = {
        header,
        farmNotice,
    }

    if ufoListSection then
        table.insert(rootChildren, ufoListSection)
    end

    if notificationWidget then
        table.insert(rootChildren, notificationWidget)
    end

    table.insert(rootChildren, summonBtn)

    local boxMeta = nil
    if styleutil and styleutil.makeStyle then
        pcall(function()
            boxMeta = {
                styleSheet = styleutil.makeStyle{
                    size = { 640, 280 },
                },
            }
        end)
    end

    return builtin.BoxLayout{
        meta = boxMeta,
        orientation = builtin.type.Orientation.Vertical,
        children = rootChildren,
    }
end)

-- Window Wrapper Recipe
UfoSummonerWindow = react.RegisterWrapperRecipe("UfoSummonerWindow", builtin.Window, function(params)
    local winParams = {
        id = WINDOW_ID,
        title = _tr("UFO_SUMMONER", "幽浮召喚器"),
        closable = true,
        movable = true,
        onClose = params.onClose,
        initialX = params.initialX or 220,
        initialY = params.initialY or 140,
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
