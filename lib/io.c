#include "io.h"

void print_chr(char c)
{
    while(MEM_READ(UART_STATUS) & 1);
    MEM_WRITE(UART_DATA, c);
}

void print(const char *s)
{
    while (*s) {
        print_chr(*s);        
        s++;
    }
}
