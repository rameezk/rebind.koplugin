local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local ButtonDialog = require("ui/widget/buttondialog")
local ButtonTable = require("ui/widget/buttontable")
local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local InputDialog = require("ui/widget/inputdialog")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local Logo = require("rebind/ui/logo")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")

local PickerState = require("rebind/picker_state")
local SaveAs = require("rebind/ui/saveas")
local TapRow = require("rebind/ui/taprow")
local Translate = require("rebind/translate")
local ValueBox = require("rebind/ui/valuebox")

local Screen = Device.screen

local function sc(v)
    return Screen:scaleBySize(v)
end

local DiffPicker = InputContainer:extend{
    fields = nil,
    state = nil,
    on_apply = nil,
    save_as = nil,
    on_save_as_change = nil,
    on_choose_library = nil,
    edition_label = nil,
    on_open_source = nil,
    hardcover_missing = false,
    translate_targets = nil,
    on_translate = nil,
    matching_open = false,
}

function DiffPicker:init()
    self.width = Screen:getWidth()
    self.height = Screen:getHeight()
    self.covers_fullscreen = true
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }

    if Device:hasKeys() then
        self.key_events = { Close = { { Device.input.group.Back } } }
    end

    self.state = PickerState.new(self.fields)
    self.state:set_save_as(self.save_as)

    self:_build()
end

function DiffPicker:setFields(fields, edition_label)
    self.fields = fields
    self.edition_label = edition_label
    self.state:set_fields(fields)
    self:_refresh()
end

function DiffPicker:_selected_value(field)
    return self.state:selected_value(field)
end

function DiffPicker:_field_block(field, width)
    local group = VerticalGroup:new{ align = "left" }

    local edit_w = sc(96)
    local label = TextWidget:new{
        text = field.label,
        face = Font:getFace("tfont", 18),
        max_width = width - edit_w - sc(8),
    }
    table.insert(group, HorizontalGroup:new{
        align = "center",
        LeftContainer:new{
            dimen = Geom:new{ w = width - edit_w - sc(8), h = label:getSize().h },
            label,
        },
        HorizontalSpan:new{ width = sc(8) },
        Button:new{
            text = _("Edit"),
            width = edit_w,
            radius = sc(4),
            bordersize = Size.border.button,
            padding = sc(4),
            show_parent = self,
            callback = function()
                self:_edit(field, self:_selected_value(field))
            end,
        },
    })
    table.insert(group, VerticalSpan:new{ width = sc(6) })

    for _i, value in ipairs(self.state:values(field.key)) do
        table.insert(group, ValueBox.new{
            width = width,
            text = value.text,
            tag = value.tag,
            empty = value.empty,
            selected = value.selected,
            on_tap = function()
                self.state:select(field.key, value.id)
                self:_refresh()
            end,
        })
        table.insert(group, VerticalSpan:new{ width = sc(6) })
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

