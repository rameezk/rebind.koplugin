local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local MultiConfirmBox = require("ui/widget/multiconfirmbox")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local NetworkMgr = require("ui/network/manager")
local SortWidget = require("ui/widget/sortwidget")
local Trapper = require("ui/trapper")
local Translator = require("ui/translator")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local T = require("ffi/util").template

local BatchProgress = require("rebind/ui/batchprogress")
local ChooseBooks = require("rebind/ui/choosebooks")
local ChoiceList = require("rebind/ui/choicelist")
local DiffPicker = require("rebind/ui/diffpicker")
local Logo = require("rebind/ui/logo")
local ReviewList = require("rebind/ui/reviewlist")
local SaveAs = require("rebind/ui/saveas")
local Apply = require("rebind/apply")
local Batch = require("rebind/batch")
local Epub = require("rebind/epub")
local Fields = require("rebind/fields")
local HardcoverProvider = require("rebind/providers/hardcover")
local Http = require("rebind/http")
local Labels = require("rebind/labels")
local Lookup = require("rebind/lookup")
local Organize = require("rebind/organize")
local ProviderSettings = require("rebind/provider_settings")
local Providers = require("rebind/providers")
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
    Dispatcher:registerAction("rebind_several", {
        category = "none",
        event = "RebindSeveral",
        title = _("Rebind several books…"),
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

local BOOK_DIALOG_MODULES = {
    "apps/filemanager/filemanagerhistory",
    "apps/filemanager/filemanagercollection",
    "apps/filemanager/filemanagerfilesearcher",
}

function Rebind:bookDialogRow(with_folders)
    return function(file, is_file)
        if not is_file then
            if not with_folders then
                return
            end
            return {
                {
                    text = _("Rebind books in this folder"),
                    callback = function()
                        self:openChooseBooks{ folder = file, tick_all = true }
                    end,
                },
            }
        end
        return {
            {
                text = _("Rebind"),
                callback = function()
                    self:onRebind(file)
                end,
            },
        }
    end
end

function Rebind:registerBookDialogModules()
    local ok, FileManager = pcall(require, "apps/filemanager/filemanager")
    if not (ok and FileManager and FileManager.addFileDialogButtons) then
        return
    end
    for _i, name in ipairs(BOOK_DIALOG_MODULES) do
        local loaded, module = pcall(require, name)
        if loaded and module then
            FileManager.removeFileDialogButtons(module, "rebind_update_metadata")
            FileManager.addFileDialogButtons(module, "rebind_update_metadata", self:bookDialogRow())
        end
    end
end

function Rebind:init()
    self:onDispatcherRegisterActions()
    self:promoteMenuOrder()
    self.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/rebind.lua")
    if self.settings:readSetting("provider_chain") == nil then
        self.settings:saveSetting("provider_chain", Providers.enabled_ids(nil))
        self.settings:flush()
    end

    if self.ui and self.ui.addFileDialogButtons then
        self.ui:addFileDialogButtons("rebind_update_metadata", self:bookDialogRow(true))
    end
    self:registerBookDialogModules()

    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function Rebind:providerEnv()
    local _available, Api = HardcoverProvider.available()
    return {
        hardcover_api = Api,
        http = Http.new{ version = self.version },
    }
end

function Rebind:enabledProviderIds()
    return Providers.enabled_ids(self.settings:readSetting("provider_chain"))
end

function Rebind:providerChain()
    return Providers.build(self:enabledProviderIds(), self:providerEnv())
end

function Rebind:_saveProviderIds(ids)
    self.settings:saveSetting("provider_chain", ids)
    self.settings:flush()
end

function Rebind:_refreshChain(chain)
    local fresh = self:providerChain()
    for i = #chain, 1, -1 do
        chain[i] = nil
    end
    for i, provider in ipairs(fresh) do
        chain[i] = provider
    end
end

function Rebind:_chainSummary()
    local names = {}
    for _i, provider in ipairs(self:providerChain()) do
        names[#names + 1] = provider.name
    end
    if #names == 0 then
        return _("None enabled")
    end
    return table.concat(names, " → ")
end

function Rebind:showLookupProviders(on_close)
    if self._providers_screen then
        UIManager:close(self._providers_screen, "ui")
    end
    local env = self:providerEnv()
    local stored = self.settings:readSetting("provider_chain")
    local rows = {}
    for _i, row in ipairs(ProviderSettings.rows(stored, env)) do
        local locked = not row.enabled and not row.can_enable
        rows[#rows + 1] = {
            title = row.name,
            subtitle = (not row.can_enable) and row.reason or nil,
            checked = row.enabled,
            disabled = locked,
            on_select = not locked and function()
                self:_saveProviderIds(ProviderSettings.set_enabled(stored, row.id, not row.enabled, env))
                self:showLookupProviders(on_close)
            end or nil,
        }
    end
    if #self:enabledProviderIds() > 1 then
        local function reorder()
            self:_reorderProviders(function()
                self:showLookupProviders(on_close)
            end)
        end
        rows[#rows + 1] = {
            title = _("Change order"),
            subtitle = self:_chainSummary(),
            action_text = _("Reorder ▸"),
            on_select = reorder,
            on_action = reorder,
        }
    end
    self._providers_screen = ChoiceList.show{
        title = _("Lookup providers"),
        rows = rows,
        on_close = on_close,
    }
end

function Rebind:_reorderProviders(on_done)
    local item_table = {}
    for _i, provider in ipairs(self:providerChain()) do
        item_table[#item_table + 1] = { text = provider.name, label = provider.id }
    end
    local sort_widget
    sort_widget = SortWidget:new{
        title = _("Order of lookup providers"),
        item_table = item_table,
        callback = function()
            local ordered = {}
            for _i, item in ipairs(item_table) do
                ordered[#ordered + 1] = item.label
            end
            self:_saveProviderIds(ProviderSettings.reorder(self.settings:readSetting("provider_chain"), ordered))
            on_done()
        end,
    }
    UIManager:show(sort_widget)
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
        sub_item_table = {
            {
                text = _("Rebind current book"),
                callback = function()
                    local file = self:currentFile()
                    if file then
                        self:onRebind(file)
                    else
                        info(_("Long-press a book in the file browser to rebind it."))
                    end
                end,
            },
            {
                text = _("Rebind several books…"),
                callback = function()
                    self:openChooseBooks{}
                end,
            },
            {
                text = _("Lookup providers"),
                callback = function()
                    self:showLookupProviders()
                end,
            },
        },
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

    self:_startLookup(file, current, self:providerChain())
end

function Rebind:_startLookup(file, current, chain)
    NetworkMgr:runWhenOnline(function()
        Trapper:wrap(function()
            self:_lookup(file, current, chain)
        end)
    end)
end

function Rebind:_withAutoEdition(current, chain, book, done)
    if not (chain and book and not book.edition_id and not book.by_isbn and book.has_editions) then
        done(book)
        return
    end
    NetworkMgr:runWhenOnline(function()
        Trapper:wrap(function()
            Trapper:info(_("Looking for an edition…"))
            local chosen = Lookup.auto_edition(chain, current, book, self.settings:readSetting("preferred_language"))
            Trapper:clear()
            done(chosen)
        end)
    end)
end

function Rebind:_lookup(file, current, chain)
    local busy = Logo.show_message(_("Looking up your book…"))
    local ok, err = pcall(function()
        local found = Lookup.find(chain, current)
        local results = found.matches
        Logo.close_message(busy)

        if Lookup.all_failed(found) then
            error(Lookup.skipped_text(found), 0)
        end

        if not results or #results == 0 then
            self:_offerManualEdit(file, current, chain,
                Lookup.not_found_text(found) .. _("\n\nEdit the metadata yourself?"))
            return
        end

        local skipped = Lookup.skipped_text(found)
        if skipped ~= "" then
            info(skipped, 4)
        end

        if #results == 1 then
            self:_withAutoEdition(current, chain, results[1], function(book)
                self:_showDiff(file, current, book, chain, results)
            end)
        else
            self:_showChooser(results, chain, {
                on_match = function(book)
                    self:_withAutoEdition(current, chain, book, function(chosen)
                        self:_showDiff(file, current, chosen, chain, results)
                    end)
                end,
                on_edition = function(edition)
                    self:_showDiff(file, current, edition, chain, results)
                end,
                on_none = function()
                    self:_showDiff(file, current, nil, chain, results)
                end,
            })
        end
    end)

    if not ok then
        Logo.close_message(busy)
        UIManager:show(MultiConfirmBox:new{
            text = _("Lookup failed:\n") .. tostring(err),
            choice1_text = _("Retry"),
            choice1_callback = function()
                self:_startLookup(file, current, chain)
            end,
            choice2_text = _("Edit myself"),
            choice2_callback = function()
                self:_showDiff(file, current, nil, chain)
            end,
        })
    end
end

function Rebind:_offerManualEdit(file, current, chain, text)
    UIManager:show(ConfirmBox:new{
        text = text or _("No match found.\n\nEdit the metadata yourself?"),
        ok_text = _("Edit"),
        cancel_text = _("Cancel"),
        ok_callback = function()
            self:_showDiff(file, current, nil, chain)
        end,
    })
end

function Rebind:_showEditions(book, chain, on_pick)
    NetworkMgr:runWhenOnline(function()
        Trapper:wrap(function()
            Trapper:info(_("Loading editions…"))
            local ok, editions = pcall(function()
                return Lookup.provider_for(chain, book):editions(book)
            end)
            Trapper:clear()

            if not ok or type(editions) ~= "table" or #editions == 0 then
                info(string.format(_("No editions found for this book on %s."), book.provider_name))
                return
            end

            local list
            local rows = {}
            for _i, edition in ipairs(editions) do
                rows[#rows + 1] = {
                    title = edition.title or _("Unknown edition"),
                    subtitle = Labels.edition_label(edition),
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

function Rebind:_showChooser(results, chain, handlers)
    local chooser
    local rows = {}
    for _i, book in ipairs(results) do
        local row = {
            title = book.title or _("Unknown title"),
            subtitle = Labels.match_subtitle(book),
            on_select = function()
                UIManager:close(chooser)
                handlers.on_match(book)
            end,
        }
        if chain and book.has_editions then
            row.action_text = _("Editions ▸")
            row.on_action = function()
                self:_showEditions(book, chain, function(edition)
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

function Rebind:_chooseLanguage(picker, current, chain, shown, on_done)
    picker:chooseLanguage(function(code)
        local book = shown.book
        local name = select(2, resolve_language(code)) or code
        self.settings:saveSetting("preferred_language", code)
        self.settings:flush()

        if not (chain and book and book.has_editions) then
            self:_offerGapTranslation(picker, code, name,
                _("Rebind has no match for this book, so it cannot look for a %1 edition."))
            on_done()
            return
        end
        self:_pickEditionInLanguage(picker, current, book, chain, code, name, shown, on_done)
    end)
end

function Rebind:_pickEditionInLanguage(picker, current, book, chain, code, name, shown, on_done)
    NetworkMgr:runWhenOnline(function()
        Trapper:wrap(function()
            Trapper:info(T(_("Looking for a %1 edition…"), name))
            local ok, editions = pcall(function()
                return Lookup.provider_for(chain, book):editions(book, code)
            end)
            Trapper:clear()

            if not ok or type(editions) ~= "table" or #editions == 0 then
                self:_offerGapTranslation(picker, code, name,
                    _("%2 has no %1 edition of this book."), book.provider_name)
                on_done()
                return
            end

            self:_showEditionList(editions, name, function(edition)
                self:_useSource(picker, current, shown, edition)
                on_done()
                self:_offerGapTranslation(picker, code, name,
                    _("%2 has no %1 description or genres. Those exist per book, not per edition."), book.provider_name)
            end)
        end)
    end)
end

function Rebind:_showEditionList(editions, name, on_pick)
    local dialog
    local buttons = {}
    for _i, edition in ipairs(editions) do
        local label = Labels.edition_label(edition, true)
        if label == "" then
            label = edition.title or _("Unknown edition")
        elseif edition.title and edition.title ~= "" then
            label = edition.title .. " - " .. label
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

function Rebind:_offerGapTranslation(picker, code, name, reason, provider_name)
    local items = picker:translatableItems()
    if #items == 0 then
        info(T(reason, name, provider_name))
        return
    end

    local labels = {}
    for _, item in ipairs(items) do
        labels[#labels + 1] = item.field.label
    end

    UIManager:show(ConfirmBox:new{
        text = T(reason, name, provider_name) .. "\n\n"
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
    local proposed = source or {}
    shown.proposed = proposed
    picker:setFields(
        Fields.build(current, proposed),
        proposed.edition_id and Labels.header_label(proposed) or nil,
        proposed.provider_name
    )
end

function Rebind:_runLookup(shown, search, on_results)
    NetworkMgr:runWhenOnline(function()
        Trapper:wrap(function()
            local busy = Logo.show_message(_("Looking up your book…"))
            local ok, found = pcall(search)
            Logo.close_message(busy)
            if not ok then
                info(_("Lookup failed:\n") .. tostring(found))
                return
            end
            if type(found.matches) ~= "table" or #found.matches == 0 then
                info(Lookup.not_found_text(found))
                return
            end
            shown.results = found.matches
            on_results(found.matches)
        end)
    end)
end

function Rebind:_findMatches(current, chain, shown, on_results)
    if #shown.results > 0 then
        on_results(shown.results)
        return
    end
    self:_runLookup(shown, function()
        return Lookup.find(chain, current)
    end, on_results)
end

function Rebind:_showSearchDialog(current, provider, on_search)
    local terms = Lookup.search_terms(current)
    local dialog
    dialog = MultiInputDialog:new{
        title = string.format(_("Search %s"), provider.name),
        fields = {
            { description = _("Title"), text = terms.title, hint = _("Title") },
            { description = _("Author"), text = terms.author, hint = _("Author") },
            { description = _("ISBN"), text = terms.isbn, hint = _("ISBN") },
        },
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
                {
                    text = _("Search"),
                    callback = function()
                        local values = dialog:getFields()
                        UIManager:close(dialog)
                        on_search(Lookup.with_terms(current, {
                            title = values[1],
                            author = values[2],
                            isbn = values[3],
                        }))
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Rebind:_findInProvider(provider, meta, shown, on_results)
    if not Lookup.searchable(meta) then
        info(_("Enter a title or an ISBN to search."))
        return
    end
    self:_runLookup(shown, function()
        return Lookup.find_in(provider, meta)
    end, on_results)
end

function Rebind:_chooseProvider(chain, shown, on_pick)
    local list
    local rows = {}
    for _i, provider in ipairs(chain) do
        rows[#rows + 1] = {
            title = provider.name,
            selected = shown.book ~= nil and shown.book.provider_id == provider.id,
            on_select = function()
                UIManager:close(list, "ui")
                on_pick(provider)
            end,
        }
    end
    list = ChoiceList.show{
        title = _("Look up in"),
        rows = rows,
    }
end

function Rebind:_sourceHandlers(picker, current, chain, shown, close)
    local function pick(book)
        shown.book = book
        self:_useSource(picker, current, shown, book)
        close()
    end
    return {
        on_match = function(book)
            self:_withAutoEdition(current, chain, book, pick)
        end,
        on_edition = pick,
        on_none = function()
            pick(nil)
        end,
    }
end

function Rebind:_sourceRows(picker, current, chain, shown, close)
    local rows = {}
    local proposed = shown.proposed or {}
    local function change_book()
        self:_findMatches(current, chain, shown, function(results)
            self:_showChooser(results, chain, self:_sourceHandlers(picker, current, chain, shown, close))
        end)
    end
    local function change_provider()
        if #chain == 0 then
            info(Lookup.not_found_text(Lookup.find(chain, current)))
            return
        end
        self:_chooseProvider(chain, shown, function(provider)
            self:_showSearchDialog(current, provider, function(meta)
                self:_findInProvider(provider, meta, shown, function(results)
                    self:_showChooser(results, chain, self:_sourceHandlers(picker, current, chain, shown, close))
                end)
            end)
        end)
    end
    local function change_edition()
        self:_showEditions(shown.book, chain, function(edition)
            self:_useSource(picker, current, shown, edition)
            close()
        end)
    end
    local function change_language()
        self:_chooseLanguage(picker, current, chain, shown, close)
    end

    local book_text = _("None")
    if shown.book and proposed.title then
        book_text = proposed.title
        if proposed.authors and proposed.authors[1] then
            book_text = book_text .. " · " .. proposed.authors[1]
        end
    end
    if chain then
        rows[#rows + 1] = {
            title = _("Book"),
            subtitle = book_text,
            action_text = _("Change ▸"),
            on_select = change_book,
            on_action = change_book,
        }
    end
    if chain then
        rows[#rows + 1] = {
            title = _("Provider"),
            subtitle = Lookup.provider_text(shown.book),
            action_text = _("Change ▸"),
            on_select = change_provider,
            on_action = change_provider,
        }
    end
    if chain and shown.book and shown.book.has_editions then
        local edition_text = proposed.edition_id and Labels.edition_label(proposed) or ""
        if edition_text == "" then
            edition_text = _("None chosen")
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
    local function change_providers()
        self:showLookupProviders(function()
            self:_refreshChain(chain)
            shown.results = {}
            close()
            self:_showSource(picker, current, chain, shown)
        end)
    end
    rows[#rows + 1] = {
        title = _("Lookup providers"),
        subtitle = self:_chainSummary(),
        action_text = _("Change ▸"),
        on_select = change_providers,
        on_action = change_providers,
    }
    if shown.book then
        rows[#rows + 1] = {
            title = string.format(_("Don't use %s"), shown.book.provider_name),
            subtitle = _("Type every value yourself"),
            on_select = self:_sourceHandlers(picker, current, chain, shown, close).on_none,
        }
    end
    return rows
end

function Rebind:_showSource(picker, current, chain, shown)
    local list
    local function close()
        UIManager:close(list, "ui")
    end
    list = ChoiceList.show{
        title = _("Source"),
        rows = self:_sourceRows(picker, current, chain, shown, close),
    }
end

function Rebind:_saveAsDefaults()
    return {
        library = self:libraryRoot(),
        sort = self.settings:isTrue("move_after_rebind") and self:libraryRoot() ~= nil,
        rename = self:renameFile(),
        keep_backup = self:keepBackup(),
        filename_template = self:filenameTemplate(),
        folder_template = self:folderTemplate(),
        custom_filename_template = self:customFilenameTemplate(),
        custom_folder_template = self:customFolderTemplate(),
    }
end

function Rebind:_showDiff(file, current, book, chain, results, on_apply, row)
    local proposed = book or {}
    local shown = { book = book, proposed = proposed, results = results or {} }
    if not (row and row.save_as) then
        local save_as = self:_saveAsDefaults()
        save_as.source_path = file
        save_as.metadata = current
        row = { save_as = save_as }
    end

    local picker = DiffPicker:new{
        fields = Fields.build(current, proposed),
        edition_label = proposed.edition_id and Labels.header_label(proposed) or nil,
        provider_name = proposed.provider_name,
        on_open_source = chain and function(picker)
            self:_showSource(picker, current, chain, shown)
        end or nil,
        translate_targets = self:_translateTargets(current, shown),
        on_translate = self:_translateHandler(),
        save_as = row.save_as,
        on_save_as_change = row.on_change or function(save_as)
            self:_rememberSaveAs(save_as)
        end,
        on_choose_library = function(on_ready)
            self:_chooseLibraryRoot(on_ready)
        end,
        on_apply = function(changes, opts)
            if on_apply then
                on_apply(changes, opts)
            else
                self:_write(file, changes, opts.keep_backup, opts.dest)
            end
        end,
    }
    UIManager:show(picker)
end

function Rebind:batchStartFolder()
    local file = self:currentFile()
    if file then
        return Organize.dirname(file)
    end
    local chooser = self.ui and self.ui.file_chooser
    if chooser and chooser.path then
        return chooser.path
    end
    return self:defaultBrowseDir()
end

function Rebind:selectedBooks()
    local ui = self.ui
    if ui and ui.selected_files then
        return Batch.selection(ui.selected_files)
    end
    return { files = {}, folders = 0 }
end

function Rebind:batchOpening(opts)
    if opts.folder then
        return { folder = opts.folder, tick_all = true }
    end
    local selected = self:selectedBooks()
    if #selected.files > 0 then
        if selected.folders > 1 then
            return { folder = self:batchStartFolder(), selection = selected }
        end
        return { folder = Organize.dirname(selected.files[1]), ticked = selected.files }
    end
    return { folder = self:batchStartFolder() }
end

function Rebind:onRebindSeveral()
    self:openChooseBooks{}
    return true
end

function Rebind:openChooseBooks(opts)
    local opening = self:batchOpening(opts)
    local folder = opening.folder
    if not folder then
        info(_("Could not find a folder to start from."))
        return true
    end
    ChooseBooks.show{
        folder = folder,
        selection = opening.selection,
        ticked = opening.ticked,
        tick_all = opening.tick_all,
        has_providers = function()
            return #self:enabledProviderIds() > 0
        end,
        on_change_folder = function(on_pick)
            local PathChooser = require("ui/widget/pathchooser")
            UIManager:show(PathChooser:new{
                title = _("Choose a folder"),
                select_file = false,
                show_files = false,
                path = folder,
                onConfirm = on_pick,
            })
        end,
        on_change_providers = function(on_close)
            self:showLookupProviders(on_close)
        end,
        interval = Batch.DEFAULT_INTERVAL,
        on_lookup = function(files, choose_screen)
            self:_startBatch(files, choose_screen)
        end,
    }
    return true
end

function Rebind:_startBatch(files, choose_screen)
    NetworkMgr:runWhenOnline(function()
        local batch = Batch.new{
            files = files,
            chain = self:providerChain(),
            preferred_language = self.settings:readSetting("preferred_language"),
            save_as = self:_saveAsDefaults(),
            open_file = self:currentFile(),
            same_file = function(a, b)
                local realpath = require("ffi/util").realpath
                return (realpath(a) or a) == (realpath(b) or b)
            end,
        }
        local progress
        local function summary()
            local counts = batch:counts()
            return string.format(_("%d sure matches · %d to review so far"), counts.sure, counts.review)
        end
        local function heading(done)
            return T(_("Looking up your books… %1 of %2"), done, #files)
        end
        local function finish()
            self:_showBatchReview(batch)
            UIManager:close(progress, "ui")
        end
        local function step()
            if batch.stopped or #batch.pending == 0 then
                finish()
                return
            end
            local delay = batch:wait_time()
            if delay > 0 then
                UIManager:scheduleIn(delay, step)
                return
            end
            progress:update{
                done = batch:done_count() + 1,
                heading = heading(batch:done_count() + 1),
                filename = Organize.basename(batch.pending[1]),
                summary = summary(),
            }
            Trapper:wrap(function()
                batch:lookup_next()
                progress:update{ done = batch:done_count(), heading = heading(batch:done_count()), summary = summary() }
                UIManager:scheduleIn(0.05, step)
            end)
        end
        progress = BatchProgress:new{
            heading = heading(0),
            stop_text = _("Stop and review what's found"),
            total = #files,
            done = 0,
            summary = summary(),
            on_stop = function()
                batch:stop()
            end,
        }
        UIManager:show(progress)
        UIManager:close(choose_screen, "ui")
        UIManager:scheduleIn(0.05, step)
    end)
end

function Rebind:_announceBatchChanges(batch)
    local files = batch:take_changed()
    if #files == 0 then
        return
    end
    for _i, file in ipairs(files) do
        UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", file))
    end
    UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
end

function Rebind:_showBatchReview(batch)
    ReviewList.show{
        batch = batch,
        on_close = function()
            self:_announceBatchChanges(batch)
        end,
        on_open = function(entry, screen)
            self:_openBatchRow(batch, screen, entry)
        end,
        on_save_as = function(screen)
            SaveAs.show{
                state = batch:save_as_state(),
                on_change = function(save_as)
                    self:_rememberSaveAs(save_as)
                end,
                on_choose_library = function(on_ready)
                    self:_chooseLibraryRoot(on_ready)
                end,
                on_close = function()
                    screen:refresh()
                end,
            }
        end,
        on_rebind = function(screen)
            self:_rebindSureMatches(batch, screen)
        end,
    }
end

function Rebind:_rebindSureMatches(batch, screen)
    local total = batch:begin_rebind()
    if total == 0 then
        return
    end
    local progress
    local function heading(done)
        return T(_("Rebinding your books… %1 of %2"), done, total)
    end
    local function step()
        if batch.stopped or #batch.queue == 0 then
            UIManager:close(progress, "ui")
            screen:refresh()
            return
        end
        progress:update{
            done = batch.queue_done,
            heading = heading(batch.queue_done + 1),
            filename = batch.queue[1].name,
        }
        batch:rebind_next()
        progress:update{ done = batch.queue_done, heading = heading(math.min(batch.queue_done + 1, total)) }
        UIManager:scheduleIn(0.05, step)
    end
    progress = BatchProgress:new{
        heading = heading(1),
        stop_text = _("Stop after this book"),
        total = total,
        done = 0,
        filename = batch.queue[1].name,
        on_stop = function()
            batch:stop()
        end,
    }
    UIManager:show(progress)
    UIManager:scheduleIn(0.05, step)
end

function Rebind:_openBatchRow(batch, screen, entry)
    if entry.state == "done" then
        return
    end
    if entry.kind == "open" then
        info(T(_("%1 is open in the reader.\n\nClose the batch and rebind it on its own from the reader."), entry.name))
        return
    end
    local chain = batch.chain
    local function on_apply(changes, opts)
        self:_applyBatchRow(batch, screen, entry, changes, opts)
    end
    local function show(book)
        self:_showDiff(entry.file, entry.current, book, chain, entry.matches or {}, on_apply, {
            save_as = batch:save_as_for(entry),
            on_change = function(save_as)
                entry.save_as = save_as
            end,
        })
    end
    if entry.state == "sure" then
        show(entry.book)
    elseif entry.kind == "write_failed" or entry.kind == "not_moved" then
        local prefix = entry.kind == "not_moved" and move_failed_text(true) or _("Update failed:\n")
        UIManager:show(InfoMessage:new{
            text = prefix .. tostring(entry.error),
            dismiss_callback = function()
                show(entry.book)
            end,
        })
    elseif entry.kind == "failed" then
        NetworkMgr:runWhenOnline(function()
            Trapper:wrap(function()
                local busy = Logo.show_message(_("Looking up your book…"))
                batch:retry(entry)
                Logo.close_message(busy)
                screen:refresh()
            end)
        end)
    elseif entry.kind == "matches" then
        self:_showChooser(entry.matches, chain, {
            on_match = function(book)
                self:_withAutoEdition(entry.current, chain, book, show)
            end,
            on_edition = show,
            on_none = function()
                show(nil)
            end,
        })
    elseif entry.kind == "check" then
        self:_withAutoEdition(entry.current, chain, entry.book, show)
    else
        show(nil)
    end
end

function Rebind:_applyBatchRow(batch, screen, entry, changes, opts)
    local progress = InfoMessage:new{ text = _("Updating EPUB…") }
    UIManager:show(progress)
    UIManager:scheduleIn(0.1, function()
        local outcome = batch:apply(entry, changes, opts)
        UIManager:close(progress)
        if not outcome.ok then
            local prefix = outcome.stage == "move" and move_failed_text(outcome.rewritten) or _("Update failed:\n")
            info(prefix .. outcome.error)
        end
        screen:refresh()
    end)
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
    local progress
    local opts = { keep_backup = keep_backup, dest = dest }
    if is_open_book then
        opts.relocate = function(from, to)
            if progress then
                UIManager:close(progress)
            end
            self:_closeOpenBook()
            return Organize.relocate(from, to)
        end
    end

    if not next(changes) then
        self:_report(file, is_open_book, Apply.run(file, changes, opts))
        return
    end

    progress = InfoMessage:new{ text = _("Updating EPUB…") }
    UIManager:show(progress)
    UIManager:scheduleIn(0.1, function()
        local outcome = Apply.run(file, changes, opts)
        UIManager:close(progress)
        self:_report(file, is_open_book, outcome)
    end)
end

function Rebind:_report(file, is_open_book, outcome)
    if outcome.rewritten or outcome.moved_dest then
        UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", file))
        UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
    end

    if outcome.stage == "write" then
        info(_("Update failed:\n") .. outcome.error)
    elseif outcome.stage == "move" then
        if is_open_book then
            self:_reopenBook(file)
        end
        info(move_failed_text(outcome.rewritten) .. outcome.error)
    elseif outcome.moved_dest and is_open_book then
        self:_reopenBook(outcome.moved_dest)
    elseif outcome.moved_dest then
        self:_finish(outcome.moved_dest, false, outcome.backup, outcome.moved_dest, outcome.rewritten)
    else
        self:_finish(file, is_open_book, outcome.backup, nil, outcome.rewritten)
    end
end

function Rebind:_closeOpenBook()
    local ui = self.ui
    ui.tearing_down = true
    ui:handleEvent(Event:new("CloseReaderMenu"))
    ui:handleEvent(Event:new("CloseConfigMenu"))
    ui:onClose(false)
end

function Rebind:_reopenBook(file)
    local ReaderUI = require("apps/reader/readerui")
    ReaderUI:showReader(file)
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
