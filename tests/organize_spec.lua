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

T["dots and spaces together never leave a dot-only name"] = function(a)
    a.eq(named("%title", { title = ".. ." }), "Unknown Title.epub")
    a.eq(Organize.target_dir("/root", { title = ".. .", authors = { "A B" } }, "nested"), "/root/B, A/Unknown Title")
end

T["Folder Preset 4 files a series book under its series"] = function(a)
    local p = Organize.target_path("/lib", COLOUR_OF_MAGIC, "x.epub", "nested", true, nil, "%author_sort/{%series/}%title")
    a.eq(p, "/lib/Pratchett, Terry/Discworld/The Colour of Magic/Pratchett, Terry - The Colour of Magic.epub")
end

local function folders(template, m)
    return Organize.target_dir("/lib", m, "nested", template)
end

T["Folder Preset 3 drops the empty series segment"] = function(a)
    local m = { title = "Enshittification", authors = { "Cory Doctorow" } }
    a.eq(folders(Organize.FOLDER_PRESETS[3], m), "/lib/Doctorow, Cory")
end

T["a token value cannot add folders"] = function(a)
    a.eq(folders(Organize.FOLDER_PRESETS[2], { authors = { "AC/DC" } }), "/lib/AC_DC")
end

T["a literal dot-dot segment cannot climb out of the Sorted library"] = function(a)
    a.eq(folders("../%author_sort/./%title", { title = "Dune", authors = { "Frank Herbert" } }),
        "/lib/Herbert, Frank/Dune")
end

T["each folder segment is capped at 200 bytes"] = function(a)
    local dir = folders("%title/%title", { title = string.rep("a", 300) })
    a.eq(dir, "/lib/" .. string.rep("a", 200) .. "/" .. string.rep("a", 200))
end

T["no saved folder template files a book as Author/Title/Author - Title"] = function(a)
    local p = Organize.target_path("/lib", { title = "Dune", authors = { "Frank Herbert" } }, "dune.epub")
    a.eq(p, "/lib/Herbert, Frank/Dune/Herbert, Frank - Dune.epub")
end

T["every folder preset renders for The Colour of Magic"] = function(a)
    local want = {
        "/lib/Pratchett, Terry/The Colour of Magic",
        "/lib/Pratchett, Terry",
        "/lib/Pratchett, Terry/Discworld",
        "/lib/Pratchett, Terry/Discworld/The Colour of Magic",
    }
    for i, template in ipairs(Organize.FOLDER_PRESETS) do
        a.eq(folders(template, COLOUR_OF_MAGIC), want[i])
    end
end

T["the Sort dialog label shows the folder path rendered for the book"] = function(a)
    a.eq(Organize.folder_label(COLOUR_OF_MAGIC, Organize.FOLDER_PRESETS[3]), "Pratchett, Terry / Discworld /")
    a.eq(Organize.folder_label(COLOUR_OF_MAGIC), "Pratchett, Terry / The Colour of Magic /")
end

T["validation accepts every preset for both kinds"] = function(a)
    for _, template in ipairs(Organize.FILENAME_PRESETS) do
        a.eq(Organize.validate_template(template, "filename"), nil)
    end
    for _, template in ipairs(Organize.FOLDER_PRESETS) do
        a.eq(Organize.validate_template(template, "folder"), nil)
    end
end

T["validation accepts escapes and a literal percent sign"] = function(a)
    a.eq(Organize.validate_template("%title %% %{ %} %", "filename"), nil)
end

T["an unknown token is refused and the reason names it"] = function(a)
    a.contains(Organize.validate_template("%titel", "filename"), "%titel")
    a.contains(Organize.validate_template("%Title - %author", "folder"), "%Title")
    a.contains(Organize.validate_template("%languagex/%title", "folder"), "%languagex")
end

T["unbalanced or nested braces are refused"] = function(a)
    a.is_true(Organize.validate_template("{%series", "filename"))
    a.is_true(Organize.validate_template("%title - (%series_index}", "filename"))
    a.is_true(Organize.validate_template("{a{b}}", "folder"))
    a.is_true(Organize.validate_template("%title}{", "folder"))
    a.eq(Organize.validate_template("%{%title - (%year)%}", "filename"), nil)
end

T["a slash is refused in a filename template but kept in a folder template"] = function(a)
    a.is_true(Organize.validate_template("%author/%title", "filename"))
    a.eq(Organize.validate_template("%author/%title", "folder"), nil)
end

T["an empty template is refused for both kinds"] = function(a)
    a.is_true(Organize.validate_template("", "filename"))
    a.is_true(Organize.validate_template("", "folder"))
    a.is_true(Organize.validate_template("   ", "folder"))
end

T["a nil template is refused for both kinds"] = function(a)
    a.is_true(Organize.validate_template(nil, "filename"))
    a.is_true(Organize.validate_template(nil, "folder"))
