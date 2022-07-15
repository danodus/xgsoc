XOSERA_EVEN_BASE = 0x20003000
XOSERA_ODD_BASE = 0x20003100

XM_XR_ADDR = 0x0
XM_XR_DATA = 0x1
XM_RD_INCR = 0x2
XM_RD_ADDR = 0x3
XM_WR_INCR = 0x4
XM_WR_ADDR = 0x5
XM_DATA = 0x6
XM_DATA_2 = 0x7
XM_SYS_CTRL = 0x8
XM_TIMER = 0x9
XM_LFSR = 0xA
XM_UNUSED_B = 0xB
XM_RW_INCR = 0xC
XM_RW_ADDR = 0xD
XM_RW_DATA = 0xE
XM_RW_DATA_2 = 0xF

XR_VID_CTRL = 0x00
XR_COPP_CTRL = 0x01
XR_UNUSED_02 = 0x02
XR_UNUSED_03 = 0x03
XR_UNUSED_04 = 0x04
XR_UNUSED_05 = 0x05
XR_VID_LEFT = 0x06
XR_VID_RIGHT = 0x07
XR_SCANLINE = 0x08
XR_UNUSED_09 = 0x09
XR_UNUSED_0A = 0x0A
XR_UNUSED_0B = 0x0B
XR_UNUSED_0C = 0x0C
XR_VID_HSIZE = 0x0D
XR_VID_VSIZE = 0x0E
XR_UNUSED_0F = 0x0F
XR_PA_GFX_CTRL = 0x10
XR_PA_TILE_CTRL = 0x11
XR_PA_DISP_ADDR = 0x12
XR_PA_LINE_LEN = 0x13
XR_PA_HV_SCROLL = 0x14
XR_PA_LINE_ADDR = 0x15
XR_PA_HV_FSCALE = 0x16
XR_PA_UNUSED_17 = 0x17

XR_PB_GFX_CTRL = 0x18
XR_PB_TILE_CTRL = 0x19
XR_PB_DISP_ADDR = 0x1A
XR_PB_LINE_LEN = 0x1B
XR_PB_HV_SCROLL = 0x1C
XR_PB_LINE_ADDR = 0x1D
XR_PB_HV_FSCALE = 0x16
XR_PB_UNUSED_1F = 0x1F

XR_BLIT_CTRL = 0x20
XR_BLIT_MOD_A = 0x21
XR_BLIT_SRC_A = 0x22
XR_BLIT_MOD_B = 0x23
XR_BLIT_SRC_B = 0x24
XR_BLIT_MOD_C = 0x25
XR_BLIT_VAL_C = 0x26
XR_BLIT_MOD_D = 0x27
XR_BLIT_DST_D = 0x28
XR_BLIT_SHIFT = 0x29
XR_BLIT_LINES = 0x2A
XR_BLIT_WORDS = 0x2B

function xsetbh(reg, val)
        poke(XOSERA_EVEN_BASE | (reg << 4), val >> 8)
end

function xsetbl(reg, val)
        poke(XOSERA_ODD_BASE | (reg << 4), val & 0xFF)
end

function xsetw(reg, val)
        poke(XOSERA_EVEN_BASE | (reg << 4), val >> 8)
        poke(XOSERA_ODD_BASE | (reg << 4), val & 0xFF)
end

function xgetw(reg)
        local v = peek(XOSERA_EVEN_BASE | (reg << 4)) << 8
        v = v | peek(XOSERA_ODD_BASE | (reg << 4))
        return v
end

function xreg_setw(reg, val)
        xsetw(XM_XR_ADDR, reg)
        xsetw(XM_XR_DATA, val)
end

function xreg_getw(reg)
        xsetw(XM_XR_ADDR, reg)
        return xgetw(XM_XR_DATA)
end
