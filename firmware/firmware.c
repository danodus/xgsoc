
#define DISPLAY         0x00001000
#define UART_DATA       0x00002000
#define UART_STATUS     0x00002004

#define REG_WRITE(_reg_, _value_) (*((volatile unsigned int *)(_reg_)) = _value_)
#define REG_READ(_reg_)           (*((volatile unsigned int *)(_reg_)))

const char *hello = "Hello, world!\r\n";

char s[32];

void main(void)
{
    unsigned int counter = 0;
    unsigned int c;

    const char *s2 = hello;
    char *sd = s;
    while (*s2) {
        *sd = *s2;
        sd++;
        s2++;
    }
    *sd = 0;

    for (;;) {
        const char *s2 = s;
        while (*s2) {
            
            while(REG_READ(UART_STATUS) & 1);
            REG_WRITE(UART_DATA, *s2);
            s2++;

            REG_WRITE(DISPLAY, counter >> 10);
            counter++;
        }
    }

/*
    // Echo test
    for (;;) {
        // wait until valid character available
        while(!(REG_READ(UART_STATUS) & 2));

        unsigned int c = REG_READ(UART_DATA);

        while(REG_READ(UART_STATUS) & 1);
        REG_WRITE(UART_DATA, c);
    }
*/

}
