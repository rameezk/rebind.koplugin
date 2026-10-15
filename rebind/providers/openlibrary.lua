local Translate = require("rebind/translate")

local Provider = {}
Provider.__index = Provider

Provider.id = "openlibrary"
Provider.name = "Open Library"

local SEARCH_URL = "https://openlibrary.org/search.json"
local SEARCH_LIMIT = 5

local FIELDS = table.concat({
    "key", "title", "author_name", "first_publish_year", "subject", "place", "person", "time",
    "series_name", "series_position",
    "editions", "editions.key", "editions.title", "editions.language", "editions.publisher",
    "editions.publish_date", "editions.ebook_access",
}, ",")

local MARC_TO_ISO = {
    eng = "en", ger = "de", fre = "fr", spa = "es", ita = "it", dut = "nl", por = "pt", rus = "ru",
    pol = "pl", swe = "sv", dan = "da", nor = "no", fin = "fi", cze = "cs", hun = "hu", rum = "ro",
    gre = "el", tur = "tr", heb = "he", ara = "ar", jpn = "ja", chi = "zh", kor = "ko", ukr = "uk",
    hin = "hi", ben = "bn", ind = "id", vie = "vi", tha = "th", per = "fa", lat = "la", cat = "ca",
    hrv = "hr", srp = "sr", slo = "sk", slv = "sl", bul = "bg", lit = "lt", lav = "lv", est = "et",
    afr = "af", wel = "cy", ice = "is", gle = "ga", baq = "eu", glg = "gl",
}

local ISO_TO_MARC = {}
for marc, iso in pairs(MARC_TO_ISO) do
    ISO_TO_MARC[iso] = marc
end

local EBOOK_ACCESS = { public = true, borrowable = true, printdisabled = true }
local EBOOK_CLAUSE = "(ebook_access:public OR ebook_access:borrowable OR ebook_access:printdisabled)"

local GENRE_LIMIT = 5
local GENRE_MAX_LENGTH = 40

local function first_string(list)
    local value = type(list) == "table" and list[1] or list
    if type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

local function language_of(edition)
    local code = first_string(edition.language)
    return code and (MARC_TO_ISO[code] or code) or nil
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

local function key_id(key)
    if type(key) ~= "string" then
        return nil
    end
    return key:match("([^/]+)$")
end

local function name_set(list)
    local set = {}
    for _i, name in ipairs(type(list) == "table" and list or {}) do
        if type(name) == "string" then
            set[name:lower()] = true
        end
    end
    return set
end

local function is_fictional_entity(subject)
    local inner = subject:lower():match("%(([^()]*)%)%s*$")
    return inner ~= nil
        and (inner:find("imaginary", 1, true) or inner:find("fictitious", 1, true)
            or inner:find("fictional", 1, true)) ~= nil
end

function Provider.genres(doc)
    if type(doc.subject) ~= "table" then
        return nil
    end
    local excluded = name_set(doc.place)
    for _i, list in ipairs({ name_set(doc.person), name_set(doc.time) }) do
        for name in pairs(list) do
            excluded[name] = true
        end
    end
    local genres, seen = {}, {}
    for _i, subject in ipairs(doc.subject) do
        local key = type(subject) == "string" and subject:lower() or nil
        if key and not subject:find("[:=]") and not excluded[key] and not seen[key]
            and #subject <= GENRE_MAX_LENGTH and not is_fictional_entity(subject) then
            seen[key] = true
            genres[#genres + 1] = subject
            if #genres >= GENRE_LIMIT then
                break
            end
        end
    end
    return genres
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

function Provider:_neutral(doc, edition)
    local series_index = type(doc.series_position) == "table" and tonumber(doc.series_position[1]) or nil
    local match = {
        provider_id = Provider.id,
        provider_name = Provider.name,
        has_editions = type(doc.key) == "string",
        is_edition = false,
        title = doc.title,
        authors = type(doc.author_name) == "table" and doc.author_name or {},
        series = first_string(doc.series_name),
        series_index = series_index,
        genres = Provider.genres(doc),
        first_published = year_of(doc.first_publish_year),
        release_year = year_of(doc.first_publish_year),
        ref = { work_key = doc.key, edition = edition },
    }
    if edition then
        match.is_edition = true
        match.edition_id = key_id(edition.key)
        match.title = edition.title or doc.title
        match.publisher = first_string(edition.publisher)
        match.edition_format = EBOOK_ACCESS[edition.ebook_access] and "E-Book" or nil
        match.release_year = year_of(first_string(edition.publish_date)) or match.release_year
        match.language = language_of(edition)
    end
    return match
end

function Provider:_search(params)
    params.fields = FIELDS
    local data, err = self.http:get_json(SEARCH_URL, params)
    if not data then
        error(err or "Open Library request failed", 0)
    end
    return type(data.docs) == "table" and data.docs or {}
end

function Provider:_find_by_isbn(meta)
    for _i, isbn in ipairs({ meta.isbn_13 or false, meta.isbn_10 or false }) do
        if isbn then
            local doc = self:_search({ q = "isbn:" .. isbn, limit = 1 })[1]
            if doc then
                local edition = type(doc.editions) == "table" and doc.editions.docs and doc.editions.docs[1]
                return { self:_neutral(doc, edition) }
            end
        end
    end
    return nil
end

local function ebook_of(edition)
    return EBOOK_ACCESS[edition.ebook_access] == true
end

local function published_year(edition)
    return tonumber(year_of(first_string(edition.publish_date))) or 0
end

local function better(a, b)
    if ebook_of(a) ~= ebook_of(b) then
        return ebook_of(a)
    end
    return published_year(a) > published_year(b)
end

function Provider:_candidates(match, language, ebook_only)
    local clauses = { string.format('key:"%s"', match.ref.work_key) }
    if language then
        clauses[#clauses + 1] = "language:" .. (ISO_TO_MARC[language] or language)
    end
    if ebook_only then
        clauses[#clauses + 1] = EBOOK_CLAUSE
    end
    local doc = self:_search({ q = table.concat(clauses, " AND "), limit = 1 })[1]
    local found = {}
    local docs = doc and type(doc.editions) == "table" and doc.editions.docs
    for _i, edition in ipairs(type(docs) == "table" and docs or {}) do
        if not language or language_of(edition) == language then
            found[#found + 1] = self:_neutral(doc, edition)
        end
    end
    return found
end

local function usable(match)
    return type(match) == "table" and type(match.ref) == "table" and type(match.ref.work_key) == "string"
end

function Provider:editions(match, language)
    if not usable(match) then
        return {}, false
    end
    return self:_candidates(match, Translate.normalize(language)), false
end

function Provider:pick_edition(match, language)
    if not usable(match) then
        return nil
    end
    language = Translate.normalize(language)
    local best
    for _i, ebook_only in ipairs({ true, false }) do
        for _j, candidate in ipairs(self:_candidates(match, language, ebook_only)) do
            if not best or better(candidate.ref.edition, best.ref.edition) then
                best = candidate
            end
        end
        if best then
            return best
        end
    end
    return nil
end

function Provider:find(meta)
    local by_isbn = self:_find_by_isbn(meta)
    if by_isbn then
        return by_isbn, "isbn"
    end
    local matches = {}
    if meta.title and meta.title ~= "" then
        local params = { title = meta.title, limit = SEARCH_LIMIT }
        params.author = meta.authors and meta.authors[1]
        for _i, doc in ipairs(self:_search(params)) do
            matches[#matches + 1] = self:_neutral(doc)
        end
    end
    return matches, "search"
end

return Provider
