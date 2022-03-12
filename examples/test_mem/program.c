
#define DISPLAY         0x20001000
#define UART_DATA       0x20002000
#define UART_STATUS     0x20002004

#define MEM_WRITE(_addr_, _value_) (*((volatile unsigned int *)(_addr_)) = _value_)
#define MEM_READ(_addr_)           (*((volatile unsigned int *)(_addr_)))

int test_mem(void) {
    for (unsigned int i = 0x10001000; i < 0x10001100; i++) {
        MEM_WRITE(i, 0x12345678);
        if (MEM_READ(i) != 0x12345678)
            return 0;
    }
    return 1;
}

void main(void)
{
    MEM_WRITE(DISPLAY, 0x00);
    if (!test_mem()) {
        // failure
        MEM_WRITE(DISPLAY, 0x01);
    } else {
        // success
        MEM_WRITE(DISPLAY, 0x1E);
    }
}
