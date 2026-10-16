local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Geom = require("ui/geometry")
local Size = require("ui/size")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local Screen = Device.screen

local function sc(v)
    return Screen:scaleBySize(v)
end

local function side()
    return sc(20)
end

local Checkbox = WidgetContainer:extend{
    checked = false,
    disabled = false,
}

function Checkbox:getSize()
    return Geom:new{ w = side(), h = side() }
end

function Checkbox:paintTo(bb, x, y)
    local s = side()
    self.dimen = Geom:new{ x = x, y = y, w = s, h = s }
    local color = self.disabled and Blitbuffer.COLOR_GRAY or Blitbuffer.COLOR_BLACK
    local border = Size.border.thick
    bb:paintRect(x, y, s, border, color)
    bb:paintRect(x, y + s - border, s, border, color)
    bb:paintRect(x, y, border, s, color)
    bb:paintRect(x + s - border, y, border, s, color)
    if self.checked then
        local inset = sc(5)
        bb:paintRect(x + inset, y + inset, s - 2 * inset, s - 2 * inset, color)
    end
end

return Checkbox
