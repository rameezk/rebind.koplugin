local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local CenterContainer = require("ui/widget/container/centercontainer")

local CloseIcon = require("rebind/ui/closeicon")

local Screen = Device.screen

local function sc(v)
    return Screen:scaleBySize(v)
end

local PagedScreen = InputContainer:extend{
    title = nil,
    build = nil,
    on_close = nil,
    page = 1,
}

PagedScreen.sc = sc

function PagedScreen.heading(text, width)
    return FrameContainer:new{
        bordersize = 0,
        padding = 0,
        padding_left = sc(17),
        padding_top = sc(12),
        padding_bottom = sc(4),
        TextWidget:new{
            text = text,
            face = Font:getFace("cfont", 16),
            bold = true,
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            max_width = width - sc(34),
        },
    }
end

function PagedScreen.primary_button(text, width, enabled, callback, show_parent)
    local button = Button:new{
        text = text,
        enabled = enabled,
        radius = sc(4),
        padding = sc(11),
        bordersize = 0,
        background = Blitbuffer.COLOR_BLACK,
        width = width,
        show_parent = show_parent,
        callback = callback,
    }
    if button.label_widget and enabled then
        button.label_widget.fgcolor = Blitbuffer.COLOR_WHITE
    end
    return button
end

function PagedScreen.outline_button(text, callback, show_parent, bold, width)
    return Button:new{
        width = width,
        text = text,
        bordersize = Size.border.button,
        margin = 0,
        padding_h = sc(10),
        radius = Size.radius.button,
        text_font_bold = bold ~= false,
        callback = callback,
        show_parent = show_parent,
    }
end

function PagedScreen:init()
    self.width = Screen:getWidth()
    self.height = Screen:getHeight()
    self.covers_fullscreen = true
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
    if Device:hasKeys() then
        self.key_events = { Close = { { Device.input.group.Back } } }
    end
    self.ges_events = {
        Swipe = {
            GestureRange:new{ ges = "swipe", range = self.dimen },
        },
    }
    self:_build()
end

function PagedScreen:_header(title)
    local pad = sc(17)
    local close_btn = CloseIcon.new{
        callback = function()
            self:onClose()
        end,
        show_parent = self,
    }
    local title_w = self.width - 2 * pad - close_btn:getSize().w - sc(8)
    local title_widget = TextWidget:new{
        text = title,
        face = Font:getFace("cfont", 24),
        bold = true,
        max_width = title_w,
    }
    return FrameContainer:new{
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
end

function PagedScreen:_rule(color)
    return LineWidget:new{
        background = color or Blitbuffer.COLOR_DARK_GRAY,
        dimen = Geom:new{ w = self.width, h = Size.line.thin },
    }
end

function PagedScreen:_pager(pages)
    local function step(label, target, enabled)
        return Button:new{
            text = label,
            enabled = enabled,
            bordersize = 0,
            margin = 0,
            padding = sc(6),
            padding_h = sc(18),
            text_font_size = 22,
            callback = function()
                self:goto_page(target)
            end,
            show_parent = self,
        }
    end
    local row = HorizontalGroup:new{
        align = "center",
        step("«", 1, self.page > 1),
        step("‹", self.page - 1, self.page > 1),
        TextWidget:new{
            text = string.format("%d / %d", self.page, pages),
            face = Font:getFace("cfont", 22),
        },
        step("›", self.page + 1, self.page < pages),
        step("»", pages, self.page < pages),
    }
    return CenterContainer:new{
        dimen = Geom:new{ w = self.width, h = row:getSize().h + sc(8) },
        row,
    }
end

function PagedScreen:_paginate(items, room)
    local pages, current, used = {}, {}, 0
    local last_section
    local function flush()
        pages[#pages + 1] = current
        current, used = {}, 0
    end
    for _i, item in ipairs(items) do
        local height = item.widget:getSize().h
        if used + height > room and #current > 0 then
            flush()
        end
        if #current == 0 and item.section and item.section == last_section and not item.is_heading then
            local cont = {
                widget = PagedScreen.heading(item.continued, self.width),
                is_heading = true,
            }
            current[#current + 1] = cont
            used = used + cont.widget:getSize().h
        end
        current[#current + 1] = item
        used = used + height
        if item.section then
            last_section = item.section
        end
    end
    if #current > 0 or #pages == 0 then
        flush()
    end
    return pages
end

function PagedScreen:_build()
    local spec = self.build(self)
    local header = self:_header(spec.title or self.title)
    local top = VerticalGroup:new{ align = "left" }
    for _i, widget in ipairs(spec.top or {}) do
        table.insert(top, widget)
    end
    local bottom = VerticalGroup:new{ align = "left" }
    for _i, widget in ipairs(spec.bottom or {}) do
        table.insert(bottom, widget)
    end
    local fixed = header:getSize().h + Size.line.thin + top:getSize().h + bottom:getSize().h
        + sc(8) + Size.line.thin
    local pager_probe = self:_pager(1)
    local room = self.height - fixed - pager_probe:getSize().h
    local pages = self:_paginate(spec.items or {}, room)
    self.page_count = #pages
    self.page = math.max(1, math.min(self.page, #pages))

    local body = VerticalGroup:new{ align = "left" }
    local used = 0
    for _i, item in ipairs(pages[self.page]) do
        table.insert(body, item.widget)
        used = used + item.widget:getSize().h
    end
    table.insert(body, VerticalSpan:new{ width = math.max(0, room - used) })

    self[1] = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        width = self.width,
        height = self.height,
        VerticalGroup:new{
            align = "left",
            header,
            self:_rule(),
            top,
            body,
            self:_rule(Blitbuffer.COLOR_LIGHT_GRAY),
            self:_pager(#pages),
            FrameContainer:new{
                bordersize = 0,
                padding = 0,
                padding_left = sc(17),
                padding_right = sc(17),
                padding_bottom = sc(8),
                bottom,
            },
        },
    }
end

function PagedScreen:goto_page(page)
    self.page = math.max(1, math.min(page, self.page_count))
    self:refresh()
end

function PagedScreen:refresh()
    self:_build()
    UIManager:setDirty(self, "ui")
end

function PagedScreen:onSwipe(_arg, ges)
    local direction = ges.direction
    if direction == "west" and self.page < self.page_count then
        self:goto_page(self.page + 1)
        return true
    elseif direction == "east" and self.page > 1 then
        self:goto_page(self.page - 1)
        return true
    end
end

function PagedScreen:onClose()
    if self.on_close then
        self.on_close(self)
    else
        UIManager:close(self, "ui")
    end
    return true
end

function PagedScreen:onShow()
    UIManager:setDirty(self, "full")
    return true
end


return PagedScreen
