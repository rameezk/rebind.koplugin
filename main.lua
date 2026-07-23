local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local NetworkMgr = require("ui/network/manager")
local Trapper = require("ui/trapper")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local DiffPicker = require("rebind/ui/diffpicker")
local Epub = require("rebind/epub")
local Hardcover = require("rebind/hardcover")
local Organize = require("rebind/organize")

local function info(text, timeout)
    UIManager:show(InfoMessage:new{ text = text, timeout = timeout })
end

local function join_authors(authors)
    if type(authors) ~= "table" then
        return ""
    end
    return table.concat(authors, ", ")
end

local PREVIEW_LIMIT = 300

local function preview_text(text)
    if type(text) ~= "string" or text == "" then
        return text
    end
    local flat = text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    if #flat <= PREVIEW_LIMIT then
        return flat
    end
    local cut = PREVIEW_LIMIT
    while cut > 0 do
        local b = flat:byte(cut + 1)
        if not b or b < 0x80 or b > 0xBF then
            break
        end
        cut = cut - 1
    end
    return flat:sub(1, cut) .. "…"
end

local function series_text(name, index)
    if not name or name == "" then
        return ""
    end
    if index ~= nil and tostring(index) ~= "" then
        return name .. " #" .. tostring(index)
    end
    return name
end

local Rebind = WidgetContainer:extend{
    name = "rebind",
    is_doc_only = false,
}

function Rebind:onDispatcherRegisterActions()
    Dispatcher:registerAction("rebind_current_book", {
        category = "none",
        event = "RebindCurrentBook",
        title = _("Rebind current book"),
        general = true,
    })
end

function Rebind:promoteMenuOrder()
    local modules = {
        "ui/elements/reader_menu_order",
        "ui/elements/filemanager_menu_order",
        "apps/reader/modules/readermenuorder",
    }
    for _, name in ipairs(modules) do
        local ok, order = pcall(require, name)
        if ok and type(order) == "table" and type(order.tools) == "table" then
            for i, v in ipairs(order.tools) do
                if v == "rebind" then
                    table.remove(order.tools, i)
                    break
                end
            end
            table.insert(order.tools, 1, "rebind")
        end
    end
end

function Rebind:init()
    self:onDispatcherRegisterActions()
    self:promoteMenuOrder()
    self.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/rebind.lua")

    if self.ui and self.ui.addFileDialogButtons then
        self.ui:addFileDialogButtons("rebind_update_metadata", function(file, is_file)
            if not is_file then
                return
            end
            return {
                {
                    text = _("Rebind"),
                    callback = function()
                        self:onRebind(file)
                    end,
                },
            }
        end)
    end

    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function Rebind:keepBackup()
    return self.settings:nilOrTrue("keep_backup")
end

function Rebind:currentFile()
    if self.ui and self.ui.document and self.ui.document.file then
        return self.ui.document.file
    end
    return nil
end

function Rebind:onRebindCurrentBook()
    local file = self:currentFile()
    if file then
        self:onRebind(file)
    else
        info(_("Open a book first, or use Rebind from the file browser."))
    end
    return true
end

function Rebind:sortedRoot()
    local root = self.settings:readSetting("sorted_root")
    if root and root ~= "" then
        return root
    end
    return nil
end

function Rebind:addToMainMenu(menu_items)
    menu_items.rebind = {
        text = _("Rebind"),
        sorting_hint = "tools",
        callback = function()
            local file = self:currentFile()
            if file then
                self:onRebind(file)
            else
                info(_("Long-press a book in the file browser to rebind it."))
            end
        end,
    }
end

function Rebind:onRebind(file)
    if not Epub.is_epub(file) then
        info(_("Rebind supports EPUB files only for now."))
        return
    end

    local available, Api = Hardcover.available()
    if not available then
        info(_([[Rebind needs the Hardcover plugin.

Install hardcoverapp.koplugin, add your API token to its hardcover_config.lua, and enable it, then try again.]]))
        return
    end

    local current, err = Epub.read_metadata(file)
    if not current then
        info(_("Could not read EPUB metadata: ") .. tostring(err))
        return
    end

    NetworkMgr:runWhenOnline(function()
        Trapper:wrap(function()
            self:_lookup(file, current, Api)
        end)
    end)
