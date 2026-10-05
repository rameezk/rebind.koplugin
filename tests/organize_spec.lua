local Organize = require("rebind/organize")

local function meta(authors, title)
    return { authors = authors, title = title }
end

local T = {}

T["surname_first converts First Last to Last, First"] = function(a)
    a.eq(Organize.surname_first("Frank Herbert"), "Herbert, Frank")
    a.eq(Organize.surname_first("Isaac Asimov"), "Asimov, Isaac")
end

T["surname_first keeps multi-word given names"] = function(a)
    a.eq(Organize.surname_first("George R. R. Martin"), "Martin, George R. R.")
end

T["surname_first leaves an existing Last, First unchanged"] = function(a)
    a.eq(Organize.surname_first("Herbert, Frank"), "Herbert, Frank")
end

T["surname_first passes through a single name"] = function(a)
    a.eq(Organize.surname_first("Voltaire"), "Voltaire")
end

T["surname_first returns nil for empty input"] = function(a)
    a.eq(Organize.surname_first(nil), nil)
    a.eq(Organize.surname_first(""), nil)
    a.eq(Organize.surname_first("   "), nil)
end

T["sanitize replaces filesystem-illegal characters"] = function(a)
    a.eq(Organize.sanitize("A/B:C*D?"), "A_B_C_D_")
    a.eq(Organize.sanitize('quote"lt<gt>pipe|'), "quote_lt_gt_pipe_")
end

T["sanitize trims trailing dots and whitespace"] = function(a)
    a.eq(Organize.sanitize("  Dune.  "), "Dune")
end

T["sanitize falls back when empty"] = function(a)
    a.eq(Organize.sanitize("", "Unknown Title"), "Unknown Title")
    a.eq(Organize.sanitize(nil, "Unknown Author"), "Unknown Author")
end

T["author_folder uses the first author, surname-first"] = function(a)
    a.eq(Organize.author_folder({ "Frank Herbert", "Kevin J. Anderson" }), "Herbert, Frank")
    a.eq(Organize.author_folder("Leigh Bardugo"), "Bardugo, Leigh")
    a.eq(Organize.author_folder({}), "Unknown Author")
end

T["target_path builds root/Author/Title/Author - Title.ext"] = function(a)
    local p = Organize.target_path("/books/Sorted", meta({ "Frank Herbert" }, "Dune"), "dune.epub")
    a.eq(p, "/books/Sorted/Herbert, Frank/Dune/Herbert, Frank - Dune.epub")
end

T["target_path strips a trailing slash from the root"] = function(a)
    local p = Organize.target_path("/books/Sorted/", meta({ "Isaac Asimov" }, "Foundation"), "f.epub")
    a.eq(p, "/books/Sorted/Asimov, Isaac/Foundation/Asimov, Isaac - Foundation.epub")
end

T["target_path sanitizes a title with a slash"] = function(a)
    local p = Organize.target_path("/r", meta({ "A B" }, "Vol 1/2"), "x.epub")
    a.eq(p, "/r/B, A/Vol 1_2/B, A - Vol 1_2.epub")
end

T["target_path keeps the original filename when rename is off"] = function(a)
    local p = Organize.target_path("/books/Sorted", meta({ "Frank Herbert" }, "Dune"), "dune.epub", "nested", false)
    a.eq(p, "/books/Sorted/Herbert, Frank/Dune/dune.epub")
end

T["basename returns the final path component"] = function(a)
    a.eq(Organize.basename("/a/b/c/book.epub"), "book.epub")
    a.eq(Organize.basename("book.epub"), "book.epub")
end

T["dirname returns the parent directory"] = function(a)
    a.eq(Organize.dirname("/a/b/c/book.epub"), "/a/b/c")
    a.eq(Organize.dirname("/books/dune.epub"), "/books")
    a.eq(Organize.dirname("book.epub"), ".")
end

