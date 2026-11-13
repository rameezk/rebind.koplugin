local Images = {}

local function be16(n)
    return string.char(math.floor(n / 256) % 256, n % 256)
end

local function be32(n)
    return be16(math.floor(n / 65536)) .. be16(n % 65536)
end

local function pad(head, size, tail)
    local fill = size - #head - #tail
    if fill < 0 then
        fill = 0
    end
    return head .. string.rep("x", fill) .. tail
end

function Images.jpeg(width, height, size)
    local sof = "\255\192" .. be16(17) .. "\8" .. be16(height) .. be16(width) .. "\3\1\34\0\2\17\1\3\17\1"
    return pad("\255\216" .. sof, size or 5000, "\255\217")
end

function Images.png(width, height, size)
    local ihdr = be32(13) .. "IHDR" .. be32(width) .. be32(height) .. "\8\2\0\0\0" .. "\0\0\0\0"
    return pad("\137PNG\13\10\26\10" .. ihdr, size or 5000, "")
end

function Images.webp(size)
    return pad("RIFF\0\0\0\0WEBPVP8 ", size or 5000, "")
end

return Images
