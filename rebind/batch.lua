local _ = require("gettext")

local Apply = require("rebind/apply")
local Epub = require("rebind/epub")
local Fields = require("rebind/fields")
local Lookup = require("rebind/lookup")
local Organize = require("rebind/organize")
local PickerState = require("rebind/picker_state")

local Batch = {}
Batch.__index = Batch

Batch.DEFAULT_INTERVAL = 1.5
Batch.LOST_CONNECTION_AFTER = 2

local ACCENTS = {
    "a", "a", "a", "a", "a", "a", "ae", "c", "e", "e", "e", "e", "i", "i", "i", "i",
    "d", "n", "o", "o", "o", "o", "o", "", "o", "u", "u", "u", "u", "y", "th", "ss",
}

local EXTENDED = {
    ["ā"] = "a", ["ă"] = "a", ["ą"] = "a", ["ć"] = "c", ["č"] = "c", ["ď"] = "d", ["đ"] = "d",
    ["ē"] = "e", ["ė"] = "e", ["ę"] = "e", ["ě"] = "e", ["ğ"] = "g", ["ī"] = "i", ["į"] = "i",
    ["ł"] = "l", ["ń"] = "n", ["ň"] = "n", ["ō"] = "o", ["ő"] = "o", ["œ"] = "oe", ["ř"] = "r",
    ["ś"] = "s", ["š"] = "s", ["ş"] = "s", ["ť"] = "t", ["ū"] = "u", ["ů"] = "u", ["ű"] = "u",
    ["ź"] = "z", ["ż"] = "z", ["ž"] = "z",
    ["Ā"] = "a", ["Ă"] = "a", ["Ą"] = "a", ["Ć"] = "c", ["Č"] = "c", ["Ď"] = "d", ["Đ"] = "d",
    ["Ē"] = "e", ["Ė"] = "e", ["Ę"] = "e", ["Ě"] = "e", ["Ğ"] = "g", ["Ī"] = "i", ["Į"] = "i",
    ["Ł"] = "l", ["Ń"] = "n", ["Ň"] = "n", ["Ō"] = "o", ["Ő"] = "o", ["Œ"] = "oe", ["Ř"] = "r",
    ["Ś"] = "s", ["Š"] = "s", ["Ş"] = "s", ["Ť"] = "t", ["Ū"] = "u", ["Ů"] = "u", ["Ű"] = "u",
    ["Ź"] = "z", ["Ż"] = "z", ["Ž"] = "z",
}

local function fold_accents(text)
    text = text:gsub("\195([\128-\191])", function(byte)
        local code = 0xC0 + byte:byte() - 0x80
        local index = (code - 0xC0) % 32 + 1
        if code == 0xD7 or code == 0xF7 then
            return " "
        elseif code == 0xFF then
            return "y"
        end
        return ACCENTS[index]
    end)
    return (text:gsub("[\196\197][\128-\191]", function(char)
        return EXTENDED[char] or char
    end))
end

local function clean(text)
    text = fold_accents(tostring(text or "")):lower()
    text = text:gsub("’", ""):gsub("['`]", ""):gsub("[^%w\128-\255]+", " ")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Batch.normalize_title(title)
    local text = clean(title)
    text = text:gsub("^the ", ""):gsub("^an ", ""):gsub("^a ", "")
    return text
end

function Batch.normalize_author(name)
    name = tostring(name or "")
    local last, first = name:match("^([^,]+),%s*(.+)$")
    if last then
        name = first .. " " .. last
    end
    return clean(name)
end

function Batch.agrees(current, match)
    local title = Batch.normalize_title(current.title)
    if title == "" or title ~= Batch.normalize_title(match.title) then
        return false
    end
    local wanted = {}
    for _i, author in ipairs(current.authors or {}) do
        local name = Batch.normalize_author(author)
        if name ~= "" then
            wanted[name] = true
        end
    end
    for _i, author in ipairs(match.authors or {}) do
        if wanted[Batch.normalize_author(author)] then
            return true
        end
    end
    return false
end

