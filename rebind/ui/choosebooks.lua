local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local _ = require("gettext")

local Batch = require("rebind/batch")
local Checkbox = require("rebind/ui/checkbox")
local PagedScreen = require("rebind/ui/pagedscreen")
local TapRow = require("rebind/ui/taprow")


local sc = PagedScreen.sc

local ChooseBooks = {}

local function plural_books(count)
    if count == 1 then
        return _("Look up 1 book")
    end
    return string.format(_("Look up %d books"), count)
end

local function split_row(width, left, right)
    local right_w = right:getSize().w
    local left_w = width - right_w - sc(12)
    return HorizontalGroup:new{
        align = "center",
        LeftContainer:new{
            dimen = Geom:new{ w = left_w, h = math.max(left:getSize().h, right:getSize().h) },
            left,
        },
        HorizontalSpan:new{ width = sc(12) },
        right,
    }
end

local function band(width, content, rule)
    return VerticalGroup:new{
        align = "left",
        FrameContainer:new{
            bordersize = 0,
            padding = sc(17),
            padding_top = sc(8),
            padding_bottom = sc(8),
            width = width,
            content,
        },
        LineWidget:new{
            background = rule or Blitbuffer.COLOR_LIGHT_GRAY,
            dimen = Geom:new{ w = width, h = Size.line.thin },
        },
    }
end

function ChooseBooks.show(opts)
    local state = {
        folder = opts.folder,
        include_subfolders = false,
        ticked = {},
        files = {},
    }

    local function reload()
        state.files = Batch.collect(state.folder, { include_subfolders = state.include_subfolders })
        state.ticked = {}
    end
    reload()

    local function ticked_count()
        local n = 0
        for _i, file in ipairs(state.files) do
            if state.ticked[file] then
                n = n + 1
            end
        end
        return n
    end

    local screen
    local function display_name(file)
        if state.include_subfolders then
            return file:sub(#Batch.trim_folder(state.folder) + 2)
        end
        return file:match("([^/]+)$")
    end

    local function build(self)
        local width = self.width
        local inner = width - sc(34)
        local top = {}

        top[#top + 1] = band(width, split_row(
            inner,
            VerticalGroup:new{
                align = "left",
                TextWidget:new{ text = _("Folder"), face = Font:getFace("cfont", 20) },
                TextWidget:new{
                    text = state.folder,
                    face = Font:getFace("cfont", 16),
                    fgcolor = Blitbuffer.COLOR_DARK_GRAY,
                    max_width = inner - sc(200),
                },
            },
            PagedScreen.outline_button(_("Change ▸"), function()
                opts.on_change_folder(function(path)
                    state.folder = path
                    reload()
                    screen.page = 1
                    screen:refresh()
                end)
            end, self)
        ), Blitbuffer.COLOR_LIGHT_GRAY)

        top[#top + 1] = band(width, split_row(
            inner,
            TextWidget:new{ text = _("Include subfolders"), face = Font:getFace("cfont", 20) },
            PagedScreen.outline_button(state.include_subfolders and _("On") or _("Off"), function()
                state.include_subfolders = not state.include_subfolders
                reload()
                screen.page = 1
                screen:refresh()
            end, self)
        ))

        if not opts.has_providers() then
            top[#top + 1] = band(width, split_row(
                inner,
                VerticalGroup:new{
                    align = "left",
                    TextWidget:new{ text = _("No lookup providers are enabled"), face = Font:getFace("cfont", 20) },
                    TextWidget:new{
                        text = _("Enable one to look these books up."),
                        face = Font:getFace("cfont", 16),
                        fgcolor = Blitbuffer.COLOR_DARK_GRAY,
                        max_width = inner - sc(200),
                    },
                },
                PagedScreen.outline_button(_("Change ▸"), function()
                    opts.on_change_providers(function()
                        screen:refresh()
                    end)
                end, self)
            ))
        end

        local count = ticked_count()
        local summary = TextWidget:new{
            text = string.format(_("%d OF %d EPUBS TICKED"), count, #state.files),
            face = Font:getFace("cfont", 16),
            bold = true,
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
        }
        local actions = HorizontalGroup:new{
            align = "center",
            PagedScreen.outline_button(_("Select all"), function()
                for _i, file in ipairs(state.files) do
                    state.ticked[file] = true
                end
                screen:refresh()
            end, self, false),
            HorizontalSpan:new{ width = sc(8) },
            PagedScreen.outline_button(_("Deselect all"), function()
                state.ticked = {}
                screen:refresh()
            end, self, false),
        }
        top[#top + 1] = FrameContainer:new{
            bordersize = 0,
            padding = sc(17),
            width = width,
            split_row(inner, summary, actions),
        }

        local items = {}
        for _i, file in ipairs(state.files) do
            local row = HorizontalGroup:new{
                align = "center",
                Checkbox:new{ checked = state.ticked[file] == true },
                HorizontalSpan:new{ width = sc(12) },
                TextWidget:new{
                    text = display_name(file),
                    face = Font:getFace("cfont", 21),
                    max_width = inner - sc(40),
                },
            }
            local cell = FrameContainer:new{
                bordersize = 0,
                padding = sc(17),
                padding_top = sc(6),
                padding_bottom = sc(6),
                width = width,
                row,
            }
            items[#items + 1] = {
                widget = VerticalGroup:new{
                    align = "left",
                    TapRow:new{
                        dimen = Geom:new{ w = width, h = cell:getSize().h },
                        on_tap = function()
                            state.ticked[file] = not state.ticked[file] or nil
                            screen:refresh()
                        end,
                        cell,
                    },
                    LineWidget:new{
                        background = Blitbuffer.COLOR_LIGHT_GRAY,
                        dimen = Geom:new{ w = width, h = Size.line.thin },
                    },
                },
            }
        end

        local button = PagedScreen.primary_button(
            plural_books(count),
            width - sc(34),
            count > 0 and opts.has_providers(),
            function()
                local chosen = {}
                for _i, file in ipairs(state.files) do
                    if state.ticked[file] then
                        chosen[#chosen + 1] = file
                    end
                end
                opts.on_lookup(chosen, screen)
            end,
            self
        )
        return { title = _("Rebind several books"), top = top, items = items, bottom = { button } }
    end

    screen = PagedScreen:new{ build = build, on_close = opts.on_close }
    UIManager:show(screen)
    return screen
end

return ChooseBooks
