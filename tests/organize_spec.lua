local Organize = require("rebind/organize")

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
    local p = Organize.target_path("/books/Sorted", { "Frank Herbert" }, "Dune", "dune.epub")
    a.eq(p, "/books/Sorted/Herbert, Frank/Dune/Herbert, Frank - Dune.epub")
end

T["target_path strips a trailing slash from the root"] = function(a)
    local p = Organize.target_path("/books/Sorted/", { "Isaac Asimov" }, "Foundation", "f.epub")
    a.eq(p, "/books/Sorted/Asimov, Isaac/Foundation/Asimov, Isaac - Foundation.epub")
end

T["target_path sanitizes a title with a slash"] = function(a)
    local p = Organize.target_path("/r", { "A B" }, "Vol 1/2", "x.epub")
    a.eq(p, "/r/B, A/Vol 1_2/B, A - Vol 1_2.epub")
end

T["target_path keeps the original filename when rename is off"] = function(a)
    local p = Organize.target_path("/books/Sorted", { "Frank Herbert" }, "Dune", "dune.epub", "nested", false)
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
    local p = Organize.target_path(dir, { "Robin Hobb" }, "Assassin's Apprentice", "assassin.epub", "flat")
    a.eq(p, "/books/incoming/Hobb, Robin - Assassin's Apprentice.epub")
end

T["target_dir omits the filename"] = function(a)
    a.eq(Organize.target_dir("/r/", { "Frank Herbert" }, "Dune"), "/r/Herbert, Frank/Dune")
end

T["flat structure moves the file directly into the root"] = function(a)
    a.eq(Organize.target_dir("/r/", { "Frank Herbert" }, "Dune", "flat"), "/r")
    a.eq(Organize.target_path("/r", { "Frank Herbert" }, "Dune", "d.epub", "flat"),
        "/r/Herbert, Frank - Dune.epub")
end

T["nested is the default structure"] = function(a)
    a.eq(Organize.target_path("/r", { "Frank Herbert" }, "Dune", "d.epub"),
        Organize.target_path("/r", { "Frank Herbert" }, "Dune", "d.epub", "nested"))
end

T["extension returns the trailing extension"] = function(a)
    a.eq(Organize.extension("dune.epub"), ".epub")
    a.eq(Organize.extension("a.b.epub"), ".epub")
    a.eq(Organize.extension("noext"), "")
end

T["filename builds Author - Title.ext, surname first"] = function(a)
    a.eq(Organize.filename({ "Frank Herbert" }, "Dune", "dune.epub"), "Herbert, Frank - Dune.epub")
    a.eq(Organize.filename({ "Frank Herbert", "Kevin J. Anderson" }, "Dune", "d.epub"),
        "Herbert, Frank - Dune.epub")
end

T["filename sanitizes illegal characters in the title"] = function(a)
    a.eq(Organize.filename({ "A B" }, "Vol: 1/2", "x.epub"), "B, A - Vol_ 1_2.epub")
end

T["filename falls back for missing author and title"] = function(a)
    a.eq(Organize.filename({}, nil, "x.epub"), "Unknown Author - Unknown Title.epub")
end

return T
