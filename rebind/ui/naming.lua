local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local Device = require("device")
local Font = require("ui/font")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local Math = require("optmath")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextViewer = require("ui/widget/textviewer")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalSpan = require("ui/widget/verticalspan")
local util = require("util")
local _ = require("gettext")

local ChoiceList = require("rebind/ui/choicelist")
local Organize = require("rebind/organize")

local Screen = Device.screen

local Naming = {}

local EXAMPLE_FILE = "book.epub"
local TEMPLATE_LINES = 3
local TEMPLATE_FONT_SIZE = 20

local function sc(v)
    return Screen:scaleBySize(v)
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
            title = _("Filename template"),
            editor_title = _("Custom filename template"),
            presets = Organize.FILENAME_PRESETS,
            label = function(template)
                return Organize.filename(opts.metadata(), EXAMPLE_FILE, template)
            end,
            example = function(template)
                return Organize.filename(opts.metadata(), "", template)
            end,
        },
        folder = {
            title = _("Folder template"),
            editor_title = _("Custom folder template"),
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
            input.do_select = false
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

        local chip_rows = {}
        for _i, row in ipairs(Organize.editor_chip_rows(kind)) do
            local buttons = {}
            for _j, chip in ipairs(row) do
                buttons[#buttons + 1] = {
                    text = _(chip.label),
                    callback = chip.token and function()
                        insert(chip.token)
                    end or wrap_optional,
                }
            end
            chip_rows[#chip_rows + 1] = buttons
        end
        local input_face = Font:getFace("infont", TEMPLATE_FONT_SIZE)

        editor = InputDialog:new{
            title = section.editor_title,
            input = custom[kind] or selected[kind],
            input_face = input_face,
            text_height = TEMPLATE_LINES * Math.round((1 + TextBoxWidget.line_height) * input_face.size),
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

        local function is_preset(template)
            for _i, preset in ipairs(section.presets) do
                if preset == template then
                    return true
                end
            end
            return false
        end

        local rows = {}
        for _i, template in ipairs(section.presets) do
            rows[#rows + 1] = {
                title = section.label(template),
                subtitle = Organize.pattern_label(template),
                selected = template == selected[kind],
                on_select = function()
                    choose[kind](template)
                    reopen()
                end,
            }
        end
        local own = custom[kind]
        rows[#rows + 1] = {
            title = own and section.label(own) or _("Custom…"),
            subtitle = own and Organize.pattern_label(own) or nil,
            selected = own ~= nil and selected[kind] == own and not is_preset(own),
            on_select = function()
                if own then
                    choose[kind](own)
                    reopen()
                else
                    open_editor(kind, reopen)
                end
            end,
            action_text = own and _("Edit") or nil,
            on_action = own and function()
                open_editor(kind, reopen)
            end or nil,
        }

        list = ChoiceList.show{
            title = section.title,
            rows = rows,
            on_close = on_close,
        }
    end

    show_list(opts.kind, opts.on_close)
end

return Naming
