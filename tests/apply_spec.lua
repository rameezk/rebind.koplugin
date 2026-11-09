local Apply = require("rebind/apply")

local function sh(cmd)
    os.execute(cmd)
end

local function write(path, text)
    local f = assert(io.open(path, "wb"))
    f:write(text)
    f:close()
end

local function read(path)
    local f = io.open(path, "rb")
    if not f then
        return nil
    end
    local text = f:read("*a")
    f:close()
    return text
end

local function with_library(fn)
    local saved = {}
    local names = { "util", "libs/libkoreader-lfs", "docsettings", "ffi/util" }
    for _i, name in ipairs(names) do
        saved[name] = package.loaded[name]
    end
    package.loaded["util"] = {
        makePath = function(path)
            sh(string.format("mkdir -p '%s'", path))
            return true
        end,
    }
    package.loaded["libs/libkoreader-lfs"] = {
        attributes = function(path)
            local f = io.open(path, "r")
            if not f then
                return nil
            end
            f:close()
            return {}
        end,
    }
    package.loaded["docsettings"] = { updateLocation = function() end }
    package.loaded["ffi/util"] = { copyFile = function() return "no copy in tests" end }
    local root = os.tmpname()
    os.remove(root)
    sh(string.format("mkdir -p '%s/incoming' '%s/lib'", root, root))
    local ok, err = pcall(fn, root)
    sh(string.format("rm -rf '%s'", root))
    for _i, name in ipairs(names) do
        package.loaded[name] = saved[name]
    end
    if not ok then
        error(err, 0)
    end
end

local function rewriting(backup)
    return function(path, changes, keep_backup)
        write(path, "rewritten")
        return true, keep_backup ~= false and backup or nil
    end
end

local T = {}

T["a book with changes is rewritten and moved, naming the new path and the backup"] = function(a)
    with_library(function(root)
        local source = root .. "/incoming/x.epub"
        local dest = root .. "/lib/Herbert/Dune.epub"
        write(source, "original")
        local outcome = Apply.run(source, { title = "Dune" }, {
            keep_backup = true,
            dest = dest,
            rewrite = rewriting(source .. ".rebind.bak"),
        })
        a.eq(outcome.ok, true)
        a.eq(outcome.rewritten, true)
        a.eq(outcome.backup, source .. ".rebind.bak")
        a.eq(outcome.moved_dest, dest)
        a.eq(read(dest), "rewritten")
        a.eq(read(source), nil)
    end)
end

T["a book with no changes is moved without being rewritten"] = function(a)
    with_library(function(root)
        local source = root .. "/incoming/x.epub"
        local dest = root .. "/lib/Herbert/Dune.epub"
        write(source, "original")
        local outcome = Apply.run(source, {}, {
            keep_backup = true,
            dest = dest,
            rewrite = function()
                error("must not rewrite")
            end,
        })
        a.eq(outcome.ok, true)
        a.eq(outcome.rewritten, false)
        a.eq(outcome.backup, nil)
        a.eq(outcome.moved_dest, dest)
        a.eq(read(dest), "original")
    end)
end

T["a book whose destination is its own path is rewritten in place and not moved"] = function(a)
    with_library(function(root)
        local source = root .. "/incoming/x.epub"
        write(source, "original")
        local outcome = Apply.run(source, { title = "Dune" }, {
            keep_backup = false,
            dest = source,
            rewrite = rewriting("unused"),
        })
        a.eq(outcome.ok, true)
        a.eq(outcome.rewritten, true)
        a.eq(outcome.backup, nil)
        a.eq(outcome.moved_dest, nil)
    end)
end

T["a failed write leaves the book untouched and unmoved"] = function(a)
    with_library(function(root)
        local source = root .. "/incoming/x.epub"
        local dest = root .. "/lib/Herbert/Dune.epub"
        write(source, "not an epub")
        local outcome = Apply.run(source, { title = "Dune" }, { keep_backup = true, dest = dest })
        a.eq(outcome.ok, false)
        a.eq(outcome.stage, "write")
        a.eq(type(outcome.error), "string")
        a.eq(outcome.rewritten, false)
        a.eq(read(source), "not an epub")
        a.eq(read(dest), nil)
    end)
end

T["a failed move keeps the rewrite and reports why"] = function(a)
    with_library(function(root)
        local source = root .. "/incoming/x.epub"
        local dest = root .. "/lib/Dune.epub"
        write(source, "original")
        write(dest, "already here")
        local outcome = Apply.run(source, { title = "Dune" }, {
            keep_backup = true,
            dest = dest,
            rewrite = rewriting(source .. ".rebind.bak"),
        })
        a.eq(outcome.ok, false)
        a.eq(outcome.stage, "move")
        a.eq(outcome.error, "A file already exists at:\n" .. dest)
        a.eq(outcome.rewritten, true)
        a.eq(outcome.backup, source .. ".rebind.bak")
        a.eq(read(source), "rewritten")
        a.eq(read(dest), "already here")
    end)
end

return T
