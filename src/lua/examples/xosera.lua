-- xosera.lua

require "asm"

XOSERA_EVEN_BASE = 0x20003000
XOSERA_ODD_BASE = 0x20003100

XM_SYS_CTRL = 0x0
XM_INT_CTRL = 0x1
XM_TIMER = 0x2
XM_RD_XADDR = 0x3
XM_WR_XADDR = 0x4
XM_XDATA = 0x5
XM_RD_INCR = 0x6
XM_RD_ADDR = 0x7
XM_WR_INCR = 0x8
XM_WR_ADDR = 0x9
XM_DATA = 0xA
XM_DATA_2 = 0xB
XM_PIXEL_X = 0xC
XM_PIXEL_Y = 0xD
XM_UART = 0xE
XM_FEATURE = 0xF

XR_VID_CTRL = 0x00
XR_COPP_CTRL = 0x01
XR_AUD_CTRL = 0x02
XR_SCANLINE = 0x03
XR_VID_LEFT = 0x04
XR_VID_RIGHT = 0x05
XR_POINTER_H = 0x06
XR_POINTER_V = 0x07
XR_UNUSED_08 = 0x08
XR_UNUSED_09 = 0x09
XR_UNUSED_0A = 0x0A
XR_UNUSED_0B = 0x0B
XR_UNUSED_0C = 0x0C
XR_UNUSED_0D = 0x0D
XR_UNUSED_0E = 0x0E
XR_UNUSED_0F = 0x0F

XR_PA_GFX_CTRL = 0x10
XR_PA_TILE_CTRL = 0x11
XR_PA_DISP_ADDR = 0x12
XR_PA_LINE_LEN = 0x13
XR_PA_HV_FSCALE = 0x14
XR_PA_HV_SCROLL = 0x15
XR_PA_LINE_ADDR = 0x16
XR_PA_UNUSED_17 = 0x17

XR_PB_GFX_CTRL = 0x18
XR_PB_TILE_CTRL = 0x19
XR_PB_DISP_ADDR = 0x1A
XR_PB_LINE_LEN = 0x1B
XR_PB_HV_FSCALE = 0x1C
XR_PB_HV_SCROLL = 0x1D
XR_PB_LINE_ADDR = 0x1E
XR_PB_UNUSED_1F = 0x1F

XR_AUD0_VOL = 0x20
XR_AUD0_PERIOD = 0x21
XR_AUD0_LENGTH = 0x22
XR_AUD0_START = 0x23
XR_AUD1_VOL = 0x24
XR_AUD1_PERIOD = 0x25
XR_AUD1_LENGTH = 0x26
XR_AUD1_START = 0x27
XR_AUD2_VOL = 0x28
XR_AUD2_PERIOD = 0x29
XR_AUD2_LENGTH = 0x2A
XR_AUD2_START = 0x2B
XR_AUD3_VOL = 0x2C
XR_AUD3_PERIOD = 0x2D
XR_AUD3_LENGTH = 0x2E
XR_AUD3_START = 0x2F

XR_BLIT_CTRL = 0x40
XR_BLIT_ANDC = 0x41
XR_BLIT_XOR = 0x42
XR_BLIT_MOD_S = 0x43
XR_BLIT_SRC_S = 0x44
XR_BLIT_MOD_D = 0x45
XR_BLIT_DST_D = 0x46
XR_BLIT_SHIFT = 0x47
XR_BLIT_LINES = 0x48
XR_BLIT_WORDS = 0x49

function xsetbh(reg, val)
        poke(XOSERA_EVEN_BASE | (reg << 4), val >> 8)
end

function xsetbl(reg, val)
        poke(XOSERA_ODD_BASE | (reg << 4), val & 0xFF)
end

xsetw = asm_function([[
  lui   t0,0x20003
  slli  a0,a0,4
  add   t0,t0,a0
  srli  a2,a1,8
  sw    a2,0(t0)
  addi  t0,t0,0x100
  andi  a2,a1,0xFF
  sw    a2,0(t0)
  jalr  zero,0(ra)
]])

function _xsetw(reg, val)
        poke(XOSERA_EVEN_BASE | (reg << 4), val >> 8)
        poke(XOSERA_ODD_BASE | (reg << 4), val & 0xFF)
end

function xgetw(reg)
        local v = peek(XOSERA_EVEN_BASE | (reg << 4)) << 8
        v = v | peek(XOSERA_ODD_BASE | (reg << 4))
        return v
end

xreg_setw = asm_function([[
  lui   t0,0x20003
  srli  a2,a0,8
  sw    a2,{XM_WR_XADDR << 4}(t0)
  andi  a2,a0,0xFF
  sw    a2,{0x100 | (XM_WR_XADDR << 4)}(t0)
  srli  a2,a1,8
  sw    a2,{XM_XDATA << 4}(t0)
  andi  a2,a1,0xFF
  sw    a2,{0x100 | (XM_XDATA << 4)}(t0)
  jalr  zero,0(ra)
]])


function _xreg_setw(reg, val)
        xsetw(XM_WR_XADDR, reg)
        xsetw(XM_XDATA, val)
end

function xreg_getw(reg)
        xsetw(XM_RD_XADDR, reg)
        return xgetw(XM_XDATA)
end
