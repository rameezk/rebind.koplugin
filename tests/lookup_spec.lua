local Lookup = require("rebind/lookup")
local HardcoverProvider = require("rebind/providers/hardcover")
local Hardcover = require("rebind/hardcover")
local FakeApi = require("tests/support/fake_api")

local T = {}

local function chain_of(api)
    return { HardcoverProvider.new(api) }
end

T["lookup goes through the chain and names Hardcover as the provider"] = function(a)
    Hardcover._user_id = nil
    local api = FakeApi.new({
        by_isbn = { book_id = 7, title = "Dune", contributions = { { author = { name = "Frank Herbert" } } } },
    })
    local result = Lookup.find(chain_of(api), { isbn_13 = "9780441013593", title = "Dune" })
    a.eq(result.method, "isbn")
    a.eq(#result.matches, 1)
    local match = result.matches[1]
    a.eq(match.title, "Dune")
    a.eq(match.authors[1], "Frank Herbert")
    a.eq(match.provider_id, "hardcover")
    a.eq(match.provider_name, "Hardcover")
    a.eq(result.provider.name, "Hardcover")
end

T["a match has editions when the provider can list them"] = function(a)
    Hardcover._user_id = nil
    local api = FakeApi.new({ by_isbn = { book_id = 7, title = "Dune" } })
    local result = Lookup.find(chain_of(api), { isbn_13 = "9780441013593" })
    a.eq(result.matches[1].has_editions, true)
end

T["editions come back in the neutral shape and only in the asked language"] = function(a)
    Hardcover._user_id = nil
    local api = FakeApi.new({
        by_isbn = { book_id = 7, title = "Dune" },
        editions = {
            { id = 1, title = "Dune", language = { code2 = "en" }, publisher = { name = "Ace" } },
            { id = 2, title = "Der Wüstenplanet", language = { code2 = "de" }, publisher = { name = "Heyne" } },
        },
    })
    local chain = chain_of(api)
    local match = Lookup.find(chain, { isbn_13 = "9780441013593" }).matches[1]
    local editions = chain[1]:editions(match, "de")
    a.eq(#editions, 1)
    a.eq(editions[1].title, "Der Wüstenplanet")
    a.eq(editions[1].language, "de")
    a.eq(editions[1].publisher, "Heyne")
    a.eq(editions[1].provider_id, "hardcover")
    a.eq(editions[1].book_id, nil)
end

T["editions of every language come back when none is asked for"] = function(a)
    Hardcover._user_id = nil
    local api = FakeApi.new({
        by_isbn = { book_id = 7, title = "Dune" },
        editions = {
            { id = 1, language = { code2 = "en" } },
            { id = 2, language = { code2 = "de" } },
        },
    })
    local chain = chain_of(api)
    local match = Lookup.find(chain, { isbn_13 = "9780441013593" }).matches[1]
    local editions, truncated = chain[1]:editions(match)
    a.eq(#editions, 2)
    a.eq(truncated, false)
end

T["the automatic edition pick follows ADR-0012"] = function(a)
    Hardcover._user_id = nil
    local api = FakeApi.new({
        by_search = { { book_id = 7, title = "Dune" } },
        defaults = {
            ebook = { id = 11, edition_format = "Kindle", language = { code2 = "de" } },
            physical = { id = 12, edition_format = "Hardcover", language = { code2 = "en" } },
        },
        editions = { { id = 13, language = { code2 = "en" } } },
    })
    local chain = chain_of(api)
    local match = Lookup.find(chain, { title = "Dune" }).matches[1]
    local edition = chain[1]:pick_edition(match, "en")
    a.eq(edition.edition_id, 12)
    a.eq(edition.provider_id, "hardcover")
    a.eq(edition.is_edition, true)
end

T["no automatic pick when the match has no editions to look at"] = function(a)
    Hardcover._user_id = nil
    local api = FakeApi.new({ by_search = { { book_id = 7, title = "Dune" } } })
    local chain = chain_of(api)
    local match = Lookup.find(chain, { title = "Dune" }).matches[1]
    a.eq(chain[1]:pick_edition(match, "en"), nil)
end

T["search results all name the provider"] = function(a)
    Hardcover._user_id = nil
    local api = FakeApi.new({ by_search = { { book_id = 1, title = "A" }, { book_id = 2, title = "B" } } })
    local result = Lookup.find(chain_of(api), { title = "A", authors = { "Writer" } })
    a.eq(result.method, "search")
    a.eq(#result.matches, 2)
    a.eq(result.matches[2].provider_name, "Hardcover")
    a.eq(api.calls.find_books.author, "Writer")
end

T["no matches comes back empty"] = function(a)
    Hardcover._user_id = nil
    local result = Lookup.find(chain_of(FakeApi.new({})), { title = "Nothing" })
    a.eq(#result.matches, 0)
    a.eq(result.provider, nil)
end

T["an empty chain makes no lookup"] = function(a)
    local result = Lookup.find({}, { title = "Dune" })
    a.eq(#result.matches, 0)
    a.eq(result.provider, nil)
end

T["the provider that made a match is found again from the match"] = function(a)
    Hardcover._user_id = nil
    local api = FakeApi.new({ by_isbn = { book_id = 7, title = "Dune" } })
    local chain = chain_of(api)
    local match = Lookup.find(chain, { isbn_13 = "9780441013593" }).matches[1]
    a.eq(Lookup.provider_for(chain, match), chain[1])
    a.eq(Lookup.provider_for(chain, { provider_id = "other" }), nil)
    a.eq(Lookup.provider_for(nil, match), nil)
end

return T