T["a flat move into the source folder renames in place"] = function(a)
    local dir = Organize.dirname("/books/incoming/assassin.epub")
    local p = Organize.target_path(dir, meta({ "Robin Hobb" }, "Assassin's Apprentice"), "assassin.epub", "flat")
    a.eq(p, "/books/incoming/Hobb, Robin - Assassin's Apprentice.epub")
end

T["target_dir omits the filename"] = function(a)
    a.eq(Organize.target_dir("/r/", meta({ "Frank Herbert" }, "Dune")), "/r/Herbert, Frank/Dune")
end

T["flat structure moves the file directly into the root"] = function(a)
    a.eq(Organize.target_dir("/r/", meta({ "Frank Herbert" }, "Dune"), "flat"), "/r")
    a.eq(Organize.target_path("/r", meta({ "Frank Herbert" }, "Dune"), "d.epub", "flat"),
        "/r/Herbert, Frank - Dune.epub")
end

T["nested is the default structure"] = function(a)
    a.eq(Organize.target_path("/r", meta({ "Frank Herbert" }, "Dune"), "d.epub"),
        Organize.target_path("/r", meta({ "Frank Herbert" }, "Dune"), "d.epub", "nested"))
end

T["extension returns the trailing extension"] = function(a)
    a.eq(Organize.extension("dune.epub"), ".epub")
    a.eq(Organize.extension("a.b.epub"), ".epub")
    a.eq(Organize.extension("noext"), "")
end

T["filename builds Author - Title.ext, surname first"] = function(a)
    a.eq(Organize.filename(meta({ "Frank Herbert" }, "Dune"), "dune.epub"), "Herbert, Frank - Dune.epub")
    a.eq(Organize.filename(meta({ "Frank Herbert", "Kevin J. Anderson" }, "Dune"), "d.epub"),
        "Herbert, Frank - Dune.epub")
end

T["filename sanitizes illegal characters in the title"] = function(a)
    a.eq(Organize.filename(meta({ "A B" }, "Vol: 1/2"), "x.epub"), "B, A - Vol_ 1_2.epub")
end

T["filename falls back for missing author and title"] = function(a)
    a.eq(Organize.filename(meta({}, nil), "x.epub"), "Unknown Author - Unknown Title.epub")
end

local PRESET_3 = "%title{ - %series #%series_index} - %author{ (%year)}"

local COLOUR_OF_MAGIC = {
    title = "The Colour of Magic",
    authors = { "Terry Pratchett" },
    series = "Discworld",
    series_index = "1",
    first_published = "1983",
}

T["a template keeps an optional series group when a series exists"] = function(a)
    a.eq(Organize.filename(COLOUR_OF_MAGIC, "x.epub", PRESET_3),
        "The Colour of Magic - Discworld #1 - Terry Pratchett (1983).epub")
end

local function named(template, m)
    return Organize.filename(m, "x.epub", template)
end

T["a template drops an optional group when a token inside it is empty"] = function(a)
    local m = { title = "Enshittification", authors = { "Cory Doctorow" }, first_published = "2025" }
    a.eq(named(PRESET_3, m), "Enshittification - Cory Doctorow (2025).epub")
end

T["a token value cannot create folders"] = function(a)
    a.eq(named("%title", { title = "AC/DC: Live" }), "AC_DC_ Live.epub")
end

T["a template's own literal text is cleaned too"] = function(a)
    a.eq(named("%title: %author", { title = "Dune", authors = { "Frank Herbert" } }),
        "Dune_ Frank Herbert.epub")
end

T["percent escapes render as literal characters"] = function(a)
    a.eq(named("%title %%%{%}", { title = "Dune" }), "Dune %{}.epub")
end

T["a missing title or author falls back"] = function(a)
    a.eq(named("%author - %title", {}), "Unknown Author - Unknown Title.epub")
    a.eq(named("%author_sort - %authors", { authors = {} }), "Unknown Author - Unknown Author.epub")
