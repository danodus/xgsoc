#include <sys.h>
#include <io.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

#include <xosera.h>

#define WIDTH 848
#define HEIGHT 480
#define NB_COLS (WIDTH / 8)

#define BLACK           0x0
#define BLUE            0x1
#define GREEN           0x2
#define CYAN            0x3
#define RED             0x4
#define MAGENTA         0x5
#define BROWN           0x6
#define WHITE           0x7
#define GRAY            0x8
#define LIGHT_BLUE      0x9
#define LIGHT_GREEN     0xA
#define LIGHT_CYAN      0xB
#define LIGHT_RED       0xC
#define LIGHT_MAGENTA   0xD
#define YELLOW          0xE
#define BRIGHT_WHITE    0xF

extern void xosera_irq_handler();
extern volatile unsigned int frame_counter;

void xclear()
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, 0);
    for (int i = 0; i < NB_COLS*30; ++i)
        xm_setw(DATA, 0x0100 | '*');
}

void xprint(unsigned int x, unsigned int y, const char *s, unsigned char color)
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, y * NB_COLS + x);
    unsigned int w = (unsigned int)color << 8;
    for (; *s; ++s) {
        xm_setw(DATA, w | *s);
    }
}

static int8_t g_sin_data[256] = {
    0,           // 0
    3,           // 1
    6,           // 2
    9,           // 3
    12,          // 4
    15,          // 5
    18,          // 6
    21,          // 7
    24,          // 8
    27,          // 9
    30,          // 10
    33,          // 11
    36,          // 12
    39,          // 13
    42,          // 14
    45,          // 15
    48,          // 16
    51,          // 17
    54,          // 18
    57,          // 19
    59,          // 20
    62,          // 21
    65,          // 22
    67,          // 23
    70,          // 24
    73,          // 25
    75,          // 26
    78,          // 27
    80,          // 28
    82,          // 29
    85,          // 30
    87,          // 31
    89,          // 32
    91,          // 33
    94,          // 34
    96,          // 35
    98,          // 36
    100,         // 37
    102,         // 38
    103,         // 39
    105,         // 40
    107,         // 41
    108,         // 42
    110,         // 43
    112,         // 44
    113,         // 45
    114,         // 46
    116,         // 47
    117,         // 48
    118,         // 49
    119,         // 50
    120,         // 51
    121,         // 52
    122,         // 53
    123,         // 54
    123,         // 55
    124,         // 56
    125,         // 57
    125,         // 58
    126,         // 59
    126,         // 60
    126,         // 61
    126,         // 62
    126,         // 63
    127,         // 64
    126,         // 65
    126,         // 66
    126,         // 67
    126,         // 68
    126,         // 69
    125,         // 70
    125,         // 71
    124,         // 72
    123,         // 73
    123,         // 74
    122,         // 75
    121,         // 76
    120,         // 77
    119,         // 78
    118,         // 79
    117,         // 80
    116,         // 81
    114,         // 82
    113,         // 83
    112,         // 84
    110,         // 85
    108,         // 86
    107,         // 87
    105,         // 88
    103,         // 89
    102,         // 90
    100,         // 91
    98,          // 92
    96,          // 93
    94,          // 94
    91,          // 95
    89,          // 96
    87,          // 97
    85,          // 98
    82,          // 99
    80,          // 100
    78,          // 101
    75,          // 102
    73,          // 103
    70,          // 104
    67,          // 105
    65,          // 106
    62,          // 107
    59,          // 108
    57,          // 109
    54,          // 110
    51,          // 111
    48,          // 112
    45,          // 113
    42,          // 114
    39,          // 115
    36,          // 116
    33,          // 117
    30,          // 118
    27,          // 119
    24,          // 120
    21,          // 121
    18,          // 122
    15,          // 123
    12,          // 124
    9,           // 125
    6,           // 126
    3,           // 127
    0,           // 128
    -3,          // 129
    -6,          // 130
    -9,          // 131
    -12,         // 132
    -15,         // 133
    -18,         // 134
    -21,         // 135
    -24,         // 136
    -27,         // 137
    -30,         // 138
    -33,         // 139
    -36,         // 140
    -39,         // 141
    -42,         // 142
    -45,         // 143
    -48,         // 144
    -51,         // 145
    -54,         // 146
    -57,         // 147
    -59,         // 148
    -62,         // 149
    -65,         // 150
    -67,         // 151
    -70,         // 152
    -73,         // 153
    -75,         // 154
    -78,         // 155
    -80,         // 156
    -82,         // 157
    -85,         // 158
    -87,         // 159
    -89,         // 160
    -91,         // 161
    -94,         // 162
    -96,         // 163
    -98,         // 164
    -100,        // 165
    -102,        // 166
    -103,        // 167
    -105,        // 168
    -107,        // 169
    -108,        // 170
    -110,        // 171
    -112,        // 172
    -113,        // 173
    -114,        // 174
    -116,        // 175
    -117,        // 176
    -118,        // 177
    -119,        // 178
    -120,        // 179
    -121,        // 180
    -122,        // 181
    -123,        // 182
    -123,        // 183
    -124,        // 184
    -125,        // 185
    -125,        // 186
    -126,        // 187
    -126,        // 188
    -126,        // 189
    -126,        // 190
    -126,        // 191
    -127,        // 192
    -126,        // 193
    -126,        // 194
    -126,        // 195
    -126,        // 196
    -126,        // 197
    -125,        // 198
    -125,        // 199
    -124,        // 200
    -123,        // 201
    -123,        // 202
    -122,        // 203
    -121,        // 204
    -120,        // 205
    -119,        // 206
    -118,        // 207
    -117,        // 208
    -116,        // 209
    -114,        // 210
    -113,        // 211
    -112,        // 212
    -110,        // 213
    -108,        // 214
    -107,        // 215
    -105,        // 216
    -103,        // 217
    -102,        // 218
    -100,        // 219
    -98,         // 220
    -96,         // 221
    -94,         // 222
    -91,         // 223
    -89,         // 224
    -87,         // 225
    -85,         // 226
    -82,         // 227
    -80,         // 228
    -78,         // 229
    -75,         // 230
    -73,         // 231
    -70,         // 232
    -67,         // 233
    -65,         // 234
    -62,         // 235
    -59,         // 236
    -57,         // 237
    -54,         // 238
    -51,         // 239
    -48,         // 240
    -45,         // 241
    -42,         // 242
    -39,         // 243
    -36,         // 244
    -33,         // 245
    -30,         // 246
    -27,         // 247
    -24,         // 248
    -21,         // 249
    -18,         // 250
    -15,         // 251
    -12,         // 252
    -9,          // 253
    -6,          // 254
    -4,          // 255
};

