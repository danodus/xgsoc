#include <math.h>
#include <io.h>

void main(void)
{
    for(float angle = 0; angle < 2.0f * M_PI; angle += 0.1f) {
        int z = sinf(angle) * 40.0f;
        for (int i = 0; i < 40 - z; i++)
            print(" ");
        print("*\r\n");
    }
    print("\r\n");
}