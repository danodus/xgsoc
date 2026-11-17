#include <io.h>

static volatile unsigned int cell;

static unsigned int amo_add(unsigned int val)
{
    unsigned int old;
    __asm__ volatile ("amoadd.w %0, %1, (%2)" : "=&r"(old) : "r"(val), "r"(&cell) : "memory");
    return old;
}

static unsigned int amo_swap(unsigned int val)
{
    unsigned int old;
    __asm__ volatile ("amoswap.w %0, %1, (%2)" : "=&r"(old) : "r"(val), "r"(&cell) : "memory");
    return old;
}

static unsigned int amo_xor(unsigned int val)
{
    unsigned int old;
    __asm__ volatile ("amoxor.w %0, %1, (%2)" : "=&r"(old) : "r"(val), "r"(&cell) : "memory");
    return old;
}

static unsigned int amo_and(unsigned int val)
{
    unsigned int old;
    __asm__ volatile ("amoand.w %0, %1, (%2)" : "=&r"(old) : "r"(val), "r"(&cell) : "memory");
    return old;
}

static unsigned int amo_or(unsigned int val)
{
    unsigned int old;
    __asm__ volatile ("amoor.w %0, %1, (%2)" : "=&r"(old) : "r"(val), "r"(&cell) : "memory");
    return old;
}

static unsigned int amo_min(unsigned int val)
{
    unsigned int old;
    __asm__ volatile ("amomin.w %0, %1, (%2)" : "=&r"(old) : "r"(val), "r"(&cell) : "memory");
    return old;
}

static unsigned int amo_max(unsigned int val)
{
    unsigned int old;
    __asm__ volatile ("amomax.w %0, %1, (%2)" : "=&r"(old) : "r"(val), "r"(&cell) : "memory");
    return old;
}

static unsigned int amo_minu(unsigned int val)
{
    unsigned int old;
    __asm__ volatile ("amominu.w %0, %1, (%2)" : "=&r"(old) : "r"(val), "r"(&cell) : "memory");
    return old;
}

static unsigned int amo_maxu(unsigned int val)
{
    unsigned int old;
    __asm__ volatile ("amomaxu.w %0, %1, (%2)" : "=&r"(old) : "r"(val), "r"(&cell) : "memory");
    return old;
}

static unsigned int lr(void)
{
    unsigned int val;
    __asm__ volatile ("lr.w %0, (%1)" : "=&r"(val) : "r"(&cell) : "memory");
    return val;
}

static unsigned int sc(unsigned int val)
{
    unsigned int status;
    __asm__ volatile ("sc.w %0, %2, (%1)" : "=&r"(status) : "r"(&cell), "r"(val) : "memory");
    return status;
}

static void check(const char *name, int pass)
{
    print(name);
    print(pass ? " Pass\r\n" : " Fail\r\n");
}

void main(void)
{
    unsigned int old;
    unsigned int status;

    print("Testing atomics...\r\n");

    cell = 5;
    old = amo_add(3);
    check("AMOADD", old == 5 && cell == 8);

    cell = 8;
    old = amo_swap(0xA5);
    check("AMOSWAP", old == 8 && cell == 0xA5);

    cell = 0xA5;
    old = amo_xor(0xFF);
    check("AMOXOR", old == 0xA5 && cell == 0x5A);

    cell = 0x5A;
    old = amo_and(0x0F);
    check("AMOAND", old == 0x5A && cell == 0x0A);

    cell = 0x0A;
    old = amo_or(0xF0);
    check("AMOOR", old == 0x0A && cell == 0xFA);

    cell = 5;
    old = amo_min(0xFFFFFFFD); /* -3 */
    check("AMOMIN", old == 5 && cell == 0xFFFFFFFD);

    cell = 0xFFFFFFFD;
    old = amo_max(0xFFFFFFFF); /* -1 */
    check("AMOMAX", old == 0xFFFFFFFD && cell == 0xFFFFFFFF);

    cell = 0xFFFFFFFF;
    old = amo_minu(1);
    check("AMOMINU", old == 0xFFFFFFFF && cell == 1);

    cell = 1;
    old = amo_maxu(0xFFFFFFFF);
    check("AMOMAXU", old == 1 && cell == 0xFFFFFFFF);

    cell = 0x11;
    old = lr();
    status = sc(0x22);
    check("LRSC", old == 0x11 && status == 0 && cell == 0x22);

    status = sc(0x99);
    check("SC fail", status != 0 && cell == 0x22);

    old = lr();
    cell = 0x33;
    status = sc(0x44);
    check("SC lost", old == 0x22 && status != 0 && cell == 0x33);

    print("Done.\r\n");
    for (;;)
        ;
}
