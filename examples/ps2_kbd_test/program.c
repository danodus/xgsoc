#include <io.h>
#include <kbd.h>

void main(void)
{
    for (;;) {
        char c = getch();
        if (c == 13) {
            print("\r\n");
        } else {
            char cc[2] = "\0\0";
            cc[0] = c;
            print(cc);
        }
    } 
}
