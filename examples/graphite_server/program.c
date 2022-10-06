#include <io.h>
#include <unistd.h>
#include <xosera.h>

#define WIDTH 848
#define NB_COLS (WIDTH / 8)

#define GRAPHITE             0x20003400
#define XGA_CONTROL          0x20003800

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

uint32_t receive_command()
{
    uint32_t command = 0;
    for (int i = 0; i < 4; ++i) {
        command <<= 8;
        while(!(MEM_READ(UART_STATUS) & 2));
        // dequeue
        MEM_WRITE(UART_STATUS, 0x1);        
        unsigned int c = MEM_READ(UART_DATA);
        command |= c;
    }
    return command;
}

void receive_commands() {

    int counter = 0;
    for(;;) {
        uint32_t command = receive_command();
        while (!MEM_READ(GRAPHITE));
        MEM_WRITE(GRAPHITE, command);
        xprint(79, 0, counter & 0x8 ? "R" : " ", 0xF);
        counter++;
    }
}

void main(void)
{
    // enable Graphite
    MEM_WRITE(XGA_CONTROL, 0x1);

    xreg_setw(PA_GFX_CTRL, 0x0000);
    xclear();
    xprint(0, 0, "Graphite Server", 0xF);

    receive_commands();

    // disable Graphite
    MEM_WRITE(XGA_CONTROL, 0x0);
}
