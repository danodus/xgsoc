#include <io.h>
#include <unistd.h>
#include <stdbool.h>

#include <xosera.h>
#include <gamepad.h>

void xclear()
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, 0);
    for (int i = 0; i < 80*30; ++i)
        xm_setw(DATA, 0x0200 | ' ');
}

void xprint(unsigned int x, unsigned int y, const char *s)
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, y * 80 + x);
    for (; *s; ++s) {
        xm_setw(DATA, 0x0F00 | *s);
    }
}

void print_gamepad_status(unsigned int buttons)
{
    xprint(0, 0, "A:");
    xprint(8, 0, buttons & BUTTON_A_MASK ? "ON " : "OFF");
    xprint(0, 1, "B:");
    xprint(8, 1, buttons & BUTTON_B_MASK ? "ON " : "OFF");
    xprint(0, 2, "X:");
    xprint(8, 2, buttons & BUTTON_X_MASK ? "ON " : "OFF");
    xprint(0, 3, "Y:");
    xprint(8, 3, buttons & BUTTON_Y_MASK ? "ON " : "OFF");
    xprint(0, 4, "UP:");
    xprint(8, 4, buttons & BUTTON_UP_MASK ? "ON " : "OFF");
    xprint(0, 5, "DOWN:");
    xprint(8, 5, buttons & BUTTON_DOWN_MASK ? "ON " : "OFF");
    xprint(0, 6, "LEFT:");
    xprint(8, 6, buttons & BUTTON_LEFT_MASK ? "ON " : "OFF");
    xprint(0, 7, "RIGHT:");
    xprint(8, 7, buttons & BUTTON_RIGHT_MASK ? "ON " : "OFF");
    xprint(0, 8, "SLEFT:");
    xprint(8, 8, buttons & BUTTON_SHOULDER_LEFT_MASK ? "ON " : "OFF");
    xprint(0, 9, "SRIGHT:");
    xprint(8, 9, buttons & BUTTON_SHOULDER_RIGHT_MASK ? "ON " : "OFF");
    xprint(0, 10, "SELECT:");
    xprint(8, 10, buttons & BUTTON_SELECT_MASK ? "ON " : "OFF");
    xprint(0, 11, "START:");
    xprint(8, 11, buttons & BUTTON_START_MASK ? "ON " : "OFF");
}

// ref: https://stackoverflow.com/questions/8257714/how-to-convert-an-int-to-string-in-c
char *uitoa(unsigned int value, char* result, int base)
{
    // check that the base if valid
    if (base < 2 || base > 36) { *result = '\0'; return result; }

    char* ptr = result, *ptr1 = result, tmp_char;
    int tmp_value;

    for (int i = 0; i < 8; ++i) {
        tmp_value = value;
        value /= base;
        *ptr++ = "zyxwvutsrqponmlkjihgfedcba9876543210123456789abcdefghijklmnopqrstuvwxyz" [35 + (tmp_value - value * base)];
    }

    *ptr-- = '\0';
    while(ptr1 < ptr) {
        tmp_char = *ptr;
        *ptr--= *ptr1;
        *ptr1++ = tmp_char;
    }
    return result;
}

void print_usb_report(unsigned int report_msw, unsigned int report_lsw)
{
    static unsigned int last_report_msw = 0, last_report_lsw = 0;

    if (report_msw != last_report_msw || report_lsw != last_report_lsw) {
        char s[32];
        uitoa(report_msw, s, 16);
        xprint(0, 25, "        ");
        xprint(0, 25, s);
        uitoa(report_lsw, s, 16);
        xprint(0, 26, "        ");
        xprint(0, 26, s);

        last_report_msw = report_msw;
        last_report_lsw = report_lsw;
    }
}

void main(void)
{
    xreg_setw(PA_GFX_CTRL, 0x0000);
    xclear();

    unsigned int buttons;
    unsigned last_buttons = buttons;

    print_gamepad_status(buttons);

    for (;;) {
        unsigned int report_msw, report_lsw;
        read_gamepad(&report_msw, &report_lsw);
        print_usb_report(report_msw, report_lsw);
        buttons = get_buttons_kiwitata(report_msw, report_lsw);
        if (buttons != last_buttons) {
            print_gamepad_status(buttons);
            last_buttons = buttons;
        }
    }
}