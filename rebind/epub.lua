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

local function is_publication_date(el)
    return attr_get(el, "event") == "publication" or attr_get(el, "opf:event") == "publication"
end

local function publication_date_element(metadata)
    local first
    for _, el in ipairs(child_elements(metadata)) do
        if is_dc(el, "date") then
            if is_publication_date(el) then
                return el
            end
            first = first or el
        end
    end
    return first
end

local function remove_element(metadata, target)
    local kept = {}
    for _, kid in ipairs(metadata.kids) do
        if kid ~= target then
            kept[#kept + 1] = kid
        end
    end
    metadata.kids = kept
end

local function set_first_published(metadata, prefix, year)
    local el = publication_date_element(metadata)
    if year == "" then
        if el then
            remove_element(metadata, el)
        end
    elseif el then
        set_text(el, year)
    else
        append_child(metadata, new_element("date", prefix, nil, year))
    end
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

local function read_first_published(metadata)
    local el = publication_date_element(metadata)
    return el and get_text(el):match("^%s*(%d%d%d%d)") or nil
end

local function find_child(pkg, name)
    for _, el in ipairs(child_elements(pkg)) do
        if el.name == name then
            return el
        end
    end
    return nil
end

local function has_token(value, token)
    for word in tostring(value or ""):gmatch("%S+") do
        if word == token then
            return true
        end
    end
    return false
end

local function manifest_item_by_id(manifest, id)
    for _, el in ipairs(child_elements(manifest)) do
        if el.name == "item" and attr_get(el, "id") == id then
            return el
        end
    end
    return nil
end

local function current_cover_item(pkg, metadata)
    local manifest = find_child(pkg, "manifest")
    if not manifest then
        return nil
    end
    for _, el in ipairs(child_elements(manifest)) do
        if el.name == "item" and has_token(attr_get(el, "properties"), "cover-image") then
            return el
        end
    end
    local marker = find_meta(metadata, function(el)
        return attr_get(el, "name") == "cover"
    end)
    local id = marker and attr_get(marker, "content")
    return id and manifest_item_by_id(manifest, id) or nil
end

local COVER_ID = "rebind-cover"
local SOURCE_META = "rebind:cover-source"
local ORIGINAL_META = "rebind:original-cover"

local function meta_content(metadata, name)
    local el = find_meta(metadata, function(e)
        return attr_get(e, "name") == name
    end)
    return el and attr_get(el, "content") or nil
end

local function dirname_of(path)
    return path:match("^(.*)/[^/]*$")
end

local function add_cover(pkg, metadata, cover, opf_path)
    if current_cover_item(pkg, metadata) then
        return nil, "The book already has a cover; replacing it is not supported yet."
    end
    local manifest = find_child(pkg, "manifest")
    if not manifest then
        return nil, "No <manifest> element in OPF."
    end
    local href = COVER_ID .. "." .. cover.extension
    local attrs = {
        { "id", COVER_ID },
        { "href", href },
        { "media-type", cover.media_type },
    }
    if tostring(attr_get(pkg, "version") or ""):sub(1, 1) == "3" then
        attrs[#attrs + 1] = { "properties", "cover-image" }
    end
    append_child(manifest, new_element("item", nil, attrs))

    remove_meta(metadata, function(el)
        local name = attr_get(el, "name")
        return name == "cover" or name == SOURCE_META or name == ORIGINAL_META
    end)
    append_child(metadata, new_element("meta", nil, { { "name", "cover" }, { "content", COVER_ID } }))
    append_child(metadata, new_element("meta", nil, { { "name", SOURCE_META }, { "content", cover.url or "" } }))
    append_child(metadata, new_element("meta", nil, { { "name", ORIGINAL_META }, { "content", "none" } }))

    local dir = dirname_of(opf_path or "")
    return dir and (dir .. "/" .. href) or href
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

    local doc, metadata, err = parse_metadata(opf_xml)
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
        first_published = read_first_published(metadata),
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
        has_cover = current_cover_item(doc.root, metadata) ~= nil,
        cover_source = meta_content(metadata, SOURCE_META),
        original_cover = meta_content(metadata, ORIGINAL_META),
    }
end

local function edit_opf(opf_xml, changes, opf_path)
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
    if changes.first_published ~= nil then
        set_first_published(metadata, prefix, changes.first_published)
    end
    if changes.series ~= nil then
        if changes.series == "" then
            clear_series(metadata)
        else
            set_calibre_series(metadata, changes.series, changes.series_index)
            set_epub3_series(metadata, changes.series, changes.series_index)
        end
    end

    local cover_entry
    if changes.cover then
        cover_entry, err = add_cover(doc.root, metadata, changes.cover, opf_path)
        if not cover_entry then
            return nil, err
        end
    end

    local ok, out = pcall(function()
        return SLAXML:xml(doc)
    end)
    if not ok or not out then
        return nil, "Could not serialize the edited OPF."
    end
    return out, cover_entry
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
    local cover_entry
    local edit_err
    for entry in reader:iterate() do
        if entry.path ~= "mimetype" and not edit_err then
            local content = reader:extractToMemory(entry.path)
            if content then
                if entry.path == opf_path then
                    local edited, e = edit_opf(content, changes, opf_path)
                    if edited then
                        content = edited
                        cover_entry = e
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
    if cover_entry and not edit_err then
        writer:addFileFromMemory(cover_entry, changes.cover.bytes)
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
