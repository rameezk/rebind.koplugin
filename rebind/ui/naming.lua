local Blitbuffer = require("ffi/blitbuffer")
local ButtonDialog = require("ui/widget/buttondialog")
local Font = require("ui/font")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local Organize = require("rebind/organize")

local Naming = {}

local EXAMPLE_FILE = "book.epub"

function Naming.show(opts)
    local dialog
    local open

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

    local function header(text)
        return { { text = text, enabled = false } }
    end

    local function open_editor(kind)
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

        editor = InputDialog:new{
            title = section.editor_title,
            input = custom[kind] or selected[kind],
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
                            UIManager:close(dialog)
                            open()
                        end,
                    },
                },
            },
        }

        example_widget = TextWidget:new{
            text = section.example(editor:getInputText()),
            face = Font:getFace("cfont", 15),
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            max_width = editor:getAddedWidgetAvailableWidth(),
        }
        editor:addWidget(example_widget, nil, true)
        UIManager:show(editor)
        editor:onShowKeyboard()
    end

    open = function()
        local buttons = {}

        for _k, kind in ipairs({ "filename", "folder" }) do
            local section = sections[kind]
            buttons[#buttons + 1] = header(section.title)
            for _i, template in ipairs(section.presets) do
                buttons[#buttons + 1] = {
                    {
                        text = (template == selected[kind] and "● " or "○ ") .. section.label(template),
                        align = "left",
                        callback = function()
                            choose[kind](template)
                            UIManager:close(dialog)
                            open()
                        end,
                    },
                }
            end
            buttons[#buttons + 1] = {
                {
                    text = (custom[kind] ~= nil and selected[kind] == custom[kind] and "● " or "○ ")
                        .. _("Custom…"),
                    align = "left",
                    callback = function()
                        open_editor(kind)
                    end,
                },
            }
        end

        buttons[#buttons + 1] = {
            {
                text = _("Close"),
                callback = function()
                    UIManager:close(dialog)
                end,
            },
        }
        dialog = ButtonDialog:new{
            title = _("Naming"),
            title_align = "center",
            buttons = buttons,
        }
        UIManager:show(dialog)
    end

    open()
end

return Naming
