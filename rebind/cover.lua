local Cover = {}

Cover.MIN_HEIGHT = 300
Cover.MIN_RATIO = 0.5
Cover.MAX_RATIO = 0.85
Cover.MIN_BYTES = 2048
Cover.MAX_PIXELS = 24000000

local function be16(bytes, at)
    local a, b = bytes:byte(at, at + 1)
    if not b then
        return nil
    end
    return a * 256 + b
end

local function be32(bytes, at)
    local hi, lo = be16(bytes, at), be16(bytes, at + 2)
    if not lo then
        return nil
    end
    return hi * 65536 + lo
end

local SOF_MARKERS = {}
for marker = 0xC0, 0xCF do
    if marker ~= 0xC4 and marker ~= 0xC8 and marker ~= 0xCC then
        SOF_MARKERS[marker] = true
    end
end

local function jpeg_size(bytes)
    local at = 3
    while at < #bytes do
        if bytes:byte(at) ~= 0xFF then
            return nil
        end
        local marker = bytes:byte(at + 1)
        if not marker then
            return nil
        end
        if marker == 0xFF then
            at = at + 1
        elseif marker == 0xD8 or marker == 0x01 or (marker >= 0xD0 and marker <= 0xD7) then
            at = at + 2
        else
            local length = be16(bytes, at + 2)
            if not length or length < 2 then
                return nil
            end
            if SOF_MARKERS[marker] then
                local height, width = be16(bytes, at + 5), be16(bytes, at + 7)
                if height and width and height > 0 and width > 0 then
                    return width, height
                end
                return nil
            end
            if marker == 0xDA then
                return nil
            end
            at = at + 2 + length
        end
    end
    return nil
end

local function png_size(bytes)
    if bytes:sub(13, 16) ~= "IHDR" then
        return nil
    end
    local width, height = be32(bytes, 17), be32(bytes, 21)
    if width and height and width > 0 and height > 0 then
        return width, height
    end
    return nil
end

function Cover.inspect(bytes)
    if type(bytes) ~= "string" then
        return nil
    end
    if bytes:sub(1, 3) == "\255\216\255" then
        local width, height = jpeg_size(bytes)
        if width then
            return { format = "jpeg", extension = "jpg", media_type = "image/jpeg", width = width, height = height }
        end
    elseif bytes:sub(1, 8) == "\137PNG\13\10\26\10" then
        local width, height = png_size(bytes)
        if width then
            return { format = "png", extension = "png", media_type = "image/png", width = width, height = height }
        end
    end
    return nil
end

function Cover.describe(bytes)
    local info = Cover.inspect(bytes)
    if not info or info.width * info.height > Cover.MAX_PIXELS then
        return nil
    end
    info.bytes = bytes
    info.size = #bytes
    return info
end

function Cover.check(bytes)
    if type(bytes) ~= "string" or #bytes < Cover.MIN_BYTES then
        return nil
    end
    local info = Cover.inspect(bytes)
    if not info or info.height < Cover.MIN_HEIGHT then
        return nil
    end
    if info.width * info.height > Cover.MAX_PIXELS then
        return nil
    end
    local ratio = info.width / info.height
    if ratio < Cover.MIN_RATIO or ratio > Cover.MAX_RATIO then
        return nil
    end
    info.bytes = bytes
    info.size = #bytes
    return info
end

function Cover.offered(current, url)
    if not current.has_cover then
        return true
    end
    local kept_original = current.original_cover ~= nil and current.original_cover ~= "none"
    return not (current.cover_source == url and not kept_original)
end

function Cover.fetch(http, candidate)
    if type(candidate) ~= "table" or type(candidate.url) ~= "string" or not candidate.url:find("^https://") then
        return nil
    end
    local ok, body = pcall(http.get_binary, http, candidate.url)
    if not ok or not body then
        return nil
    end
    local info = Cover.check(body)
    if info then
        info.url = candidate.url
    end
    return info
end

function Cover.attach(http, proposed)
    local out = {}
    for key, value in pairs(proposed or {}) do
        out[key] = value
    end
    out.cover_image = Cover.fetch(http, out.cover)
    return out
end

return Cover
