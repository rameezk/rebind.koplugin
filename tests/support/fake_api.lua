local FakeApi = {}
FakeApi.__index = FakeApi

function FakeApi.new(opts)
    opts = opts or {}
    return setmetatable({
        me_result = opts.me or { id = 42 },
        by_isbn = opts.by_isbn,
        by_search = opts.by_search or {},
        descriptions = opts.descriptions,
        query_error = opts.query_error,
        calls = {},
    }, FakeApi)
end

function FakeApi:query(query, parameters)
    self.calls.query = { query = query, parameters = parameters }
    if self.query_error then
        error(self.query_error)
    end
    if not self.descriptions then
        return nil
    end
    local books = {}
    for _, id in ipairs(parameters and parameters.ids or {}) do
        local description = self.descriptions[id]
        if description then
            books[#books + 1] = { id = id, description = description }
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
