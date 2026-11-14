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

local OPF_LANGPUB = [[<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>Old Title</dc:title>
    <dc:creator>Old Author</dc:creator>
    <dc:language>fr</dc:language>
    <dc:publisher>Old House</dc:publisher>
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

local OPF_DATES = [[<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>Old Title</dc:title>
    <dc:date opf:event="modification">2020-01-02T03:04:05Z</dc:date>
    <dc:date opf:event="publication">2012-05-24T00:00:00Z</dc:date>
  </metadata>
  <manifest></manifest>
</package>]]

local OPF_UNMARKED_DATE = [[<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>Old Title</dc:title>
    <dc:date>1999-03-01</dc:date>
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

T["language and publisher replace existing ones without duplicating"] = function(a)
    local out = assert(Epub._edit_opf(OPF_LANGPUB, { language = "en", publisher = "Penguin" }))
    a.count_eq(out, "<dc:language>", 1)
    a.count_eq(out, "<dc:publisher>", 1)
    a.contains(out, "<dc:language>en</dc:language>")
    a.contains(out, "<dc:publisher>Penguin</dc:publisher>")
    a.not_contains(out, "Old House")
    a.not_contains(out, "<dc:language>fr<")
end

T["language and publisher are added when the OPF has neither"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { language = "en", publisher = "Chilton Books" }))
    a.count_eq(out, "<dc:language>", 1)
    a.contains(out, "<dc:language>en</dc:language>")
    a.contains(out, "<dc:publisher>Chilton Books</dc:publisher>")
end

T["publisher markup is escaped"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { publisher = 'Head & <b>Shoulders</b>' }))
    a.contains(out, "Head &amp; &lt;b&gt;Shoulders&lt;/b&gt;")
    a.not_contains(out, "<b>Shoulders</b>")
end

T["an empty language removes the dc:language element"] = function(a)
    local out = assert(Epub._edit_opf(OPF_LANGPUB, { language = "" }))
    a.not_contains(out, "<dc:language>")
    a.contains(out, "<dc:publisher>Old House</dc:publisher>")
    a.contains(out, "<dc:title>Old Title</dc:title>")
end

T["an empty publisher removes the dc:publisher element"] = function(a)
    local out = assert(Epub._edit_opf(OPF_LANGPUB, { publisher = "" }))
    a.not_contains(out, "<dc:publisher>")
    a.not_contains(out, "Old House")
    a.contains(out, "<dc:language>fr</dc:language>")
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

T["read_metadata reads the language and publisher"] = function(a)
    seed(OPF_LANGPUB)
    local md = assert(Epub.read_metadata("/fake/book.epub"))
    a.eq(md.language, "fr")
    a.eq(md.publisher, "Old House")
    unseed()
end

T["read_metadata reports a missing language and publisher as nil"] = function(a)
    seed(OPF2)
    local md = assert(Epub.read_metadata("/fake/book.epub"))
    a.eq(md.language, nil)
    a.eq(md.publisher, nil)
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

T["read_metadata reads First published from the publication dc:date"] = function(a)
    seed(OPF_DATES)
    local md = assert(Epub.read_metadata("/fake/book.epub"))
    a.eq(md.first_published, "2012")
    unseed()
end

T["read_metadata falls back to the first dc:date when none is marked publication"] = function(a)
    seed(OPF_UNMARKED_DATE)
    local md = assert(Epub.read_metadata("/fake/book.epub"))
    a.eq(md.first_published, "1999")
    unseed()
end

T["writing First published replaces only the publication dc:date"] = function(a)
    local out = assert(Epub._edit_opf(OPF_DATES, { first_published = "1983" }))
    a.contains(out, '<dc:date opf:event="publication">1983</dc:date>')
    a.contains(out, '<dc:date opf:event="modification">2020-01-02T03:04:05Z</dc:date>')
    a.not_contains(out, "2012")
end

T["writing First published adds a dc:date when the OPF has none"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { first_published = "1983" }))
    a.count_eq(out, "<dc:date", 1)
    a.contains(out, "<dc:date>1983</dc:date>")
end

T["clearing First published removes only the publication dc:date"] = function(a)
    local out = assert(Epub._edit_opf(OPF_DATES, { first_published = "" }))
    a.count_eq(out, "<dc:date", 1)
    a.not_contains(out, "2012")
    a.contains(out, '<dc:date opf:event="modification">2020-01-02T03:04:05Z</dc:date>')
end

T["leaving First published unselected keeps a full date"] = function(a)
    local out = assert(Epub._edit_opf(OPF_UNMARKED_DATE, { title = "New" }))
    a.contains(out, "<dc:date>1999-03-01</dc:date>")
end

local Images = require("tests/support/images")

local OPF3_BOOK = [[<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="pub-id">urn:isbn:9780441013593</dc:identifier>
    <dc:title>Old Title</dc:title>
  </metadata>
  <manifest>
    <item id="c1" href="c1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="c1"/></spine>
</package>]]

local OPF2_BOOK = [[<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>Old Title</dc:title>
  </metadata>
  <manifest>
    <item id="c1" href="c1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx"><itemref idref="c1"/></spine>
</package>]]

local OPF3_WITH_COVER = [[<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Old Title</dc:title>
  </metadata>
  <manifest>
    <item id="cover" href="images/cover.jpg" media-type="image/jpeg" properties="cover-image"/>
  </manifest>
  <spine></spine>
</package>]]

local OPF2_WITH_COVER = [[<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Old Title</dc:title>
    <meta name="cover" content="cover-img"/>
  </metadata>
  <manifest>
    <item id="cover-img" href="cover.png" media-type="image/png"/>
  </manifest>
  <spine></spine>
</package>]]

local NEW_COVER = {
    bytes = Images.jpeg(400, 600),
    extension = "jpg",
    media_type = "image/jpeg",
    url = "https://assets.test/dune.jpg",
}

local function spine_of(opf)
    return opf:match("<spine.-</spine>")
end

T["adding a cover to an epub3 book points the cover-image marker and the cover meta at the new image"] = function(a)
    local out, entry = Epub._edit_opf(OPF3_BOOK, { cover = NEW_COVER }, "OEBPS/content.opf")
    a.eq(entry, "OEBPS/rebind-cover.jpg")
    a.contains(out, 'id="rebind-cover"')
    a.contains(out, 'href="rebind-cover.jpg"')
    a.contains(out, 'media-type="image/jpeg"')
    a.contains(out, 'properties="cover-image"')
    a.contains(out, '<meta name="cover" content="rebind-cover"')
end

T["adding a cover records the source url and no original cover"] = function(a)
    local out = Epub._edit_opf(OPF3_BOOK, { cover = NEW_COVER }, "OEBPS/content.opf")
    a.contains(out, '<meta name="rebind:cover-source" content="https://assets.test/dune.jpg"')
    a.contains(out, '<meta name="rebind:original-cover" content="none"')
end

T["adding a cover never touches the spine"] = function(a)
    local out = Epub._edit_opf(OPF3_BOOK, { cover = NEW_COVER }, "OEBPS/content.opf")
    a.eq(spine_of(out), spine_of(OPF3_BOOK))
    a.eq(spine_of(Epub._edit_opf(OPF2_BOOK, { cover = NEW_COVER }, "content.opf")), spine_of(OPF2_BOOK))
end

T["adding a cover to an epub2 book sets the cover meta without epub3 properties"] = function(a)
    local out, entry = Epub._edit_opf(OPF2_BOOK, { cover = NEW_COVER }, "content.opf")
    a.eq(entry, "rebind-cover.jpg")
    a.contains(out, '<meta name="cover" content="rebind-cover"')
    a.not_contains(out, "properties=")
end

T["a png cover is stored under a png name"] = function(a)
    local cover = { bytes = Images.png(400, 600), extension = "png", media_type = "image/png", url = "u" }
    local out, entry = Epub._edit_opf(OPF3_BOOK, { cover = cover }, "OEBPS/content.opf")
    a.eq(entry, "OEBPS/rebind-cover.png")
    a.contains(out, 'media-type="image/png"')
end

T["a cover is added to an opf with an empty manifest"] = function(a)
    local out = assert(Epub._edit_opf(OPF2, { cover = NEW_COVER }, "content.opf"))
    a.contains(out, 'href="rebind-cover.jpg"')
end

T["writing a cover next to other changes keeps both"] = function(a)
    local out = Epub._edit_opf(OPF3_BOOK, { cover = NEW_COVER, title = "Dune" }, "OEBPS/content.opf")
    a.contains(out, "<dc:title>Dune</dc:title>")
    a.contains(out, 'href="rebind-cover.jpg"')
end

local OPF3_COVER_PAGE = [[<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Old Title</dc:title>
  </metadata>
  <manifest>
    <item id="cover" href="images/cover.jpg" media-type="image/jpeg" properties="cover-image"/>
    <item id="coverpage" href="text/cover.xhtml" media-type="application/xhtml+xml"/>
    <item id="c1" href="c1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="coverpage"/><itemref idref="c1"/></spine>
</package>]]

local function replaced(opf, cover)
    return Epub._edit_opf(opf, { cover = cover or NEW_COVER }, "OEBPS/content.opf")
end

T["replacing an epub3 cover points the cover-image marker at the new image and keeps the old one as the original"] = function(a)
    local out, entry, plan = replaced(OPF3_COVER_PAGE)
    a.eq(entry, "OEBPS/rebind-cover.jpg")
    a.count_eq(out, 'properties="cover-image"', 1)
    a.contains(out, '<item id="rebind-cover" href="rebind-cover.jpg" media-type="image/jpeg" properties="cover-image"')
    a.contains(out, '<item id="cover" href="images/cover.jpg" media-type="image/jpeg"/>')
    a.contains(out, '<meta name="cover" content="rebind-cover"')
    a.contains(out, '<meta name="rebind:original-cover" content="cover"')
    a.contains(out, '<meta name="rebind:cover-source" content="https://assets.test/dune.jpg"')
    a.eq(spine_of(out), spine_of(OPF3_COVER_PAGE))
    a.is_true(plan.pages["OEBPS/text/cover.xhtml"])
    a.eq(plan.from, "OEBPS/images/cover.jpg")
    a.eq(plan.to, "OEBPS/rebind-cover.jpg")
end

T["replacing an epub2 cover points the cover meta at the new image and keeps the old one as the original"] = function(a)
    local out, entry = Epub._edit_opf(OPF2_WITH_COVER, { cover = NEW_COVER }, "content.opf")
    a.eq(entry, "rebind-cover.jpg")
    a.count_eq(out, 'name="cover"', 1)
    a.contains(out, '<meta name="cover" content="rebind-cover"')
    a.contains(out, '<item id="cover-img" href="cover.png" media-type="image/png"/>')
    a.contains(out, '<meta name="rebind:original-cover" content="cover-img"')
end

T["replacing twice keeps the cover from before the first change as the original"] = function(a)
    local first = replaced(OPF3_COVER_PAGE)
    local png = { bytes = Images.png(400, 600), extension = "png", media_type = "image/png", url = "https://assets.test/b.png" }
    local out, entry, plan = replaced(first, png)
    a.eq(entry, "OEBPS/rebind-cover.png")
    a.count_eq(out, 'id="rebind-cover"', 1)
    a.count_eq(out, 'properties="cover-image"', 1)
    a.contains(out, 'href="rebind-cover.png"')
    a.not_contains(out, "rebind-cover.jpg")
    a.contains(out, '<meta name="rebind:original-cover" content="cover"')
    a.contains(out, '<meta name="rebind:cover-source" content="https://assets.test/b.png"')
    a.is_true(plan.drop["OEBPS/rebind-cover.jpg"])
    a.eq(plan.from, "OEBPS/rebind-cover.jpg")
end

T["replacing a cover that was added from nothing keeps the original as no cover"] = function(a)
    local first = replaced(OPF3_BOOK)
    local out = replaced(first, { bytes = Images.png(400, 600), extension = "png", media_type = "image/png", url = "b" })
    a.contains(out, '<meta name="rebind:original-cover" content="none"')
    a.count_eq(out, 'id="rebind-cover"', 1)
end

T["read_metadata reports a book without a cover"] = function(a)
    seed(OPF3_BOOK)
    local md = assert(Epub.read_metadata("/fake/book.epub"))
    a.eq(md.has_cover, false)
    a.eq(md.cover_source, nil)
    a.eq(md.original_cover, nil)
    unseed()
end

T["read_metadata sees an epub3 cover-image and an epub2 cover meta"] = function(a)
    seed(OPF3_WITH_COVER)
    a.eq(assert(Epub.read_metadata("/fake/book.epub")).has_cover, true)
    seed(OPF2_WITH_COVER)
    a.eq(assert(Epub.read_metadata("/fake/book.epub")).has_cover, true)
    unseed()
end

T["read_metadata reads back the cover Rebind wrote"] = function(a)
    local out = Epub._edit_opf(OPF3_BOOK, { cover = NEW_COVER }, "OEBPS/content.opf")
    seed(out)
    local md = assert(Epub.read_metadata("/fake/book.epub"))
    a.eq(md.has_cover, true)
    a.eq(md.cover_source, "https://assets.test/dune.jpg")
    a.eq(md.original_cover, "none")
    unseed()
end

T["rewrite embeds the cover exactly as downloaded after the mimetype entry"] = function(a)
    local path = os.tmpname()
    local f = assert(io.open(path, "wb"))
    f:write("original")
    f:close()
    seed(OPF3_BOOK)
    _G.__TEST_FS["OEBPS/c1.xhtml"] = "<html/>"
    _G.__TEST_ORDER = { "mimetype", "META-INF/container.xml", "OEBPS/content.opf", "OEBPS/c1.xhtml" }
    _G.__TEST_FS["mimetype"] = "application/epub+zip"
    local rename = os.rename
    os.rename = function() return true end
    local ok = Epub.rewrite(path, { cover = NEW_COVER }, false)
    os.rename = rename
    local writes = _G.__TEST_WRITES
    unseed()
    os.remove(path)
    os.remove(path .. ".rebind.bak")
    a.is_true(ok)
    a.eq(writes[1].path, "mimetype")
    local image
    for _, entry in ipairs(writes) do
        if entry.path == "OEBPS/rebind-cover.jpg" then
            image = entry
        end
    end
    a.is_true(image)
    a.eq(image.content, NEW_COVER.bytes)
end

local OLD_IMAGE = Images.jpeg(300, 450, 3000)

local function seed_cover_book(opf, page)
    seed(opf)
    _G.__TEST_FS["mimetype"] = "application/epub+zip"
    _G.__TEST_FS["OEBPS/images/cover.jpg"] = OLD_IMAGE
    _G.__TEST_FS["OEBPS/text/cover.xhtml"] = page
    _G.__TEST_FS["OEBPS/c1.xhtml"] = "<html/>"
    _G.__TEST_ORDER = {
        "mimetype", "META-INF/container.xml", "OEBPS/text/cover.xhtml", "OEBPS/content.opf",
        "OEBPS/images/cover.jpg", "OEBPS/c1.xhtml",
    }
end

local function rewrite_book(changes)
    local path = os.tmpname()
    local f = assert(io.open(path, "wb"))
    f:write("original")
    f:close()
    local rename = os.rename
    os.rename = function() return true end
    local ok = Epub.rewrite(path, changes, false)
    os.rename = rename
    os.remove(path)
    os.remove(path .. ".rebind.bak")
    local by_path = {}
    for _, entry in ipairs(_G.__TEST_WRITES or {}) do
        by_path[entry.path] = entry.content
    end
    return ok, by_path
end

T["rewrite points the cover page at the new image and keeps the old image"] = function(a)
    seed_cover_book(OPF3_COVER_PAGE, '<html><body><img alt="c" src="../images/cover.jpg"/></body></html>')
    local ok, files = rewrite_book({ cover = NEW_COVER })
    unseed()
    a.is_true(ok)
    a.contains(files["OEBPS/text/cover.xhtml"], 'src="../rebind-cover.jpg"')
    a.not_contains(files["OEBPS/text/cover.xhtml"], "images/cover.jpg")
    a.eq(files["OEBPS/images/cover.jpg"], OLD_IMAGE)
    a.eq(files["OEBPS/rebind-cover.jpg"], NEW_COVER.bytes)
    a.eq(files["OEBPS/c1.xhtml"], "<html/>")
    a.contains(files["OEBPS/content.opf"], 'content="cover"')
end

T["rewrite repoints an svg cover page"] = function(a)
    seed_cover_book(OPF3_COVER_PAGE, '<svg><image width="1" xlink:href="../images/cover.jpg"/></svg>')
    local _, files = rewrite_book({ cover = NEW_COVER })
    unseed()
    a.contains(files["OEBPS/text/cover.xhtml"], 'xlink:href="../rebind-cover.jpg"')
end

T["rewrite leaves a first page that shows another image alone"] = function(a)
    local page = '<html><img src="../images/other.jpg"/></html>'
    seed_cover_book(OPF3_COVER_PAGE, page)
    local _, files = rewrite_book({ cover = NEW_COVER })
    unseed()
    a.eq(files["OEBPS/text/cover.xhtml"], page)
end

T["rewriting a replaced cover drops Rebind's previous image but keeps the original"] = function(a)
    local first = replaced(OPF3_COVER_PAGE)
    seed_cover_book(first, '<html><img src="../rebind-cover.jpg"/></html>')
    _G.__TEST_FS["OEBPS/rebind-cover.jpg"] = "previous"
    table.insert(_G.__TEST_ORDER, "OEBPS/rebind-cover.jpg")
    local png = { bytes = Images.png(400, 600), extension = "png", media_type = "image/png", url = "u" }
    local ok, files = rewrite_book({ cover = png })
    unseed()
    a.is_true(ok)
    a.eq(files["OEBPS/rebind-cover.jpg"], nil)
    a.eq(files["OEBPS/rebind-cover.png"], png.bytes)
    a.eq(files["OEBPS/images/cover.jpg"], OLD_IMAGE)
    a.contains(files["OEBPS/text/cover.xhtml"], 'src="../rebind-cover.png"')
end

T["read_metadata can read the current and the kept original cover images"] = function(a)
    local first = replaced(OPF3_COVER_PAGE)
    seed_cover_book(first, "<html/>")
    _G.__TEST_FS["OEBPS/rebind-cover.jpg"] = NEW_COVER.bytes
    table.insert(_G.__TEST_ORDER, "OEBPS/rebind-cover.jpg")
    local md = assert(Epub.read_metadata("/fake/book.epub", { cover_image = true }))
    a.eq(md.cover_image.width, 400)
    a.eq(md.cover_image.height, 600)
    a.eq(md.cover_image.bytes, NEW_COVER.bytes)
    a.eq(md.cover_source, "https://assets.test/dune.jpg")
    a.eq(md.original_cover, "cover")
    seed_cover_book(OPF3_COVER_PAGE, "<html/>")
    md = assert(Epub.read_metadata("/fake/book.epub", { cover_image = true }))
    a.eq(md.cover_image.width, 300)
    a.eq(md.cover_image.size, #OLD_IMAGE)
    md = assert(Epub.read_metadata("/fake/book.epub"))
    a.eq(md.cover_image, nil)
    a.eq(md.has_cover, true)
    unseed()
end

local function opf_with_manifest(items, extra_meta, version)
    return '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="' .. (version or "3.0") .. '">'
        .. '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>T</dc:title>' .. (extra_meta or "") .. '</metadata>'
        .. "<manifest>" .. items .. "</manifest><spine></spine></package>"
end

T["a manifest item that only borrows Rebind's cover id is never dropped from the archive"] = function(a)
    local opf = opf_with_manifest(
        '<item id="rebind-cover" href="chapter3.xhtml" media-type="image/jpeg" properties="cover-image"/>'
    )
    local out, err = replaced(opf)
    a.eq(out, nil)
    a.is_true(err)
end

T["an own cover left in the manifest is replaced even when another item holds the cover marker"] = function(a)
    local opf = opf_with_manifest(
        '<item id="rebind-cover" href="rebind-cover.jpg" media-type="image/jpeg"/>'
            .. '<item id="other" href="o.png" media-type="image/png" properties="cover-image"/>',
        '<meta name="rebind:original-cover" content="cover"/>'
    )
    local out, _, plan = replaced(opf)
    a.count_eq(out, 'id="rebind-cover"', 1)
    a.contains(out, '<meta name="rebind:original-cover" content="cover"')
    a.is_true(plan.drop["OEBPS/rebind-cover.jpg"])
end

T["a package path that climbs out of the archive is refused"] = function(a)
    local out, err = Epub._edit_opf(OPF3_BOOK, { cover = NEW_COVER }, "../../x/content.opf")
    a.eq(out, nil)
    a.is_true(err)
end

T["rewrite leaves an image reference that climbs out of the archive alone"] = function(a)
    local page = '<html><img src="../../../OEBPS/images/cover.jpg"/></html>'
    seed_cover_book(OPF3_COVER_PAGE, page)
    local _, files = rewrite_book({ cover = NEW_COVER })
    unseed()
    a.eq(files["OEBPS/text/cover.xhtml"], page)
end

T["rewrite repoints a cover page that is not the first spine item"] = function(a)
    local opf = OPF3_COVER_PAGE:gsub('<spine><itemref idref="coverpage"/><itemref idref="c1"/></spine>', '<spine><itemref idref="c1"/><itemref idref="coverpage"/></spine>')
    seed_cover_book(opf, '<html><img src="../images/cover.jpg"/></html>')
    local _, files = rewrite_book({ cover = NEW_COVER })
    unseed()
    a.contains(files["OEBPS/text/cover.xhtml"], 'src="../rebind-cover.jpg"')
end

T["rewrite repoints the cover page the guide names in an epub2 book"] = function(a)
    local opf = OPF2_WITH_COVER:gsub("<spine></spine>", '<spine><itemref idref="c1"/></spine><guide><reference type="cover" href="text/cover.xhtml"/></guide>')
    opf = opf:gsub('href="cover.png"', 'href="images/cover.jpg"'):gsub('image/png', 'image/jpeg')
    seed_cover_book(opf, '<html><img src="../images/cover.jpg"/></html>')
    local _, files = rewrite_book({ cover = NEW_COVER })
    unseed()
    a.contains(files["OEBPS/text/cover.xhtml"], 'src="../rebind-cover.jpg"')
    a.contains(files["OEBPS/content.opf"], '<meta name="cover" content="rebind-cover"')
end

T["a huge cover page without any closing bracket is scanned in linear time"] = function(a)
    seed_cover_book(OPF3_COVER_PAGE, string.rep("<a ", 40000))
    local started = os.clock()
    local ok = rewrite_book({ cover = NEW_COVER })
    local elapsed = os.clock() - started
    unseed()
    a.is_true(ok)
    a.is_true(elapsed < 0.5)
end

T["an item that borrows Rebind's cover id but is not a jpeg or png image is refused"] = function(a)
    local opf = opf_with_manifest('<item id="rebind-cover" href="rebind-cover.xhtml" media-type="application/xhtml+xml"/>')
    local out, err = replaced(opf)
    a.eq(out, nil)
    a.is_true(err)
end

T["a cover item without an id gets one so the original can be named"] = function(a)
    local opf = opf_with_manifest('<item href="images/cover.jpg" media-type="image/jpeg" properties="cover-image"/>')
    local out = replaced(opf)
    a.contains(out, 'id="rebind-original-cover"')
    a.contains(out, '<meta name="rebind:original-cover" content="rebind-original-cover"')
end

T["rewrite repoints a cover image whose name holds an apostrophe"] = function(a)
    local opf = OPF3_COVER_PAGE:gsub("images/cover.jpg", "images/o'cover.jpg")
    seed_cover_book(opf, [[<html><img src="../images/o'cover.jpg"/></html>]])
    local _, files = rewrite_book({ cover = NEW_COVER })
    unseed()
    a.contains(files["OEBPS/text/cover.xhtml"], 'src="../rebind-cover.jpg"')
end

T["a book with thousands of spine items is planned in linear time"] = function(a)
    local items, refs = { '<item id="cover" href="images/cover.jpg" media-type="image/jpeg" properties="cover-image"/>' }, {}
    for n = 1, 4000 do
        items[#items + 1] = '<item id="c' .. n .. '" href="c' .. n .. '.xhtml" media-type="application/xhtml+xml"/>'
        refs[#refs + 1] = '<itemref idref="c' .. n .. '"/>'
    end
    local opf = opf_with_manifest(table.concat(items)):gsub("<spine></spine>", "<spine>" .. table.concat(refs) .. "</spine>")
    local started = os.clock()
    local out = replaced(opf)
    local elapsed = os.clock() - started
    a.is_true(out)
    a.is_true(elapsed < 0.5)
end

return T
