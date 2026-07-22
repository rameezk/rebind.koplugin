local M = {}

local function fail(msg)
    error(msg or "assertion failed", 3)
end

function M.is_true(cond, msg)
    if not cond then
        fail(msg or "expected a truthy value")
    end
end

function M.eq(actual, expected, msg)
    if actual ~= expected then
        fail((msg or "values not equal")
            .. " (got=" .. tostring(actual) .. " want=" .. tostring(expected) .. ")")
    end
end

function M.count(s, sub)
    local n, i = 0, 1
    while true do
        local a = s:find(sub, i, true)
        if not a then
            break
        end
        n = n + 1
        i = a + 1
    end
    return n
end

function M.contains(s, sub, msg)
    if type(s) ~= "string" or not s:find(sub, 1, true) then
        fail((msg or "missing expected substring") .. " (want=" .. tostring(sub) .. ")")
    end
end

function M.not_contains(s, sub, msg)
    if type(s) == "string" and s:find(sub, 1, true) then
        fail((msg or "found unexpected substring") .. " (found=" .. tostring(sub) .. ")")
    end
end

function M.count_eq(s, sub, n, msg)
    local c = M.count(s, sub)
    if c ~= n then
        fail((msg or "wrong occurrence count")
            .. " (got=" .. c .. " want=" .. n .. " for '" .. sub .. "')")
    end
end

return M
