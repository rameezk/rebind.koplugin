local FakeApi = require("tests/support/fake_api")
local FakeTransport = require("tests/support/fake_transport")
local Http = require("rebind/http")
local Lookup = require("rebind/lookup")
local Providers = require("rebind/providers")
local ProviderSettings = require("rebind/provider_settings")

local T = {}

local function row_ids(rows)
    local ids = {}
    for _i, row in ipairs(rows) do
        ids[#ids + 1] = row.id
    end
    return table.concat(ids, ",")
end

local function row_for(rows, id)
    for _i, row in ipairs(rows) do
        if row.id == id then
            return row
        end
    end
end

T["enabled providers come first in the stored order, then the disabled ones"] = function(a)
    local rows = ProviderSettings.rows({ "openlibrary" }, { hardcover_api = {}, http = {} })
    a.eq(row_ids(rows), "openlibrary,hardcover")
    a.eq(rows[1].enabled, true)
    a.eq(rows[2].enabled, false)
end

T["a provider that is not set up cannot be enabled and says why"] = function(a)
    local rows = ProviderSettings.rows({ "openlibrary" }, { http = {} })
    local hardcover = row_for(rows, "hardcover")
    a.eq(hardcover.can_enable, false)
    a.eq(hardcover.reason, "Hardcover plugin not installed")
    a.eq(row_for(rows, "openlibrary").can_enable, true)
end

T["enabling a provider adds it to the end of the chain"] = function(a)
    local ids = ProviderSettings.set_enabled({ "openlibrary" }, "hardcover", true, { hardcover_api = {}, http = {} })
    a.eq(table.concat(ids, ","), "openlibrary,hardcover")
end

T["a provider that is not set up stays out of the chain when enabled"] = function(a)
    local ids = ProviderSettings.set_enabled({ "openlibrary" }, "hardcover", true, { http = {} })
    a.eq(table.concat(ids, ","), "openlibrary")
end

T["disabling a provider keeps the order of the others"] = function(a)
    local env = { hardcover_api = {}, http = {} }
    local ids = ProviderSettings.set_enabled({ "openlibrary", "hardcover" }, "openlibrary", false, env)
    a.eq(table.concat(ids, ","), "hardcover")
end

T["a disabled provider is not called when a book is looked up"] = function(a)
    local api = FakeApi.new({ by_isbn = { book_id = 7, title = "Dune" } })
    local transport = FakeTransport.new({ { when = "isbn:9780441013593", file = "isbn_dune.json" } })
    local env = { hardcover_api = api, http = Http.new{ transport = transport:fn(), version = "2.1.0" } }
    local ids = ProviderSettings.set_enabled({ "openlibrary", "hardcover" }, "hardcover", false, env)
    local result = Lookup.find(Providers.build(ids, env), { isbn_13 = "9780441013593", title = "Dune" })
    a.eq(result.provider.id, "openlibrary")
    a.eq(next(api.calls), nil)
end

T["moving open library above hardcover puts it first in the chain"] = function(a)
    local ids = ProviderSettings.reorder({ "hardcover", "openlibrary" }, { "openlibrary", "hardcover" })
    a.eq(table.concat(ids, ","), "openlibrary,hardcover")
    local env = { hardcover_api = {}, http = {} }
    a.eq(Providers.build(ids, env)[1].id, "openlibrary")
end

T["reordering never adds or drops an enabled provider"] = function(a)
    local ids = ProviderSettings.reorder({ "hardcover", "openlibrary" }, { "openlibrary", "nope" })
    a.eq(table.concat(ids, ","), "openlibrary,hardcover")
    local only = ProviderSettings.reorder({ "openlibrary" }, { "hardcover", "openlibrary" })
    a.eq(table.concat(only, ","), "openlibrary")
end

return T
