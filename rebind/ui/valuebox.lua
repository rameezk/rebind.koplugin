local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LeftContainer = require("ui/widget/container/leftcontainer")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local Radio = require("rebind/ui/radio")
local TapRow = require("rebind/ui/taprow")

local Screen = Device.screen

local function sc(v)
    return Screen:scaleBySize(v)
end

local DashedFrame = WidgetContainer:extend{
    padding = 0,
    thickness = 1,
}

function DashedFrame:init()
    self.dash = self.dash or sc(6)
    self.gap = self.gap or sc(4)
end

function DashedFrame:getSize()
    local inner = self[1]:getSize()
    return Geom:new{ w = inner.w + 2 * self.padding, h = inner.h + 2 * self.padding }
end

function DashedFrame:paintTo(bb, x, y)
    local size = self:getSize()
    self.dimen = Geom:new{ x = x, y = y, w = size.w, h = size.h }
    self[1]:paintTo(bb, x + self.padding, y + self.padding)
    local t, step = self.thickness, self.dash + self.gap
    local color = Blitbuffer.COLOR_BLACK
    for dx = 0, size.w - 1, step do
        local w = math.min(self.dash, size.w - dx)
        bb:paintRect(x + dx, y, w, t, color)
        bb:paintRect(x + dx, y + size.h - t, w, t, color)
    end
    for dy = 0, size.h - 1, step do
        local h = math.min(self.dash, size.h - dy)
        bb:paintRect(x, y + dy, t, h, color)
        bb:paintRect(x + size.w - t, y + dy, t, h, color)
    end
end

local StruckText = WidgetContainer:extend{}

function StruckText:getSize()
    return self[1]:getSize()
end

function StruckText:paintTo(bb, x, y)
    local size = self:getSize()
    self.dimen = Geom:new{ x = x, y = y, w = size.w, h = size.h }
    self[1]:paintTo(bb, x, y)
    bb:paintRect(x, y + math.floor(size.h / 2), size.w, Size.line.medium, Blitbuffer.COLOR_BLACK)
end

local ValueBox = {}

local FACE_SIZE = 18

local function tag_widget(tag)
    local label = TextWidget:new{
        text = tag,
        face = Font:getFace("cfont", 14),
        fgcolor = Blitbuffer.COLOR_DARK_GRAY,
    }
    return FrameContainer:new{
        bordersize = Size.border.thin,
        radius = sc(3),
        padding = sc(2),
        margin = 0,
        label,
    }
end

local function text_widget(opts, width)
    local shown = (opts.text ~= nil and opts.text ~= "") and opts.text or _("(none)")
    if opts.tag == "removed" then
        local struck = StruckText:new{
            TextWidget:new{
                text = shown,
                face = Font:getFace("cfont", FACE_SIZE),
                max_width = width,
            },
        }
        return LeftContainer:new{
            dimen = Geom:new{ w = width, h = struck:getSize().h },
            struck,
        }
    end
    local face = opts.tag == "translated" and Font:getFace("NotoSans-Italic.ttf", FACE_SIZE)
        or Font:getFace("cfont", FACE_SIZE)
    return TextBoxWidget:new{
        text = shown,
        face = face,
        width = width,
        alignment = "left",
        fgcolor = opts.empty and Blitbuffer.COLOR_DARK_GRAY or Blitbuffer.COLOR_BLACK,
    }
end

function ValueBox.new(opts)
    local border = opts.selected and Size.border.thick or Size.border.thin
    local padding = Size.padding.default
    local inner_w = opts.width - 2 * (border + padding)
    local tag = tag_widget(opts.tag)
    local gap = sc(10)
    local text_w = inner_w - Radio:new{}:getSize().w - tag:getSize().w - 2 * gap

    local row = HorizontalGroup:new{
        align = "center",
        Radio:new{ selected = opts.selected },
        HorizontalSpan:new{ width = gap },
        text_widget(opts, text_w),
        HorizontalSpan:new{ width = gap },
        tag,
    }

    local box
    if opts.tag == "translated" then
        box = DashedFrame:new{
            padding = padding + border,
            thickness = border,
            row,
        }
    else
        box = FrameContainer:new{
            bordersize = border,
            radius = sc(4),
            padding = padding,
            margin = 0,
            row,
        }
    end

    return TapRow:new{
        on_tap = opts.on_tap,
        dimen = Geom:new{ w = opts.width, h = box:getSize().h },
        box,
    }
end

return ValueBox
