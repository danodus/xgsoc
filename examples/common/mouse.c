#include "mouse.h"

#include "io.h"

#define PS2_MOUSE_BUTTONS  0x20005008
#define PS2_MOUSE_X        0x2000500C
#define PS2_MOUSE_Y        0x20005010

uint8_t mouse_get_buttons()
{
    return (uint8_t)MEM_READ(PS2_MOUSE_BUTTONS);
}

uint16_t mouse_get_x()
{
    return (uint16_t)MEM_READ(PS2_MOUSE_X);
}

uint16_t mouse_get_y()
{
    return (uint16_t)MEM_READ(PS2_MOUSE_Y);
}
