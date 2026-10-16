local Translate = require("rebind/translate")

local Provider = {}
Provider.__index = Provider

Provider.id = "inventaire"
Provider.name = "Inventaire"
Provider.picks_by_language = true

local API = "https://inventaire.io/api/"
local SEARCH_URL = API .. "search"
local BY_URIS_URL = API .. "entities/by-uris"
local REVERSE_CLAIMS_URL = API .. "entities/reverse-claims"

local SEARCH_LIMIT = 5
local BATCH_SIZE = 50
local EDITION_SCAN_LIMIT = 100
local GENRE_LIMIT = 5
local AUTHOR_LIMIT = 10
local DEFAULT_LANGUAGE = "en"

local AUTHOR = "wdt:P50"
local GENRE = "wdt:P136"
local SERIES = "wdt:P179"
local SERIES_ORDINAL = "wdt:P1545"
local PUBLICATION_DATE = "wdt:P577"
local PUBLISHER = "wdt:P123"
local EDITION_OF = "wdt:P629"
local EDITION_TITLE = "wdt:P1476"
local EDITION_LANGUAGE = "wdt:P407"
local LANGUAGE_ISO_639_1 = "wdt:P218"

local function entity_uri(uri)
    return type(uri) == "string" and (uri:match("^wd:Q%d+$") ~= nil or uri:match("^inv:%x+$") ~= nil)
end

local function valid_uri(uri)
    return entity_uri(uri) or (type(uri) == "string" and uri:match("^isbn:%d+X?$") ~= nil)
end

local function claim(entity, property)
    local values = type(entity) == "table" and type(entity.claims) == "table" and entity.claims[property]
    return type(values) == "table" and values or {}
end

local function year_of(value)
    if type(value) == "number" then
        value = tostring(value)
    end
    if type(value) ~= "string" then
        return nil
    end
    return value:match("%f[%d]%d%d%d%d%f[%D]")
end

local function label_of(entity, language)
    local labels = type(entity) == "table" and type(entity.labels) == "table" and entity.labels or {}
    for _i, key in ipairs({ language or false, DEFAULT_LANGUAGE, "mul", "fromclaims" }) do
        local value = key and labels[key]
        if type(value) == "string" and value ~= "" then
            return value
        end
    end
    local keys = {}
    for key in pairs(labels) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for _i, key in ipairs(keys) do
        if type(labels[key]) == "string" and labels[key] ~= "" then
            return labels[key]
        end
    end
    return nil
end

local function language_code(language)
    local code = Translate.normalize(language)
    if code and not code:match("^%a%a%a?$") then
        return false
    end
    return code
end

