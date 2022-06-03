// Ref.: http://www.rjhcoding.com/avrc-sd-interface-1.php

#include <io.h>
#include <stdint.h>

#define SD_CARD   0x20006000  

#define CS_BIT      0x2
#define SCLK_BIT    0x4

#define CMD0        0
#define CMD0_ARG    0x00000000
#define CMD0_CRC    0x94

#define CS_ENABLE()  { g_sd_cs = CS_BIT; MEM_WRITE(SD_CARD, g_sd_cs); }
#define CS_DISABLE() { g_sd_cs = 0; MEM_WRITE(SD_CARD, g_sd_cs); }

static uint32_t g_sd_cs = 0;

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
        MEM_WRITE(SD_CARD, g_sd_cs | b);
        MEM_WRITE(SD_CARD, g_sd_cs | b | SCLK_BIT);

        uint32_t r = MEM_READ(SD_CARD);
        miso |= (r & 0x1);

        MEM_WRITE(SD_CARD, g_sd_cs | b);
        mosi <<= 1;

    }

    return miso;
}

void sd_command(uint8_t cmd, uint32_t arg, uint8_t crc)
{
    // transmit command to SD card
    spi_transfer(cmd | 0x40);

    // transmit argument
    spi_transfer((uint8_t)(arg >> 24));
    spi_transfer((uint8_t)(arg >> 16));
    spi_transfer((uint8_t)(arg >> 8));
    spi_transfer((uint8_t)(arg));

    // transmit crc
    spi_transfer(crc | 0x1);
}


uint8_t sd_read_res1()
{
    uint8_t i = 0, res1 = 0xFF;

    // keep polling until actual data received
    while((res1 = spi_transfer(0xFF)) == 0xFF)
    {
        i++;

        // if no data is received for 8 bytes, break
        if (i > 8)
            break;
    }

    return res1;
}

void sd_power_up_seq()
{
    // make sure the card is deselected
    CS_DISABLE();

    // give sd card time to power up
    // TODO: wait 1 ms

    // send 80 clock cycles to synchronize
    for (uint8_t i = 0; i < 10; ++i)
        spi_transfer(0xFF);

    // deselect SD card
    CS_DISABLE();
    spi_transfer(0xFF);
}

uint8_t sd_go_idle_state()
{
    // assert chip select
    spi_transfer(0xFF);
    CS_ENABLE();
    spi_transfer(0xFF);

    // send CMD0
    sd_command(CMD0, CMD0_ARG, CMD0_CRC);

    // read response
    uint8_t res1 = sd_read_res1();

    // deassert chip select
    spi_transfer(0xFF);
    CS_DISABLE();
    spi_transfer(0xFF);

    return res1;
}

void main(void)
{
    print("SD Card Test\r\n");

    // start the power up sequence
    sd_power_up_seq();

    // command card to go idle
    uint8_t res1 = sd_go_idle_state();

    printv("Go to idle result: ", res1);

}
