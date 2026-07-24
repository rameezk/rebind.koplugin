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
