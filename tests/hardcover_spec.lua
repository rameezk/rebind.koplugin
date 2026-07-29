local Hardcover = require("rebind/hardcover")
local FakeApi = require("tests/support/fake_api")

local T = {}

T["extract reads authors from array contributions"] = function(a)
    local book = {
        book_id = 1,
        title = "Dune",
        contributions = {
            { author = { name = "Frank Herbert" } },
            { author = { name = "Someone Else" } },
        },
        book_series = { { position = 1, series = { name = "Dune" } } },
    }
    local m = Hardcover.extract(book)
    a.eq(m.title, "Dune")
    a.eq(m.authors[1], "Frank Herbert")
    a.eq(m.authors[2], "Someone Else")
    a.eq(m.series, "Dune")
    a.eq(m.series_index, 1)
end

T["extract reads a single string contribution"] = function(a)
    local m = Hardcover.extract({ title = "X", contributions = { author = "Solo Author" } })
    a.eq(m.authors[1], "Solo Author")
    a.eq(#m.authors, 1)
end

T["extract handles a missing series and empty contributions"] = function(a)
    local m = Hardcover.extract({ title = "X", contributions = {} })
    a.eq(m.series, nil)
    a.eq(m.series_index, nil)
    a.eq(#m.authors, 0)
end

T["extract carries the description through"] = function(a)
    local m = Hardcover.extract({ title = "X", contributions = {}, description = "A blurb." })
    a.eq(m.description, "A blurb.")
end

T["extract carries attached genres through"] = function(a)
    local m = Hardcover.extract({ title = "X", contributions = {}, genres = { "Fantasy", "Adventure" } })
    a.eq(m.genres[1], "Fantasy")
    a.eq(m.genres[2], "Adventure")
end

T["extract reads genres from raw cached_tags, capped at five"] = function(a)
    local tags = {}
    for i = 1, 8 do
        tags[i] = { tag = "G" .. i }
    end
    local m = Hardcover.extract({ title = "X", contributions = {}, cached_tags = tags })
    a.eq(#m.genres, 5)
    a.eq(m.genres[1], "G1")
    a.eq(m.genres[5], "G5")
end

T["extract reads the edition language code and publisher name"] = function(a)
    local m = Hardcover.extract({
        title = "X",
        contributions = {},
        language = { code2 = "en", language = "English" },
        publisher = { name = "Penguin" },
    })
    a.eq(m.language, "en")
    a.eq(m.publisher, "Penguin")
end

T["extract falls back to the language name when no code is given"] = function(a)
    local m = Hardcover.extract({ title = "X", contributions = {}, language = { language = "Icelandic" } })
    a.eq(m.language, "Icelandic")
end

T["extract leaves language and publisher nil when the edition has neither"] = function(a)
    local m = Hardcover.extract({ title = "X", contributions = {} })
    a.eq(m.language, nil)
    a.eq(m.publisher, nil)
end

T["extract carries the edition id through"] = function(a)
    local m = Hardcover.extract({ title = "X", contributions = {}, edition_id = 99 })
    a.eq(m.edition_id, 99)
end

T["edition_label describes format, year, publisher, pages and language"] = function(a)
    local label = Hardcover.edition_label({
        edition_format = "Paperback",
        release_year = "2010",
        publisher = "Penguin",
        pages = 412,
        language = "en",
    })
    a.eq(label, "Paperback · 2010 · Penguin · 412pp · en")
end

T["edition_label skips the parts an edition does not have"] = function(a)
    a.eq(Hardcover.edition_label({ edition_format = "Ebook", pages = 300 }), "Ebook · 300pp")
    a.eq(Hardcover.edition_label({}), "")
end

T["list_editions asks the API for one more edition than it shows"] = function(a)
    local api = FakeApi.new({ editions = { { id = 1, title = "Dune" } } })
    local editions = Hardcover.list_editions(api, { book_id = 7 })
    a.eq(#editions, 1)
    a.eq(editions[1].edition_id, 1)
    a.eq(editions[1].book_id, 7)
    a.eq(api.calls.editions_query.parameters.book_id, 7)
    a.eq(api.calls.editions_query.parameters.limit, 31)
end

T["list_editions leaves audiobooks out of the query"] = function(a)
    local api = FakeApi.new({ editions = { { id = 1 } } })
    Hardcover.list_editions(api, { book_id = 7 })
    a.contains(api.calls.editions_query.query, "reading_format_id: { _neq: 2 }")
end

T["list_editions takes the description, genres and series from the book"] = function(a)
    local api = FakeApi.new({
        editions = {
            { id = 1 },
            { id = 2, description = "Ignored: editions have no description." },
        },
    })
    local editions = Hardcover.list_editions(api, {
        book_id = 7,
        description = "Book blurb.",
        genres = { "Science Fiction" },
        book_series = { { position = 1, series = { name = "Dune" } } },
        contributions = { { author = { name = "Frank Herbert" } } },
    })
    a.eq(editions[1].description, "Book blurb.")
    a.eq(editions[1].genres[1], "Science Fiction")
    a.eq(editions[2].description, "Book blurb.")
    local m = Hardcover.extract(editions[2])
    a.eq(m.series, "Dune")
    a.eq(m.series_index, 1)
    a.eq(m.authors[1], "Frank Herbert")
end

T["list_editions reads the year out of the release date"] = function(a)
    local api = FakeApi.new({ editions = { { id = 1, release_date = "2010-09-14" }, { id = 2 } } })
    local editions = Hardcover.list_editions(api, { book_id = 7 })
    a.eq(editions[1].release_year, "2010")
    a.eq(editions[2].release_year, nil)
end

T["list_editions names the format when the edition does not"] = function(a)
    local api = FakeApi.new({
        editions = {
            { id = 1, edition_format = "Mass Market Paperback", reading_format_id = 1 },
            { id = 2, edition_format = "", reading_format_id = 4 },
            { id = 3, reading_format_id = 1 },
            { id = 4 },
        },
    })
    local editions = Hardcover.list_editions(api, { book_id = 7 })
    a.eq(editions[1].edition_format, "Mass Market Paperback")
    a.eq(editions[2].edition_format, "E-Book")
    a.eq(editions[3].edition_format, "Physical Book")
    a.eq(editions[4].edition_format, nil)
end

T["list_editions falls back to the book title when an edition has none"] = function(a)
    local api = FakeApi.new({ editions = { { id = 1 }, { id = 2, title = "Aprendiz de asesino" } } })
    local editions = Hardcover.list_editions(api, { book_id = 7, title = "Assassin's Apprentice" })
    a.eq(editions[1].title, "Assassin's Apprentice")
    a.eq(editions[2].title, "Aprendiz de asesino")
end

T["list_editions is empty when the Hardcover plugin cannot list editions"] = function(a)
    local editions, truncated = Hardcover.list_editions({}, { book_id = 7 })
    a.eq(#editions, 0)
    a.eq(truncated, false)
end

T["list_editions is empty without a book id"] = function(a)
    local api = FakeApi.new({ editions = { { id = 1 } } })
    a.eq(#Hardcover.list_editions(api, { title = "No id" }), 0)
    a.eq(api.calls.editions_query, nil)
end

T["list_editions survives an API error"] = function(a)
    local api = FakeApi.new({ editions_error = "boom" })
    local editions = Hardcover.list_editions(api, { book_id = 7 })
    a.eq(#editions, 0)
end

T["list_editions caps the list and reports the truncation"] = function(a)
    local many = {}
    for i = 1, 42 do
        many[i] = { id = i }
    end
    local api = FakeApi.new({ editions = many })
    local editions, truncated = Hardcover.list_editions(api, { book_id = 7 })
    a.eq(#editions, 30)
    a.eq(truncated, true)
end

T["list_editions reports no truncation when the book has exactly the cap"] = function(a)
    local exactly = {}
    for i = 1, 30 do
        exactly[i] = { id = i }
    end
    local api = FakeApi.new({ editions = exactly })
    local editions, truncated = Hardcover.list_editions(api, { book_id = 7 })
    a.eq(#editions, 30)
    a.eq(truncated, false)
end

T["lookup attaches descriptions to ISBN matches"] = function(a)
    Hardcover._user_id = nil
    local book = { book_id = 7, title = "Dune", contributions = {}, book_series = {} }
    local api = FakeApi.new({ by_isbn = book, descriptions = { [7] = "Spice." } })
    local results = Hardcover.lookup(api, { isbn_13 = "9780441013593", title = "Dune" })
    a.eq(results[1].description, "Spice.")
    a.eq(api.calls.query.parameters.ids[1], 7)
end

T["lookup attaches genres to ISBN matches"] = function(a)
    Hardcover._user_id = nil
    local book = { book_id = 7, title = "Dune", contributions = {}, book_series = {} }
    local api = FakeApi.new({
        by_isbn = book,
        genres = { [7] = { { tag = "Science Fiction" }, { tag = "Adventure" } } },
    })
    local results = Hardcover.lookup(api, { isbn_13 = "9780441013593", title = "Dune" })
    a.eq(results[1].genres[1], "Science Fiction")
    a.eq(results[1].genres[2], "Adventure")
end

T["lookup attaches descriptions to every search result"] = function(a)
    Hardcover._user_id = nil
    local api = FakeApi.new({
        by_search = { { book_id = 1, title = "A" }, { book_id = 2, title = "B" } },
        descriptions = { [2] = "Only the second." },
    })
    local results = Hardcover.lookup(api, { title = "A" })
    a.eq(results[1].description, nil)
    a.eq(results[2].description, "Only the second.")
end

T["attach_details caps genres at five per book"] = function(a)
    local tags = {}
    for i = 1, 9 do
        tags[i] = { tag = "G" .. i }
    end
    local api = FakeApi.new({ genres = { [5] = tags } })
    local books = Hardcover.attach_details(api, { { book_id = 5, title = "E" } })
    a.eq(#books[1].genres, 5)
    a.eq(books[1].genres[1], "G1")
end

T["attach_details leaves results intact when the query fails"] = function(a)
    local api = FakeApi.new({ query_error = "boom" })
    local books = Hardcover.attach_details(api, { { book_id = 3, title = "C" } })
    a.eq(#books, 1)
    a.eq(books[1].description, nil)
    a.eq(books[1].genres, nil)
end

T["attach_details skips the query when there is nothing to fetch"] = function(a)
    local api = FakeApi.new({ descriptions = { [4] = "Unused." } })
    Hardcover.attach_details(api, { { book_id = 4, description = "Already here.", genres = {} } })
    a.eq(api.calls.query, nil)
end

T["lookup uses ISBN when available"] = function(a)
    Hardcover._user_id = nil
    local book = { book_id = 7, title = "Dune", contributions = {}, book_series = {} }
    local api = FakeApi.new({ by_isbn = book })
    local results, source = Hardcover.lookup(api, { isbn_13 = "9780441013593", title = "Dune" })
    a.eq(source, "isbn")
    a.eq(#results, 1)
    a.eq(results[1].book_id, 7)
    a.eq(api.calls.by_identifiers.isbn_13, "9780441013593")
    a.eq(api.calls.isbn_user_id, 42)
end

T["lookup falls back to title and author search"] = function(a)
    Hardcover._user_id = nil
    local api = FakeApi.new({ by_search = { { book_id = 1, title = "A" }, { book_id = 2, title = "B" } } })
    local results, source = Hardcover.lookup(api, { title = "A", authors = { "Writer" } })
    a.eq(source, "search")
    a.eq(#results, 2)
    a.eq(api.calls.find_books.title, "A")
    a.eq(api.calls.find_books.author, "Writer")
end

T["lookup falls through to search when the ISBN misses"] = function(a)
    Hardcover._user_id = nil
    local api = FakeApi.new({ by_isbn = nil, by_search = { { book_id = 9, title = "Z" } } })
    local results, source = Hardcover.lookup(api, { isbn_13 = "0000000000000", title = "Z" })
    a.eq(source, "search")
    a.eq(#results, 1)
    a.eq(results[1].book_id, 9)
end

T["available is false when the Hardcover plugin is not installed"] = function(a)
    a.eq(Hardcover.available(), false)
end

return T
