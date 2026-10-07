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
    return PickerState.new(fields), fields
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
    return PickerState.new(fields), fields
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
    local state = PickerState.new(Fields.build(current, p))
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

return T
