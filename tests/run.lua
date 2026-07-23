package.path = table.concat({
    "tests/support/stubs/?.lua",
    "./?.lua",
    "./?/init.lua",
    package.path,
}, ";")

local assertions = require("tests/support/assert")

local specs = {
    "tests/epub_spec",
    "tests/fields_spec",
    "tests/hardcover_spec",
    "tests/organize_spec",
}

local total, failed = 0, 0

for _, spec_name in ipairs(specs) do
    local suite = require(spec_name)
    print("== " .. spec_name .. " ==")
    local names = {}
    for name in pairs(suite) do
        names[#names + 1] = name
    end
    table.sort(names)
    for _, name in ipairs(names) do
        total = total + 1
        local ok, err = pcall(suite[name], assertions)
        if ok then
            print("  ok   " .. name)
        else
            failed = failed + 1
            print("  FAIL " .. name)
            print("         " .. tostring(err))
        end
    end
end

print(string.format("\n%d run, %d failed", total, failed))
os.exit(failed == 0 and 0 or 1)
