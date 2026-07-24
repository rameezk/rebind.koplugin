local Epub = require("rebind/epub")

local CONTAINER = [[<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>]]

local OPF2 = [[<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>Old Title</dc:title>
    <dc:creator opf:role="aut">Old Author</dc:creator>
    <dc:identifier id="BookId" opf:scheme="ISBN">978-0-441-01359-3</dc:identifier>
    <meta name="calibre:series" content="Old Series"/>
    <meta name="calibre:series_index" content="3"/>
  </metadata>
  <manifest></manifest>
</package>]]

local OPF3 = [[<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="pub-id">urn:isbn:9780441013593</dc:identifier>
    <dc:title>Old Title</dc:title>
    <dc:creator>Old Author</dc:creator>
    <meta property="belongs-to-collection" id="c01">Old Series</meta>
    <meta refines="#c01" property="collection-type">series</meta>
    <meta refines="#c01" property="group-position">2</meta>
  </metadata>
  <manifest></manifest>
</package>]]

local OPF_ISBN10 = [[<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>Ten Digit</dc:title>
    <dc:creator>A</dc:creator>
    <dc:identifier opf:scheme="ISBN">0-8044-2957-X</dc:identifier>
  </metadata>
  <manifest></manifest>
</package>]]

local OPF_DESC = [[<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>Old Title</dc:title>
    <dc:creator>Old Author</dc:creator>
    <dc:description>Old blurb.</dc:description>
  </metadata>
  <manifest></manifest>
</package>]]

local OPF_GENRES = [[<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>Old Title</dc:title>
    <dc:creator>Old Author</dc:creator>
    <dc:subject>Horror</dc:subject>
    <dc:subject>Thriller</dc:subject>
  </metadata>
  <manifest></manifest>
</package>]]

local OPF_WRONGORDER = [[<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>Old Title</dc:title>
    <dc:creator>Old Author</dc:creator>
    <meta name="calibre:series_index" content="3"/>
    <meta name="calibre:series" content="Old Series"/>
  </metadata>
  <manifest></manifest>
</package>]]

local function seed(opf)
    _G.__TEST_FS = {
        ["META-INF/container.xml"] = CONTAINER,
        ["OEBPS/content.opf"] = opf,
    }
    _G.__TEST_ORDER = { "mimetype", "META-INF/container.xml", "OEBPS/content.opf" }
end

local function unseed()
    _G.__TEST_FS = nil
    _G.__TEST_ORDER = nil
end

local T = {}

T["epub2 updates title in place without duplicating"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { title = "Dune" }))
    a.count_eq(out, "<dc:title>", 1)
    a.contains(out, "<dc:title>Dune</dc:title>")
    a.not_contains(out, "Old Title")
end

T["epub2 replaces multiple creators without duplicating"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { authors = { "Frank Herbert", "Someone Else" } }))
    a.count_eq(out, "<dc:creator", 2)
    a.contains(out, "Frank Herbert")
    a.contains(out, "Someone Else")
    a.not_contains(out, "Old Author")
end

T["description replaces an existing one without duplicating"] = function(a)
    local out = assert(Epub._edit_opf(OPF_DESC, { description = "New blurb." }))
    a.count_eq(out, "<dc:description>", 1)
    a.contains(out, "<dc:description>New blurb.</dc:description>")
    a.not_contains(out, "Old blurb.")
end

T["description is added when the OPF has none"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { description = "Fresh blurb." }))
    a.count_eq(out, "<dc:description>", 1)
    a.contains(out, "Fresh blurb.")
end

T["description markup is escaped"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { description = 'A <b>bold</b> & "quoted" blurb.' }))
    a.contains(out, "A &lt;b&gt;bold&lt;/b&gt; &amp;")
    a.not_contains(out, "<b>bold</b>")
end

T["genres replace existing subjects without duplicating"] = function(a)
    local out = assert(Epub._edit_opf(OPF_GENRES, { genres = { "Fantasy", "Adventure" } }))
    a.count_eq(out, "<dc:subject>", 2)
    a.contains(out, "<dc:subject>Fantasy</dc:subject>")
    a.contains(out, "<dc:subject>Adventure</dc:subject>")
    a.not_contains(out, "Horror")
    a.not_contains(out, "Thriller")
