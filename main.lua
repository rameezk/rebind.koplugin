local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
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

local ChoiceList = require("rebind/ui/choicelist")
local DiffPicker = require("rebind/ui/diffpicker")
local Epub = require("rebind/epub")
local Fields = require("rebind/fields")
local Hardcover = require("rebind/hardcover")
local Organize = require("rebind/organize")
local Translate = require("rebind/translate")

local function info(text, timeout, icon)
    UIManager:show(InfoMessage:new{ text = text, timeout = timeout, icon = icon })
end

local function move_failed_text(rewritten)
    if rewritten then
        return _("Metadata updated, but the move failed:\n")
    end
    return _("The file was not moved:\n")
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

function Rebind:renameFile()
    return self.settings:nilOrTrue("rename_file")
end

function Rebind:filenameTemplate()
    return self.settings:readSetting("filename_template") or Organize.DEFAULT_FILENAME_TEMPLATE
end

function Rebind:folderTemplate()
    return self.settings:readSetting("folder_template") or Organize.DEFAULT_FOLDER_TEMPLATE
end

function Rebind:customFilenameTemplate()
    return self.settings:readSetting("custom_filename_template")
end

function Rebind:customFolderTemplate()
    return self.settings:readSetting("custom_folder_template")
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

function Rebind:libraryRoot()
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
        self:_offerManualEdit(file, current, nil, _([[Rebind needs the Hardcover plugin to look books up.

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
            self:_offerManualEdit(file, current, Api)
            return
        end

        if #results == 1 then
            self:_showDiff(file, current, results[1], Api, results)
        else
            self:_showChooser(results, Api, {
                on_match = function(book)
                    self:_showDiff(file, current, book, Api, results)
                end,
                on_edition = function(edition)
                    self:_showDiff(file, current, edition, Api, results)
                end,
                on_none = function()
                    self:_showDiff(file, current, nil, Api, results)
                end,
            })
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
                self:_showDiff(file, current, nil, Api)
            end,
        })
    end
end

function Rebind:_offerManualEdit(file, current, Api, text)
    UIManager:show(ConfirmBox:new{
        text = text or _("No match found on Hardcover.\n\nEdit the metadata yourself?"),
        ok_text = _("Edit"),
        cancel_text = _("Cancel"),
        ok_callback = function()
            self:_showDiff(file, current, nil, Api)
        end,
    })
end

function Rebind:_showEditions(book, Api, on_pick)
    NetworkMgr:runWhenOnline(function()
        Trapper:wrap(function()
            Trapper:info(_("Loading editions…"))
            local ok, editions = pcall(function()
                return Hardcover.list_editions(Api, book)
            end)
            Trapper:clear()

            if not ok or type(editions) ~= "table" or #editions == 0 then
                info(_("No editions found for this book on Hardcover."))
                return
            end

            local list
            local rows = {}
            for _i, edition in ipairs(editions) do
                local m = Hardcover.extract(edition)
                rows[#rows + 1] = {
                    title = m.title or _("Unknown edition"),
                    subtitle = Hardcover.edition_label(m),
                    on_select = function()
                        UIManager:close(list)
                        on_pick(edition)
                    end,
                }
            end

            list = ChoiceList.show{
                title = _("Select an edition"),
                rows = rows,
            }
        end)
    end)
end

function Rebind:_showChooser(results, Api, handlers)
    local chooser
    local rows = {}
    for _i, book in ipairs(results) do
        local m = Hardcover.extract(book)
        local row = {
            title = m.title or _("Unknown title"),
            subtitle = Hardcover.match_subtitle(m),
            on_select = function()
                UIManager:close(chooser)
                handlers.on_match(book)
            end,
        }
        if Api and tonumber(book.book_id) then
            row.action_text = _("Editions ▸")
            row.on_action = function()
                self:_showEditions(book, Api, function(edition)
                    UIManager:close(chooser)
                    handlers.on_edition(edition)
                end)
            end
        end
        rows[#rows + 1] = row
    end

    rows[#rows + 1] = {
        title = _("None of these"),
        subtitle = _("Type the values yourself"),
        on_select = function()
            UIManager:close(chooser)
            handlers.on_none()
        end,
    }

    chooser = ChoiceList.show{
        title = _("Select a match"),
        rows = rows,
    }
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

function Rebind:_chooseLanguage(picker, current, Api, shown, on_done)
    picker:chooseLanguage(function(code)
        local book = shown.book
        local name = select(2, resolve_language(code)) or code
        self.settings:saveSetting("preferred_language", code)
        self.settings:flush()

        if not (Api and book and tonumber(book.book_id)) then
            self:_offerGapTranslation(picker, code, name,
                _("Rebind has no Hardcover match for this book, so it cannot look for a %1 edition."))
            on_done()
            return
        end
        self:_pickEditionInLanguage(picker, current, book, Api, code, name, shown, on_done)
    end)
end

function Rebind:_pickEditionInLanguage(picker, current, book, Api, code, name, shown, on_done)
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
                on_done()
                return
            end

            self:_showEditionList(editions, name, function(edition)
                self:_useSource(picker, current, shown, edition)
                on_done()
                self:_offerGapTranslation(picker, code, name,
                    _("Hardcover has no %1 description or genres. Those exist per book, not per edition."))
            end)
        end)
    end)
end

function Rebind:_showEditionList(editions, name, on_pick)
    local dialog
    local buttons = {}
    for _i, edition in ipairs(editions) do
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
    for _i, chunk in ipairs(Translate.chunks(text)) do
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

function Rebind:_useSource(picker, current, shown, source)
    local m = source and Hardcover.extract(source) or {}
    shown.proposed = m
    picker:setFields(Fields.build(current, m), m.edition_id and Hardcover.edition_label(m) or nil)
end

function Rebind:_findMatches(current, Api, shown, on_results)
    if #shown.results > 0 then
        on_results(shown.results)
        return
    end
    NetworkMgr:runWhenOnline(function()
        Trapper:wrap(function()
            Trapper:info(_("Looking up on Hardcover…"))
            local ok, results = pcall(function()
                return Hardcover.lookup(Api, current)
            end)
            Trapper:clear()
            if not ok then
                info(_("Hardcover lookup failed:\n") .. tostring(results))
                return
            end
            if type(results) ~= "table" or #results == 0 then
                info(_("No match found on Hardcover."))
                return
            end
            shown.results = results
            on_results(results)
        end)
    end)
end

function Rebind:_sourceHandlers(picker, current, shown, close)
    local function pick(book)
        shown.book = book
        self:_useSource(picker, current, shown, book)
        close()
    end
    return {
        on_match = pick,
        on_edition = pick,
        on_none = function()
            pick(nil)
        end,
    }
end

function Rebind:_sourceRows(picker, current, Api, shown, close)
    local rows = {}
    local proposed = shown.proposed or {}
    local function change_book()
        self:_findMatches(current, Api, shown, function(results)
            self:_showChooser(results, Api, self:_sourceHandlers(picker, current, shown, close))
        end)
    end
    local function change_edition()
        self:_showEditions(shown.book, Api, function(edition)
            self:_useSource(picker, current, shown, edition)
            close()
        end)
    end
    local function change_language()
        self:_chooseLanguage(picker, current, Api, shown, close)
    end

    local book_text = _("None")
    if shown.book and proposed.title then
        book_text = proposed.title
        if proposed.authors and proposed.authors[1] then
            book_text = book_text .. " · " .. proposed.authors[1]
        end
    end
    if Api then
        rows[#rows + 1] = {
            title = _("Book"),
            subtitle = book_text,
            action_text = _("Change ▸"),
            on_select = change_book,
            on_action = change_book,
        }
    end
    if Api and shown.book and tonumber(shown.book.book_id) then
        local edition_text = proposed.edition_id and Hardcover.edition_label(proposed) or ""
        if edition_text == "" then
            edition_text = _("Default")
        end
        rows[#rows + 1] = {
            title = _("Edition"),
            subtitle = edition_text,
            action_text = _("Change ▸"),
            on_select = change_edition,
            on_action = change_edition,
        }
    end
    local code = proposed.language or (current and current.language)
    rows[#rows + 1] = {
        title = _("Language"),
        subtitle = code and (select(2, resolve_language(code)) or code) or _("Unknown"),
        action_text = _("Change ▸"),
        on_select = change_language,
        on_action = change_language,
    }
    if shown.book then
        rows[#rows + 1] = {
            title = _("Don't use Hardcover"),
            subtitle = _("Type every value yourself"),
            on_select = self:_sourceHandlers(picker, current, shown, close).on_none,
        }
    end
    return rows
end

function Rebind:_showSource(picker, current, Api, shown)
    local list
    local function close()
        UIManager:close(list, "ui")
    end
    list = ChoiceList.show{
        title = _("Source"),
        rows = self:_sourceRows(picker, current, Api, shown, close),
    }
end

function Rebind:_showDiff(file, current, book, Api, results)
    local proposed = book and Hardcover.extract(book) or {}
    local shown = { book = book, proposed = proposed, results = results or {} }

    local picker = DiffPicker:new{
        fields = Fields.build(current, proposed),
        edition_label = proposed.edition_id and Hardcover.edition_label(proposed) or nil,
        hardcover_missing = Api == nil,
        on_open_source = Api and function(picker)
            self:_showSource(picker, current, Api, shown)
        end or nil,
        translate_targets = self:_translateTargets(current, shown),
        on_translate = self:_translateHandler(),
        save_as = {
            source_path = file,
            metadata = current,
            library = self:libraryRoot(),
            sort = self.settings:isTrue("move_after_rebind") and self:libraryRoot() ~= nil,
            rename = self:renameFile(),
            keep_backup = self:keepBackup(),
            filename_template = self:filenameTemplate(),
            folder_template = self:folderTemplate(),
            custom_filename_template = self:customFilenameTemplate(),
            custom_folder_template = self:customFolderTemplate(),
        },
        on_save_as_change = function(save_as)
            self:_rememberSaveAs(save_as)
        end,
        on_choose_library = function(on_ready)
            self:_chooseLibraryRoot(on_ready)
        end,
        on_apply = function(changes, opts)
            self:_write(file, changes, opts.keep_backup, opts.dest)
        end,
    }
    UIManager:show(picker)
end

function Rebind:_rememberSaveAs(save_as)
    self.settings:saveSetting("keep_backup", save_as.keep_backup)
    self.settings:saveSetting("move_after_rebind", save_as.sort)
    self.settings:saveSetting("rename_file", save_as.rename)
    self.settings:saveSetting("filename_template", save_as.filename_template)
    self.settings:saveSetting("folder_template", save_as.folder_template)
    self.settings:saveSetting("custom_filename_template", save_as.custom_filename_template)
    self.settings:saveSetting("custom_folder_template", save_as.custom_folder_template)
    if save_as.library then
        self.settings:saveSetting("sorted_root", save_as.library)
    end
    self.settings:flush()
end

function Rebind:_write(file, changes, keep_backup, dest)
    local is_open_book = self:currentFile() == file
    if not next(changes) then
        self:_afterRewrite(file, is_open_book, nil, dest, false)
        return
    end

    local progress = InfoMessage:new{ text = _("Updating EPUB…") }
    UIManager:show(progress)
    UIManager:scheduleIn(0.1, function()
        local ok, result = Epub.rewrite(file, changes, keep_backup)
        UIManager:close(progress)
        if not ok then
            info(_("Update failed:\n") .. tostring(result))
            return
        end

        UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", file))
        UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
        self:_afterRewrite(file, is_open_book, result, dest, true)
    end)
end

function Rebind:_afterRewrite(file, is_open_book, backup, dest, rewritten)
    if dest == file then
        self:_finish(file, is_open_book, backup, nil, rewritten)
    elseif is_open_book then
        self:_relocateOpenBook(file, dest, rewritten)
    else
        self:_doMove(file, dest, backup, rewritten)
    end
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

function Rebind:_chooseLibraryRoot(on_ready)
    local PathChooser = require("ui/widget/pathchooser")
    UIManager:show(PathChooser:new{
        title = _("Choose your library folder"),
        select_file = false,
        show_files = false,
        path = self:libraryRoot() or self:defaultBrowseDir(),
        onConfirm = on_ready,
    })
end

function Rebind:_doMove(file, dest, backup, rewritten)
    local moved, moved_result = Organize.relocate(file, dest)
    if moved then
        UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", file))
        UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
        self:_finish(moved_result, false, backup, moved_result, rewritten)
    else
        info(move_failed_text(rewritten) .. tostring(moved_result))
    end
end

function Rebind:_relocateOpenBook(file, dest, rewritten)
    local ReaderUI = require("apps/reader/readerui")
    local ui = self.ui
    ui.tearing_down = true
    ui:handleEvent(Event:new("CloseReaderMenu"))
    ui:handleEvent(Event:new("CloseConfigMenu"))
    ui:onClose(false)

    local moved, moved_result = Organize.relocate(file, dest)
    if moved then
        UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", file))
        UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
        ReaderUI:showReader(moved_result)
    else
        ReaderUI:showReader(file)
        info(move_failed_text(rewritten) .. tostring(moved_result))
    end
end

function Rebind:_finish(file, is_open_book, backup, moved_dest, rewritten)
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
    if moved_dest and rewritten then
        message = _("Metadata updated and moved to:\n") .. moved_dest
    elseif moved_dest then
        message = _("Moved to:\n") .. moved_dest
    else
        message = _("Metadata updated.")
    end
    if backup then
        message = message .. _("\nBackup saved to:\n") .. tostring(backup)
    end
    info(message, nil, "check")
end

return Rebind
