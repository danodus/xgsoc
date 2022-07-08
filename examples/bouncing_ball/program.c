#include <io.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>

#include <xosera.h>

#define WIDTH_A  40
#define HEIGHT_A 30

#define START_B  (WIDTH_A * HEIGHT_A)
#define WIDTH_B  320
#define HEIGHT_B 240

uint16_t tile_mem[] = {
    // 0
    0x8888, 0x8888,
    0x8000, 0x0008,
    0x8000, 0x0008,
    0x8000, 0x0008,
    0x8000, 0x0008,
    0x8000, 0x0008,
    0x8000, 0x0008,
    0x8888, 0x8888,

    // 1
    0x000f, 0xffff,
    0x0ff1, 0x1111,
    0xf111, 0xf111,
    0xf11f, 0x1111,
    0xf111, 0x1111,
    0xf111, 0x1111,
    0xf111, 0x1111,
    0xf111, 0x1111,

    // 2
    0xffff, 0xf000,
    0x1111, 0x1ff0,
    0x1111, 0x111f,
    0x1111, 0x111f,
    0x1111, 0x111f,
    0x1111, 0x111f,
    0x1111, 0x111f,
    0x1111, 0x111f,

    // 3
    0xf111, 0x1111,
    0xf111, 0x1111,
    0xf111, 0x1111,
    0xf111, 0x1111,
    0xf111, 0x1111,
    0xf111, 0x1111,
    0x0ff1, 0x1111,
    0x000f, 0xffff,

    // 4
    0x1111, 0x111f,
    0x1111, 0x111f,
    0x1111, 0x111f,
    0x1111, 0x111f,
    0x1111, 0x111f,
    0x1111, 0x111f,
    0x1111, 0x1ff0,
    0xffff, 0xf000};

void draw_background()
{
    xm_setw(WR_INCR, 0x0001);
    xm_setw(WR_ADDR, 0x0000);

    for (int y = 0; y < HEIGHT_A; ++y)
        for (int x = 0; x < WIDTH_A; ++x)
            xm_setw(DATA, 0x0000);
}

static void draw_pixel(int x, int y, int color)
{
    uint16_t ux = x;
    uint16_t uy = y;
    uint8_t  uc = color;
    if (ux < WIDTH_B && uy < HEIGHT_B)
    {
        uint16_t addr = START_B + (uy * (WIDTH_B / 2)) + (ux / 2);
        xm_setw(WR_ADDR, addr);
        xm_setbl(SYS_CTRL, (ux & 1) ? 0x03 : 0x0C);
        xm_setbh(DATA, uc);
        xm_setbl(DATA, uc);
        xm_setbl(SYS_CTRL, 0x0F);
    }
}

static void draw_sprite(int x, int y, uint16_t * data, bool is_visible)
{
    uint32_t * p = (uint32_t *)data;
    for (int yy = 0; yy < 8; ++yy)
    {
        uint32_t t = (*p << 16) | (*p >> 16);
        for (int xx = 0; xx < 8; ++xx)
        {
            uint8_t v = (t >> 4 * (7 - xx)) & 0xF;
            draw_pixel(x + xx, y + yy, is_visible ? v : 0x00);
        }
        p++;
    }
}

void draw_ball(int x, int y, bool is_visible)
{
    draw_sprite(x, y, tile_mem + 16 * 1, is_visible);
    draw_sprite(x + 8, y, tile_mem + 16 * 2, is_visible);
    draw_sprite(x, y + 8, tile_mem + 16 * 3, is_visible);
    draw_sprite(x + 8, y + 8, tile_mem + 16 * 4, is_visible);
}

void wait_frame()
{
    // TODO
}

void main()
{
    //
    // Playfield A
    //

    xreg_setw(PA_DISP_ADDR, 0x0000);
    xreg_setw(PA_LINE_LEN, WIDTH_A);

    // Set to tiled 4-bpp + Hx2 + Vx2
    xreg_setw(PA_GFX_CTRL, 0x0015);

    // tile height to 8
    xreg_setw(PA_TILE_CTRL, 0x0007);

    //
    // Playfield B
    //

    xreg_setw(PB_DISP_ADDR, START_B);
    xreg_setw(PB_LINE_LEN, WIDTH_B / 2);

    // Set to bitmap 8-bpp + Hx2 + Vx2
    xreg_setw(PB_GFX_CTRL, 0x0065);

    // Clear playfield B

    xm_setw(WR_ADDR, START_B);
    xm_setw(WR_INCR, 1);

    for (int y = 0; y < HEIGHT_B; ++y)
        for (int x = 0; x < WIDTH_B / 2; ++x)
        {
            if (x == 0)
            {
                xm_setw(DATA, 0x0202);
            }
            else if (x == WIDTH_B / 2 - 1)
            {
                xm_setw(DATA, 0x0303);
            }
            else if (y == 0)
            {
                xm_setw(DATA, 0x0404);
            }
            else if (y == HEIGHT_B - 1)
            {
                xm_setw(DATA, 0x0505);
            }
            else
            {
                xm_setw(DATA, 0x0000);
            }
        }

    // Set tiles
    xm_setw(XR_ADDR, XR_TILE_ADDR);
    for (size_t i = 0; i < 4096; ++i)
    {
        if (i < sizeof(tile_mem) / sizeof(uint16_t))
        {
            xm_setw(XR_DATA, tile_mem[i]);
        }
        else
        {
            xm_setw(XR_DATA, 0x0000);
        }
    }

    draw_background();
    int x  = 0;
    int y  = 0;
    int sx = 1;
    int sy = 1;

    while (1)
    {
        wait_frame();

        draw_ball(x, y, false);

        x += sx;
        y += sy;
        if (x < 0)
        {
            x  = 0;
            sx = -sx;
        }
        if (y < 0)
        {
            y  = 0;
            sy = -sy;
        }
        if (x >= WIDTH_B - 16)
        {
            x  = WIDTH_B - 1 - 16;
            sx = -sx;
        }
        if (y >= HEIGHT_B - 16)
        {
            y  = HEIGHT_B - 1 - 16;
            sy = -sy;
        }
        draw_ball(x, y, true);
    }
}