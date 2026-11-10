local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
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

local function tag_widget(text, muted, plain)
    local color = muted and Blitbuffer.COLOR_DARK_GRAY or Blitbuffer.COLOR_BLACK
    return FrameContainer:new{
        bordersize = plain and 0 or Size.border.thin,
        color = color,
        radius = sc(4),
        padding = sc(4),
        padding_left = sc(10),
        padding_right = sc(10),
        margin = 0,
        TextWidget:new{ text = text, face = Font:getFace("cfont", 17), fgcolor = color },
    }
end

local function summary_banner(text, width)
    return FrameContainer:new{
        bordersize = 0,
        padding = sc(17),
        padding_bottom = sc(4),
        FrameContainer:new{
            bordersize = Size.border.thick,
            radius = sc(6),
            padding = sc(14),
            margin = 0,
            TextBoxWidget:new{
                text = text,
                face = Font:getFace("cfont", 21),
                width = width - sc(34) - 2 * sc(14) - 2 * Size.border.thick,
            },
        },
    }
end

local function save_as_row(batch, width, on_tap)
    local top, bottom = batch:save_as_summary()
    local text_w = width - sc(34) - sc(36)
    local lines = VerticalGroup:new{
        align = "left",
        TextWidget:new{
            text = top,
            face = Font:getFace("cfont", 16),
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            max_width = text_w,
        },
        TextWidget:new{ text = bottom, face = Font:getFace("cfont", 19), max_width = text_w },
    }
    return TapRow:new{
        dimen = Geom:new{ w = width - sc(34), h = lines:getSize().h + sc(8) },
        on_tap = on_tap,
        HorizontalGroup:new{
            align = "center",
            LeftContainer:new{
                dimen = Geom:new{ w = text_w, h = lines:getSize().h + sc(8) },
                lines,
            },
            HorizontalSpan:new{ width = sc(8) },
            TextWidget:new{ text = "▶", face = Font:getFace("cfont", 22) },
        },
    }
end

local function entry_row(entry, width, tag, subtitle, on_tap)
    local done = entry.state == "done"
    local tag_box = tag_widget(tag, entry.state ~= "review", done)
    local text_w = width - sc(34) - tag_box:getSize().w - sc(12)
    local lines = VerticalGroup:new{
        align = "left",
        TextWidget:new{
            text = row_title(entry),
            face = Font:getFace("cfont", 21),
            bold = not done,
            fgcolor = done and Blitbuffer.COLOR_DARK_GRAY or Blitbuffer.COLOR_BLACK,
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
        local summary = batch:summary()
        if summary then
            top[#top + 1] = summary_banner(summary, width)
        end
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
                local subtitle = entry.state == "done" and batch:done_location(entry) or entry.name
                items[#items + 1] = {
                    widget = entry_row(entry, width, batch:tag(entry), subtitle, function()
                        opts.on_open(entry, screen)
                    end),
                    section = section.key,
                    continued = heading_text(section.key, count, true),
                }
            end
        end

        local bottom
        local sure = batch:sure_count()
        if sure > 0 then
            local label = sure == 1 and _("Rebind 1 sure match") or string.format(_("Rebind %d sure matches"), sure)
            bottom = {
                save_as_row(batch, width, function()
                    opts.on_save_as(screen)
                end),
                VerticalSpan:new{ width = sc(8) },
                PagedScreen.primary_button(label, width - sc(34), true, function()
                    opts.on_rebind(screen)
                end, self),
            }
        else
            bottom = {
                PagedScreen.outline_button(_("Close"), function()
                    screen:onClose()
                end, self, true, width - sc(34)),
            }
        end
        return {
            title = string.format(#batch.entries == 1 and _("Review %d book") or _("Review %d books"), #batch.entries),
            top = top,
            items = items,
            bottom = bottom,
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
