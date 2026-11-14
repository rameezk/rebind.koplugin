local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local RenderImage = require("ui/renderimage")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local TapRow = require("rebind/ui/taprow")

local Screen = Device.screen

local CoverTiles = {}

local THUMB_HEIGHT = 190

local function sc(v)
    return Screen:scaleBySize(v)
end

local function thumbnail(option, width, height)
    local image = option.image
    local fit_w, fit_h = width, height
    if image and image.width and image.height then
        local scale = math.min(width / image.width, height / image.height)
        fit_w, fit_h = math.max(1, math.floor(image.width * scale)), math.max(1, math.floor(image.height * scale))
    end
    local bb = image and image.bytes and RenderImage:renderImageData(image.bytes, #image.bytes, false, fit_w, fit_h)
    if bb then
        return CenterContainer:new{
            dimen = Geom:new{ w = width, h = height },
            ImageWidget:new{
                image = bb,
                image_disposable = true,
                width = fit_w,
                height = fit_h,
                scale_factor = 0,
            },
        }
    end
    return FrameContainer:new{
        bordersize = Size.border.thin,
        padding = 0,
        margin = 0,
        width = width,
        height = height,
        CenterContainer:new{
            dimen = Geom:new{ w = width - 2 * Size.border.thin, h = height - 2 * Size.border.thin },
            TextWidget:new{
                text = option.text,
                face = Font:getFace("cfont", 16),
                fgcolor = Blitbuffer.COLOR_DARK_GRAY,
                max_width = width - sc(8),
            },
        },
    }
end

local function tag_widget(tag, max_width)
    return FrameContainer:new{
        bordersize = Size.border.thin,
        radius = sc(3),
        padding = sc(2),
        padding_left = sc(6),
        padding_right = sc(6),
        margin = 0,
        TextWidget:new{
            text = tag,
            face = Font:getFace("cfont", 14),
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            max_width = max_width,
        },
    }
end

local function tile(option, width, on_tap, on_hold)
    local border = option.selected and Size.border.thick or Size.border.thin
    local padding = Size.padding.default
    local inner_w = width - 2 * (border + padding)
    local height = sc(THUMB_HEIGHT)
    local column = VerticalGroup:new{
        align = "center",
        thumbnail(option, inner_w, height),
        VerticalSpan:new{ width = sc(6) },
        TextWidget:new{
            text = option.image and option.text or "",
            face = Font:getFace("cfont", 16),
            max_width = inner_w,
        },
        VerticalSpan:new{ width = sc(4) },
        tag_widget(option.tag, inner_w - sc(16)),
    }
    local box = FrameContainer:new{
        bordersize = border,
        radius = sc(4),
        padding = padding,
        margin = 0,
        column,
    }
    return TapRow:new{
        on_tap = on_tap,
        on_hold = on_hold,
        dimen = Geom:new{ w = width, h = box:getSize().h },
        box,
    }
end

function CoverTiles.new(opts)
    local gap = sc(8)
    local count = math.max(#opts.options, 1)
    local tile_w = math.floor((opts.width - (count - 1) * gap) / count)
    local row = HorizontalGroup:new{ align = "top" }
    for i, option in ipairs(opts.options) do
        if i > 1 then
            table.insert(row, HorizontalSpan:new{ width = gap })
        end
        table.insert(row, tile(option, tile_w, function()
            opts.on_select(option)
        end, function()
            opts.on_hold(option)
        end))
    end
    return row
end

return CoverTiles
