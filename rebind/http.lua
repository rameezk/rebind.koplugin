local Http = {}
Http.__index = Http

Http.MAX_ATTEMPTS = 3
Http.BASE_BACKOFF = 2
Http.MAX_WAIT = 30
Http.MAX_BODY = 4 * 1024 * 1024
Http.HOMEPAGE = "https://github.com/rameezk/rebind.koplugin"

function Http.user_agent(version)
    return string.format("Rebind/%s (%s)", version or "dev", Http.HOMEPAGE)
end

function Http.escape(value)
    return (tostring(value):gsub("[^%w%-%._~]", function(c)
        return string.format("%%%02X", c:byte())
    end))
end

function Http.query_string(params)
    local keys = {}
    for key in pairs(params or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local parts = {}
    for _i, key in ipairs(keys) do
        parts[#parts + 1] = Http.escape(key) .. "=" .. Http.escape(params[key])
    end
    return table.concat(parts, "&")
end

function Http.limited_sink(chunks, limit)
    local size = 0
    return function(chunk)
        if chunk then
            size = size + #chunk
            if size > limit then
                return nil, "response too large"
            end
            chunks[#chunks + 1] = chunk
        end
        return 1
    end
end

function Http.default_transport(req)
    local https_loaded, https = pcall(require, "ssl.https")
    local http = https_loaded and req.url:find("^https://") and https or require("socket.http")
    local socketutil = require("socketutil")
    local chunks = {}
    socketutil:set_timeout(socketutil.LARGE_BLOCK_TIMEOUT, socketutil.LARGE_TOTAL_TIMEOUT)
    local ok, code, headers = http.request{
        url = req.url,
        method = "GET",
        headers = req.headers,
        sink = Http.limited_sink(chunks, Http.MAX_BODY),
    }
    socketutil:reset_timeout()
    if not ok then
        return nil, tostring(code)
    end
    return { status = tonumber(code) or 0, body = table.concat(chunks), headers = headers or {} }
end

function Http.default_sleep(seconds)
    require("ffi/util").sleep(seconds)
end

function Http.new(opts)
    opts = opts or {}
    return setmetatable({
        transport = opts.transport or Http.default_transport,
        sleep = opts.sleep or Http.default_sleep,
        user_agent = Http.user_agent(opts.version),
    }, Http)
end

local function wait_seconds(response, attempt)
    local headers = response.headers or {}
    local advised = tonumber(headers["retry-after"] or headers["Retry-After"])
    if advised and advised >= 0 then
        return math.min(advised, Http.MAX_WAIT)
    end
    return math.min(Http.BASE_BACKOFF * 2 ^ (attempt - 1), Http.MAX_WAIT)
end

function Http:get_json(url, params)
    local query = Http.query_string(params)
    if query ~= "" then
        url = url .. (url:find("?", 1, true) and "&" or "?") .. query
    end
    local req = {
        url = url,
        headers = { ["User-Agent"] = self.user_agent, ["Accept"] = "application/json" },
    }

    for attempt = 1, Http.MAX_ATTEMPTS do
        local response, err = self.transport(req)
        if not response then
            return nil, err or "request failed"
        end
        if response.status == 429 then
            if attempt == Http.MAX_ATTEMPTS then
                return nil, "HTTP 429"
            end
            self.sleep(wait_seconds(response, attempt))
        elseif response.status ~= 200 then
            return nil, "HTTP " .. tostring(response.status)
        else
            local parsed, decoded = pcall(require("json").decode, response.body)
            if not parsed or type(decoded) ~= "table" then
                return nil, "invalid JSON response"
            end
            return decoded
        end
    end
end

return Http
