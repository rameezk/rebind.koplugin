local _ = require("gettext")

local Hardcover = {
    _user_id = nil,
}

function Hardcover.available()
    local ok, Api = pcall(require, "hardcover/lib/hardcover_api")
    if ok and type(Api) == "table" and type(Api.query) == "function" then
        return true, Api
    end
    return false, nil
end

function Hardcover.get_user_id(Api)
    if Hardcover._user_id then
        return Hardcover._user_id
    end
    local me = Api:me()
    if me and me.id then
        Hardcover._user_id = me.id
    end
    return Hardcover._user_id
end

local function authors_from_contributions(c)
    if type(c) ~= "table" then
        return {}
    end
    if type(c.author) == "string" and c.author ~= "" then
        return { c.author }
    end
    local names = {}
    for _, entry in ipairs(c) do
        if type(entry) == "table" then
            if type(entry.author) == "table" and type(entry.author.name) == "string" then
                names[#names + 1] = entry.author.name
            elseif type(entry.author) == "string" and entry.author ~= "" then
                names[#names + 1] = entry.author
            end
        end
    end
    return names
end

local GENRE_LIMIT = 5

local function genres_from_tags(tags)
    if type(tags) ~= "table" then
        return nil
    end
    local names = {}
    for _, entry in ipairs(tags) do
        if type(entry) == "table" and type(entry.tag) == "string" and entry.tag ~= "" then
            names[#names + 1] = entry.tag
            if #names >= GENRE_LIMIT then
                break
            end
        end
    end
    return names
end

local function series_entry(book)
    local bs = book and book.book_series
    if type(bs) == "table" and type(bs[1]) == "table" then
        return bs[1]
    end
    return nil
end

local function language_code(language)
    if type(language) == "string" then
        return language ~= "" and language or nil
    end
    if type(language) ~= "table" then
        return nil
    end
    for _, key in ipairs({ "code2", "code3", "language" }) do
        local value = language[key]
        if type(value) == "string" and value ~= "" then
            return value
        end
    end
    return nil
end

local function publisher_name(publisher)
    if type(publisher) == "string" then
        return publisher ~= "" and publisher or nil
    end
    if type(publisher) == "table" and type(publisher.name) == "string" and publisher.name ~= "" then
        return publisher.name
    end
    return nil
end

function Hardcover.extract(book)
    local series_name, series_index
    local se = series_entry(book)
    if se then
        if type(se.series) == "table" then
            series_name = se.series.name
        end
        series_index = se.position
    end

    return {
        book_id = book.book_id,
        edition_id = book.edition_id,
        title = book.title,
        authors = authors_from_contributions(book.contributions),
        description = book.description,
        genres = book.genres or genres_from_tags(book.cached_tags),
        series = series_name,
        series_index = series_index,
        release_year = book.release_year,
        edition_format = book.edition_format or book.filetype,
        language = language_code(book.language),
        publisher = publisher_name(book.publisher),
        pages = book.pages,
        users_count = book.users_count,
        users_read_count = book.users_read_count,
    }
end

function Hardcover.edition_label(m)
    local parts = {}
    if m.edition_format and m.edition_format ~= "" then
        parts[#parts + 1] = tostring(m.edition_format)
    end
    if m.release_year then
        parts[#parts + 1] = tostring(m.release_year)
    end
    if m.publisher then
        parts[#parts + 1] = m.publisher
    end
    if tonumber(m.pages) then
        parts[#parts + 1] = tostring(math.floor(tonumber(m.pages))) .. _("pp")
    end
    if m.language then
        parts[#parts + 1] = m.language
    end
    if #parts == 0 then
        return ""
    end
    return table.concat(parts, " · ")
end

local DETAILS_QUERY = [[
    query ($ids: [Int!]) {
      books(where: { id: { _in: $ids }}) {
        id
        description
        genres: cached_tags(path: "Genre")
      }
    }
]]

function Hardcover.attach_details(Api, books)
    if type(books) ~= "table" or #books == 0 then
        return books
    end

    local ids = {}
    for _, book in ipairs(books) do
        local id = tonumber(book.book_id)
        if id and (book.description == nil or book.genres == nil) then
            ids[#ids + 1] = id
        end
    end
    if #ids == 0 then
        return books
    end

    local ok, result = pcall(function()
        return Api:query(DETAILS_QUERY, { ids = ids })
    end)
    local rows = ok and type(result) == "table" and result.books
    if type(rows) ~= "table" then
        return books
    end

    local by_id = {}
    for _, row in ipairs(rows) do
        if type(row) == "table" then
            by_id[tonumber(row.id)] = row
        end
    end

    for _, book in ipairs(books) do
        local row = by_id[tonumber(book.book_id)]
        if row then
            if book.description == nil then
                book.description = row.description
            end
            if book.genres == nil then
                book.genres = genres_from_tags(row.genres)
            end
        end
    end

    return books
end

local EDITION_LIMIT = 30

local AUDIOBOOK_FORMAT_ID = 2

local EDITIONS_QUERY = [[
    query ($book_id: Int!, $limit: Int!) {
      editions(
        where: {
          book_id: { _eq: $book_id },
          _or: [
            { reading_format_id: { _is_null: true }},
            { reading_format_id: { _neq: ]] .. AUDIOBOOK_FORMAT_ID .. [[ }}
          ]
        },
        order_by: { users_count: desc_nulls_last },
        limit: $limit
      ) {
        id
        title
        edition_format
        reading_format_id
        pages
        users_count
        release_date
        publisher { name }
        language { code2 language }
      }
    }
]]

local READING_FORMAT_NAMES = {
    [1] = "Physical Book",
    [4] = "E-Book",
}

local function edition_format_name(row)
    if type(row.edition_format) == "string" and row.edition_format ~= "" then
        return row.edition_format
    end
    return READING_FORMAT_NAMES[tonumber(row.reading_format_id)]
end

local function release_year_of(release_date)
    if type(release_date) ~= "string" then
        return nil
    end
    return release_date:match("^(%d%d%d%d)%-")
end

function Hardcover.list_editions(Api, book)
    if type(book) ~= "table" or type(Api) ~= "table" or type(Api.query) ~= "function" then
        return {}, false
    end
    local book_id = tonumber(book.book_id)
    if not book_id then
        return {}, false
    end

    local ok, result = pcall(function()
        return Api:query(EDITIONS_QUERY, { book_id = book_id, limit = EDITION_LIMIT + 1 })
    end)
    local rows = ok and type(result) == "table" and result.editions
    if type(rows) ~= "table" then
        return {}, false
    end

    local out = {}
    for _, row in ipairs(rows) do
        if type(row) == "table" then
            if #out >= EDITION_LIMIT then
                return out, true
            end
            out[#out + 1] = {
                book_id = book_id,
                edition_id = row.id,
                title = row.title or book.title,
                contributions = book.contributions,
                book_series = book.book_series,
                description = book.description,
                genres = book.genres,
                cached_tags = book.cached_tags,
                users_read_count = book.users_read_count,
                edition_format = edition_format_name(row),
                release_year = release_year_of(row.release_date),
                language = row.language,
                publisher = row.publisher,
                pages = row.pages,
                users_count = row.users_count,
            }
        end
    end
    return out, false
end

function Hardcover.lookup(Api, meta)
    local user_id = Hardcover.get_user_id(Api)

    local identifiers = {}
    if meta.isbn_13 then
        identifiers.isbn_13 = meta.isbn_13
    end
    if meta.isbn_10 then
        identifiers.isbn_10 = meta.isbn_10
    end

    if next(identifiers) then
        local book = Api:findBookByIdentifiers(identifiers, user_id)
        if book then
            return Hardcover.attach_details(Api, { book }), "isbn"
        end
    end

    if meta.title and meta.title ~= "" then
        local author = meta.authors and meta.authors[1]
        local books = Api:findBooks(meta.title, author, user_id)
        if type(books) == "table" then
            return Hardcover.attach_details(Api, books), "search"
        end
    end

    return {}, "search"
end

return Hardcover
