local ButtonDialog = require("ui/widget/buttondialog")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local Organize = require("rebind/organize")

local Naming = {}

local EXAMPLE_FILE = "book.epub"

function Naming.show(opts)
    local selected_filename = opts.filename_template
    local selected_folder = opts.folder_template
    local dialog

    local function header(text)
        return { { text = text, enabled = false } }
    end

    local function open()
        local function add_section(buttons, title, presets, selected, label, choose)
            buttons[#buttons + 1] = header(title)
            for _i, template in ipairs(presets) do
                local marker = template == selected and "● " or "○ "
                buttons[#buttons + 1] = {
                    {
                        text = marker .. label(template),
                        align = "left",
                        callback = function()
                            choose(template)
                            UIManager:close(dialog)
                            open()
                        end,
                    },
                }
            end
        end

        local buttons = {}
        add_section(buttons, _("File name"), Organize.FILENAME_PRESETS, selected_filename, function(template)
            return Organize.filename(opts.metadata(), EXAMPLE_FILE, template)
        end, function(template)
            selected_filename = template
            opts.on_select_filename(template)
        end)
        add_section(buttons, _("Sort folders"), Organize.FOLDER_PRESETS, selected_folder, function(template)
            return Organize.folder_label(opts.metadata(), template)
        end, function(template)
            selected_folder = template
            opts.on_select_folder(template)
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
