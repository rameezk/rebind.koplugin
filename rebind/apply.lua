local Epub = require("rebind/epub")
local Organize = require("rebind/organize")

local Apply = {}

function Apply.run(file, changes, opts)
    local rewrite = opts.rewrite or Epub.rewrite
    local relocate = opts.relocate or Organize.relocate
    local outcome = { ok = true, rewritten = false }

    if next(changes) then
        local ok, result = rewrite(file, changes, opts.keep_backup)
        if not ok then
            outcome.ok = false
            outcome.stage = "write"
            outcome.error = tostring(result)
            return outcome
        end
        outcome.rewritten = true
        outcome.backup = result
    end

    if opts.dest ~= file then
        local moved, result = relocate(file, opts.dest)
        if not moved then
            outcome.ok = false
            outcome.stage = "move"
            outcome.error = tostring(result)
            return outcome
        end
        outcome.moved_dest = result
    end
    return outcome
end

return Apply
