local Library = {}

function Library.sh(cmd)
    os.execute(cmd)
end

function Library.write(path, text)
    local f = assert(io.open(path, "wb"))
    f:write(text)
    f:close()
end

function Library.read(path)
    local f = io.open(path, "rb")
    if not f then
        return nil
    end
    local text = f:read("*a")
    f:close()
    return text
end

function Library.with_library(fn)
    local saved = {}
    local names = { "util", "libs/libkoreader-lfs", "docsettings", "ffi/util" }
    for _i, name in ipairs(names) do
        saved[name] = package.loaded[name]
    end
    package.loaded["util"] = {
        makePath = function(path)
            Library.sh(string.format("mkdir -p '%s'", path))
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
    Library.sh(string.format("mkdir -p '%s/incoming' '%s/lib'", root, root))
    local ok, err = pcall(fn, root)
    Library.sh(string.format("rm -rf '%s'", root))
    for _i, name in ipairs(names) do
        package.loaded[name] = saved[name]
    end
    if not ok then
        error(err, 0)
    end

end

return Library
