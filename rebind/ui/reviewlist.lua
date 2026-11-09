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

local PagedScreen = require("rebind/ui/pagedscreen")
local TapRow = require("rebind/ui/taprow")

local sc = PagedScreen.sc

local ReviewList = {}

local HEADINGS = {
    review = _("TO REVIEW"),
    sure = _("SURE MATCHES"),
    done = _("DONE"),
}

local HINTS = {
    review = _("TAP TO OPEN"),
    sure = _("TAP TO CHECK"),
}

local function heading_text(key, count, continued)
    local text = HEADINGS[key] .. " · " .. count
    if HINTS[key] then
        text = text .. " · " .. HINTS[key]
    end
    if continued then
        text = text .. " " .. _("(continued)")
    end
    return text
end

local function row_title(entry)
    local source = entry.state ~= "review" and entry.book or entry.current or {}
    local title = source.title
    if not title or title == "" then
        return entry.name
    end
    local author = source.authors and source.authors[1]
    if author and author ~= "" then
        return title .. " · " .. author
    end
    return title
end

local function tag_widget(text, muted)
    local color = muted and Blitbuffer.COLOR_DARK_GRAY or Blitbuffer.COLOR_BLACK
    return FrameContainer:new{
        bordersize = Size.border.thin,
        color = color,
        radius = sc(4),
        padding = sc(4),
        padding_left = sc(10),
        padding_right = sc(10),
        margin = 0,
        TextWidget:new{ text = text, face = Font:getFace("cfont", 17), fgcolor = color },
    }
end

local function entry_row(entry, width, tag, on_tap)
    local tag_box = tag_widget(tag, entry.state ~= "review")
    local text_w = width - sc(34) - tag_box:getSize().w - sc(12)
    local subtitle = entry.state == "done" and entry.new_path or entry.name
    local lines = VerticalGroup:new{
        align = "left",
        TextWidget:new{
            text = row_title(entry),
            face = Font:getFace("cfont", 21),
            bold = true,
            max_width = text_w,
        },
        TextWidget:new{
            text = subtitle,
            face = Font:getFace("cfont", 16),
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            max_width = text_w,
        },
    }
    local cell = FrameContainer:new{
        bordersize = 0,
        padding = sc(17),
        padding_top = sc(8),
        padding_bottom = sc(8),
        width = width,
        HorizontalGroup:new{
            align = "center",
            LeftContainer:new{
                dimen = Geom:new{ w = text_w, h = lines:getSize().h },
                lines,
            },
            HorizontalSpan:new{ width = sc(12) },
            tag_box,
        },
    }
    return VerticalGroup:new{
        align = "left",
        TapRow:new{
            dimen = Geom:new{ w = width, h = cell:getSize().h },
            on_tap = on_tap,
            cell,
        },
        LineWidget:new{
            background = Blitbuffer.COLOR_LIGHT_GRAY,
            dimen = Geom:new{ w = width, h = Size.line.thin },
        },
    }
end

function ReviewList.show(opts)
    local batch = opts.batch
    local screen

    local function build(self)
        local width = self.width
        local top = {}
        for _i, line in ipairs(batch:skip_notices()) do
            top[#top + 1] = VerticalGroup:new{
                align = "left",
                FrameContainer:new{
                    bordersize = 0,
                    padding = sc(17),
                    padding_top = sc(8),
                    padding_bottom = sc(8),
                    width = width,
                    TextWidget:new{
                        text = line,
                        face = Font:getFace("cfont", 17),
                        fgcolor = Blitbuffer.COLOR_DARK_GRAY,
                        max_width = width - sc(34),
                    },
                },
                LineWidget:new{
                    background = Blitbuffer.COLOR_LIGHT_GRAY,
                    dimen = Geom:new{ w = width, h = Size.line.thin },
                },
            }
        end

        local items = {}
        for _i, section in ipairs(batch:sections()) do
            local count = #section.entries
            items[#items + 1] = {
                widget = PagedScreen.heading(heading_text(section.key, count), width),
                is_heading = true,
                section = section.key,
            }
            for _j, entry in ipairs(section.entries) do
                items[#items + 1] = {
                    widget = entry_row(entry, width, batch:tag(entry), function()
                        opts.on_open(entry, screen)
                    end),
                    section = section.key,
                    continued = heading_text(section.key, count, true),
                }
            end
        end

        local close_button = PagedScreen.outline_button(_("Close"), function()
            screen:onClose()
        end, self, true, width - sc(34))
        return {
            title = string.format(#batch.entries == 1 and _("Review %d book") or _("Review %d books"), #batch.entries),
            top = top,
            items = items,
            bottom = { close_button },
        }
    end

    screen = PagedScreen:new{
        build = build,
        on_close = function(widget)
            UIManager:close(widget, "ui")
            if opts.on_close then
                opts.on_close()
            end
        end,
    }
    UIManager:show(screen)
    return screen
end

return ReviewList
