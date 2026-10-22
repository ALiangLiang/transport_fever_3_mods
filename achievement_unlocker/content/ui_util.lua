-- ==============================================================================
-- UI Utility & Shared Layout Helpers for Achievement Unlocker
-- ==============================================================================

local react = ug_require and ug_require("::/gui/main/react.lua") or require("/gui/main/react.lua")
local builtin = ug_require and ug_require("::/gui/main/builtin.lua") or require("/gui/main/builtin.lua")

local styleutil = nil
pcall(function()
    styleutil = ug_require and ug_require("::/gui/main/styleutil.tl") or require("/gui/main/styleutil.tl")
end)

local M = {}

-- Safe translation helper querying strings.json
function M.tr(key, default)
    if _ and type(_) == "function" then
        local ok, res = pcall(_, key)
        if ok and res and res ~= key and #res > 0 then
            return res
        end
    end
    return default or key
end

-- Horizontal spacer
function M.makeHSpacer(w)
    local meta = nil
    if styleutil and styleutil.makeStyle then
        pcall(function()
            meta = { styleSheet = styleutil.makeStyle{ size = { w, 1 } } }
        end)
    end
    return builtin.Component{ meta = meta }
end

-- Vertical spacer
function M.makeVSpacer(h)
    local meta = nil
    if styleutil and styleutil.makeStyle then
        pcall(function()
            meta = { styleSheet = styleutil.makeStyle{ size = { 1, h } } }
        end)
    end
    return builtin.Component{ meta = meta }
end

-- Expanding spacer (fills remaining space horizontally)
function M.makeExpandingSpacer()
    return builtin.Component{ meta = { class = "horizontal-spacer" } }
end

-- Full-width row wrapper with left and right 16px margins
function M.makeFullWidthRow(children, class)
    local rowChildren = { M.makeHSpacer(16) }
    for _, ch in ipairs(children) do
        table.insert(rowChildren, ch)
    end
    table.insert(rowChildren, M.makeHSpacer(16))

    local rowMeta = { class = "horizontal-spacer" }
    if class then
        rowMeta.class = rowMeta.class .. " " .. class
    end

    return builtin.BoxLayout{
        meta = rowMeta,
        orientation = builtin.type.Orientation.Horizontal,
        children = rowChildren,
    }
end

-- Scrollable container for rows
function M.createScrollArea(rows, height)
    local scrollMeta = { class = "horizontal-spacer" }
    if styleutil and styleutil.makeStyle then
        pcall(function()
            scrollMeta.styleSheet = styleutil.makeStyle{
                size = { -1, height or 420 },
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

-- Root window layout box
function M.createWindowBox(children, width, height)
    local boxMeta = nil
    if styleutil and styleutil.makeStyle then
        pcall(function()
            local s = styleutil.makeStyle{ size = { -1, height or 540 } }
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
                    local ok, s = pcall(styleutil.makeStyle, { size = { width or 820, 0 } })
                    if ok then return { styleSheet = s } end
                end
                return nil
            end)(),
        },
    }
    for _, ch in ipairs(children) do
        table.insert(allChildren, ch)
    end
    return builtin.BoxLayout{
        meta = boxMeta,
        orientation = builtin.type.Orientation.Vertical,
        children = allChildren,
    }
end

return M
