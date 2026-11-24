local Isbn = {}

local function digits_of(text)
    if type(text) ~= "string" then
        return nil
    end
    return (text:upper():gsub("[%s%-]", ""))
end

local function valid_13(s)
    if not s:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d$") then
        return false
    end
    local sum = 0
    for i = 1, 13 do
        sum = sum + tonumber(s:sub(i, i)) * ((i % 2 == 1) and 1 or 3)
    end
    return sum % 10 == 0
end

local function valid_10(s)
    if not s:match("^%d%d%d%d%d%d%d%d%d[%dX]$") then
        return false
    end
    local sum = 0
    for i = 1, 10 do
        local c = s:sub(i, i)
        sum = sum + (c == "X" and 10 or tonumber(c)) * (11 - i)
    end
    return sum % 11 == 0
end

local function check_digit_13(body)
    local sum = 0
    for i = 1, 12 do
        sum = sum + tonumber(body:sub(i, i)) * ((i % 2 == 1) and 1 or 3)
    end
    return tostring((10 - sum % 10) % 10)
end

function Isbn.to_13(text)
    local s = digits_of(text)
    if not s then
        return nil
    end
    if valid_13(s) then
        return s
    end
    if valid_10(s) then
        local body = "978" .. s:sub(1, 9)
        return body .. check_digit_13(body)
    end
    return nil
end

function Isbn.best(...)
    local converted
    for i = 1, select("#", ...) do
        local candidate = select(i, ...)
        local isbn = Isbn.to_13(candidate)
        if isbn then
            if digits_of(candidate) == isbn then
                return isbn
            end
            converted = converted or isbn
        end
    end
    return converted
end

return Isbn
