local Archiver = { Reader = {}, Writer = {} }
Archiver.Reader.__index = Archiver.Reader
Archiver.Writer.__index = Archiver.Writer

function Archiver.Reader:new()
    return setmetatable({ _seen = {} }, Archiver.Reader)
end

function Archiver.Reader:open(path)
    self._fs = _G.__TEST_FS
    self._order = _G.__TEST_ORDER
    self._seen = {}
    return self._fs ~= nil
end

function Archiver.Reader:extractToMemory(key)
    if not (self._fs and self._seen[key]) then
        return nil
    end
    return self._fs[key]
end

function Archiver.Reader:iterate()
    local i = 0
    local order = self._order or {}
    return function()
        i = i + 1
        local p = order[i]
        if p then
            self._seen[p] = true
            return { path = p }
        end
    end
end

function Archiver.Reader:close() end

function Archiver.Writer:new()
    return setmetatable({ entries = {} }, Archiver.Writer)
end

function Archiver.Writer:open(path)
    self.path = path
    return true
end

function Archiver.Writer:setZipCompression(method)
    self.comp = method
end

function Archiver.Writer:addFileFromMemory(entry_path, content)
    self.entries[#self.entries + 1] = { path = entry_path, content = content, comp = self.comp }
end

function Archiver.Writer:close()
    _G.__TEST_WRITES = self.entries
end

return Archiver
