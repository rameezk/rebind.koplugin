local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")

local Screen = Device.screen

local function sc(v)
    return Screen:scaleBySize(v)
end

local DiffPicker = InputContainer:extend{
    fields = nil,
    selection = nil,
    on_apply = nil,
    subtitle = nil,
    keep_backup = nil,
    move_to_sorted = nil,
}

function DiffPicker:init()
    self.width = Screen:getWidth()
    self.height = Screen:getHeight()
    self.covers_fullscreen = true
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }

    if self.keep_backup == nil then
        self.keep_backup = true
    end
    if self.move_to_sorted == nil then
        self.move_to_sorted = false
    end

    if Device:hasKeys() then
        self.key_events = { Close = { { Device.input.group.Back } } }
    end

    self.selection = {}
    for _, f in ipairs(self.fields) do
        local has_new = f.new_text ~= nil and f.new_text ~= ""
        if has_new and f.new_text ~= f.current_text then
            self.selection[f.key] = "new"
        else
            self.selection[f.key] = "current"
        end
    end

    self:_build()
end

function DiffPicker:_value_box(text, width, dim)
    local face = Font:getFace("cfont", 18)
    local shown = (text ~= nil and text ~= "") and text or _("(none)")
    local box = TextBoxWidget:new{
        text = shown,
        face = face,
        width = width - 2 * Size.padding.default,
        alignment = "left",
        fgcolor = dim and Blitbuffer.COLOR_DARK_GRAY or Blitbuffer.COLOR_BLACK,
    }
    return FrameContainer:new{
        bordersize = Size.border.thin,
        radius = sc(4),
        padding = Size.padding.default,
        width = width,
        LeftContainer:new{
            dimen = Geom:new{ w = width - 2 * Size.padding.default, h = box:getSize().h },
            box,
        },
    }
end

function DiffPicker:_select_button(text, width, selected, callback, enabled)
    local btn = Button:new{
        text = text,
        width = width,
        radius = sc(4),
        bordersize = Size.border.button,
        padding = sc(8),
        enabled = enabled ~= false,
        background = selected and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_WHITE,
        show_parent = self,
        callback = callback,
    }
    if selected and btn.label_widget then
        btn.label_widget.fgcolor = Blitbuffer.COLOR_WHITE
    end
    return btn
end

function DiffPicker:_field_row(field, col_w)
    local group = VerticalGroup:new{ align = "left" }

    table.insert(group, TextWidget:new{
        text = field.label,
        face = Font:getFace("tfont", 18),
    })
    table.insert(group, VerticalSpan:new{ width = sc(4) })

    table.insert(group, HorizontalGroup:new{
        self:_value_box(field.current_text, col_w),
        HorizontalSpan:new{ width = sc(8) },
        self:_value_box(field.new_text, col_w, field.new_text == nil or field.new_text == ""),
    })
    table.insert(group, VerticalSpan:new{ width = sc(6) })

    local has_new = field.new_text ~= nil and field.new_text ~= ""
    local sel = self.selection[field.key]
    table.insert(group, HorizontalGroup:new{
        self:_select_button(_("◂ Keep current"), col_w, sel == "current", function()
            self.selection[field.key] = "current"
            self:_refresh()
        end),
        HorizontalSpan:new{ width = sc(8) },
        self:_select_button(_("Use new ▸"), col_w, sel == "new", function()
            self.selection[field.key] = "new"
            self:_refresh()
        end, has_new),
    })

    return FrameContainer:new{
        bordersize = 0,
        padding = Size.padding.default,
        group,
    }
end