end

T["a custom folder template files a book by language and author"] = function(a)
    local m = { title = "Enshittification", authors = { "Cory Doctorow" }, language = "en" }
    a.eq(folders("%language/%author_sort", m), "/lib/en/Doctorow, Cory")
end

local function mkdir(path)
    local ok = os.execute(string.format("mkdir -p '%s'", path))
    return ok == 0 or ok == true
end

local function with_fake_koreader(fn)
    local saved = {}
    local names = { "util", "libs/libkoreader-lfs", "docsettings", "ffi/util" }
    for _i, name in ipairs(names) do
        saved[name] = package.loaded[name]
    end
    package.loaded["util"] = {
        makePath = mkdir,
    }
    package.loaded["libs/libkoreader-lfs"] = {
        attributes = function(path, what)
            local f = io.open(path, "r")
            if not f then
                return nil
            end
            f:close()
            return what == "mode" and "file" or {}
        end,
    }
    package.loaded["docsettings"] = { updateLocation = function() end }
    package.loaded["ffi/util"] = { copyFile = function() return "no copy in tests" end }
    local ok, err = pcall(fn)
    for _i, name in ipairs(names) do
        package.loaded[name] = saved[name]
    end
    if not ok then
        error(err, 0)
    end
end

local function write(path, text)
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
end

T["relocate refuses to overwrite a file already at the destination"] = function(a)
    with_fake_koreader(function()
        local root = os.tmpname()
        os.remove(root)
        mkdir(root .. "/incoming")
        mkdir(root .. "/lib/Pratchett, Terry/Discworld")
        local source = root .. "/incoming/x.epub"
        local existing = root .. "/lib/Pratchett, Terry/Discworld/Pratchett, Terry - The Colour of Magic.epub"
        write(source, "new")
        write(existing, "old")
        local ok, err = Organize.relocate(source, existing)
        local f = io.open(source, "r")
        local still_there = f ~= nil
        if f then
            f:close()
        end
        os.execute(string.format("rm -rf '%s'", root))
        a.eq(ok, false)
        a.eq(still_there, true)
        a.eq(err, "A file already exists at:\n" .. existing)
    end)
end

local SAVE_AS_META = { title = "Dune", authors = { "Frank Herbert" } }

T["destination keeps the file where it is with its current name when Save as does nothing"] = function(a)
    local dest = Organize.destination("/books/inbox/dune.epub", SAVE_AS_META, { sort = false, rename = false })
    a.eq(dest, "/books/inbox/dune.epub")
end

T["destination renames in place with the Filename template"] = function(a)
    local dest = Organize.destination("/books/inbox/dune.epub", SAVE_AS_META, {
        sort = false,
        rename = true,
        filename_template = "%title - %author",
    })
    a.eq(dest, "/books/inbox/Dune - Frank Herbert.epub")
end

T["destination sorts into the Sorted library with the Folder template and keeps the name"] = function(a)
    local dest = Organize.destination("/books/inbox/dune.epub", SAVE_AS_META, {
        sort = true,
        root = "/lib/",
        rename = false,
        folder_template = "%author_sort/%title",
    })
    a.eq(dest, "/lib/Herbert, Frank/Dune/dune.epub")
end

T["destination renames and sorts together"] = function(a)
    local dest = Organize.destination("/books/inbox/dune.epub", SAVE_AS_META, {
        sort = true,
        root = "/lib",
        rename = true,
        filename_template = "%author_sort - %title",
        folder_template = "%author_sort",
    })
    a.eq(dest, "/lib/Herbert, Frank/Herbert, Frank - Dune.epub")
end

T["destination does not sort when there is no Sorted library yet"] = function(a)
    local dest = Organize.destination("/books/inbox/dune.epub", SAVE_AS_META, { sort = true, rename = false })
    a.eq(dest, "/books/inbox/dune.epub")
end

T["clash reports a file already at a different destination"] = function(a)
    local exists = function(path)
        return path == "/lib/Dune.epub"
    end
    a.eq(Organize.clash("/in/dune.epub", "/lib/Dune.epub", exists), true)
    a.eq(Organize.clash("/in/dune.epub", "/lib/Other.epub", exists), false)
end

T["clash does not report a case-only rename of the file itself on a case-insensitive filesystem"] = function(a)
    local saved = package.loaded["libs/libkoreader-lfs"]
    package.loaded["libs/libkoreader-lfs"] = {
        attributes = function(path, what)
            if path:lower() ~= "/in/dune.epub" then
                return nil
            end
            local attrs = { mode = "file", dev = 1, ino = 7 }
            if what then
                return attrs[what]
            end
            return attrs
        end,
    }
    local ok, err = pcall(function()
        a.eq(Organize.clash("/in/dune.epub", "/in/Dune.epub"), false)
    end)
    package.loaded["libs/libkoreader-lfs"] = saved
    if not ok then
        error(err, 0)
    end
