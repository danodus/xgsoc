#include <stdio.h>
#include <stdlib.h>

void main(void)
{
    for(;;) {
        char c = getchar();
        if (c) {
            char s[16];
            itoa(c, s, 16);
            for (char *s2 = s; *s2; ++s2)
                putchar(*s2);
            putchar(' ');
        }
        if (c == '\n')
            putchar('\n');
        fflush(stdout);
    };
}
