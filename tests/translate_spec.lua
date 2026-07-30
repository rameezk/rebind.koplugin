local Fields = require("rebind/fields")
local Translate = require("rebind/translate")

local SUPPORTED = {
    en = "English",
    es = "Spanish",
    fr = "French",
    de = "German",
    af = "Afrikaans",
}

local ALIASES = { eng = "en-US", spa = "es" }

local function resolve(code)
    if SUPPORTED[code] then
        return code, SUPPORTED[code]
    end
    local alias = Translate.normalize(ALIASES[code])
    if alias and SUPPORTED[alias] then
        return alias, SUPPORTED[alias]
    end
    return nil
end

local function by_key(fields, key)
    for _, f in ipairs(fields) do
        if f.key == key then
            return f
        end
    end
    error("no field named " .. key)
end

local function build(current, proposed)
    return Fields.build(current or {}, proposed or {})
end

local function codes(targets)
    local out = {}
    for _, t in ipairs(targets) do
        out[#out + 1] = t.code
    end
    return table.concat(out, ",")
end

local T = {}

T["normalize lowercases and drops the region"] = function(a)
    a.eq(Translate.normalize("EN"), "en")
    a.eq(Translate.normalize("en-GB"), "en")
    a.eq(Translate.normalize("pt_BR"), "pt")
    a.eq(Translate.normalize("  fr  "), "fr")
    a.eq(Translate.normalize(""), nil)
    a.eq(Translate.normalize(nil), nil)
end

T["preferred languages lead the target list, in order, without repeats"] = function(a)
    local targets = Translate.targets{
        resolve = resolve,
        preferred = { "af", "es", "af" },
        common = { "en", "es", "fr" },
    }
    a.eq(codes(targets), "af,es,en,fr")
end

T["unsupported languages are dropped from the targets"] = function(a)
    local targets = Translate.targets{
        resolve = resolve,
        preferred = { "xx-YY" },
        common = { "en", "zz" },
    }
    a.eq(codes(targets), "en")
end

T["a three-letter book language resolves to its supported code once"] = function(a)
    local targets = Translate.targets{
        resolve = resolve,
        preferred = { "spa", "eng" },
        common = { "en", "es" },
    }
    a.eq(codes(targets), "es,en")
end

T["targets carry the resolved display name"] = function(a)
    local targets = Translate.targets{ resolve = resolve, preferred = { "eng" }, common = {} }
    a.eq(targets[1].code, "en")
    a.eq(targets[1].name, "English")
end

T["only genres and description are translatable"] = function(a)
    local fields = build({}, {
        title = "Dune",
        authors = { "Frank Herbert" },
        genres = { "Science Fiction" },
        series = "Dune",
        language = "en",
        publisher = "Chilton",
        description = "A blurb.",
    })
    local items = Translate.translatable(fields, function(field)
        return field.new_value
    end)
    local keys = {}
    for _, item in ipairs(items) do
        keys[#keys + 1] = item.field.key
    end
    a.eq(table.concat(keys, ","), "genre,description",
        "titles, series and names come from the edition, never from a translator")
end

T["a title is never offered for translation even when set"] = function(a)
    local fields = build({}, { title = "The Hobbit", series = "Middle-earth" })
    for _, f in ipairs(fields) do
        if f.key == "title" or f.key == "series" or f.key == "author"
            or f.key == "publisher" or f.key == "language" then
            a.is_true(not f.translatable, f.key .. " must not be translatable")
        end
    end
end

T["a plan flattens every field's strings and collect scatters them back"] = function(a)
    local fields = build({}, {
        genres = { "Fantasy", "Adventure" },
        description = "A hobbit goes on a journey.",
    })
    local items = Translate.translatable(fields, function(field)
        return field.new_value
    end)
    local plan = Translate.plan(items)
    a.eq(table.concat(plan.texts, "|"),
        "Fantasy|Adventure|A hobbit goes on a journey.")

    local translated = {}
    for i, text in ipairs(plan.texts) do
        translated[i] = "<" .. text .. ">"
    end

    local results = {}
    for _, result in ipairs(Translate.collect(plan, translated)) do
        results[result.field.key] = result
    end
    a.eq(results.description.raw, "<A hobbit goes on a journey.>")
    a.eq(results.genre.raw[1], "<Fantasy>")
    a.eq(results.genre.raw[2], "<Adventure>")
end

T["untranslated strings fall back to the original text"] = function(a)
    local field = by_key(build({}, { genres = { "Fantasy", "Adventure" } }), "genre")
    local plan = Translate.plan({ { field = field, raw = field.new_value } })
    local results = Translate.collect(plan, { [1] = "Fantasía" })
    a.eq(results[1].raw[1], "Fantasía")
    a.eq(results[1].raw[2], "Adventure")
end

T["a translated value is trimmed and empty genres are dropped"] = function(a)
    local description = by_key(build(), "description")
    a.eq(description.from_translated("", { "  Una mezcla impresionante.  " }), "Una mezcla impresionante.")

    local genre = by_key(build(), "genre")
    local raw = genre.from_translated({}, { " Fantasía ", "   ", "Aventura" })
    a.eq(#raw, 2)
    a.eq(raw[1], "Fantasía")
    a.eq(raw[2], "Aventura")
end

T["short text is a single chunk"] = function(a)
    local chunks = Translate.chunks("Hello there.", 100)
    a.eq(#chunks, 1)
    a.eq(chunks[1].text, "Hello there.")
    a.eq(chunks[1].sep, "")
end

T["chunks split on paragraph breaks and keep the separator whole"] = function(a)
    local text = string.rep("a", 30) .. "\n\n" .. string.rep("b", 30)
    local chunks = Translate.chunks(text, 40)
    a.eq(#chunks, 2)
    a.eq(chunks[1].text, string.rep("a", 30))
    a.eq(chunks[1].sep, "\n\n")
    a.eq(chunks[2].text, string.rep("b", 30))
end

T["chunks split on sentence ends when there is no line break"] = function(a)
    local chunks = Translate.chunks("One sentence here. Two sentence here. Three.", 25)
    a.is_true(#chunks > 1)
    a.eq(chunks[1].text, "One sentence here.")
    a.eq(chunks[1].sep, " ")
end

T["rejoining chunks reproduces the original text exactly"] = function(a)
    local text = "First line.\nSecond line here.\n\n   Third paragraph, a bit longer than the rest.\nDone."
    for _, limit in ipairs({ 10, 17, 24, 40, 1000 }) do
        local parts = {}
        for _, chunk in ipairs(Translate.chunks(text, limit)) do
            parts[#parts + 1] = chunk.text .. chunk.sep
        end
        a.eq(table.concat(parts), text, "limit " .. limit .. " did not round-trip")
    end
end

T["chunks never exceed the limit when a break is available"] = function(a)
    local text = string.rep("word ", 200)
    for _, chunk in ipairs(Translate.chunks(text, 50)) do
        a.is_true(#chunk.text <= 50, "chunk of " .. #chunk.text .. " bytes exceeds the limit")
    end
end

T["an unbreakable run is cut without splitting a utf8 character"] = function(a)
    local chunks = Translate.chunks(string.rep("é", 60), 25)
    a.is_true(#chunks > 1)
    for _, chunk in ipairs(chunks) do
        a.eq(#chunk.text % 2, 0, "a split é would leave an odd byte count")
    end
end

return T
