#include <io.h>
#include <stdint.h>

#define VGA         0x30000000

void main(void)
{

    uint32_t v = 0x01020304;
    uint32_t counter = 0;
    for (;;) {
        for (uint32_t i = 0; i < 424*240 / 4; i++)
            MEM_WRITE(VGA + i * 4, v);
        uint32_t x = v & 0xFF;
        v >>= 8;
        v |= x << 24;

        MEM_WRITE(DISPLAY, counter >> 6);
        counter++;
    }
}
