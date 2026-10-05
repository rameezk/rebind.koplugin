local Fields = require("rebind/fields")

local CURRENT = {
    title = "Old Title",
    authors = { "Old Author" },
    description = "Old blurb.",
    genres = { "Horror" },
    series = "Old Series",
    series_index = "3",
    language = "en",
    publisher = "Old House",
}

local PROPOSED = {
    title = "New Title",
    authors = { "New Author", "Co Author" },
    description = "New blurb.",
    genres = { "Fantasy", "Adventure" },
    series = "New Series",
    series_index = 1,
    language = "fr",
    publisher = "New House",
}

local function by_key(fields, key)
    for _, f in ipairs(fields) do
        if f.key == key then
            return f
        end
    end
    error("no field named " .. key)
end

local function build(current, proposed)
    return Fields.build(current or CURRENT, proposed or PROPOSED)
end

local T = {}

T["build exposes one field per editable value"] = function(a)
    local fields = build()
    a.eq(#fields, 8)
    a.eq(by_key(fields, "title").editor, "text")
    a.eq(by_key(fields, "author").editor, "authors")
    a.eq(by_key(fields, "series").editor, "series")
    a.eq(by_key(fields, "genre").editor, "genres")
    a.eq(by_key(fields, "language").editor, "text")
    a.eq(by_key(fields, "publisher").editor, "text")
    a.eq(by_key(fields, "description").editor, "longtext")
    a.eq(by_key(fields, "first_published").editor, "text")
end

T["First published sits directly after Series"] = function(a)
    local fields = build()
    local keys = {}
    for i, f in ipairs(fields) do
        keys[i] = f.key
    end
    local at
    for i, key in ipairs(keys) do
        if key == "series" then
            at = i
        end
    end
    a.eq(keys[at + 1], "first_published")
end

T["First published carries the Current and Proposed years"] = function(a)
    local fields = build({ first_published = "2012" }, { first_published = "1983" })
    local f = by_key(fields, "first_published")
    a.eq(f.display(f.current_value), "2012")
    a.eq(f.display(f.new_value), "1983")
end

T["First published applies a year and clears on empty"] = function(a)
    local f = by_key(build(), "first_published")
    local changes = {}
    f.apply(changes, "1983")
    a.eq(changes.first_published, "1983")
    f.apply(changes, "")
    a.eq(changes.first_published, "")
    a.is_true(f.is_empty(""))
end

T["First published refuses an Own value that is not a year"] = function(a)
    local f = by_key(build(), "first_published")
    a.is_true(f.validate("circa 1983") ~= nil)
    a.is_true(f.validate("83") ~= nil)
    a.is_true(f.validate("19831") ~= nil)
    a.eq(f.validate("1983"), nil)
    a.eq(f.validate(""), nil)
    a.eq(f.validate("  1983 "), nil)
    a.eq(f.from_input("  1983 "), "1983")
end

T["language and publisher carry both sides of the diff"] = function(a)
    local fields = build()
    local language = by_key(fields, "language")
    a.eq(language.display(language.current_value), "en")
    a.eq(language.display(language.new_value), "fr")
    local publisher = by_key(fields, "publisher")
    a.eq(publisher.display(publisher.current_value), "Old House")
    a.eq(publisher.display(publisher.new_value), "New House")
end

T["language trims and applies edited text"] = function(a)
    local field = by_key(build(), "language")
    local changes = {}
    field.apply(changes, field.from_input("  de  "))
    a.eq(changes.language, "de")
end

T["an emptied publisher applies as a clear"] = function(a)
    local field = by_key(build(), "publisher")
    local raw = field.from_input("   ")
    a.is_true(field.is_empty(raw))
    local changes = {}
    field.apply(changes, raw)
    a.eq(changes.publisher, "")
end

T["genres round-trip through the editor"] = function(a)
    local field = by_key(build(), "genre")
    a.eq(field.to_input(field.new_value), "Fantasy, Adventure")
    local raw = field.from_input(field.to_input(field.new_value))
    a.eq(#raw, 2)
    a.eq(raw[1], "Fantasy")
    a.eq(raw[2], "Adventure")
    local changes = {}
    field.apply(changes, raw)
    a.eq(changes.genres[1], "Fantasy")
end

T["split_authors trims and drops empties"] = function(a)
    local names = Fields.split_authors("  Frank Herbert ,, Brian Herbert,  ")
    a.eq(#names, 2)
    a.eq(names[1], "Frank Herbert")
    a.eq(names[2], "Brian Herbert")
end

T["split_authors on an empty string yields no authors"] = function(a)
    a.eq(#Fields.split_authors(""), 0)
    a.eq(#Fields.split_authors("   "), 0)
    a.eq(#Fields.split_authors(nil), 0)
end

T["authors round-trip through the editor"] = function(a)
    local field = by_key(build(), "author")
    a.eq(field.to_input(field.new_value), "New Author, Co Author")
    local raw = field.from_input(field.to_input(field.new_value))
    a.eq(#raw, 2)
    a.eq(raw[1], "New Author")
    a.eq(raw[2], "Co Author")
end

T["an emptied author list applies as a clear"] = function(a)
    local field = by_key(build(), "author")
    local changes = {}
    field.apply(changes, field.from_input(" , "))
    a.eq(type(changes.authors), "table")
    a.eq(#changes.authors, 0)
    a.is_true(field.is_empty(changes.authors))
end

T["series splits into name and index for the editor"] = function(a)
    local field = by_key(build(), "series")
    local input = field.to_input(field.new_value)
    a.eq(input.name, "New Series")
    a.eq(input.index, "1")
    a.eq(field.display(field.new_value), "New Series #1")
end

T["series index is dropped when the name is cleared"] = function(a)
    local field = by_key(build(), "series")
    local raw = field.from_input({ name = "  ", index = "4" })
    a.eq(raw.name, "")
    a.eq(raw.index, nil)
    a.is_true(field.is_empty(raw))

    local changes = {}
    field.apply(changes, raw)
    a.eq(changes.series, "")
    a.eq(changes.series_index, nil)
end

T["a series without an index displays and applies without one"] = function(a)
    local field = by_key(build(), "series")
    local raw = field.from_input({ name = "Dune", index = "" })
    a.eq(raw.index, nil)
    a.eq(field.display(raw), "Dune")

    local changes = {}
    field.apply(changes, raw)
    a.eq(changes.series, "Dune")
    a.eq(changes.series_index, nil)
end

T["a whole-number series index keeps its integer form"] = function(a)
    a.eq(Fields.format_index(2), "2")
    a.eq(Fields.format_index(2.0), "2")
    a.eq(Fields.format_index(1.5), "1.5")
    a.eq(Fields.format_index(nil), "")
    a.eq(Fields.format_index(""), "")
end

T["title trims and applies edited text"] = function(a)
    local field = by_key(build(), "title")
    local changes = {}
    field.apply(changes, field.from_input("  Dune  "))
    a.eq(changes.title, "Dune")
end

T["an emptied title applies as a clear"] = function(a)
    local field = by_key(build(), "title")
    local raw = field.from_input("   ")
    a.is_true(field.is_empty(raw))
    local changes = {}
    field.apply(changes, raw)
    a.eq(changes.title, "")
end

T["the description editor gets the full text, the box a preview"] = function(a)
    local long = string.rep("a", 400)
    local field = by_key(build(CURRENT, { description = long }), "description")
    a.eq(field.to_input(field.new_value), long)
    a.eq(#field.display(field.new_value) < #long, true)
    a.contains(field.display(field.new_value), "…")
end

T["the description preview does not split a utf8 character"] = function(a)
    local text = string.rep("é", 400)
    local shown = Fields.preview_text(text)
    a.contains(shown, "…")
    local body = shown:sub(1, #shown - #"…")
    a.eq(#body % 2, 0, "a split é would leave an odd byte count")
end

T["a short description is shown in full"] = function(a)
    local field = by_key(build(), "description")
    a.eq(field.display(field.current_value), "Old blurb.")
end

T["description whitespace is flattened for the preview only"] = function(a)
    local field = by_key(build(CURRENT, { description = "Line one.\n\nLine two." }), "description")
    a.eq(field.display(field.new_value), "Line one. Line two.")
    a.eq(field.to_input(field.new_value), "Line one.\n\nLine two.")
end

T["missing proposed values are empty, not nil"] = function(a)
    local fields = build(CURRENT, {})
    for _, f in ipairs(fields) do
        a.is_true(f.is_empty(f.new_value), f.key .. " should read as empty")
        a.eq(f.display(f.new_value), "")
    end
end

T["current values survive a build with no proposal"] = function(a)
    local fields = build(CURRENT, {})
    a.eq(by_key(fields, "title").display(by_key(fields, "title").current_value), "Old Title")
    a.eq(by_key(fields, "author").display(by_key(fields, "author").current_value), "Old Author")
    a.eq(by_key(fields, "series").display(by_key(fields, "series").current_value), "Old Series #3")
end

return T
