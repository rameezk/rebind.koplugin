local HardcoverProvider = require("rebind/providers/hardcover")
local OpenLibraryProvider = require("rebind/providers/openlibrary")

local Providers = {}

Providers.DEFAULT_IDS = { "hardcover", "openlibrary" }

local function build_one(id, env)
    if id == "hardcover" then
        return HardcoverProvider.new(env.hardcover_api)
    elseif id == "openlibrary" then
        return OpenLibraryProvider.new(env.http)
    end
    return nil
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
