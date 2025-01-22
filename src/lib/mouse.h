#ifndef MOUSE_H
#define MOUSE_H

#include <stdint.h>
#include <stdbool.h>

bool mouse_get(bool is_blocking, uint8_t *btn, int8_t *dx, int8_t *dy, int8_t *dz);

#endif // MOUSE_H