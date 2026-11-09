local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local ProgressWidget = require("ui/widget/progresswidget")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")

local Logo = require("rebind/ui/logo")
local PagedScreen = require("rebind/ui/pagedscreen")

local Screen = Device.screen

local sc = PagedScreen.sc

local BatchProgress = InputContainer:extend{
    title = nil,
    stop_text = nil,
    on_stop = nil,
    total = 0,
    done = 0,
    filename = "",
    summary = "",
}

function BatchProgress:init()
    self.width = Screen:getWidth()
    self.height = Screen:getHeight()
    self.covers_fullscreen = true
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
    self:_build()
end

function BatchProgress:_build()
    local box_w = self.width - sc(48)
    local inner = box_w - sc(60)
    local stop = PagedScreen.outline_button(self.stop_text, function()
        if self.on_stop then
            self.on_stop()
        end
    end, self)
    local group = VerticalGroup:new{
        align = "center",
        Logo.widget(sc(64)),
        VerticalSpan:new{ width = sc(18) },
        TextWidget:new{
            text = string.format("%s %d of %d", self.title, self.done, self.total),
            face = Font:getFace("cfont", 24),
            bold = true,
            max_width = inner,
        },
        VerticalSpan:new{ width = sc(14) },
        ProgressWidget:new{
            width = inner,
            height = sc(14),
            percentage = self.total > 0 and self.done / self.total or 0,
            ticks = nil,
            last = nil,
        },
        VerticalSpan:new{ width = sc(14) },
        TextWidget:new{
            text = self.filename,
            face = Font:getFace("cfont", 17),
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            max_width = inner,
        },
        VerticalSpan:new{ width = sc(12) },
        TextWidget:new{ text = self.summary, face = Font:getFace("cfont", 19), max_width = inner },
        VerticalSpan:new{ width = sc(14) },
        stop,
    }
    self[1] = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        width = self.width,
        height = self.height,
        CenterContainer:new{
            dimen = self.dimen,
            FrameContainer:new{
                background = Blitbuffer.COLOR_WHITE,
                bordersize = Size.border.window,
                radius = Size.radius.window,
                padding = sc(30),
                group,
            },
        },
    }
end

function BatchProgress:update(fields)
    for key, value in pairs(fields) do
        self[key] = value
    end
    self:_build()
    UIManager:setDirty(self, "ui")
    UIManager:forceRePaint()
end

function BatchProgress:onShow()
    UIManager:setDirty(self, "full")
    return true
end

return BatchProgress