end

function Rebind:_lookup(file, current, Api)
    Trapper:info(_("Looking up on Hardcover…"))
    local ok, err = pcall(function()
        local results = Hardcover.lookup(Api, current)
        Trapper:clear()

        if not results or #results == 0 then
            info(_("No match found on Hardcover."))
            return
        end

        if #results == 1 then
            self:_showDiff(file, current, results[1])
        else
            self:_showChooser(file, current, results)
        end
    end)

    if not ok then
        Trapper:clear()
        info(_("Hardcover lookup failed:\n") .. tostring(err))
    end
end

function Rebind:_showChooser(file, current, results)
    local chooser
    local buttons = {}
    for i, book in ipairs(results) do
        local m = Hardcover.extract(book)
        local label = m.title or _("Unknown title")
        if m.authors and m.authors[1] then
            label = label .. " — " .. m.authors[1]
        end
        local extra = {}
        if m.release_year then
            extra[#extra + 1] = tostring(m.release_year)
        end
        if m.series then
            extra[#extra + 1] = series_text(m.series, m.series_index)
        end
        if m.users_read_count then
            extra[#extra + 1] = tostring(m.users_read_count) .. _(" readers")
        end
        if #extra > 0 then
            label = label .. " (" .. table.concat(extra, ", ") .. ")"
        end
        buttons[#buttons + 1] = {
            {
                text = label,
                callback = function()
                    UIManager:close(chooser)
                    self:_showDiff(file, current, book)
                end,
            },
        }
    end

    chooser = ButtonDialog:new{
        title = _("Select a match"),
        title_align = "center",
        buttons = buttons,
    }
    UIManager:show(chooser)
end

function Rebind:_showDiff(file, current, book)
    local proposed = Hardcover.extract(book)

    local fields = {
        {
            key = "title",
            label = _("Title"),
            current_text = current.title,
            new_text = proposed.title,
            apply = function(changes)
                changes.title = proposed.title
            end,
        },
        {
            key = "author",
            label = _("Author(s)"),
            current_text = join_authors(current.authors),
            new_text = join_authors(proposed.authors),
            apply = function(changes)
                changes.authors = proposed.authors
            end,
        },
        {
            key = "series",
            label = _("Series"),
            current_text = series_text(current.series, current.series_index),
            new_text = series_text(proposed.series, proposed.series_index),
            apply = function(changes)
                changes.series = proposed.series
                changes.series_index = proposed.series_index
            end,
        },
        {
            key = "description",
            label = _("Description"),
            current_text = preview_text(current.description),
            new_text = preview_text(proposed.description),
            apply = function(changes)
                changes.description = proposed.description
            end,
        },
    }

    local picker = DiffPicker:new{
        fields = fields,
        subtitle = _("Pick which value to keep for each field"),
        keep_backup = self:keepBackup(),
        move_to_sorted = self.settings:isTrue("move_after_rebind"),
        on_apply = function(changes, opts)
            opts = opts or {}
            local keep = opts.keep_backup
            if keep == nil then
                keep = self:keepBackup()
            end
            local move = opts.move_to_sorted == true
            self.settings:saveSetting("keep_backup", keep)
            self.settings:saveSetting("move_after_rebind", move)
            self.settings:flush()
            self:_write(file, changes, keep, move)
        end,
    }
    UIManager:show(picker)
end

function Rebind:_write(file, changes, keep_backup, move_enabled)
    if not next(changes) then
        info(_("No changes selected."))
        return
    end

    local progress = InfoMessage:new{ text = _("Updating EPUB…") }
    UIManager:show(progress)
    local is_open_book = self:currentFile() == file
    UIManager:scheduleIn(0.1, function()
        local ok, result = Epub.rewrite(file, changes, keep_backup)
        UIManager:close(progress)
        if not ok then
            info(_("Update failed:\n") .. tostring(result))
            return
        end

        UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", file))
        UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
        self:_afterRewrite(file, is_open_book, result, move_enabled)
    end)
end

function Rebind:_afterRewrite(file, is_open_book, backup, move_enabled)
    if not move_enabled then
        self:_finish(file, is_open_book, backup, nil)
        return
    end

    self:_withSortedRoot(function(root)
        self:_chooseStructureAndMove(file, is_open_book, backup, root)
    end, function()
        self:_finish(file, is_open_book, backup, nil)
    end)
end

function Rebind:defaultBrowseDir()
    if G_reader_settings then
        local home = G_reader_settings:readSetting("home_dir")
        if home and home ~= "" then
            return home
        end
    end
    local ok, filemanagerutil = pcall(require, "apps/filemanager/filemanagerutil")
    if ok and filemanagerutil and filemanagerutil.getDefaultDir then
        return filemanagerutil.getDefaultDir()
    end
    return nil
end

function Rebind:_withSortedRoot(on_ready, on_cancel)
    local root = self:sortedRoot()
    if root then
        on_ready(root)
        return
    end
    local PathChooser = require("ui/widget/pathchooser")
    local chooser
    chooser = PathChooser:new{
        title = _("Choose your sorted books folder"),
        select_file = false,
        show_files = false,
        path = self:defaultBrowseDir(),
        onConfirm = function(dir)
            self.settings:saveSetting("sorted_root", dir)
            self.settings:flush()
            on_ready(dir)
        end,
    }
    chooser.close_callback = function()
        if not self:sortedRoot() and on_cancel then
            on_cancel()
        end
    end
    UIManager:show(chooser)
end

function Rebind:_chooseStructureAndMove(file, is_open_book, backup, root)
    local meta = Epub.read_metadata(file)
    local authors = meta and meta.authors or {}
    local title = meta and meta.title
    local dialog
    dialog = ButtonDialog:new{
        title = _("Move into:\n") .. root,
        title_align = "center",
        buttons = {
            {
                {
                    text = _("Author / Title / book"),
                    callback = function()
                        UIManager:close(dialog)
                        self:_doMove(file, is_open_book, backup, root, authors, title, "nested")
                    end,
                },
            },
            {
                {
                    text = _("Directly in this folder"),
                    callback = function()
                        UIManager:close(dialog)
                        self:_doMove(file, is_open_book, backup, root, authors, title, "flat")
                    end,
                },
            },
            {
                {
                    text = _("Keep here"),
                    callback = function()
                        UIManager:close(dialog)
                        self:_finish(file, is_open_book, backup, nil)
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
end

function Rebind:_doMove(file, is_open_book, backup, root, authors, title, structure)
    if is_open_book then
        self:_relocateOpenBook(file, root, authors, title, backup, structure)
        return
    end
    local moved, moved_result = Organize.move(file, root, authors, title, structure)
    if moved then
        UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", file))
        UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
        self:_finish(moved_result, false, backup, moved_result)
    else
        info(_("Metadata updated, but the move failed:\n") .. tostring(moved_result))
    end
end

function Rebind:_relocateOpenBook(file, root, authors, title, backup, structure)
    local ReaderUI = require("apps/reader/readerui")
    local ui = self.ui
    ui.tearing_down = true
    ui:handleEvent(Event:new("CloseReaderMenu"))
    ui:handleEvent(Event:new("CloseConfigMenu"))
    ui:onClose(false)

    local moved, moved_result = Organize.move(file, root, authors, title, structure)
    if moved then
        UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", file))
        UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
        ReaderUI:showReader(moved_result)
    else
        ReaderUI:showReader(file)
        info(_("Metadata updated, but the move failed:\n") .. tostring(moved_result))
    end
end

function Rebind:_finish(file, is_open_book, backup, moved_dest)
    if is_open_book and not moved_dest and self.ui and self.ui.reloadDocument then
        UIManager:show(ConfirmBox:new{
            text = _("Metadata updated. Reopen the book now to apply the changes?"),
            ok_text = _("Reopen"),
            cancel_text = _("Later"),
            ok_callback = function()
                self.ui:reloadDocument()
            end,
        })
        return
    end

    local message
    if moved_dest then
        message = _("Metadata updated and moved to:\n") .. moved_dest
    else
        message = _("Metadata updated.")
    end
    if backup then
        message = message .. _("\nBackup saved to:\n") .. tostring(backup)
    end
    info(message)
end

return Rebind
