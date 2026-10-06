local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconButton = require("ui/widget/iconbutton")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")

local TapRow = require("rebind/ui/taprow")

local Screen = Device.screen

local ChoiceList = InputContainer:extend{
    title = nil,
    rows = nil,
    on_close = nil,
}

local function sc(v)
    return Screen:scaleBySize(v)
end

function ChoiceList:init()
    self.width = Screen:getWidth()
    self.height = Screen:getHeight()
    self.covers_fullscreen = true
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
    if Device:hasKeys() then
        self.key_events = { Close = { { Device.input.group.Back } } }
    end

    local pad = sc(12)
    local inner = self.width - 2 * pad

    local close_btn = IconButton:new{
        icon = "close",
        width = sc(32),
        height = sc(32),
        padding = sc(6),
        callback = function()
            self:onClose()
        end,
        show_parent = self,
    }
    local title_w = inner - close_btn:getSize().w - sc(8)
    local title_widget = TextWidget:new{
        text = self.title,
        face = Font:getFace("cfont", 24),
        bold = true,
        max_width = title_w,
    }
    local header = FrameContainer:new{
        bordersize = 0,
        padding = pad,
        HorizontalGroup:new{
            align = "center",
            LeftContainer:new{
                dimen = Geom:new{ w = title_w, h = title_widget:getSize().h },
                title_widget,
            },
            HorizontalSpan:new{ width = sc(8) },
            close_btn,
        },
    }
    self.header_height = header:getSize().h + Size.line.thin

    local body = VerticalGroup:new{ align = "left" }
    for _i, row in ipairs(self.rows) do
        local action_btn
        local action_w = 0
        if row.action_text then
            action_btn = Button:new{
                text = row.action_text,
                bordersize = Size.border.button,
                margin = 0,
                padding_h = sc(10),
                radius = Size.radius.button,
                callback = row.on_action,
                show_parent = self,
            }
            action_w = action_btn:getSize().w + sc(12)
        end
        local text_w = inner - action_w
        local lines = VerticalGroup:new{
            align = "left",
            TextBoxWidget:new{
                text = row.title,
                face = Font:getFace("cfont", 20),
                bold = true,
                width = text_w,
            },
        }
        if row.subtitle and row.subtitle ~= "" then
            table.insert(lines, TextBoxWidget:new{
                text = row.subtitle,
                face = Font:getFace("cfont", 16),
                fgcolor = Blitbuffer.COLOR_DARK_GRAY,
                width = text_w,
            })
        end
        local line = HorizontalGroup:new{ align = "center", lines }
        if action_btn then
            table.insert(line, HorizontalSpan:new{ width = sc(12) })
            table.insert(line, action_btn)
        end
        local cell = FrameContainer:new{
            bordersize = 0,
            padding = pad,
            padding_top = sc(10),
            padding_bottom = sc(10),
            width = self.width,
            line,
        }
        table.insert(body, TapRow:new{
            on_tap = row.on_select,
            dimen = Geom:new{ w = self.width, h = cell:getSize().h },
            cell,
        })
        table.insert(body, LineWidget:new{
            background = Blitbuffer.COLOR_LIGHT_GRAY,
            dimen = Geom:new{ w = self.width, h = Size.line.thin },
        })
    end

    local scroller = ScrollableContainer:new{
        dimen = Geom:new{ w = self.width, h = self.height - self.header_height },
        show_parent = self,
        bordersize = 0,
        padding = 0,
        FrameContainer:new{
            bordersize = 0,
            padding = 0,
            body,
        },
    }
    self.cropping_widget = scroller

    self[1] = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        width = self.width,
        height = self.height,
        VerticalGroup:new{
            align = "left",
            header,
            LineWidget:new{
                background = Blitbuffer.COLOR_DARK_GRAY,
                dimen = Geom:new{ w = self.width, h = Size.line.thin },
            },
            scroller,
        },
    }
end

function ChoiceList:onClose()
    UIManager:close(self, "ui")
    if self.on_close then
        self.on_close()
    end
    return true
end

function ChoiceList:onShow()
    UIManager:setDirty(self, "full")
    return true
end

function ChoiceList.show(opts)
    local list = ChoiceList:new{
        title = opts.title,
        rows = opts.rows,
        on_close = opts.on_close,
    }
    UIManager:show(list)
    return list
end

return ChoiceList
