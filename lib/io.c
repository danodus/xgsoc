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

char get_chr()
{
    while (1) {
        if (MEM_READ(UART_STATUS) & 2) {
            // dequeue
            MEM_WRITE(UART_STATUS, 0x1);
            unsigned int c = MEM_READ(UART_DATA);
            return (char)c;
        }
    }
}