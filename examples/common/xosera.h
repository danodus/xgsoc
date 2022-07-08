// Ref.: https://github.com/XarkLabs/Xosera/tree/master/xosera_m68k_api

#ifndef XOSERA_H
#define XOSERA_H

#include "io.h"

#include <stdint.h>

#define XOSERA_EVEN_BASE          0x20003000  // even byte
#define XOSERA_ODD_BASE           0x20003100  // odd byte

#define _XREG_CONCAT(A, B)   A ## B
#define XM_STR(reg)          _XREG_CONCAT(XM_, reg)
#define XR_STR(reg)          _XREG_CONCAT(XR_, reg)

// Xosera XR Memory Regions (size in 16-bit words)
#define XR_COLOR_ADDR   0x8000        // (R/W) 0x8000-0x81FF 2 x A & B color lookup memory
#define XR_COLOR_SIZE   0x0200        //                      2 x 256 x 16-bit words  (0xARGB)
#define XR_COLOR_A_ADDR 0x8000        // (R/W) 0x8000-0x80FF A 256 entry color lookup memory
#define XR_COLOR_A_SIZE 0x0100        //                      256 x 16-bit words (0xARGB)
#define XR_COLOR_B_ADDR 0x8100        // (R/W) 0x8100-0x81FF B 256 entry color lookup memory
#define XR_COLOR_B_SIZE 0x0100        //                      256 x 16-bit words (0xARGB)
#define XR_TILE_ADDR    0xA000        // (R/W) 0xA000-0xB3FF tile glyph/tile map memory
#define XR_TILE_SIZE    0x1400        //                      5120 x 16-bit tile glyph/tile map memory
#define XR_COPPER_ADDR  0xC000        // (R/W) 0xC000-0xC7FF copper program memory (32-bit instructions)
#define XR_COPPER_SIZE  0x0800        //                      2048 x 16-bit copper program memory addresses
#define XR_UNUSED_ADDR  0xE000        // (-/-) 0xE000-0xFFFF unused

// Macros to make bit-fields easier (works similar to Verilog "+:" operator, e.g., word[RIGHTMOST_BIT +: BIT_WIDTH])
#define XB_(v, right_bit, bit_width) (((v) & ((1 << (bit_width)) - 1)) << (right_bit))

// Xosera Main Registers (XM Registers, directly CPU accessable)
// NOTE: Main register numbers are multiplied by 4 for rosco_m68k, because of even byte 6800 8-bit addressing plus
// 16-bit registers
#define XM_XR_ADDR   0x0         // (R /W+) XR register number/address for XM_XR_DATA read/write access
#define XM_XR_DATA   0x1         // (R /W+) read/write XR register/memory at XM_XR_ADDR (XM_XR_ADDR incr. on write)
#define XM_RD_INCR   0x2         // (R /W ) increment value for XM_RD_ADDR read from XM_DATA/XM_DATA_2
#define XM_RD_ADDR   0x3         // (R /W+) VRAM address for reading from VRAM when XM_DATA/XM_DATA_2 is read
#define XM_WR_INCR   0x4        // (R /W ) increment value for XM_WR_ADDR on write to XM_DATA/XM_DATA_2
#define XM_WR_ADDR   0x5        // (R /W ) VRAM address for writing to VRAM when XM_DATA/XM_DATA_2 is written
#define XM_DATA      0x6        // (R+/W+) read/write VRAM word at XM_RD_ADDR/XM_WR_ADDR (and add XM_RD_INCR/XM_WR_INCR)
#define XM_DATA_2    0x7        // (R+/W+) 2nd XM_DATA(to allow for 32-bit read/write access)
#define XM_SYS_CTRL  0x8        // (R /W+) busy status, FPGA reconfig, interrupt status/control, write masking
#define XM_TIMER     0x9        // (R /W+) read 1/10th millisecond timer, write clear interrupt signal
#define XM_LFSR      0xA        // (RO)    LFSR pseudo-random number // TODO: keep this?
#define XM_UNUSED_B  0xB        // (R /W ) unused direct register 0xB // TODO: slated for XR_DATA_2 after reorg
#define XM_RW_INCR   0xC        // (R /W ) XM_RW_ADDR increment value on read/write of XM_RW_DATA/XM_RW_DATA_2
#define XM_RW_ADDR   0xD        // (R /W+) read/write address for VRAM access from XM_RW_DATA/XM_RW_DATA_2
#define XM_RW_DATA   0xE        // (R+/W+) read/write VRAM word at XM_RW_ADDR (and add XM_RW_INCR)
#define XM_RW_DATA_2 0xF        // (R+/W+) 2nd XM_RW_DATA(to allow for 32-bit read/write access)

// XR Extended Register / Region (accessed via XM_XR_ADDR and XM_XR_DATA)

