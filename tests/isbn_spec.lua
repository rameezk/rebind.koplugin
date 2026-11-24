local Isbn = require("rebind/isbn")

local T = {}

T["an ISBN-13 with hyphens is normalised"] = function(a)
    a.eq(Isbn.to_13("978-1-4919-3936-9"), "9781491939369")
end

T["an ISBN-10 is converted to ISBN-13"] = function(a)
    a.eq(Isbn.to_13("0137314914"), "9780137314911")
    a.eq(Isbn.to_13("0-8044-2957-X"), "9780804429573")
end

T["a number with a wrong check digit is not an ISBN"] = function(a)
    a.eq(Isbn.to_13("9781491939360"), nil)
    a.eq(Isbn.to_13("0137314915"), nil)
end

T["text that is not a number is not an ISBN"] = function(a)
    a.eq(Isbn.to_13("hello"), nil)
    a.eq(Isbn.to_13(""), nil)
    a.eq(Isbn.to_13(nil), nil)
end

return T
