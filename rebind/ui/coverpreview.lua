local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderImage = require("ui/renderimage")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")

local PagedScreen = require("rebind/ui/pagedscreen")

local Screen = Device.screen

local sc = PagedScreen.sc

local CoverPreview = InputContainer:extend{
    preview = nil,
    on_back = nil,
    on_select = nil,
}

function CoverPreview:init()
    self.width = Screen:getWidth()
    self.height = Screen:getHeight()
    self.covers_fullscreen = true
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
    if Device:hasKeys() then
        self.key_events = { Close = { { Device.input.group.Back } } }
    end
    self:_build()
end

function CoverPreview:_details()
    local p = self.preview
    local lines = { _("Source") .. ": " .. tostring(p.source) }
    if p.edition then
        table.insert(lines, _("Edition") .. ": " .. p.edition)
    end
    table.insert(lines, _("Size") .. ": " .. p.size)
    if p.file_size then
        table.insert(lines, _("File size") .. ": " .. p.file_size)
    end
    return lines
end

function CoverPreview:_image(width, height)
    local image = self.preview.image
    local bb = image and RenderImage:renderImageData(image.bytes, #image.bytes, false, width, height)
    if bb then
        return CenterContainer:new{
            dimen = Geom:new{ w = width, h = height },
            ImageWidget:new{
                image = bb,
                image_disposable = true,
                width = width,
                height = height,
                scale_factor = 0,
            },
        }
    end
    return CenterContainer:new{
        dimen = Geom:new{ w = width, h = height },
        TextWidget:new{
            text = self.preview.size,
            face = Font:getFace("cfont", 22),
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            max_width = width,
        },
    }
end

function CoverPreview:_build()
    local pad = sc(17)
    local inner = self.width - 2 * pad
    local details = VerticalGroup:new{ align = "left" }
    for _i, line in ipairs(self:_details()) do
        table.insert(details, TextWidget:new{
            text = line,
            face = Font:getFace("cfont", 20),
            max_width = inner,
        })
    end
    local gap = sc(10)
    local button_w = math.floor((inner - gap) / 2)
    local buttons = HorizontalGroup:new{
        PagedScreen.outline_button(_("Back"), function()
            self:onClose()
        end, self, true, button_w),
        HorizontalSpan:new{ width = gap },
        PagedScreen.primary_button(_("Select this cover"), button_w, true, function()
            if self.on_select then
                self.on_select()
            end
        end, self),
    }
    local image_h = self.height - details:getSize().h - buttons:getSize().h - 4 * pad
    self[1] = FrameContainer:new{
        bordersize = 0,
        padding = pad,
        background = Blitbuffer.COLOR_WHITE,
        width = self.width,
        height = self.height,
        VerticalGroup:new{
            align = "center",
            self:_image(inner, image_h),
            VerticalSpan:new{ width = pad },
            details,
            VerticalSpan:new{ width = pad },
            buttons,
        },
    }
end

function CoverPreview:onClose()
    if self.on_back then
        self.on_back()
    end
    return true
end

function CoverPreview:onCloseWidget()
    UIManager:setDirty(nil, "full")
end

return CoverPreview
