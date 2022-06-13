#include <io.h>
#include <stdint.h>
#include <stdbool.h>

#define FLASH   0x20007000  

#define CS_BIT      0x2
#define SCLK_BIT    0x4

#define CS_ENABLE()  { g_cs = CS_BIT; MEM_WRITE(FLASH, g_cs); }
#define CS_DISABLE() { g_cs = 0; MEM_WRITE(FLASH, g_cs); }

#define FLASH_WRDIS         0x04
#define FLASH_RDSR          0x05
#define FLASH_WREN          0x06
#define FLASH_RDID          0x9F
#define FLASH_POWER_UP      0xAB
#define FLASH_POWER_DOWN    0xB9

static uint32_t g_cs = 0;

void printv(const char *m, int v)
{
    print(m);
    char s[32];
    itoa(v, s, 16);
    print(s);
    print("\r\n");
}

uint8_t spi_transfer(uint8_t mosi)
{
    uint8_t miso = 0;

    for (int i = 0; i < 8; ++i) {
        miso <<= 1;

        uint32_t b = mosi & 0x80 ? 0x1 : 0x0;
        MEM_WRITE(FLASH, g_cs | b);
        MEM_WRITE(FLASH, g_cs | b | SCLK_BIT);

        uint32_t r = MEM_READ(FLASH);
        miso |= (r & 0x1);

        MEM_WRITE(FLASH, g_cs | b);
        mosi <<= 1;

    }

    return miso;
}

void main(void)
{
    print("Flash Test\r\n");

    uint8_t rx[3];

    CS_ENABLE();
    spi_transfer(0xFF);
    CS_DISABLE();

    CS_ENABLE();
    spi_transfer(FLASH_POWER_UP);
    CS_DISABLE();

    // Read status reg
    CS_ENABLE();
    spi_transfer(FLASH_RDID);
    rx[0] = spi_transfer(0xFF);
    rx[1] = spi_transfer(0xFF);
    rx[2] = spi_transfer(0xFF);
    CS_DISABLE();

    printv("ID[0]: ", rx[0]);
    printv("ID[1]: ", rx[1]);
    printv("ID[2]: ", rx[2]);

    CS_ENABLE();
    spi_transfer(FLASH_RDSR);
    rx[0] = spi_transfer(0xFF);
    printv("Status: ", rx[0]);
    CS_DISABLE();

    print("Enable write...\r\n");

    CS_ENABLE();
    spi_transfer(FLASH_WREN);
    CS_DISABLE();

    CS_ENABLE();
    spi_transfer(FLASH_RDSR);
    rx[0] = spi_transfer(0xFF);
    printv("Status: ", rx[0]);
    CS_DISABLE();

    CS_ENABLE();
    spi_transfer(FLASH_POWER_DOWN);
    CS_DISABLE();

    print("Disable write...\r\n");

    CS_ENABLE();
    spi_transfer(FLASH_WRDIS);
    CS_DISABLE();

    CS_ENABLE();
    spi_transfer(FLASH_RDSR);
    rx[0] = spi_transfer(0xFF);
    printv("Status: ", rx[0]);
    CS_DISABLE();    


    print("Done.\r\n");
}
