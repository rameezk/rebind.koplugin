local Providers = require("rebind/providers")

local ProviderSettings = {}

function ProviderSettings.rows(stored, env)
    local enabled = Providers.enabled_ids(stored)
    local is_enabled = {}
    local order = {}
    for _i, id in ipairs(enabled) do
        is_enabled[id] = true
        order[#order + 1] = id
    end
    for _i, id in ipairs(Providers.KNOWN_IDS) do
        if not is_enabled[id] then
            order[#order + 1] = id
        end
    end

    local rows = {}
    for i, provider in ipairs(Providers.build(order, env)) do
        local ready, reason = provider:ready()
        rows[i] = {
            id = provider.id,
            name = provider.name,
            enabled = is_enabled[provider.id] == true,
            can_enable = ready,
            reason = reason,
        }
    end
    return rows
end

function ProviderSettings.set_enabled(stored, id, enabled, env)
    local ids = {}
    local present = false
    for _i, current in ipairs(Providers.enabled_ids(stored)) do
        if current == id then
            present = true
        end
        if current ~= id or enabled then
            ids[#ids + 1] = current
        end
    end
    if enabled and not present then
        for _i, row in ipairs(ProviderSettings.rows(stored, env)) do
            if row.id == id and row.can_enable then
                ids[#ids + 1] = id
            end
        end
    end
    return ids
end

function ProviderSettings.reorder(stored, ordered)
    local enabled = Providers.enabled_ids(stored)
    local is_enabled = {}
    for _i, id in ipairs(enabled) do
        is_enabled[id] = true
    end
    local ids, placed = {}, {}
    for _i, id in ipairs(ordered or {}) do
        if is_enabled[id] and not placed[id] then
            placed[id] = true
            ids[#ids + 1] = id
        end
    end
    for _i, id in ipairs(enabled) do
        if not placed[id] then
            ids[#ids + 1] = id
        end
    end
    return ids
end

return ProviderSettings