end

T["authors joins every author in natural order"] = function(a)
    a.eq(named("%authors - %title", { title = "Good Omens", authors = { "Terry Pratchett", "Neil Gaiman" } }),
        "Terry Pratchett & Neil Gaiman - Good Omens.epub")
end

T["author is the first author and author_sort is surname-first"] = function(a)
    local m = { authors = { "Frank Herbert", "Brian Herbert" } }
    a.eq(named("%author|%author_sort", m), "Frank Herbert_Herbert, Frank.epub")
end

T["language and publisher are available"] = function(a)
    a.eq(named("%publisher (%language)", { publisher = "Gollancz", language = "en" }), "Gollancz (en).epub")
end

T["a token ends at the first character that is not a letter or underscore"] = function(a)
    a.eq(named("%year-%series_index.", { first_published = "1983", series_index = "2.5" }), "1983-2.5..epub")
end

T["an empty token outside a group renders as nothing and whitespace collapses"] = function(a)
    a.eq(named("%title - %series - %author", { title = "Dune" }), "Dune - - Unknown Author.epub")
    a.eq(named("  %series   %title  ", { title = "Dune" }), "Dune.epub")
end

T["a filename that renders empty falls back to the default preset"] = function(a)
    a.eq(named("%series", { title = "Dune", authors = { "Frank Herbert" } }), "Herbert, Frank - Dune.epub")
end

T["a rendered filename is capped at 200 bytes"] = function(a)
    local name = named("%title", { title = string.rep("a", 300) })
    a.eq(#name, 200 + #".epub")
end

T["Sort and rename use the chosen template"] = function(a)
    local p = Organize.target_path("/lib", { title = "Dune", authors = { "Frank Herbert" } }, "d.epub", "flat", true,
        "%title - %author")
    a.eq(p, "/lib/Dune - Frank Herbert.epub")
end

T["every filename preset renders for The Colour of Magic"] = function(a)
    local want = {
        "Pratchett, Terry - The Colour of Magic.epub",
        "The Colour of Magic - Terry Pratchett.epub",
        "The Colour of Magic - Discworld #1 - Terry Pratchett (1983).epub",
        "Discworld 1 - The Colour of Magic.epub",
    }
    for i, template in ipairs(Organize.FILENAME_PRESETS) do
        a.eq(Organize.filename(COLOUR_OF_MAGIC, "x.epub", template), want[i])
    end
end

T["with_changes overlays the chosen values onto the current metadata"] = function(a)
    local current = { title = "Colour", authors = { "T. Pratchett" }, series = "Discworld", series_index = "1" }
    local merged = Organize.with_changes(current, { title = "Colour of Magic", series = "", series_index = nil })
    a.eq(merged.title, "Colour of Magic")
    a.eq(merged.authors[1], "T. Pratchett")
    a.eq(merged.series, "")
    a.eq(merged.series_index, nil)
    a.eq(current.title, "Colour")
end

T["a token value ending in a dot loses it, as the default naming always did"] = function(a)
    a.eq(Organize.filename({ title = "Vol 1.", authors = { "J. R. R. Tolkien" } }, "x.epub"),
        "Tolkien, J. R. R - Vol 1.epub")
    a.eq(named("%title", { title = "..." }), "Unknown Title.epub")
end

T["a preset's optional series group is dropped without a series"] = function(a)
    local m = { title = "Dune", authors = { "Frank Herbert" } }
    a.eq(named(Organize.FILENAME_PRESETS[4], m), "Dune.epub")
end

T["Sort into the nested layout keeps the template's filename"] = function(a)
    local p = Organize.target_path("/lib", { title = "Dune", authors = { "Frank Herbert" } }, "d.epub", "nested", true,
        "%title - %author")
    a.eq(p, "/lib/Herbert, Frank/Dune/Dune - Frank Herbert.epub")
end

return T
