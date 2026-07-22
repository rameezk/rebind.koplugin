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

T["target_path builds root/Author/Title/filename"] = function(a)
    local p = Organize.target_path("/books/Sorted", { "Frank Herbert" }, "Dune", "dune.epub")
    a.eq(p, "/books/Sorted/Herbert, Frank/Dune/dune.epub")
end

T["target_path strips a trailing slash from the root"] = function(a)
    local p = Organize.target_path("/books/Sorted/", { "Isaac Asimov" }, "Foundation", "f.epub")
    a.eq(p, "/books/Sorted/Asimov, Isaac/Foundation/f.epub")
end

T["target_path sanitizes a title with a slash"] = function(a)
    local p = Organize.target_path("/r", { "A B" }, "Vol 1/2", "x.epub")
    a.eq(p, "/r/B, A/Vol 1_2/x.epub")
end

T["basename returns the final path component"] = function(a)
    a.eq(Organize.basename("/a/b/c/book.epub"), "book.epub")
    a.eq(Organize.basename("book.epub"), "book.epub")
end

T["target_dir omits the filename"] = function(a)
    a.eq(Organize.target_dir("/r/", { "Frank Herbert" }, "Dune"), "/r/Herbert, Frank/Dune")
end

T["flat structure moves the file directly into the root"] = function(a)
    a.eq(Organize.target_dir("/r/", { "Frank Herbert" }, "Dune", "flat"), "/r")
    a.eq(Organize.target_path("/r", { "Frank Herbert" }, "Dune", "d.epub", "flat"), "/r/d.epub")
end

T["nested is the default structure"] = function(a)
    a.eq(Organize.target_path("/r", { "Frank Herbert" }, "Dune", "d.epub"),
        Organize.target_path("/r", { "Frank Herbert" }, "Dune", "d.epub", "nested"))
end

return T
