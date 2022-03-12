#define DISPLAY         0x20001000
#define UART_DATA       0x20002000
#define UART_STATUS     0x20002004

#define MEM_WRITE(_addr_, _value_) (*((volatile unsigned int *)(_addr_)) = _value_)
#define MEM_READ(_addr_)           (*((volatile unsigned int *)(_addr_)))

char *itoa(int value, char* result, int base);
void print(const char *s);
