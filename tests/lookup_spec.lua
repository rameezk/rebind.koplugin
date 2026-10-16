local Http = require("rebind/http")
local Lookup = require("rebind/lookup")
local HardcoverProvider = require("rebind/providers/hardcover")
local OpenLibraryProvider = require("rebind/providers/openlibrary")
local InventaireProvider = require("rebind/providers/inventaire")
local PickerState = require("rebind/picker_state")
local Hardcover = require("rebind/hardcover")
local FakeApi = require("tests/support/fake_api")
local FakeTransport = require("tests/support/fake_transport")

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

local function open_library(routes)
    local transport = FakeTransport.new(routes)
    local http = Http.new{ transport = transport:fn(), sleep = function() end, version = "2.1.0" }
    return OpenLibraryProvider.new(http), transport
end

local DUNE_ROUTES = {
    { when = "isbn:", file = "isbn_dune.json" },
    { when = "title=", file = "search_dune.json" },
}

T["the first provider with a match wins and later providers are not called"] = function(a)
    Hardcover._user_id = nil
    local api = FakeApi.new({ by_isbn = { book_id = 7, title = "Dune" } })
    local ol, transport = open_library(DUNE_ROUTES)
    local result = Lookup.find({ HardcoverProvider.new(api), ol }, { isbn_13 = "9780441013593", title = "Dune" })
    a.eq(result.provider.id, "hardcover")
    a.eq(#transport.calls, 0)
    a.eq(#result.skipped, 0)
end

T["a provider with no match hands over to the next one"] = function(a)
    Hardcover._user_id = nil
    local ol = open_library(DUNE_ROUTES)
    local result = Lookup.find({ HardcoverProvider.new(FakeApi.new({})), ol }, { title = "Dune" })
    a.eq(result.provider.id, "openlibrary")
    a.eq(result.matches[1].provider_name, "Open Library")
    a.eq(#result.skipped, 0)
end

local function inventaire(routes)
    local transport = FakeTransport.new(routes, "inventaire")
    local http = Http.new{ transport = transport:fn(), sleep = function() end, version = "2.1.0" }
    return InventaireProvider.new(http), transport
end

local CURSEE_ROUTES = {
    { when = "api/search", file = "search_curee.json" },
    { when = "attributes=claims|labels&uris=wd:Q962265", file = "works_curee.json" },
    { when = "attributes=labels&uris=", file = "labels_curee.json" },
}

T["a french book neither hardcover nor open library has is matched in inventaire"] = function(a)
    Hardcover._user_id = nil
    local ol = open_library({ { when = "title=", file = "search_none.json" } })
    local chain = { HardcoverProvider.new(FakeApi.new({})), ol, (inventaire(CURSEE_ROUTES)) }
    local result = Lookup.find(chain, { title = "La Curée", language = "fr" })
    a.eq(result.provider.id, "inventaire")
    a.eq(result.matches[1].title, "La Curée")
    a.eq(#result.skipped, 0)
    a.eq(#result.tried, 3)
    local state = PickerState.new({}, result.matches[1].provider_name)
    a.eq(state:provider_label(), "Inventaire values")
end

T["a provider that is not set up is skipped and reported"] = function(a)
    local ol = open_library(DUNE_ROUTES)
    local result = Lookup.find({ HardcoverProvider.new(nil), ol }, { title = "Dune" })
    a.eq(result.provider.id, "openlibrary")
    a.eq(#result.skipped, 1)
    a.eq(result.skipped[1].provider.id, "hardcover")
    a.eq(Lookup.skipped_text(result), "Hardcover was skipped: Hardcover plugin not installed")
end

T["a provider that fails at lookup time is skipped and reported"] = function(a)
    Hardcover._user_id = nil
    local api = FakeApi.new({})
    api.me = function()
        error("token rejected")
    end
    local ol = open_library(DUNE_ROUTES)
    local result = Lookup.find({ HardcoverProvider.new(api), ol }, { title = "Dune" })
    a.eq(result.provider.id, "openlibrary")
    a.eq(result.skipped[1].provider.id, "hardcover")
    a.eq(Lookup.skipped_text(result), "Hardcover was skipped: lookup failed")
end

T["nothing found names every provider that was tried"] = function(a)
    Hardcover._user_id = nil
    local ol = open_library({ { when = "title=", file = "search_none.json" } })
    local result = Lookup.find({ HardcoverProvider.new(FakeApi.new({})), ol }, { title = "Zzqxjv" })
    a.eq(#result.matches, 0)
    a.eq(Lookup.not_found_text(result), "Not found on Hardcover or Open Library")
end

T["nothing found also says which providers were skipped"] = function(a)
    local ol = open_library({ { when = "title=", file = "search_none.json" } })
    local result = Lookup.find({ HardcoverProvider.new(nil), ol }, { title = "Zzqxjv" })
    a.eq(Lookup.not_found_text(result),
        "Not found on Open Library\n\nHardcover was skipped: Hardcover plugin not installed")
end

T["every provider failing is told apart from nothing being found"] = function(a)
    Hardcover._user_id = nil
    local api = FakeApi.new({})
    api.me = function()
        error("no network")
    end
    local down = open_library({ { when = "title=", status = 503 } })
    local failed = Lookup.find({ HardcoverProvider.new(api), down }, { title = "Dune" })
    a.eq(Lookup.all_failed(failed), true)

    local none = open_library({ { when = "title=", file = "search_none.json" } })
    local unset = Lookup.find({ HardcoverProvider.new(nil), none }, { title = "Dune" })
    a.eq(Lookup.all_failed(unset), false)
end

T["an edition is picked in the current language, then the preferred one"] = function(a)
    local ol = open_library({
        { when = "title=Harry", file = "search_harry_potter.json" },
        { when = "language:jpn", file = "edition_jpn_none.json" },
        { when = "key:\"/works/OL82563W\"", file = "editions_mixed.json" },
    })
    local match = Lookup.find({ ol }, { title = "Harry Potter and the Philosopher's Stone" }).matches[1]
    a.eq(Lookup.pick_edition(ol, match, "ja", "de").edition_id, "OL47682314M")
    a.eq(Lookup.pick_edition(ol, match, "en", "de").edition_id, "OL59004869M")
    a.eq(Lookup.pick_edition(ol, match, nil, "de").edition_id, "OL47682314M")
    a.eq(Lookup.pick_edition(ol, match, "ja", nil), nil)
    a.eq(Lookup.pick_edition(ol, match, nil, nil), nil)
end

T["a provider with default editions still picks one when no language is known"] = function(a)
    Hardcover._user_id = nil
    local api = FakeApi.new({
        by_search = { { book_id = 7, title = "Dune" } },
        defaults = { ebook = { id = 11, edition_format = "Kindle", language = { code2 = "de" } } },
    })
    local chain = chain_of(api)
    local match = Lookup.find(chain, { title = "Dune" }).matches[1]
    a.eq(Lookup.pick_edition(chain[1], match, nil, nil).edition_id, 11)
end

T["a provider with default editions follows the current language only"] = function(a)
    Hardcover._user_id = nil
    local api = FakeApi.new({
        by_search = { { book_id = 7, title = "Dune" } },
        defaults = {
            ebook = { id = 11, edition_format = "Kindle", language = { code2 = "de" } },
            physical = { id = 12, edition_format = "Hardcover", language = { code2 = "en" } },
        },
    })
    local chain = chain_of(api)
    local match = Lookup.find(chain, { title = "Dune" }).matches[1]
    a.eq(Lookup.pick_edition(chain[1], match, nil, "en").edition_id, 11)
    a.eq(Lookup.pick_edition(chain[1], match, "en", "de").edition_id, 12)
end

T["an empty chain says no lookup providers are enabled"] = function(a)
    local result = Lookup.find({}, { title = "Dune" })
    local text = Lookup.not_found_text(result)
    a.eq(text:match("^[^\n]+"), "No lookup providers enabled")
    a.is_true(text:find("Tools → Rebind → Lookup providers", 1, true), "points to the settings")
end

return T
