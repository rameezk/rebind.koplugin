local Translate = {}

Translate.CHUNK_LIMIT = 1800

Translate.COMMON = {
    "en", "es", "pt", "fr", "de", "it", "nl", "af",
    "sv", "da", "no", "fi", "pl", "cs", "hu", "ro", "el",
    "uk", "ru", "tr", "ar", "he", "fa",
    "hi", "bn", "id", "vi", "th", "ja", "ko", "zh",
}

function Translate.normalize(code)
    if type(code) ~= "string" then
        return nil
    end
    local base = code:gsub("_", "-"):match("^%s*([^-%s]+)")
    if not base or base == "" then
        return nil
    end
    return base:lower()
end

function Translate.targets(opts)
    opts = opts or {}
    local resolve = opts.resolve or function(code)
        return code, code
    end
    local out, seen = {}, {}

    local function add(code)
        code = Translate.normalize(code)
        if not code then
            return
        end
        local resolved, name = resolve(code)
        if not resolved or seen[resolved] then
            return
        end
        seen[resolved] = true
        out[#out + 1] = { code = resolved, name = name or resolved }
    end

    for _, code in ipairs(opts.preferred or {}) do
        add(code)
    end
    for _, code in ipairs(opts.common or Translate.COMMON) do
        add(code)
    end
    return out
end

function Translate.translatable(fields, selected_value)
    local out = {}
    for _, field in ipairs(fields or {}) do
        if field.translatable then
            local raw = selected_value(field)
            if not field.is_empty(raw) then
                out[#out + 1] = { field = field, raw = raw }
            end
        end
    end
    return out
end

function Translate.plan(items)
    local texts, slices = {}, {}
    for _, item in ipairs(items or {}) do
        local parts = item.field.to_translate(item.raw)
        if #parts > 0 then
            slices[#slices + 1] = {
                field = item.field,
                raw = item.raw,
                from = #texts + 1,
                to = #texts + #parts,
            }
            for _, part in ipairs(parts) do
                texts[#texts + 1] = part
            end
        end
    end
    return { texts = texts, slices = slices }
end

function Translate.collect(plan, translated)
    local out = {}
    for _, slice in ipairs(plan.slices) do
        local parts = {}
        for i = slice.from, slice.to do
            parts[#parts + 1] = translated[i] or plan.texts[i]
        end
        out[#out + 1] = {
            field = slice.field,
            raw = slice.field.from_translated(slice.raw, parts),
        }
    end
    return out
end

local function utf8_safe_cut(text, limit)
    local cut = limit
    while cut > 0 do
        local b = text:byte(cut + 1)
        if not b or b < 0x80 or b > 0xBF then
            break
        end
        cut = cut - 1
    end
    return cut
end

function Translate.chunks(text, limit)
    limit = limit or Translate.CHUNK_LIMIT
    local out = {}
    if type(text) ~= "string" or text == "" then
        return out
    end
    local rest = text
    while #rest > limit do
        local head = rest:sub(1, utf8_safe_cut(rest, limit))
        local at = head:match("^.*()\n")
            or head:match("^.*[%.%?!]()%s")
            or head:match("^.*()%s")
        while at and at > 1 and rest:sub(at - 1, at - 1):match("%s") do
            at = at - 1
        end
        if not at or at <= 1 then
            at = #head + 1
        end
        local piece = rest:sub(1, at - 1)
        local sep = rest:sub(at):match("^%s*")
        out[#out + 1] = { text = piece, sep = sep }
        rest = rest:sub(at + #sep)
    end
    out[#out + 1] = { text = rest, sep = "" }
    return out
end

return Translate
