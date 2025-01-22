#include <vconsole.h>
#include <stdlib.h>
#include <io.h>

void main(void)
{
    vconsole_init();
    vconsole_print("Video Console\n");
    for (;;) {
        if (chr_avail()) {
            char c = get_chr();
            if (c == 27)
                break;
            vconsole_printc(c);
        }
    }
}
