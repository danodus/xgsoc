#include <io.h>

int test_mem(void) {
    unsigned int expected = 0x12345678;
    for (unsigned int addr = 0x10001000; addr < 0x10001100; addr++) {
        MEM_WRITE(addr, expected);
        unsigned int read = MEM_READ(addr);
        if (read != expected) {
            char s[16];
            print("Mismatch detected at address=");
            print(itoa(addr, s, 16));
            print(" expected=");
            print(itoa(expected, s, 16));
            print(" read=");
            print(itoa(read, s, 16));
            print("\r\n");
            return 0;
        }
    }
    return 1;
}

void main(void)
{
    MEM_WRITE(DISPLAY, 0x00);
    if (!test_mem()) {
        // failure
        MEM_WRITE(DISPLAY, 0x01);
    } else {
        // success
        MEM_WRITE(DISPLAY, 0x1E);
    }

    for (;;);
}
