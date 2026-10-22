-- ==============================================================================
-- Achievement Unlocker GUI Script
-- React window and toolbar button for instant achievement unlocking
-- ==============================================================================

local react = ug_require and ug_require("::/gui/main/react.lua") or require("/gui/main/react.lua")
local builtin = ug_require and ug_require("::/gui/main/builtin.lua") or require("/gui/main/builtin.lua")
local main_mod_button_area = ug_require and ug_require("::/gui/main/main_mod_button_area.tl") or require("/gui/main/main_mod_button_area.tl")
local game_react_globals = ug_require and ug_require("::/gui/main/game_react_globals.tl") or require("/gui/main/game_react_globals.tl")

local ui = nil
pcall(function()
    ui = ug_require and ug_require("aliangliang_achievements_unlock::/ui_util.lua") or require("ui_util.lua")
end)

local core = nil
pcall(function()
    core = ug_require and ug_require("aliangliang_achievements_unlock::/achievements_unlock.lua") or require("achievements_unlock.lua")
end)

local styleutil = nil
pcall(function()
    styleutil = ug_require and ug_require("::/gui/main/styleutil.tl") or require("/gui/main/styleutil.tl")
end)

local function _tr(key, default)
    if ui and ui.tr then return ui.tr(key, default) end
    if _ and type(_) == "function" then
        local ok, res = pcall(_, key)
        if ok and res and res ~= key and #res > 0 then return res end
    end
    return default or key
end

local function makeHSpacer(w)
    if ui and ui.makeHSpacer then return ui.makeHSpacer(w) end
    return builtin.Component{}
end

local function makeVSpacer(h)
    if ui and ui.makeVSpacer then return ui.makeVSpacer(h) end
    return builtin.Component{}
end

local function makeExpandingSpacer()
    if ui and ui.makeExpandingSpacer then return ui.makeExpandingSpacer() end
    return builtin.Component{ meta = { class = "horizontal-spacer" } }
end

-- ==============================================================================
-- Window Management & State
-- ==============================================================================

local WINDOW_ID = "achievement_unlocker_window"
local CONFIRM_WINDOW_ID = "achievement_unlocker_confirm_window"
local isWindowOpen = false
local AchievementUnlockerWindow = nil
local AchievementConfirmWindow = nil

local confirmTarget = nil
local updateConfirmContent = nil
local triggerMainWindowRefresh = nil
local setMainWindowNotification = nil

local function windowOpen()
    return isWindowOpen
end

local function closeConfirmWindow()
    confirmTarget = nil
    local wa = game_react_globals and game_react_globals.getDefaultWindowApi and game_react_globals.getDefaultWindowApi()
    if wa ~= nil and AchievementConfirmWindow ~= nil then
        pcall(function()
            wa.removeAllWindows(AchievementConfirmWindow)
        end)
    end
end

local function openConfirmWindow(target)
    confirmTarget = target
    local wa = game_react_globals and game_react_globals.getDefaultWindowApi and game_react_globals.getDefaultWindowApi()
    if wa == nil or AchievementConfirmWindow == nil then return end
    pcall(function()
        wa.removeAllWindows(AchievementConfirmWindow)
        wa.addSingletonWindow(AchievementConfirmWindow, {
            onClose = closeConfirmWindow,
            initialX = 0.5,
            initialY = 0.5,
        })
        wa.moveSingletonWindowToFront(AchievementConfirmWindow)
    end)
    if updateConfirmContent then
        pcall(function()
            updateConfirmContent(target)
        end)
    end
end

local function closeWindow()
    isWindowOpen = false
    closeConfirmWindow()
    local wa = game_react_globals and game_react_globals.getDefaultWindowApi and game_react_globals.getDefaultWindowApi()
    if wa ~= nil and AchievementUnlockerWindow ~= nil then
        pcall(function()
            wa.removeAllWindows(AchievementUnlockerWindow)
        end)
    end
end