end

T["genres are added when the OPF has none"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { genres = { "Science Fiction" } }))
    a.count_eq(out, "<dc:subject>", 1)
    a.contains(out, "Science Fiction")
end

T["genre markup is escaped"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { genres = { 'A & <b>B</b>' } }))
    a.contains(out, "A &amp; &lt;b&gt;B&lt;/b&gt;")
    a.not_contains(out, "<b>B</b>")
end

T["an empty genre list removes every dc:subject"] = function(a)
    local out = assert(Epub._edit_opf(OPF_GENRES, { genres = {} }))
    a.not_contains(out, "<dc:subject>")
    a.not_contains(out, "Horror")
    a.contains(out, "<dc:title>Old Title</dc:title>")
end

T["epub2 updates calibre series and adds epub3 series"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { series = "Dune", series_index = 1 }))
    a.count_eq(out, 'name="calibre:series"', 1)
    a.contains(out, 'name="calibre:series" content="Dune"')
    a.contains(out, 'name="calibre:series_index" content="1"')
    a.contains(out, 'property="belongs-to-collection"')
    a.contains(out, ">Dune</meta>")
    a.contains(out, 'property="group-position">1<')
end

T["epub3 updates belongs-to-collection in place and adds calibre"] = function(a)
    local out = assert(Epub._edit_opf(OPF3, { series = "Foundation", series_index = 1.5 }))
    a.count_eq(out, 'property="belongs-to-collection"', 1)
    a.contains(out, ">Foundation</meta>")
    a.count_eq(out, 'property="collection-type"', 1)
    a.count_eq(out, 'property="group-position"', 1)
    a.contains(out, 'property="group-position">1.5<')
    a.contains(out, 'refines="#c01"')
    a.contains(out, 'name="calibre:series" content="Foundation"')
end

T["unselected fields are left unchanged"] = function(a)
    local out = assert(Epub._edit_opf(OPF3, { series = "Foundation", series_index = 1 }))
    a.contains(out, "<dc:title>Old Title</dc:title>")
    a.contains(out, "Old Author")
end

T["integer series index is not written as a float"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { series = "Dune", series_index = 2 }))
    a.contains(out, 'name="calibre:series_index" content="2"')
    a.not_contains(out, 'content="2.0"')
end

T["calibre series tag is written before series_index (crengine requirement)"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { series = "Dune", series_index = 1 }))
    local ps = out:find('name="calibre:series"', 1, true)
    local pi = out:find('name="calibre:series_index"', 1, true)
    a.is_true(ps ~= nil and pi ~= nil, "both calibre tags present")
    a.is_true(ps < pi, "calibre:series must precede calibre:series_index")
end

T["corrects a reversed calibre series order from the source OPF"] = function(a)
    local out = assert(Epub._edit_opf(OPF_WRONGORDER, { series = "New Series", series_index = 2 }))
    a.count_eq(out, 'name="calibre:series"', 1)
    a.count_eq(out, 'name="calibre:series_index"', 1)
    a.contains(out, 'name="calibre:series" content="New Series"')
    a.contains(out, 'name="calibre:series_index" content="2"')
    local ps = out:find('name="calibre:series"', 1, true)
    local pi = out:find('name="calibre:series_index"', 1, true)
    a.is_true(ps < pi, "reversed order should be corrected to name-then-index")
end

T["an empty title removes the dc:title element"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { title = "" }))
    a.not_contains(out, "<dc:title>")
    a.not_contains(out, "Old Title")
    a.contains(out, "Old Author")
end

T["an empty description removes the dc:description element"] = function(a)
    local out = assert(Epub._edit_opf(OPF_DESC, { description = "" }))
    a.not_contains(out, "<dc:description>")
    a.not_contains(out, "Old blurb.")
    a.contains(out, "<dc:title>Old Title</dc:title>")
end

T["an empty author list removes every dc:creator"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { authors = {} }))
    a.not_contains(out, "<dc:creator")
    a.not_contains(out, "Old Author")
    a.contains(out, "<dc:title>Old Title</dc:title>")
end

T["an empty series removes the calibre tags"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { series = "" }))
    a.not_contains(out, "calibre:series")
    a.not_contains(out, "Old Series")
    a.contains(out, "<dc:title>Old Title</dc:title>")
