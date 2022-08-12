#include <io.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

#include <xosera.h>
#include <sys.h>
#include <xosera_ansiterm.h>

#define WIDTH 640
#define NB_COLS (WIDTH / 8)
#define NB_LINES 30

void bench_dhry();

void xclear(int c)
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, 0);
    xm_setbh(DATA, 0x07);
    for (int i = 0; i < NB_COLS*30; ++i)
        xm_setbl(DATA, c);
}

void xclear_ansi_stdout(int c)
{
    // Go home
    write(STDOUT_FILENO, "\x1b[H",3);
    for (int i = 0; i < NB_COLS * NB_LINES; ++i)
        write(STDOUT_FILENO, &c, 1);
}

void xclear_ansi_sys(int c)
{
    // Go home
    xansiterm_PRINTCHAR('\x1b');
    xansiterm_PRINTCHAR('[');
    xansiterm_PRINTCHAR('H');
    for (int i = 0; i < NB_COLS * NB_LINES; ++i) {
        xansiterm_PRINTCHAR(c);
    }
}


void xprintxy(unsigned int x, unsigned int y, const char *s, unsigned char color)
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, y * NB_COLS + x);
    unsigned int w = (unsigned int)color << 8;
    for (; *s; ++s) {
        xm_setw(DATA, w | *s);
    }
}

long xosera_clock()
{
    return xm_getw(TIMER);
}

void bench_video_ansi()
{
    // hide cursor
    write(STDOUT_FILENO, "\x1b[?25l", 6);

    int c = 0;
    xreg_setw(PA_GFX_CTRL, 0x0000);
    for(;;) {

        uint16_t t1 = xm_getw(TIMER);

        xclear_ansi_sys(32 + c);  
        c = (c + 1) % 64;

        uint16_t t2 = xm_getw(TIMER);


        uint16_t dt;

        if (t2 >= t1)
        {
            dt = t2 - t1;
        }
        else
        {
            dt = 65535 - t1 + t2;
        }

        float freq = (1.0f * NB_COLS * NB_LINES) / ((float)dt / 10000.0f);

        char s[32];
        itoa((int)freq, s, 10);
        print(s);
        print("\r\n");
    }
}

void main(void)
{
    MEM_WRITE(TIMER_INTR_ENA, 0x0);
    bench_dhry();
    for(;;);
}
