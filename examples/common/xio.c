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

void xprint_buf(const char *s, size_t len)
{
    xansiterm_PRINTBUF(s, len);
    xansiterm_UPDATECURSOR();
}

char xget_chr()
{
    static int seq_index = -1;
    static char *seq_char;

    while(1) {

        // send sequence if any
        if (seq_index == 0) {
            seq_index++;
            return 27;
        } else if (seq_index == 1) {
            seq_index++;
            return '[';
        } else if (seq_index >= 2) {
            char c = seq_char[seq_index - 2];
            if (c) {
                seq_index++;
                return c;
            } else {
                seq_index = -1;
            }
        }
        
        // send ansi query response if any
        char c = xansiterm_RECVQUERY();
        if (c)
            return c;

        // read character from keyboard
        uint16_t cc = kbd_get_char(true);
        if (!KBD_IS_EXTENDED(cc)) {
            return (char)cc;
        } else {
            // the character is extended, send sequence if handled
            switch (cc) {
                case KBD_UP:
                    seq_char = "A";
                    seq_index = 0;
                    break;
                case KBD_DOWN:
                    seq_char = "B";
                    seq_index = 0;
                    break;
                case KBD_RIGHT:
                    seq_char = "C";
                    seq_index = 0;
                    break;
                case KBD_LEFT:
                    seq_char = "D";
                    seq_index = 0;
                    break;
                case KBD_HOME:
                    seq_char = "1~";
                    seq_index = 0;
                    break;
                case KBD_INSERT:
                    seq_char = "2~";
                    seq_index = 0;
                    break;
                case KBD_DELETE:
                    seq_char = "3~";
                    seq_index = 0;
                    break;
                case KBD_END:
                    seq_char = "4~";
                    seq_index = 0;
                    break;
                case KBD_PAGE_UP:
                    seq_char = "5~";
                    seq_index = 0;
                    break;
                case KBD_PAGE_DOWN:
                    seq_char = "6~";
                    seq_index = 0;
                    break;
                case KBD_F1:
                    seq_char = "11~";
                    seq_index = 0;
                    break;
                case KBD_F2:
                    seq_char = "12~";
                    seq_index = 0;
                    break;
                case KBD_F3:
                    seq_char = "13~";
                    seq_index = 0;
                    break;
                case KBD_F4:
                    seq_char = "14~";
                    seq_index = 0;
                    break;
                case KBD_F5:
                    seq_char = "15~";
                    seq_index = 0;
                    break;
                case KBD_F6:
                    seq_char = "17~";
                    seq_index = 0;
                    break;
                case KBD_F7:
                    seq_char = "18~";
                    seq_index = 0;
                    break;
                case KBD_F8:
                    seq_char = "19~";
                    seq_index = 0;
                    break;
                case KBD_F9:
                    seq_char = "20~";
                    seq_index = 0;
                    break;
                case KBD_F10:
                    seq_char = "21~";
                    seq_index = 0;
                    break;
                case KBD_F11:
                    seq_char = "23~";
                    seq_index = 0;
                    break;
                case KBD_F12:
                    seq_char = "24~";
                    seq_index = 0;
                    break;
                case KBD_SCROLL_LOCK:
                    return 0xFF;
            }
        }
    }
    
}