#include <io.h>
#include <stdint.h>

#define VDU         0x10000000
#define VDU_REGS    0x10020000
void main(void)
{

    uint32_t v = 0x01020304;
    uint32_t counter = 0;

    //for (uint32_t i = 0; i < 256; ++i) {
    //    MEM_WRITE(VGA_REGS + i * 4, 0x0FF);
    //}

    for (;;) {
        for (uint32_t i = 0; i < 320*240 / 4; i++)
            MEM_WRITE(VDU + i * 4, v);
        uint32_t x = v & 0xFF;
        v >>= 8;
        v |= x << 24;

        MEM_WRITE(LED, counter >> 6);
        counter++;
    }
}