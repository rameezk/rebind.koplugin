local Cover = require("rebind/cover")
local Http = require("rebind/http")
local Images = require("tests/support/images")
local Lookup = require("rebind/lookup")
local OpenLibrary = require("rebind/providers/openlibrary")
local FakeTransport = require("tests/support/fake_transport")

local T = {}

local ISBN = "9780441013593"

local function setup(routes)
    local transport = FakeTransport.new(routes)
    local sleeps = {}
    local http = Http.new{
        transport = transport:fn(),
        sleep = function(seconds)
            sleeps[#sleeps + 1] = seconds
        end,
        version = "2.1.0",
    }
    return OpenLibrary.new(http), transport, sleeps
end

local function lookup(provider, meta)
    return Lookup.find({ provider }, meta)
end

T["an isbn the catalogue knows returns the matching edition without picking another"] = function(a)
    local provider, transport = setup({ { when = "isbn:" .. ISBN, file = "isbn_dune.json" } })
    local result = lookup(provider, { isbn_13 = ISBN, title = "Dune" })
    a.eq(result.method, "isbn")
    a.eq(#result.matches, 1)
    local match = result.matches[1]
    a.eq(match.provider_id, "openlibrary")
    a.eq(match.provider_name, "Open Library")
    a.eq(match.title, "Dune")
    a.eq(match.authors[1], "Frank Herbert")
    a.eq(match.edition_id, "OL17952222M")
    a.eq(match.is_edition, true)
    a.eq(match.publisher, "Ace Books")
    a.eq(match.language, "en")
    a.eq(match.first_published, "1965")
    a.eq(#transport.calls, 1)
end

T["without an isbn the title and author are searched and each result is a book"] = function(a)
    local provider, transport = setup({ { when = "title=Dune", file = "search_dune.json" } })
    local result = lookup(provider, { title = "Dune", authors = { "Frank Herbert" } })
    a.eq(result.method, "search")
    a.eq(#result.matches, 5)
    local match = result.matches[1]
    a.eq(match.title, "Dune")
    a.eq(match.edition_id, nil)
    a.eq(match.is_edition, false)
    a.eq(match.has_editions, true)
    a.eq(match.series, "Dune")
    a.eq(match.series_index, 1)
    a.contains(transport.calls[1].decoded, "author=Frank Herbert")
    a.eq(#transport.calls, 1)
end

T["an isbn the catalogue does not know falls back to the title search"] = function(a)
    local provider, transport = setup({
        { when = "isbn:", file = "search_none.json" },
        { when = "title=Dune", file = "search_dune.json" },
    })
    local result = lookup(provider, { isbn_13 = ISBN, title = "Dune" })
    a.eq(result.method, "search")
    a.eq(#result.matches, 5)
    a.eq(#transport.calls, 2)
end

T["nothing found comes back as no match"] = function(a)
    local provider = setup({ { when = "title=", file = "search_none.json" } })
    local result = lookup(provider, { title = "Zzqxjv Nonexistent Volume" })
    a.eq(#result.matches, 0)
end

T["every request carries the user agent"] = function(a)
    local provider, transport = setup({
        { when = "isbn:", file = "search_none.json" },
        { when = "title=Dune", file = "search_dune.json" },
    })
    lookup(provider, { isbn_13 = ISBN, title = "Dune" })
    a.eq(#transport.calls, 2)
    for _i, call in ipairs(transport.calls) do
        a.eq(call.headers["User-Agent"], "Rebind/2.1.0 (https://github.com/rameezk/rebind.koplugin)")
    end
end

T["a 429 once is waited out and the match is still returned"] = function(a)
    local provider, transport, sleeps = setup({
        { when = "isbn:" .. ISBN, responses = {
            { status = 429, headers = { ["retry-after"] = "2" } },
            { file = "isbn_dune.json" },
        } },
    })
    local result = lookup(provider, { isbn_13 = ISBN })
    a.eq(#result.matches, 1)
    a.eq(result.matches[1].title, "Dune")
    a.eq(#transport.calls, 2)
    a.eq(sleeps[1], 2)
end

local function first_match(provider, meta)
    return lookup(provider, meta).matches[1]
end

T["subjects are cleaned into at most five genuine genres"] = function(a)
    local provider = setup({ { when = "title=Harry", file = "search_harry_potter.json" } })
    local match = first_match(provider, { title = "Harry Potter and the Philosopher's Stone" })
    a.eq(table.concat(match.genres, "|"),
        "Ghosts|Monsters|Vampires|Witches|Challenges and Overcoming Obstacles")
end

T["places, people, machine tags and very long entries are dropped from genres"] = function(a)
    local body = [[{"numFound":1,"docs":[{
        "key":"/works/OL1W","title":"A Book",
        "place":["England"],"person":["Harry Potter"],"time":["Late 1990s"],
        "subject":["nyt:hardcover-fiction=2020-01-05","England","harry potter","Late 1990s",
            "Fantasy","Adventure","fantasy","Mystery","Thriller","Romance","Horror","Humour",
            "Dune (Imaginary place)","A subject so long that no catalogue would ever call it a genre"]
    }]}]]
    local provider = setup({ { when = "title=", body = body } })
    local match = first_match(provider, { title = "A Book" })
    a.eq(table.concat(match.genres, "|"), "Fantasy|Adventure|Mystery|Thriller|Romance")
end

T["a search match gets the english ebook over a paperback and a german ebook"] = function(a)
    local provider, transport = setup({
        { when = "title=Harry", file = "search_harry_potter.json" },
        { when = "key:\"/works/OL82563W\"", file = "editions_mixed.json" },
    })
    local match = first_match(provider, { title = "Harry Potter and the Philosopher's Stone" })
    a.eq(match.edition_id, nil)
    local edition = provider:pick_edition(match, "en")
    a.eq(edition.edition_id, "OL59004869M")
    a.eq(edition.is_edition, true)
    a.eq(edition.language, "en")
    a.eq(edition.publisher, "Bloomsbury")
    a.eq(edition.edition_format, "E-Book")
    a.eq(edition.provider_id, "openlibrary")
    a.eq(edition.authors[1], "J. K. Rowling")
    a.contains(transport.calls[2].decoded, "language:eng")
end

T["no edition is picked when the language is unknown"] = function(a)
    local provider, transport = setup({
        { when = "title=Harry", file = "search_harry_potter.json" },
        { when = "key:\"/works/OL82563W\"", file = "editions_mixed.json" },
    })
    local match = first_match(provider, { title = "Harry Potter and the Philosopher's Stone" })
    a.eq(provider:pick_edition(match, nil), nil)
    a.eq(#transport.calls, 1)
end

T["a language that is not a language code never reaches the query"] = function(a)
    local provider, transport = setup({
        { when = "title=Harry", file = "search_harry_potter.json" },
        { when = "key:\"/works/OL82563W\"", file = "editions_mixed.json" },
    })
    local match = first_match(provider, { title = "Harry Potter and the Philosopher's Stone" })
    a.eq(provider:pick_edition(match, "*"), nil)
    a.eq(#provider:editions(match, "x)"), 0)
    a.eq(#transport.calls, 1)
end

T["an isbn match is marked so no edition is picked over it"] = function(a)
    local body = '{"numFound":1,"docs":[{"key":"/works/OL1W","title":"A Book"}]}'
    local provider = setup({ { when = "isbn:", body = body } })
    local match = first_match(provider, { isbn_13 = ISBN })
    a.eq(match.by_isbn, true)
    a.eq(first_match(setup({ { when = "title=", file = "search_dune.json" } }), { title = "Dune" }).by_isbn, nil)
end

T["a genre is not dropped as too long just because its letters take several bytes"] = function(a)
    local body = '{"numFound":1,"docs":[{"key":"/works/OL1W","title":"A Book",'
        .. '"subject":["Научная фантастика и фэнтези"]}]}'
    local provider = setup({ { when = "title=", body = body } })
    a.eq(first_match(provider, { title = "A Book" }).genres[1], "Научная фантастика и фэнтези")
end

T["a work key that is not a work key is never put into a query"] = function(a)
    local body = '{"numFound":1,"docs":[{"key":"/works/OL1W\\" OR key:\\"x","title":"A Book"}]}'
    local provider, transport = setup({ { when = "title=", body = body } })
    local match = first_match(provider, { title = "A Book" })
    a.eq(match.has_editions, false)
    a.eq(provider:pick_edition(match, "en"), nil)
    a.eq(#provider:editions(match), 0)
    a.eq(#transport.calls, 1)
end

T["the language alone is searched again when no ebook comes back"] = function(a)
    local provider = setup({
        { when = "title=Harry", file = "search_harry_potter.json" },
        { when = "ebook_access:public", file = "edition_jpn_none.json" },
        { when = "language:en", file = "editions_mixed.json" },
    })
    local match = first_match(provider, { title = "Harry Potter and the Philosopher's Stone" })
    a.eq(provider:pick_edition(match, "en").edition_id, "OL59004869M")
end

T["no edition is picked when none is in the language"] = function(a)
    local provider = setup({
        { when = "title=Harry", file = "search_harry_potter.json" },
        { when = "key:\"/works/OL82563W\"", file = "edition_jpn_none.json" },
    })
    local match = first_match(provider, { title = "Harry Potter and the Philosopher's Stone" })
    a.eq(provider:pick_edition(match, "ja"), nil)
end

T["editions are listed in the neutral shape and only in the asked language"] = function(a)
    local provider = setup({
        { when = "title=Harry", file = "search_harry_potter.json" },
        { when = "key:\"/works/OL82563W\"", file = "editions_mixed.json" },
    })
    local match = first_match(provider, { title = "Harry Potter and the Philosopher's Stone" })
    local all = provider:editions(match)
    a.eq(#all, 3)
    local german = provider:editions(match, "de")
    a.eq(#german, 1)
    a.eq(german[1].title, "Harry Potter und der Stein der Weisen")
    a.eq(german[1].language, "de")
    a.eq(german[1].publisher, "Carlsen")
end

T["a failing request while picking an edition raises so the caller can fall back"] = function(a)
    local provider = setup({ { when = "title=Harry", file = "search_harry_potter.json" } })
    local match = first_match(provider, { title = "Harry Potter and the Philosopher's Stone" })
    local ok = pcall(provider.pick_edition, provider, match, "en")
    a.eq(ok, false)
end

local function cover_url(id)
    return "https://covers.openlibrary.org/b/id/" .. id .. "-L.jpg?default=false"
end

T["the search asks for the cover ids in the same request"] = function(a)
    local provider, transport = setup({ { when = "title=Dune", file = "search_dune.json" } })
    first_match(provider, { title = "Dune" })
    a.eq(#transport.calls, 1)
    a.contains(transport.calls[1].decoded, "cover_i")
    a.contains(transport.calls[1].decoded, "editions.cover_i")
end

T["a search match proposes the book's cover"] = function(a)
    local provider = setup({ { when = "title=Dune", file = "search_dune.json" } })
    a.eq(first_match(provider, { title = "Dune" }).cover.url, cover_url(11481354))
end

T["an edition cover is proposed before the book's"] = function(a)
    local provider = setup({ { when = "isbn:" .. ISBN, file = "isbn_dune.json" } })
    a.eq(first_match(provider, { isbn_13 = ISBN }).cover.url, cover_url(14856017))
end

T["an edition without a cover proposes the book's"] = function(a)
    local provider = setup({
        { when = "title=Harry", file = "search_harry_potter.json" },
        { when = "key:\"/works/OL82563W\"", file = "editions_mixed.json" },
    })
    local match = first_match(provider, { title = "Harry Potter and the Philosopher's Stone" })
    local by_id = {}
    for _i, edition in ipairs(provider:editions(match, nil)) do
        by_id[edition.edition_id] = edition
    end
    a.eq(by_id.OL59004869M.cover.url, cover_url(15159585))
    a.eq(by_id.OL8005728M.cover.url, cover_url(15155833))
end

T["a match with no cover id proposes no cover"] = function(a)
    local body = '{"numFound":1,"docs":[{"key":"/works/OL1W","title":"A Book"}]}'
    local provider = setup({ { when = "title=", body = body } })
    a.eq(first_match(provider, { title = "A Book" }).cover, nil)
end

T["a cover id that is not a plain number is not proposed"] = function(a)
    for _i, id in ipairs({ '"../x"', "1e30", "-5", "1.5" }) do
        local body = '{"numFound":1,"docs":[{"key":"/works/OL1W","title":"A Book","cover_i":' .. id .. '}]}'
        local provider = setup({ { when = "title=", body = body } })
        a.eq(first_match(provider, { title = "A Book" }).cover, nil)
    end
end

T["the proposed cover downloads and passes the filter"] = function(a)
    local provider, transport = setup({
        { when = "title=Dune", file = "search_dune.json" },
        { when = "covers.openlibrary.org/b/id/11481354-L.jpg", body = Images.jpeg(400, 600) },
    })
    local cover = Cover.fetch(provider.http, first_match(provider, { title = "Dune" }).cover)
    a.eq(cover.width, 400)
    a.eq(cover.url, cover_url(11481354))
    a.contains(transport.calls[2].decoded, "default=false")
end

T["no image for the cover id means no cover, not a placeholder"] = function(a)
    local provider = setup({
        { when = "title=Dune", file = "search_dune.json" },
        { when = "covers.openlibrary.org", status = 404 },
    })
    a.eq(Cover.fetch(provider.http, first_match(provider, { title = "Dune" }).cover), nil)
end

return T
