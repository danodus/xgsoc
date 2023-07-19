#include <stdio.h>
#include <stdlib.h>

void main(void)
{
    puts("\e[20h");
    for(;;) {
        char c = getchar();
        char s[16];
        itoa(c, s, 16);
        for (char *s2 = s; *s2; ++s2)
            putchar(*s2);
        putchar(' ');
        if (c == '\n')
            putchar('\n');
        fflush(stdout);
    };
}
