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

local hasGameScriptActive = false

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
            if ok and res and type(res) == "table" and (res.getLivestockFarms or res.getActiveUfos or res.summonUfo) then
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
    local refreshTick = react.useState(0)
    local notificationState = react.useState("")
    local lastCheckTime = react.useRef(0)

    local pendingFocusRef = react.useRef(false)
    local pendingFocusStartTime = react.useRef(0)
    local lastPendingFocusCheck = react.useRef(0)

    -- Auto-refresh status interval
    react.onStep(function()
        local now = os.clock()
        if now - lastCheckTime:get() >= 0.5 then
            lastCheckTime:set(now)
            refreshTick:transform(function(v) return v + 1 end)
        end

        if pendingFocusRef:get() then
            if now - pendingFocusStartTime:get() > 8.0 then
                pendingFocusRef:set(false)
            elseif now - lastPendingFocusCheck:get() >= 0.3 then
                lastPendingFocusCheck:set(now)
                if c and c.getActiveUfos then
                    local currentUfos = c.getActiveUfos() or {}
                    for _, u in ipairs(currentUfos) do
                        if u and u.ufoEntity and u.ufoEntity > 0 then
                            pendingFocusRef:set(false)
                            c.focusEntity(u.ufoEntity)
                            break
                        end
                    end
                end
            end
        end
    end)

    local activeUfos = {}
    local hasFarms = false
    if c then
        activeUfos = c.getActiveUfos() or {}
        hasFarms = c.hasLivestockFarm and c.hasLivestockFarm()
    end

    local hasActiveUfo = #activeUfos > 0

    -- Global in-game system notification helper
    local function sendGlobalNotification(title, text, icon)
        pcall(function()
            if api and api.cmd and api.cmd.makeScriptingSendEventCmd then
                api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd("", "Notifications", "add", {
                    type = "aliangliang_ufo_summoner::/ufo_notification.script",
                    params = {
                        title = title,
                        description = text,
                        icon = icon or "::/game_mechanics/notifications/gui/icons/task_complete.tga",
                    },
                    autoDismissDuration = 7000,
                }))
            end
        end)
    end

    -- Official Summon Trigger
    local function doSummon()
        if c and c.recordPendingSummon then
            c.recordPendingSummon()
        end
        pendingFocusRef:set(true)
        pendingFocusStartTime:set(os.clock())
        -- NOTE: Pull camera strictly to the UFO in the air, NOT pasture or cow.

        if not hasFarms then
            local warnMsg = _tr("NO_COW_FARMS_WARNING", "⚠️ Warning: No livestock farm found on the map! Official UFO requires cattle as target. If no UFO appears, please build a Livestock Farm first.")
            notificationState:set(warnMsg)
            sendGlobalNotification(_tr("UFO_SUMMONER", "UFO Summoner"), warnMsg, "::/game_mechanics/notifications/gui/icons/animal_despawn.tga")
        else
            local succMsg = _tr("SUMMON_SENDING", "🛸 Summon command sent! UFO is flying in (ensure the game is not paused)...")
            notificationState:set(succMsg)
            sendGlobalNotification(_tr("UFO_SUMMONER", "UFO Summoner"), succMsg, "::/game_mechanics/notifications/gui/icons/task_complete.tga")
        end

        pcall(function()
            api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd("", "UfoSummoner", "spawnUfo", {}))
        end)
        refreshTick:transform(function(v) return v + 1 end)
    end

    -- 1. Header Toolbar
    local statusText = hasActiveUfo and string.format(_tr("AIRSPACE_STATUS_ACTIVE", "Airspace: %d Active UFO(s)"), #activeUfos)
                                   or _tr("AIRSPACE_STATUS_IDLE", "Airspace: No Active UFO")

    local farmNotice = nil
    if not hasFarms then
        farmNotice = builtin.TextView{
            meta = { class = "font-scale-caption" },
            text = _tr("NO_COWS_DETECTED", "Notice: No livestock farm found. Build a Livestock Farm to enable cattle abduction!"),
        }
    else
        farmNotice = builtin.TextView{
            meta = { class = "font-scale-caption" },
            text = _tr("COWS_DETECTED", "Livestock farm ready for abduction event"),
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
                    tooltip = _tr("REFRESH_TIP", "Scan active UFOs in airspace"),
                },
                content = builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = _tr("REFRESH", "Refresh"),
                },
                onClick = function()
                    if c and c.getActiveUfos then
                        c.getActiveUfos(true)
                    end
                    refreshTick:transform(function(v) return v + 1 end)
                end,
            },
            makeHSpacer(8),
            builtin.Button{
                meta = {
                    class = "primary",
                    tooltip = _tr("TOOLTIP_SUMMON_BTN", "Immediately summon a mysterious UFO into the airspace"),
                },
                content = builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = _tr("BTN_SUMMON", "Summon UFO"),
                },
                onClick = function()
                    doSummon()
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
                        text = _tr("NO_ACTIVE_UFOS", "No active UFO currently in the sky. Click 'Summon UFO' above to summon one!"),
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
                stateLabel = _tr("STATE_APPROACH", "Approaching")
            elseif stateLabel == "Target" then
                stateLabel = _tr("STATE_TARGET", "Targeting Cow")
            elseif stateLabel == "Abduct" then
                stateLabel = _tr("STATE_ABDUCT", "Abducting Cow!")
            elseif stateLabel == "Leave" then
                stateLabel = _tr("STATE_LEAVE", "Leaving Airspace")
            elseif stateLabel == "Despawn" then
                stateLabel = _tr("STATE_DESPAWN", "Despawning")
            end

            local cowText = (ufo.cowEntity and ufo.cowEntity > 0)
                and string.format(_tr("TARGET_COW_LABEL", "Target: Cow #%d"), ufo.cowEntity)
                or _tr("NO_COW", "No target")

            local isRealUfo = (ufo.ufoEntity and ufo.ufoEntity > 0)
            local ufoTitle = isRealUfo
                and string.format("%s #%d", _tr("UFO_ENTITY", "UFO"), ufo.ufoEntity)
                or string.format("🛸 %s", _tr("UFO_SPAWNING", "UFO (Approaching...)"))

            local actionButtons = {}
            if isRealUfo then
                table.insert(actionButtons, builtin.Button{
                    meta = { class = "secondary", tooltip = _tr("BTN_FOLLOW_UFO", "Follow UFO") },
                    content = builtin.TextView{
                        meta = { class = "font-scale-body" },
                        text = _tr("BTN_FOLLOW_UFO", "Follow UFO"),
                    },
                    onClick = function()
                        if c and ufo.ufoEntity then
                            c.focusEntity(ufo.ufoEntity)
                        end
                    end,
                })
            else
                table.insert(actionButtons, builtin.TextView{
                    meta = { class = "font-scale-caption" },
                    text = _tr("APPROACHING", "Approaching..."),
                })
            end

            if ufo.cowEntity and ufo.cowEntity > 0 then
                table.insert(actionButtons, makeHSpacer(8))
                table.insert(actionButtons, builtin.Button{
                    meta = { class = "secondary", tooltip = _tr("BTN_FOLLOW_COW", "Follow Cow") },
                    content = builtin.TextView{
                        meta = { class = "font-scale-body" },
                        text = _tr("BTN_FOLLOW_COW", "Follow Cow"),
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
                                    local ok, s = pcall(styleutil.makeStyle, { size = { 190, 28 } })
                                    if ok then return s end
                                end
                                return nil
                            end)(),
                        },
                        text = ufoTitle,
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
                        text = string.format("%s: %s", _tr("STATE_LABEL", "Phase"), stateLabel),
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

    -- 3. Notification feedback area
    local currentNotification = (notificationState.old and notificationState:old()) or (notificationState.get and notificationState:get()) or ""
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

    -- 4. Footer Tip
    local footer = builtin.BoxLayout{
        meta = { class = "horizontal-spacer" },
        orientation = builtin.type.Orientation.Horizontal,
        children = {
            makeHSpacer(16),
            builtin.TextView{
                meta = { class = "font-scale-annotation" },
                text = _tr("FOOTER_TIP", "Tip: Click 'Summon UFO' to initiate cow abduction. Reminder: You must click directly on the UFO entity in the game world to unlock the achievement!"),
            },
            makeExpandingSpacer(),
            makeHSpacer(16),
        },
    }

    return createWindowBox({
        makeVSpacer(12),
        header,
        makeVSpacer(10),
        makeUfoList(activeUfos),
        makeVSpacer(8),
        notificationRow,
        makeVSpacer(4),
        footer,
        makeVSpacer(8),
    }, 720, 420)
end)

-- Window Wrapper Recipe
UfoSummonerWindow = react.RegisterWrapperRecipe("UfoSummonerWindow", builtin.Window, function(params)
    local winParams = {
        id = WINDOW_ID,
        title = _tr("UFO_SUMMONER", "UFO Summoner"),
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
    end)

    if isMapEditorRef:get() then
        return nil
    end

    local btn = builtin.ToggleButton{
        meta = {
            class = "primary",
            tooltip = _tr("TOOLTIP_OPEN_UFO", "UFO Summoner\nSummon UFO and track abduction events"),
        },
        content = builtin.BoxLayout{
            orientation = builtin.type.Orientation.Horizontal,
            children = {
                builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = _tr("TOOLBAR_BTN_UFO", "UFO"),
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
}

function data()
    return exports
end

return exports