//  Video Config and Copper XR Registers
#define XR_VID_CTRL    0x00        // (R /W) display control and border color index
#define XR_COPP_CTRL   0x01        // (R /W) display synchronized coprocessor control
#define XR_AUD0_VOL    0x02        // (R /W) // TODO: to be refactored
#define XR_AUD0_PERIOD 0x03        // (R /W) // TODO: to be refactored
#define XR_AUD0_START  0x04        // (R /W) // TODO: to be refactored
#define XR_AUD0_LENGTH 0x05        // (R /W) // TODO: to be refactored
#define XR_VID_LEFT    0x06        // (R /W) left edge of active display window (typically 0)
#define XR_VID_RIGHT   0x07        // (R /W) right edge +1 of active display window (typically 640 or 848)
#define XR_SCANLINE    0x08        // (RO  ) [15] in V blank, [14] in H blank [10:0] V scanline
#define XR_UNUSED_09   0x09        // (RO  )
#define XR_VERSION     0x0A        // (RO  ) Xosera optional feature bits [15:8] and version code [7:0] [TODO]
#define XR_GITHASH_H   0x0B        // (RO  ) [15:0] high 16-bits of 32-bit Git hash build identifier
#define XR_GITHASH_L   0x0C        // (RO  ) [15:0] low 16-bits of 32-bit Git hash build identifier
#define XR_VID_HSIZE   0x0D        // (RO  ) native pixel width of monitor mode (e.g. 640/848)
#define XR_VID_VSIZE   0x0E        // (RO  ) native pixel height of monitor mode (e.g. 480)
#define XR_VID_VFREQ   0x0F        // (RO  ) update frequency of monitor mode in BCD 1/100th Hz (0x5997 = 59.97 Hz)


// Playfield A Control XR Registers
#define XR_PA_GFX_CTRL  0x10        // (R /W) playfield A graphics control
#define XR_PA_TILE_CTRL 0x11        // (R /W) playfield A tile control
#define XR_PA_DISP_ADDR 0x12        // (R /W) playfield A display VRAM start address
#define XR_PA_LINE_LEN  0x13        // (R /W) playfield A display line width in words
#define XR_PA_HV_SCROLL 0x14        // (R /W) playfield A horizontal and vertical fine scroll
#define XR_PA_LINE_ADDR 0x15        // (- /W) playfield A scanline start address (loaded at start of line)
#define XR_PA_HV_FSCALE 0x16        // (R /W) playfield A horizontal and vertical fractional scale
#define XR_PA_UNUSED_17 0x17        //

// Playfield B Control XR Registers
#define XR_PB_GFX_CTRL  0x18        // (R /W) playfield B graphics control
#define XR_PB_TILE_CTRL 0x19        // (R /W) playfield B tile control
#define XR_PB_DISP_ADDR 0x1A        // (R /W) playfield B display VRAM start address
#define XR_PB_LINE_LEN  0x1B        // (R /W) playfield B display line width in words
#define XR_PB_HV_SCROLL 0x1C        // (R /W) playfield B horizontal and vertical fine scroll
#define XR_PB_LINE_ADDR 0x1D        // (- /W) playfield B scanline start address (loaded at start of line)
#define XR_PB_HV_FSCALE 0x1E        // (R /W) playfield B horizontal and vertical fractional scale
#define XR_PB_UNUSED_1F 0x1F        //

#define MAKE_GFX_CTRL(colbase, blank, bpp, bm, hx, vx)                                                                 \
    (XB_(colbase, 8, 8) | XB_(blank, 7, 1) | XB_(bm, 6, 1) | XB_(bpp, 4, 2) | XB_(hx, 2, 2) | XB_(vx, 0, 2))
#define MAKE_TILE_CTRL(tilebase, map_in_tile, glyph_in_vram, tileheight)                                               \
    (((tilebase)&0xFC00) | XB_(map_in_tile, 9, 1) | XB_(glyph_in_vram, 8, 1) | XB_(((tileheight)-1), 0, 4))

#define xsetw(reg, val)                                           \
    {                                                             \
        uint16_t v = val;                                         \
        MEM_WRITE(XOSERA_EVEN_BASE | ((reg) << 4), (v) >> 8);     \
        MEM_WRITE(XOSERA_ODD_BASE | ((reg) << 4), (v) & 0xFF);    \
    }

#define xgetw(reg)                                  \
    ({                                              \
        uint16_t val = 0;                           \
        val = MEM_READ(XOSERA_EVEN_BASE | ((reg) << 4)) << 8;  \
        val |= (MEM_READ(XOSERA_ODD_BASE | ((reg) << 4)) & 0xFF);   \
        val;                                        \
    })

#define xm_setbh(reg, val)                                        \
    MEM_WRITE(XOSERA_EVEN_BASE | (XM_STR(reg) << 4), (val));

#define xm_setbl(reg, val)                                        \
    MEM_WRITE(XOSERA_ODD_BASE | (XM_STR(reg) << 4), (val));

#define xm_setw(reg, val)                                               \
    {                                                                   \
        uint16_t v = val;                                               \
        MEM_WRITE(XOSERA_EVEN_BASE | (XM_STR(reg) << 4), (v) >> 8);     \
        MEM_WRITE(XOSERA_ODD_BASE | (XM_STR(reg) << 4), (v) & 0xFF);    \
    }

#define xm_getw(reg)                                \
    ({xgetw(XM_STR(reg));})

#define xreg_setw(reg, val)                         \
    {                                               \
        xm_setw(XR_ADDR, XR_STR(reg));              \
        xm_setw(XR_DATA, (val));                    \
    }

#define xreg_getw(reg)                              \
    ({                                              \
        uint16_t val;                               \
        xm_setw(XR_ADDR, XR_STR(reg));              \
        val = xm_getw(XR_DATA);                     \
        val;                                        \
    })

#define xmem_setw(xrmem, val)                       \
    {                                               \
        xm_setw(XR_ADDR, xrmem);                    \
        xm_setw(XR_DATA, (val));                    \
    }    

#endif // XOSERA_H
