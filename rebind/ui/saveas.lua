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
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")

local Naming = require("rebind/ui/naming")
local Organize = require("rebind/organize")
local Radio = require("rebind/ui/radio")
local TapRow = require("rebind/ui/taprow")

local Screen = Device.screen

local function sc(v)
    return Screen:scaleBySize(v)
end

local SaveAs = InputContainer:extend{
    state = nil,
    on_change = nil,
    on_choose_root = nil,
    on_close = nil,
}

function SaveAs:init()
    self.width = Screen:getWidth()
    self.height = Screen:getHeight()
    self.covers_fullscreen = true
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
    self.view_w = self.width - 3 * ScrollableContainer.scroll_bar_width
    if Device:hasKeys() then
        self.key_events = { Close = { { Device.input.group.Back } } }
    end
    self:_build()
end

function SaveAs:_remember(patch)
    local save_as = self.state.save_as
    for k, v in pairs(patch) do
        save_as[k] = v
    end
    if self.on_change then
        self.on_change(save_as)
    end
end

function SaveAs:_update(patch)
    self:_remember(patch)
    self:_refresh()
end

function SaveAs:_choose_sort()
    if self.state.save_as.root then
        self:_update{ sort = true }
        return
    end
    self.on_choose_root(function(dir)
        self:_update{ root = dir, sort = true }
    end)
end

function SaveAs:_change_root()
    self.on_choose_root(function(dir)
        self:_update{ root = dir }
    end)
end

function SaveAs:_edit_templates(kind)
    local save_as = self.state.save_as
    Naming.show{
        kind = kind,
        metadata = function()
            return self.state:metadata()
        end,
        filename_template = save_as.filename_template,
        folder_template = save_as.folder_template,
        custom_filename_template = save_as.custom_filename_template,
        custom_folder_template = save_as.custom_folder_template,
        on_select_filename = function(template)
            self:_remember{ filename_template = template }
        end,
        on_select_folder = function(template)
            self:_remember{ folder_template = template }
        end,
        on_save_custom_filename = function(template)
            self:_remember{ custom_filename_template = template, filename_template = template }
        end,
        on_save_custom_folder = function(template)
            self:_remember{ custom_folder_template = template, folder_template = template }
        end,
        on_close = function()
            self:_refresh()
        end,
    }
end

function SaveAs:_row(opts)
    local pad = sc(12)
    local inner = self.view_w - 2 * pad - (opts.indent or 0)
    local action_btn
    local action_w = 0
    if opts.action_text then
        action_btn = Button:new{
            text = opts.action_text,
            bordersize = Size.border.button,
            margin = 0,
            padding_h = sc(10),
            radius = Size.radius.button,
            callback = opts.on_tap,
            show_parent = self,
        }
        action_w = action_btn:getSize().w + sc(12)
    end
    local mark
    local mark_w = 0
    if opts.selected ~= nil then
        mark = Radio:new{ selected = opts.selected }
        mark_w = mark:getSize().w + sc(12)
    end
    local text_w = inner - action_w - mark_w
    local lines = VerticalGroup:new{
        align = "left",
        TextBoxWidget:new{
            text = opts.title,
            face = Font:getFace("cfont", 20),
            bold = opts.selected == true,
            width = text_w,
        },
    }
    if opts.subtitle and opts.subtitle ~= "" then
        table.insert(lines, TextBoxWidget:new{
            text = opts.subtitle,
            face = Font:getFace("cfont", 16),
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            width = text_w,
        })
    end
    local line = HorizontalGroup:new{ align = "center" }
    if opts.indent then
        table.insert(line, HorizontalSpan:new{ width = opts.indent })
    end
    if mark then
        table.insert(line, mark)
        table.insert(line, HorizontalSpan:new{ width = sc(12) })
    end
    table.insert(line, lines)
    if action_btn then
        table.insert(line, HorizontalSpan:new{ width = sc(12) })
        table.insert(line, action_btn)
    end
    local cell = FrameContainer:new{
        bordersize = 0,
        padding = pad,
        padding_top = sc(10),
        padding_bottom = sc(10),
        width = self.view_w,
        line,
    }
    return TapRow:new{
        on_tap = opts.on_tap,
        dimen = Geom:new{ w = self.view_w, h = cell:getSize().h },
        cell,
    }
end

function SaveAs:_section_label(text)
    return FrameContainer:new{
        bordersize = 0,
        padding = sc(12),
        padding_bottom = sc(2),
        TextWidget:new{
            text = text,
            face = Font:getFace("cfont", 15),
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            max_width = self.view_w - 2 * sc(12),
        },
    }
