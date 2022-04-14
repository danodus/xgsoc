#ifndef XOSERA_H
#define XOSERA_H

#include "io.h"

#define XOSERA_EVEN_BASE          0x20003000  // even byte
#define XOSERA_ODD_BASE           0x20003100  // odd byte

// XM
#define XR_ADDR   0x0
#define XR_DATA   0x1
#define	RD_INCR   0x2
#define	RD_ADDR   0x3
#define WR_INCR   0x4
#define WR_ADDR   0x5
#define DATA      0x6
#define DATA_2    0x7
#define SYS_CTRL  0x8
#define TIMER     0x9
#define LFSR	  0xA
#define UNUSED_B  0xB
#define RW_INCR   0xC
#define RW_ADDR   0xD
#define RW_DATA   0xE
#define RW_DATA_2 0xF

// XR
#define VID_CTRL    0x00 
#define AUD0_VOL    0x02        // (R /W) // TODO: to be refactored
#define AUD0_PERIOD 0x03        // (R /W) // TODO: to be refactored
#define AUD0_START  0x04        // (R /W) // TODO: to be refactored
#define AUD0_LENGTH 0x05        // (R /W) // TODO: to be refactored
#define PA_GFX_CTRL 0x10

void xsetw(unsigned int reg, unsigned int val)
{
    MEM_WRITE(XOSERA_EVEN_BASE | (reg << 4), val >> 8);
    MEM_WRITE(XOSERA_ODD_BASE | (reg << 4), val & 0xFF);
}

unsigned int xgetw(unsigned int reg)
{
    unsigned int val = 0;
    MEM_READ(XOSERA_EVEN_BASE | (reg << 4));
    val |= MEM_READ(XOSERA_EVEN_BASE) << 8;
    MEM_READ(XOSERA_ODD_BASE | (reg << 4));
    val |= MEM_READ(XOSERA_ODD_BASE) & 0xFF;
    return val;
}

void xm_setw(unsigned int reg, unsigned int val)
{
    xsetw(reg, val);
}
unsigned int xm_getw(unsigned int reg)
{
    return xgetw(reg);
}

void xreg_setw(unsigned int reg, unsigned int val)
{
    xsetw(XR_ADDR, reg);
    xsetw(XR_DATA, val);
}

#endif // XOSERA_H