end

T["relocate never copies a file onto itself when a rename to its own inode fails"] = function(a)
    local names = { "util", "libs/libkoreader-lfs", "docsettings", "ffi/util" }
    local saved = {}
    for _i, name in ipairs(names) do
        saved[name] = package.loaded[name]
    end
    local copied = false
    package.loaded["util"] = { makePath = function() return true end }
    package.loaded["libs/libkoreader-lfs"] = {
        attributes = function()
            return { mode = "file", dev = 1, ino = 7 }
        end,
    }
    package.loaded["docsettings"] = { updateLocation = function() end }
    package.loaded["ffi/util"] = {
        copyFile = function()
            copied = true
            return nil
        end,
    }
    local source = os.tmpname()
    local ok, result = pcall(function()
        return Organize.relocate(source, "/nonexistent-rebind-dir/" .. Organize.basename(source):upper())
    end)
    os.remove(source)
    for _i, name in ipairs(names) do
        package.loaded[name] = saved[name]
    end
    if not ok then
        error(result, 0)
    end
    a.eq(copied, false)
end

T["clash never reports the file being its own destination"] = function(a)
    a.eq(Organize.clash("/in/dune.epub", "/in/dune.epub", function()
        return true
    end), false)
end

T["insert_token puts a Token at the cursor and moves the cursor after it"] = function(a)
    local text, cursor = Organize.insert_token("%author_sort - ", 15, "%title")
    a.eq(text, "%author_sort - %title")
    a.eq(cursor, 21)
end

T["insert_token inserts in the middle of a template"] = function(a)
    local text, cursor = Organize.insert_token("%title - %author", 6, "%series")
    a.eq(text, "%title%series - %author")
    a.eq(cursor, 13)
end

T["wrap_optional wraps the selection in braces"] = function(a)
    local template = "%title - %series #%series_index"
    local text, cursor = Organize.wrap_optional(template, 6, #template)
    a.eq(text, "%title{ - %series #%series_index}")
    a.eq(cursor, #text)
end

T["wrap_optional with nothing selected inserts braces with the cursor inside"] = function(a)
    local text, cursor = Organize.wrap_optional("%title", 6, 6)
    a.eq(text, "%title{}")
    a.eq(cursor, 7)
end

T["token_help shows each Token with this book's value and (empty) when it has none"] = function(a)
    local rows = Organize.token_help({
        title = "Dune",
        authors = { "Frank Herbert" },
        series = "Dune",
        series_index = 1,
        first_published = 1965,
        language = "en",
    })
    local by_token = {}
    for _i, row in ipairs(rows) do
        by_token[row.token] = row.value
    end
    a.eq(by_token["%publisher"], "(empty)")
    a.eq(by_token["%title"], "Dune")
    a.eq(by_token["%author_sort"], "Herbert, Frank")
    a.eq(by_token["%series_index"], "1")
    a.eq(by_token["%year"], "1965")
    a.eq(by_token["%language"], "en")
end

T["only the folder editor offers / New folder and mentions folders in Help"] = function(a)
    local function has_new_folder(kind)
        for _i, chip in ipairs(Organize.editor_chips(kind)) do
            if chip.label == "/ New folder" then
                return chip.token == "/"
            end
        end
        return false
    end
    a.eq(has_new_folder("folder"), true)
    a.eq(has_new_folder("filename"), false)
    a.eq(Organize.help_notes("folder")[1], "/ starts a new folder")
    for _i, note in ipairs(Organize.help_notes("filename")) do
        a.eq(note:find("folder", 1, true), nil)
    end
end

T["help_notes explain braces and the special characters"] = function(a)
    local joined = table.concat(Organize.help_notes("filename"), "\n")
    a.eq(joined:find("%% is", 1, true) ~= nil, true)
    a.eq(joined:find("%{ is", 1, true) ~= nil, true)
    a.eq(joined:find("%} is", 1, true) ~= nil, true)
    a.eq(joined:find("Unsupported characters become _", 1, true) ~= nil, true)
end

T["pattern_label names the Tokens in plain words"] = function(a)
    a.eq(Organize.pattern_label("%author_sort - %title"), "Author - Title")
    a.eq(Organize.pattern_label("%author_sort/{%series/}%title"), "Author / {Series /} Title")
    a.eq(Organize.pattern_label("%title{ - %series_index}"), "Title{ - Series #}")
end

T["pattern_label keeps escaped percent signs literal"] = function(a)
    a.eq(Organize.pattern_label("100%%title"), "100%%title")
    a.eq(Organize.pattern_label("%%{%title%%}"), "%%{Title%%}")
end

T["help_notes tell how to select text for the Optional chip"] = function(a)
    local joined = table.concat(Organize.help_notes("filename"), "\n")
    a.eq(joined:find("select", 1, true) ~= nil, true)
end

return T
