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
        local buttons = { header(_("File name")) }
        for _i, template in ipairs(Organize.FILENAME_PRESETS) do
            local marker = template == selected_filename and "● " or "○ "
            buttons[#buttons + 1] = {
                {
                    text = marker .. Organize.filename(opts.metadata(), EXAMPLE_FILE, template),
                    align = "left",
                    callback = function()
                        selected_filename = template
                        opts.on_select_filename(template)
                        UIManager:close(dialog)
                        open()
                    end,
                },
            }
        end
        buttons[#buttons + 1] = header(_("Sort folders"))
        for _i, template in ipairs(Organize.FOLDER_PRESETS) do
            local marker = template == selected_folder and "● " or "○ "
            buttons[#buttons + 1] = {
                {
                    text = marker .. Organize.folder_label(opts.metadata(), template),
                    align = "left",
                    callback = function()
                        selected_folder = template
                        opts.on_select_folder(template)
                        UIManager:close(dialog)
                        open()
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
