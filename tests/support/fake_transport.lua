local FakeTransport = {}
FakeTransport.__index = FakeTransport

local function read(path)
    local f = assert(io.open(path, "rb"))
    local body = f:read("*a")
    f:close()
    return body
end

local function decode_url(url)
    return (url:gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end):gsub("%+", " "))
end

function FakeTransport.fixture(name, dir)
    return read("tests/fixtures/" .. (dir or "openlibrary") .. "/" .. name)
end

function FakeTransport.new(routes, dir)
    return setmetatable({ routes = routes or {}, calls = {}, dir = dir or "openlibrary" }, FakeTransport)
end

function FakeTransport:request(req)
    local decoded = decode_url(req.url)
    self.calls[#self.calls + 1] = { url = req.url, decoded = decoded, headers = req.headers }
    for _i, route in ipairs(self.routes) do
        if decoded:find(route.when, 1, true) then
            route.served = (route.served or 0) + 1
            local responses = route.responses or { route }
            local response = responses[math.min(route.served, #responses)]
            local body = response.body
            if response.file then
                body = read("tests/fixtures/" .. self.dir .. "/" .. response.file)
            end
            return { status = response.status or 200, body = body or "", headers = response.headers or {} }
        end
    end
    return { status = 404, body = "", headers = {} }
end

function FakeTransport:fn()
    return function(req)
        return self:request(req)
    end
end

return FakeTransport
