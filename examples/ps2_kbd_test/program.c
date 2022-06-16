#include <io.h>
#include <kbd.h>

void main(void)
{
    print("PS/2 Keyboard Test\r\n");
    for (;;) {
        char c = kbd_get_char();
        if (c == 13) {
            print("\r\n");
        } else {
            char cc[2] = "\0\0";
            cc[0] = c;
            print(cc);
        }
    } 
}
