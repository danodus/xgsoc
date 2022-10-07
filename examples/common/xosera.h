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
#define XR_CONFIG_REGS  0x0000        // 0x0000-0x000F 16 config/ctrl registers
#define XR_PA_REGS      0x0010        // 0x0010-0x0017 8 playfield A video registers
#define XR_PB_REGS      0x0018        // 0x0018-0x001F 8 playfield B video registers
#define XR_AUDIO_REGS   0x0020        // 0x0020-0x002F 16 audio playback registers      // TODO: audio
#define XR_BLIT_REGS    0x0040        // 0x0040-0x004B 12 blitter registers
#define XR_TILE_ADDR    0x4000        // (R/W) 0x4000-0x53FF tile glyph/tile map memory
#define XR_TILE_SIZE    0x1400        //                     5120 x 16-bit tile glyph/tile map memory
#define XR_COLOR_ADDR   0x8000        // (R/W) 0x8000-0x81FF 2 x A & B color lookup memory
#define XR_COLOR_SIZE   0x0200        //                     2 x 256 x 16-bit words  (0xARGB)
#define XR_COLOR_A_ADDR 0x8000        // (R/W) 0x8000-0x80FF A 256 entry color lookup memory
#define XR_COLOR_A_SIZE 0x0100        //                     256 x 16-bit words (0xARGB)
#define XR_COLOR_B_ADDR 0x8100        // (R/W) 0x8100-0x81FF B 256 entry color lookup memory
#define XR_COLOR_B_SIZE 0x0100        //                     256 x 16-bit words (0xARGB)
#define XR_COPPER_ADDR  0xC000        // (R/W) 0xC000-0xC7FF copper program memory (32-bit instructions)
#define XR_COPPER_SIZE  0x0800        //                     2048 x 16-bit copper program memory addresses

// Macros to make bit-fields easier (works similar to Verilog "+:" operator, e.g., word[RIGHTMOST_BIT +: BIT_WIDTH])
#define XB_(v, right_bit, bit_width) (((v) & ((1 << (bit_width)) - 1)) << (right_bit))

// Xosera Main Registers (XM Registers, directly CPU accessable)
// NOTE: Main register numbers are multiplied by 4 for rosco_m68k, because of even byte 6800 8-bit addressing plus
// 16-bit registers
#define XM_SYS_CTRL  0x0        // (R /W+) status bits, FPGA config, write masking
#define XM_INT_CTRL  0x1        // (R /W ) interrupt status/control
#define XM_TIMER     0x2        // (RO   ) read 1/10th millisecond timer
#define XM_RD_XADDR  0x3        // (R /W+) XR register/address for XM_XDATA read access
#define XM_WR_XADDR  0x4        // (R /W ) XR register/address for XM_XDATA write access
#define XM_XDATA     0x5        // (R /W+) read/write XR register/memory at XM_RD_XADDR/XM_WR_XADDR
#define XM_RD_INCR   0x6        // (R /W ) increment value for XM_RD_ADDR read from XM_DATA/XM_DATA_2
#define XM_RD_ADDR   0x7        // (R /W+) VRAM address for reading from VRAM when XM_DATA/XM_DATA_2 is read
#define XM_WR_INCR   0x8        // (R /W ) increment value for XM_WR_ADDR on write to XM_DATA/XM_DATA_2
#define XM_WR_ADDR   0x9        // (R /W ) VRAM address for writing to VRAM when XM_DATA/XM_DATA_2 is written
#define XM_DATA      0xA        // (R+/W+) read/write VRAM word at XM_RD_ADDR/XM_WR_ADDR & add XM_RD_INCR/XM_WR_INCR
#define XM_DATA_2    0xB        // (R+/W+) 2nd XM_DATA(to allow for 32-bit read/write access)
#define XM_UNUSED_0C 0xC        // (- /- )
#define XM_UNUSED_0D 0xD        // (- /- )
#define XM_UNUSED_0E 0xE        // (- /- )
#define XM_UNUSED_0F 0xF        // (- /- )


