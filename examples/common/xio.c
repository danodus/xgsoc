#include "xio.h"

#include "xosera_ansiterm.h"
#include "kbd.h"

void xinit()
{
    xansiterm_INIT();
    xansiterm_UPDATECURSOR();
}

void xprint_chr(char c)
{
    xansiterm_PRINTCHAR(c);
    xansiterm_UPDATECURSOR();
}

void xprint(const char *s)
{
    xansiterm_PRINT(s);
    xansiterm_UPDATECURSOR();
}

char xget_chr()
{
    static char seq_index = -1;
    static char seq_char;

    while(1) {

        // send sequence if any
        if (seq_index == 0) {
            seq_index++;
            return 27;
        } else if (seq_index == 1) {
            seq_index++;
            return '[';
        } else if (seq_index == 2) {
            seq_index = -1;
            return seq_char;
        }
        
        // send ansi query response if any
        char c = xansiterm_RECVQUERY();
        if (c)
            return c;

        // read character from keyboard
        uint16_t cc = kbd_get_char();
        if (!KBD_IS_EXTENDED(cc)) {
            return (char)cc;
        } else {
            // the character is extended, send sequence if handled
            switch (cc) {
                case KBD_UP:
                    seq_char = 'A';
                    seq_index = 0;
                    break;
                case KBD_DOWN:
                    seq_char = 'B';
                    seq_index = 0;
                    break;
                case KBD_RIGHT:
                    seq_char = 'C';
                    seq_index = 0;
                    break;
                case KBD_LEFT:
                    seq_char = 'D';
                    seq_index = 0;
                    break;
                case KBD_END:
                    seq_char = 'F';
                    seq_index = 0;
                    break;
                case KBD_HOME:
                    seq_char = 'H';
                    seq_index = 0;
                    break;
            }
        }
    }
    
}