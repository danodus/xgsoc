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
#define XR_COPPER_SIZE  0x0600        //                     2048 x 16-bit copper program memory addresses

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
#define XM_PIXEL_X   0xC        // (- /W+) pixel X coordinate / pixel base address
#define XM_PIXEL_Y   0xD        // (- /W+) pixel Y coordinate / pixel line width
#define XM_UART      0xE        // (R+/W+) optional debug USB UART communication
#define XM_FEATURE   0xF        // (R /W+) Xosera feature flags, write sets pixel base, width to X, Y and mask mode


// SYS_CTRL bit numbers NOTE: These are bits in high byte of SYS_CTRL word (for access with fast address register
// indirect with no offset)
#define SYS_CTRL_MEM_WAIT_B    7        // (RO   )  memory read/write operation pending (with contended memory)
#define SYS_CTRL_BLIT_FULL_B   6        // (RO   )  blitter queue is full, do not write new operation to blitter registers
#define SYS_CTRL_BLIT_BUSY_B   5        // (RO   )  blitter is still busy performing an operation (not done)
#define SYS_CTRL_UNUSED_12_B   4        // (RO   )  unused (reads 0)
#define SYS_CTRL_HBLANK_B      3        // (RO   )  video signal is in horizontal blank period
#define SYS_CTRL_VBLANK_B      2        // (RO   )  video signal is in vertical blank period
#define SYS_CTRL_PIX_NO_MASK_B 1        // (R /W )  PIXEL_X/Y won't set WR_MASK (low two bits of PIXEL_X ignored)
#define SYS_CTRL_PIX_8B_MASK_B 0        // (R /W )  PIXEL_X/Y 8-bit pixel mask for WR_MASK
// SYS_CTRL bit flags
#define SYS_CTRL_MEM_WAIT_F    0x80        // (RO   )  memory read/write operation pending (with contended memory)
#define SYS_CTRL_BLIT_FULL_F   0x40        // (RO   )  blitter queue is full (do not write to blitter registers)
#define SYS_CTRL_BLIT_BUSY_F   0x20        // (RO   )  blitter is still busy performing an operation (not done)
#define SYS_CTRL_UNUSED_12_F   0x10        // (RO   )  unused (reads 0)
#define SYS_CTRL_HBLANK_F      0x08        // (RO   )  video signal is in horizontal blank period
#define SYS_CTRL_VBLANK_F      0x04        // (RO   )  video signal is in vertical blank period
#define SYS_CTRL_PIX_NO_MASK_F 0x02        // (R /W )  PIXEL_X/Y won't set WR_MASK (low two bits of PIXEL_X ignored)
#define SYS_CTRL_PIX_8B_MASK_F 0x01        // (R /W )  PIXEL_X/Y 8-bit pixel mask for WR_MASK


// XR Extended Register / Region (accessed via XM_RD_XADDR/XM_WR_XADDR and XM_XDATA)

//  Video Config and Copper XR Registers
#define XR_VID_CTRL  0x00        // (R /W) display control and border color index
#define XR_COPP_CTRL 0x01        // (R /W) display synchronized coprocessor control
#define XR_AUD_CTRL  0x02        // (- /-) TODO: audio channel control
#define XR_SCANLINE  0x03        // (R /W) read scanline (incl. offscreen), write signal video interrupt
#define XR_VID_LEFT  0x04        // (R /W) left edge of active display window (typically 0)
#define XR_VID_RIGHT 0x05        // (R /W) right edge of active display window +1 (typically 640 or 848)
#define XR_POINTER_H 0x06        // (- /W) pointer sprite raw H position
#define XR_POINTER_V 0x07        // (- /W) pointer sprite raw V position / pointer color select
#define XR_UNUSED_08 0x08        // (- /-) unused XR 08
#define XR_UNUSED_09 0x09        // (- /-) unused XR 09
#define XR_UNUSED_0A 0x0A        // (- /-) unused XR 0A
#define XR_UNUSED_0B 0x0B        // (- /-) unused XR 0B
#define XR_UNUSED_0C 0x0C        // (- /-) unused XR 0C
#define XR_UNUSED_0D 0x0D        // (- /-) unused XR 0D
#define XR_UNUSED_0E 0x0E        // (- /-) unused XR 0E
#define XR_UNUSED_0F 0x0F        // (- /-) unused XR 0F

