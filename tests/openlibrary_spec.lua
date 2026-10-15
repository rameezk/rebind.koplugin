local Http = require("rebind/http")
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

T["the newest ebook wins when the language is unknown"] = function(a)
    local provider = setup({
        { when = "title=Harry", file = "search_harry_potter.json" },
        { when = "key:\"/works/OL82563W\"", file = "editions_mixed.json" },
    })
    local match = first_match(provider, { title = "Harry Potter and the Philosopher's Stone" })
    a.eq(provider:pick_edition(match, nil).edition_id, "OL59004869M")
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

return T
