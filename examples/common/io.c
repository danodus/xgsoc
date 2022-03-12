#include "io.h"

// ref: https://stackoverflow.com/questions/8257714/how-to-convert-an-int-to-string-in-c
char *itoa(int value, char* result, int base)
{
    // check that the base if valid
    if (base < 2 || base > 36) { *result = '\0'; return result; }

    char* ptr = result, *ptr1 = result, tmp_char;
    int tmp_value;

    do {
        tmp_value = value;
        value /= base;
        *ptr++ = "zyxwvutsrqponmlkjihgfedcba9876543210123456789abcdefghijklmnopqrstuvwxyz" [35 + (tmp_value - value * base)];
    } while ( value );

    // Apply negative sign
    if (tmp_value < 0) *ptr++ = '-';
    *ptr-- = '\0';
    while(ptr1 < ptr) {
        tmp_char = *ptr;
        *ptr--= *ptr1;
        *ptr1++ = tmp_char;
    }
    return result;
}

void print(const char *s)
{
    while (*s) {
        
        while(MEM_READ(UART_STATUS) & 1);
        MEM_WRITE(UART_DATA, *s);
        s++;
    }
}
