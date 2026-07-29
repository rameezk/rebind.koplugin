local Archiver = require("ffi/archiver")
local SLAXML = require("rebind/vendor/slaxdom")

local DC_NS = "http://purl.org/dc/elements/1.1/"

local Epub = {}

function Epub.is_epub(path)
    return type(path) == "string" and path:lower():match("%.epub$") ~= nil
end

local function is_element(node)
    return type(node) == "table" and node.type == "element"
end

local function child_elements(el)
    local out = {}
    for _, kid in ipairs(el.kids) do
        if is_element(kid) then
            out[#out + 1] = kid
        end
    end
    return out
end

local function is_dc(el, localname)
    return is_element(el) and el.name == localname and (el.nsURI == DC_NS or el.nsPrefix == "dc")
end

local function is_meta(el)
    return is_element(el) and el.name == "meta"
end

local function attr_get(el, name)
    return el.attr and el.attr[name]
end

local function attr_set(el, name, value)
    el.attr = el.attr or {}
    el.attr[name] = value
    for _, a in ipairs(el.attr) do
        if a.name == name and not a.nsPrefix then
            a.value = value
            return
        end
    end
    table.insert(el.attr, { type = "attribute", name = name, value = value })
end

local function get_text(el)
    local parts = {}
    for _, kid in ipairs(el.kids) do
        if kid.type == "text" then
            parts[#parts + 1] = kid.value
        end
    end
    return table.concat(parts)
end

local function set_text(el, value)
    el.kids = { { type = "text", name = "#text", value = value } }
end

local function new_element(name, nsPrefix, attrs, text)
    local el = { type = "element", name = name, nsPrefix = nsPrefix, kids = {}, attr = {} }
    for _, a in ipairs(attrs or {}) do
        el.attr[a[1]] = a[2]
        table.insert(el.attr, { type = "attribute", name = a[1], value = a[2] })
    end
    if text ~= nil then
        el.kids = { { type = "text", name = "#text", value = text } }
    end
    return el
end

local function append_child(metadata, el)
    table.insert(metadata.kids, { type = "text", name = "#text", value = "\n    " })
    table.insert(metadata.kids, el)
end

local function find_metadata(pkg)
    for _, el in ipairs(child_elements(pkg)) do
        if el.name == "metadata" then
            return el
        end
    end
    return nil
end

local function detect_dc_prefix(metadata)
    for _, el in ipairs(child_elements(metadata)) do
        if el.nsURI == DC_NS and el.nsPrefix then
            return el.nsPrefix
        end
    end
    return "dc"
end

local function fmt_index(v)
    if v == nil then
        return nil
    end
    local n = tonumber(v)
    if n then
        if n == math.floor(n) then
            return tostring(math.floor(n))
        end
        return tostring(n)
    end
    return tostring(v)
end

local function find_meta(metadata, predicate)
    for _, el in ipairs(child_elements(metadata)) do
        if is_meta(el) and predicate(el) then
            return el
        end
    end
    return nil
end

local function set_dc_text(metadata, localname, prefix, value)
    for _, el in ipairs(child_elements(metadata)) do
        if is_dc(el, localname) then
            set_text(el, value)
            return
        end
    end
    append_child(metadata, new_element(localname, prefix, nil, value))
end

local function remove_dc(metadata, localname)
    local kept = {}
    for _, kid in ipairs(metadata.kids) do
        if not is_dc(kid, localname) then
            kept[#kept + 1] = kid
        end
    end
    metadata.kids = kept
end

local function set_creators(metadata, prefix, authors)
    remove_dc(metadata, "creator")
    for _, author in ipairs(authors) do
        append_child(metadata, new_element("creator", prefix, nil, author))
    end
end

local function set_subjects(metadata, prefix, genres)
    remove_dc(metadata, "subject")
    for _, genre in ipairs(genres) do
        append_child(metadata, new_element("subject", prefix, nil, genre))
    end
end

local function remove_meta(metadata, predicate)
    local kept = {}
    for _, kid in ipairs(metadata.kids) do
        if not (is_meta(kid) and predicate(kid)) then
            kept[#kept + 1] = kid
        end
    end
    metadata.kids = kept
end

local function set_calibre_series(metadata, series, series_index)
    remove_meta(metadata, function(el)
        local name = attr_get(el, "name")
        return name == "calibre:series" or name == "calibre:series_index"
    end)

    append_child(metadata, new_element("meta", nil, {
        { "name", "calibre:series" },
        { "content", series },
    }))

    local idx = fmt_index(series_index)
    if idx then
        append_child(metadata, new_element("meta", nil, {
            { "name", "calibre:series_index" },
            { "content", idx },
        }))
    end
end

local function set_epub3_series(metadata, series, series_index)
    local coll_el = find_meta(metadata, function(el)
        return attr_get(el, "property") == "belongs-to-collection"
    end)
    local coll_id
    if coll_el then
        coll_id = attr_get(coll_el, "id")
        if not coll_id or coll_id == "" then
            coll_id = "rebind-series"
            attr_set(coll_el, "id", coll_id)
        end
        set_text(coll_el, series)
    else
        coll_id = "rebind-series"
        append_child(metadata, new_element("meta", nil, {
            { "property", "belongs-to-collection" },
            { "id", coll_id },
        }, series))
    end

    local refines = "#" .. coll_id
    local type_el = find_meta(metadata, function(el)
        return attr_get(el, "refines") == refines and attr_get(el, "property") == "collection-type"
    end)
    if type_el then
        set_text(type_el, "series")
    else
        append_child(metadata, new_element("meta", nil, {
            { "refines", refines },
            { "property", "collection-type" },
        }, "series"))
    end

    local idx = fmt_index(series_index)
    if idx then
        local pos_el = find_meta(metadata, function(el)
            return attr_get(el, "refines") == refines and attr_get(el, "property") == "group-position"
        end)
        if pos_el then
            set_text(pos_el, idx)
        else
            append_child(metadata, new_element("meta", nil, {
                { "refines", refines },
                { "property", "group-position" },
            }, idx))
        end
    end
end

local function clear_series(metadata)
    remove_meta(metadata, function(el)
        local name = attr_get(el, "name")
        return name == "calibre:series" or name == "calibre:series_index"
    end)

    local refines = {}
    for _, el in ipairs(child_elements(metadata)) do
        if is_meta(el) and attr_get(el, "property") == "belongs-to-collection" then
            local id = attr_get(el, "id")
            if id and id ~= "" then
                refines["#" .. id] = true
            end
        end
    end

    remove_meta(metadata, function(el)
        if attr_get(el, "property") == "belongs-to-collection" then
            return true
        end
        local r = attr_get(el, "refines")
        return r ~= nil and refines[r] == true
    end)
end

local function detect_isbn(txt)
    local s = txt:upper():gsub("[^0-9X]", "")
    if #s == 13 and s:match("^%d+$") then
        return "isbn_13", s
    end
    if #s == 10 and s:match("^%d%d%d%d%d%d%d%d%d[%dX]$") then
        return "isbn_10", s
    end
    return nil
end

local function extract_isbns(metadata)
    local isbn_13, isbn_10
    for _, el in ipairs(child_elements(metadata)) do
        if is_dc(el, "identifier") then
            local kind, value = detect_isbn(get_text(el))
            if kind == "isbn_13" and not isbn_13 then
                isbn_13 = value
            elseif kind == "isbn_10" and not isbn_10 then
                isbn_10 = value
            end
        end
    end
    return isbn_13, isbn_10
end

local function read_series(metadata)
    local series_el = find_meta(metadata, function(el)
        return attr_get(el, "name") == "calibre:series"
    end)
    if series_el then
        local idx_el = find_meta(metadata, function(el)
            return attr_get(el, "name") == "calibre:series_index"
        end)
        return attr_get(series_el, "content"), idx_el and attr_get(idx_el, "content")
    end

    local coll_el = find_meta(metadata, function(el)
        return attr_get(el, "property") == "belongs-to-collection"
    end)
    if coll_el then
        local coll_id = attr_get(coll_el, "id")
        local pos
        if coll_id then
            local refines = "#" .. coll_id
            local pos_el = find_meta(metadata, function(el)
                return attr_get(el, "refines") == refines and attr_get(el, "property") == "group-position"
            end)
            pos = pos_el and get_text(pos_el)
        end
        return get_text(coll_el), pos
    end

    return nil, nil
end

local function first_dc_text(metadata, localname)
    for _, el in ipairs(child_elements(metadata)) do
        if is_dc(el, localname) then
            return get_text(el)
        end
    end
    return nil
end

local function opf_path_from_container(container)
    return container:match('full%-path%s*=%s*"([^"]+)"')
        or container:match("full%-path%s*=%s*'([^']+)'")
end

local function parse_metadata(opf_xml)
    local ok, doc = pcall(function()
        return SLAXML:dom(opf_xml)
    end)
    if not ok or not doc or not doc.root then
        return nil, nil, "Could not parse OPF."
    end
    local metadata = find_metadata(doc.root)
    if not metadata then
        return nil, nil, "No <metadata> element in OPF."
    end
    return doc, metadata
end

local function open_reader(path)
    local reader = Archiver.Reader:new()
    if not reader:open(path) then
        return nil
    end
    return reader
end

local function extract_named(path, names)
    local reader = open_reader(path)
    if not reader then
        return nil, "Could not open EPUB."
    end
    local out = {}
    for entry in reader:iterate() do
        if names[entry.path] and out[entry.path] == nil then
            out[entry.path] = reader:extractToMemory(entry.path)
        end
    end
    reader:close()
    return out
end

function Epub.read_metadata(path)
    local got, err = extract_named(path, { ["META-INF/container.xml"] = true })
    if not got then
        return nil, err
    end
    local container = got["META-INF/container.xml"]
    if not container then
        return nil, "Missing META-INF/container.xml."
    end
    local opf_path = opf_path_from_container(container)
    if not opf_path then
        return nil, "Could not locate the OPF file."
    end
    local got_opf = extract_named(path, { [opf_path] = true })
    local opf_xml = got_opf and got_opf[opf_path]
    if not opf_xml then
        return nil, "Could not read the OPF file."
    end

    local _, metadata, err = parse_metadata(opf_xml)
    if not metadata then
        return nil, err
    end

    local series, series_index = read_series(metadata)
    local title = first_dc_text(metadata, "title")
    local description = first_dc_text(metadata, "description")
    local language = first_dc_text(metadata, "language")
    local publisher = first_dc_text(metadata, "publisher")
    local authors = {}
    for _, el in ipairs(child_elements(metadata)) do
        if is_dc(el, "creator") then
            authors[#authors + 1] = get_text(el)
        end
    end
    local genres = {}
    for _, el in ipairs(child_elements(metadata)) do
        if is_dc(el, "subject") then
            genres[#genres + 1] = get_text(el)
        end
    end
    local isbn_13, isbn_10 = extract_isbns(metadata)

    return {
        title = title,
        authors = authors,
        description = description,
        genres = genres,
        series = series,
        series_index = series_index,
        language = language,
        publisher = publisher,
        isbn_13 = isbn_13,
        isbn_10 = isbn_10,
    }
end

local function edit_opf(opf_xml, changes)
    local doc, metadata, err = parse_metadata(opf_xml)
    if not metadata then
        return nil, err
    end
    local prefix = detect_dc_prefix(metadata)

    local function apply_dc_text(localname, value)
        if value == nil then
            return
        end
        if value == "" then
            remove_dc(metadata, localname)
        else
            set_dc_text(metadata, localname, prefix, value)
        end
    end

    apply_dc_text("title", changes.title)
    if changes.authors ~= nil then
        set_creators(metadata, prefix, changes.authors)
    end
    if changes.genres ~= nil then
        set_subjects(metadata, prefix, changes.genres)
    end
    apply_dc_text("description", changes.description)
    apply_dc_text("language", changes.language)
    apply_dc_text("publisher", changes.publisher)
    if changes.series ~= nil then
        if changes.series == "" then
            clear_series(metadata)
        else
            set_calibre_series(metadata, changes.series, changes.series_index)
            set_epub3_series(metadata, changes.series, changes.series_index)
        end
    end

    local ok, out = pcall(function()
        return SLAXML:xml(doc)
    end)
    if not ok or not out then
        return nil, "Could not serialize the edited OPF."
    end
    return out
end

local function copy_file(src, dst)
    local fi = io.open(src, "rb")
    if not fi then
        return false
    end
    local data = fi:read("*a")
    fi:close()
    local fo = io.open(dst, "wb")
    if not fo then
        return false
    end
    fo:write(data)
    fo:close()
    return true
end

local function validate_epub(path, opf_path)
    local reader = open_reader(path)
    if not reader then
        return false
    end
    local first_path, mimetype, opf_xml
    for entry in reader:iterate() do
        if not first_path then
            first_path = entry.path
        end
        if entry.path == "mimetype" then
            mimetype = reader:extractToMemory(entry.path)
        elseif entry.path == opf_path then
            opf_xml = reader:extractToMemory(entry.path)
        end
    end
    reader:close()
    if first_path ~= "mimetype" then
        return false
    end
    if not mimetype or not mimetype:find("application/epub%+zip") then
        return false
    end
    if not opf_xml then
        return false
    end
    return (pcall(function()
        return SLAXML:dom(opf_xml)
    end))
end

function Epub.rewrite(path, changes, keep_backup)
    local got, err = extract_named(path, { ["META-INF/container.xml"] = true })
    if not got then
        return false, err
    end
    local container = got["META-INF/container.xml"]
    if not container then
        return false, "Missing META-INF/container.xml."
    end
    local opf_path = opf_path_from_container(container)
    if not opf_path then
        return false, "Could not locate the OPF file."
    end

    local reader = open_reader(path)
    if not reader then
        return false, "Could not open EPUB."
    end

    local tmp = path .. ".rebind.tmp"
    os.remove(tmp)
    local writer = Archiver.Writer:new{}
    if not writer:open(tmp, "epub") then
        reader:close()
        return false, "Could not create temporary EPUB."
    end

    writer:setZipCompression("store")
    writer:addFileFromMemory("mimetype", "application/epub+zip")
    writer:setZipCompression("deflate")

    local wrote_opf = false
    local edit_err
    for entry in reader:iterate() do
        if entry.path ~= "mimetype" and not edit_err then
            local content = reader:extractToMemory(entry.path)
            if content then
                if entry.path == opf_path then
                    local edited, e = edit_opf(content, changes)
                    if edited then
                        content = edited
                        wrote_opf = true
                    else
                        edit_err = e
                        content = nil
                    end
                end
                if content then
                    writer:addFileFromMemory(entry.path, content)
                end
            end
        end
    end
    writer:close()
    reader:close()

    if edit_err then
        os.remove(tmp)
        return false, edit_err
    end
    if not wrote_opf then
        os.remove(tmp)
        return false, "OPF entry was not found while repacking."
    end

    if not validate_epub(tmp, opf_path) then
        os.remove(tmp)
        return false, "The rewritten EPUB failed validation; the original was left untouched."
    end

    local backup = path .. ".rebind.bak"
    os.remove(backup)
    if not copy_file(path, backup) then
        os.remove(tmp)
        return false, "Could not create a backup; aborting to protect the original."
    end

    local ok_rename, rename_err = os.rename(tmp, path)
    if not ok_rename then
        os.remove(tmp)
        return false, "Could not replace the original: " .. tostring(rename_err)
    end

    if keep_backup == false then
        os.remove(backup)
        return true, nil
    end
    return true, backup
end

Epub._edit_opf = edit_opf

return Epub
