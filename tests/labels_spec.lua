local Labels = require("rebind/labels")

local T = {}

T["edition_label describes format, year, publisher, pages and language"] = function(a)
    local label = Labels.edition_label({
        edition_format = "Paperback",
        release_year = "2010",
        publisher = "Penguin",
        pages = 412,
        language = "en",
    })
    a.eq(label, "Paperback · 2010 · Penguin · 412pp · en")
end

T["edition_label skips the parts an edition does not have"] = function(a)
    a.eq(Labels.edition_label({ edition_format = "Ebook", pages = 300 }), "Ebook · 300pp")
    a.eq(Labels.edition_label({}), "")
end

T["header_label is year, publisher and language without format or pages"] = function(a)
    local m = {
        edition_format = "Hardcover",
        release_year = "2020",
        publisher = "Ballantine Books",
        pages = 367,
        language = "en",
    }
    a.eq(Labels.header_label(m), "2020 · Ballantine Books · en")
end

T["header_label leaves out the parts an edition does not have"] = function(a)
    a.eq(Labels.header_label({ edition_format = "Ebook", pages = 300, language = "de" }), "de")
    a.eq(Labels.header_label({ release_year = 1999, publisher = "Penguin" }), "1999 · Penguin")
    a.eq(Labels.header_label({}), "")
end

T["match_subtitle joins author, year and readers"] = function(a)
    local m = { authors = { "Frank Herbert", "Someone Else" }, release_year = 1965, users_read_count = 1204 }
    a.eq(Labels.match_subtitle(m), "Frank Herbert · 1965 · 1204 readers")
end

T["match_subtitle skips what a match does not have and singularises one reader"] = function(a)
    a.eq(Labels.match_subtitle({ authors = { "Solo" }, users_read_count = 1 }), "Solo · 1 reader")
    a.eq(Labels.match_subtitle({ release_year = 1972 }), "1972")
    a.eq(Labels.match_subtitle({}), "")
end

T["edition_label can leave the language out"] = function(a)
    local m = { edition_format = "Paperback", release_year = "1999", language = "es" }
    a.eq(Labels.edition_label(m), "Paperback · 1999 · es")
    a.eq(Labels.edition_label(m, true), "Paperback · 1999")
end


return T
