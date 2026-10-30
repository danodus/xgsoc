// program.c
// Copyright (c) 2026 Daniel Cliche
// SPDX-License-Identifier: MIT

#include <io.h>

#define BASE_VIDEO 0x1000000

// 2^32 * Hz / 48000
#define PHASE_440 39370534u
#define PHASE_880 78741067u

static short sine_sample(unsigned int phase)
{
    unsigned int i = phase >> 24;
    unsigned int idx = i & 63;
    unsigned int mag = (i & 64) ? (63 - idx) : idx;
    short s = (short)(mag << 9);
    if (i & 128)
        s = -s;
    return s >> 4;
}

#define GREEN 0x07e0u
#define BORDER 8

static unsigned int bar_word(int x, int words)
{
    static const unsigned int colors[8] = {
        0xf800, 0xffe0, 0x07e0, 0x07ff,
        0x001f, 0xf81f, 0xffff, 0x0000
    };
    unsigned int c = colors[(x * 8) / words];
    return (c << 16) | c;
}

static int on_border(int x, int y, int words, int vres)
{
    int side = BORDER / 2;
    return y < BORDER || y >= vres - BORDER || x < side || x >= words - side;
}

void main(void)
{
    unsigned int res = MEM_READ(CONFIG);
    int hres = res >> 16;
    int vres = res & 0xffff;
    int words = hres / 2;

    if (words < 1)
        words = 1;

    for (int y = 0; y < vres; ++y) {
        for (int x = 0; x < words; ++x) {
            unsigned int i = y * (hres * 2) + x * 4;
            unsigned int word = on_border(x, y, words, vres) ? ((GREEN << 16) | GREEN) : bar_word(x, words);
            MEM_WRITE(BASE_VIDEO + i, word);
        }
    }
    MEM_WRITE(CONFIG, 1);

    print("test_audio: 440 Hz left, 880 Hz right\r\n");
    MEM_WRITE(LED, 1);

    unsigned int phase_l = 0;
    unsigned int phase_r = 0;
    for (;;) {
        if (MEM_READ(PCM) & 1) {
            unsigned int left = (unsigned short)sine_sample(phase_l);
            unsigned int right = (unsigned short)sine_sample(phase_r);
            MEM_WRITE(PCM, (right << 16) | left);
            phase_l += PHASE_440;
            phase_r += PHASE_880;
        }
    }
}