end

T["an empty series removes the epub3 collection tags"] = function(a)
    local out = assert(Epub._edit_opf(OPF3, { series = "" }))
    a.not_contains(out, "belongs-to-collection")
    a.not_contains(out, "collection-type")
    a.not_contains(out, "group-position")
    a.not_contains(out, "Old Series")
    a.contains(out, "<dc:title>Old Title</dc:title>")
end

T["clearing does not touch fields that were not selected"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { series = "" }))
    a.contains(out, "Old Author")
    a.contains(out, "978-0-441-01359-3")
end

T["is_epub matches only epub extensions"] = function(a)
    a.is_true(Epub.is_epub("/x/Book.EPUB"))
    a.is_true(Epub.is_epub("/x/book.epub"))
    a.is_true(not Epub.is_epub("/x/book.mobi"))
    a.is_true(not Epub.is_epub("/x/book.pdf"))
end

T["read_metadata parses container and opf"] = function(a)
    seed(OPF2)
    local md = assert(Epub.read_metadata("/fake/book.epub"))
    a.eq(md.title, "Old Title")
    a.eq(md.authors[1], "Old Author")
    a.eq(md.isbn_13, "9780441013593")
    a.eq(md.series, "Old Series")
    a.eq(tostring(md.series_index), "3")
    unseed()
end

T["read_metadata reads the description"] = function(a)
    seed(OPF_DESC)
    local md = assert(Epub.read_metadata("/fake/book.epub"))
    a.eq(md.description, "Old blurb.")
    unseed()
end

T["read_metadata reads genres from dc:subject"] = function(a)
    seed(OPF_GENRES)
    local md = assert(Epub.read_metadata("/fake/book.epub"))
    a.eq(#md.genres, 2)
    a.eq(md.genres[1], "Horror")
    a.eq(md.genres[2], "Thriller")
    unseed()
end

T["read_metadata reports no genres as an empty table"] = function(a)
    seed(OPF2)
    local md = assert(Epub.read_metadata("/fake/book.epub"))
    a.eq(type(md.genres), "table")
    a.eq(#md.genres, 0)
    unseed()
end

T["read_metadata reports a missing description as nil"] = function(a)
    seed(OPF3)
    local md = assert(Epub.read_metadata("/fake/book.epub"))
    a.eq(md.description, nil)
    unseed()
end

T["read_metadata reads epub3 series from belongs-to-collection"] = function(a)
    seed(OPF3)
    local md = assert(Epub.read_metadata("/fake/book.epub"))
    a.eq(md.series, "Old Series")
    a.eq(tostring(md.series_index), "2")
    a.eq(md.isbn_13, "9780441013593")
    unseed()
end

T["read_metadata detects isbn_10 with X check digit"] = function(a)
    seed(OPF_ISBN10)
    local md = assert(Epub.read_metadata("/fake/book.epub"))
    a.eq(md.isbn_10, "080442957X")
    a.eq(md.isbn_13, nil)
    unseed()
end

T["archiver entries are only extractable after iteration discovers them"] = function(a)
    local Archiver = require("ffi/archiver")
    _G.__TEST_FS = { ["a.txt"] = "hello" }
    _G.__TEST_ORDER = { "a.txt" }
    local reader = Archiver.Reader:new()
    reader:open("/fake")
    a.eq(reader:extractToMemory("a.txt"), nil)
    for _ in reader:iterate() do end
    a.eq(reader:extractToMemory("a.txt"), "hello")
    reader:close()
    unseed()
end

T["read_metadata finds container.xml when it is not the first entry"] = function(a)
    _G.__TEST_FS = {
        ["mimetype"] = "application/epub+zip",
        ["OEBPS/cover.xhtml"] = "<html></html>",
        ["META-INF/container.xml"] = CONTAINER,
        ["OEBPS/content.opf"] = OPF2,
    }
    _G.__TEST_ORDER = { "mimetype", "OEBPS/cover.xhtml", "META-INF/container.xml", "OEBPS/content.opf" }
    local md = assert(Epub.read_metadata("/fake/book.epub"))
    a.eq(md.title, "Old Title")
    a.eq(md.isbn_13, "9780441013593")
    unseed()
end

return T
