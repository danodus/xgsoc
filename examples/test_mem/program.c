#include <io.h>
#include <stdlib.h>

int test_mem(void) {
    char s[16];
    for (unsigned int addr = 0x10008000; addr < 0x11000000 - 2048; addr+=4) {
        unsigned int expected = rand();
        if (addr % 2048 == 0) {
            print("Testing 2K range from address ");
            print(itoa(addr, s, 16));
            print(": ");
        }
        MEM_WRITE(addr, expected);
        unsigned int read = MEM_READ(addr);
        if (read != expected) {
            print("Mismatch detected at address ");
            print(itoa(addr, s, 16));
            print(" expected=");
            print(itoa(expected, s, 16));
            print(" read=");
            print(itoa(read, s, 16));
            print("\r\n");
            return 0;
        } else {
            if (addr % 2048 == 0)
                print("OK\r\n");
        }
    }
    return 1;
}

void main(void)
{
    MEM_WRITE(DISPLAY, 0x00);
    if (!test_mem()) {
        // failure
        print("*** FAILURE DETECTED ***\r\n");
    } else {
        // success
        print("*** SUCCESS ***\r\n");
    }

    for (;;);
}
