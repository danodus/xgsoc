#include <io.h>
#include <mouse.h>
#include <stdlib.h>

void main(void)
{
    print("PS/2 Mouse Test\r\n");

    uint8_t last_buttons = mouse_get_buttons();
    uint16_t last_x = mouse_get_x();
    uint16_t last_y = mouse_get_y();

    for (;;) {
        uint8_t buttons = mouse_get_buttons();
        uint16_t x = mouse_get_x();
        uint16_t y = mouse_get_y();

        if (buttons != last_buttons || x != last_x || y != last_y) {
            char s[16];

            print("Buttons: ");
            itoa(buttons, s, 10);
            print(s);
            print(", x: ");
            itoa(x, s, 10);
            print(s);
            print(", y: ");
            itoa(y, s, 10);
            print(s);
            print("\r\n");

            last_buttons = buttons;
            last_x = x;
            last_y = y;
        }
    } 
}