// SYS_CTRL bit numbers NOTE: These are bits in high byte of SYS_CTRL word (for access with fast address register
// indirect with no offset)
#define SYS_CTRL_MEM_BUSY_B  7        // (RO   )  memory read/write operation pending (with contended memory)
#define SYS_CTRL_BLIT_FULL_B 6        // (RO   )  blitter queue is full, do not write new operation to blitter registers
#define SYS_CTRL_BLIT_BUSY_B 5        // (RO   )  blitter is still busy performing an operation (not done)
#define SYS_CTRL_UNUSED_12_B 4        // (RO   )  unused (reads 0)
#define SYS_CTRL_HBLANK_B    3        // (RO   )  video signal is in horizontal blank period
#define SYS_CTRL_VBLANK_B    2        // (RO   )  video signal is in vertical blank period
#define SYS_CTRL_UNUSED_9_B  1        // (RO   )  unused (reads 0)
#define SYS_CTRL_UNUSED_8_B  0        // (- /- )
// SYS_CTRL bit flags
#define SYS_CTRL_MEM_BUSY_F  0x80        // (RO   )  memory read/write operation pending (with contended memory)
#define SYS_CTRL_BLIT_FULL_F 0x40        // (RO   )  blitter queue is full (do not write to blitter registers)
#define SYS_CTRL_BLIT_BUSY_F 0x20        // (RO   )  blitter is still busy performing an operation (not done)
#define SYS_CTRL_UNUSED_12_F 0x10        // (RO   )  unused (reads 0)
#define SYS_CTRL_HBLANK_F    0x08        // (RO   )  video signal is in horizontal blank period
#define SYS_CTRL_VBLANK_F    0x04        // (RO   )  video signal is in vertical blank period
#define SYS_CTRL_UNUSED_9_F  0x02        // (RO   )  unused (reads 0)
#define SYS_CTRL_UNUSED_8_F  0x01        // (- /- )


// XR Extended Register / Region (accessed via XM_XR_ADDR and XM_XR_DATA)

//  Video Config and Copper XR Registers
#define XR_VID_CTRL  0x00        // (R /W) display control and border color index
#define XR_COPP_CTRL 0x01        // (R /W) display synchronized coprocessor control
#define XR_AUD_CTRL  0x02        // (- /-) TODO: audio channel control
#define XR_UNUSED_03 0x03        // (- /-) TODO: unused XR 03
#define XR_VID_LEFT  0x04        // (R /W) left edge of active display window (typically 0)
#define XR_VID_RIGHT 0x05        // (R /W) right edge of active display window +1 (typically 640 or 848)
#define XR_UNUSED_06 0x06        // (- /-) TODO: unused XR 06
#define XR_UNUSED_07 0x07        // (- /-) TODO: unused XR 07
#define XR_SCANLINE  0x08        // (RO  ) scanline (including offscreen >= 480)
#define XR_FEATURES  0x09        // (RO  ) update frequency of monitor mode in BCD 1/100th Hz (0x5997 = 59.97 Hz)
#define XR_VID_HSIZE 0x0A        // (RO  ) native pixel width of monitor mode (e.g. 640/848)
#define XR_VID_VSIZE 0x0B        // (RO  ) native pixel height of monitor mode (e.g. 480)
#define XR_UNUSED_0C 0x0C        // (- /-) TODO: unused XR 0C
#define XR_UNUSED_0D 0x0D        // (- /-) TODO: unused XR 0D
#define XR_UNUSED_0E 0x0E        // (- /-) TODO: unused XR 0E
#define XR_UNUSED_0F 0x0F        // (- /-) TODO: unused XR 0F


// Playfield A Control XR Registers
#define XR_PA_GFX_CTRL  0x10        // (R /W) playfield A graphics control
#define XR_PA_TILE_CTRL 0x11        // (R /W) playfield A tile control
#define XR_PA_DISP_ADDR 0x12        // (R /W) playfield A display VRAM start address
#define XR_PA_LINE_LEN  0x13        // (R /W) playfield A display line width in words
#define XR_PA_HV_FSCALE 0x14        // (R /W) playfield A horizontal and vertical fractional scale
#define XR_PA_HV_SCROLL 0x15        // (R /W) playfield A horizontal and vertical fine scroll
#define XR_PA_LINE_ADDR 0x16        // (- /W) playfield A scanline start address (loaded at start of line)
#define XR_PA_UNUSED_17 0x17        // // TODO: colorbase?

// Playfield B Control XR Registers
#define XR_PB_GFX_CTRL  0x18        // (R /W) playfield B graphics control
#define XR_PB_TILE_CTRL 0x19        // (R /W) playfield B tile control
#define XR_PB_DISP_ADDR 0x1A        // (R /W) playfield B display VRAM start address
#define XR_PB_LINE_LEN  0x1B        // (R /W) playfield B display line width in words
#define XR_PB_HV_FSCALE 0x1C        // (R /W) playfield B horizontal and vertical fractional scale
#define XR_PB_HV_SCROLL 0x1D        // (R /W) playfield B horizontal and vertical fine scroll
#define XR_PB_LINE_ADDR 0x1E        // (- /W) playfield B scanline start address (loaded at start of line)
#define XR_PB_UNUSED_1F 0x1F        // // TODO: colorbase?

