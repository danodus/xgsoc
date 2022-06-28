#include <xosera_ansiterm.h>
#include <kbd.h>

void main(void)
{
    xansiterm_INIT();
    for(;;) {
        xansiterm_UPDATECURSOR();
        char c = kbd_get_char();
        for (int i = 32; i < 128; ++i)
            xansiterm_PRINTCHAR(i);
    };
}
