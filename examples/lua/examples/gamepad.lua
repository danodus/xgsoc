-- gamepad.lua

BUTTON_A_MASK = 0x1
BUTTON_B_MASK = 0x2
BUTTON_X_MASK = 0x4
BUTTON_Y_MASK = 0x8
BUTTON_UP_MASK = 0x10
BUTTON_DOWN_MASK = 0x20
BUTTON_LEFT_MASK = 0x40
BUTTON_RIGHT_MASK = 0x80
BUTTON_SHOULDER_LEFT_MASK = 0x100
BUTTON_SHOULDER_RIGHT_MASK = 0x200
BUTTON_SELECT_MASK = 0x400
BUTTON_START_MASK = 0x800

local USB_STATUS = 0x20004000
local USB_REPORT_MSW = 0x20004004
local USB_REPORT_LSW = 0x20004008

function read_gamepad()
        local r = {peek(USB_REPORT_LSW), peek(USB_REPORT_MSW)}
        return get_buttons_kiwidata(r)
end

function get_buttons_kiwidata(r)
        local ret = 0
--      print(string.format("%x %x", r[2], r[1]))
        if r[2] & 0x00002000 ~= 0x00000000 then
                ret = ret | BUTTON_A_MASK
        end
        if r[2] & 0x00004000 ~= 0x00000000 then
                ret = ret | BUTTON_B_MASK
        end
        if r[2] & 0x00001000 ~= 0x00000000 then
                ret = ret | BUTTON_X_MASK
        end
        if r[2] & 0x00008000 ~= 0x00000000 then
                ret = ret | BUTTON_Y_MASK
        end
        if r[2] & 0x000000FF == 0x00000000 then
                ret = ret | BUTTON_UP_MASK
        end
        if r[2] & 0x000000FF == 0x000000FF then
                ret = ret | BUTTON_DOWN_MASK
        end
        if r[1] & 0xFF000000 == 0x00000000 then
                ret = ret | BUTTON_LEFT_MASK
        end
        if r[1] & 0xFF000000 == 0xFF000000 then
                ret = ret | BUTTON_RIGHT_MASK
        end
        if r[2] & 0x00010000 ~= 0x00000000 then
                ret = ret | BUTTON_SHOULDER_LEFT_MASK
        end
        if r[2] & 0x00020000 ~= 0x00000000 then
                ret = ret | BUTTON_SHOULDER_RIGHT_MASK
        end
        if r[2] & 0x00100000 ~= 0x00000000 then
                ret = ret | BUTTON_SELECT_MASK
        end
        if r[2] & 0x00200000 ~= 0x00000000 then
                ret = ret | BUTTON_START_MASK
        end
        return ret
end
