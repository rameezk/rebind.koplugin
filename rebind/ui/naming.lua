local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local ButtonDialog = require("ui/widget/buttondialog")
local ButtonTable = require("ui/widget/buttontable")
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
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextViewer = require("ui/widget/textviewer")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local util = require("util")
local _ = require("gettext")

local Organize = require("rebind/organize")

local Screen = Device.screen

local Naming = {}

local EXAMPLE_FILE = "book.epub"
local CHIPS_PER_ROW = 3

local function sc(v)
    return Screen:scaleBySize(v)
end

local TapRow = InputContainer:extend{
    on_tap = nil,
}

function TapRow:init()
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

function TapRow:onTap()
    if self.on_tap then
        self.on_tap()
        return true
    end
end

local TemplateList = InputContainer:extend{
    title = nil,
    rows = nil,
    on_close = nil,
}

function TemplateList:init()
    self.width = Screen:getWidth()
    self.height = Screen:getHeight()
    self.covers_fullscreen = true
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
    if Device:hasKeys() then
        self.key_events = { Close = { { Device.input.group.Back } } }
    end

    local pad = sc(12)
    local inner = self.width - 2 * pad
    local content = VerticalGroup:new{ align = "left" }

    table.insert(content, FrameContainer:new{
        bordersize = 0,
        padding = pad,
        TextWidget:new{
            text = self.title,
            face = Font:getFace("cfont", 24),
            bold = true,
            max_width = inner,
        },
    })
    table.insert(content, LineWidget:new{
        background = Blitbuffer.COLOR_DARK_GRAY,
        dimen = Geom:new{ w = self.width, h = Size.line.thin },
    })

    for _i, row in ipairs(self.rows) do
        local edit_w = 0
        local edit_btn
        if row.on_edit then
            edit_btn = Button:new{
                text = _("Edit"),
                bordersize = Size.border.button,
                margin = 0,
                radius = Size.radius.button,
                callback = row.on_edit,
                show_parent = self,
            }
            edit_w = edit_btn:getSize().w + sc(8)
        end
        local mark = TextWidget:new{
            text = row.selected and "●" or "○",
            face = Font:getFace("cfont", 24),
        }
        local text_w = inner - mark:getSize().w - sc(12) - edit_w
        local lines = VerticalGroup:new{
            align = "left",
            TextBoxWidget:new{
                text = row.label,
                face = Font:getFace("cfont", 20),
                bold = row.selected,
                width = text_w,
            },
        }
        if row.pattern then
            table.insert(lines, TextBoxWidget:new{
                text = row.pattern,
                face = Font:getFace("cfont", 15),
                fgcolor = Blitbuffer.COLOR_DARK_GRAY,
                width = text_w,
            })
        end
        local line = HorizontalGroup:new{
            align = "center",
            mark,
            HorizontalSpan:new{ width = sc(12) },
            lines,
        }
        if edit_btn then
            table.insert(line, HorizontalSpan:new{ width = sc(8) })
            table.insert(line, edit_btn)
        end
        local cell = FrameContainer:new{
            bordersize = 0,
            padding = pad,
            padding_top = sc(10),
            padding_bottom = sc(10),
            width = self.width,
            line,
        }
        local tap = TapRow:new{
            on_tap = row.on_select,
            dimen = Geom:new{ w = self.width, h = cell:getSize().h },
            cell,
        }
        table.insert(content, tap)
        table.insert(content, LineWidget:new{
            background = Blitbuffer.COLOR_LIGHT_GRAY,
            dimen = Geom:new{ w = self.width, h = Size.line.thin },
        })
    end

    table.insert(content, VerticalSpan:new{ width = sc(16) })
    table.insert(content, FrameContainer:new{
        bordersize = 0,
        padding = pad,
        Button:new{
            text = _("Close"),
            width = inner,
            bordersize = Size.border.button,
            radius = Size.radius.button,
            callback = function()
                self:onClose()
            end,
            show_parent = self,
        },
    })

    self[1] = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        width = self.width,
        height = self.height,
        content,
    }
