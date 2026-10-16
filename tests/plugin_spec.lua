local PluginLoader = require("tests/support/plugin_loader")

local T = {}

T["no _meta.lua field replaces a plugin method when koreader loads the plugin"] = function(a)
    local plugin = PluginLoader.load_main(".")
    local methods = {}
    for k, v in pairs(plugin) do
        if type(v) == "function" then
            methods[k] = true
        end
    end
    PluginLoader.apply_meta(plugin, ".")
    for k in pairs(methods) do
        a.eq(type(plugin[k]), "function", "_meta.lua field '" .. k .. "' replaces Rebind:" .. k .. "()")
    end
end

T["lookups identify themselves with the installed version when koreader loads the plugin"] = function(a)
    local plugin = PluginLoader.load("."):new{}

    local env = plugin:providerEnv()

    a.contains(env.http.user_agent, "Rebind/" .. dofile("_meta.lua").version .. " ")
end

T["_meta.lua leaves the plugin name to main.lua so koreader logs no deprecation warning"] = function(a)
    a.eq(dofile("_meta.lua").name, nil)
end

return T
