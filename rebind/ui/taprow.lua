local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")

local TapRow = InputContainer:extend{
    on_tap = nil,
}

function TapRow:init()
    self.ges_events = {
        Tap = {
            GestureRange:new{
                ges = "tap",
                range = function()
                    return self.dimen
                end,
            },
        },
    }
end

function TapRow:onTap()
    if self.on_tap then
        self.on_tap()
        return true
    end
end

return TapRow
