local Device = require("device")
local ImageWidget = require("ui/widget/imagewidget")
local InfoMessage = require("ui/widget/infomessage")
local RenderImage = require("ui/renderimage")
local UIManager = require("ui/uimanager")

local Screen = Device.screen

local Logo = {}

local function asset_path()
    local source = debug.getinfo(1, "S").source:gsub("^@", "")
    local dir = source:match("^(.*)/ui/logo%.lua$") or "rebind"
    return dir .. "/assets/rebind-eink.svg"
end

function Logo.widget(size)
    return ImageWidget:new{
        file = asset_path(),
        width = size,
        height = size,
        alpha = true,
        scale_factor = 0,
    }
end

function Logo.message(text)
    local size = Screen:scaleBySize(64)
    local bb = RenderImage:renderSVGImageFile(asset_path(), size, size)
    return InfoMessage:new{
        text = text,
        image = bb,
        image_width = size,
        image_height = size,
        alpha = true,
        dismissable = false,
        flush_events_on_show = true,
    }
end

function Logo.show_message(text)
    local widget = Logo.message(text)
    UIManager:show(widget)
    UIManager:forceRePaint()
    return widget
end

function Logo.close_message(widget)
    if widget then
        UIManager:close(widget)
        UIManager:forceRePaint()
    end
end

return Logo
