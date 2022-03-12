#include <math.h>

#define DISPLAY         0x20001000
#define UART_DATA       0x20002000
#define UART_STATUS     0x20002004

#define MEM_WRITE(_addr_, _value_) (*((volatile unsigned int *)(_addr_)) = _value_)
#define MEM_READ(_addr_)           (*((volatile unsigned int *)(_addr_)))

void print(const char *s)
{
    while (*s) {
        
        while(MEM_READ(UART_STATUS) & 1);
        MEM_WRITE(UART_DATA, *s);
        s++;
    }
}

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