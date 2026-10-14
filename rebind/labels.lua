local _ = require("gettext")

local Labels = {}

function Labels.edition_label(m, omit_language)
    local parts = {}
    if m.edition_format and m.edition_format ~= "" then
        parts[#parts + 1] = tostring(m.edition_format)
    end
    if m.release_year then
        parts[#parts + 1] = tostring(m.release_year)
    end
    if m.publisher then
        parts[#parts + 1] = m.publisher
    end
    if tonumber(m.pages) then
        parts[#parts + 1] = tostring(math.floor(tonumber(m.pages))) .. _("pp")
    end
    if m.language and not omit_language then
        parts[#parts + 1] = m.language
    end
    if #parts == 0 then
        return ""
    end
    return table.concat(parts, " · ")
end

function Labels.header_label(m)
    local parts = {}
    if m.release_year then
        parts[#parts + 1] = tostring(m.release_year)
    end
    if m.publisher then
        parts[#parts + 1] = m.publisher
    end
    if m.language then
        parts[#parts + 1] = m.language
    end
    return table.concat(parts, " · ")
end

function Labels.match_subtitle(m)
    local parts = {}
    if m.authors and m.authors[1] then
        parts[#parts + 1] = m.authors[1]
    end
    if m.release_year then
        parts[#parts + 1] = tostring(m.release_year)
    end
    if m.users_read_count then
        local count = tostring(m.users_read_count)
        parts[#parts + 1] = count .. (tonumber(m.users_read_count) == 1 and _(" reader") or _(" readers"))
    end
    return table.concat(parts, " · ")
end

return Labels