function DiffPicker:_build()
    local content_inner = self.width - 2 * Size.padding.default
    local col_w = math.floor((content_inner - sc(8)) / 2) - Size.padding.default

    local bulk_w = math.floor((content_inner - sc(8)) / 2)
    local keep_all_btn = Button:new{
        text = _("Keep all current"),
        radius = sc(4),
        padding = sc(8),
        bordersize = Size.border.button,
        width = bulk_w,
        show_parent = self,
        callback = function()
            self:_select_all("current")
        end,
    }
    local use_all_btn = Button:new{
        text = _("Use all new"),
        radius = sc(4),
        padding = sc(8),
        bordersize = Size.border.button,
        width = bulk_w,
        show_parent = self,
        callback = function()
            self:_select_all("new")
        end,
    }

    local header = FrameContainer:new{
        bordersize = 0,
        padding = Size.padding.default,
        VerticalGroup:new{
            align = "left",
            TextWidget:new{
                text = _("Update metadata"),
                face = Font:getFace("tfont", 22),
            },
            VerticalSpan:new{ width = sc(2) },
            TextWidget:new{
                text = self.subtitle or _("Choose current or new for each field"),
                face = Font:getFace("cfont", 15),
                fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            },
            VerticalSpan:new{ width = sc(6) },
            HorizontalGroup:new{
                keep_all_btn,
                HorizontalSpan:new{ width = sc(8) },
                use_all_btn,
            },
        },
    }

    local function col_head(text)
        local tw = TextWidget:new{
            text = text,
            face = Font:getFace("tfont", 16),
        }
        return LeftContainer:new{
            dimen = Geom:new{ w = col_w, h = tw:getSize().h },
            tw,
        }
    end
    local col_header = FrameContainer:new{
        bordersize = 0,
        padding = Size.padding.default,
        HorizontalGroup:new{
            col_head(_("Current")),
            HorizontalSpan:new{ width = sc(8) },
            col_head(_("New (Hardcover)")),
        },
    }

    local body = VerticalGroup:new{ align = "left" }
    for i, field in ipairs(self.fields) do
        table.insert(body, self:_field_row(field, col_w))
        if i < #self.fields then
            table.insert(body, LineWidget:new{
                background = Blitbuffer.COLOR_LIGHT_GRAY,
                dimen = Geom:new{ w = content_inner, h = Size.line.thin },
            })
        end
    end

    local apply_btn = Button:new{
        text = _("Apply"),
        radius = sc(4),
        padding = sc(11),
        bordersize = 0,
        background = Blitbuffer.COLOR_BLACK,
        width = math.floor(content_inner / 2) - sc(6),
        show_parent = self,
        callback = function()
            self:_apply()
        end,
    }
    if apply_btn.label_widget then
        apply_btn.label_widget.fgcolor = Blitbuffer.COLOR_WHITE
    end
    local cancel_btn = Button:new{
        text = _("Cancel"),
        radius = sc(4),
        padding = sc(11),
        bordersize = Size.border.button,
        width = math.floor(content_inner / 2) - sc(6),
        show_parent = self,
        callback = function()
            self:onClose()
        end,
    }
    local toggle_w = math.floor((content_inner - sc(8)) / 2)
    local backup_btn = Button:new{
        text = self.keep_backup and _("Keep backup: On") or _("Keep backup: Off"),
        radius = sc(4),
        padding = sc(8),
        bordersize = Size.border.button,
        width = toggle_w,
        show_parent = self,
        callback = function()
            self.keep_backup = not self.keep_backup
            self:_refresh()
        end,
    }
    local move_btn = Button:new{
        text = self.move_to_sorted and _("Sort book: On") or _("Sort book: Off"),
        radius = sc(4),
        padding = sc(8),
        bordersize = Size.border.button,
        width = toggle_w,
        show_parent = self,
        callback = function()
            self.move_to_sorted = not self.move_to_sorted
            self:_refresh()
        end,
    }
    local footer = FrameContainer:new{
        bordersize = 0,
        padding = Size.padding.default,
        VerticalGroup:new{
            align = "left",
            HorizontalGroup:new{
                backup_btn,
                HorizontalSpan:new{ width = sc(8) },
                move_btn,
            },
            VerticalSpan:new{ width = sc(6) },
            HorizontalGroup:new{
                apply_btn,
                HorizontalSpan:new{ width = sc(12) },
                cancel_btn,
            },
        },
    }

    local header_h = header:getSize().h
    local col_header_h = col_header:getSize().h
    local footer_h = footer:getSize().h
    local body_h = self.height - header_h - col_header_h - footer_h - 3 * sc(2)
    if body_h < math.floor(self.height * 0.4) then
        body_h = math.floor(self.height * 0.4)
    end

    local previous = self.cropping_widget
    local scroller = ScrollableContainer:new{
        dimen = Geom:new{ w = self.width, h = body_h },
        show_parent = self,
        bordersize = 0,
        padding = 0,
        FrameContainer:new{
            bordersize = 0,
            padding = 0,
            body,
        },
    }
    if previous then
        scroller:setScrolledOffset(previous:getScrolledOffset())
        previous:onCloseWidget()
    end
    self.cropping_widget = scroller

    local content = VerticalGroup:new{
        align = "left",
        header,
        LineWidget:new{
            background = Blitbuffer.COLOR_DARK_GRAY,
            dimen = Geom:new{ w = self.width, h = Size.line.thin },
        },
        col_header,
        scroller,
        LineWidget:new{
            background = Blitbuffer.COLOR_DARK_GRAY,
            dimen = Geom:new{ w = self.width, h = Size.line.thin },
        },
        footer,
    }

    self[1] = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        width = self.width,
        height = self.height,
        content,
    }
end

function DiffPicker:_select_all(choice)
    for _, f in ipairs(self.fields) do
        if choice == "new" then
            local has_new = f.new_text ~= nil and f.new_text ~= ""
            self.selection[f.key] = has_new and "new" or "current"
        else
            self.selection[f.key] = "current"
        end
    end
    self:_refresh()
end

function DiffPicker:_refresh()
    self:_build()
    UIManager:setDirty(self, "ui")
end

function DiffPicker:_apply()
    local changes = {}
    for _, f in ipairs(self.fields) do
        if self.selection[f.key] == "new" then
            f.apply(changes)
        end
    end
    UIManager:close(self, "ui")
    if self.on_apply then
        self.on_apply(changes, {
            keep_backup = self.keep_backup,
            move_to_sorted = self.move_to_sorted,
        })
    end
end

function DiffPicker:onClose()
    UIManager:close(self, "ui")
    return true
end

function DiffPicker:onShow()
    UIManager:setDirty(self, "full")
    return true
end

return DiffPicker
