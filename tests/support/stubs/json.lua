local M = {}

local function skip(s, i)
    return s:find("[^ \t\r\n]", i) or #s + 1
end

local ESCAPES = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", ["/"] = "/", ["\\"] = "\\", ['"'] = '"' }

local function utf8_of(code)
    if code < 0x80 then
        return string.char(code)
    elseif code < 0x800 then
        return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
    end
    return string.char(
        0xE0 + math.floor(code / 0x1000),
        0x80 + math.floor(code / 0x40) % 0x40,
        0x80 + code % 0x40)
end

local parse_value

local function parse_string(s, i)
    local out = {}
    i = i + 1
    while true do
        local c = s:sub(i, i)
        if c == "" then
            error("unterminated string")
        elseif c == '"' then
            return table.concat(out), i + 1
        elseif c == "\\" then
            local e = s:sub(i + 1, i + 1)
            if e == "u" then
                local code = tonumber(s:sub(i + 2, i + 5), 16)
                i = i + 6
                if code >= 0xD800 and code < 0xDC00 and s:sub(i, i + 1) == "\\u" then
                    local low = tonumber(s:sub(i + 2, i + 5), 16)
                    code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
                    i = i + 6
                end
                if code >= 0x10000 then
                    out[#out + 1] = string.char(
                        0xF0 + math.floor(code / 0x40000),
                        0x80 + math.floor(code / 0x1000) % 0x40,
                        0x80 + math.floor(code / 0x40) % 0x40,
                        0x80 + code % 0x40)
                else
                    out[#out + 1] = utf8_of(code)
                end
            else
                out[#out + 1] = ESCAPES[e] or error("bad escape")
                i = i + 2
            end
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
end

local function parse_array(s, i)
    local arr = {}
    i = skip(s, i + 1)
    if s:sub(i, i) == "]" then
        return arr, i + 1
    end
    while true do
        local v
        v, i = parse_value(s, i)
        arr[#arr + 1] = v
        i = skip(s, i)
        local c = s:sub(i, i)
        if c == "]" then
            return arr, i + 1
        elseif c ~= "," then
            error("expected , or ]")
        end
        i = skip(s, i + 1)
    end
end

local function parse_object(s, i)
    local obj = {}
    i = skip(s, i + 1)
    if s:sub(i, i) == "}" then
        return obj, i + 1
    end
    while true do
        local k, v
        k, i = parse_string(s, i)
        i = skip(s, i)
        if s:sub(i, i) ~= ":" then
            error("expected :")
        end
        v, i = parse_value(s, skip(s, i + 1))
        obj[k] = v
        i = skip(s, i)
        local c = s:sub(i, i)
        if c == "}" then
            return obj, i + 1
        elseif c ~= "," then
            error("expected , or }")
        end
        i = skip(s, i + 1)
    end
end

function parse_value(s, i)
    i = skip(s, i)
    local c = s:sub(i, i)
    if c == "{" then
        return parse_object(s, i)
    elseif c == "[" then
        return parse_array(s, i)
    elseif c == '"' then
        return parse_string(s, i)
    elseif s:sub(i, i + 3) == "true" then
        return true, i + 4
    elseif s:sub(i, i + 4) == "false" then
        return false, i + 5
    elseif s:sub(i, i + 3) == "null" then
        return nil, i + 4
    end
    local num = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
    if not num or num == "" then
        error("unexpected character at " .. i)
    end
    return tonumber(num), i + #num
end

function M.decode(s)
    local ok, value, i = pcall(parse_value, s, 1)
    if not ok then
        return nil, value
    end
    if skip(s, i) <= #s then
        return nil, "trailing characters"
    end
    return value
end

return M
