local _ = require("gettext")

local PickerState = {}
PickerState.__index = PickerState

function PickerState.new(fields)
    local self = setmetatable({ fields = fields, chosen = {}, extra = {} }, PickerState)
    self:_open_selection()
    self.opened = { chosen = {} }
    for key, choice in pairs(self.chosen) do
        self.opened.chosen[key] = choice
    end
    return self
end

function PickerState:_open_selection()
    for _, f in ipairs(self.fields) do
        if self.extra[f.key] == nil then
            if self:_differs(f) then
                self.chosen[f.key] = "new"
            else
                self.chosen[f.key] = "current"
            end
        end
    end
end

function PickerState:_differs(field)
    if field.is_empty(field.new_value) then
        return false
    end
    if field.same then
        return not field.same(field.new_value, field.current_value)
    end
    return field.display(field.new_value) ~= field.display(field.current_value)
end

function PickerState:manual()
    for _i, f in ipairs(self.fields) do
        if not f.is_empty(f.new_value) then
            return false
        end
    end
    return true
end

function PickerState:has_bulk()
    return not self:manual()
end

function PickerState:_listed(field)
    return self:manual() or self:_differs(field) or self.extra[field.key] ~= nil
end

function PickerState:differing_fields()
    local out = {}
    for _i, f in ipairs(self.fields) do
        if self:_listed(f) then
            out[#out + 1] = f
        end
    end
    return out
end

function PickerState:differing_keys()
    local keys = {}
    for _i, f in ipairs(self:differing_fields()) do
        keys[#keys + 1] = f.key
    end
    return keys
end

function PickerState:matching_fields()
    local out = {}
    for _i, f in ipairs(self.fields) do
        if not self:_listed(f) then
            out[#out + 1] = f
        end
    end
    return out
end

function PickerState:differ_heading()
    local n = #self:differing_fields()
    if self:manual() then
        return string.format(_("%d FIELDS"), n)
    end
    if n == 0 then
        return _("NO FIELDS DIFFER")
    elseif n == 1 then
        return _("1 FIELD DIFFERS")
    end
    return string.format(_("%d FIELDS DIFFER"), n)
end

function PickerState:matching_summary()
    local labels = {}
    for _i, f in ipairs(self:matching_fields()) do
        labels[#labels + 1] = f.label
    end
    local n = #labels
    local head = n == 1 and _("1 field already matches") or string.format(_("%d fields already match"), n)
    return head .. " · " .. table.concat(labels, ", ")
end

local SOURCE_ORDER = {
    { choice = "new", label = _("Hardcover values") },
    { choice = "current", label = _("Book values") },
    { choice = "custom", label = _("Custom values") },
    { choice = "translated", label = _("Translated values") },
    { choice = "removed", label = _("Removed") },
}

function PickerState:_source(field)
    local choice = self.chosen[field.key]
    local extra = self.extra[field.key]
    if choice == "custom" and extra and field.is_empty(extra.raw) then
        return "removed"
    end
    return choice
end

function PickerState:status_line()
    local counts = {}
    for _i, f in ipairs(self:differing_fields()) do
        local choice = self:_source(f)
        if not (self:manual() and choice == "current") then
            counts[choice] = (counts[choice] or 0) + 1
        end
    end
    local parts = {}
    for _i, source in ipairs(SOURCE_ORDER) do
        if counts[source.choice] then
            parts[#parts + 1] = source.label .. ": " .. counts[source.choice]
        end
    end
    return table.concat(parts, " · ")
end

function PickerState:_any_on_book(fields)
    for _i, f in ipairs(fields) do
        if self.chosen[f.key] == "current" then
            return true
        end
    end
    return false
end

function PickerState:bulk_label()
    local fields = self:differing_fields()
    if self:_any_on_book(fields) then
        return string.format(_("Use Hardcover values for all %d"), #fields)
    end
    return string.format(_("Use book values for all %d"), #fields)
end

function PickerState:bulk()
    local fields = self:differing_fields()
    local to_book = not self:_any_on_book(fields)
    for _i, f in ipairs(fields) do
        if to_book or f.is_empty(f.new_value) then
            self.chosen[f.key] = "current"
        else
            self.chosen[f.key] = "new"
        end
    end
end

function PickerState:values(key)
    local field = self:_field(key)
    local out = {}
    local function add(id, tag, raw)
        if id == "custom" and field.is_empty(raw) then
            tag = "removed"
        end
        out[#out + 1] = {
            id = id,
            tag = tag,
            text = field.display(raw),
            empty = field.is_empty(raw),
            selected = self.chosen[key] == id,
        }
    end
    add("current", "book", field.current_value)
    if self:_differs(field) then
        add("new", "Hardcover", field.new_value)
    end
    local extra = self.extra[key]
    if extra then
        add(extra.kind, extra.kind, extra.raw)
    end
    return out
end

function PickerState:_field(key)
    for _i, f in ipairs(self.fields) do
        if f.key == key then
            return f
        end
    end
end

function PickerState:selection(key)
    return self.chosen[key]
end

function PickerState:set_fields(fields)
    self.fields = fields
    self:_open_selection()
end

function PickerState:select(key, choice)
    self.chosen[key] = choice
end

function PickerState:_save(key, kind, raw)
    self.extra[key] = { kind = kind, raw = raw }
    self.chosen[key] = kind
end

function PickerState:save_custom(key, raw)
    self:_save(key, "custom", raw)
end

function PickerState:save_translated(key, raw)
    self:_save(key, "translated", raw)
end

function PickerState:selected_value(field)
    local sel = self.chosen[field.key]
    if sel == "custom" or sel == "translated" then
        return self.extra[field.key].raw
    elseif sel == "new" then
        return field.new_value
    end
    return field.current_value
end

local function same_written(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    for k, v in pairs(a) do
        if not same_written(v, b[k]) then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

function PickerState:_changed_fields()
    local out = {}
    for _i, f in ipairs(self.fields) do
        local wanted, kept = {}, {}
        f.apply(wanted, self:selected_value(f))
        f.apply(kept, f.current_value)
        if not same_written(wanted, kept) then
            out[#out + 1] = f
        end
    end
    return out
end

function PickerState:changes()
    local changes = {}
    for _i, f in ipairs(self:_changed_fields()) do
        f.apply(changes, self:selected_value(f))
    end
    return changes
end

function PickerState:apply_label()
    local n = #self:_changed_fields()
    if n == 1 then
        return _("Apply 1 change")
    end
    return string.format(_("Apply %d changes"), n)
end

function PickerState:needs_discard_prompt()
    for _i, f in ipairs(self.fields) do
        if self.chosen[f.key] ~= self.opened.chosen[f.key] or self.extra[f.key] ~= nil then
            return true
        end
    end
    return false
end

return PickerState
