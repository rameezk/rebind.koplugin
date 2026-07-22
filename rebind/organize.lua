local Organize = {}

function Organize.surname_first(name)
    if not name or name == "" then
        return nil
    end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        return nil
    end
    if name:find(",", 1, true) then
        return name
    end
    local words = {}
    for w in name:gmatch("%S+") do
        words[#words + 1] = w
    end
    if #words < 2 then
        return name
    end
    local last = table.remove(words)
    return last .. ", " .. table.concat(words, " ")
end

function Organize.sanitize(component, fallback)
    fallback = fallback or "Unknown"
    if not component then
        return fallback
    end
    local s = component:gsub('[/\\:%*%?"<>|]', "_")
    s = s:gsub("%c", "_")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    s = s:gsub("%.+$", "")
    s = s:gsub("%s+$", "")
    if s == "" then
        return fallback
    end
    if #s > 200 then
        s = s:sub(1, 200):gsub("%s+$", "")
    end
    return s
end

function Organize.author_folder(authors)
    local first
    if type(authors) == "table" then
        first = authors[1]
    elseif type(authors) == "string" then
        first = authors
    end
    return Organize.sanitize(Organize.surname_first(first), "Unknown Author")
end

function Organize.basename(path)
    return path:match("[^/]+$") or path
end

function Organize.target_dir(root, authors, title, structure)
    root = root:gsub("/+$", "")
    if structure == "flat" then
        return root
    end
    local author_dir = Organize.author_folder(authors)
    local title_dir = Organize.sanitize(title, "Unknown Title")
    return table.concat({ root, author_dir, title_dir }, "/")
end

function Organize.target_path(root, authors, title, source_filename, structure)
    return Organize.target_dir(root, authors, title, structure) .. "/" .. source_filename
end

local function move_file(from, to)
    if os.rename(from, to) then
        return true
    end
    local ffiutil = require("ffi/util")
    local err = ffiutil.copyFile(from, to)
    if err then
        return false, err
    end
    os.remove(from)
    return true
end

function Organize.move(source_path, root, authors, title, structure)
    local util = require("util")
    local lfs = require("libs/libkoreader-lfs")
    local DocSettings = require("docsettings")

    local dest = Organize.target_path(root, authors, title, Organize.basename(source_path), structure)
    if dest == source_path then
        return true, dest
    end
    if lfs.attributes(dest, "mode") ~= nil then
        return false, "A file already exists at:\n" .. dest
    end
    local ok_dir, mkerr = util.makePath(Organize.target_dir(root, authors, title, structure))
    if not ok_dir then
        return false, "Could not create folder:\n" .. tostring(mkerr)
    end
    local ok_move, moverr = move_file(source_path, dest)
    if not ok_move then
        return false, "Could not move file:\n" .. tostring(moverr)
    end
    DocSettings.updateLocation(source_path, dest, false)
    return true, dest
end

return Organize
