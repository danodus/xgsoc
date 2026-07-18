#include <io.h>

void print_hex(unsigned int val) {
    char buf[9];
    buf[8] = '\0';
    for (int i = 7; i >= 0; i--) {
        int nibble = val & 0xF;
        buf[i] = nibble < 10 ? '0' + nibble : 'A' + nibble - 10;
        val >>= 4;
    }
    print(buf);
    print("\r\n");
}

void main() {
    print("Testing division...\r\n");
    unsigned int a = 120;
    unsigned int b = 10;
    unsigned int q, r;
    __asm__ volatile ("divu %0, %1, %2" : "=r"(q) : "r"(a), "r"(b));
    __asm__ volatile ("remu %0, %1, %2" : "=r"(r) : "r"(a), "r"(b));
    
    print("q = "); print_hex(q);
    print("r = "); print_hex(r);
    
    if (q == 12) print("DIVU Pass\r\n");
    else print("DIVU Fail\r\n");
    
    if (r == 0) print("REMU Pass\r\n");
    else print("REMU Fail\r\n");
    
    print("Done.\r\n");
}
