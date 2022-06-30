#include "xio.h"

#include "xosera_ansiterm.h"

void xinit()
{
    xansiterm_INIT();
}

void xprint_chr(char c)
{
    if (c == '\n')
        xansiterm_PRINTCHAR('\r');
    xansiterm_PRINTCHAR(c);
    xansiterm_UPDATECURSOR();
}

void xprint(const char *s)
{
    xansiterm_PRINT(s);
    xansiterm_UPDATECURSOR();
}