local function uris_of(entity, property, limit)
    local uris = {}
    for _i, uri in ipairs(claim(entity, property)) do
        if valid_uri(uri) and #uris < limit then
            uris[#uris + 1] = uri
        end
    end
    return uris
end

local function labels_for(uris, entities, language)
    local names, seen = {}, {}
    for _i, uri in ipairs(uris) do
        local name = label_of(entities[uri], language)
        if name and not seen[name:lower()] then
            seen[name:lower()] = true
            names[#names + 1] = name
        end
    end
    return names
end

function Provider.available()
    return true
end

function Provider.new(http)
    return setmetatable({ http = http }, Provider)
end

function Provider:ready()
    return true
end

function Provider:_get(url, params)
    local data, err = self.http:get_json(url, params)
    if not data then
        error(err or "Inventaire request failed", 0)
    end
    return data
end

function Provider:_entities(uris, attributes)
    local wanted, seen = {}, {}
    for _i, uri in ipairs(uris) do
        if valid_uri(uri) and not seen[uri] then
            seen[uri] = true
            wanted[#wanted + 1] = uri
        end
    end
    local found = {}
    for first = 1, #wanted, BATCH_SIZE do
        local chunk = { unpack(wanted, first, math.min(first + BATCH_SIZE - 1, #wanted)) }
        local data = self:_get(BY_URIS_URL, { uris = table.concat(chunk, "|"), attributes = attributes })
        for uri, entity in pairs(type(data.entities) == "table" and data.entities or {}) do
            if type(entity) == "table" then
                found[uri] = entity
            end
        end
        for from, to in pairs(type(data.redirects) == "table" and data.redirects or {}) do
            found[from] = found[to]
        end
    end
    return found
end

function Provider:_books(uris, language)
    local works = self:_entities(uris, "claims|labels")
    local refs = {}
    for _i, uri in ipairs(uris) do
        for _j, property in ipairs({ AUTHOR, GENRE, SERIES }) do
            local limit = property == AUTHOR and AUTHOR_LIMIT or property == GENRE and GENRE_LIMIT or 1
            for _k, ref in ipairs(uris_of(works[uri], property, limit)) do
                refs[#refs + 1] = ref
            end
        end
    end
    local labels = self:_entities(refs, "labels")
    local books = {}
    for _i, uri in ipairs(uris) do
        local work = works[uri]
        if work then
            local series = labels_for(uris_of(work, SERIES, 1), labels, language)[1]
            local year = year_of(claim(work, PUBLICATION_DATE)[1])
            books[#books + 1] = {
                provider_id = Provider.id,
                provider_name = Provider.name,
                has_editions = true,
                is_edition = false,
                title = label_of(work, language),
                authors = labels_for(uris_of(work, AUTHOR, AUTHOR_LIMIT), labels, language),
                series = series,
                series_index = series and tonumber(claim(work, SERIES_ORDINAL)[1]) or nil,
                genres = labels_for(uris_of(work, GENRE, GENRE_LIMIT), labels, language),
                first_published = year,
                release_year = year,
                ref = { work_uri = uri },
            }
        end
    end
    return books
end

function Provider:_language_codes(editions)
    self.language_codes = self.language_codes or {}
    local unknown = {}
    for _i, edition in ipairs(editions) do
        local uri = claim(edition, EDITION_LANGUAGE)[1]
        if valid_uri(uri) and self.language_codes[uri] == nil then
            unknown[#unknown + 1] = uri
        end
    end
    local found = self:_entities(unknown, "claims")
    for _i, uri in ipairs(unknown) do
        local code = claim(found[uri], LANGUAGE_ISO_639_1)[1]
        self.language_codes[uri] = type(code) == "string" and code:lower() or false
    end
end

function Provider:_edition_matches(editions, book, language)
    self:_language_codes(editions)
    local publishers = {}
    for i, edition in ipairs(editions) do
        publishers[i] = uris_of(edition, PUBLISHER, 1)[1] or false
    end
    local labels = self:_entities(publishers, "labels")
    local matches = {}
    for i, edition in ipairs(editions) do
        local match = {}
        for key, value in pairs(book) do
            match[key] = value
        end
        local title = claim(edition, EDITION_TITLE)[1]
        local published = year_of(claim(edition, PUBLICATION_DATE)[1])
        local code = self.language_codes[claim(edition, EDITION_LANGUAGE)[1]]
        match.is_edition = true
        match.edition_id = edition.uri
        match.title = type(title) == "string" and title ~= "" and title or book.title
        match.publisher = publishers[i] and label_of(labels[publishers[i]], language) or nil
        match.language = code or nil
        match.release_year = published or book.release_year
        match.ref = { work_uri = book.ref.work_uri, edition_uri = edition.uri }
        matches[#matches + 1] = match
    end
    return matches
end

function Provider:_find_by_isbn(meta, language)
    for _i, isbn in ipairs({ meta.isbn_13 or false, meta.isbn_10 or false }) do
        local digits = isbn and tostring(isbn):gsub("[%s%-]", ""):upper()
        if digits and valid_uri("isbn:" .. digits) then
            local data = self:_get(BY_URIS_URL, { uris = "isbn:" .. digits, attributes = "claims" })
            local uri, edition = next(type(data.entities) == "table" and data.entities or {})
            local work_uri = entity_uri(uri) and type(edition) == "table" and uris_of(edition, EDITION_OF, 1)[1]
            local book = work_uri and self:_books({ work_uri }, language)[1]
            if book then
                edition.uri = uri
                local match = self:_edition_matches({ edition }, book, language)[1]
                match.by_isbn = true
                return { match }
            end
        end
    end
    return nil
end

local function by_author_first(books, author)
    if type(author) ~= "string" or author == "" then
        return books
    end
    local wanted = author:lower()
    local preferred, rest = {}, {}
    for _i, book in ipairs(books) do
        local listed = rest
        for _j, name in ipairs(book.authors) do
            if name:lower() == wanted then
                listed = preferred
            end
        end
        listed[#listed + 1] = book
    end
    for _i, book in ipairs(rest) do
        preferred[#preferred + 1] = book
    end
    return preferred
end

function Provider:_search(meta, language)
    local data = self:_get(SEARCH_URL, {
        search = meta.title,
        types = "works",
        limit = SEARCH_LIMIT,
        lang = language or DEFAULT_LANGUAGE,
    })
    local uris = {}
    for _i, result in ipairs(type(data.results) == "table" and data.results or {}) do
        if type(result) == "table" and valid_uri(result.uri) then
            uris[#uris + 1] = result.uri
        end
    end
    return by_author_first(self:_books(uris, language), meta.authors and meta.authors[1])
end

function Provider:find(meta)
    local language = language_code(meta.language) or nil
    local by_isbn = self:_find_by_isbn(meta, language)
    if by_isbn then
        return by_isbn, "isbn"
    end
    local matches = {}
    if meta.title and meta.title ~= "" then
        matches = self:_search(meta, language)
    end
    return matches, "search"
end

local function usable(match)
    return type(match) == "table" and type(match.ref) == "table" and entity_uri(match.ref.work_uri)
end

local function published_of(edition)
    return tonumber(year_of(claim(edition, PUBLICATION_DATE)[1])) or 0
end

function Provider:_scan(match, language)
    local data = self:_get(REVERSE_CLAIMS_URL, { property = EDITION_OF, value = match.ref.work_uri })
    local uris = {}
    for _i, uri in ipairs(type(data.uris) == "table" and data.uris or {}) do
        if valid_uri(uri) and #uris < EDITION_SCAN_LIMIT then
            uris[#uris + 1] = uri
        end
    end
    local entities = self:_entities(uris, "claims")
    local editions = {}
    for _i, uri in ipairs(uris) do
        if entities[uri] then
            entities[uri].uri = uri
            editions[#editions + 1] = entities[uri]
        end
    end
    self:_language_codes(editions)
    local wanted = {}
    for _i, edition in ipairs(editions) do
        if not language or self.language_codes[claim(edition, EDITION_LANGUAGE)[1]] == language then
            wanted[#wanted + 1] = edition
        end
    end
    local truncated = type(data.uris) == "table" and #data.uris > EDITION_SCAN_LIMIT
    return wanted, truncated
end

function Provider:editions(match, language)
    local code = language_code(language)
    if not usable(match) or code == false then
        return {}, false
    end
    local wanted, truncated = self:_scan(match, code)
    return self:_edition_matches(wanted, match, code), truncated
end

function Provider:pick_edition(match, language)
    language = language_code(language)
    if not usable(match) or not language then
        return nil
    end
    local best
    for _i, edition in ipairs((self:_scan(match, language))) do
        if not best or published_of(edition) > published_of(best) then
            best = edition
        end
    end
    return best and self:_edition_matches({ best }, match, language)[1]
end

return Provider
