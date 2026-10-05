local ButtonDialog = require("ui/widget/buttondialog")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local Organize = require("rebind/organize")

local Naming = {}

local EXAMPLE_FILE = "book.epub"

function Naming.show(opts)
    local selected = opts.filename_template
    local dialog

    local function open()
        local buttons = {}
        for _i, template in ipairs(Organize.FILENAME_PRESETS) do
            local marker = template == selected and "● " or "○ "
            buttons[#buttons + 1] = {
                {
                    text = marker .. Organize.filename(opts.metadata(), EXAMPLE_FILE, template),
                    align = "left",
                    callback = function()
                        selected = template
                        opts.on_select(template)
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
            title = _("Naming") .. "\n\n" .. _("File name"),
            title_align = "center",
            buttons = buttons,
        }
        UIManager:show(dialog)
    end

    open()
end

return Naming
