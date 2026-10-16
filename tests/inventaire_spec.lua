local Http = require("rebind/http")
local Lookup = require("rebind/lookup")
local Inventaire = require("rebind/providers/inventaire")
local FakeTransport = require("tests/support/fake_transport")

local T = {}

local CUREE_ISBN = "9782218958847"

local WORKS_CUREE = "attributes=claims|labels&uris=wd:Q962265|wd:Q3208037"
local WORKS_PASCAL = "attributes=claims|labels&uris=wd:Q663632|"

local function setup(routes)
    local transport = FakeTransport.new(routes, "inventaire")
    local sleeps = {}
    local http = Http.new{
        transport = transport:fn(),
        sleep = function(seconds)
            sleeps[#sleeps + 1] = seconds
        end,
        version = "2.1.0",
    }
    return Inventaire.new(http), transport, sleeps
end

local function lookup(provider, meta)
    return Lookup.find({ provider }, meta)
end

local function curee_routes()
    return {
        { when = "api/search", file = "search_curee.json" },
        { when = WORKS_CUREE, file = "works_curee.json" },
        { when = "attributes=labels&uris=", file = "labels_curee.json" },
    }
end

T["a title search returns each work as a book with its series and genres"] = function(a)
    local provider, transport = setup(curee_routes())
    local result = lookup(provider, { title = "La Curée", authors = { "Émile Zola" }, language = "fr" })
    a.eq(result.method, "search")
    a.eq(result.provider.id, "inventaire")
    a.eq(#result.matches, 5)
    local match = result.matches[1]
    a.eq(match.provider_id, "inventaire")
    a.eq(match.provider_name, "Inventaire")
    a.eq(match.title, "La Curée")
    a.eq(match.authors[1], "Émile Zola")
    a.eq(match.series, "Les Rougon-Macquart")
    a.eq(match.series_index, 2)
    a.eq(table.concat(match.genres, "|"), "naturalisme")
    a.eq(match.first_published, "1871")
    a.eq(match.is_edition, false)
    a.eq(match.has_editions, true)
    a.eq(match.edition_id, nil)
    a.contains(transport.calls[1].decoded, "search=La Curée")
    a.contains(transport.calls[1].decoded, "types=works")
    a.contains(transport.calls[1].decoded, "lang=fr")
    a.eq(#transport.calls, 3)
end

local function isbn_routes()
    return {
        { when = "uris=isbn:" .. CUREE_ISBN, file = "isbn_curee.json" },
        { when = "attributes=claims|labels&uris=wd:Q962265", file = "work_curee.json" },
        { when = "attributes=labels&uris=", file = "labels_curee_isbn.json" },
        { when = "attributes=claims&uris=wd:Q150", file = "languages_curee.json" },
    }
end

T["an isbn the catalogue knows returns that edition with its book's fields"] = function(a)
    local provider, transport = setup(isbn_routes())
    local result = lookup(provider, { isbn_13 = CUREE_ISBN, title = "La Curée" })
    a.eq(result.method, "isbn")
    a.eq(#result.matches, 1)
    local match = result.matches[1]
    a.eq(match.provider_id, "inventaire")
    a.eq(match.by_isbn, true)
    a.eq(match.is_edition, true)
    a.eq(match.has_editions, true)
    a.eq(match.edition_id, "inv:fee7944f22dfef2a2cf0e48e43bce761")
    a.eq(match.title, "La curée")
    a.eq(match.authors[1], "Émile Zola")
    a.eq(match.publisher, "Hatier")
    a.eq(match.language, "fr")
    a.eq(match.release_year, "2011")
    a.eq(match.first_published, "1871")
    a.eq(match.series, "Les Rougon-Macquart")
    a.eq(match.series_index, 2)
    a.contains(transport.calls[1].decoded, "uris=isbn:" .. CUREE_ISBN)
end

T["an isbn the catalogue does not know falls back to the title search"] = function(a)
    local routes = curee_routes()
    table.insert(routes, 1, { when = "uris=isbn:", file = "isbn_unknown.json" })
    local provider = setup(routes)
    local result = lookup(provider, { isbn_13 = "9781402894626", title = "La Curée" })
    a.eq(result.method, "search")
    a.eq(#result.matches, 5)
end

local function edition_routes()
    local routes = {
        { when = "reverse-claims", file = "editions_uris_curee.json" },
        { when = "attributes=claims&uris=wd:Q56611488", file = "editions_curee.json" },
        { when = "attributes=claims&uris=wd:Q1860", file = "languages_curee.json" },
        { when = "attributes=labels&uris=wd:Q3128309", file = "publishers_curee_fr.json" },
        { when = "attributes=labels&uris=wd:Q1629027", file = "publishers_curee_fr.json" },
        { when = "attributes=labels&uris=wd:Q217595", file = "publishers_curee_en.json" },
    }
    for _i, route in ipairs(curee_routes()) do
        routes[#routes + 1] = route
    end
    return routes
end

local function curee_book(provider)
    return lookup(provider, { title = "La Curée", language = "fr" }).matches[1]
end

T["a book with french and english editions gets a french edition when the language is french"] = function(a)
    local provider, transport = setup(edition_routes())
    local edition = provider:pick_edition(curee_book(provider), "fr")
    a.eq(edition.is_edition, true)
    a.eq(edition.edition_id, "inv:fee7944f22dfef2a2cf0e48e43bce761")
    a.eq(edition.language, "fr")
    a.eq(edition.title, "La curée")
    a.eq(edition.publisher, "Hatier")
    a.eq(edition.release_year, "2011")
    a.eq(edition.provider_id, "inventaire")
    a.eq(edition.authors[1], "Émile Zola")
    a.eq(edition.series, "Les Rougon-Macquart")
    a.eq(edition.first_published, "1871")
    a.contains(transport.calls[4].decoded, "property=wdt:P629")
    a.contains(transport.calls[4].decoded, "value=wd:Q962265")
end

T["the same book gets its english edition when the language is english"] = function(a)
    local provider = setup(edition_routes())
    local edition = provider:pick_edition(curee_book(provider), "en")
    a.eq(edition.edition_id, "inv:d8d791d9c14649d2d687990a3efb212b")
    a.eq(edition.language, "en")
    a.eq(edition.publisher, "Oxford University Press")
end

local function pascal_routes()
    return {
        { when = "api/search", file = "search_pascal.json" },
        { when = WORKS_PASCAL, file = "works_pascal.json" },
        { when = "attributes=labels&uris=", file = "labels_pascal.json" },
        { when = "reverse-claims", file = "editions_uris_pascal.json" },
        { when = "attributes=claims&uris=wd:Q42396857", file = "editions_pascal.json" },
        { when = "attributes=claims&uris=wd:Q150", file = "languages_pascal.json" },
    }
end

T["a book whose editions are all french gets no edition when the language is english"] = function(a)
    local provider = setup(pascal_routes())
    local match = lookup(provider, { title = "Le Docteur Pascal", language = "en" }).matches[1]
    a.eq(match.title, "Doctor Pascal")
    a.eq(match.has_editions, true)
    a.eq(provider:pick_edition(match, "en"), nil)
    a.eq(provider:pick_edition(match, "fr").language, "fr")
end

T["results by the searched author come first and the rest keep their order"] = function(a)
    local provider = setup(curee_routes())
    local result = lookup(provider, { title = "La Curée", authors = { "bruno masure" }, language = "fr" })
    a.eq(result.matches[1].authors[1], "Bruno Masure")
    a.eq(result.matches[2].title, "La Curée")
    a.eq(result.matches[3].title, "La Curée des astres")
end

T["editions are listed in the neutral shape and only in the asked language"] = function(a)
    local provider = setup(edition_routes())
    local match = curee_book(provider)
    local french, truncated = provider:editions(match, "fr")
    a.eq(#french, 18)
    a.eq(truncated, false)
    a.eq(french[1].is_edition, true)
    a.eq(french[1].language, "fr")
    local english = provider:editions(match, "en")
    a.eq(#english, 2)
    a.eq(#provider:editions(match), 21)
end

T["no language and a language that is not a code both pick nothing without asking"] = function(a)
    local provider, transport = setup(edition_routes())
    local match = curee_book(provider)
    local calls = #transport.calls
    a.eq(provider:pick_edition(match, nil), nil)
    a.eq(provider:pick_edition(match, "x)"), nil)
    a.eq(#provider:editions(match, "x)"), 0)
    a.eq(#transport.calls, calls)
end

T["a work uri that is not a work uri is never put into a request"] = function(a)
    local provider, transport = setup({})
    local forged = { ref = { work_uri = "wd:Q1|inv:abc&value=x" } }
    a.eq(provider:pick_edition(forged, "fr"), nil)
    a.eq(#provider:editions(forged, "fr"), 0)
    a.eq(#transport.calls, 0)
end

T["a title that is empty asks nothing"] = function(a)
    local provider, transport = setup({})
    a.eq(#lookup(provider, { title = "" }).matches, 0)
    a.eq(#transport.calls, 0)
end

T["nothing found comes back as no match"] = function(a)
    local provider = setup({ { when = "api/search", body = '{"results":[],"total":0}' } })
    a.eq(#lookup(provider, { title = "Zzqxjv Nonexistent Volume" }).matches, 0)
end

T["every request carries the user agent"] = function(a)
    local provider, transport = setup(edition_routes())
    provider:pick_edition(curee_book(provider), "fr")
    a.is_true(#transport.calls > 4)
    for _i, call in ipairs(transport.calls) do
        a.eq(call.headers["User-Agent"], "Rebind/2.1.0 (https://github.com/rameezk/rebind.koplugin)")
    end
end

T["a 429 once is waited out and the match is still returned"] = function(a)
    local provider, transport, sleeps = setup({
        { when = "api/search", responses = {
            { status = 429, headers = { ["retry-after"] = "3" } },
            { file = "search_curee.json" },
        } },
        { when = WORKS_CUREE, file = "works_curee.json" },
        { when = "attributes=labels&uris=", file = "labels_curee.json" },
    })
    local result = lookup(provider, { title = "La Curée" })
    a.eq(#result.matches, 5)
    a.eq(sleeps[1], 3)
    a.eq(#transport.calls, 4)
end

T["a failing request raises so the chain can skip the provider"] = function(a)
    local provider = setup({})
    local result = lookup(provider, { title = "La Curée" })
    a.eq(#result.matches, 0)
    a.eq(result.skipped[1].provider.id, "inventaire")
    a.eq(Lookup.all_failed(result), true)
    local ok = pcall(provider.pick_edition, provider, { ref = { work_uri = "wd:Q962265" } }, "fr")
    a.eq(ok, false)
end

T["picking an edition only asks for the publisher of the edition it picked"] = function(a)
    local provider, transport = setup(edition_routes())
    local edition = provider:pick_edition(curee_book(provider), "fr")
    a.eq(edition.publisher, "Hatier")
    for _i, call in ipairs(transport.calls) do
        a.is_true(not call.decoded:find("Q1629027", 1, true), "asked for a publisher of an edition it did not pick")
    end
end

T["a language the catalogue could not return is asked for once"] = function(a)
    local routes = edition_routes()
    table.insert(routes, 1, { when = "attributes=claims&uris=wd:Q1860", body = '{"entities":{}}' })
    local provider, transport = setup(routes)
    local match = curee_book(provider)
    a.eq(provider:pick_edition(match, "fr"), nil)
    a.eq(provider:pick_edition(match, "fr"), nil)
    local asked = 0
    for _i, call in ipairs(transport.calls) do
        if call.decoded:find("attributes=claims&uris=wd:Q1860", 1, true) then
            asked = asked + 1
        end
    end
    a.eq(asked, 1)
end

T["an isbn answer keyed by something that is not an entity uri is ignored"] = function(a)
    local routes = curee_routes()
    table.insert(routes, 1, {
        when = "uris=isbn:",
        body = '{"entities":{"x|y":{"claims":{"wdt:P629":["wd:Q962265"]}}}}',
    })
    local provider = setup(routes)
    local result = lookup(provider, { isbn_13 = CUREE_ISBN, title = "La Curée" })
    a.eq(result.method, "search")
    a.eq(#result.matches, 5)
end

T["an entity that is not an object is ignored instead of failing the lookup"] = function(a)
    local routes = edition_routes()
    table.insert(routes, 1, { when = "attributes=claims&uris=wd:Q56611488", body = '{"entities":{"wd:Q56611488":"x"}}' })
    local provider = setup(routes)
    local ok, edition = pcall(provider.pick_edition, provider, curee_book(provider), "fr")
    a.eq(ok, true)
    a.eq(edition, nil)
end

return T
