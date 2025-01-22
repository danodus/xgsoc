#include <io.h>
#include <mouse.h>
#include <stdlib.h>

void main(void)
{
    print("PS/2 Mouse Test\r\n");

    for (;;) {
        uint8_t btn;
        int8_t dx, dy, dz;
        if (mouse_get(true, &btn, &dx, &dy, &dz)) {
            char s[16];
            print("Buttons: ");
            itoa(btn, s, 10);
            print(s);
            print(", dx: ");
            itoa(dx, s, 10);
            print(s);
            print(", dy: ");
            itoa(dy, s, 10);
            print(s);
            print(", dz: ");
            itoa(dz, s, 10);
            print(s);
            print("\r\n");
        }
    } 
}
