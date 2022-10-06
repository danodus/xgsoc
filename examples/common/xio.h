#ifndef XIO_H
#define XIO_H

#include <stddef.h>

void xinit();

void xprint_chr(char c);
void xprint_buf(const char *s, size_t len);
char xget_chr();

#endif
