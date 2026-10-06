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

local function open(overrides)
    local fields = Fields.build(CURRENT, proposed(overrides))
    return PickerState.new(fields), fields
end

local T = {}

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
    local genre
    for _, f in ipairs(fields) do
        if f.key == "genre" then
            genre = f
        end
    end
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

T["keep all current writes nothing and use all new restores Hardcover"] = function(a)
    local state = open({ publisher = "" })
    state:select_all("current")
    a.eq(state:selection("series"), "current")
    a.eq(next(state:changes()), nil)
    state:select_all("new")
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
    local genre
    for _, f in ipairs(fields) do
        if f.key == "genre" then
            genre = f
        end
    end
    state:save_custom("genre", genre.from_input("Fantasy"))
    state:set_fields(Fields.build(CURRENT, proposed({ series = "Other Series" })))
    a.eq(state:selection("genre"), "custom")
    a.eq(state:changes().series, "Other Series")
end

return T
