local M = {}

local function class(base, fields)
    local cls = fields or {}
    cls.__index = cls
    cls.extend = function(parent, sub)
        return class(parent, sub)
    end
    cls.new = function(self, o)
        o = o or {}
        return setmetatable(o, self)
    end
    return setmetatable(cls, { __index = base })
end

local stub_mt = {}

local function stub()
    return setmetatable({}, stub_mt)
end

stub_mt.__index = function(_self, key)
    if key == "extend" then
        return function(parent, fields)
            return class(parent, fields)
        end
    end
    return stub()
end
stub_mt.__call = function()
    return stub()
end
for _i, op in ipairs({ "__add", "__sub", "__mul", "__div", "__unm", "__concat", "__lt", "__le" }) do
    stub_mt[op] = function()
        return stub()
    end
end

local function stub_loader(name)
    return function()
        package.loaded[name] = stub()
        return package.loaded[name]
    end
end

function M.load_main(root)
    local loaders = package.loaders or package.searchers
    local saved = {}
    for name in pairs(package.loaded) do
        saved[name] = true
    end
    table.insert(loaders, stub_loader)
    local ok, plugin_module = pcall(dofile, root .. "/main.lua")
    table.remove(loaders)
    for name in pairs(package.loaded) do
        if not saved[name] then
            package.loaded[name] = nil
        end
    end
    if not ok then
        error(plugin_module, 2)
    end
    plugin_module.path = root
    return plugin_module
end

function M.apply_meta(plugin_module, root)
    for k, module in pairs(dofile(root .. "/_meta.lua")) do
        if k ~= "name" then
            plugin_module[k] = module
        end
    end
    return plugin_module
end

function M.load(root)
    return M.apply_meta(M.load_main(root), root)
end

return M
