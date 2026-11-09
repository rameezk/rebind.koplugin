local spool = os.getenv("REBIND_HARNESS_SPOOL")
if not spool or spool == "" then
    return { disabled = true }
end

local Device = require("device")
local Event = require("ui/event")
local Geom = require("ui/geometry")
local Key = require("device/key")
local time = require("ui/time")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local POLL_SECONDS = 0.1
local SETTLE_SECONDS = 0.05
local SETTLE_TICKS = 3
local SETTLE_TIMEOUT_SECONDS = 15
local READY_TIMEOUT_SECONDS = 60

local MAX_DEPTH = 60
local SKIPPED_FIELDS = {
    parent = true,
    show_parent = true,
    ui = true,
    menu = true,
    _parent = true,
    document = true,
    view = true,
}

local started = false

local function readFile(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local content = f:read("*a")
    f:close()
    return content
end

local function writeAtomic(path, content)
    local tmp = path .. ".tmp"
    local f = assert(io.open(tmp, "w"))
    f:write(content)
    f:close()
    assert(os.rename(tmp, path))
end

local function respond(id, ok, message)
    local content = (ok and "ok" or "error") .. "\n" .. (message or "") .. "\n"
    local written, err = pcall(writeAtomic, spool .. "/" .. id .. ".res", content)
    if not written then
        logger.err("rebind harness: could not answer", id, err)
    end
end

local function isQuiet()
    return next(UIManager._dirty) == nil
        and #UIManager._refresh_stack == 0
        and #UIManager._refresh_func_stack == 0
end

local function fileBrowserIsOnTop()
    local FileManager = require("apps/filemanager/filemanager")
    local top = UIManager._window_stack[#UIManager._window_stack]
    return FileManager.instance ~= nil and top ~= nil and top.widget == FileManager.instance
end

local function whenSettled(callback, extra_condition, timeout)
    local quiet_ticks = 0
    local waited = 0
    local function check()
        if isQuiet() and (not extra_condition or extra_condition()) then
            quiet_ticks = quiet_ticks + 1
        else
            quiet_ticks = 0
        end
        waited = waited + SETTLE_SECONDS
        if quiet_ticks >= SETTLE_TICKS then
            callback(true)
        elseif waited >= (timeout or SETTLE_TIMEOUT_SECONDS) then
            callback(false)
        else
            UIManager:scheduleIn(SETTLE_SECONDS, check)
        end
    end
    UIManager:scheduleIn(SETTLE_SECONDS, check)
end

local function isWidget(value)
    return type(value) == "table" and type(value.paintTo) == "function"
end

local function normalizeLabel(text)
    local stripped = text
        :gsub("\226\128[\139-\143\168-\174]", "")
        :gsub("\226\129[\160-\169]", "")
        :gsub("\194[\128-\159]", "")
        :gsub("\216\156", "")
        :gsub("\239\187\191", "")
    return (stripped:gsub("%c", " "):gsub("%s+", " "):match("^ ?(.-) ?$"))
end

local function isPassword(widget)
    return widget.charlist ~= nil and widget.text_type == "password"
end

local function labelOf(widget)
    local label = ""
    local is_icon = false
    if type(widget.getText) == "function" and widget.charlist then
        if isPassword(widget) then
            label = "<hidden>"
        else
            label = widget:getText()
        end
        if label == "" and type(widget.hint) == "string" then
            label = widget.hint
        end
    else
        for _, field in ipairs({ "text", "icon" }) do
            local value = widget[field]
            if type(value) == "string" and value ~= "" then
                label = value
                is_icon = field == "icon"
                break
            end
        end
    end
    return normalizeLabel(label), is_icon
end

local function visibleRect(widget)
    local dimen = widget.dimen
    if type(dimen) ~= "table" or not dimen.x or not dimen.y or not dimen.w or not dimen.h then
        return nil
    end
    if dimen.w <= 0 or dimen.h <= 0 then
        return nil
    end
    local screen = Device.screen
    if dimen.x >= screen:getWidth() or dimen.y >= screen:getHeight()
        or dimen.x + dimen.w <= 0 or dimen.y + dimen.h <= 0 then
        return nil
    end
    return { x = dimen.x, y = dimen.y, w = dimen.w, h = dimen.h }
end

local function center(rect)
    return rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2)
end

local function eachChild(widget, visit)
    for key, value in pairs(widget) do
        if not SKIPPED_FIELDS[key] and isWidget(value) then
            visit(value)
        end
    end
end

local function collect(widget, entries, visited, parent_label, parent_rect, depth)
    if visited[widget] or depth > MAX_DEPTH then
        return
    end
    visited[widget] = true
    local label, is_icon = labelOf(widget)
    local own_rect = visibleRect(widget)
    local rect = own_rect or parent_rect
    if own_rect and own_rect.x == 0 and own_rect.y == 0 and parent_rect
        and (parent_rect.x ~= 0 or parent_rect.y ~= 0) then
        rect = parent_rect
    end
    local next_parent_label = parent_label
    local unpainted = rect and rect.x == 0 and rect.y == 0 and not is_icon
    if label ~= "" and rect and not unpainted and label ~= parent_label then
        table.insert(entries, { label = label, x = rect.x, y = rect.y, w = rect.w, h = rect.h })
        next_parent_label = label
    end
    if isPassword(widget) then
        return
    end
    eachChild(widget, function(child)
        collect(child, entries, visited, next_parent_label, own_rect or parent_rect, depth + 1)
    end)
end

local function footprint(widget)
    local screen = Device.screen
    local current = widget
    for _ = 1, MAX_DEPTH do
        local rect = visibleRect(current)
        if rect and (rect.w < screen:getWidth() or rect.h < screen:getHeight()) then
            return rect
        end
        current = current[1]
        if not isWidget(current) then
            return nil
        end
    end
    return nil
end

local function contains(rect, x, y)
    return x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h
end

local function eachInteractiveWindow(visit)
    local stack = UIManager._window_stack
    for i = #stack, 1, -1 do
        local widget = stack[i].widget
        if widget then
            if visit(widget) then
                return
            end
            if widget.modal or widget.covers_fullscreen then
                return
            end
        end
    end
end

local function visibleWidgets()
    local entries = {}
    local visited = {}
    local covers = {}
    eachInteractiveWindow(function(widget)
        local window_entries = {}
        collect(widget, window_entries, visited, nil, nil, 0)
        for _, entry in ipairs(window_entries) do
            local cx, cy = center(entry)
            local hidden = false
            for _, cover in ipairs(covers) do
                hidden = hidden or contains(cover, cx, cy)
            end
            if not hidden then
                table.insert(entries, entry)
            end
        end
        table.insert(covers, footprint(widget))
    end)
    return entries
end

local function findFocusedInput(widget, visited, depth)
    if visited[widget] or depth > MAX_DEPTH then
        return nil
    end
    visited[widget] = true
    if widget.charlist and widget.focused then
        return widget
    end
    local found
    eachChild(widget, function(child)
        found = found or findFocusedInput(child, visited, depth + 1)
    end)
    return found
end

local function focusedInput()
    local found
    local visited = {}
    eachInteractiveWindow(function(widget)
        found = findFocusedInput(widget, visited, 0)
        return found ~= nil
    end)
    return found
end

local function afterSettling(done, message)
    whenSettled(function(settled)
        if not settled then
            return done(false, "the screen did not settle")
        end
        done(true, message)
    end)
end

local function tapAt(x, y)
    UIManager:sendEvent(Event:new("Gesture", {
        ges = "tap",
        pos = Geom:new{ x = x, y = y, w = 0, h = 0 },
        time = time.now(),
    }))
end

local commands = {}

function commands.dump(_id, _args, done)
    whenSettled(function(settled)
        if not settled then
            return done(false, "the screen did not settle")
        end
        local lines = {}
        for _, rect in ipairs(visibleWidgets()) do
            table.insert(lines, string.format('"%s" x=%d y=%d w=%d h=%d', rect.label, rect.x, rect.y, rect.w, rect.h))
        end
        done(true, table.concat(lines, "\n"))
    end)
end

function commands.tap(_id, args, done)
    local x, y, described
    if #args == 2 then
        x, y = tonumber(args[1]), tonumber(args[2])
        if not x or not y then
            return done(false, "tap needs two numbers or one label")
        end
        described = string.format("(%d, %d)", x, y)
    elseif #args == 1 then
        local label = normalizeLabel(args[1])
        local matches = {}
        for _, rect in ipairs(visibleWidgets()) do
            if rect.label == label then
                table.insert(matches, rect)
            end
        end
        if #matches == 0 then
            return done(false, string.format('no widget on screen is labelled "%s"', label))
        elseif #matches > 1 then
            return done(false, string.format('%d widgets on screen are labelled "%s"; tap by coordinates instead', #matches, label))
        end
        x, y = center(matches[1])
        described = string.format('"%s" at (%d, %d)', label, x, y)
    else
        return done(false, "tap needs two numbers or one label")
    end
    tapAt(x, y)
    afterSettling(done, "tapped " .. described)
end

function commands.type(_id, args, done)
    if #args ~= 1 then
        return done(false, "type needs one text argument")
    end
    local input = focusedInput()
    if not input then
        return done(false, "no text field is focused")
    end
    input:addChars(args[1])
    afterSettling(done, "typed into the focused text field")
end

function commands.key(_id, args, done)
    if #args ~= 1 or args[1] == "" then
        return done(false, "key needs one key name")
    end
    UIManager:sendEvent(Event:new("KeyPress", Key:new(args[1], {})))
    afterSettling(done, "pressed " .. normalizeLabel(args[1]))
end

function commands.screenshot(id, _args, done)
    whenSettled(function(settled)
        if not settled then
            return done(false, "the screen did not settle")
        end
        local ok, err = Device.screen:shot(spool .. "/" .. id .. ".png")
        if ok == false then
            return done(false, "could not save the screenshot: " .. tostring(err))
        end
        done(true)
    end)
end

function commands.quit(_id, _args, done)
    done(true)
    UIManager:scheduleIn(SETTLE_SECONDS, function()
        UIManager:quit()
    end)
end

local function parse(content)
    local lines = {}
    for line in content:gmatch("([^\n]*)\n") do
        table.insert(lines, line)
    end
    local name = table.remove(lines, 1)
    return name, lines
end

local busy = false

local function nextRequestId()
    local ids = {}
    for entry in lfs.dir(spool) do
        local id = entry:match("^(.+)%.cmd$")
        if id then
            table.insert(ids, id)
        end
    end
    table.sort(ids)
    return ids[1]
end

local function handle(id)
    local path = spool .. "/" .. id .. ".cmd"
    local content = readFile(path)
    os.remove(path)
    if not content then
        return
    end
    local name, args = parse(content)
    local command = name and commands[name]
    if not command then
        return respond(id, false, "unknown command: " .. tostring(name))
    end
    busy = true
    local ok, err = pcall(command, id, args, function(success, message)
        busy = false
        respond(id, success, message)
    end)
    if not ok then
        busy = false
        logger.err("rebind harness: command failed", name, err)
        respond(id, false, tostring(err))
    end
end

local function poll()
    if not busy then
        local id = nextRequestId()
        if id then
            handle(id)
        end
    end
    UIManager:scheduleIn(POLL_SECONDS, poll)
end

local function start()
    if started then
        return
    end
    started = true
    whenSettled(function(settled)
        if not settled then
            logger.err("rebind harness: the file browser never settled")
            return
        end
        writeAtomic(spool .. "/ready", "ready\n")
        logger.info("rebind harness: ready")
    end, fileBrowserIsOnTop, READY_TIMEOUT_SECONDS)
    UIManager:scheduleIn(POLL_SECONDS, poll)
end

local Harness = WidgetContainer:extend{
    name = "rebindharness",
    is_doc_only = false,
}

function Harness:init()
    start()
end

return Harness