local function chunks(text)
    local out, pos = {}, 1
    text = text:lower()
    while pos <= #text do
        local digits = text:match("^%d+", pos)
        if digits then
            out[#out + 1] = tonumber(digits)
            pos = pos + #digits
        else
            local word = text:match("^%D+", pos)
            out[#out + 1] = word
            pos = pos + #word
        end
    end
    return out
end

function Batch.natural_less(a, b)
    local left, right = chunks(a), chunks(b)
    for i = 1, math.min(#left, #right) do
        local x, y = left[i], right[i]
        if x ~= y then
            local x_num, y_num = type(x) == "number", type(y) == "number"
            if x_num and y_num then
                return x < y
            elseif x_num ~= y_num then
                return x_num
            end
            return x < y
        end
    end
    if #left ~= #right then
        return #left < #right
    end
    return a < b
end

function Batch.lfs_fs()
    local lfs = require("libs/libkoreader-lfs")
    return {
        list = function(dir)
            local names = {}
            local ok = pcall(function()
                for name in lfs.dir(dir) do
                    if name:sub(1, 1) ~= "." then
                        names[#names + 1] = name
                    end
                end
            end)
            return ok and names or {}
        end,
        is_dir = function(path)
            return lfs.symlinkattributes(path, "mode") == "directory"
        end,
    }
end

function Batch.trim_folder(folder)
    return (folder:gsub("/+$", ""))
end

function Batch.collect(folder, opts)
    opts = opts or {}
    local fs = opts.fs or Batch.lfs_fs()
    local found = {}
    local function walk(dir, rel)
        for _i, name in ipairs(fs.list(dir)) do
            local path = dir .. "/" .. name
            if fs.is_dir(path) then
                if opts.include_subfolders and not name:match("%.sdr$") then
                    walk(path, rel .. name .. "/")
                end
            elseif Epub.is_epub(name) then
                found[#found + 1] = { path = path, key = rel .. name }
            end
        end
    end
    walk(Batch.trim_folder(folder), "")
    table.sort(found, function(x, y)
        return Batch.natural_less(x.key, y.key)
    end)
    local files = {}
    for _i, item in ipairs(found) do
        files[#files + 1] = item.path
    end
    return files
end

function Batch.selection(selected)
    local files, folders, seen = {}, 0, {}
    for path in pairs(selected or {}) do
        if Epub.is_epub(path) then
            files[#files + 1] = path
            local folder = Organize.dirname(path)
            if not seen[folder] then
                seen[folder] = true
                folders = folders + 1
            end
        end
    end
    table.sort(files, Batch.natural_less)
    return { files = files, folders = folders }
end

function Batch.selection_label(selection)
    return string.format(_("Selected books · %d books from %d folders"), #selection.files, selection.folders)
end

Batch.LARGE_SELECTION = 300

function Batch.needs_confirmation(count)
    return count > Batch.LARGE_SELECTION
end

local function with_commas(count)
    local text = tostring(count)
    while true do
        local replaced, n = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        text = replaced
        if n == 0 then
            return text
        end
    end
end

function Batch.large_title(count)
    return string.format(_("Look up %s books?"), with_commas(count))
end

local function duration_text(seconds)
    local minutes = math.floor(seconds / 60 + 0.5)
    if minutes <= 1 then
        return _("about a minute")
    elseif minutes < 60 then
        return string.format(_("about %d minutes"), minutes)
    end
    local hours = math.floor(minutes / 60 + 0.5)
    if hours == 1 then
        return _("about an hour")
    end
    return string.format(_("about %d hours"), hours)
end

function Batch.large_text(count, interval)
    return string.format(
        _("This takes %s, and the device is kept awake. You can stop and review what's found at any time."),
        duration_text(count * (interval or Batch.DEFAULT_INTERVAL))
    )
end

local function default_clock()
    local ok, socket = pcall(require, "socket")
    if ok and type(socket) == "table" and type(socket.gettime) == "function" then
        return socket.gettime
    end
    return os.time
end

local function default_sleep(seconds)
    require("ffi/util").sleep(seconds)
end

function Batch.new(opts)
    return setmetatable({
        pending = { unpack(opts.files or {}) },
        entries = {},
        chain = opts.chain or {},
        read_metadata = opts.read_metadata or Epub.read_metadata,
        clock = opts.clock or default_clock(),
        sleep = opts.sleep or default_sleep,
        changed = {},
        interval = opts.interval or Batch.DEFAULT_INTERVAL,
        preferred_language = opts.preferred_language,
        rewrite = opts.rewrite,
        relocate = opts.relocate,
        save_as = opts.save_as or {},
        open_file = opts.open_file,
        same_file = opts.same_file or function(a, b)
            return a == b
        end,
        queue = {},
        queue_total = 0,
        queue_done = 0,
        results = { rebound = 0, sorted = 0, failed = 0, not_moved = 0 },
        total = #(opts.files or {}),
        skips = {},
        skip_order = {},
        stopped = false,
        last_call = nil,
        failed_in_a_row = 0,
    }, Batch)
end

function Batch:done_count()
    return self.total - #self.pending
end

function Batch:counts()
    local counts = { sure = 0, review = 0, done = 0 }
    for _i, entry in ipairs(self.entries) do
        counts[entry.state] = counts[entry.state] + 1
    end
    return counts
end

function Batch:stop()
    self.stopped = true
end

function Batch:wait_time()
    if not self.last_call then
        return 0
    end
    return math.max(0, self.last_call + self.interval - self.clock())
end

function Batch:_forget_skips(entry)
    for name in pairs(entry.skipped or {}) do
        self.skips[name].count = self.skips[name].count - 1
    end
    entry.skipped = {}
end

function Batch:_note_skips(entry, found)
    for _i, skipped in ipairs(found.skipped or {}) do
        local name = skipped.provider.name
        local note = self.skips[name]
        if not note then
            note = { provider = name, count = 0, reason = skipped.reason }
            self.skips[name] = note
            self.skip_order[#self.skip_order + 1] = name
        end
        if not entry.skipped[name] then
            entry.skipped[name] = true
            note.count = note.count + 1
        end
    end
end

function Batch:skip_notices()
    local lines = {}
    for _i, name in ipairs(self.skip_order) do
        local note = self.skips[name]
        if note.count == 1 then
            lines[#lines + 1] = string.format(_("%s was skipped for 1 book: %s."), name, note.reason)
        elseif note.count > 1 then
            lines[#lines + 1] = string.format(_("%s was skipped for %d books: %s."), name, note.count, note.reason)
        end
    end
    return lines
end

function Batch:_sure_entry(entry, current, match, isbn)
    local book = Lookup.auto_edition(self.chain, current, match, self.preferred_language)
    local state = PickerState.new(Fields.build(current, book), book.provider_name)
    entry.state = "sure"
    entry.book = book
    entry.isbn = isbn
    entry.changes = state:change_count()
end

function Batch:_mark_open(entry)
    if self.open_file and self.same_file(entry.file, self.open_file) then
        entry.state, entry.kind = "review", "open"
    end
end

function Batch:_classify(entry)
    entry.state, entry.kind, entry.book, entry.matches = "review", nil, nil, nil
    self:_forget_skips(entry)
    local current, err = self.read_metadata(entry.file)
    if not current then
        entry.kind, entry.error = "failed", tostring(err)
        return
    end
    entry.current = current
    local found = Lookup.find(self.chain, current)
    self:_note_skips(entry, found)
    if Lookup.all_failed(found) then
        entry.kind, entry.error = "failed", Lookup.skipped_text(found)
        return true
    end
    local matches = found.matches
    entry.matches = matches
    if #matches == 0 then
        entry.kind = "none"
    elseif found.method == "isbn" then
        self:_sure_entry(entry, current, matches[1], true)
    elseif #matches == 1 and Batch.agrees(current, matches[1]) then
        self:_sure_entry(entry, current, matches[1], false)
    elseif #matches == 1 then
        entry.kind = "check"
        entry.book = matches[1]
    else
        entry.kind = "matches"
    end
end

function Batch:_run_lookup(entry)
    local delay = self:wait_time()
    if delay > 0 then
        self.sleep(delay)
    end
    local ok, unreachable = pcall(self._classify, self, entry)
    if not ok then
        entry.state, entry.kind, entry.error = "review", "failed", tostring(unreachable)
    end
    self.last_call = self.clock()
    self:_mark_open(entry)
    return unreachable == true
end

function Batch:_new_entry(file, reason)
    return {
        file = file,
        name = Organize.basename(file),
        skipped = {},
        state = reason and "review" or nil,
        kind = reason and "failed" or nil,
        error = reason,
    }
end

function Batch:lookup_next()
    if self.stopped or #self.pending == 0 then
        return false
    end
    local file = table.remove(self.pending, 1)
    local entry = self:_new_entry(file)
    self.entries[#self.entries + 1] = entry
    if self:_run_lookup(entry) then
        self.failed_in_a_row = self.failed_in_a_row + 1
    else
        self.failed_in_a_row = 0
    end
    if self.failed_in_a_row >= Batch.LOST_CONNECTION_AFTER then
        self:_fail_pending(entry.error)
    end
    return true
end

function Batch:_fail_pending(reason)
    for _i, file in ipairs(self.pending) do
        local entry = self:_new_entry(file, reason)
        self:_mark_open(entry)
        self.entries[#self.entries + 1] = entry
    end
    self.pending = {}
end

function Batch:lookup_all()
    while self:lookup_next() do
    end
end

function Batch:retry(entry)
    self:_run_lookup(entry)
end

function Batch:sections()
    local by_state = { review = {}, sure = {}, done = {} }
    for _i, entry in ipairs(self.entries) do
        table.insert(by_state[entry.state], entry)
    end
    local sections = {}
    for _i, key in ipairs({ "review", "sure", "done" }) do
        local entries = by_state[key]
        if #entries > 0 then
            table.sort(entries, function(x, y)
                return Batch.natural_less(x.name, y.name)
            end)
            sections[#sections + 1] = { key = key, entries = entries }
        end
    end
    return sections
end

function Batch:tag(entry)
    if entry.state == "done" then
        return entry.sorted and _("✓ Sorted") or _("✓ Rebound")
    end
    if entry.state == "sure" then
        if entry.changes == 0 then
            return _("No changes")
        end
        local changes = entry.changes == 1 and _("1 change") or string.format(_("%d changes"), entry.changes)
        local text = entry.book.provider_name .. " · " .. changes
        return entry.isbn and (_("ISBN") .. " · " .. text) or text
    end
    if entry.kind == "open" then
        return _("Open in the reader")
    elseif entry.kind == "write_failed" then
        return _("Write failed")
    elseif entry.kind == "not_moved" then
        return _("Not moved")
    elseif entry.kind == "matches" then
        return string.format(_("%d matches"), #entry.matches)
    elseif entry.kind == "check" then
        return _("Check match")
    elseif entry.kind == "none" then
        return _("No match")
    end
    return _("Lookup failed")
end

function Batch:save_as_for(entry)
    local save_as = {}
    for key, value in pairs(entry.save_as or self.save_as) do
        save_as[key] = value
    end
    save_as.source_path = entry.file
    save_as.metadata = entry.current
    return save_as
end

function Batch:save_as_summary()
    local save_as = self.save_as
    local top = _("Save as for this batch") .. " · " .. (save_as.keep_backup and _("backup kept") or _("no backup"))
    local folder = (save_as.sort and save_as.library) and _("Sort into your library") or _("Leave where it is")
    local name = save_as.rename and (_("rename to") .. " " .. Organize.pattern_label(save_as.filename_template))
        or _("keep current name")
    return top, folder .. " · " .. name
end

function Batch:save_as_state()
    local sample = self.entries[1]
    for _i, entry in ipairs(self.entries) do
        if entry.current then
            sample = entry
            break
        end
    end
    local state = PickerState.new({})
    self.save_as.source_path = sample and sample.file or ""
    self.save_as.metadata = sample and sample.current or {}
    state:set_save_as(self.save_as)
    return state
end

function Batch:_picker_state(entry)
    local state = PickerState.new(Fields.build(entry.current, entry.book), entry.book.provider_name)
    state:set_save_as(self:save_as_for(entry))
    return state
end

function Batch:_settle(entry, outcome, changes)
    if outcome.rewritten or outcome.moved_dest then
        self.changed[#self.changed + 1] = entry.file
    end
    if outcome.ok then
        local dest = outcome.moved_dest or entry.file
        entry.state, entry.kind, entry.error = "done", nil, nil
        entry.sorted = Organize.dirname(dest) ~= Organize.dirname(entry.file)
        entry.new_path = dest
    elseif outcome.stage == "move" then
        if outcome.rewritten then
            entry.current = Organize.with_changes(entry.current, changes)
        end
        entry.state, entry.kind, entry.error = "review", "not_moved", outcome.error
    end
end

function Batch:apply(entry, changes, opts)
    local outcome = Apply.run(entry.file, changes, {
        keep_backup = opts.keep_backup,
        dest = opts.dest,
        rewrite = self.rewrite,
        relocate = self.relocate,
    })
    self:_settle(entry, outcome, changes)
    return outcome
end

function Batch:unfinished_count()
    local count = 0
    for _i, entry in ipairs(self.entries) do
        if entry.state ~= "done" and entry.kind ~= "open" then
            count = count + 1
        end
    end
    return count
end

function Batch:close_prompt()
    local count = self:unfinished_count()
    if count == 0 then
        return nil
    elseif count == 1 then
        return _("1 book hasn't been rebound. Its lookup will be lost.")
    end
    return string.format(_("%d books haven't been rebound. Their lookups will be lost."), count)
end

function Batch:sure_count()
    local count = 0
    for _i, entry in ipairs(self.entries) do
        if entry.state == "sure" then
            count = count + 1
        end
    end
    return count
end

function Batch:begin_rebind()
    self.stopped = false
    self.queue = {}
    for _i, entry in ipairs(self.entries) do
        if entry.state == "sure" then
            self.queue[#self.queue + 1] = entry
        end
    end
    table.sort(self.queue, function(x, y)
        return Batch.natural_less(x.name, y.name)
    end)
    self.queue_total = #self.queue
    self.queue_done = 0
    return self.queue_total
end

function Batch:_rebind_entry(entry)
    local state = self:_picker_state(entry)
    local changes = state:changes()
    local outcome = Apply.run(entry.file, changes, {
        keep_backup = state.save_as.keep_backup,
        dest = state:destination(),
        rewrite = self.rewrite,
        relocate = self.relocate,
    })
    self:_settle(entry, outcome, changes)
    return outcome
end

function Batch:rebind_next()
    if self.stopped or #self.queue == 0 then
        return false
    end
    local entry = table.remove(self.queue, 1)
    local ok, outcome = xpcall(self._rebind_entry, tostring, self, entry)
    if not ok then
        outcome = { ok = false, stage = "write", error = outcome }
    end
    if outcome.ok then
        self.results.rebound = self.results.rebound + 1
        self.results.sorted = self.results.sorted + (entry.sorted and 1 or 0)
    elseif outcome.stage == "move" then
        self.results.not_moved = self.results.not_moved + 1
    else
        self.results.failed = self.results.failed + 1
        entry.state, entry.kind, entry.error = "review", "write_failed", outcome.error
    end
    self.queue_done = self.queue_done + 1
    return true
end

function Batch:rebind_all()
    self:begin_rebind()
    while self:rebind_next() do
    end
end

function Batch:summary()
    local results = self.results
    local parts = {}
    if results.rebound > 0 then
        local books = results.rebound == 1 and _("1 book") or string.format(_("%d books"), results.rebound)
        if results.sorted == results.rebound then
            parts[#parts + 1] = string.format(_("✓ %s rebound and sorted into your library."), books)
        elseif results.sorted > 0 then
            parts[#parts + 1] = string.format(_("✓ %s rebound, %d sorted into your library."), books, results.sorted)
        else
            parts[#parts + 1] = string.format(_("✓ %s rebound."), books)
        end
    end
    if results.failed == 1 then
        parts[#parts + 1] = _("1 could not be written.")
    elseif results.failed > 1 then
        parts[#parts + 1] = string.format(_("%d could not be written."), results.failed)
    end
    if results.not_moved == 1 then
        parts[#parts + 1] = _("1 was rebound but not moved.")
    elseif results.not_moved > 1 then
        parts[#parts + 1] = string.format(_("%d were rebound but not moved."), results.not_moved)
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, " ")
end

function Batch:done_location(entry)
    local library = (entry.save_as or self.save_as).library
    local path = entry.new_path
    if entry.sorted and library then
        local prefix = Batch.trim_folder(library) .. "/"
        if path:sub(1, #prefix) == prefix then
            return path:sub(#prefix + 1)
        end
    end
    return Organize.basename(path)
end

function Batch:take_changed()
    local files = self.changed
    self.changed = {}
    return files
end

return Batch
