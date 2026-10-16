local HardcoverProvider = require("rebind/providers/hardcover")
local OpenLibraryProvider = require("rebind/providers/openlibrary")

local Providers = {}

local REGISTRY = {
    hardcover = function(env)
        return HardcoverProvider.new(env.hardcover_api)
    end,
    openlibrary = function(env)
        return OpenLibraryProvider.new(env.http)
    end,
}

Providers.KNOWN_IDS = { "hardcover", "openlibrary" }
Providers.DEFAULT_IDS = { "hardcover", "openlibrary" }

local function build_one(id, env)
    local new = REGISTRY[id]
    return new and new(env) or nil
end

function Providers.enabled_ids(stored)
    if type(stored) ~= "table" then
        return Providers.enabled_ids(Providers.DEFAULT_IDS)
    end
    local ids, seen = {}, {}
    for _i, id in ipairs(stored) do
        if build_one(id, {}) and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    return ids
end

function Providers.build(ids, env)
    local chain = {}
    for _i, id in ipairs(ids) do
        chain[#chain + 1] = build_one(id, env)
    end
    return chain
end

return Providers