// Playfield A Control XR Registers
#define XR_PA_GFX_CTRL  0x10        // (R /W) playfield A graphics control
#define XR_PA_TILE_CTRL 0x11        // (R /W) playfield A tile control
#define XR_PA_DISP_ADDR 0x12        // (R /W) playfield A display VRAM start address
#define XR_PA_LINE_LEN  0x13        // (R /W) playfield A display line width in words
#define XR_PA_HV_FSCALE 0x14        // (R /W) playfield A horizontal and vertical fractional scale
#define XR_PA_HV_SCROLL 0x15        // (R /W) playfield A horizontal and vertical fine scroll
#define XR_PA_LINE_ADDR 0x16        // (- /W) playfield A scanline start address (loaded at start of line)
#define XR_PA_UNUSED_17 0x17        // (- /-)

// Playfield B Control XR Registers
#define XR_PB_GFX_CTRL  0x18        // (R /W) playfield B graphics control
#define XR_PB_TILE_CTRL 0x19        // (R /W) playfield B tile control
#define XR_PB_DISP_ADDR 0x1A        // (R /W) playfield B display VRAM start address
#define XR_PB_LINE_LEN  0x1B        // (R /W) playfield B display line width in words
#define XR_PB_HV_FSCALE 0x1C        // (R /W) playfield B horizontal and vertical fractional scale
#define XR_PB_HV_SCROLL 0x1D        // (R /W) playfield B horizontal and vertical fine scroll
#define XR_PB_LINE_ADDR 0x1E        // (- /W) playfield B scanline start address (loaded at start of line)
#define XR_PB_UNUSED_1F 0x1F        // (- /-)

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
#define XR_BLIT_CTRL  0x40        // (WO) blit control ([15:8]=transp value, [5]=8 bpp, [4]=transp on, [0]=S constant)
#define XR_BLIT_ANDC  0x41        // (WO) blit AND-COMPLEMENT constant value
#define XR_BLIT_XOR   0x42        // (WO) blit XOR constant value
#define XR_BLIT_MOD_S 0x43        // (WO) blit modulo added to S source after each line
#define XR_BLIT_SRC_S 0x44        // (WO) blit S source VRAM read address / constant value
#define XR_BLIT_MOD_D 0x45        // (WO) blit modulo added to D destination after each line
#define XR_BLIT_DST_D 0x46        // (WO) blit D destination VRAM write address
#define XR_BLIT_SHIFT 0x47        // (WO) blit first and last word nibble masks and nibble right shift (0-3)
#define XR_BLIT_LINES 0x48        // (WO) blit number of lines minus 1, (repeats blit word count after modulo calc)
#define XR_BLIT_WORDS 0x49        // (WO+) blit word count minus 1 per line (write starts blit operation)
#define XR_UNUSED_4A  0x4A        // unused XR reg
#define XR_UNUSED_4B  0x4B        // unused XR reg
#define XR_UNUSED_4C  0x4C        // unused XR reg
#define XR_UNUSED_4D  0x4D        // unused XR reg
#define XR_UNUSED_4E  0x4E        // unused XR reg
#define XR_UNUSED_4F  0x4F        // unused XR reg

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

#define xreg_setw_next(val)                         \
    {                                               \
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

#define xosera_vid_width()                         \
    (((xm_getbl(FEATURE) & 0xF) == 0) ? 640 : 848)

#define xosera_vid_height()                        \
    480

#endif // XOSERA_H