local function openWindow()
    local wa = game_react_globals and game_react_globals.getDefaultWindowApi and game_react_globals.getDefaultWindowApi()
    if wa == nil then return end
    isWindowOpen = true
    if AchievementUnlockerWindow ~= nil then
        pcall(function()
            wa.addSingletonWindow(AchievementUnlockerWindow, {
                onClose = closeWindow,
                initialX = 0.5,
                initialY = 0.5,
            })
            wa.moveSingletonWindowToFront(AchievementUnlockerWindow)
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

local AchievementUnlockerContent = react.RegisterRecipe("AchievementUnlockerContent", function()
    local refreshTick = react.useState(0)
    local filterState = react.useState("ALL") -- "ALL", "LOCKED", "UNLOCKED"
    local notificationState = react.useState("")

    triggerMainWindowRefresh = function()
        refreshTick:transform(function(v) return v + 1 end)
    end

    setMainWindowNotification = function(text)
        notificationState:set(text or "")
    end

    -- Fetch current list of achievements
    local allAchievements = {}
    if core and core.getAchievements then
        allAchievements = core.getAchievements()
    end

    -- Calculate total and unlocked count
    local totalCount = #allAchievements
    local unlockedCount = 0
    for _, a in ipairs(allAchievements) do
        if a.unlocked then
            unlockedCount = unlockedCount + 1
        end
    end
    local percent = totalCount > 0 and math.floor((unlockedCount / totalCount) * 100) or 0

    -- Filter list based on selected tab
    local currentFilter = filterState:old()
    local filteredAchievements = {}
    for _, a in ipairs(allAchievements) do
        if currentFilter == "ALL" then
            table.insert(filteredAchievements, a)
        elseif currentFilter == "LOCKED" and not a.unlocked then
            table.insert(filteredAchievements, a)
        elseif currentFilter == "UNLOCKED" and a.unlocked then
            table.insert(filteredAchievements, a)
        end
    end

    -- Header row 1: Status summary + Actions
    local statusText = string.format(_tr("STATUS_SUMMARY", "Progress: %d / %d (%d%%)"), unlockedCount, totalCount, percent)

    local headerRow1 = builtin.BoxLayout{
        meta = { class = "horizontal-spacer" },
        orientation = builtin.type.Orientation.Horizontal,
        children = {
            makeHSpacer(16),
            builtin.TextView{
                meta = { class = "font-scale-headline" },
                text = statusText,
            },
            makeExpandingSpacer(),
            builtin.Button{
                meta = {
                    class = "secondary",
                    tooltip = _tr("BTN_REFRESH", "Refresh"),
                },
                content = builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = _tr("BTN_REFRESH", "Refresh"),
                },
                onClick = function()
                    refreshTick:transform(function(v) return v + 1 end)
                end,
            },
            makeHSpacer(8),
            builtin.Button{
                meta = {
                    class = "primary",
                    tooltip = _tr("BTN_UNLOCK_ALL", "Unlock All"),
                },
                content = builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = _tr("BTN_UNLOCK_ALL", "Unlock All"),
                },
                onClick = function()
                    local remaining = totalCount - unlockedCount
                    if remaining > 0 then
                        openConfirmWindow({ type = "ALL", count = remaining })
                    end
                end,
            },
            makeHSpacer(16),
        },
    }

    -- Header row 2: Filter tabs
    local function makeFilterButton(tabKey, labelText)
        local isSelected = (currentFilter == tabKey)
        return builtin.Button{
            meta = {
                class = isSelected and "primary" or "secondary",
            },
            content = builtin.TextView{
                meta = { class = "font-scale-body" },
                text = labelText,
            },
            onClick = function()
                filterState:set(tabKey)
            end,
        }
    end

    local filterRow = builtin.BoxLayout{
        meta = { class = "horizontal-spacer" },
        orientation = builtin.type.Orientation.Horizontal,
        children = {
            makeHSpacer(16),
            makeFilterButton("ALL", string.format("%s (%d)", _tr("FILTER_ALL", "All"), totalCount)),
            makeHSpacer(8),
            makeFilterButton("LOCKED", string.format("%s (%d)", _tr("FILTER_LOCKED", "Locked"), totalCount - unlockedCount)),
            makeHSpacer(8),
            makeFilterButton("UNLOCKED", string.format("%s (%d)", _tr("FILTER_UNLOCKED", "Unlocked"), unlockedCount)),
            makeExpandingSpacer(),
            makeHSpacer(16),
        },
    }

    -- Notification message row (if present)
    local notificationRow = nil
    local currentNotif = notificationState:old()
    if currentNotif and #currentNotif > 0 then
        notificationRow = builtin.BoxLayout{
            meta = { class = "horizontal-spacer" },
            orientation = builtin.type.Orientation.Horizontal,
            children = {
                makeHSpacer(16),
                builtin.TextView{
                    meta = { class = "font-scale-caption" },
                    text = currentNotif,
                },
                makeExpandingSpacer(),
                makeHSpacer(16),
            },
        }
    end

    -- Achievement item row builder
    local function makeAchievementRow(ach)
        local iconComp = nil
        if ach.icon and #ach.icon > 0 then
            iconComp = builtin.ImageView{
                meta = {
                    styleSheet = (function()
                        if styleutil and styleutil.makeStyle then
                            local ok, s = pcall(styleutil.makeStyle, { size = { 48, 48 } })
                            if ok then return s end
                        end
                        return nil
                    end)(),
                },
                path = ach.icon,
                scaling = builtin.type.ImageViewScaling.AutoFit,
            }
        else
            iconComp = builtin.ImageView{
                meta = {
                    styleSheet = (function()
                        if styleutil and styleutil.makeStyle then
                            local ok, s = pcall(styleutil.makeStyle, { size = { 48, 48 } })
                            if ok then return s end
                        end
                        return nil
                    end)(),
                },
                path = "::/gui/context_helper/icons/menu_achievements@2x.tga",
                scaling = builtin.type.ImageViewScaling.AutoFit,
            }
        end

        local textComp = builtin.BoxLayout{
            orientation = builtin.type.Orientation.Vertical,
            children = {
                builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = ach.name or ach.id,
                },
                makeVSpacer(2),
                builtin.TextView{
                    meta = {
                        class = "font-scale-caption",
                        styleSheet = (function()
                            if styleutil and styleutil.makeStyle then
                                local ok, s = pcall(styleutil.makeStyle, { size = { 520, -1 } })
                                if ok then return s end
                            end
                            return nil
                        end)(),
                    },
                    text = ach.desc or "",
                },
            },
        }

        local actionComp = nil
        if ach.unlocked then
            actionComp = builtin.BoxLayout{
                orientation = builtin.type.Orientation.Horizontal,
                children = {
                    builtin.TextView{
                        meta = { class = "font-scale-body" },
                        text = _tr("STATUS_UNLOCKED_BADGE", "[Achieved]"),
                    },
                },
            }
        else
            actionComp = builtin.Button{
                meta = {
                    class = "primary",
                    tooltip = _tr("BTN_UNLOCK", "Unlock"),
                },
                content = builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = _tr("BTN_UNLOCK", "Unlock"),
                },
                onClick = function()
                    openConfirmWindow({ type = "SINGLE", ach = ach })
                end,
            }
        end

        return builtin.BoxLayout{
            meta = {
                class = "horizontal-spacer",
                styleSheet = (function()
                    if styleutil and styleutil.makeStyle then
                        local ok, s = pcall(styleutil.makeStyle, { size = { -1, 56 } })
                        if ok then return s end
                    end
                    return nil
                end)(),
            },
            orientation = builtin.type.Orientation.Horizontal,
            children = {
                makeHSpacer(16),
                iconComp,
                makeHSpacer(12),
                textComp,
                makeExpandingSpacer(),
                actionComp,
                makeHSpacer(16),
            },
        }
    end

    -- Scrollable list of achievements
    local rows = {}
    if #filteredAchievements == 0 then
        table.insert(rows, makeVSpacer(32))
        table.insert(rows, builtin.BoxLayout{
            meta = { class = "horizontal-spacer" },
            orientation = builtin.type.Orientation.Horizontal,
            children = {
                makeHSpacer(16),
                builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = _tr("NO_ACHIEVEMENTS_FOUND", "No achievements matching filter."),
                },
                makeExpandingSpacer(),
                makeHSpacer(16),
            },
        })
    else
        table.insert(rows, makeVSpacer(6))
        for _, ach in ipairs(filteredAchievements) do
            table.insert(rows, makeAchievementRow(ach))
            table.insert(rows, makeVSpacer(6))
        end
    end

    local scrollMeta = { class = "horizontal-spacer" }
    if styleutil and styleutil.makeStyle then
        pcall(function()
            scrollMeta.styleSheet = styleutil.makeStyle{ size = { -1, 460 } }
        end)
    end

    local scrollArea = builtin.ScrollArea{
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

    local rootChildren = {
        makeVSpacer(12),
        headerRow1,
        makeVSpacer(10),
        filterRow,
        makeVSpacer(8),
    }
    if notificationRow then
        table.insert(rootChildren, notificationRow)
        table.insert(rootChildren, makeVSpacer(8))
    end
    table.insert(rootChildren, scrollArea)
    table.insert(rootChildren, makeVSpacer(12))

    if ui and ui.createWindowBox then
        return ui.createWindowBox(rootChildren, 820, 560)
    end

    return builtin.BoxLayout{
        orientation = builtin.type.Orientation.Vertical,
        children = rootChildren,
    }
end)

