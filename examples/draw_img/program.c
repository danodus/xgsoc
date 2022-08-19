#include <io.h>
#include <unistd.h>
#include <xosera.h>

#define WIDTH 640
#define NB_COLS (WIDTH / 8)

#define XGA_CONTROL          0x20003800
#define FB_BASE_ADDRESS      0x11000000

#define IMAGE_SIZE           (320*240)

uint16_t read_pixel()
{
    unsigned short int pixel = 0;
    for (int i = 0; i < 2; ++i) {
        pixel <<= 8;
        while(!(MEM_READ(UART_STATUS) & 2));
        // dequeue
        MEM_WRITE(UART_STATUS, 0x1);        
        unsigned int c = MEM_READ(UART_DATA);
        pixel |= c;
    }
    return pixel;
}

void receive_image() {
    uint32_t addr = FB_BASE_ADDRESS;

    for (unsigned int i = 0; i < IMAGE_SIZE / 2; ++i) {
        uint16_t msp = read_pixel();
        uint16_t lsp = read_pixel();
        uint32_t word = ((uint32_t)(msp) << 16) | (uint32_t)(lsp);
        MEM_WRITE(addr, word);
        addr += 4;
    }
}

void clear_fb()
{
    uint32_t addr = FB_BASE_ADDRESS;

    for (unsigned int i = 0; i < IMAGE_SIZE / 2; ++i) {
        MEM_WRITE(addr, 0xF000F000);
        addr += 4;
    }
}

void xclear()
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, 0);
    for (int i = 0; i < NB_COLS*30; ++i)
        xm_setw(DATA, 0x0F00 | ' ');
}

void main(void)
{
    // enable Graphite
    MEM_WRITE(XGA_CONTROL, 0x1);

    xreg_setw(PA_GFX_CTRL, 0x0000);
    xclear();

    clear_fb();

    for (;;) {
        receive_image();
    }
}
