local FakeApi = {}
FakeApi.__index = FakeApi

function FakeApi.new(opts)
    opts = opts or {}
    return setmetatable({
        me_result = opts.me or { id = 42 },
        by_isbn = opts.by_isbn,
        by_search = opts.by_search or {},
        descriptions = opts.descriptions,
        genres = opts.genres,
        editions = opts.editions,
        editions_error = opts.editions_error,
        defaults = opts.defaults,
        defaults_error = opts.defaults_error,
        query_error = opts.query_error,
        calls = {},
    }, FakeApi)
end

function FakeApi:query(query, parameters)
    if query:match("default_ebook_edition") then
        self.calls.defaults_query = { query = query, parameters = parameters }
        if self.defaults_error then
            error(self.defaults_error)
        end
        if not self.defaults then
            return nil
        end
        return { books_by_pk = {
            default_ebook_edition = self.defaults.ebook,
            default_physical_edition = self.defaults.physical,
        } }
    end

    if query:match("editions") then
        self.calls.editions_query = { query = query, parameters = parameters }
        if self.editions_error then
            error(self.editions_error)
        end
        if not self.editions then
            return nil
        end
        local limit = parameters and parameters.limit
        local language = parameters and parameters.language
        local rows = {}
        for _, edition in ipairs(self.editions) do
            if limit and #rows >= limit then
                break
            end
            local code = type(edition.language) == "table" and edition.language.code2
            if not language or code == language then
                rows[#rows + 1] = edition
            end
        end
        return { editions = rows }
    end

    self.calls.query = { query = query, parameters = parameters }
    if self.query_error then
        error(self.query_error)
    end
    if not self.descriptions and not self.genres then
        return nil
    end
    local books = {}
    for _, id in ipairs(parameters and parameters.ids or {}) do
        local description = self.descriptions and self.descriptions[id]
        local genres = self.genres and self.genres[id]
        if description or genres then
            books[#books + 1] = { id = id, description = description, genres = genres }
        end
    end
    return { books = books }
end

function FakeApi:me()
    self.calls.me = (self.calls.me or 0) + 1
    return self.me_result
end

function FakeApi:findBookByIdentifiers(identifiers, user_id)
    self.calls.by_identifiers = identifiers
    self.calls.isbn_user_id = user_id
    return self.by_isbn
end

function FakeApi:findBooks(title, author, user_id)
    self.calls.find_books = { title = title, author = author, user_id = user_id }
    return self.by_search
end

return FakeApi
