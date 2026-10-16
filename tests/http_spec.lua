local Http = require("rebind/http")
local FakeTransport = require("tests/support/fake_transport")

local T = {}

local function client(routes, extra)
    local transport = FakeTransport.new(routes)
    local sleeps = {}
    local opts = {
        transport = transport:fn(),
        sleep = function(seconds)
            sleeps[#sleeps + 1] = seconds
        end,
        version = "2.1.0",
    }
    for k, v in pairs(extra or {}) do
        opts[k] = v
    end
    return Http.new(opts), transport, sleeps
end

T["every request carries the Rebind user agent and no email"] = function(a)
    local http, transport = client({ { when = "example.test", body = '{"ok":true}' } })
    local data = http:get_json("https://example.test/search.json", { q = "dune" })
    a.eq(data.ok, true)
    a.eq(
        transport.calls[1].headers["User-Agent"],
        "Rebind/2.1.0 (https://github.com/rameezk/rebind.koplugin)")
end

T["query parameters are percent encoded in sorted order"] = function(a)
    local http, transport = client({ { when = "example.test", body = "{}" } })
    http:get_json("https://example.test/search.json", { title = "Dune & more", author = "Frank Herbert" })
    a.eq(
        transport.calls[1].url,
        "https://example.test/search.json?author=Frank%20Herbert&title=Dune%20%26%20more")
end

T["a 429 waits and retries until the server answers"] = function(a)
    local http, transport, sleeps = client({
        { when = "example.test", responses = {
            { status = 429, headers = { ["retry-after"] = "3" } },
            { status = 200, body = '{"ok":true}' },
        } },
    })
    local data = http:get_json("https://example.test/search.json")
    a.eq(data.ok, true)
    a.eq(#transport.calls, 2)
    a.eq(#sleeps, 1)
    a.eq(sleeps[1], 3)
end

T["a 429 without retry-after backs off before retrying"] = function(a)
    local http, _, sleeps = client({
        { when = "example.test", responses = {
            { status = 429 },
            { status = 429 },
            { status = 200, body = "{}" },
        } },
    })
    http:get_json("https://example.test/")
    a.eq(#sleeps, 2)
    a.is_true(sleeps[1] > 0 and sleeps[2] > sleeps[1], "backoff should grow")
end

T["a 429 that never clears fails after the retries run out"] = function(a)
    local http, transport = client({ { when = "example.test", status = 429 } })
    local data, err = http:get_json("https://example.test/")
    a.eq(data, nil)
    a.contains(err, "429")
    a.eq(#transport.calls, Http.MAX_ATTEMPTS)
end

T["other HTTP errors and bad JSON fail without retrying"] = function(a)
    local http, transport = client({
        { when = "down.test", status = 503 },
        { when = "junk.test", body = "<html>" },
    })
    local data, err = http:get_json("https://down.test/")
    a.eq(data, nil)
    a.contains(err, "503")
    local junk, junk_err = http:get_json("https://junk.test/")
    a.eq(junk, nil)
    a.contains(junk_err, "JSON")
    a.eq(#transport.calls, 2)
end

T["a response larger than the limit is cut off instead of buffered"] = function(a)
    local chunks = {}
    local sink = Http.limited_sink(chunks, 10)
    a.eq(sink("12345"), 1)
    a.eq(sink("6789"), 1)
    local ok, err = sink("0123")
    a.eq(ok, nil)
    a.contains(err, "too large")
end

return T
