// Ref.: https://gist.github.com/mifritscher/fe8058a9ec294522a88d3d62fb9f6498

#include "kbd.h"

#include "io.h"

#define KEYMAP_SIZE 132
static const char g_keymap[] = 
// Without shift or control
"             \x09""`      q1   zsaw2  cxde43   vftr5  nbhgy6   mju78  ,kio09"
"  ./l;p-   \' [=    \x0D""] \\        \x08""  1 47   0.2568\x1B""  +3-*9      "
// With shift
"             \x09""~      Q!   ZSAW@  CXDE$#   VFTR%  NBHGY^   MJU&*  <KIO)("
"  >?L:P_   \" {+    \x0D""} |        \x08""  1 47   0.2568\x1B""  +3-*9      "
// With control
"             \x09""`      \x11""1   \x1A""\x13""\x01""\x17""2  \x03""\x18""\x04""\x05""43  \x00""\x16""\x06""\x14""\x12""5  \x0E""\x02""\x08""\x07""\x19""6   \x0D""\x0A""\x15""78  ,\x0B""\x09""\x0F""09"
"  ./\x0C"";\x10""-   \' \x1B""=    \x0D""\x1D"" \x1C""        \x08""  1 47   0.2568\x1B""  +3-*9      "
// With control and shift
"             \x09""`      \x11""1   \x1A""\x13""\x01""\x17""\x00""  \x03""\x18""\x04""\x05""43   \x16""\x06""\x14""\x12""5  \x0E""\x02""\x08""\x07""\x19""\x1E""   \x0D""\x0A""\x15""78  ,\x0B""\x09""\x0F""09"
"  ./\x0C"";\x10""\x1F""   \' [=    \x0D""] \\        \x08""  1 47   0.2568\x1B""  +3-*9      "
;

uint16_t kbd_get_char(bool is_blocking)
{
    static int brk = 0, modifier = 0, shift = 0, control = 0;

    for (;;) {
        // if character available
        unsigned int status = MEM_READ(PS2_KBD_STATUS);
        if (status & 0x1) {
            // read character
            unsigned int code = MEM_READ(PS2_KBD_DATA);

            if (code == 0xAA) { // BAT completion code
                continue; 
            }
            if (code == 0xF0) {
                brk = 1;
                continue;
            }
            if (code == 0xE0) {
                modifier = 1;
                continue;
            }
            if (brk) {
                if ((code == 0x12) || (code == 0x59)) {
                    shift = 0;
                } else if (code == 0x14)
                    control = 0;
                brk = 0;
                modifier = 0;
                continue;
            }
            if ((code == 0x12) || (code == 0x59)) {
                // left of right shift
                shift = 1;
                brk = 0;
                modifier = 0;
                continue;
            }
            if (code == 0x14) {
                // left or right control
                control = 1;
                brk = 0;
                modifier = 0;
                continue;
            }
            
            if (modifier)
                return 0x8000 | (uint16_t)code;

            // function keys
            if (code == 0x05 ||
                code == 0x06 ||
                code == 0x04 ||
                code == 0x0C ||
                code == 0x03 ||
                code == 0x0B ||
                code == 0x83 ||
                code == 0x0A ||
                code == 0x01 ||
                code == 0x09 ||
                code == 0x78 ||
                code == 0x07 ||
                code == 0x7E)
                return 0x8100 | (uint16_t)code;

            char c = 0;
            if (code < KEYMAP_SIZE)
                c = g_keymap[code + KEYMAP_SIZE * (control << 1 | shift)];
            return (uint16_t)c;
        } else {
            if (!is_blocking)
                break;
        }
    }

    // no character available
    return 0;
}