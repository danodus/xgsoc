#include <io.h>

unsigned int fact(unsigned int i) {
    print(".");
    if (i <= 1)
        return 1;
    return i * fact(i-1);
}

void main(void)
{
    MEM_WRITE(DISPLAY, 0x01);
    unsigned int f = fact(5);
    print("\r\nThe factorial of 5 is ");
    char s[16];
    itoa(f, s, 10);
    print(s);
    print(".\r\n");

    MEM_WRITE(DISPLAY, 0x00);
}