#include "xio.h"

#include <xosera.h>
#include <kbd.h>

#define SCREEN_WIDTH 640
#define NB_COLS (SCREEN_WIDTH / 8)
#define NB_LINES 30

static int g_cursor_x = 0;
static int g_cursor_y = 0;

void xclear();
void xprint_cursor(int visible);

void xinit()
{
    xreg_setw(PA_GFX_CTRL, 0x0000);
    xclear();
    xprint_cursor(1);
}

void xclear()
{
    xprint_cursor(0);
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, 0);
    for (int i = 0; i < NB_COLS*NB_LINES; ++i)
        xm_setw(DATA, 0x0100 | ' ');
    g_cursor_x = 0;
    g_cursor_y = 0;
    xprint_cursor(1);
}

void xprint_cursor(int visible)
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, g_cursor_y * NB_COLS + g_cursor_x);
    xm_setw(DATA, (visible ? 0xF000 : 0x0F00) | ' ');
}

void xscroll()
{
    for (int y = 1; y < NB_LINES; ++y) {
        for (int x = 0; x < NB_COLS; ++x) {
            xm_setw(RD_ADDR, y*NB_COLS+x);
            xm_setw(WR_ADDR, (y-1)*NB_COLS+x);
            unsigned int d = xm_getw(DATA);
            xm_setw(DATA, d);
        }
    }

    // Clear last line
    xm_setw(WR_INCR, 1);
    xm_setw(WR_ADDR, (NB_LINES - 1) * NB_COLS);
    for (int x = 0; x < NB_COLS; ++x)
        xm_setw(DATA, 0x0100 | ' ');
}

void xprint_chr_xy(int x, int y, char c)
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, y * NB_COLS + x);
    xm_setw(DATA, 0x0F00 | c);
}

void xprint_chr(char c)
{
    xprint_cursor(0);
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

        if (g_cursor_y > NB_LINES - 1) {
            xscroll();
            g_cursor_x = 0;
            g_cursor_y = NB_LINES - 1;
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
    xprint_cursor(1);
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

static char g_getchar_buf[128] = {'\0'};
int getchar()
{
    // if buffer empty
    if (g_getchar_buf[0] == '\0') {
        // read line
        int len = xreadline(g_getchar_buf, 128 - 1);
        // append '\n'
        g_getchar_buf[len] = '\n';
        g_getchar_buf[len + 1] = '\0';
    }

    // get character in buffer
    char c = g_getchar_buf[0];

    // shift buffer left
    for (int i = 0; ; ++i) {
        g_getchar_buf[i] = g_getchar_buf[i + 1];
        if (g_getchar_buf[i] == '\0')
            break;
    }

    return (int)c;
}

int putchar(int character)
{
    xprint_chr((char)character);
}