end

function SaveAs:_separator()
    return LineWidget:new{
        background = Blitbuffer.COLOR_LIGHT_GRAY,
        dimen = Geom:new{ w = self.view_w, h = Size.line.thin },
    }
end

function SaveAs:_result_box()
    local pad = sc(12)
    local inner = self.view_w - 4 * pad
    local clash = self.state:name_clash()
    local group = VerticalGroup:new{
        align = "left",
        TextWidget:new{
            text = _("Result"),
            face = Font:getFace("cfont", 15),
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            max_width = inner,
        },
        TextBoxWidget:new{
            text = self.state:destination(),
            face = Font:getFace("cfont", 18),
            width = inner,
        },
    }
    if clash then
        table.insert(group, TextBoxWidget:new{
            text = _("A file with this name already exists"),
            face = Font:getFace("cfont", 16),
            bold = true,
            width = inner,
        })
    end
    return FrameContainer:new{
        bordersize = 0,
        padding = pad,
        FrameContainer:new{
            bordersize = Size.border.default,
            radius = sc(4),
            padding = pad,
            group,
        },
    }
end

function SaveAs:_build()
    local save_as = self.state.save_as
    local body = VerticalGroup:new{ align = "left" }
    local function add(widget)
        table.insert(body, widget)
    end

    add(self:_result_box())

    add(self:_section_label(_("Folder")))
    add(self:_separator())
    add(self:_row{
        title = _("Leave where it is"),
        selected = not save_as.sort,
        on_tap = function()
            self:_update{ sort = false }
        end,
    })
    add(self:_separator())
    add(self:_row{
        title = _("Sort into the Sorted library"),
        selected = save_as.sort == true,
        on_tap = function()
            self:_choose_sort()
        end,
    })
    add(self:_separator())
    if save_as.sort then
        add(self:_row{
            title = _("Folder template"),
            subtitle = Organize.pattern_label(save_as.folder_template) .. " ▸",
            indent = sc(36),
            on_tap = function()
                self:_edit_templates("folder")
            end,
        })
        add(self:_separator())
        add(self:_row{
            title = _("Sorted library"),
            subtitle = save_as.root or _("Not chosen yet"),
            action_text = _("Change ▸"),
            indent = sc(36),
            on_tap = function()
                self:_change_root()
            end,
        })
        add(self:_separator())
    end

    add(VerticalSpan:new{ width = sc(8) })
    add(self:_section_label(_("Filename")))
    add(self:_separator())
    add(self:_row{
        title = _("Keep current name"),
        selected = not save_as.rename,
        on_tap = function()
            self:_update{ rename = false }
        end,
    })
    add(self:_separator())
    add(self:_row{
        title = _("Rename"),
        selected = save_as.rename == true,
        on_tap = function()
            self:_update{ rename = true }
        end,
    })
    add(self:_separator())
    if save_as.rename then
        add(self:_row{
            title = _("Filename template"),
            subtitle = Organize.pattern_label(save_as.filename_template) .. " ▸",
            indent = sc(36),
            on_tap = function()
                self:_edit_templates("filename")
            end,
        })
        add(self:_separator())
    end

    add(VerticalSpan:new{ width = sc(8) })
    add(self:_separator())
    add(self:_row{
        title = _("Keep a backup"),
        subtitle = save_as.keep_backup and _("The original is kept as .rebind.bak") or _("The original is replaced"),
        action_text = save_as.keep_backup and _("On") or _("Off"),
        on_tap = function()
            self:_update{ keep_backup = not save_as.keep_backup }
        end,
    })
    add(self:_separator())
    add(VerticalSpan:new{ width = sc(16) })

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
        text = _("Save as"),
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
    local header_height = header:getSize().h + Size.line.thin

    local previous = self.cropping_widget
    local scroller = ScrollableContainer:new{
        dimen = Geom:new{ w = self.width, h = self.height - header_height },
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

function SaveAs:_refresh()
    self:_build()
    UIManager:setDirty(self, "ui")
end

function SaveAs:onClose()
    UIManager:close(self, "ui")
    if self.on_close then
        self.on_close()
    end
    return true
end

function SaveAs:onShow()
    UIManager:setDirty(self, "full")
    return true
end

function SaveAs.show(opts)
    local screen = SaveAs:new{
        state = opts.state,
        on_change = opts.on_change,
        on_choose_root = opts.on_choose_root,
        on_close = opts.on_close,
    }
    UIManager:show(screen)
    return screen
end

return SaveAs