-- ==============================================================================
-- Confirmation Dialog Content & Window Recipe
-- ==============================================================================

local AchievementConfirmContent = react.RegisterRecipe("AchievementConfirmContent", function()
    local targetState = react.useState(confirmTarget)
    updateConfirmContent = function(newTarget)
        targetState:set(newTarget)
    end

    local target = targetState:old() or confirmTarget
    if not target then
        return builtin.BoxLayout{
            orientation = builtin.type.Orientation.Vertical,
            children = { makeVSpacer(10) },
        }
    end

    local introText = _tr("CONFIRM_INTRO", "如果你因要完成此遊戲的所有成就影響你的生活，而身心俱疲，請按下解鎖。")
    local emphasisText = _tr("CONFIRM_EMPHASIS", "若不是，而你仍享受這個遊戲，請按下取消並取消訂閱此mod。")
    local warningText = _tr("CONFIRM_WARNING", "此操作無法復原，你確定要立即解鎖成就嗎？")

    local bodyChildren = {
        makeVSpacer(14),
        -- Paragraph 1: Intro
        builtin.BoxLayout{
            meta = { class = "horizontal-spacer" },
            orientation = builtin.type.Orientation.Horizontal,
            children = {
                makeHSpacer(20),
                builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = introText,
                },
                makeExpandingSpacer(),
                makeHSpacer(20),
            },
        },
        makeVSpacer(10),
        -- Paragraph 2: Emphasized Bold
        builtin.BoxLayout{
            meta = { class = "horizontal-spacer" },
            orientation = builtin.type.Orientation.Horizontal,
            children = {
                makeHSpacer(20),
                builtin.TextView{
                    meta = { class = "font-scale-title-4" },
                    text = emphasisText,
                },
                makeExpandingSpacer(),
                makeHSpacer(20),
            },
        },
        makeVSpacer(10),
        -- Paragraph 3: Warning
        builtin.BoxLayout{
            meta = { class = "horizontal-spacer" },
            orientation = builtin.type.Orientation.Horizontal,
            children = {
                makeHSpacer(20),
                builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = warningText,
                },
                makeExpandingSpacer(),
                makeHSpacer(20),
            },
        },
        makeVSpacer(18),
        -- Buttons row
        builtin.BoxLayout{
            meta = { class = "horizontal-spacer" },
            orientation = builtin.type.Orientation.Horizontal,
            children = {
                makeHSpacer(20),
                makeExpandingSpacer(),
                builtin.Button{
                    meta = {
                        class = "secondary",
                        tooltip = _tr("BTN_CANCEL", "Cancel"),
                    },
                    content = builtin.TextView{
                        meta = { class = "font-scale-body" },
                        text = _tr("BTN_CANCEL", "Cancel"),
                    },
                    onClick = function()
                        closeConfirmWindow()
                    end,
                },
                makeHSpacer(12),
                builtin.Button{
                    meta = {
                        class = "primary",
                        tooltip = _tr("BTN_CONFIRM_UNLOCK", "Unlock"),
                    },
                    content = builtin.TextView{
                        meta = { class = "font-scale-body" },
                        text = _tr("BTN_CONFIRM_UNLOCK", "Unlock"),
                    },
                    onClick = function()
                        if target.type == "SINGLE" and target.ach then
                            if core and core.unlock then
                                core.unlock(target.ach.id)
                                if setMainWindowNotification then
                                    setMainWindowNotification(string.format(_tr("UNLOCK_SUCCESS", "Successfully unlocked: %s"), target.ach.name or target.ach.id))
                                end
                            end
                        elseif target.type == "ALL" then
                            if core and core.unlockAll then
                                local allList = (core.getAchievements and core.getAchievements()) or {}
                                local count = core.unlockAll(allList)
                                if setMainWindowNotification then
                                    setMainWindowNotification(string.format(_tr("UNLOCK_ALL_SUCCESS", "Successfully unlocked %d achievements!"), count))
                                end
                            end
                        end
                        closeConfirmWindow()
                        if triggerMainWindowRefresh then
                            triggerMainWindowRefresh()
                        end
                    end,
                },
                makeHSpacer(20),
            },
        },
        makeVSpacer(14),
    }

    if ui and ui.createWindowBox then
        return ui.createWindowBox(bodyChildren, 640, -1)
    end

    return builtin.BoxLayout{
        orientation = builtin.type.Orientation.Vertical,
        children = bodyChildren,
    }
