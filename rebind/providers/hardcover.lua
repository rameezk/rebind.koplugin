local Hardcover = require("rebind/hardcover")

local Provider = {}
Provider.__index = Provider

Provider.id = "hardcover"
Provider.name = "Hardcover"

function Provider.available()
    return Hardcover.available()
end

function Provider.new(api)
    return setmetatable({ api = api }, Provider)
end

function Provider:_neutral(raw)
    local m = Hardcover.extract(raw)
    m.provider_id = Provider.id
    m.provider_name = Provider.name
    m.has_editions = tonumber(raw.book_id) ~= nil
    m.is_edition = raw.is_edition == true
    m.book_id = nil
    m.ref = raw
    return m
end

function Provider:_neutral_list(rows)
    local out = {}
    for _i, raw in ipairs(rows or {}) do
        out[#out + 1] = self:_neutral(raw)
    end
    return out
end

function Provider:find(meta)
    local rows, method = Hardcover.lookup(self.api, meta)
    return self:_neutral_list(rows), method
end

function Provider:editions(match, language)
    if type(match) ~= "table" or type(match.ref) ~= "table" then
        return {}, false
    end
    local rows, truncated = Hardcover.list_editions(self.api, match.ref, language)
    return self:_neutral_list(rows), truncated
end

function Provider:pick_edition(match, language)
    if type(match) ~= "table" or type(match.ref) ~= "table" then
        return nil
    end
    local raw = Hardcover.pick_default_edition(self.api, match.ref, language)
    return raw and self:_neutral(raw) or nil
end

return Provider
