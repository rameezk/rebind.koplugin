local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local MultiConfirmBox = require("ui/widget/multiconfirmbox")
local NetworkMgr = require("ui/network/manager")
local Trapper = require("ui/trapper")
local Translator = require("ui/translator")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local T = require("ffi/util").template

local DiffPicker = require("rebind/ui/diffpicker")
local Epub = require("rebind/epub")
local Fields = require("rebind/fields")
local Hardcover = require("rebind/hardcover")
local Organize = require("rebind/organize")
local Translate = require("rebind/translate")

local function info(text, timeout)
    UIManager:show(InfoMessage:new{ text = text, timeout = timeout })
end

local function resolve_language(code)
    local name, supported = Translator:getLanguageName(code, nil)
    if supported then
        return code, name
    end
    local ok, ReaderTypography = pcall(require, "apps/reader/modules/readertypography")
    local aliases = ok and ReaderTypography and ReaderTypography.LANG_ALIAS_TO_LANG_TAG
    local alias = aliases and Translate.normalize(aliases[code])
    if not alias then
        return nil
    end
    name, supported = Translator:getLanguageName(alias, nil)
    if supported then
        return alias, name
    end
    return nil
end

local function editions_button_width()
    return Device.screen:scaleBySize(110)
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

    local current, err = Epub.read_metadata(file)
    if not current then
        info(_("Could not read EPUB metadata: ") .. tostring(err))
        return
    end

    local available, Api = Hardcover.available()
    if not available then
        self:_offerManualEdit(file, current, _([[Rebind needs the Hardcover plugin to look books up.

Install hardcoverapp.koplugin, add your API token to its hardcover_config.lua, and enable it.

Edit this book's metadata by hand instead?]]))
        return
    end

    self:_startLookup(file, current, Api)
end

function Rebind:_startLookup(file, current, Api)
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
            self:_offerManualEdit(file, current)
            return
        end

        if #results == 1 then
            self:_showDiff(file, current, results[1], Api)
        else
            self:_showChooser(file, current, results, Api)
        end
    end)

    if not ok then
        Trapper:clear()
        UIManager:show(MultiConfirmBox:new{
            text = _("Hardcover lookup failed:\n") .. tostring(err),
            choice1_text = _("Retry"),
            choice1_callback = function()
                self:_startLookup(file, current, Api)
            end,
            choice2_text = _("Edit myself"),
            choice2_callback = function()
                self:_showDiff(file, current, nil)
            end,
        })
    end
end

function Rebind:_offerManualEdit(file, current, text)
    UIManager:show(ConfirmBox:new{
        text = text or _("No match found on Hardcover.\n\nEdit the metadata yourself?"),
        ok_text = _("Edit"),
        cancel_text = _("Cancel"),
        ok_callback = function()
            self:_showDiff(file, current, nil)
        end,
    })
end

function Rebind:_showEditions(book, Api, on_pick)
    NetworkMgr:runWhenOnline(function()
        Trapper:wrap(function()
            Trapper:info(_("Loading editions…"))
            local ok, editions, truncated = pcall(function()
                return Hardcover.list_editions(Api, book)
            end)
            Trapper:clear()

            if not ok or type(editions) ~= "table" or #editions == 0 then
                info(_("No editions found for this book on Hardcover."))
                return
            end

            local dialog
            local buttons = {}
            for _, edition in ipairs(editions) do
                local m = Hardcover.extract(edition)
                local label = Hardcover.edition_label(m)
                if label == "" then
                    label = m.title or _("Unknown edition")
                elseif m.title and m.title ~= "" then
                    label = m.title .. " - " .. label
                end
                buttons[#buttons + 1] = {
                    {
                        text = label,
                        callback = function()
                            UIManager:close(dialog)
                            on_pick(edition)
                        end,
                    },
                }
            end
            buttons[#buttons + 1] = {
                {
                    text = _("Cancel"),
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
            }

            dialog = ButtonDialog:new{
                title = truncated and _("Select an edition (most popular first)")
                    or _("Select an edition"),
                title_align = "center",
                buttons = buttons,
            }
            UIManager:show(dialog)
        end)
    end)
end

function Rebind:_showChooser(file, current, results, Api)
    local chooser
    local buttons = {}
    for i, book in ipairs(results) do
        local m = Hardcover.extract(book)
        local label = m.title or _("Unknown title")
        if m.authors and m.authors[1] then
            label = label .. " - " .. m.authors[1]
        end
        local extra = {}
        if m.release_year then
            extra[#extra + 1] = tostring(m.release_year)
        end
        if m.series then
            extra[#extra + 1] = Fields.series_text(m.series, m.series_index)
        end
        if m.users_read_count then
            extra[#extra + 1] = tostring(m.users_read_count) .. _(" readers")
        end
        if #extra > 0 then
            label = label .. " (" .. table.concat(extra, ", ") .. ")"
        end
        local row = {
            {
                text = label,
                callback = function()
                    UIManager:close(chooser)
                    self:_showDiff(file, current, book, Api)
                end,
            },
        }
        if Api and tonumber(book.book_id) then
            row[#row + 1] = {
                text = _("Editions"),
                width = editions_button_width(),
                callback = function()
                    self:_showEditions(book, Api, function(edition)
                        UIManager:close(chooser)
                        self:_showDiff(file, current, edition, Api)
                    end)
                end,
            }
        end
        buttons[#buttons + 1] = row
    end

    buttons[#buttons + 1] = {
        {
            text = _("None of these, edit myself"),
            callback = function()
                UIManager:close(chooser)
                self:_showDiff(file, current, nil)
            end,
        },
    }

    chooser = ButtonDialog:new{
        title = _("Select a match"),
        title_align = "center",
        buttons = buttons,
    }
    UIManager:show(chooser)
end

function Rebind:_translateTargets(current, shown)
    return function()
        local preferred = {}
        local function prefer(code)
            if code and code ~= "" then
                preferred[#preferred + 1] = code
            end
        end
        prefer(self.settings:readSetting("preferred_language"))
        prefer(shown.proposed and shown.proposed.language)
        prefer(current and current.language)
        prefer(Translator:getTargetLanguage())
        return Translate.targets{ resolve = resolve_language, preferred = preferred }
    end
end

function Rebind:_chooseLanguage(picker, current, book, Api, shown)
    picker:chooseLanguage(function(code)
        local name = select(2, resolve_language(code)) or code
        self.settings:saveSetting("preferred_language", code)
        self.settings:flush()

        if not (Api and book and tonumber(book.book_id)) then
            self:_offerGapTranslation(picker, code, name,
                _("Rebind has no Hardcover match for this book, so it cannot look for a %1 edition."))
            return
        end
        self:_pickEditionInLanguage(picker, current, book, Api, code, name, shown)
    end)
end

function Rebind:_pickEditionInLanguage(picker, current, book, Api, code, name, shown)
    NetworkMgr:runWhenOnline(function()
        Trapper:wrap(function()
            Trapper:info(T(_("Looking for a %1 edition…"), name))
            local ok, editions = pcall(function()
                return Hardcover.list_editions(Api, book, code)
            end)
            Trapper:clear()

            if not ok or type(editions) ~= "table" or #editions == 0 then
                self:_offerGapTranslation(picker, code, name,
                    _("Hardcover has no %1 edition of this book."))
                return
            end

            self:_showEditionList(editions, name, function(edition)
                local m = Hardcover.extract(edition)
                shown.proposed = m
                picker:setFields(Fields.build(current, m), Hardcover.edition_label(m))
                self:_offerGapTranslation(picker, code, name,
                    _("Hardcover has no %1 description or genres. Those exist per book, not per edition."))
            end)
        end)
    end)
end

function Rebind:_showEditionList(editions, name, on_pick)
    local dialog
    local buttons = {}
    for _, edition in ipairs(editions) do
        local m = Hardcover.extract(edition)
        local label = Hardcover.edition_label(m, true)
        if label == "" then
            label = m.title or _("Unknown edition")
        elseif m.title and m.title ~= "" then
            label = m.title .. " - " .. label
        end
        buttons[#buttons + 1] = {
            {
                text = label,
                callback = function()
                    UIManager:close(dialog)
                    on_pick(edition)
                end,
            },
        }
    end
    buttons[#buttons + 1] = {
        {
            text = _("Cancel"),
            callback = function()
                UIManager:close(dialog)
            end,
        },
    }

    dialog = ButtonDialog:new{
        title = T(_("Select a %1 edition"), name),
        title_align = "center",
        buttons = buttons,
    }
    UIManager:show(dialog)
end

function Rebind:_offerGapTranslation(picker, code, name, reason)
    local items = picker:translatableItems()
    if #items == 0 then
        info(T(reason, name))
        return
    end

    local labels = {}
    for _, item in ipairs(items) do
        labels[#labels + 1] = item.field.label
    end

    UIManager:show(ConfirmBox:new{
        text = T(reason, name) .. "\n\n"
            .. T(_("Translate %1 with Google Translate instead?"), table.concat(labels, ", "))
            .. "\n\n"
            .. _("Machine translation is not the publisher's own text. You can review it before applying."),
        ok_text = _("Translate"),
        cancel_text = _("Leave as is"),
        ok_callback = function()
            picker:translateInto(items, code)
        end,
    })
end

function Rebind:_translateHandler()
    return function(items, target, on_done)
        NetworkMgr:runWhenOnline(function()
            Trapper:wrap(function()
                local plan = Translate.plan(items)
                local translated, failure = {}, nil
                for i, text in ipairs(plan.texts) do
                    if text:match("%S") then
                        Trapper:info(T(_("Translating %1 of %2…"), i, #plan.texts))
                        local rendered, err = self:_translateText(text, target)
                        if not rendered then
                            failure = err
                            break
                        end
                        translated[i] = rendered
                    end
                end
                Trapper:clear()

                if failure then
                    info(_("Translation failed:\n") .. failure)
                    return
                end
                self.settings:saveSetting("preferred_language", target)
                self.settings:flush()
                on_done(Translate.collect(plan, translated))
            end)
        end)
    end
end

function Rebind:_translateText(text, target)
    local parts = {}
    for _, chunk in ipairs(Translate.chunks(text)) do
        local ok, rendered = pcall(function()
            return Translator:translate(chunk.text, target)
        end)
        if not ok then
            return nil, tostring(rendered)
        end
        if not rendered or rendered == "" then
            return nil, _("the translation service returned nothing")
        end
        parts[#parts + 1] = rendered .. chunk.sep
    end
    return table.concat(parts)
end

function Rebind:_showDiff(file, current, book, Api)
    local proposed = book and Hardcover.extract(book) or {}
    local manual = book == nil
    local shown = { proposed = proposed }

    local on_choose_edition
    if Api and tonumber(proposed.book_id) then
        on_choose_edition = function(picker)
            self:_showEditions(book, Api, function(edition)
                local m = Hardcover.extract(edition)
                shown.proposed = m
                picker:setFields(Fields.build(current, m), Hardcover.edition_label(m))
            end)
        end
    end

    local picker = DiffPicker:new{
        fields = Fields.build(current, proposed),
        subtitle = manual and _("Tap a value to edit it")
            or _("Pick a value per field, or tap one to edit it"),
        new_label = manual and _("Hardcover (not used)") or nil,
        edition_label = proposed.edition_id and Hardcover.edition_label(proposed) or nil,
        on_choose_edition = on_choose_edition,
        translate_targets = self:_translateTargets(current, shown),
        on_translate = self:_translateHandler(),
        on_choose_language = function(picker)
            self:_chooseLanguage(picker, current, book, Api, shown)
        end,
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
