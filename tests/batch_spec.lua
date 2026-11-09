local Batch = require("rebind/batch")

local T = {}

local function fake_fs(tree)
    return {
        list = function(dir)
            local names = {}
            for name in pairs(tree[dir] or {}) do
                names[#names + 1] = name
            end
            return names
        end,
        is_dir = function(path)
            return tree[path] ~= nil
        end,
    }
end

local function joined(list)
    return table.concat(list, " | ")
end

local function names_of(files)
    local out = {}
    for _i, path in ipairs(files) do
        out[#out + 1] = path:match("([^/]+)$")
    end
    return out
end

local function provider(id, name, finder)
    return {
        id = id,
        name = name,
        ready = function()
            return true
        end,
        find = function(_self, meta)
            return finder(meta)
        end,
    }
end

local function match(title, authors, extra)
    local m = { title = title, authors = authors, provider_id = "p", provider_name = "Prov" }
    for k, v in pairs(extra or {}) do
        m[k] = v
    end
    return m
end

local function batch_for(metas, finder, opts)
    opts = opts or {}
    local files = {}
    for path in pairs(metas) do
        files[#files + 1] = path
    end
    table.sort(files)
    local clock = opts.clock or function()
        return 0
    end
    return Batch.new{
        files = files,
        chain = { provider("p", "Prov", finder) },
        read_metadata = function(path)
            return metas[path]
        end,
        clock = clock,
        sleep = opts.sleep,
        interval = opts.interval or 0,
        rewrite = opts.rewrite,
        relocate = opts.relocate,
    }
end

T["only epubs are listed, in natural case-insensitive order"] = function(a)
    local fs = fake_fs({
        ["/lib"] = { ["Book 10.epub"] = true, ["book 2.epub"] = true, ["notes.pdf"] = true },
    })
    a.eq(joined(names_of(Batch.collect("/lib", { fs = fs }))), "book 2.epub | Book 10.epub")
end

T["subfolders are included at any depth, ordered by path"] = function(a)
    local fs = fake_fs({
        ["/lib"] = { ["Book 10.epub"] = true, ["book 2.epub"] = true, ["notes.pdf"] = true, ["sci"] = true },
        ["/lib/sci"] = { ["Dune.epub"] = true, ["deep"] = true },
        ["/lib/sci/deep"] = { ["Zed.epub"] = true },
    })
    a.eq(
        joined(Batch.collect("/lib", { fs = fs, include_subfolders = true })),
        "/lib/book 2.epub | /lib/Book 10.epub | /lib/sci/deep/Zed.epub | /lib/sci/Dune.epub"
    )
end

T["a folder given with a trailing slash lists single-slash paths"] = function(a)
    local fs = fake_fs({ ["/lib"] = { ["a.epub"] = true }, [""] = { ["b.epub"] = true } })
    a.eq(joined(Batch.collect("/lib/", { fs = fs })), "/lib/a.epub")
    a.eq(joined(Batch.collect("/", { fs = fs })), "/b.epub")
end

T["an isbn match is a sure match tagged with isbn and its provider"] = function(a)
    local batch = batch_for({ ["/b/x.epub"] = { title = "X", authors = { "Y" }, isbn_13 = "9780441013593" } }, function()
        return { match("Dune", { "Frank Herbert" }, { by_isbn = true }) }, "isbn"
    end)
    batch:lookup_all()
    local entry = batch.entries[1]
    a.eq(entry.state, "sure")
    a.eq(batch:tag(entry), "ISBN · Prov · 2 changes")
end

T["one agreeing match is sure"] = function(a)
    local batch = batch_for({
        ["/b/x.epub"] = { title = "The Left Hand of Darkness", authors = { "Le Guin, Ursula K." } },
    }, function()
        return { match("Left Hand of Darkness", { "Ursula K. Le Guin" }) }, "search"
    end)
    batch:lookup_all()
    a.eq(batch.entries[1].state, "sure")
end

T["a disagreeing or ambiguous match needs review"] = function(a)
    local metas = {
        ["/b/a.epub"] = { title = "Dune", authors = { "Frank Herbert" } },
        ["/b/b.epub"] = { title = "Unknown", authors = {} },
        ["/b/c.epub"] = { title = "Three", authors = { "Someone" } },
    }
    local batch = batch_for(metas, function(meta)
        if meta.title == "Dune" then
            return { match("Dune Messiah", { "Frank Herbert" }) }, "search"
        elseif meta.title == "Unknown" then
            return { match("Something", { "Else" }) }, "search"
        end
        return { match("A", { "x" }), match("B", { "x" }), match("C", { "x" }) }, "search"
    end)
    batch:lookup_all()
    local tags = {}
    for _i, entry in ipairs(batch.entries) do
        a.eq(entry.state, "review")
        tags[#tags + 1] = batch:tag(entry)
    end
    a.eq(joined(tags), "Check match | Check match | 3 matches")
end

T["no match and a failed lookup are told apart"] = function(a)
    local metas = {
        ["/b/a.epub"] = { title = "Nothing", authors = {} },
        ["/b/b.epub"] = { title = "Boom", authors = {} },
    }
    local batch = batch_for(metas, function(meta)
        if meta.title == "Boom" then
            error("network down")
        end
        return {}, "search"
    end)
    batch:lookup_all()
    a.eq(batch:tag(batch.entries[1]), "No match")
    a.eq(batch:tag(batch.entries[2]), "Lookup failed")
end

T["sections are ordered, sorted by filename and empty ones hidden"] = function(a)
    local metas = {
        ["/b/B 10.epub"] = { title = "Dune", authors = { "Frank Herbert" } },
        ["/b/b 2.epub"] = { title = "Dune", authors = { "Frank Herbert" } },
        ["/b/c.epub"] = { title = "Nope", authors = {} },
    }
    local batch = batch_for(metas, function(meta)
        if meta.title == "Dune" then
            return { match("Dune", { "Frank Herbert" }) }, "search"
        end
        return {}, "search"
    end)
    batch:lookup_all()
    local sections = batch:sections()
    a.eq(#sections, 2)
    a.eq(sections[1].key, "review")
    a.eq(sections[2].key, "sure")
    a.eq(sections[2].entries[1].name .. " | " .. sections[2].entries[2].name, "b 2.epub | B 10.epub")
end

local function numbered(count)
    local metas = {}
    for i = 1, count do
        metas[string.format("/b/%02d.epub", i)] = { title = "T" .. i, authors = { "A" } }
    end
    return metas
end

T["stopping keeps what was found and leaves the rest out"] = function(a)
    local batch = batch_for(numbered(10), function()
        return {}, "search"
    end)
    for _i = 1, 4 do
        batch:lookup_next()
    end
    batch:stop()
    batch:lookup_all()
    a.eq(#batch.entries, 4)
    a.eq(#batch:sections()[1].entries, 4)
    a.eq(batch:lookup_next(), false)
end

T["lookups are never closer together than the throttle allows"] = function(a)
    local now = 100
    local calls = {}
    local batch = batch_for(numbered(6), function()
        calls[#calls + 1] = now
        return {}, "search"
    end, {
        interval = 1.5,
        clock = function()
            return now
        end,
        sleep = function(seconds)
            now = now + seconds
        end,
    })
    batch:lookup_all()
    a.eq(#calls, 6)
    for i = 2, #calls do
        a.is_true(calls[i] - calls[i - 1] >= 1.5, "calls too close together")
    end
end

T["the throttle counts from the end of a slow lookup"] = function(a)
    local now = 0
    local starts, ends = {}, {}
    local batch = batch_for(numbered(3), function()
        starts[#starts + 1] = now
        now = now + 4
        ends[#ends + 1] = now
        return {}, "search"
    end, {
        interval = 1.5,
        clock = function()
            return now
        end,
        sleep = function(seconds)
            now = now + seconds
        end,
    })
    batch:lookup_all()
    for i = 2, #starts do
        a.is_true(starts[i] - ends[i - 1] >= 1.5, "next lookup started too soon after the last ended")
    end
end

T["retrying a lookup respects the throttle too"] = function(a)
    local now = 10
    local calls = {}
    local batch = batch_for({ ["/b/a.epub"] = { title = "Dune", authors = {} } }, function()
        calls[#calls + 1] = now
        return {}, "search"
    end, {
        interval = 2,
        clock = function()
            return now
        end,
        sleep = function(seconds)
            now = now + seconds
        end,
    })
    batch:lookup_all()
    batch:retry(batch.entries[1])
    a.is_true(calls[2] - calls[1] >= 2, "retry ran inside the throttle window")
end

T["titles and authors agree across accents, curly quotes and a leading article"] = function(a)
    a.eq(Batch.normalize_title("The Café’s Secret"), "cafes secret")
    a.eq(Batch.normalize_title("Flÿ"), "fly")
    a.eq(Batch.normalize_title("Straße"), "strasse")
    a.is_true(Batch.agrees({ title = "Les Misérables", authors = { "Hugo, Victor" } },
        { title = "les miserables", authors = { "Victor Hugo" } }))
end

T["a failed lookup is looked up again when retried"] = function(a)
    local attempts = 0
    local batch = batch_for({ ["/b/a.epub"] = { title = "Dune", authors = { "Frank Herbert" } } }, function()
        attempts = attempts + 1
        if attempts == 1 then
            error("offline")
        end
        return { match("Dune", { "Frank Herbert" }) }, "search"
    end)
    batch:lookup_all()
    a.eq(batch:tag(batch.entries[1]), "Lookup failed")
    batch:retry(batch.entries[1])
    a.eq(batch.entries[1].state, "sure")
end

T["provider skips are collected into one notice per provider"] = function(a)
    local slow = {
        id = "inv",
        name = "Inventaire",
        ready = function()
            return false, "timed out"
        end,
        find = function() end,
    }
    local batch = batch_for(numbered(2), function()
        return {}, "search"
    end)
    table.insert(batch.chain, 1, slow)
    batch:lookup_all()
    a.eq(joined(batch:skip_notices()), "Inventaire was skipped for 2 books: timed out.")
end

local function sure_batch(opts)
    local batch = batch_for({ ["/b/a.epub"] = { title = "Dune", authors = { "Frank Herbert" } } }, function()
        return { match("Dune", { "Frank Herbert" }, { series = "Dune Chronicles" }) }, "search"
    end, opts)
    batch:lookup_all()
    return batch
end

T["applying a row rewrites the book and moves the row to done"] = function(a)
    local written
    local batch = sure_batch({
        rewrite = function(file, changes, keep)
            written = { file = file, changes = changes, keep = keep }
            return true, "/b/a.epub.rebind.bak"
        end,
        relocate = function(_from, to)
            return true, to
        end,
    })
    local entry = batch.entries[1]
    local outcome = batch:apply(entry, { series = "Dune Chronicles" }, { keep_backup = true, dest = "/lib/Herbert/Dune.epub" })
    a.is_true(outcome.ok)
    a.eq(written.file, "/b/a.epub")
    a.eq(entry.state, "done")
    a.eq(batch:tag(entry), "✓ Sorted")
    a.eq(entry.new_path, "/lib/Herbert/Dune.epub")
    a.eq(#batch:sections(), 1)
end

T["a row applied in place is tagged rebound"] = function(a)
    local batch = sure_batch({
        rewrite = function()
            return true
        end,
    })
    batch:apply(batch.entries[1], { series = "x" }, { keep_backup = false, dest = "/b/a.epub" })
    a.eq(batch:tag(batch.entries[1]), "✓ Rebound")
end

T["a failed write leaves the row where it was"] = function(a)
    local batch = sure_batch({
        rewrite = function()
            return false, "disk full"
        end,
    })
    local outcome = batch:apply(batch.entries[1], { series = "x" }, { keep_backup = false, dest = "/b/a.epub" })
    a.eq(outcome.ok, false)
    a.eq(batch.entries[1].state, "sure")
end

T["a batch hands out the files it changed once"] = function(a)
    local batch = sure_batch({
        rewrite = function()
            return true
        end,
    })
    batch:apply(batch.entries[1], { series = "x" }, { keep_backup = false, dest = "/b/a.epub" })
    a.eq(joined(batch:take_changed()), "/b/a.epub")
    a.eq(#batch:take_changed(), 0)
end

T["retrying a skipped book does not count its skip twice"] = function(a)
    local slow = {
        id = "inv",
        name = "Inventaire",
        ready = function()
            return false, "timed out"
        end,
        find = function() end,
    }
    local batch = batch_for(numbered(1), function()
        return {}, "search"
    end)
    table.insert(batch.chain, 1, slow)
    batch:lookup_all()
    batch:retry(batch.entries[1])
    a.eq(joined(batch:skip_notices()), "Inventaire was skipped for 1 book: timed out.")
end

return T
