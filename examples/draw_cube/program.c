#include <io.h>
#include <unistd.h>

#define VGA             0x20003000

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
#define OP_SET_COLOR 24
#define OP_CLEAR 25
#define OP_DRAW 26
#define OP_SWAP 27
#define OP_SET_TEX_ADDR 28
#define OP_WRITE_TEX 29

struct Command {
    uint32_t opcode : 8;
    uint32_t param : 24;
};

void main(void)
{
    struct Command cmd;
    uint32_t *pcmd = (uint32_t *)(&cmd);

    // Clear framebuffer
    cmd.opcode = OP_CLEAR;
    cmd.param = 0x00F333;
    while (!MEM_READ(VGA));
    MEM_WRITE(VGA, (cmd.opcode << 24) | cmd.param);
}
