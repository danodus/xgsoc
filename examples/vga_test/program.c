#include <io.h>
#include <stdint.h>

#define VGA         0x30000000
#define VGA_REGS    0x30020000
void main(void)
{

    uint32_t v = 0x01234567;
    uint32_t counter = 0;

    //for (uint32_t i = 0; i < 256; ++i) {
    //    MEM_WRITE(VGA_REGS + i * 4, 0x0FF);
    //}
    for (;;) {
        for (uint32_t i = 0; i < 424*240 / 8; i++)
            MEM_WRITE(VGA + i * 4, v);
        uint32_t x = v & 0xF;
        v >>= 4;
        v |= x << 28;

        MEM_WRITE(DISPLAY, counter >> 6);
        counter++;
    }
}
