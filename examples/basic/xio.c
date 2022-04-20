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

void xprint_chr_xy(int x, int y, char c)
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, y * NB_COLS + x);
    xm_setw(DATA, 0x0F00 | c);
}

void xprint_chr(char c)
{
    if (c == '\b') {
        // Backspace
        
        if (g_cursor_x == 0) {
            if (g_cursor_y > 0) {
                g_cursor_y--;
                g_cursor_x = NB_COLS - 1;
            }
        } else {
            g_cursor_x--;
        }

        xprint_chr_xy(g_cursor_x, g_cursor_y, ' ');
    } else {
        if (c == '\n') {
            g_cursor_x = 0;
            g_cursor_y++;
        }

        if (g_cursor_y >= 29) {
            xscroll();
            g_cursor_x = 0;
        }

        if (c != '\r' && c != '\n') {
            xprint_chr_xy(g_cursor_x, g_cursor_y, c);

            g_cursor_x++;
            if (g_cursor_x > NB_COLS - 1) {
                g_cursor_x = 0;
                g_cursor_y++;
            }
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
        if (c == '\b') {
            if (len > 0) {
                s--;
                *s = '\0';
                len--;
                xprint_chr(c);
            }
        } else if (c == '\r') {
            xprint_chr('\n');
            *s = '\0';
            return len;
        } else {
            xprint_chr(c);
            *s = c;
            s++;
            len++;
        }
    }

    *s = '\0';
    return len;
}