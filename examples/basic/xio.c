#include "xio.h"

#include <xosera.h>
#include <kbd.h>

#define SCREEN_WIDTH 848
#define NB_COLS (SCREEN_WIDTH / 8)

int g_cursor_x = 0;
int g_cursor_y = 0;

void xclear();

void xinit()
{
    xreg_setw(PA_GFX_CTRL, 0x0000);
    xclear();
}

void xclear()
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, 0);
    for (int i = 0; i < NB_COLS*30; ++i)
        xm_setw(DATA, 0x0100 | ' ');
    g_cursor_x = 0;
    g_cursor_y = 0;
}

void xscroll()
{
    g_cursor_x = 0;
    g_cursor_y = 0;
}

void xprint_chr(char c)
{
    if (c == '\n') {
        g_cursor_x = 0;
        g_cursor_y++;
    }

    if (g_cursor_y >= 29) {
        xscroll();
        g_cursor_x = 0;
    }

    if (c != '\r' && c != '\n') {
        xm_setw(WR_INCR, 1);    
        xm_setw(WR_ADDR, g_cursor_y * NB_COLS + g_cursor_x);
        xm_setw(DATA, 0x0F00 | c);

        g_cursor_x++;
        if (g_cursor_x > 79) {
            g_cursor_x = 0;
            g_cursor_y++;
        }
    }
}

void xprint(const char *s)
{
    while (*s) {
        xprint_chr(*s);
        s++;
    }
}

size_t xreadline(char *s, size_t buffer_len)
{
    size_t len = 0;
    while(len < buffer_len - 1) {
        char c = getch();
        if (c == '\r') {
            xprint_chr('\n');
            *s = '\0';
            return len;
        }
        xprint_chr(c);
        *s = c;
        s++;
        len++;
    }

    *s = '\0';
    return len;
}