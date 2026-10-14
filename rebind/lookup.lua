local Lookup = {}

function Lookup.find(chain, meta)
    for _i, provider in ipairs(chain or {}) do
        local matches, method = provider:find(meta)
        if type(matches) == "table" and #matches > 0 then
            return { matches = matches, method = method, provider = provider }
        end
    end
    return { matches = {}, method = "search" }
end

function Lookup.provider_for(chain, match)
    if type(match) ~= "table" then
        return nil
    end
    for _i, provider in ipairs(chain or {}) do
        if provider.id == match.provider_id then
            return provider
        end
    end
    return nil
end

return Lookup
