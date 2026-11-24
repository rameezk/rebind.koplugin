local _ = require("gettext")

local Lookup = {}

function Lookup.names(providers)
    local names = {}
    for _i, provider in ipairs(providers or {}) do
        names[#names + 1] = provider.name
    end
    if #names <= 1 then
        return names[1] or ""
    end
    local last = table.remove(names)
    return table.concat(names, ", ") .. _(" or ") .. last
end

local function skip(result, provider, reason, failed)
    result.skipped[#result.skipped + 1] = { provider = provider, reason = reason, failed = failed }
end

local MAX_FOUND_ISBN_TRIES = 3

local function search_chain(chain, meta)
    local result = { matches = {}, method = "search", tried = {}, skipped = {}, empty_chain = #(chain or {}) == 0 }
    for _i, provider in ipairs(chain or {}) do
        local ready, reason = provider:ready()
        if not ready then
            skip(result, provider, reason)
        else
            local ok, matches, method = pcall(provider.find, provider, meta)
            if not ok then
                skip(result, provider, _("lookup failed"), true)
            else
                result.tried[#result.tried + 1] = provider
                if type(matches) == "table" and #matches > 0 then
                    result.matches = matches
                    result.method = method
                    result.provider = provider
                    return result
                end
            end
        end
    end
    return result
end

local function isbn_only(meta, isbn)
    local out = {}
    for key, value in pairs(meta) do
        out[key] = value
    end
    out.found_isbns = nil
    out.title, out.authors = nil, {}
    out.isbn_13 = #isbn == 13 and isbn or nil
    out.isbn_10 = #isbn == 10 and isbn or nil
    return out
end

local function remember_isbn(result, isbn)
    if result.method == "isbn" then
        for _i, match in ipairs(result.matches) do
            match.lookup_isbn = isbn
        end
    end
    return result
end

function Lookup.find(chain, meta)
    local found = meta and not (meta.isbn_13 or meta.isbn_10) and meta.found_isbns or {}
    for index = 1, math.min(#found, MAX_FOUND_ISBN_TRIES) do
        local attempt = search_chain(chain, isbn_only(meta, found[index]))
        if #attempt.matches > 0 and attempt.method == "isbn" then
            attempt.found_isbn = found[index]
            return remember_isbn(attempt, found[index])
        end
        if Lookup.all_failed(attempt) then
            break
        end
    end
    return remember_isbn(search_chain(chain, meta), meta and (meta.isbn_13 or meta.isbn_10))
end

function Lookup.carry_isbn(source, book)
    if type(source) ~= "table" or source.lookup_isbn or not (book and book.lookup_isbn) then
        return source
    end
    local out = {}
    for key, value in pairs(source) do
        out[key] = value
    end
    out.lookup_isbn = book.lookup_isbn
    return out
end

function Lookup.find_in(provider, meta)
    return Lookup.find({ provider }, meta)
end

function Lookup.search_terms(meta)
    meta = meta or {}
    return {
        title = meta.title or "",
        author = meta.authors and meta.authors[1] or "",
        isbn = meta.isbn_13 or meta.isbn_10 or (meta.found_isbns and meta.found_isbns[1]) or "",
    }
end

local function trimmed(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Lookup.with_terms(meta, terms)
    local out = {}
    for key, value in pairs(meta or {}) do
        out[key] = value
    end
    local title = trimmed(terms.title)
    local author = trimmed(terms.author)
    local isbn = trimmed(terms.isbn):gsub("[%s%-]", ""):upper()
    out.title = title ~= "" and title or nil
    out.authors = author ~= "" and { author } or {}
    out.isbn_13, out.isbn_10, out.found_isbns = nil, nil, nil
    if isbn:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d$") then
        out.isbn_13 = isbn
    elseif isbn:match("^%d%d%d%d%d%d%d%d%d[%dX]$") then
        out.isbn_10 = isbn
    end
    return out
end

function Lookup.searchable(meta)
    return (meta.title ~= nil and meta.title ~= "") or meta.isbn_13 ~= nil or meta.isbn_10 ~= nil
end

function Lookup.provider_text(match)
    return match and match.provider_name or _("None")
end

function Lookup.all_failed(result)
    if #result.tried > 0 then
        return false
    end
    for _i, entry in ipairs(result.skipped) do
        if entry.failed then
            return true
        end
    end
    return false
end

function Lookup.pick_edition(provider, match, current, preferred)
    if not provider.picks_by_language then
        return provider:pick_edition(match, current)
    end
    local edition = current and provider:pick_edition(match, current)
    if edition or not preferred or preferred == current then
        return edition
    end
    return provider:pick_edition(match, preferred)
end

function Lookup.auto_edition(chain, current, book, preferred)
    if not (chain and book and not book.edition_id and not book.by_isbn and book.has_editions) then
        return book
    end
    local provider = Lookup.provider_for(chain, book)
    local ok, edition = pcall(function()
        return provider and Lookup.pick_edition(provider, book, current and current.language, preferred)
    end)
    return ok and edition and Lookup.carry_isbn(edition, book) or book
end

function Lookup.skipped_text(result)
    local lines = {}
    for _i, entry in ipairs(result.skipped or {}) do
        lines[#lines + 1] = string.format(_("%s was skipped: %s"), entry.provider.name, entry.reason)
    end
    return table.concat(lines, "\n")
end

function Lookup.not_found_text(result)
    if result.empty_chain then
        return _("No lookup providers enabled") .. "\n\n" .. _("Turn some on under Tools → Rebind → Lookup providers.")
    end
    local text
    if #result.tried > 0 then
        text = string.format(_("Not found on %s"), Lookup.names(result.tried))
    else
        text = _("No lookup provider could be reached")
    end
    local skipped = Lookup.skipped_text(result)
    if skipped ~= "" then
        text = text .. "\n\n" .. skipped
    end
    return text
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
