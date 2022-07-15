require "xosera"
require "gamepad"

DBG_LINE = 161
function hook(event, line)
        if (event == "line" and line == DBG_LINE) then
                if x == 5 and y == 5 then
                        error("Break!")
                end
        end
end

debug.sethook()
--debug.sethook(hook, "l")


START_A = 40 * 30
WIDTH_A = 40
HEIGHT_A = 30

START_B = START_A + (WIDTH_A * HEIGHT_A)
WIDTH_B = 320
HEIGHT_B = 240

START_BOBS = START_B + (WIDTH_B * HEIGHT_B / 4)

tile_mem = {
-- 0
        0x8888, 0x8888,
        0x8000, 0x0008,
        0x8000, 0x0008,
        0x8000, 0x0008,
        0x8000, 0x0008,
        0x8000, 0x0008,
        0x8000, 0x0008,
        0x8888, 0x8888
}

ball_bob = {
-- 0
        0x000f, 0xffff, 0xffff, 0xf000,
        0x0ff1, 0x1111, 0x1111, 0x1ff0,
        0xf111, 0xf111, 0x1111, 0x111f,
        0xf11f, 0x1111, 0x1111, 0x111f,
        0xf111, 0x1111, 0x1111, 0x111f,
        0xf111, 0x1111, 0x1111, 0x111f,
        0xf111, 0x1111, 0x1111, 0x111f,
        0xf111, 0x1111, 0x1111, 0x111f,
-- 1
        0xf111, 0x1111, 0x1111, 0x111f,
        0xf111, 0x1111, 0x1111, 0x111f,
        0xf111, 0x1111, 0x1111, 0x111f,
        0xf111, 0x1111, 0x1111, 0x111f,
        0xf111, 0x1111, 0x1111, 0x111f,
        0xf111, 0x1111, 0x1111, 0x111f,
        0x0ff1, 0x1111, 0x1111, 0x1ff0,
        0x000f, 0xffff, 0xffff, 0xf000
}

function draw_background()
        xsetw(XM_WR_INCR, 0x0001)
        xsetw(XM_WR_ADDR, START_A)
        for y=1,HEIGHT_A do
                for x=1,WIDTH_A do
                        xsetw(XM_DATA, 0x0000)
                end
        end
end

function init_bobs()
        xsetw(XM_WR_INCR, 0x0001)
        xsetw(XM_WR_ADDR, START_BOBS)
        for _,v in ipairs(ball_bob) do
                xsetw(XM_DATA, v)
        end
end

function wait_blit_ready()
        local v
        repeat
                v = xgetw(XM_SYS_CTRL)
        until (v & 0x0020) == 0x0000
end

function wait_blit_done()
        local v
        repeat
                v = xgetw(XM_SYS_CTRL)
        until (v & 0x0040) == 0x0000
end

function init_draw_ball()
        xreg_setw(XR_BLIT_MOD_A, 0x0000)
        xreg_setw(XR_BLIT_SRC_A, START_BOBS)
        xreg_setw(XR_BLIT_SRC_B, 0xFFFF)
        xreg_setw(XR_BLIT_VAL_C, 0x0000)
        xreg_setw(XR_BLIT_MOD_D, WIDTH_B / 4 - 4)
        xreg_setw(XR_BLIT_SHIFT, 0xFF00)
        xreg_setw(XR_BLIT_LINES, 15)
end

function wait_vsync()
        local v
        repeat
                v = xreg_getw(XR_SCANLINE)
        until (v & 0x8000) == 0x0000
        repeat
                v = xreg_getw(XR_SCANLINE)
        until (v & 0x8000) == 0x8000
end

function draw_ball(x, y, visible)
        xreg_setw(XR_BLIT_CTRL, 0x0002 | (visible and 0x0000 or 0x0004))
        --xreg_setw(XR_BLIT_MOD_A, 0x0000)
        --xreg_setw(XR_BLIT_SRC_A, START_BOBS)
        --xreg_setw(XR_BLIT_SRC_B, 0xFFFF)
        --xreg_setw(XR_BLIT_VAL_C, 0x0000)
        --xreg_setw(XR_BLIT_MOD_D, WIDTH_B / 4 - 4)
        xreg_setw(XR_BLIT_DST_D, START_B + y * WIDTH_B / 4 + x)
        --xreg_setw(XR_BLIT_SHIFT, 0xFF00)
        --xreg_setw(XR_BLIT_LINES, 15)
        wait_blit_ready()
        xreg_setw(XR_BLIT_WORDS, 3)
end

-- playfield A

xreg_setw(XR_PA_DISP_ADDR, START_A)
xreg_setw(XR_PA_LINE_LEN, WIDTH_A)

-- set to tiled 4-bpp, Hx2, Vx2
xreg_setw(XR_PA_GFX_CTRL, 0x0015)

-- tile height to 8
xreg_setw(XR_PA_TILE_CTRL, 0x0007)

-- set tiles
XR_TILE_ADDR=0xA000
xsetw(XM_XR_ADDR, XR_TILE_ADDR)
for _,v in ipairs(tile_mem) do
        xsetw(XM_XR_DATA, v)
end

init_bobs()

draw_background()

-- playfield B
xreg_setw(XR_PB_DISP_ADDR, START_B)
xreg_setw(XR_PB_LINE_LEN, WIDTH_B / 4)

-- set to bitmap 4-bpp, Hx2, Vx2
xreg_setw(XR_PB_GFX_CTRL, 0x0055)

-- clear playfield B

xreg_setw(XR_BLIT_CTRL, 0x0003)
xreg_setw(XR_BLIT_SRC_A, 0x0000)
xreg_setw(XR_BLIT_SRC_B, 0xFFFF)
xreg_setw(XR_BLIT_VAL_C, 0x0000)
xreg_setw(XR_BLIT_MOD_D, 0x0000)
xreg_setw(XR_BLIT_DST_D, START_B)
xreg_setw(XR_BLIT_SHIFT, 0xFF00)
xreg_setw(XR_BLIT_LINES, HEIGHT_B - 1)
xreg_setw(XR_BLIT_WORDS, WIDTH_B / 4 - 1)
wait_blit_done()

init_draw_ball()
x=0
y=0
gp=0
repeat
        draw_ball(x >> 2, y, true)
        gp = read_gamepad()
        if gp ~= 0 then
                draw_ball(x >> 2, y, false)
                if gp & BUTTON_LEFT_MASK ~= 0 then
                        if x > 1 then
                                x = x - 1
                        end
                end
                if gp & BUTTON_RIGHT_MASK ~= 0 then
                        if x < WIDTH_B - 16 - 1 then
                                x = x + 1
                        end
                end
                if gp & BUTTON_UP_MASK ~= 0 then
                        if y > 1 then
                                y = y - 1
                        end
                end
                if gp & BUTTON_DOWN_MASK ~= 0 then
                        if y < HEIGHT_B - 16 - 1 then
                                y = y + 1
                        end
                end
        end
until gp & BUTTON_SELECT_MASK ~= 0

-- back to normal
xreg_setw(XR_PA_DISP_ADDR, 0x0000)
xreg_setw(XR_PA_GFX_CTRL, 0x0000)
xreg_setw(XR_PB_GFX_CTRL, 0x0080)
print("Done!")
