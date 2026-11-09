local spool = os.getenv("REBIND_HARNESS_SPOOL")
if not spool or spool == "" then
    return { disabled = true }
end

local Device = require("device")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local POLL_SECONDS = 0.1
local SETTLE_SECONDS = 0.05
local SETTLE_TICKS = 3
local SETTLE_TIMEOUT_SECONDS = 15
local READY_TIMEOUT_SECONDS = 60

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
    writeAtomic(spool .. "/" .. id .. ".res", (ok and "ok" or "error") .. "\n" .. (message or "") .. "\n")
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

local commands = {}

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
    whenSettled(function()
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
