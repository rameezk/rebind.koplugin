local ASSET = "rebind/assets/rebind-eink.svg"

local function read_asset()
    local f = io.open(ASSET, "rb")
    if not f then
        return nil
    end
    local body = f:read("*a")
    f:close()
    return body
end

local T = {}

T["the e-ink logo ships inside the plugin directory"] = function(a)
    a.is_true(read_asset() ~= nil, ASSET .. " is missing")
end

T["the e-ink logo has no styles, dark-mode rules, markers or wordmark"] = function(a)
    local svg = read_asset() or ""
    a.is_true(svg ~= "", ASSET .. " is missing")
    for _, banned in ipairs({ "<style", "@media", "<marker", "marker-", "<text", "class=" }) do
        a.not_contains(svg, banned)
    end
end

T["the e-ink logo is drawn in black and grey only"] = function(a)
    local svg = read_asset() or ""
    a.is_true(svg ~= "", ASSET .. " is missing")
    local colours = 0
    for hex in svg:gmatch('"#(%x+)"') do
        colours = colours + 1
        a.eq(#hex, 6, "colour #" .. hex .. " is not 6 digits")
        local r, g, b = hex:sub(1, 2), hex:sub(3, 4), hex:sub(5, 6)
        a.is_true(r == g and g == b, "colour #" .. hex .. " is not a grey")
    end
    a.is_true(colours > 0, "no colours found")
end

return T
