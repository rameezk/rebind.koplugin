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
    local selected_filename = opts.filename_template
    local selected_folder = opts.folder_template
    local custom_filename = opts.custom_filename_template
    local custom_folder = opts.custom_folder_template
    local dialog
    local open

    local function header(text)
        return { { text = text, enabled = false } }
    end

    local function example(kind, template)
        local meta = opts.metadata()
        if kind == "filename" then
            return Organize.filename(meta, "", template)
        end
        return Organize.folder_label(meta, template)
    end

    local function open_editor(kind, prefill, on_save)
        local title = kind == "filename" and _("Custom file name") or _("Custom sort folders")
        local editor
        local example_widget

        local function refresh_example()
            if not example_widget then
                return
            end
            example_widget:setText(example(kind, editor:getInputText()))
            UIManager:setDirty(editor, "ui")
        end

        editor = InputDialog:new{
            title = title,
            input = prefill,
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
                            on_save(template)
                            UIManager:close(dialog)
                            open()
                        end,
                    },
                },
            },
        }

        example_widget = TextWidget:new{
            text = example(kind, editor:getInputText()),
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

        local function add_section(title, kind, presets, selected, label, choose, custom, save)
            buttons[#buttons + 1] = header(title)
            for _i, template in ipairs(presets) do
                buttons[#buttons + 1] = {
                    {
                        text = (template == selected and "● " or "○ ") .. label(template),
                        align = "left",
                        callback = function()
                            choose(template)
                            UIManager:close(dialog)
                            open()
                        end,
                    },
                }
            end
            buttons[#buttons + 1] = {
                {
                    text = (custom ~= nil and selected == custom and "● " or "○ ") .. _("Custom…"),
                    align = "left",
                    callback = function()
                        open_editor(kind, custom or selected, save)
                    end,
                },
            }
        end

        add_section(_("File name"), "filename", Organize.FILENAME_PRESETS, selected_filename, function(template)
            return Organize.filename(opts.metadata(), EXAMPLE_FILE, template)
        end, function(template)
            selected_filename = template
            opts.on_select_filename(template)
        end, custom_filename, function(template)
            selected_filename = template
            custom_filename = template
            opts.on_save_custom_filename(template)
        end)
        add_section(_("Sort folders"), "folder", Organize.FOLDER_PRESETS, selected_folder, function(template)
            return Organize.folder_label(opts.metadata(), template)
        end, function(template)
            selected_folder = template
            opts.on_select_folder(template)
        end, custom_folder, function(template)
            selected_folder = template
            custom_folder = template
            opts.on_save_custom_folder(template)
        end)

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
