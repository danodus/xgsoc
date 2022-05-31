#include <io.h>
#include <unistd.h>
#include <xosera.h>

#define WIDTH 640
#define NB_COLS (WIDTH / 8)

#define XGA_CONTROL          0x20003800
#define FB_BASE_ADDRESS      0x11000000

uint16_t read_pixel()
{
    unsigned short int pixel = 0;
    for (int i = 0; i < 2; ++i) {
        pixel <<= 8;
        while(!(MEM_READ(UART_STATUS) & 2));
        unsigned int c = MEM_READ(UART_DATA);
        pixel |= c;
    }
    return pixel;
}

void receive_image() {
    // Read program
    const unsigned int size = 640*480;

    uint32_t addr = 0x11000000;

    for (unsigned int i = 0; i < size; ++i) {
        uint16_t pixel = read_pixel();
        MEM_WRITE(addr, (uint32_t)pixel);
        addr += 2;
    }
}

void xclear()
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, 0);
    for (int i = 0; i < NB_COLS*30; ++i)
        xm_setw(DATA, 0x0F00 | ' ');
}

void xprint(unsigned int x, unsigned int y, const char *s, unsigned char color)
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, y * NB_COLS + x);
    unsigned int w = (unsigned int)color << 8;
    for (; *s; ++s) {
        xm_setw(DATA, w | *s);
    }
}

void main(void)
{
    // enable Graphite
    MEM_WRITE(XGA_CONTROL, 0x1);

    xreg_setw(PA_GFX_CTRL, 0x0000);
    xclear();

    for (;;) {
        receive_image();
    }
}
