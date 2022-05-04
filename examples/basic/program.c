#include <xio.h>

#include "ubasic.h"

#include <stdlib.h>

#define MAX_PROGRAM_LENGTH    32768

void main(void)
{
    xinit();

    char *program = (char *)malloc(MAX_PROGRAM_LENGTH);
    if (!program) {
        xprint("Out of memory\n");
        exit(1);
    }

    char *p = program;
    size_t program_length = 0;
    for (;;) {

        xprint("OK\n");

        char s[256];
        size_t len = xreadline(s, sizeof(s));
        if (program_length + len >= MAX_PROGRAM_LENGTH - 2) {
            xprint("Not enough memory");
        } else {
            if (len == 3 && s[0] == 'r' && s[1] == 'u' && s[2] == 'n') {
                *p = '\0';

                ubasic_init(program);
                
                do {
                    ubasic_run();
                } while(!ubasic_finished());

                p = program;
                program_length = 0;
            } else if (len > 0) {
                // append the line
                char *s2 = s;
                for (char *s2 = s; *s2; ++s2) {
                    *p = *s2;
                    p++; program_length++; 
                }
                *p = '\n';
                p++; program_length++;
            }
        }
    }

    free(program);
    exit(0);
}
