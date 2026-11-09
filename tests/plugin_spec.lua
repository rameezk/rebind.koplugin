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

T["_meta.lua declares no plugin name so koreader logs no deprecation warning"] = function(a)
    a.eq(dofile("_meta.lua").name, nil)
end

local MODULES = {
    filemanager = "apps/filemanager/filemanager",
    history = "apps/filemanager/filemanagerhistory",
    collections = "apps/filemanager/filemanagercollection",
    filesearcher = "apps/filemanager/filemanagerfilesearcher",
}

local function with_fake_file_dialog_modules(run)
    local registered = {}
    local FileManager = {}
    function FileManager.addFileDialogButtons(widget, id, row_func)
        for _i, entry in ipairs(registered) do
            if entry.widget == widget and entry.id == id then
                return
            end
        end
        registered[#registered + 1] = { widget = widget, id = id, row_func = row_func }
    end
    function FileManager.removeFileDialogButtons(widget, id)
        for i = #registered, 1, -1 do
            if registered[i].widget == widget and registered[i].id == id then
                table.remove(registered, i)
            end
        end
    end
    local widgets = { filemanager = FileManager }
    package.preload[MODULES.filemanager] = function()
        return FileManager
    end
    for key, name in pairs(MODULES) do
        if key ~= "filemanager" then
            widgets[key] = {}
            package.preload[name] = function()
                return widgets[key]
            end
        end
    end
    local ok, err = pcall(run, registered, widgets)
    for _key, name in pairs(MODULES) do
        package.preload[name] = nil
        package.loaded[name] = nil
    end
    if not ok then
        error(err, 0)
    end
end

T["the rebind button is offered for books on history, collections and file search"] = function(a)
    with_fake_file_dialog_modules(function(registered, widgets)
        local plugin = PluginLoader.load("."):new{ ui = { addFileDialogButtons = function() end } }
        local rebound = {}
        function plugin:onRebind(file)
            rebound[#rebound + 1] = file
        end

        plugin:init()

        for _i, key in ipairs({ "history", "collections", "filesearcher" }) do
            local rows = {}
            for _j, entry in ipairs(registered) do
                if entry.widget == widgets[key] then
                    rows[#rows + 1] = entry.row_func("/books/a.epub", true)
                end
            end
            a.eq(#rows, 1, key .. " rows")
            a.eq(rows[1][1].text, "Rebind")
            rows[1][1].callback()
            a.eq(rebound[#rebound], "/books/a.epub")
            for _j, entry in ipairs(registered) do
                if entry.widget == widgets[key] then
                    a.eq(entry.row_func("/books/folder", false), nil)
                end
            end
        end
    end)
end

T["initialising twice leaves one rebind row per module"] = function(a)
    with_fake_file_dialog_modules(function(registered)
        local plugin = PluginLoader.load("."):new{ ui = { addFileDialogButtons = function() end } }
        plugin:init()
        plugin:init()
        a.eq(#registered, 3)
    end)
end

T["the rebind button is registered for the reader's own instance too"] = function(a)
    with_fake_file_dialog_modules(function(registered, widgets)
        local first = PluginLoader.load("."):new{ ui = { addFileDialogButtons = function() end } }
        first:init()
        local reader = PluginLoader.load("."):new{ ui = {} }
        local rebound = {}
        function reader:onRebind(file)
            rebound[#rebound + 1] = file
        end
        reader:init()

        a.eq(#registered, 3)
        for _i, entry in ipairs(registered) do
            entry.row_func("/books/a.epub", true)[1].callback()
        end
        a.eq(#rebound, 3)
    end)
end

T["the file browser keeps exactly one rebind row"] = function(a)
    with_fake_file_dialog_modules(function()
        local ids = {}
        local plugin = PluginLoader.load("."):new{
            ui = {
                addFileDialogButtons = function(_self, id)
                    ids[#ids + 1] = id
                end,
            },
        }
        plugin:init()
        a.eq(#ids, 1)
    end)
end

T["the stock file browser class is never given a second rebind row"] = function(a)
    with_fake_file_dialog_modules(function(registered, widgets)
        local plugin = PluginLoader.load("."):new{ ui = { addFileDialogButtons = function() end } }
        plugin:init()
        for _i, entry in ipairs(registered) do
            a.is_true(entry.widget ~= widgets.filemanager, "file browser class registered")
        end
    end)
end

return T
