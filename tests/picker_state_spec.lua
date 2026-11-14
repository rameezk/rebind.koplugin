local Fields = require("rebind/fields")
local PickerState = require("rebind/picker_state")

local CURRENT = {
    title = "Same Title",
    authors = { "Same Author" },
    description = "Old blurb.",
    genres = { "Horror" },
    series = "Old Series",
    series_index = "3",
    language = "en",
    publisher = "Same House",
}

local function proposed(overrides)
    local p = {
        title = "Same Title",
        authors = { "Same Author" },
        description = "New blurb.",
        genres = { "Horror" },
        series = "New Series",
        series_index = 1,
        language = "en",
        publisher = "Same House",
    }
    for k, v in pairs(overrides or {}) do
        p[k] = v
    end
    return p
end

local function field_for(fields, key)
    for _, f in ipairs(fields) do
        if f.key == key then
            return f
        end
    end
end

local function selected_value_of(state, key)
    for _i, v in ipairs(state:values(key)) do
        if v.selected then
            return v
        end
    end
end

local function tags_of(state, key)
    local tags = {}
    for _i, v in ipairs(state:values(key)) do
        tags[#tags + 1] = v.tag
    end
    return table.concat(tags, ",")
end

local function open(overrides)
    local fields = Fields.build(CURRENT, proposed(overrides))
    return PickerState.new(fields, "Hardcover"), fields
end

local FOUR_DIFFER_CURRENT = {
    title = "Same Title",
    authors = { "Same Author" },
    description = "Old blurb.",
    genres = { "Horror" },
    series = "Old Series",
    series_index = "3",
    first_published = "1999",
    language = "en",
    publisher = "Same House",
}

local function open_four_differing()
    local fields = Fields.build(FOUR_DIFFER_CURRENT, {
        title = "Same Title",
        authors = { "Same Author" },
        description = "New blurb.",
        genres = { "Fantasy" },
        series = "New Series",
        series_index = 1,
        first_published = "2001",
        language = "en",
        publisher = "Same House",
    })
    return PickerState.new(fields, "Hardcover"), fields
end

local T = {}

T["Fields that differ are listed apart from the ones that already match"] = function(a)
    local state = open_four_differing()
    a.eq(table.concat(state:differing_keys(), ","), "series,first_published,genre,description")
    a.eq(state:matching_summary(), "4 fields already match · Title, Author(s), Language, Publisher")
    a.eq(state:status_line(), "Hardcover values: 4")
    a.eq(state:bulk_label(), "Use book values for all 4")
end

T["the bulk action flips every differing Field between book and Hardcover values"] = function(a)
    local state = open_four_differing()
    state:bulk()
    a.eq(state:status_line(), "Book values: 4")
    a.eq(state:bulk_label(), "Use Hardcover values for all 4")
    state:bulk()
    a.eq(state:status_line(), "Hardcover values: 4")
    a.eq(state:bulk_label(), "Use book values for all 4")
end

T["the bulk action does what its label says when one Field already selects its book value"] = function(a)
    local state = open_four_differing()
    state:select("series", "current")
    a.eq(state:bulk_label(), "Use Hardcover values for all 4")
    state:bulk()
    a.eq(state:status_line(), "Hardcover values: 4")
end

T["a saved Custom value is a third option, selected, tagged custom and counted"] = function(a)
    local state, fields = open_four_differing()
    state:save_custom("genre", field_for(fields, "genre").from_input("Western"))
    local selected = selected_value_of(state, "genre")
    a.eq(tags_of(state, "genre"), "book,Hardcover,custom")
    a.eq(selected.tag, "custom")
    a.eq(selected.text, "Western")
    a.eq(state:status_line(), "Hardcover values: 3 · Custom values: 1")
end

T["an empty Custom value is tagged removed and counted apart from Custom values"] = function(a)
    local state, fields = open_four_differing()
    state:save_custom("series", field_for(fields, "series").from_input({ name = "", index = "" }))
    a.eq(selected_value_of(state, "series").tag, "removed")
    a.eq(state:status_line(), "Hardcover values: 3 · Removed: 1")
end

T["a Translated value stays translated until it is edited and saved, then it is custom"] = function(a)
    local state = open_four_differing()
    state:save_translated("description", "Nouvelle description.")
    a.eq(state:selection("description"), "translated")
    a.eq(state:status_line(), "Hardcover values: 3 · Translated values: 1")
    a.eq(state:changes().description, "Nouvelle description.")
    state:save_custom("description", "Nouvelle description, revue.")
    a.eq(state:selection("description"), "custom")
    a.eq(state:status_line(), "Hardcover values: 3 · Custom values: 1")
    a.eq(tags_of(state, "description"), "book,Hardcover,custom")
end

T["the Apply label counts the Fields it will change"] = function(a)
    local state = open_four_differing()
    a.eq(state:apply_label(), "Apply 4 changes")
    state:select("series", "current")
    a.eq(state:apply_label(), "Apply 3 changes")
    state:select("description", "current")
    state:select("genre", "current")
    a.eq(state:apply_label(), "Apply 1 change")
end

T["closing needs a discard prompt only once something differs from the opening state"] = function(a)
    local state, fields = open_four_differing()
    a.eq(state:needs_discard_prompt(), false)
    state:select("series", "current")
    a.eq(state:needs_discard_prompt(), true)
    state:select("series", "new")
    a.eq(state:needs_discard_prompt(), false)
    state:save_custom("title", field_for(fields, "title").from_input("Other"))
    a.eq(state:needs_discard_prompt(), true)
end

T["the heading counts the Fields that differ"] = function(a)
    a.eq(open_four_differing():differ_heading(), "4 FIELDS DIFFER")
    a.eq(open({ series = "Old Series", series_index = "3", description = "Old blurb." }):differ_heading(),
        "NO FIELDS DIFFER")
    local state = open({ description = "Old blurb." })
    a.eq(state:differ_heading(), "1 FIELD DIFFERS")
end

T["opening selects Hardcover only for Fields that differ"] = function(a)
    local state = open()
    a.eq(state:selection("series"), "new")
    a.eq(state:selection("description"), "new")
    a.eq(state:selection("title"), "current")
end

T["a Field Hardcover has no value for stays current"] = function(a)
    local state = open({ publisher = "" })
    a.eq(state:selection("publisher"), "current")
end

T["a Field the Provider had nothing for is listed apart from the ones that already match"] = function(a)
    local state = open({ series = "", series_index = "" })
    a.eq(table.concat(state:not_found_keys(), ","), "series,first_published")
    a.eq(state:not_found_summary(), "2 fields not found on Hardcover · Series, First published")
    for _i, f in ipairs(state:matching_fields()) do
        a.is_true(f.key ~= "series")
    end
    a.eq(state:matching_summary(), "5 fields already match · Title, Author(s), Genre(s), Language, Publisher")
end

T["a Field the Provider had nothing for can be given a Custom value"] = function(a)
    local state, fields = open({ series = "", series_index = "" })
    state:save_custom("series", field_for(fields, "series").from_input({ name = "Dune", index = "2" }))
    a.eq(state:selection("series"), "custom")
    a.eq(state:changes().series, "Dune")
end

T["the not found summary names the Provider and counts Fields"] = function(a)
    local fields = Fields.build(CURRENT, proposed({ series = "", series_index = "", publisher = "" }))
    local state = PickerState.new(fields, "Open Library")
    a.eq(state:not_found_summary(), "3 fields not found on Open Library · Series, First published, Publisher")
end

T["the Proposed value choice, status line and bulk action name the Provider"] = function(a)
    local fields = Fields.build(CURRENT, proposed())
    local state = PickerState.new(fields, "Inventaire")
    a.eq(tags_of(state, "series"), "book,Inventaire")
    a.eq(state:status_line(), "Inventaire values: 2")
    a.eq(state:bulk_label(), "Use book values for all 2")
    state:bulk()
    a.eq(state:bulk_label(), "Use Inventaire values for all 2")
    a.eq(state:provider_label(), "Inventaire values")
end

T["a saved Custom value is selected and written"] = function(a)
    local state, fields = open()
    local genre = field_for(fields, "genre")
    state:save_custom("genre", genre.from_input("Fantasy, Adventure"))
    a.eq(state:selection("genre"), "custom")
    local changes = state:changes()
    a.eq(table.concat(changes.genres, ","), "Fantasy,Adventure")
end

T["changes to write are exactly the Fields whose selection differs from current"] = function(a)
    local state = open()
    local changes = state:changes()
    a.eq(changes.title, nil)
    a.eq(changes.description, "New blurb.")
    a.eq(changes.series, "New Series")
    a.eq(changes.genres, nil)
end

T["flipping the bulk action to book values writes nothing and back restores Hardcover"] = function(a)
    local state = open({ publisher = "" })
    state:bulk()
    a.eq(state:selection("series"), "current")
    a.eq(next(state:changes()), nil)
    state:bulk()
    a.eq(state:selection("series"), "new")
    a.eq(state:selection("publisher"), "current")
end

T["a single Field can be switched back to its current value"] = function(a)
    local state = open()
    state:select("series", "current")
    a.eq(state:selection("series"), "current")
    a.eq(state:changes().series, nil)
end

T["swapping the fields keeps Custom values selected"] = function(a)
    local state, fields = open()
    local genre = field_for(fields, "genre")
    state:save_custom("genre", genre.from_input("Fantasy"))
    state:set_fields(Fields.build(CURRENT, proposed({ series = "Other Series" })))
    a.eq(state:selection("genre"), "custom")
    a.eq(state:changes().series, "Other Series")
end

T["a Custom value equal to the current value is not written"] = function(a)
    local state, fields = open()
    state:save_custom("title", field_for(fields, "title").from_input("Same Title"))
    a.eq(state:selection("title"), "custom")
    a.eq(state:changes().title, nil)
end

T["a Description differing only past the preview limit is still written"] = function(a)
    local shared = string.rep("x", 400)
    local current = {}
    for k, v in pairs(CURRENT) do
        current[k] = v
    end
    current.description = shared .. " old"
    local p = proposed()
    p.description = shared .. " new"
    local state = PickerState.new(Fields.build(current, p), "Hardcover")
    a.eq(table.concat(state:differing_keys(), ","), "series,description")
    a.eq(state:changes().description, shared .. " new")
end

T["without Proposed values every Field is listed open with no bulk action"] = function(a)
    local state = PickerState.new(Fields.build(CURRENT, {}))
    a.eq(state:manual(), true)
    a.eq(#state:differing_fields(), 8)
    a.eq(#state:matching_fields(), 0)
    a.eq(state:has_bulk(), false)
    a.eq(state:differ_heading(), "8 FIELDS")
    a.eq(state:status_line(), "")
end

T["without Proposed values the status counts only the user's changes"] = function(a)
    local fields = Fields.build(CURRENT, {})
    local state = PickerState.new(fields)
    state:save_custom("genre", field_for(fields, "genre").from_input("Western"))
    state:save_custom("series", field_for(fields, "series").from_input({ name = "", index = "" }))
    state:save_translated("description", "Nouvelle description.")
    a.eq(state:status_line(), "Custom values: 1 · Translated values: 1 · Removed: 1")
end

T["a Match with Proposed values is not manual and has a bulk action"] = function(a)
    local state = open()
    a.eq(state:manual(), false)
    a.eq(state:has_bulk(), true)
end

T["dropping Hardcover keeps Custom values and lists every Field open"] = function(a)
    local state, fields = open()
    state:save_custom("genre", field_for(fields, "genre").from_input("Fantasy"))
    state:set_fields(Fields.build(CURRENT, {}))
    a.eq(state:manual(), true)
    a.eq(state:selection("genre"), "custom")
    a.eq(state:selection("series"), "current")
    a.eq(state:status_line(), "Custom values: 1")
    a.eq(tags_of(state, "series"), "book")
end

local function save_as(overrides)
    local cfg = {
        source_path = "/inbox/book.epub",
        metadata = CURRENT,
        library = "/lib",
        sort = false,
        rename = false,
        keep_backup = true,
        filename_template = "%title - %author",
        folder_template = "%author_sort/%title",
        exists = function()
            return false
        end,
    }
    for k, v in pairs(overrides or {}) do
        cfg[k] = v
    end
    return cfg
end

local function on_book_values(cfg)
    local state = open()
    state:bulk()
    state:set_save_as(save_as(cfg))
    return state
end

T["Apply says Rename and move when only Save as would rename and Sort"] = function(a)
    local state = on_book_values({ rename = true, sort = true })
    a.eq(state:apply_label(), "Rename and move")
    a.eq(state:apply_enabled(), true)
    a.eq(next(state:changes()), nil)
end

T["Apply says Rename when only the name would change"] = function(a)
    local state = on_book_values({ rename = true })
    a.eq(state:apply_label(), "Rename")
    a.eq(state:apply_enabled(), true)
end

T["Apply says Move when only the folder would change"] = function(a)
    local state = on_book_values({ sort = true })
    a.eq(state:apply_label(), "Move")
    a.eq(state:apply_enabled(), true)
end

T["Apply says No changes and is disabled when nothing would change"] = function(a)
    local state = on_book_values({})
    a.eq(state:apply_label(), "No changes")
    a.eq(state:apply_enabled(), false)
end

T["Sort without a Library leaves the file where it is"] = function(a)
    local state = on_book_values({ sort = true, library = false })
    a.eq(state:apply_label(), "No changes")
end

T["Apply keeps counting metadata changes when Save as also renames"] = function(a)
    local state = open()
    state:set_save_as(save_as({ rename = true, sort = true }))
    a.eq(state:apply_label(), "Apply 2 changes")
    a.eq(state:apply_enabled(), true)
end

T["a name clash disables Apply and names the way out"] = function(a)
    local state = open()
    state:set_save_as(save_as({
        rename = true,
        exists = function(path)
            return path == "/inbox/Same Title - Same Author.epub"
        end,
    }))
    a.eq(state:name_clash(), true)
    a.eq(state:apply_label(), "Change the name or folder to apply")
    a.eq(state:apply_enabled(), false)
end

T["the Save as summary shows backup state over the destination path"] = function(a)
    local state = open()
    state:set_save_as(save_as({ rename = true, sort = true }))
    local top, bottom = state:save_as_summary()
    a.eq(top, "Save as · backup kept")
    a.eq(bottom, "/lib/Author, Same/Same Title/Same Title - Same Author.epub")
    state:set_save_as(save_as({ keep_backup = false }))
    top, bottom = state:save_as_summary()
    a.eq(top, "Save as · no backup")
    a.eq(bottom, "/inbox/book.epub")
end

T["the Save as summary reports a name clash instead of the path"] = function(a)
    local state = open()
    state:set_save_as(save_as({
        rename = true,
        exists = function()
            return true
        end,
    }))
    local _, bottom = state:save_as_summary()
    a.eq(bottom, "A file with this name already exists")
end

T["the destination follows the values selected in the Picker"] = function(a)
    local state = open()
    state:set_save_as(save_as({ rename = true, filename_template = "%title{ - %series}" }))
    a.eq(state:destination(), "/inbox/Same Title - New Series.epub")
    state:select("series", "current")
    a.eq(state:destination(), "/inbox/Same Title - Old Series.epub")
end

local Images = require("tests/support/images")
local Cover = require("rebind/cover")

local function cover_image()
    local info = Cover.check(Images.jpeg(400, 600))
    info.url = "https://assets.test/dune.jpg"
    return info
end

local function cover_state(proposed_overrides)
    local current = { title = "Same Title", has_cover = false }
    local fields = Fields.build(current, proposed(proposed_overrides or { cover_image = cover_image() }))
    return PickerState.new(fields, "Hardcover"), fields
end

T["the cover field comes first for a book with no cover"] = function(a)
    local state, fields = cover_state()
    a.eq(fields[1].key, "cover")
    a.eq(state:differing_fields()[1].key, "cover")
end

T["the provider cover starts selected and counts as a change"] = function(a)
    local state = cover_state()
    a.eq(state:selection("cover"), "new")
    local before = state:change_count()
    state:select("cover", "current")
    a.eq(state:change_count(), before - 1)
    a.eq(state:changes().cover, nil)
    state:select("cover", "new")
    a.eq(state:changes().cover.url, "https://assets.test/dune.jpg")
    a.eq(state:changes().cover.bytes, cover_image().bytes)
end

T["the cover shows up in the apply label"] = function(a)
    local same = {}
    for k, v in pairs(CURRENT) do
        same[k] = v
    end
    same.cover_image = cover_image()
    local current = { has_cover = false }
    for k, v in pairs(CURRENT) do
        current[k] = v
    end
    local state = PickerState.new(Fields.build(current, same), "Hardcover")
    a.eq(state:apply_label(), "Apply 1 change")
end

T["the cover offers the book as no cover and the provider cover with its size"] = function(a)
    local state = cover_state()
    local options = state:values("cover")
    a.eq(#options, 2)
    a.eq(options[1].id, "current")
    a.eq(options[1].tag, "book")
    a.eq(options[1].text, "no cover")
    a.eq(options[1].selected, false)
    a.eq(options[1].image, nil)
    a.eq(options[2].id, "new")
    a.eq(options[2].tag, "Hardcover")
    a.eq(options[2].text, "400×600")
    a.eq(options[2].selected, true)
    a.eq(options[2].image.width, 400)
end

T["the bulk button counts the cover and moves it with the other fields"] = function(a)
    local state = cover_state()
    local n = #state:differing_fields()
    a.eq(state:bulk_label(), "Use book values for all " .. n)
    state:bulk()
    a.eq(state:selection("cover"), "current")
    a.eq(state:bulk_label(), "Use Hardcover values for all " .. n)
    state:bulk()
    a.eq(state:selection("cover"), "new")
end

T["the cover field is hidden when the download failed or nothing passed the filter"] = function(a)
    local with = Fields.build({ has_cover = false }, proposed({ cover_image = cover_image() }))
    local without = Fields.build({ has_cover = false }, proposed())
    a.eq(field_for(without, "cover"), nil)
    a.eq(#without + 1, #with)
    a.eq(field_for(without, "title").key, "title")
end

local function with_cover_state(current_overrides)
    local current = { title = "Same Title", has_cover = true, cover_image = Cover.describe(Images.jpeg(300, 450, 3000)) }
    for k, v in pairs(current_overrides or {}) do
        current[k] = v
    end
    local fields = Fields.build(current, proposed({ cover_image = cover_image() }))
    return PickerState.new(fields, "Hardcover"), fields
end

T["a book with a cover keeps it selected and the cover is not a change"] = function(a)
    local state, fields = with_cover_state()
    a.eq(fields[1].key, "cover")
    a.eq(state:selection("cover"), "current")
    local before = state:change_count()
    a.eq(state:changes().cover, nil)
    local options = state:values("cover")
    a.eq(options[1].tag, "book")
    a.eq(options[1].text, "300×450")
    a.eq(options[1].selected, true)
    a.eq(options[2].tag, "Hardcover")
    a.eq(options[2].text, "400×600")
end

T["choosing the provider cover for a book with a cover counts as a change"] = function(a)
    local state = with_cover_state()
    local before = state:change_count()
    state:select("cover", "new")
    a.eq(state:change_count(), before + 1)
    a.eq(state:changes().cover.url, "https://assets.test/dune.jpg")
end

T["a cover that cannot be read still counts as the book's cover and stays selected"] = function(a)
    local state = with_cover_state({ cover_image = false })
    a.eq(state:selection("cover"), "current")
    a.eq(state:changes().cover, nil)
    a.eq(state:values("cover")[1].text, "cover")
end

T["the cover field is hidden when the book already has the cover set from the same source and nothing to restore"] = function(a)
    local _, fields = with_cover_state({ cover_source = "https://assets.test/dune.jpg" })
    a.eq(field_for(fields, "cover"), nil)
end

T["the cover field header reads hold to view"] = function(a)
    local _state, fields = cover_state()
    a.eq(fields[1].hint, "Hold to view")
end

T["previewing the provider cover lists source, edition, pixel size and file size"] = function(a)
    local state = cover_state()
    local preview = state:preview("cover", "new", "Paperback 2005")
    a.eq(preview.id, "new")
    a.eq(preview.source, "Hardcover")
    a.eq(preview.edition, "Paperback 2005")
    a.eq(preview.size, "400×600")
    a.eq(preview.file_size, string.format("%.1f KB", #cover_image().bytes / 1024))
    a.eq(preview.image.width, 400)
    a.eq(preview.selected, true)
end

T["previewing the book cover has no edition and an unselected preview reports it"] = function(a)
    local state = cover_state()
    local preview = state:preview("cover", "current", "Paperback 2005")
    a.eq(preview.source, "book")
    a.eq(preview.edition, nil)
    a.eq(preview.image, nil)
    a.eq(preview.selected, false)
end

T["selecting from the preview selects that tile and counts it as a change"] = function(a)
    local state = cover_state()
    state:select("cover", "current")
    local before = state:change_count()
    state:select("cover", state:preview("cover", "new", "x").id)
    a.eq(state:selection("cover"), "new")
    a.eq(state:change_count(), before + 1)
end

T["previewing without selecting leaves the selection alone"] = function(a)
    local state = cover_state()
    state:preview("cover", "current", "x")
    a.eq(state:selection("cover"), "new")
end

T["the cover field stays when the same source cover has a kept original or another source"] = function(a)
    local _, kept = with_cover_state({ cover_source = "https://assets.test/dune.jpg", original_cover = "cover" })
    a.eq(field_for(kept, "cover").key, "cover")
    local _, other = with_cover_state({ cover_source = "https://assets.test/other.jpg" })
    a.eq(field_for(other, "cover").key, "cover")
end

local function replaced_state(current_overrides, proposed_overrides)
    local current = {
        title = "Same Title",
        has_cover = true,
        cover_image = Cover.describe(Images.jpeg(400, 600, 4000)),
        cover_source = "https://assets.test/old.jpg",
        original_cover = "cover",
        original_cover_image = Cover.describe(Images.jpeg(300, 450, 3000)),
    }
    for k, v in pairs(current_overrides or {}) do
        current[k] = v
    end
    local fields = Fields.build(current, proposed(proposed_overrides or { cover_image = cover_image() }))
    return PickerState.new(fields, "Hardcover"), fields
end

T["a replaced cover offers the book, the original and the provider cover in that order"] = function(a)
    local state = replaced_state()
    a.eq(tags_of(state, "cover"), "book,original,Hardcover")
    local options = state:values("cover")
    a.eq(options[2].id, "original")
    a.eq(options[2].text, "300×450")
    a.eq(options[2].image.width, 300)
    a.eq(options[2].selected, false)
    a.eq(state:selection("cover"), "current")
end

T["the original is offered when the provider has no cover"] = function(a)
    local state, fields = replaced_state(nil, {})
    a.eq(fields[1].key, "cover")
    a.eq(state:differing_fields()[1].key, "cover")
    a.eq(tags_of(state, "cover"), "book,original")
    a.eq(state:selection("cover"), "current")
    a.eq(state:changes().cover, nil)
    a.eq(state:changes().restore_cover, nil)
end

T["selecting the original counts as a change and restores it on apply"] = function(a)
    local state = replaced_state()
    local before = state:change_count()
    state:select("cover", "original")
    a.eq(state:change_count(), before + 1)
    a.eq(state:changes().restore_cover, true)
    a.eq(state:changes().cover, nil)
    a.eq(state:apply_label(), "Apply " .. state:change_count() .. " changes")
    a.eq(state:status_line(), "Hardcover values: 6 · Original cover: 1")
    a.is_true(state:needs_discard_prompt())
end

T["the original of a book that had no cover reads no cover and has no image"] = function(a)
    local state = replaced_state({ original_cover = "none", original_cover_image = false })
    local original = state:values("cover")[2]
    a.eq(original.tag, "original")
    a.eq(original.text, "no cover")
    a.eq(original.image, nil)
    state:select("cover", "original")
    a.eq(state:changes().restore_cover, true)
end

T["an original that cannot be read is still offered as a cover"] = function(a)
    local state = replaced_state({ original_cover_image = false })
    a.eq(state:values("cover")[2].text, "cover")
end

T["the bulk button moves a restored cover back to the book values"] = function(a)
    local state = replaced_state()
    state:select("cover", "original")
    state:bulk()
    a.eq(state:selection("cover"), "current")
end

T["a book without a kept original never offers one"] = function(a)
    local state = with_cover_state()
    a.eq(tags_of(state, "cover"), "book,Hardcover")
    a.eq(state:changes().restore_cover, nil)
end

T["the same source cover still shows the cover field with the original, even when that is no cover"] = function(a)
    local state = replaced_state({ cover_source = "https://assets.test/dune.jpg", cover_image = cover_image() })
    a.eq(tags_of(state, "cover"), "book,original")
    state = replaced_state({ cover_source = "https://assets.test/dune.jpg", cover_image = cover_image(), original_cover = "none", original_cover_image = false })
    a.eq(tags_of(state, "cover"), "book,original")
end

return T