end)

-- Confirmation Dialog Window Wrapper Recipe
AchievementConfirmWindow = react.RegisterWrapperRecipe("AchievementConfirmWindow", builtin.Window, function(params)
    local winParams = {
        id = CONFIRM_WINDOW_ID,
        title = _tr("CONFIRM_TITLE", "給完美主義者"),
        closable = true,
        movable = true,
        onClose = closeConfirmWindow,
        initialX = params.initialX or 0.5,
        initialY = params.initialY or 0.5,
        content = AchievementConfirmContent(),
    }
    return builtin.Window(winParams)
end)

-- Window Wrapper Recipe
AchievementUnlockerWindow = react.RegisterWrapperRecipe("AchievementUnlockerWindow", builtin.Window, function(params)
    local winParams = {
        id = WINDOW_ID,
        title = _tr("ACHIEVEMENT_UNLOCKER", "Achievements Unlock"),
        closable = true,
        movable = true,
        onClose = params.onClose,
        initialX = params.initialX or 0.5,
        initialY = params.initialY or 0.5,
        content = AchievementUnlockerContent(),
    }
    return builtin.Window(winParams)
end)

-- ==============================================================================
-- Toolbar Plugin Button
-- ==============================================================================

local function pluginRoot(child)
    return builtin.BoxLayout{
        orientation = builtin.type.Orientation.Horizontal,
        children = { child },
    }
end

local AchievementsUnlockHudPlugin = react.RegisterPluginRecipe(main_mod_button_area.MainModButtonAreaExtension, "AchievementsUnlockHudPlugin", function()
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
            tooltip = _tr("TOOLTIP_OPEN_ACHIEVEMENTS", "Achievements Unlock\nView all achievements and unlock with one click"),
        },
        content = builtin.BoxLayout{
            orientation = builtin.type.Orientation.Horizontal,
            children = {
                builtin.TextView{
                    meta = { class = "font-scale-body" },
                    text = _tr("TOOLBAR_BTN_ACHIEVEMENTS", "Achievements"),
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
    AchievementsUnlockHudPlugin = AchievementsUnlockHudPlugin,
    AchievementUnlockerHudPlugin = AchievementsUnlockHudPlugin,
    ToolbarButtonPlugin = AchievementsUnlockHudPlugin,
    toggleWindow = toggleWindow,
    openWindow = openWindow,
    closeWindow = closeWindow,
    openConfirmWindow = openConfirmWindow,
    closeConfirmWindow = closeConfirmWindow,
}

function data()
    return exports
end

return exports
