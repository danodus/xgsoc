
#define DISPLAY         0x20001000
#define UART_DATA       0x20002000
#define UART_STATUS     0x20002004

#define MEM_WRITE(_addr_, _value_) (*((volatile unsigned int *)(_addr_)) = _value_)
#define MEM_READ(_addr_)           (*((volatile unsigned int *)(_addr_)))

const char *hello = "Hello, world!\r\n";

void main(void)
{
    unsigned int counter = 0;

    for (;;) {
        const char *s = hello;
        while (*s) {
            
            while(MEM_READ(UART_STATUS) & 1);
            MEM_WRITE(UART_DATA, *s);
            s++;

            MEM_WRITE(DISPLAY, counter >> 10);
            counter++;
        }
    }
}
