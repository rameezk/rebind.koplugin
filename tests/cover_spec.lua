local Cover = require("rebind/cover")
local Http = require("rebind/http")
local Images = require("tests/support/images")
local FakeTransport = require("tests/support/fake_transport")

local T = {}

T["a tall portrait JPEG passes the filter with its pixel size"] = function(a)
    local info = Cover.check(Images.jpeg(400, 600))
    a.is_true(info)
    a.eq(info.width, 400)
    a.eq(info.height, 600)
    a.eq(info.format, "jpeg")
    a.eq(info.extension, "jpg")
    a.eq(info.media_type, "image/jpeg")
end

T["a portrait PNG passes the filter"] = function(a)
    local info = Cover.check(Images.png(400, 600))
    a.is_true(info)
    a.eq(info.format, "png")
    a.eq(info.media_type, "image/png")
end

T["a cover under 300px tall counts as no cover"] = function(a)
    a.eq(Cover.check(Images.jpeg(133, 200)), nil)
end

T["a square cover counts as no cover"] = function(a)
    a.eq(Cover.check(Images.jpeg(600, 600)), nil)
end

T["a cover wider than 0.85 or narrower than 0.5 counts as no cover"] = function(a)
    a.eq(Cover.check(Images.jpeg(520, 600)), nil)
    a.eq(Cover.check(Images.jpeg(290, 600)), nil)
    a.is_true(Cover.check(Images.jpeg(300, 600)))
    a.is_true(Cover.check(Images.jpeg(510, 600)))
end

T["a cover under 2 KB counts as no cover"] = function(a)
    a.eq(Cover.check(Images.jpeg(400, 600, 2047)), nil)
    a.is_true(Cover.check(Images.jpeg(400, 600, 2048)))
end

T["a WebP cover counts as no cover"] = function(a)
    a.eq(Cover.check(Images.webp()), nil)
end

T["bytes that do not decode count as no cover"] = function(a)
    a.eq(Cover.check("\255\216" .. string.rep("x", 4000)), nil)
    a.eq(Cover.check("\137PNG\13\10\26\10" .. string.rep("x", 4000)), nil)
    a.eq(Cover.check(""), nil)
    a.eq(Cover.check(nil), nil)
end

T["a cover with an enormous declared size counts as no cover"] = function(a)
    a.eq(Cover.check(Images.jpeg(10000, 16000)), nil)
    a.is_true(Cover.check(Images.jpeg(2000, 3000)))
end

T["fetch refuses a cover url that is not https"] = function(a)
    local http, transport = nil, nil
    http, transport = (function()
        local t = FakeTransport.new({ { when = "img.test", body = Images.jpeg(400, 600) } })
        return Http.new{ transport = t:fn(), sleep = function() end }, t
    end)()
    a.eq(Cover.fetch(http, { url = "http://img.test/a.jpg" }), nil)
    a.eq(#transport.calls, 0)
    a.is_true(Cover.fetch(http, { url = "https://img.test/a.jpg" }))
end

local function client(routes)
    local transport = FakeTransport.new(routes)
    return Http.new{ transport = transport:fn(), sleep = function() end, version = "2.1.0" }, transport
end

T["the binary download carries the Rebind user agent and returns the bytes"] = function(a)
    local bytes = Images.jpeg(400, 600)
    local http, transport = client({ { when = "img.test/a.jpg", body = bytes } })
    local body = http:get_binary("https://img.test/a.jpg")
    a.eq(body, bytes)
    a.eq(transport.calls[1].headers["User-Agent"], "Rebind/2.1.0 (https://github.com/rameezk/rebind.koplugin)")
end

T["the binary download backs off on 429 like JSON requests"] = function(a)
    local bytes = Images.jpeg(400, 600)
    local transport = FakeTransport.new({
        { when = "img.test", responses = { { status = 429, headers = { ["retry-after"] = "3" } }, { body = bytes } } },
    })
    local sleeps = {}
    local http = Http.new{ transport = transport:fn(), sleep = function(s) sleeps[#sleeps + 1] = s end }
    a.eq(http:get_binary("https://img.test/a.jpg"), bytes)
    a.eq(sleeps[1], 3)
end

T["the binary download reports an HTTP error as no body"] = function(a)
    local http = client({})
    local body, err = http:get_binary("https://img.test/missing.jpg")
    a.eq(body, nil)
    a.eq(err, "HTTP 404")
end

T["fetch returns the checked cover with its source url"] = function(a)
    local bytes = Images.jpeg(400, 600)
    local http = client({ { when = "img.test/a.jpg", body = bytes } })
    local cover = Cover.fetch(http, { url = "https://img.test/a.jpg" })
    a.eq(cover.bytes, bytes)
    a.eq(cover.url, "https://img.test/a.jpg")
    a.eq(cover.width, 400)
    a.eq(cover.size, #bytes)
end

T["fetch is empty when the download fails or the cover is filtered out"] = function(a)
    local http = client({ { when = "img.test/small.jpg", body = Images.jpeg(100, 150) } })
    a.eq(Cover.fetch(http, { url = "https://img.test/small.jpg" }), nil)
    a.eq(Cover.fetch(http, { url = "https://img.test/gone.jpg" }), nil)
    a.eq(Cover.fetch(http, nil), nil)
    a.eq(Cover.fetch(http, {}), nil)
end

T["attach downloads the proposed cover and leaves other values alone"] = function(a)
    local http, transport = client({
        { when = "img.test/edition.jpg", body = Images.jpeg(400, 600) },
        { when = "img.test/book.jpg", body = Images.jpeg(300, 450) },
    })
    local proposed = { title = "Dune", cover = { url = "https://img.test/edition.jpg" } }
    local out = Cover.attach(http, proposed)
    a.eq(out.title, "Dune")
    a.eq(out.cover_image.width, 400)
    a.eq(proposed.cover_image, nil)
    a.eq(#transport.calls, 1)
end

T["attach drops the previous cover image when another edition has none"] = function(a)
    local http = client({})
    local out = Cover.attach(http, { title = "Dune", cover_image = { url = "x" } })
    a.eq(out.cover_image, nil)
    a.eq(out.title, "Dune")
end

T["attach copes with no proposal"] = function(a)
    a.eq(next(Cover.attach(client({}), nil)), nil)
end

T["a cover is offered to a book without one, or with another cover, but not for the same source"] = function(a)
    local url = "https://assets.test/dune.jpg"
    a.is_true(Cover.offered({ has_cover = false }, url))
    a.is_true(Cover.offered({ has_cover = true }, url))
    a.is_true(Cover.offered({ has_cover = true, cover_source = "https://other/x.jpg" }, url))
    a.is_true(Cover.offered({ has_cover = true, cover_source = url, original_cover = "cover" }, url))
    a.eq(Cover.offered({ has_cover = true, cover_source = url }, url), false)
    a.eq(Cover.offered({ has_cover = true, cover_source = url, original_cover = "none" }, url), false)
end

return T
