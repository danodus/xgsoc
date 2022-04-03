#include <io.h>

#define XOSERA_EVEN_BASE          0x20003000  // even byte
#define XOSERA_ODD_BASE           0x20003100  // odd byte

void xwrite(unsigned int reg, unsigned int val)
{
    MEM_WRITE(XOSERA_EVEN_BASE | (reg << 4), val >> 8);
    MEM_WRITE(XOSERA_ODD_BASE | (reg << 4), val & 0xFF);
}

void xclear()
{
    xwrite(0x4, 1);    
    xwrite(0x5, 0);
    for (int i = 0; i < 80*30; ++i)
        xwrite(0x6, 0x0100 | '*');
}

void xprint(unsigned int x, unsigned int y, const char *s)
{
    xwrite(0x4, 1);    
    xwrite(0x5, y * 80 + x);
    for (; *s; ++s) {
        xwrite(0x6, 0x0F00 | *s);
    }
}

void main(void)
{
    xwrite(0x0, 0x10);
    xwrite(0x1, 0x0000);

    xclear();

    xprint(15, 10, "  Xosera and danoidus' RISC-V running on ULX3S!  ");
}
