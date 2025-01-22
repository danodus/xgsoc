-- game.lua

require "asm"
require "mon"
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


START_A = 0
WIDTH_A = 53
HEIGHT_A = 30

START_B = START_A + (WIDTH_A * HEIGHT_A)
WIDTH_B = 424
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

draw_background = asm_function([[
  lui   t0,0x20003
  addi  t1,zero,1
  sw    zero,128(t0)
  sw    t1,384(t0)
  sw    zero,144(t0)
  sw    zero,400(t0)
  addi  t2,zero,{WIDTH_A * HEIGHT_A}
  sw    zero,160(t0)
  sw    zero,416(t0)
  addi  t2,t2,-1
  bne   t2,zero,-12
  jalr  zero,0(ra)
]])

function _draw_background()
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
  until (v & 0x4000) == 0x0000
end

function wait_blit_done()
  local v
  repeat
    v = xgetw(XM_SYS_CTRL)
  until (v & 0x2000) == 0x0000
end

function init_draw_ball()
  xreg_setw(XR_BLIT_MOD_S, 0x0000)
  xreg_setw(XR_BLIT_MOD_D, WIDTH_B / 4 - 4)
  xreg_setw(XR_BLIT_SHIFT, 0xFF00)
  xreg_setw(XR_BLIT_LINES, 15)
end

function wait_vsync()
  local vs
  repeat
    vs = peek(0x10900000)
  until last_vsync ~= vs
  last_vsync = vs
end

draw_ball_bin = asm_str([[
  lui   t0,0x20003
  andi  a0,a0,0x3
  jalr  zero,0(ra)
]])


function draw_ball(x, y, visible)
  local shift = x & 0x3
  if visible then
    xreg_setw(XR_BLIT_SRC_S, START_BOBS)
    xreg_setw(XR_BLIT_CTRL, 0x0010)
  else
    xreg_setw(XR_BLIT_SRC_S, 0x0000)
    xreg_setw(XR_BLIT_CTRL, 0x0001)
  end
  xreg_setw(XR_BLIT_MOD_S, shift > 0 and 0xFFFF or 0x0000)
  xreg_setw(XR_BLIT_MOD_D, WIDTH_B / 4 - 4 - (shift > 0 and 1 or 0))
  xreg_setw(XR_BLIT_DST_D, START_B + y * WIDTH_B / 4 + (x >> 2))
  local mask_shift = {0xFF00, 0x7801, 0x3C02, 0x1E03}
  xreg_setw(XR_BLIT_SHIFT, mask_shift[shift + 1])
  wait_blit_ready()
  xreg_setw(XR_BLIT_WORDS, 3 + (shift > 0 and 1 or 0))
end

db2_t0 = (WIDTH_B >> 2) - 4
db2_mask_shift = {0xFF00, 0x7801, 0x3C02, 0x1E03}

function draw_ball2(x, y, visible)
  local shift = x & 0x3
  if visible then
    xreg_setw(XR_BLIT_SRC_S, START_BOBS)
    xreg_setw(XR_BLIT_CTRL, 0x0010)
  else
    xreg_setw(XR_BLIT_SRC_S, 0x0000)
    xreg_setw(XR_BLIT_CTRL, 0x0001)
  end
    xreg_setw(XR_BLIT_MOD_S, shift > 0 and 0xFFFF or 0x0000)
    xreg_setw(XR_BLIT_MOD_D, db2_t0 - (shift > 0 and 1 or 0))
    xreg_setw(XR_BLIT_DST_D, START_B + y * (WIDTH_B >> 2) + (x >> 2))
    xreg_setw(XR_BLIT_SHIFT, db2_mask_shift[shift + 1])
    wait_blit_ready()
    xreg_setw(XR_BLIT_WORDS, 3 + (shift > 0 and 1 or 0))
end


vsync = asm_function([[
  addi  sp,sp,-8
  sw    t1,4(sp)
  sw    t0,0(sp)
  lui   t0,0x10900
  lw    t1,0(t0)
  addi  t1,t1,1
  sw    t1,0(t0)
  lui   t0,0x20003
  addi  t0,t0,0x100
  addi  t1,zero,0x10
  sw    t1,16(t0)
  lw    t0,0(sp)
  lw    t1,4(sp)
  addi  sp,sp,8
  jalr  zero,0(ra)
]])

poke(0x100000ec, vsync.bin:getptr())
last_vsync = peek(0x10900000)
xsetw(XM_INT_CTRL, 0x1010)

-- playfield A

xreg_setw(XR_PA_DISP_ADDR, START_A)
xreg_setw(XR_PA_LINE_LEN, WIDTH_A)

-- set to tiled 4-bpp, Hx2, Vx2
xreg_setw(XR_PA_GFX_CTRL, 0x0015)

-- tile height to 8
xreg_setw(XR_PA_TILE_CTRL, 0x0007)

-- set tiles
XR_TILE_ADDR=0x4000
xsetw(XM_WR_XADDR, XR_TILE_ADDR)
for _,v in ipairs(tile_mem) do
  xsetw(XM_XDATA, v)
end

init_bobs()

draw_background()

-- playfield B
xreg_setw(XR_PB_DISP_ADDR, START_B)
xreg_setw(XR_PB_LINE_LEN, WIDTH_B / 4)

-- set to bitmap 4-bpp, Hx2, Vx2
xreg_setw(XR_PB_GFX_CTRL, 0x0055)

-- clear playfield B

xreg_setw(XR_BLIT_CTRL, 0x0001)
xreg_setw(XR_BLIT_SRC_S, 0x0000)
xreg_setw(XR_BLIT_MOD_D, 0x0000)
xreg_setw(XR_BLIT_DST_D, START_B)
xreg_setw(XR_BLIT_SHIFT, 0xFF00)
xreg_setw(XR_BLIT_LINES, HEIGHT_B - 1)
xreg_setw(XR_BLIT_WORDS, WIDTH_B / 4 - 1)
wait_blit_done()

init_draw_ball()

t0 = os.clock()
draw_ball2(0, 0, false)
t1 = os.clock()

x=32
y=32
gp=0
repeat
  wait_vsync()
  draw_ball2(x, y, true)
  gp = read_gamepad()
  if gp ~= 0 then
    wait_vsync()
    draw_ball2(x, y, false)
    if gp & BUTTON_LEFT_MASK ~= 0 then
      if x > 0 then
        x = x - 1
      end
    end
    if gp & BUTTON_RIGHT_MASK ~= 0 then
      if x < WIDTH_B - 16 then
        x = x + 1
      end
    end
    if gp & BUTTON_UP_MASK ~= 0 then
      if y > 0 then
        y = y - 1
      end
    end
    if gp & BUTTON_DOWN_MASK ~= 0 then
      if y < HEIGHT_B - 16 then
        y = y + 1
      end
    end
  end
until gp & BUTTON_SELECT_MASK ~= 0


-- back to normal
xreg_setw(XR_PA_DISP_ADDR, 0x0000)
xreg_setw(XR_PA_GFX_CTRL, 0x0000)
xreg_setw(XR_PB_GFX_CTRL, 0x0080)

-- Disable vsync interrupt
xsetw(XM_INT_CTRL, 0x0000)
poke(0x100000ec, 0x0000)

print("Time:", t1-t0, (t1-t0)/100000)

print("Done!")
