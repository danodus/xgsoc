#include <io.h>
#include <unistd.h>
#include <xosera.h>

#define WIDTH 640
#define NB_COLS (WIDTH / 8)

#define BLACK           0x0
#define BLUE            0x1
#define GREEN           0x2
#define CYAN            0x3
#define RED             0x4
#define MAGENTA         0x5
#define BROWN           0x6
#define WHITE           0x7
#define GRAY            0x8
#define LIGHT_BLUE      0x9
#define LIGHT_GREEN     0xA
#define LIGHT_CYAN      0xB
#define LIGHT_RED       0xC
#define LIGHT_MAGENTA   0xD
#define YELLOW          0xE
#define BRIGHT_WHITE    0xF


#define GRAPHITE             0x20003400
#define XGA_CONTROL          0x20003800

#define OP_SET_X0 0
#define OP_SET_Y0 1
#define OP_SET_Z0 2
#define OP_SET_X1 3
#define OP_SET_Y1 4
#define OP_SET_Z1 5
#define OP_SET_X2 6
#define OP_SET_Y2 7
#define OP_SET_Z2 8
#define OP_SET_R0 9
#define OP_SET_G0 10
#define OP_SET_B0 11
#define OP_SET_R1 12
#define OP_SET_G1 13
#define OP_SET_B1 14
#define OP_SET_R2 15
#define OP_SET_G2 16
#define OP_SET_B2 17
#define OP_SET_S0 18
#define OP_SET_T0 19
#define OP_SET_S1 20
#define OP_SET_T1 21
#define OP_SET_S2 22
#define OP_SET_T2 23
#define OP_CLEAR 24
#define OP_DRAW 25
#define OP_SWAP 26
#define OP_SET_TEX_ADDR 27
#define OP_WRITE_TEX 28

struct Command {
    uint32_t opcode : 8;
    uint32_t param : 24;
};

void send_command(struct Command *cmd)
{
    while (!MEM_READ(GRAPHITE));
    MEM_WRITE(GRAPHITE, (cmd->opcode << 24) | cmd->param);
}

void clear()
{
    struct Command cmd;

    // Clear framebuffer
    cmd.opcode = OP_CLEAR;
    cmd.param = 0x00F333;
    send_command(&cmd);
}

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

    MEM_WRITE(DISPLAY, 0xFF);

    // Read program
    const unsigned int size = 640*480;

    uint32_t tex_addr = 0;

    struct Command c;
    c.opcode = OP_SET_TEX_ADDR;
    c.param = tex_addr & 0xFFFF;
    send_command(&c);
    c.param = 0x10000 | (tex_addr >> 16);
    send_command(&c);

    c.opcode = OP_WRITE_TEX;

    for (unsigned int i = 0; i < size; ++i) {
        uint16_t pixel = read_pixel();
        c.param = pixel;
        send_command(&c);
        MEM_WRITE(DISPLAY, i << 1);        
    }
    MEM_WRITE(DISPLAY, 0x00);
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

    clear();

    for (;;) {
        receive_image();
    }
}
