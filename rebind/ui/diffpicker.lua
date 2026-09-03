local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local ButtonDialog = require("ui/widget/buttondialog")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local InputDialog = require("ui/widget/inputdialog")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")

local Translate = require("rebind/translate")

local Screen = Device.screen

local function sc(v)
    return Screen:scaleBySize(v)
end

local TapBox = InputContainer:extend{
    on_tap = nil,
}

function TapBox:init()
    self.ges_events = {
        Tap = {
            GestureRange:new{
                ges = "tap",
                range = function()
                    return self.dimen
                end,
            },
        },
    }
end

function TapBox:onTap()
    if self.on_tap then
        self.on_tap()
        return true
    end
end

local DiffPicker = InputContainer:extend{
    fields = nil,
    selection = nil,
    custom = nil,
    on_apply = nil,
    subtitle = nil,
    new_label = nil,
    keep_backup = nil,
    move_to_sorted = nil,
    edition_label = nil,
    on_choose_edition = nil,
    translate_targets = nil,
    on_translate = nil,
    on_choose_language = nil,
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
    self.custom = {}
    self:_default_selection()

    self:_build()
end

function DiffPicker:_default_selection()
    for _, f in ipairs(self.fields) do
        if self.selection[f.key] ~= "custom" then
            if not f.is_empty(f.new_value) and f.display(f.new_value) ~= f.display(f.current_value) then
                self.selection[f.key] = "new"
            else
                self.selection[f.key] = "current"
            end
        end
    end
end

function DiffPicker:setFields(fields, edition_label)
    self.fields = fields
    self.edition_label = edition_label
    self:_default_selection()
    self:_refresh()
end

function DiffPicker:_value_box(text, width, dim, on_tap)
    local face = Font:getFace("cfont", 18)
    local shown = (text ~= nil and text ~= "") and text or _("(none)")
    local box = TextBoxWidget:new{
        text = shown,
        face = face,
        width = width - 2 * Size.padding.default,
        alignment = "left",
        fgcolor = dim and Blitbuffer.COLOR_DARK_GRAY or Blitbuffer.COLOR_BLACK,
    }
    local frame = FrameContainer:new{
        bordersize = Size.border.thin,
        radius = sc(4),
        padding = Size.padding.default,
        width = width,
        LeftContainer:new{
            dimen = Geom:new{ w = width - 2 * Size.padding.default, h = box:getSize().h },
            box,
        },
    }
    if not on_tap then
        return frame
    end
    return TapBox:new{
        on_tap = on_tap,
        frame,
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

function DiffPicker:_selected_value(field)
    local sel = self.selection[field.key]
    if sel == "custom" then
        return self.custom[field.key]
    elseif sel == "new" then
        return field.new_value
    end
    return field.current_value
end

function DiffPicker:_field_row(field, col_w)
    local group = VerticalGroup:new{ align = "left" }
    local full_w = 2 * col_w + sc(8)

    table.insert(group, TextWidget:new{
        text = field.label,
        face = Font:getFace("tfont", 18),
    })
    table.insert(group, VerticalSpan:new{ width = sc(4) })

    local has_new = not field.is_empty(field.new_value)
    table.insert(group, HorizontalGroup:new{
        self:_value_box(field.display(field.current_value), col_w, false, function()
            self:_edit(field, field.current_value)
        end),
        HorizontalSpan:new{ width = sc(8) },
        self:_value_box(field.display(field.new_value), col_w, not has_new, function()
            self:_edit(field, field.new_value)
        end),
    })
    table.insert(group, VerticalSpan:new{ width = sc(6) })

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

    local custom = self.custom[field.key]
    if custom ~= nil then
        table.insert(group, VerticalSpan:new{ width = sc(6) })
        table.insert(group, self:_value_box(field.display(custom), full_w, false, function()
            self:_edit(field, custom)
        end))
    end

    local can_translate = field.translatable and self.on_translate ~= nil
    local action_w = can_translate and col_w or full_w
    local action
    if custom == nil then
        action = Button:new{
            text = _("Edit"),
            width = action_w,
            radius = sc(4),
            bordersize = Size.border.button,
            padding = sc(8),
            show_parent = self,
            callback = function()
                self:_edit(field, self:_selected_value(field))
            end,
        }
    else
        action = self:_select_button(_("Use mine"), action_w, sel == "custom", function()
            self.selection[field.key] = "custom"
            self:_refresh()
        end)
    end

    table.insert(group, VerticalSpan:new{ width = sc(6) })
    if can_translate then
        table.insert(group, HorizontalGroup:new{
            action,
            HorizontalSpan:new{ width = sc(8) },
            Button:new{
                text = _("Translate ▸"),
                width = action_w,
                radius = sc(4),
                bordersize = Size.border.button,
                padding = sc(8),
                enabled = not field.is_empty(self:_selected_value(field)),
                show_parent = self,
                callback = function()
                    self:_translate({ field })
                end,
            },
        })
    else
        table.insert(group, action)
    end

    return FrameContainer:new{
        bordersize = 0,
        padding = Size.padding.default,
        group,
    }
end

function DiffPicker:translatableItems(fields)
    return Translate.translatable(fields or self.fields, function(field)
        return self:_selected_value(field)
    end)
end

function DiffPicker:translateInto(items, target)
    if not self.on_translate or #items == 0 then
        return
    end
    self.on_translate(items, target, function(results)
        for _, result in ipairs(results or {}) do
            self.custom[result.field.key] = result.raw
            self.selection[result.field.key] = "custom"
        end
        self:_refresh()
    end)
end

function DiffPicker:_translate(fields)
    if not self.on_translate then
        return
    end
    local items = self:translatableItems(fields)
    if #items == 0 then
        UIManager:show(InfoMessage:new{ text = _("Nothing to translate in this field.") })
        return
    end
    self:_choose_language(function(target)
        self:translateInto(items, target)
    end, _("Translate to"))
end

function DiffPicker:chooseLanguage(on_pick)
    self:_choose_language(on_pick, _("Show this book in"))
end

function DiffPicker:_choose_language(on_pick, title)
    local targets = self.translate_targets and self.translate_targets() or {}
    if #targets == 0 then
        UIManager:show(InfoMessage:new{ text = _("No translation languages are available.") })
        return
    end

    local dialog
    local buttons = {}
    for _, target in ipairs(targets) do
        buttons[#buttons + 1] = {
            {
                text = target.name,
                callback = function()
                    UIManager:close(dialog)
                    on_pick(target.code)
                end,
            },
        }
    end
    buttons[#buttons + 1] = {
        {
            text = _("Cancel"),
            callback = function()
                UIManager:close(dialog)
            end,
        },
    }

    dialog = ButtonDialog:new{
        title = title or _("Translate to"),
        title_align = "center",
        buttons = buttons,
    }
    UIManager:show(dialog)
end

function DiffPicker:_commit(field, raw)
    self.custom[field.key] = raw
    self.selection[field.key] = "custom"
    self:_refresh()
end

function DiffPicker:_edit(field, seed)
    if field.editor == "series" then
        self:_edit_series(field, seed)
        return
    end

    local long = field.editor == "longtext"
    local dialog
    local save = {
        text = _("Save"),
        is_enter_default = not long,
        callback = function()
            local text = dialog:getInputText()
            UIManager:close(dialog)
            self:_commit(field, field.from_input(text))
        end,
    }
    local cancel = {
        text = _("Cancel"),
        id = "close",
        callback = function()
            UIManager:close(dialog)
        end,
    }

    local opts = {
        title = field.label,
        input = field.to_input(seed),
        buttons = { { cancel, save } },
    }
    if field.editor == "authors" then
        opts.description = _("Separate multiple authors with commas.")
    elseif field.editor == "genres" then
        opts.description = _("Separate multiple genres with commas.")
    end
    if long then
        opts.fullscreen = true
        opts.condensed = true
        opts.allow_newline = true
        opts.cursor_at_end = false
        opts.add_scroll_buttons = true
        opts.buttons = { {}, { cancel, save } }
    end

    dialog = InputDialog:new(opts)
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function DiffPicker:_edit_series(field, seed)
    local input = field.to_input(seed)
    local dialog
    dialog = MultiInputDialog:new{
        title = field.label,
        fields = {
            {
                description = _("Series name"),
                text = input.name,
                hint = _("Series"),
            },
            {
                description = _("Series index"),
                text = input.index,
                hint = _("1"),
            },
        },
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
                {
                    text = _("Save"),
                    callback = function()
                        local values = dialog:getFields()
                        UIManager:close(dialog)
                        self:_commit(field, field.from_input({
                            name = values[1],
                            index = values[2],
                        }))
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
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

    local header_group = VerticalGroup:new{
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
    }

    if self.on_choose_language then
        table.insert(header_group, VerticalSpan:new{ width = sc(6) })
        table.insert(header_group, Button:new{
            text = _("Another language ▸"),
            radius = sc(4),
            padding = sc(8),
            bordersize = Size.border.button,
            width = content_inner,
            show_parent = self,
            callback = function()
                self.on_choose_language(self)
            end,
        })
    end

    if self.on_choose_edition then
        local label = self.edition_label
        if label == nil or label == "" then
            label = _("default")
        end
        table.insert(header_group, VerticalSpan:new{ width = sc(6) })
        table.insert(header_group, Button:new{
            text = _("Edition: ") .. label .. " ▸",
            radius = sc(4),
            padding = sc(8),
            bordersize = Size.border.button,
            width = content_inner,
            show_parent = self,
            callback = function()
                self.on_choose_edition(self)
            end,
        })
    end

    local header = FrameContainer:new{
        bordersize = 0,
        padding = Size.padding.default,
        header_group,
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
            col_head(self.new_label or _("New (Hardcover)")),
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
    local toggles = FrameContainer:new{
        bordersize = 0,
        padding = Size.padding.default,
        HorizontalGroup:new{
            backup_btn,
            HorizontalSpan:new{ width = sc(8) },
            move_btn,
        },
    }
    local action_bar = FrameContainer:new{
        bordersize = 0,
        padding = Size.padding.default,
        HorizontalGroup:new{
            apply_btn,
            HorizontalSpan:new{ width = sc(12) },
            cancel_btn,
        },
    }

    local scroll_content = VerticalGroup:new{
        align = "left",
        header,
        LineWidget:new{
            background = Blitbuffer.COLOR_DARK_GRAY,
            dimen = Geom:new{ w = self.width, h = Size.line.thin },
        },
        col_header,
        body,
        LineWidget:new{
            background = Blitbuffer.COLOR_DARK_GRAY,
            dimen = Geom:new{ w = self.width, h = Size.line.thin },
        },
        toggles,
    }

    local action_h = action_bar:getSize().h
    local scroll_h = self.height - action_h - Size.line.thin

    local previous = self.cropping_widget
    local scroller = ScrollableContainer:new{
        dimen = Geom:new{ w = self.width, h = scroll_h },
        show_parent = self,
        bordersize = 0,
        padding = 0,
        FrameContainer:new{
            bordersize = 0,
            padding = 0,
            scroll_content,
        },
    }
    if previous then
        scroller:setScrolledOffset(previous:getScrolledOffset())
        previous:onCloseWidget()
    end
    self.cropping_widget = scroller

    local content = VerticalGroup:new{
        align = "left",
        scroller,
        LineWidget:new{
            background = Blitbuffer.COLOR_DARK_GRAY,
            dimen = Geom:new{ w = self.width, h = Size.line.thin },
        },
        action_bar,
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
            self.selection[f.key] = (not f.is_empty(f.new_value)) and "new" or "current"
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
        local sel = self.selection[f.key]
        if sel == "new" then
            f.apply(changes, f.new_value)
        elseif sel == "custom" then
            f.apply(changes, self.custom[f.key])
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
