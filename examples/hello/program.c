#include <io.h>

void main(void)
{
    unsigned int counter = 0;

    for (;;) {
        print("Hello, world!\r\n");
        MEM_WRITE(DISPLAY, counter >> 6);
        counter++;
    }
}
