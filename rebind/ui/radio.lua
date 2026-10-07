local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Geom = require("ui/geometry")
local Size = require("ui/size")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local Screen = Device.screen

local function sc(v)
    return Screen:scaleBySize(v)
end

local function radius()
    return sc(10)
end

local Radio = WidgetContainer:extend{
    selected = false,
}

function Radio:getSize()
    return Geom:new{ w = 2 * radius(), h = 2 * radius() }
end

function Radio:paintTo(bb, x, y)
    local r = radius()
    self.dimen = Geom:new{ x = x, y = y, w = 2 * r, h = 2 * r }
    local cx, cy = x + r, y + r
    bb:paintCircle(cx, cy, r, Blitbuffer.COLOR_BLACK, Size.border.thick)
    if self.selected then
        bb:paintCircle(cx, cy, r - sc(5), Blitbuffer.COLOR_BLACK)
    end
end

return Radio