end

function TemplateList:onClose()
    UIManager:close(self, "ui")
    if self.on_close then
        self.on_close()
    end
    return true
end

function TemplateList:onShow()
    UIManager:setDirty(self, "full")
    return true
end

local function char_to_byte_offset(charlist, char_pos)
    if char_pos <= 1 then
        return 0
    end
    return #table.concat(charlist, "", 1, char_pos - 1)
end

local function byte_to_char_pos(text, byte_offset)
    return #util.splitToChars(text:sub(1, byte_offset)) + 1
end

function Naming.show(opts)
    local selected = {
        filename = opts.filename_template,
        folder = opts.folder_template,
    }
    local custom = {
        filename = opts.custom_filename_template,
        folder = opts.custom_folder_template,
    }

    local function folder_label(template)
        return Organize.folder_label(opts.metadata(), template)
    end

    local sections = {
        filename = {
            title = _("File name"),
            editor_title = _("Custom file name"),
            presets = Organize.FILENAME_PRESETS,
            label = function(template)
                return Organize.filename(opts.metadata(), EXAMPLE_FILE, template)
            end,
            example = function(template)
                return Organize.filename(opts.metadata(), "", template)
            end,
        },
        folder = {
            title = _("Sort folders"),
            editor_title = _("Custom sort folders"),
            presets = Organize.FOLDER_PRESETS,
            label = folder_label,
            example = folder_label,
        },
    }

    local choose = {
        filename = function(template)
            selected.filename = template
            opts.on_select_filename(template)
        end,
        folder = function(template)
            selected.folder = template
            opts.on_select_folder(template)
        end,
    }

    local save_custom = {
        filename = function(template)
            selected.filename = template
            custom.filename = template
            opts.on_save_custom_filename(template)
        end,
        folder = function(template)
            selected.folder = template
            custom.folder = template
            opts.on_save_custom_folder(template)
        end,
    }

    local show_list

    local function show_help(kind)
        local lines = {}
        for _i, row in ipairs(Organize.token_help(opts.metadata())) do
            lines[#lines + 1] = string.format("%s  %s\n    %s", row.token, row.label, row.value)
        end
        local notes = {}
        for _i, note in ipairs(Organize.help_notes(kind)) do
            notes[#notes + 1] = _(note)
        end
        UIManager:show(TextViewer:new{
            title = _("Template help"),
            text = table.concat(lines, "\n") .. "\n\n" .. table.concat(notes, "\n\n"),
            justified = false,
        })
    end

    local function open_editor(kind, on_done)
        local section = sections[kind]
        local editor
        local example_widget

        local function refresh_example()
            if not example_widget then
                return
            end
            example_widget:setText(section.example(editor:getInputText()))
            UIManager:setDirty(editor, "ui")
        end

        local function apply(text, cursor)
            local input = editor._input_widget
            input.selection_start_pos = nil
            editor:setInputText(text)
            input:moveCursorToCharPos(byte_to_char_pos(text, cursor))
            refresh_example()
        end

        local function cursor_offset()
            local input = editor._input_widget
            return char_to_byte_offset(input.charlist, input.charpos)
        end

        local function insert(token)
            local text, cursor = Organize.insert_token(editor:getInputText(), cursor_offset(), token)
            apply(text, cursor)
        end

        local function wrap_optional()
            local input = editor._input_widget
            local from = cursor_offset()
            local to = from
            local start = input.selection_start_pos
            if start and start ~= input.charpos then
                local a, b = math.min(start, input.charpos), math.max(start, input.charpos)
                from = char_to_byte_offset(input.charlist, a)
                to = char_to_byte_offset(input.charlist, b)
            end
            local text, cursor = Organize.wrap_optional(editor:getInputText(), from, to)
            apply(text, cursor)
        end

        local chips = {}
        for _i, chip in ipairs(Organize.editor_chips(kind)) do
            chips[#chips + 1] = {
                text = _(chip.label),
                callback = function()
                    insert(chip.token)
                end,
            }
        end
        chips[#chips + 1] = {
            text = _("{ Optional }"),
            callback = wrap_optional,
        }
        local chip_rows = {}
        for i, chip in ipairs(chips) do
            local row = math.ceil(i / CHIPS_PER_ROW)
            chip_rows[row] = chip_rows[row] or {}
            table.insert(chip_rows[row], chip)
        end

        editor = InputDialog:new{
            title = section.editor_title,
            input = custom[kind] or selected[kind],
            input_face = Font:getFace("infont", 20),
            edited_callback = refresh_example,
            buttons = {
                {
                    {
                        text = _("Cancel"),
                        id = "close",
                        callback = function()
                            UIManager:close(editor)
                        end,
                    },
                    {
                        text = _("Help"),
                        callback = function()
                            show_help(kind)
                        end,
                    },
                    {
                        text = _("Save"),
                        is_enter_default = true,
                        callback = function()
                            local template = editor:getInputText()
                            local problem = Organize.validate_template(template, kind)
                            if problem then
                                UIManager:show(InfoMessage:new{ text = problem })
                                return
                            end
                            UIManager:close(editor)
                            save_custom[kind](template)
                            on_done()
                        end,
                    },
                },
            },
        }

        local width = editor:getAddedWidgetAvailableWidth()
        example_widget = TextWidget:new{
            text = section.example(editor:getInputText()),
            face = Font:getFace("cfont", 16),
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            max_width = width,
        }
        editor:addWidget(TextWidget:new{
            text = _("Insert at cursor"),
            face = Font:getFace("cfont", 15),
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            max_width = width,
        }, nil, true)
        editor:addWidget(ButtonTable:new{
            width = width,
            buttons = chip_rows,
            show_parent = editor,
        }, nil, true)
        editor:addWidget(VerticalSpan:new{ width = sc(6) }, nil, true)
        editor:addWidget(TextWidget:new{
            text = _("Example"),
            face = Font:getFace("cfont", 15),
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            max_width = width,
        }, nil, true)
        editor:addWidget(example_widget, nil, true)
        UIManager:show(editor)
        editor:onShowKeyboard()
    end

    show_list = function(kind, on_close)
        local section = sections[kind]
        local list
        local function reopen()
            UIManager:close(list, "ui")
            show_list(kind, on_close)
        end

        local rows = {}
        for _i, template in ipairs(section.presets) do
            rows[#rows + 1] = {
                label = section.label(template),
                pattern = Organize.pattern_label(template),
                selected = template == selected[kind],
                on_select = function()
                    choose[kind](template)
                    reopen()
                end,
            }
        end
        local own = custom[kind]
        rows[#rows + 1] = {
            label = own and section.label(own) or _("Custom…"),
            pattern = own and Organize.pattern_label(own) or nil,
            selected = own ~= nil and selected[kind] == own,
            on_select = function()
                if own then
                    choose[kind](own)
                    reopen()
                else
                    open_editor(kind, reopen)
                end
            end,
            on_edit = own and function()
                open_editor(kind, reopen)
            end or nil,
        }

        list = TemplateList:new{
            title = section.title,
            rows = rows,
            on_close = on_close,
        }
        UIManager:show(list)
    end

    local menu
    local function open_menu()
        local function entry(kind)
            local section = sections[kind]
            return {
                {
                    text = section.title .. ":  " .. section.label(selected[kind]),
                    align = "left",
                    callback = function()
                        UIManager:close(menu)
                        show_list(kind, open_menu)
                    end,
                },
            }
        end
        menu = ButtonDialog:new{
            title = _("Naming"),
            title_align = "center",
            buttons = {
                entry("filename"),
                entry("folder"),
                {
                    {
                        text = _("Close"),
                        callback = function()
                            UIManager:close(menu)
                        end,
                    },
                },
            },
        }
        UIManager:show(menu)
    end

    open_menu()
end

return Naming
