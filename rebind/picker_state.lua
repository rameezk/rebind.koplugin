local PickerState = {}
PickerState.__index = PickerState

function PickerState.new(fields)
    local self = setmetatable({ fields = fields, chosen = {}, custom = {} }, PickerState)
    self:_open_selection()
    return self
end

function PickerState:_open_selection()
    for _, f in ipairs(self.fields) do
        if self.chosen[f.key] ~= "custom" then
            if not f.is_empty(f.new_value) and f.display(f.new_value) ~= f.display(f.current_value) then
                self.chosen[f.key] = "new"
            else
                self.chosen[f.key] = "current"
            end
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

function PickerState:select_all(choice)
    for _, f in ipairs(self.fields) do
        if choice == "new" and not f.is_empty(f.new_value) then
            self.chosen[f.key] = "new"
        else
            self.chosen[f.key] = "current"
        end
    end
end

function PickerState:save_custom(key, raw)
    self.custom[key] = raw
    self.chosen[key] = "custom"
end

function PickerState:custom_value(key)
    return self.custom[key]
end

function PickerState:selected_value(field)
    local sel = self.chosen[field.key]
    if sel == "custom" then
        return self.custom[field.key]
    elseif sel == "new" then
        return field.new_value
    end
    return field.current_value
end

function PickerState:changes()
    local changes = {}
    for _, f in ipairs(self.fields) do
        local value = self:selected_value(f)
        if f.display(value) ~= f.display(f.current_value) then
            f.apply(changes, value)
        end
    end
    return changes
end

return PickerState
