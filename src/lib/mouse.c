#include "mouse.h"

#include "io.h"

bool mouse_get(bool is_blocking, uint8_t *btn, int8_t *dx, int8_t *dy, int8_t *dz) {
    for (;;) {
        uint32_t mouse_status = MEM_READ(PS2_MOUSE_STATUS);
        if (mouse_status) {
            uint32_t mouse_data = MEM_READ(PS2_MOUSE_DATA);
            *btn = (uint8_t)((mouse_data >> 24) & 0xFF);
            *dx = (int8_t)((mouse_data >> 16) & 0xFF);
            *dy = (int8_t)((mouse_data >> 8) & 0xFF);
            *dz = (int8_t)((mouse_data) & 0xFF);
            return true;
        } else {
            if (!is_blocking)
                break;
        }
    }

    return false;
}