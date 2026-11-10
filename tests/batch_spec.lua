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

T["a selection keeps only epubs, sorted by path, and counts the folders"] = function(a)
    local selection = Batch.selection({
        ["/lib/sci/Dune.epub"] = true,
        ["/lib/a/notes.pdf"] = true,
        ["/lib/a/Book 10.epub"] = true,
        ["/lib/a/book 2.epub"] = true,
    })
    a.eq(joined(selection.files), "/lib/a/book 2.epub | /lib/a/Book 10.epub | /lib/sci/Dune.epub")
    a.eq(selection.folders, 2)
end

T["a selection of no epubs is empty"] = function(a)
    local selection = Batch.selection({ ["/lib/a/notes.pdf"] = true })
    a.eq(#selection.files, 0)
    a.eq(selection.folders, 0)
end

T["a selection is described by its book and folder counts"] = function(a)
    a.eq(Batch.selection_label({ files = { "a", "b" }, folders = 2 }), "Selected books · 2 books from 2 folders")
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

T["a lost connection fails the rest of the books, and retrying one looks it up again"] = function(a)
    local calls, online = 0, false
    local batch = batch_for(numbered(6), function(meta)
        calls = calls + 1
        if calls > 3 and not online then
            error("network unreachable")
        end
        return { match("Other", { "B" }) }, "search"
    end)
    batch:lookup_all()
    a.eq(#batch.entries, 6)
    a.eq(#batch.pending, 0)
    a.eq(batch:done_count(), 6)
    local tags = {}
    for _i, entry in ipairs(batch.entries) do
        tags[#tags + 1] = batch:tag(entry)
    end
    a.eq(joined(tags), "Check match | Check match | Check match | Lookup failed | Lookup failed | Lookup failed")
    online = true
    batch:retry(batch.entries[5])
    a.eq(batch.entries[5].kind, "check")
end

T["one failed book is not mistaken for a lost connection"] = function(a)
    local batch = batch_for(numbered(3), function(meta)
        if meta.title == "T1" then
            error("bad response")
        end
        return {}, "search"
    end)
    batch:lookup_all()
    a.eq(batch:tag(batch.entries[1]), "Lookup failed")
    a.eq(batch:tag(batch.entries[2]), "No match")
    a.eq(batch:tag(batch.entries[3]), "No match")
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


local Library = require("tests/support/library")
local Organize = require("rebind/organize")

local function library_batch(root, books, opts)
    opts = opts or {}
    local metas, matches, files = {}, {}, {}
    for _i, book in ipairs(books) do
        local path = root .. "/incoming/" .. book.name
        Library.write(path, "original " .. book.name)
        metas[path] = book.meta
        matches[book.meta.title] = book.match
        files[#files + 1] = path
    end
    local calls = {}
    local batch = Batch.new{
        files = files,
        chain = { provider("p", "Prov", function(meta)
            return { matches[meta.title] }, "search"
        end) },
        read_metadata = function(path)
            return metas[path]
        end,
        clock = function()
            return 0
        end,
        interval = 0,
        open_file = opts.open_file,
        same_file = opts.same_file,
        save_as = opts.save_as or {
            sort = true,
            library = root .. "/lib",
            rename = true,
            keep_backup = false,
            filename_template = Organize.DEFAULT_FILENAME_TEMPLATE,
            folder_template = Organize.DEFAULT_FOLDER_TEMPLATE,
        },
        rewrite = function(path, changes, keep)
            calls[#calls + 1] = { file = path, changes = changes, keep = keep }
            if opts.rewrite then
                return opts.rewrite(path, changes, keep, #calls)
            end
            Library.write(path, "rewritten")
            return true
        end,
    }
    batch:lookup_all()
    return batch, calls
end

local function dune(name, series)
    return {
        name = name,
        meta = { title = "Dune " .. name, authors = { "Frank Herbert" }, publisher = "Ace" },
        match = match("Dune " .. name, { "Frank Herbert" }, { series = series, publisher = "" }),
    }
end

T["a sure match writes what its picker would apply untouched"] = function(a)
    Library.with_library(function(root)
        local batch, calls = library_batch(root, { dune("a.epub", "Dune Chronicles") })
        a.eq(batch:sure_count(), 1)
        batch:rebind_all()
        a.eq(#calls, 1)
        a.eq(calls[1].changes.series, "Dune Chronicles")
        a.eq(calls[1].changes.title, nil)
        a.eq(calls[1].changes.publisher, nil)
        a.eq(batch.entries[1].state, "done")
    end)
end

T["a sure match with no changes is moved but not rewritten"] = function(a)
    Library.with_library(function(root)
        local batch, calls = library_batch(root, { dune("a.epub", nil) })
        a.eq(batch.entries[1].changes, 0)
        batch:rebind_all()
        a.eq(#calls, 0)
        local entry = batch.entries[1]
        a.eq(entry.state, "done")
        a.eq(Library.read(root .. "/incoming/a.epub"), nil)
        a.eq(Library.read(entry.new_path), "original a.epub")
        a.eq(Organize.dirname(entry.new_path):sub(1, #root + 4), root .. "/lib")
    end)
end

T["a failed write does not stop the batch"] = function(a)
    Library.with_library(function(root)
        local batch = library_batch(root, {
            dune("a.epub", "S"), dune("b.epub", "S"), dune("c.epub", "S"),
        }, {
            rewrite = function(path, _changes, _keep, n)
                if n == 2 then
                    return false, "bad zip"
                end
                Library.write(path, "rewritten")
                return true
            end,
        })
        batch:rebind_all()
        local states = {}
        for _i, entry in ipairs(batch.entries) do
            states[#states + 1] = batch:tag(entry)
        end
        a.eq(joined(states), "✓ Sorted | Write failed | ✓ Sorted")
        a.eq(batch.entries[2].state, "review")
        a.eq(batch.entries[2].error, "bad zip")
        a.eq(Library.read(root .. "/incoming/b.epub"), "original b.epub")
        a.eq(batch:summary(), "✓ 2 books rebound and sorted into your library. 1 could not be written.")
    end)
end

T["a failed move is reported as not moved with the metadata already written"] = function(a)
    Library.with_library(function(root)
        local batch, calls = library_batch(root, { dune("a.epub", "S") })
        local entry = batch.entries[1]
        local dest = Organize.destination(entry.file, Organize.with_changes(entry.current, { series = "S" }), {
            sort = true, library = root .. "/lib", rename = true,
            filename_template = Organize.DEFAULT_FILENAME_TEMPLATE,
            folder_template = Organize.DEFAULT_FOLDER_TEMPLATE,
        })
        Library.sh(string.format("mkdir -p '%s'", Organize.dirname(dest)))
        Library.write(dest, "occupied")
        batch:rebind_all()
        a.eq(#calls, 1)
        a.eq(Library.read(entry.file), "rewritten")
        a.eq(Library.read(dest), "occupied")
        a.eq(entry.state, "review")
        a.eq(batch:tag(entry), "Not moved")
        a.is_true(entry.error:find("already exists", 1, true) ~= nil)
        a.eq(batch:summary(), "1 was rebound but not moved.")
    end)
end

T["stopping after this book leaves the rest as sure matches"] = function(a)
    Library.with_library(function(root)
        local batch
        batch = library_batch(root, {
            dune("1.epub", "S"), dune("2.epub", "S"), dune("3.epub", "S"), dune("4.epub", "S"), dune("5.epub", "S"),
        }, {
            rewrite = function(path, _changes, _keep, n)
                if n == 2 then
                    batch:stop()
                end
                Library.write(path, "rewritten")
                return true
            end,
        })
        batch:rebind_all()
        local counts = batch:counts()
        a.eq(counts.done, 2)
        a.eq(counts.sure, 3)
        a.eq(batch:sure_count(), 3)
    end)
end

T["a change to one book's save as applies to that book only"] = function(a)
    Library.with_library(function(root)
        local batch = library_batch(root, { dune("a.epub", "S"), dune("b.epub", "S"), dune("c.epub", "S") })
        local first = batch.entries[1]
        local save_as = batch:save_as_for(first)
        save_as.sort = false
        save_as.rename = false
        first.save_as = save_as
        batch:rebind_all()
        a.eq(first.state, "done")
        a.eq(first.new_path, root .. "/incoming/a.epub")
        a.eq(batch:tag(first), "✓ Rebound")
        a.eq(batch:tag(batch.entries[2]), "✓ Sorted")
        a.eq(batch:tag(batch.entries[3]), "✓ Sorted")
        a.eq(batch.save_as.sort, true)
    end)
end

T["the open book is not written and is not counted"] = function(a)
    Library.with_library(function(root)
        local batch, calls = library_batch(root, { dune("a.epub", "S"), dune("b.epub", "S") }, {
            open_file = root .. "/incoming/a.epub",
        })
        a.eq(batch:sure_count(), 1)
        a.eq(batch:tag(batch.entries[1]), "Open in the reader")
        batch:rebind_all()
        a.eq(#calls, 1)
        a.eq(Library.read(root .. "/incoming/a.epub"), "original a.epub")
        a.eq(batch.entries[1].state, "review")
    end)
end

T["the open book stays in to review as open even without a sure match"] = function(a)
    local batch = batch_for(numbered(2), function()
        return {}, "search"
    end)
    batch.open_file = "/b/01.epub"
    batch:lookup_all()
    a.eq(batch:tag(batch.entries[1]), "Open in the reader")
    a.eq(batch:tag(batch.entries[2]), "No match")
    a.eq(batch.entries[1].state, "review")
end

T["the open book is tagged open even when its lookup failed"] = function(a)
    local batch = batch_for(numbered(1), function()
        error("offline")
    end)
    batch.open_file = "/b/01.epub"
    batch:lookup_all()
    a.eq(batch:tag(batch.entries[1]), "Open in the reader")
end

T["closing asks only about books that are neither done nor open"] = function(a)
    local batch = batch_for(numbered(3), function()
        return {}, "search"
    end)
    batch.open_file = "/b/01.epub"
    batch:lookup_all()
    a.eq(batch:unfinished_count(), 2)
    a.eq(batch:close_prompt(), "2 books haven't been rebound. Their lookups will be lost.")
    batch.entries[2].state = "done"
    a.eq(batch:close_prompt(), "1 book hasn't been rebound. Its lookup will be lost.")
    batch.entries[3].state = "done"
    a.eq(batch:close_prompt(), nil)
end

T["a large selection asks first, with a time estimated from the throttle"] = function(a)
    a.eq(Batch.needs_confirmation(300), false)
    a.eq(Batch.needs_confirmation(301), true)
    a.eq(Batch.large_title(3000), "Look up 3,000 books?")
    a.eq(
        Batch.large_text(3000, 1.5),
        "This takes about an hour, and the device is kept awake. You can stop and review what's found at any time."
    )
    a.is_true(Batch.large_text(301, 1.5):find("about 8 minutes", 1, true) ~= nil)
    a.is_true(Batch.large_text(10000, 1.5):find("about 4 hours", 1, true) ~= nil)
    a.is_true(Batch.large_text(301, 0.2):find("about a minute", 1, true) ~= nil)
end

T["with nothing to rebind the summary is empty"] = function(a)
    Library.with_library(function(root)
        local batch = library_batch(root, { dune("a.epub", "S") })
        a.eq(batch:summary(), nil)
    end)
end


T["the batch save as is summarised as backup state, folder and filename"] = function(a)
    local batch = Batch.new{ save_as = {
        keep_backup = true,
        sort = true,
        library = "/lib",
        rename = true,
        filename_template = Organize.DEFAULT_FILENAME_TEMPLATE,
        folder_template = Organize.DEFAULT_FOLDER_TEMPLATE,
    } }
    local top, bottom = batch:save_as_summary()
    a.eq(top, "Save as for this batch · backup kept")
    a.eq(bottom, "Sort into your library · rename to Author - Title")
    batch.save_as.keep_backup, batch.save_as.sort, batch.save_as.rename = false, false, false
    top, bottom = batch:save_as_summary()
    a.eq(top, "Save as for this batch · no backup")
    a.eq(bottom, "Leave where it is · keep current name")
end

T["a done row shows its path inside the library, or its filename when left in place"] = function(a)
    Library.with_library(function(root)
        local batch = library_batch(root, { dune("a.epub", "S"), dune("b.epub", "S") })
        batch.entries[2].save_as = { sort = false, rename = false, keep_backup = false }
        batch:rebind_all()
        a.is_true(batch:done_location(batch.entries[1]):find("^Herbert") ~= nil)
        a.eq(batch:done_location(batch.entries[2]), "b.epub")
    end)
end

T["the open book is recognised through another spelling of its path"] = function(a)
    Library.with_library(function(root)
        local batch, calls = library_batch(root, { dune("a.epub", "S"), dune("b.epub", "S") }, {
            open_file = root .. "//incoming/a.epub",
            same_file = function(x, y)
                return x:gsub("//+", "/") == y:gsub("//+", "/")
            end,
        })
        a.eq(batch:sure_count(), 1)
        batch:rebind_all()
        a.eq(#calls, 1)
        a.eq(Library.read(root .. "/incoming/a.epub"), "original a.epub")
    end)
end

return T
