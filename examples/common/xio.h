#ifndef XIO_H
#define XIO_H

#include <stddef.h>

#define EOF -1

void xinit();
void xprint(const char *s);
size_t xreadline(char *s, size_t buffer_len);

// stdio.h
int getchar();
int putchar(int character);

#endif
