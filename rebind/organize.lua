local Fields = require("rebind/fields")

local Organize = {}

local SEGMENT_LIMIT = 200

Organize.FILENAME_PRESETS = {
    "%author_sort - %title",
    "%title - %author",
    "%title{ - %series #%series_index} - %author{ (%year)}",
    "{%series %series_index - }%title",
}

Organize.DEFAULT_FILENAME_TEMPLATE = Organize.FILENAME_PRESETS[1]

Organize.FOLDER_PRESETS = {
    "%author_sort/%title",
    "%author_sort",
    "%author_sort/{%series/}",
    "%author_sort/{%series/}%title",
}

Organize.DEFAULT_FOLDER_TEMPLATE = Organize.FOLDER_PRESETS[1]

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

function Organize.basename(path)
    return path:match("[^/]+$") or path
end

function Organize.dirname(path)
    return path:match("^(.*)/[^/]+$") or "."
end

function Organize.extension(filename)
    return filename:match("%.[^.]+$") or ""
end

local function clean(text)
    return (text:gsub('[/\\:%*%?"<>|]', "_"):gsub("%c", "_"))
end

local function first_author(authors)
    if type(authors) == "table" then
        return authors[1]
    elseif type(authors) == "string" then
        return authors
    end
    return nil
end

local function present(value)
    if value == nil then
        return nil
    end
    value = clean(tostring(value)):gsub("^%s+", ""):gsub("[%s%.]+$", "")
    if value == "" then
        return nil
    end
    return value
end

local TOKENS = {
    title = function(meta)
        return present(meta.title) or "Unknown Title"
    end,
    author = function(meta)
        return present(first_author(meta.authors)) or "Unknown Author"
    end,
    author_sort = function(meta)
        return present(Organize.surname_first(first_author(meta.authors))) or "Unknown Author"
    end,
    authors = function(meta)
        if type(meta.authors) == "table" and #meta.authors > 0 then
            return present(table.concat(meta.authors, " & ")) or "Unknown Author"
        end
        return present(first_author(meta.authors)) or "Unknown Author"
    end,
    series = function(meta)
        return present(meta.series)
    end,
    series_index = function(meta)
        return present(Fields.format_index(meta.series_index))
    end,
    year = function(meta)
        return present(meta.first_published)
    end,
    language = function(meta)
        return present(meta.language)
    end,
    publisher = function(meta)
        return present(meta.publisher)
    end,
}

local ESCAPES = { ["%"] = "%", ["{"] = "{", ["}"] = "}" }

local function truncate_bytes(text, limit)
    if #text <= limit then
        return text
    end
    local cut = limit
    while cut > 0 do
        local b = text:byte(cut + 1)
        if not b or b < 0x80 or b > 0xBF then
            break
        end
        cut = cut - 1
    end
    return text:sub(1, cut)
end

local function render_text(template, meta, keep_slash)
    meta = meta or {}
    local out = {}
    local group, group_empty
    local function emit(text)
        local target = group or out
        target[#target + 1] = text
    end
    local i, n = 1, #template
    while i <= n do
        local c = template:sub(i, i)
        if c == "%" then
            local nxt = template:sub(i + 1, i + 1)
            local name = template:match("^[%a_]+", i + 1)
            if ESCAPES[nxt] then
                emit(ESCAPES[nxt])
                i = i + 2
            elseif name then
                local getter = TOKENS[name]
                local value = getter and getter(meta)
                if value then
                    emit(clean(value))
                elseif group then
                    group_empty = true
                end
                i = i + 1 + #name
            else
                emit("%")
                i = i + 1
            end
        elseif c == "{" and not group then
            group, group_empty = {}, false
            i = i + 1
        elseif c == "}" and group then
            local finished, dropped = group, group_empty
            group, group_empty = nil, nil
            if not dropped then
                out[#out + 1] = table.concat(finished)
            end
            i = i + 1
        else
            emit(keep_slash and c == "/" and c or clean(c))
            i = i + 1
        end
    end
    if group and not group_empty then
        out[#out + 1] = table.concat(group)
    end
    return (table.concat(out):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

local function cap(text)
    return (truncate_bytes(text, SEGMENT_LIMIT):gsub(" $", ""))
end

function Organize.render(template, meta)
    return cap(render_text(template, meta, false))
end

function Organize.folder_segments(meta, template)
    local segments = {}
    for part in render_text(template or Organize.DEFAULT_FOLDER_TEMPLATE, meta, true):gmatch("[^/]+") do
        local segment = cap(part:gsub("^%s+", ""):gsub("[%s%.]+$", ""))
        if segment ~= "" then
            segments[#segments + 1] = segment
        end
    end
    return segments
end

function Organize.with_changes(current, changes)
    local merged = {}
    for k, v in pairs(current or {}) do
        merged[k] = v
    end
    for k, v in pairs(changes or {}) do
        merged[k] = v
    end
    if changes and changes.series ~= nil then
        merged.series_index = changes.series_index
    end
    return merged
end

function Organize.folder_label(meta, folder_template)
    local segments = Organize.folder_segments(meta, folder_template)
    if #segments == 0 then
        return "/"
    end
    return table.concat(segments, " / ") .. " /"
end

function Organize.filename(meta, source_filename, template)
    local name = Organize.render(template or Organize.DEFAULT_FILENAME_TEMPLATE, meta)
    if name == "" then
        name = Organize.render(Organize.DEFAULT_FILENAME_TEMPLATE, meta)
    end
    return name .. Organize.extension(source_filename)
end

function Organize.target_dir(root, meta, structure, folder_template)
    root = root:gsub("/+$", "")
    if structure == "flat" then
        return root
    end
    local parts = Organize.folder_segments(meta, folder_template)
    table.insert(parts, 1, root)
    return table.concat(parts, "/")
end

function Organize.target_path(root, meta, source_filename, structure, rename, template, folder_template)
    local name = source_filename
    if rename ~= false then
        name = Organize.filename(meta, source_filename, template)
    end
    return Organize.target_dir(root, meta, structure, folder_template) .. "/" .. name
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

function Organize.move(source_path, root, meta, structure, rename, template, folder_template)
    local util = require("util")
    local lfs = require("libs/libkoreader-lfs")
    local DocSettings = require("docsettings")

    local dest = Organize.target_path(root, meta, Organize.basename(source_path), structure, rename, template, folder_template)
    if dest == source_path then
        return true, dest
    end
    if lfs.attributes(dest, "mode") ~= nil then
        return false, "A file already exists at:\n" .. dest
    end
    local ok_dir, mkerr = util.makePath(Organize.target_dir(root, meta, structure, folder_template))
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
