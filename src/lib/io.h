#ifndef _IO_H_
#define _IO_H_

#include <stddef.h>

#define BASE_IO     0xE0000000

#define TIMER            (BASE_IO + 0)
#define LED              (BASE_IO + 4)
#define UART_DATA        (BASE_IO + 8)
#define UART_STATUS      (BASE_IO + 12)
#define SPI_DATA         (BASE_IO + 16)
#define SPI_STATUS       (BASE_IO + 20)
#define PS2_KBD_DATA     (BASE_IO + 24)
#define PS2_KBD_STATUS   (BASE_IO + 28)
#define GRAPHITE         (BASE_IO + 32)
#define CONFIG           (BASE_IO + 36)
#define CONFIG2          (BASE_IO + 40)
#define CONFIG3          (BASE_IO + 44)
#define PS2_MOUSE_DATA   (BASE_IO + 48)
#define PS2_MOUSE_STATUS (BASE_IO + 52)

#define MEM_WRITE(_addr_, _value_) (*((volatile unsigned int *)(_addr_)) = _value_)
#define MEM_READ(_addr_) *((volatile unsigned int *)(_addr_))

char *uitoa(unsigned int value, char* result, int base);

// UART
int chr_avail();
char get_chr();
void print_chr(char c);
void print_buf(const char *s, size_t len);
void print(const char *s);

#endif