// Audio Registers
#define XR_AUD0_VOL    0x20        // (WO/-) // TODO: WIP
#define XR_AUD0_PERIOD 0x21        // (WO/-) // TODO: WIP
#define XR_AUD0_LENGTH 0x22        // (WO/-) // TODO: WIP
#define XR_AUD0_START  0x23        // (WO/-) // TODO: WIP
#define XR_AUD1_VOL    0x24        // (WO/-) // TODO: WIP
#define XR_AUD1_PERIOD 0x25        // (WO/-) // TODO: WIP
#define XR_AUD1_LENGTH 0x26        // (WO/-) // TODO: WIP
#define XR_AUD1_START  0x27        // (WO/-) // TODO: WIP
#define XR_AUD2_VOL    0x28        // (WO/-) // TODO: WIP
#define XR_AUD2_PERIOD 0x29        // (WO/-) // TODO: WIP
#define XR_AUD2_LENGTH 0x2A        // (WO/-) // TODO: WIP
#define XR_AUD2_START  0x2B        // (WO/-) // TODO: WIP
#define XR_AUD3_VOL    0x2C        // (WO/-) // TODO: WIP
#define XR_AUD3_PERIOD 0x2D        // (WO/-) // TODO: WIP
#define XR_AUD3_LENGTH 0x2E        // (WO/-) // TODO: WIP
#define XR_AUD3_START  0x2F        // (WO/-) // TODO: WIP

// Blitter Registers
#define XR_BLIT_CTRL  0x40        // (R /W) blit control (transparency control, logic op and op input flags)
#define XR_BLIT_MOD_A 0x41        // (R /W) blit line modulo added to SRC_A (XOR if A const)
#define XR_BLIT_SRC_A 0x42        // (R /W) blit A source VRAM read address / constant value
#define XR_BLIT_MOD_B 0x43        // (R /W) blit line modulo added to SRC_B (XOR if B const)
#define XR_BLIT_SRC_B 0x44        // (R /W) blit B AND source VRAM read address / constant value
#define XR_BLIT_MOD_C 0x45        // (R /W) blit line XOR modifier for C_VAL const
#define XR_BLIT_VAL_C 0x46        // (R /W) blit C XOR constant value
#define XR_BLIT_MOD_D 0x47        // (R /W) blit modulo added to D destination after each line
#define XR_BLIT_DST_D 0x48        // (R /W) blit D VRAM destination write address
#define XR_BLIT_SHIFT 0x49        // (R /W) blit first and last word nibble masks and nibble right shift (0-3)
#define XR_BLIT_LINES 0x4A        // (R /W) blit number of lines minus 1, (repeats blit word count after modulo calc)
#define XR_BLIT_WORDS 0x4B        // (R /W) blit word count minus 1 per line (write starts blit operation)
#define XR_UNUSED_2C  0x4C        // (- /-) TODO: unused XR 2C
#define XR_UNUSED_2D  0x4D        // (- /-) TODO: unused XR 2D
#define XR_UNUSED_2E  0x4E        // (- /-) TODO: unused XR 2E
#define XR_UNUSED_2F  0x4F        // (- /-) TODO: unused XR 2F

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

#define xgetw(reg)                                                  \
    ({                                                              \
        uint16_t val = 0;                                           \
        val = MEM_READ(XOSERA_EVEN_BASE | ((reg) << 4)) << 8;       \
        val |= (MEM_READ(XOSERA_ODD_BASE | ((reg) << 4)) & 0xFF);   \
        val;                                                        \
    })

#define xgetbh(reg)                                                    \
    ({                                                                 \
        uint8_t val = MEM_READ(XOSERA_EVEN_BASE | ((reg) << 4));       \
        val;                                                           \
    })

#define xgetbl(reg)                                                  \
    ({                                                               \
        uint8_t val = (MEM_READ(XOSERA_ODD_BASE | ((reg) << 4)));    \
        val;                                                         \
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

#define xm_getbh(reg)                                \
    ({xgetbh(XM_STR(reg));})

#define xm_getbl(reg)                                \
    ({xgetbl(XM_STR(reg));})

#define xreg_setw(reg, val)                         \
    {                                               \
        xm_setw(WR_XADDR, XR_STR(reg));             \
        xm_setw(XDATA, (val));                      \
    }

#define xreg_getw(reg)                              \
    ({                                              \
        uint16_t val;                               \
        xm_setw(RD_XADDR, XR_STR(reg));             \
        val = xm_getw(XDATA);                       \
        val;                                        \
    })

#define xmem_setw(xrmem, val)                       \
    {                                               \
        xm_setw(WR_XADDR, xrmem);                   \
        xm_setw(XDATA, (val));                      \
    }    

// set XR memory write address xrmem (use xmem_setw_next()/xmem_setw_next_wait() to write data)
#define xmem_set_addr(xrmem) xm_setw(WR_XADDR, (xrmem))

// set next xmem (i.e., next WR_XADDR after increment) 16-bit word value
#define xmem_setw_next(word_value) xm_setw(XDATA, (word_value))

#endif // XOSERA_H
