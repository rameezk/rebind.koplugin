local _ = require("gettext")

local Fields = {}

local PREVIEW_LIMIT = 300

function Fields.preview_text(text)
    if type(text) ~= "string" or text == "" then
        return text
    end
    local flat = text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    if #flat <= PREVIEW_LIMIT then
        return flat
    end
    local cut = PREVIEW_LIMIT
    while cut > 0 do
        local b = flat:byte(cut + 1)
        if not b or b < 0x80 or b > 0xBF then
            break
        end
        cut = cut - 1
    end
    return flat:sub(1, cut) .. "…"
end

function Fields.join_authors(authors)
    if type(authors) ~= "table" then
        return ""
    end
    return table.concat(authors, ", ")
end

function Fields.split_authors(text)
    local out = {}
    if type(text) ~= "string" then
        return out
    end
    for part in (text .. ","):gmatch("([^,]*),") do
        local name = part:gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" then
            out[#out + 1] = name
        end
    end
    return out
end

Fields.join_list = Fields.join_authors
Fields.split_list = Fields.split_authors

function Fields.format_index(v)
    if v == nil or v == "" then
        return ""
    end
    local n = tonumber(v)
    if n then
        if n == math.floor(n) then
            return tostring(math.floor(n))
        end
        return tostring(n)
    end
    return tostring(v)
end

function Fields.series_text(name, index)
    if not name or name == "" then
        return ""
    end
    local idx = Fields.format_index(index)
    if idx ~= "" then
        return name .. " #" .. idx
    end
    return name
end

local function trim(text)
    if type(text) ~= "string" then
        return ""
    end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function text_field(key, label, editor, current_value, new_value, apply)
    return {
        key = key,
        label = label,
        editor = editor,
        current_value = current_value or "",
        new_value = new_value or "",
        is_empty = function(raw)
            return trim(raw) == ""
        end,
        display = function(raw)
            return raw
        end,
        to_input = function(raw)
            return raw or ""
        end,
        from_input = function(input)
            return trim(input)
        end,
        apply = apply,
    }
end

local function title_field(current, proposed)
    local field = text_field("title", _("Title"), "text", current.title, proposed.title,
        function(changes, raw)
            changes.title = trim(raw)
        end)
    return field
end

local function description_field(current, proposed)
    local field = text_field("description", _("Description"), "longtext",
        current.description, proposed.description,
        function(changes, raw)
            changes.description = trim(raw)
        end)
    field.display = Fields.preview_text
    return field
end

local function author_field(current, proposed)
    return {
        key = "author",
        label = _("Author(s)"),
        editor = "authors",
        current_value = type(current.authors) == "table" and current.authors or {},
        new_value = type(proposed.authors) == "table" and proposed.authors or {},
        is_empty = function(raw)
            return type(raw) ~= "table" or #raw == 0
        end,
        display = Fields.join_authors,
        to_input = Fields.join_authors,
        from_input = Fields.split_authors,
        apply = function(changes, raw)
            changes.authors = type(raw) == "table" and raw or {}
        end,
    }
end

local function genres_field(current, proposed)
    return {
        key = "genre",
        label = _("Genre(s)"),
        editor = "genres",
        current_value = type(current.genres) == "table" and current.genres or {},
        new_value = type(proposed.genres) == "table" and proposed.genres or {},
        is_empty = function(raw)
            return type(raw) ~= "table" or #raw == 0
        end,
        display = Fields.join_list,
        to_input = Fields.join_list,
        from_input = Fields.split_list,
        apply = function(changes, raw)
            changes.genres = type(raw) == "table" and raw or {}
        end,
    }
end

local function language_field(current, proposed)
    return text_field("language", _("Language"), "text", current.language, proposed.language,
        function(changes, raw)
            changes.language = trim(raw)
        end)
end

local function publisher_field(current, proposed)
    return text_field("publisher", _("Publisher"), "text", current.publisher, proposed.publisher,
        function(changes, raw)
            changes.publisher = trim(raw)
        end)
end

local function series_field(current, proposed)
    return {
        key = "series",
        label = _("Series"),
        editor = "series",
        current_value = { name = current.series, index = current.series_index },
        new_value = { name = proposed.series, index = proposed.series_index },
        is_empty = function(raw)
            return type(raw) ~= "table" or trim(raw.name) == ""
        end,
        display = function(raw)
            if type(raw) ~= "table" then
                return ""
            end
            return Fields.series_text(raw.name, raw.index)
        end,
        to_input = function(raw)
            if type(raw) ~= "table" then
                return { name = "", index = "" }
            end
            return { name = raw.name or "", index = Fields.format_index(raw.index) }
        end,
        from_input = function(input)
            input = type(input) == "table" and input or {}
            local name = trim(input.name)
            if name == "" then
                return { name = "", index = nil }
            end
            local index = trim(input.index)
            return { name = name, index = index ~= "" and index or nil }
        end,
        apply = function(changes, raw)
            if type(raw) ~= "table" or trim(raw.name) == "" then
                changes.series = ""
                changes.series_index = nil
                return
            end
            changes.series = trim(raw.name)
            changes.series_index = raw.index
        end,
    }
end

function Fields.build(current, proposed)
    current = current or {}
    proposed = proposed or {}
    return {
        title_field(current, proposed),
        author_field(current, proposed),
        series_field(current, proposed),
        genres_field(current, proposed),
        language_field(current, proposed),
        publisher_field(current, proposed),
        description_field(current, proposed),
    }
end

return Fields