static void play_audio_sample(int8_t * samp, int bytesize, int speed)
{
    uint16_t test_vaddr = 0x8000;
    xreg_setw(AUD0_VOL, 0x0000);           // set volume to 0%
    xreg_setw(AUD0_PERIOD, 0x0000);        // 1000 clocks per each sample byte
    xreg_setw(AUD0_LENGTH, 0x0000);        // 1000 clocks per each sample byte
    xreg_setw(AUD_CTRL, 0x0001);           // enable audio DMA to start playing

    xm_setw(SYS_CTRL, 0x000F);        // make sure no nibbles masked

    xm_setw(WR_INCR, 0x0001);            // set write increment
    xm_setw(WR_ADDR, test_vaddr);        // set write address

    for (int i = 0; i < bytesize; i += 2)
    {
        xm_setbh(DATA, *samp++);
        xm_setbl(DATA, *samp++);
    }

    uint16_t p  = speed;
    uint8_t  lv = 0x40;
    uint8_t  rv = 0x40;

    xreg_setw(AUD0_VOL, lv << 8 | rv);                 // set left 100% volume, right 50% volume
    xreg_setw(AUD0_PERIOD, p);                         // 1000 clocks per each sample byte
    xreg_setw(AUD0_START, test_vaddr);                 // address in VRAM
    xreg_setw(AUD0_LENGTH, (bytesize / 2) - 1);        // length in words (256 8-bit samples)
}

void wait_vsync()
{
    unsigned fc = frame_counter;
    while (frame_counter == fc);
}

void wait_blit_done() {
    uint16_t v;
    do {
      v = xm_getw(SYS_CTRL);
    } while ((v & 0x2000) != 0x0000);
}

// slightly optimized version ~20% faster
void line_draw(int16_t x1, int16_t y1, int16_t x2, int16_t y2, uint16_t color)
{
    int16_t x = x1, y = y1;
    int16_t d;
    int16_t a = x2 - x1, b = y2 - y1;
    int16_t dx_diag, dy_diag;
    int16_t dx_nondiag, dy_nondiag;
    int16_t inc_nondiag, inc_diag;

    // always draw first pixel, and this sets up full data word and latch
    xm_setw(PIXEL_X, x);
    xm_setw(PIXEL_Y, y);
    xm_setw(DATA, color);

    if (a < 0)
    {
        a       = -a;
        dx_diag = -1;
    }
    else
    {
        dx_diag = 1;
    }

    if (b < 0)
    {
        b       = -b;
        dy_diag = -1;
    }
    else
    {
        dy_diag = 1;
    }

    // instead of swapping for one loop, have x major and y major loops
    // remove known zero terms
    if (a < b)
    {
        dy_nondiag = dy_diag;

        d           = a + a - b;
        inc_nondiag = a + a;
        inc_diag    = a + a - b - b;

        // start count at one (drew one pixel already )
        for (int16_t i = 1; i <= b; i++)
        {
            if (d < 0)
            {
                y += dy_nondiag;
                d += inc_nondiag;
                // x not changing, don't need to set it
                xm_setw(PIXEL_Y, y);
                xm_setbl(DATA, color);        // we can get away with bl here, since upper byte is latched
            }
            else
            {
                x += dx_diag;
                y += dy_diag;
                d += inc_diag;
                xm_setw(PIXEL_X, x);
                xm_setw(PIXEL_Y, y);
                xm_setbl(DATA, color);        // we can get away with bl here, since upper byte is latched
            }
        }
    }
    else
    {
        dx_nondiag = dx_diag;

        d           = b + b - a;
        inc_nondiag = b + b;
        inc_diag    = b + b - a - a;

        // start count at one (drew one pixel already )
        for (int16_t i = 1; i <= a; i++)
        {
            if (d < 0)
            {
                x += dx_nondiag;
                d += inc_nondiag;
                // y not changing, don't need to set it
                xm_setw(PIXEL_X, x);
                xm_setbl(DATA, color);        // we can get away with bl here, since upper byte is latched
            }
            else
            {
                x += dx_diag;
                y += dy_diag;
                d += inc_diag;
                xm_setw(PIXEL_X, x);
                xm_setw(PIXEL_Y, y);
                xm_setbl(DATA, color);        // we can get away with bl here, since upper byte is latched
            }
        }
    }
}

