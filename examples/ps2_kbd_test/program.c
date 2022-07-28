#include <io.h>
#include <kbd.h>
#include <stdlib.h>

void main(void)
{
    print("PS/2 Keyboard Test\r\n");
    for (;;) {
        uint16_t c = kbd_get_char(true);
        char s[16];
        itoa(c, s, 16);
        print(s);

        if (KBD_IS_EXTENDED(c)) {
            print(" (Extended)");
        } else {
            if (c >= ' ') {
                char cc[2] = "\0\0";
                cc[0] = c;
                print(" (");
                print(cc);
                print(")");
            }
        }
        print("\r\n");
    } 
}
