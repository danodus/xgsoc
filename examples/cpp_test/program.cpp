#include <io.h>
#include <stdint.h>

#include <xosera.h>

#include <string>
#include <vector>

#define WIDTH 640
#define NB_COLS (WIDTH / 8)

void xclear()
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, 0);
    for (int i = 0; i < NB_COLS*30; ++i)
        xm_setw(DATA, 0x0100 | '*');
}

void xprint(unsigned int x, unsigned int y, const char *s)
{
    xm_setw(WR_INCR, 1);    
    xm_setw(WR_ADDR, y * NB_COLS + x);
    for (; *s; ++s) {
        xm_setw(DATA, 0x0F00 | *s);
    }
}

int main(void)
{
    xreg_setw(PA_GFX_CTRL, 0x0000);

    xclear();

    std::vector<std::string> v;
    v.push_back("This is a string");
    v.push_back("This is another string");

    int y = 10;
    for (auto s : v)
        xprint(15, y++, s.c_str());

    for (;;);

    return 0;
}
