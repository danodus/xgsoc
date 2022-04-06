#include <io.h>

#define USB_STATUS      0x20004000
#define USB_REPORT_MSW  0x20004004
#define USB_REPORT_LSW  0x20004008

// ref: https://stackoverflow.com/questions/8257714/how-to-convert-an-int-to-string-in-c
char *uitoa(unsigned int value, char* result, int base)
{
    // check that the base if valid
    if (base < 2 || base > 36) { *result = '\0'; return result; }

    char* ptr = result, *ptr1 = result, tmp_char;
    int tmp_value;

    for (int i = 0; i < 8; ++i) {
        tmp_value = value;
        value /= base;
        *ptr++ = "zyxwvutsrqponmlkjihgfedcba9876543210123456789abcdefghijklmnopqrstuvwxyz" [35 + (tmp_value - value * base)];
    }

    *ptr-- = '\0';
    while(ptr1 < ptr) {
        tmp_char = *ptr;
        *ptr--= *ptr1;
        *ptr1++ = tmp_char;
    }
    return result;
}


void main(void)
{
    unsigned int counter = 0;
    char s[64];

    for (;;) {
        if (MEM_READ(USB_STATUS) & 0x1) {
            print("USB report detected: ");
            unsigned int report_msw = MEM_READ(USB_REPORT_MSW);
            unsigned int report_lsw = MEM_READ(USB_REPORT_LSW);
            uitoa(report_msw, s, 16);
            print(s);
            uitoa(report_lsw, s, 16);
            print(s);
            print("\r\n");
        } 
    }
}
