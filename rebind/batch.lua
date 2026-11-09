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
    walk(folder, "")
    table.sort(found, function(x, y)
        return Batch.natural_less(x.key, y.key)
    end)
    local files = {}
    for _i, item in ipairs(found) do
        files[#files + 1] = item.path
    end
    return files
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
        total = #(opts.files or {}),
        skips = {},
        skip_order = {},
        stopped = false,
        last_call = nil,
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

function Batch:_note_skips(found)
    for _i, skipped in ipairs(found.skipped or {}) do
        local name = skipped.provider.name
        local note = self.skips[name]
        if not note then
            note = { provider = name, count = 0, reason = skipped.reason }
            self.skips[name] = note
            self.skip_order[#self.skip_order + 1] = name
        end
        note.count = note.count + 1
    end
end

function Batch:skip_notices()
    local lines = {}
    for _i, name in ipairs(self.skip_order) do
        local note = self.skips[name]
        local text = note.count == 1 and _("%s was skipped for 1 book: %s.") or _("%s was skipped for %d books: %s.")
        if note.count == 1 then
            lines[#lines + 1] = string.format(text, name, note.reason)
        else
            lines[#lines + 1] = string.format(text, name, note.count, note.reason)
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

function Batch:_classify(entry)
    entry.state, entry.kind, entry.book, entry.matches = "review", nil, nil, nil
    local current, err = self.read_metadata(entry.file)
    if not current then
        entry.kind, entry.error = "failed", tostring(err)
        return
    end
    entry.current = current
    local found = Lookup.find(self.chain, current)
    self:_note_skips(found)
    if Lookup.all_failed(found) then
        entry.kind, entry.error = "failed", Lookup.skipped_text(found)
        return
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
    local ok, err = pcall(self._classify, self, entry)
    if not ok then
        entry.state, entry.kind, entry.error = "review", "failed", tostring(err)
    end
    self.last_call = self.clock()
end

function Batch:lookup_next()
    if self.stopped or #self.pending == 0 then
        return false
    end
    local file = table.remove(self.pending, 1)
    local entry = { file = file, name = Organize.basename(file) }
    self.entries[#self.entries + 1] = entry
    self:_run_lookup(entry)
    return true
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
    if entry.kind == "matches" then
        return string.format(_("%d matches"), #entry.matches)
    elseif entry.kind == "check" then
        return _("Check match")
    elseif entry.kind == "none" then
        return _("No match")
    end
    return _("Lookup failed")
end

function Batch:apply(entry, changes, opts)
    local outcome = Apply.run(entry.file, changes, {
        keep_backup = opts.keep_backup,
        dest = opts.dest,
        rewrite = self.rewrite,
        relocate = self.relocate,
    })
    if outcome.ok then
        local dest = outcome.moved_dest or entry.file
        entry.state = "done"
        entry.sorted = Organize.dirname(dest) ~= Organize.dirname(entry.file)
        entry.new_path = dest
    end
    if outcome.rewritten or outcome.moved_dest then
        self.changed[#self.changed + 1] = entry.file
    end
    return outcome
end

function Batch:take_changed()
    local files = self.changed
    self.changed = {}
    return files
end

return Batch
