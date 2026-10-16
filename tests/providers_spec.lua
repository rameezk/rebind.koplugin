local Providers = require("rebind/providers")

local T = {}

local function ids_of(chain)
    local ids = {}
    for _i, provider in ipairs(chain) do
        ids[#ids + 1] = provider.id
    end
    return table.concat(ids, ",")
end

T["a fresh install or an upgrade starts with hardcover then open library"] = function(a)
    a.eq(table.concat(Providers.enabled_ids(nil), ","), "hardcover,openlibrary")
end

T["the stored order is kept and unknown providers are dropped"] = function(a)
    a.eq(table.concat(Providers.enabled_ids({ "openlibrary", "nope", "hardcover", "openlibrary" }), ","),
        "openlibrary,hardcover")
end

T["a stored empty list stays empty"] = function(a)
    a.eq(#Providers.enabled_ids({}), 0)
end

T["the chain is built in the stored order and hardcover is not ready without its plugin"] = function(a)
    local chain = Providers.build({ "openlibrary", "hardcover" }, { http = {}, hardcover_api = nil })
    a.eq(ids_of(chain), "openlibrary,hardcover")
    a.eq(chain[1]:ready(), true)
    a.eq(chain[2]:ready(), false)
    local with_plugin = Providers.build({ "hardcover" }, { http = {}, hardcover_api = {} })
    a.eq(with_plugin[1]:ready(), true)
end

return T
