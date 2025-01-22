#include "vconsole.h"

#include "io.h"
#include "font8x8_basic.h"

#include <stdint.h>

#define BASE_VIDEO 0x1000000

static int g_hres, g_vres;
static int g_col = 0, g_line = 0;

static void flush_cache(void)
{
    // Flush cache
    MEM_WRITE(CONFIG, 0x1);
}

static void clear_fb(int color)
{
    uint32_t *fb = (uint32_t *)BASE_VIDEO;
    uint32_t c = color << 16 | color;
    for (int y = 0; y < g_vres; y++)
        for (int x = 0; x < g_hres / 2; x++) {
            *fb = c;
            fb++;
        }

    flush_cache();
}

static inline void draw_pixel(int x, int y, int color)
{
    uint16_t *fb = (uint16_t *)BASE_VIDEO;
    if (x >= 0 && y >= 0 && x < g_hres && y < g_vres)
        fb[y * g_hres + x] = (uint16_t)color;
}

static void render(int x, int y, char *bitmap, int color)
{
    int xx, yy;
    int set;

    yy = y;
    for (int line = 0; line < 8; line++) {
        xx = x;
        for (int col = 0; col < 8; col++) {
            set = bitmap[line] & 1 << col;
            draw_pixel(xx, yy, set ? color : 0);
            xx++;
        }
        yy++;
    }
}

static void printc(char c)
{
    if (g_line >= g_vres / 8) {
        // TODO: scroll
        g_line = 0;
    }

    if (c == '\n') {
        g_col = 0;
        g_line++;
    } else {
        if (g_col >= g_hres / 8) {
            g_col = 0;
            g_line++;
        }
        render(g_col*8, g_line*8, font8x8_basic[c], 0xFFFF);
        g_col++;
    }
}

void vconsole_init(void)
{
    unsigned int res = MEM_READ(CONFIG);
    g_hres = res >> 16;
    g_vres = res & 0xffff;
    vconsole_clear();
}

void vconsole_clear(void)
{
    clear_fb(0);
}

void vconsole_printc(char c)
{
    if (c == '\b') {
        
    } else {
        printc(c);
    }
    flush_cache();
}

void vconsole_print(const char *str)
{
    while (*str) {
        printc(*str);
        str++;
    }
    flush_cache();
}
