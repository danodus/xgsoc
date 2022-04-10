// Ref.: https://gist.github.com/mifritscher/fe8058a9ec294522a88d3d62fb9f6498

#include "io.h"

#define PS2_KBD_STATUS  0x20005000
#define PS2_KBD_CODE    0x20005004

#define KEYMAP_SIZE 132
static const char g_keymap[] = 
// Without shift
"             \011`      q1   zsaw2  cxde43   vftr5  nbhgy6   mju78  ,kio09"
"  ./l;p-   \' [=    \015] \\        \010  1 47   0.2568\033  +3-*9      "
// With shift
"             \011~      Q!   ZSAW@  CXDE$#   VFTR%  NBHGY^   MJU&*  <KIO)("
"  >?L:P_   \" {+    \015} |        \010  1 47   0.2568\033  +3-*9       ";

char getch()
{
    static int brk = 0, modifier = 0, shift = 0;

    for (;;) {
        // if character available
        unsigned int status = MEM_READ(PS2_KBD_STATUS);
        if (status & 0x1) {
            // dequeue from FIFO
            MEM_WRITE(PS2_KBD_STATUS, 0x1);

            // read character
            unsigned int code = MEM_READ(PS2_KBD_CODE);

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
                }
                brk = 0;
                modifier = 0;
                continue;
            }
            if ((code == 0x12) || (code == 0x59)) {
                shift = 1;
                continue;
            }
            if (modifier) {
                continue;
            }
            
            char c = 0;
            if (code < KEYMAP_SIZE)
                c = g_keymap[code + KEYMAP_SIZE * shift];
            return c;
        } 
    }
}