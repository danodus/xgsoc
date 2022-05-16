#include <io.h>
#include <stdint.h>

#include <xosera.h>

#define WIDTH 640
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

static void test_audio_sample(int8_t * samp, int bytesize, int speed)
{
    xm_setw(WR_INCR, 0x0001);
    xm_setw(WR_ADDR, 0x8000);
    xm_setw(SYS_CTRL, 0x000F);
    xreg_setw(AUD0_VOL, 0x0000);           // set volume to 0%
    xreg_setw(AUD0_PERIOD, 0x0000);        // 1000 clocks per each sample byte
    xreg_setw(AUD0_LENGTH, 0x0000);        // 1000 clocks per each sample byte

    for (int i = 0; i < bytesize; i += 2)
    {
        uint8_t s0 = (uint8_t)(*samp++);
        uint8_t s1 = (uint8_t)(*samp++);
        uint16_t s = s0 << 8 | s1;
        xm_setw(DATA, s);
    }

    uint16_t p  = speed;
    uint8_t  lv = 0x80;
    uint8_t  rv = 0x80;

    xreg_setw(AUD0_PERIOD, p);                         // 1000 clocks per each sample byte
    xreg_setw(AUD0_START, 0x8000);                     // address in VRAM
    xreg_setw(AUD0_LENGTH, (bytesize / 2) - 1);        // length in words (256 8-bit samples)
    xreg_setw(AUD0_VOL, lv << 8 | rv);                 // set left 100% volume, right 50% volume
    xreg_setw(VID_CTRL, 0x0010);                       // enable audio DMA to start playing
}

void main(void)
{
    print("Xosera Test\r\n");

    xreg_setw(PA_GFX_CTRL, 0x0000);

    xclear();

    xprint(5, 1, " RISC-V/Xosera ", WHITE);

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

    test_audio_sample(g_sin_data, sizeof(g_sin_data), 1000);

    for (;;) {
        uint16_t tv = xm_getw(TIMER);
        char s[32];
        itoa(tv, s, 16);
        xprint(0, 29, "          ", WHITE);
        xprint(0, 29, s, WHITE);
    }
}
