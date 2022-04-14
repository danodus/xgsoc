#ifndef XIO_H
#define XIO_H

#include <stddef.h>

void xinit();
void xprint(const char *s);
size_t xreadline(char *s, size_t buffer_len);

#endif
