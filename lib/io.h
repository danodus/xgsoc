#ifndef IO_H
#define IO_H

#include <stddef.h>

#define DISPLAY         0x20001000
#define UART_DATA       0x20002000
#define UART_STATUS     0x20002004

#define MEM_WRITE(_addr_, _value_) (*((volatile unsigned int *)(_addr_)) = _value_)
#define MEM_READ(_addr_)           (*((volatile unsigned int *)(_addr_)))

void print_chr(char c);
void print_buf(const char *s, size_t len);
void print(const char *s);

char get_chr();

#endif // IO_H
