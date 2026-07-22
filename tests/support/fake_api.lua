local FakeApi = {}
FakeApi.__index = FakeApi

function FakeApi.new(opts)
    opts = opts or {}
    return setmetatable({
        me_result = opts.me or { id = 42 },
        by_isbn = opts.by_isbn,
        by_search = opts.by_search or {},
        calls = {},
    }, FakeApi)
end

function FakeApi:query()
    return nil
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
