#include <xosera_ansiterm.h>
#include <kbd.h>

void main(void)
{
    xansiterm_INIT();
    for(;;) {
        xansiterm_UPDATECURSOR();
        char c = kbd_get_char();
        xansiterm_PRINTCHAR(c);
    };
}
