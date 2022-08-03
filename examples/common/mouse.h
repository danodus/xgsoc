#ifndef MOUSE_H
#define MOUSE_H

#include <stdint.h>

uint8_t mouse_get_buttons();
uint16_t mouse_get_x();
uint16_t mouse_get_y();

#endif // MOUSE_H