function DiffPicker:translateInto(items, target, on_result)
    if not self.on_translate or #items == 0 then
        return
    end
    self.on_translate(items, target, function(results)
        for _, result in ipairs(results or {}) do
            if on_result then
                on_result(result)
            else
                self.state:save_translated(result.field.key, result.raw)
            end
        end
        if not on_result then
            self:_refresh()
        end
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

function DiffPicker:_commit(field, raw, translated)
    if translated then
        self.state:save_translated(field.key, raw)
    else
        self.state:save_custom(field.key, raw)
    end
    self:_refresh()
end

function DiffPicker:_add_start_from(dialog, field, get_raw, set_raw)
    local translated_text
    local chips = {
        {
            text = _("Book"),
            callback = function()
                set_raw(field.current_value)
            end,
        },
    }
    if not field.is_empty(field.new_value) then
        chips[#chips + 1] = {
            text = _("Hardcover"),
            callback = function()
                set_raw(field.new_value)
            end,
        }
    end
    if field.translatable and self.on_translate then
        chips[#chips + 1] = {
            text = _("Translate…"),
            callback = function()
                local raw = get_raw()
                if field.is_empty(raw) then
                    UIManager:show(InfoMessage:new{ text = _("Nothing to translate in this field.") })
                    return
                end
                self:_choose_language(function(target)
                    self:translateInto({ { field = field, raw = raw } }, target, function(result)
                        set_raw(result.raw)
                        translated_text = dialog:getInputText()
                    end)
                end, _("Translate to"))
            end,
        }
    end
    chips[#chips + 1] = {
        text = _("Clear"),
        callback = function()
            set_raw(field.from_input(field.editor == "series" and {} or ""))
        end,
    }

    local width = dialog:getAddedWidgetAvailableWidth()
    dialog:addWidget(TextWidget:new{
        text = _("Start from"),
        face = Font:getFace("cfont", 15),
        fgcolor = Blitbuffer.COLOR_DARK_GRAY,
        max_width = width,
    }, nil, true)
    dialog:addWidget(ButtonTable:new{
        width = width,
        buttons = { chips },
        show_parent = dialog,
    }, nil, true)
    return function()
        return translated_text
    end
end

function DiffPicker:_edit(field, seed)
    if field.editor == "series" then
        self:_edit_series(field, seed)
        return
    end

    local long = field.editor == "longtext"
    local dialog
    local get_translated_text
    local save = {
        text = _("Save"),
        is_enter_default = not long,
        callback = function()
            local text = dialog:getInputText()
            local problem = field.validate and field.validate(text)
            if problem then
                UIManager:show(InfoMessage:new{ text = problem })
                return
            end
            UIManager:close(dialog)
            self:_commit(field, field.from_input(text), text == get_translated_text())
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
    elseif field.key == "first_published" then
        opts.description = _("A 4-digit year. Leave empty to clear.")
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
    get_translated_text = self:_add_start_from(dialog, field, function()
        return field.from_input(dialog:getInputText())
    end, function(raw)
        dialog:setInputText(field.to_input(raw))
    end)
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
    self:_add_start_from(dialog, field, function()
        local values = dialog:getFields()
        return field.from_input({ name = values[1], index = values[2] })
    end, function(raw)
        local filled = field.to_input(raw)
        dialog.input_fields[1]:setText(filled.name)
        dialog.input_fields[2]:setText(filled.index)
    end)
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function DiffPicker:_source_button()
    if self.state:manual() then
        if self.hardcover_missing then
            return _("Hardcover plugin not installed"), false
        end
        if self.on_open_source then
            return _("Not using Hardcover ▸"), true
        end
        return _("Not using Hardcover"), false
    end
    local label = "Hardcover"
    if self.edition_label and self.edition_label ~= "" then
        label = label .. " · " .. self.edition_label
    end
    if self.on_open_source then
        return label .. " ▸", true
    end
    return label, false
end

function DiffPicker:_build()
    local footer_inner = self.width - 2 * Size.padding.default
    local view_w = self.width - 3 * ScrollableContainer.scroll_bar_width
    local content_inner = view_w - 2 * Size.padding.default

    local close_btn = Button:new{
        text = "×",
        radius = sc(4),
        bordersize = Size.border.button,
        padding = sc(4),
        width = sc(48),
        show_parent = self,
        callback = function()
            self:onClose()
        end,
    }
    local source_text, source_enabled = self:_source_button()
    local logo_gap = sc(8)
    local source_opts = {
        text = source_text,
        enabled = source_enabled,
        radius = sc(4),
        padding = sc(8),
        bordersize = Size.border.button,
        show_parent = self,
        callback = function()
            self.on_open_source(self)
        end,
    }
    source_opts.width = content_inner
    local header_height = Button:new(source_opts):getSize().h
    source_opts.width = content_inner - sc(48) - sc(8) - header_height - logo_gap
    local source_btn = Button:new(source_opts)

    local header_group = HorizontalGroup:new{
        align = "center",
        Logo.widget(header_height),
        HorizontalSpan:new{ width = logo_gap },
        source_btn,
        HorizontalSpan:new{ width = sc(8) },
        close_btn,
    }

    local header = FrameContainer:new{
        bordersize = 0,
        padding = Size.padding.default,
        header_group,
    }

    local block_w = content_inner
    local differing = self.state:differing_fields()

    local body = VerticalGroup:new{ align = "left" }

    local status_group = VerticalGroup:new{ align = "left" }
    local bulk_w = math.floor(content_inner * 0.42)
    local status_w = content_inner - bulk_w - sc(8)
    table.insert(status_group, TextWidget:new{
        text = self.state:differ_heading(),
        face = Font:getFace("tfont", 15),
        fgcolor = Blitbuffer.COLOR_DARK_GRAY,
        max_width = status_w,
    })
    local status_text = self.state:status_line()
    if status_text ~= "" then
        table.insert(status_group, TextBoxWidget:new{
            text = status_text,
            face = Font:getFace("cfont", 16),
            width = status_w,
        })
    end
    local status_row = HorizontalGroup:new{
        align = "center",
        status_group,
        HorizontalSpan:new{ width = sc(8) },
    }
    if self.state:has_bulk() and #differing > 0 then
        table.insert(status_row, Button:new{
            text = self.state:bulk_label(),
            radius = sc(4),
            padding = sc(6),
            bordersize = Size.border.button,
            width = bulk_w,
            show_parent = self,
            callback = function()
                self:_bulk()
            end,
        })
    end
    table.insert(body, FrameContainer:new{
        bordersize = 0,
        padding = Size.padding.default,
        status_row,
    })

    local function add_separator()
        table.insert(body, LineWidget:new{
            background = Blitbuffer.COLOR_LIGHT_GRAY,
            dimen = Geom:new{ w = content_inner, h = Size.line.thin },
        })
    end

    local function add_block(field)
        add_separator()
        table.insert(body, self:_field_block(field, block_w))
    end

    for _i, field in ipairs(differing) do
        add_block(field)
    end

    local matching = self.state:matching_fields()
    if #matching > 0 then
        add_separator()
        local summary = TextBoxWidget:new{
            text = (self.matching_open and "▾ " or "▸ ") .. self.state:matching_summary(),
            face = Font:getFace("cfont", 16),
            width = content_inner - 2 * Size.padding.default,
        }
        table.insert(body, TapRow:new{
            on_tap = function()
                self.matching_open = not self.matching_open
                self:_refresh()
            end,
            dimen = Geom:new{ w = view_w, h = summary:getSize().h + 4 * Size.padding.default },
            FrameContainer:new{
                bordersize = 0,
                padding = Size.padding.default * 2,
                summary,
            },
        })
        if self.matching_open then
            for _i, field in ipairs(matching) do
                add_block(field)
            end
        end
    end

    local apply_btn = Button:new{
        text = self.state:apply_label(),
        enabled = self.state:apply_enabled(),
        radius = sc(4),
        padding = sc(11),
        bordersize = 0,
        background = Blitbuffer.COLOR_BLACK,
        width = footer_inner,
        show_parent = self,
        callback = function()
            self:_apply()
        end,
    }
    if apply_btn.label_widget and self.state:apply_enabled() then
        apply_btn.label_widget.fgcolor = Blitbuffer.COLOR_WHITE
    end
    local summary_top, summary_bottom = self.state:save_as_summary()
    local summary_w = footer_inner - sc(24)
    local summary_group = VerticalGroup:new{
        align = "left",
        TextWidget:new{
            text = summary_top,
            face = Font:getFace("cfont", 15),
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            max_width = summary_w,
        },
        TextWidget:new{
            text = summary_bottom,
            face = Font:getFace("cfont", 17),
            bold = self.state:name_clash(),
            max_width = summary_w,
        },
    }
    local summary_row = TapRow:new{
        on_tap = function()
            self:_show_save_as()
        end,
        dimen = Geom:new{ w = footer_inner, h = summary_group:getSize().h },
        HorizontalGroup:new{
            align = "center",
            LeftContainer:new{
                dimen = Geom:new{ w = summary_w, h = summary_group:getSize().h },
                summary_group,
            },
            HorizontalSpan:new{ width = sc(8) },
            TextWidget:new{
                text = "▸",
                face = Font:getFace("cfont", 22),
            },
        },
    }
    local action_bar = FrameContainer:new{
        bordersize = 0,
        padding = Size.padding.default,
        VerticalGroup:new{
            align = "left",
            summary_row,
            VerticalSpan:new{ width = sc(8) },
            apply_btn,
        },
    }

    local scroll_content = VerticalGroup:new{
        align = "left",
        header,
        LineWidget:new{
            background = Blitbuffer.COLOR_DARK_GRAY,
            dimen = Geom:new{ w = view_w, h = Size.line.thin },
        },
        body,
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

function DiffPicker:_bulk()
    self.state:bulk()
    self:_refresh()
end

function DiffPicker:_refresh()
    self:_build()
    UIManager:setDirty(self, "ui")
end

function DiffPicker:_selected_changes()
    return self.state:changes()
end

function DiffPicker:_show_save_as()
    SaveAs.show{
        state = self.state,
        on_change = self.on_save_as_change,
        on_choose_library = self.on_choose_library,
        on_close = function()
            self:_refresh()
        end,
    }
end

function DiffPicker:_apply()
    local changes = self:_selected_changes()
    local dest = self.state:destination()
    local keep_backup = self.state.save_as.keep_backup
    UIManager:close(self, "ui")
    if self.on_apply then
        self.on_apply(changes, { keep_backup = keep_backup, dest = dest })
    end
end

function DiffPicker:onClose()
    if not self.state:needs_discard_prompt() then
        UIManager:close(self, "ui")
        return true
    end
    UIManager:show(ConfirmBox:new{
        text = _("Discard your changes?"),
        ok_text = _("Discard"),
        cancel_text = _("Keep editing"),
        ok_callback = function()
            UIManager:close(self, "ui")
        end,
    })
    return true
end

function DiffPicker:onShow()
    UIManager:setDirty(self, "full")
    return true
end

return DiffPicker
