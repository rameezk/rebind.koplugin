local Device = require("device")
local IconButton = require("ui/widget/iconbutton")

local Screen = Device.screen

local CloseIcon = {}

function CloseIcon.new(opts)
    return IconButton:new{
        icon = "close",
        width = Screen:scaleBySize(32),
        height = Screen:scaleBySize(32),
        padding = Screen:scaleBySize(6),
        callback = opts.callback,
        show_parent = opts.show_parent,
    }
end

return CloseIcon