void test_line_draw()
{
    xreg_setw(PA_GFX_CTRL, 0x0055);
    xreg_setw(PA_LINE_LEN, WIDTH / 8);

    // clear playfield B

    xreg_setw(BLIT_CTRL, 0x0001);
    xreg_setw(BLIT_SRC_S, 0x0000);
    xreg_setw(BLIT_MOD_D, 0x0000);
    xreg_setw(BLIT_DST_D, 0x0000);
    xreg_setw(BLIT_SHIFT, 0xFF00);
    xreg_setw(BLIT_LINES, HEIGHT / 2 - 1);
    xreg_setw(BLIT_WORDS, WIDTH / 8 - 1);
    wait_blit_done();    

    xm_setw(WR_INCR, 0);
    uint16_t color = 0xFFFF;

    // init
    xm_setw(PIXEL_X, 0x0000);         // base VRAM address
    xm_setw(PIXEL_Y, WIDTH / 8);      // words per line
    xm_setbh(SYS_CTRL, 0x00);         // set PIXEL_BASE and PIXEL_WIDTH for 4-bpp

    for (uint16_t x = 0; x < WIDTH / 4; x += 8) {
        line_draw(x, 0, WIDTH / 2 - x - 1, HEIGHT / 2 - 1, color);
        line_draw(WIDTH / 2 - x - 1, 0, x, HEIGHT / 2 - 1, color);
        color = (color == 0xFFFF) ? 0 : color + 0x1111;
    }

    for (int i = 0; i < 300; ++i)
        wait_vsync();
}

void test_text(void)
{
    xreg_setw(PA_GFX_CTRL, 0x0000);
    xreg_setw(PA_TILE_CTRL, 0x000F); // 8x16 tiles @ tilemem 0x0000
    xreg_setw(PA_LINE_LEN, WIDTH / 8);
    xm_setw(SYS_CTRL, 0x000F);        // make sure no nibbles masked

    
    xclear();

    xprint(5, 1, " Xosera ", WHITE);

    xprint(5, 6,  " BLACK   ", BLACK);
    xprint(5, 7,  " BLUE    ", BLUE);
    xprint(5, 8,  " GREEN   ", GREEN);
    xprint(5, 9,  " CYAN    ", CYAN);
    xprint(5, 10, " RED     ", RED);
    xprint(5, 11, " MAGENTA ", MAGENTA);
    xprint(5, 12, " BROWN   ", BROWN);
    xprint(5, 13, " WHITE   ", WHITE);

    xprint(20, 6, " GRAY          ", GRAY);
    xprint(20, 7, " LIGHT BLUE    ", LIGHT_BLUE);
    xprint(20, 8, " LIGHT GREEN   ", LIGHT_GREEN);
    xprint(20, 9, " LIGHT CYAN    ", LIGHT_CYAN);
    xprint(20, 10," LIGHT RED     ", LIGHT_RED);
    xprint(20, 11," LIGHT MAGENTA ", LIGHT_MAGENTA);
    xprint(20, 12," YELLOW        ", YELLOW);
    xprint(20, 13," BRIGHT WHITE  ", BRIGHT_WHITE);

    for (int i = 0; i < 300; ++i) {
        wait_vsync();

        uint16_t tv = xm_getw(TIMER);
        char s[32];
        itoa(tv, s, 16);
        xprint(0, 29, "          ", WHITE);
        xprint(0, 29, s, WHITE);

        itoa(frame_counter, s, 10);
        xprint(0, 28, "          ", WHITE);
        xprint(0, 28, s, WHITE);

        itoa(clock() / CLOCKS_PER_SEC, s, 10);
        xprint(0, 27, "          ", WHITE);
        xprint(0, 27, s, WHITE);
    }
}

void main(void)
{
    print("Xosera Test\r\n");

    // enable Xosera interrupts for VSYNC
    irq1_handler = &xosera_irq_handler;
    xm_setw(INT_CTRL, 0x1010);
    xreg_setw(VID_RIGHT, WIDTH);

    xreg_setw(PB_GFX_CTRL, 0x0080); // blank pb

    play_audio_sample(g_sin_data, sizeof(g_sin_data), 1000);

    for (;;) {

        test_text();
        test_line_draw();
    }
}
