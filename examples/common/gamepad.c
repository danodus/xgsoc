#include "gamepad.h"
#include "io.h"

#define USB_STATUS      0x20004000
#define USB_REPORT_MSW  0x20004004
#define USB_REPORT_LSW  0x20004008

void read_gamepad(unsigned int *report_msw, unsigned int *report_lsw)
{
    *report_msw = MEM_READ(USB_REPORT_MSW);
    *report_lsw = MEM_READ(USB_REPORT_LSW);
}

unsigned int get_buttons_kiwitata(unsigned int report_msw, unsigned int report_lsw)
{
    unsigned int ret = 0;

    if (report_msw & 0x00002000)
        ret |= BUTTON_A_MASK;

    if (report_msw & 0x00004000)
        ret |= BUTTON_B_MASK;

    if (report_msw & 0x00001000)
        ret |= BUTTON_X_MASK;

    if (report_msw & 0x00008000)
        ret |= BUTTON_Y_MASK;

    if ((report_msw & 0x000000FF) == 0x00000000)
        ret |= BUTTON_UP_MASK;

    if ((report_msw & 0x000000FF) == 0x000000FF)
        ret |= BUTTON_DOWN_MASK;

    if ((report_lsw & 0xFF000000) == 0x00000000)
        ret |= BUTTON_LEFT_MASK;

    if ((report_lsw & 0xFF000000) == 0xFF000000)
        ret |= BUTTON_RIGHT_MASK;

    if (report_msw & 0x00010000)
        ret |= BUTTON_SHOULDER_LEFT_MASK;

    if (report_msw & 0x00020000)
        ret |= BUTTON_SHOULDER_RIGHT_MASK;

    if (report_msw & 0x00100000)
        ret |= BUTTON_SELECT_MASK;

    if (report_msw & 0x00200000)
        ret |= BUTTON_START_MASK;

    return ret;
}

