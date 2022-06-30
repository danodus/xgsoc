#include <xosera_ansiterm.h>
#include <kbd.h>

void main(void)
{
    xansiterm_INIT();
    for(;;) {
        xansiterm_UPDATECURSOR();
        uint16_t c = kbd_get_char();
        if (!KBD_IS_EXTENDED(c))
            xansiterm_PRINTCHAR(c);
    };
}
