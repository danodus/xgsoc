
#define DISPLAY         0x20001000
#define UART_DATA       0x20002000
#define UART_STATUS     0x20002004

#define MEM_WRITE(_addr_, _value_) (*((volatile unsigned int *)(_addr_)) = _value_)
#define MEM_READ(_addr_)           (*((volatile unsigned int *)(_addr_)))

void start_prog()
{
    asm volatile(
        "lui x15,0x10000\n"
        "addi x15,x15,0\n"
        "jalr x0,x15,0\n"
    );
}

unsigned int read_word()
{
    unsigned int word = 0;
    for (int i = 0; i < 4; ++i) {
        word <<= 8;
        while(!(MEM_READ(UART_STATUS) & 2));
        unsigned int c = MEM_READ(UART_DATA);
        word |= c;
    }
    return word;
}

void main(void)
{
    // Read program
    unsigned int addr = 0x10000000;
    unsigned int size;
    size = read_word();

    if (size == 0) {
        MEM_WRITE(DISPLAY, 0x01);
        return;
    }

    for (unsigned int i = 0; i < size; ++i) {
        unsigned int word = read_word();
        MEM_WRITE(addr, word);
        addr += 4;
        MEM_WRITE(DISPLAY, i << 1);        
    }
    start_prog();
}
