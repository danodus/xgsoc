// Ref.: http://www.rjhcoding.com/avrc-sd-interface-1.php

#include <io.h>
#include <stdint.h>
#include <stdbool.h>

#define SD_CARD   0x20006000  

#define CS_BIT      0x2
#define SCLK_BIT    0x4

#define SD_START_TOKEN  0xFE

#define SD_MAX_READ_ATTEMPTS    300000
#define SD_MAX_WRITE_ATTEMPTS   750000

#define SD_BLOCK_LEN  512

#define CS_ENABLE()  { g_sd_cs = CS_BIT; MEM_WRITE(SD_CARD, g_sd_cs); }
#define CS_DISABLE() { g_sd_cs = 0; MEM_WRITE(SD_CARD, g_sd_cs); }

static uint32_t g_sd_cs = 0;

// Ref.: https://stackoverflow.com/questions/49672644/cant-figure-out-how-to-calculate-crc7
uint8_t crc7(const uint8_t message[], const unsigned int length)
{
    const unsigned char poly = 0b10001001;
    uint8_t crc = 0;
    for (unsigned i = 0; i < length; i++) {
        crc ^= message[i];
        for (int j = 0; j < 8; j++) {
        // crc = crc & 0x1 ? (crc >> 1) ^ poly : crc >> 1;       
        crc = (crc & 0x80u) ? ((crc << 1) ^ (poly << 1)) : (crc << 1);
    }
  }
  return crc;
}

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

void sd_command(uint8_t cmd, uint32_t arg, bool calc_crc)
{
    uint8_t m[5];
    m[0] = cmd | 0x40;
    m[1] = (uint8_t)(arg >> 24);
    m[2] = (uint8_t)(arg >> 16);
    m[3] = (uint8_t)(arg >> 8);
    m[4] = (uint8_t)(arg);

    for (int i = 0; i < 5; ++i)
        spi_transfer(m[i]);

    uint8_t crc = 0;
    if (calc_crc)
        crc = crc7(m, 5);

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

void sd_read_res3_7(uint8_t *res)
{
    // read response 1 in R7
    res[0] = sd_read_res1();

    // if error reading R1, return
    if (res[0] > 1) return;

    // read remaining bytes
    res[1] = spi_transfer(0xFF);
    res[2] = spi_transfer(0xFF);
    res[3] = spi_transfer(0xFF);
    res[4] = spi_transfer(0xFF);
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
    sd_command(0, 0x00000000, true);

    // read response
    uint8_t res1 = sd_read_res1();

    // deassert chip select
    spi_transfer(0xFF);
    CS_DISABLE();
    spi_transfer(0xFF);

    return res1;
}

void sd_send_if_cond(uint8_t *res)
{
    // assert chip select
    spi_transfer(0xFF);
    CS_ENABLE();
    spi_transfer(0xFF);

    // send cmd8
    sd_command(8, 0x000001AA, true);

    // read response
    sd_read_res3_7(res);

    // deassert chip select
    spi_transfer(0xFF);
    CS_DISABLE();
    spi_transfer(0xFF);
}

void sd_read_ocr(uint8_t *res)
{
    // assert chip select
    spi_transfer(0xFF);
    CS_ENABLE();
    spi_transfer(0xFF);

    // send cmd58
    sd_command(58, 0x00000000, false);

    // read response
    sd_read_res3_7(res);

    // deassert chip select
    spi_transfer(0xFF);
    CS_DISABLE();
    spi_transfer(0xFF);
}

uint8_t sd_send_app()
{
    // assert chip select
    spi_transfer(0xFF);
    CS_ENABLE();
    spi_transfer(0xFF);

    // send cmd55
    sd_command(55, 0x00000000, false);

    // read response
    uint8_t res1 = sd_read_res1();

    // deassert chip select
    spi_transfer(0xFF);
    CS_DISABLE();
    spi_transfer(0xFF);

    return res1;
}

uint8_t sd_send_op_cond()
{
    // assert chip select
    spi_transfer(0xFF);
    CS_ENABLE();
    spi_transfer(0xFF);

    // send cmd41
    sd_command(41, 0x40000000, false);

    // read response
    uint8_t res1 = sd_read_res1();

    // deassert chip select
    spi_transfer(0xFF);
    CS_DISABLE();
    spi_transfer(0xFF);

    return res1;
}

uint8_t sd_read_single_block(uint32_t addr, uint8_t *buf, uint8_t *token)
{
    uint8_t res1, read;
    unsigned int read_attempts;

    // set token to none
    *token = 0xFF;

    // assert chip select
    spi_transfer(0xFF);
    CS_ENABLE();
    spi_transfer(0xFF);

    // send CMD17
    sd_command(17, addr, false);

    // read R1
    res1 = sd_read_res1();

    // if response received from the card
    if (res1 != 0xFF) {
        // wait for a response token (timeout == 100ms)
        read_attempts = 0;
        while (++read_attempts != SD_MAX_READ_ATTEMPTS)
            if ((read = spi_transfer(0xFF)) != 0xFF)
                break;

            // if response token is 0xFE
            if (read == 0xFE) {
                // read block
                for (uint16_t i = 0; i < SD_BLOCK_LEN; ++i)
                    *buf++ = spi_transfer(0xFF);

                // read 16-bit CRC
                spi_transfer(0xFF);
                spi_transfer(0xFF);
            }

            // set token to card response
            *token = read;
    }

    // deassert chip select
    spi_transfer(0xFF);
    CS_DISABLE();
    spi_transfer(0xFF);

    return res1;
}

uint8_t sd_write_single_block(uint32_t addr, uint8_t *buf, uint8_t *token)
{
    uint8_t res1, write;
    unsigned int write_attempts;

    // set token to none
    *token = 0xFF;

    // assert chip select
    spi_transfer(0xFF);
    CS_ENABLE();
    spi_transfer(0xFF);

    // send CMD24
    sd_command(24, addr, false);

    // read R1
    res1 = sd_read_res1();

    if (res1 == 0x00) {
        // send start token
        spi_transfer(SD_START_TOKEN);

        // write buffer to card
        for (uint16_t i = 0; i < SD_BLOCK_LEN; ++i)
            spi_transfer(buf[i]);
    }

    // if response received from the card
    if (res1 != 0xFF) {
        // wait for a response token (timeout == 250ms)
        write_attempts = 0;
        while (++write_attempts != SD_MAX_WRITE_ATTEMPTS)
            if ((write = spi_transfer(0xFF)) != 0xFF) {
                *token = 0xFF;
                break;
            }

        // if data accepted
        if ((write & 0x1F) == 0x05) {
            // set token to data accepted
            *token = 0x05;

            // wait for write to finish (timeout == 250ms)
            write_attempts = 0;
            while (spi_transfer(0xFF) == 0x00)
                if (++write_attempts == SD_MAX_WRITE_ATTEMPTS) {
                    *token = 0x00;
                    break;
                }
        }
    }

    // deassert chip select
    spi_transfer(0xFF);
    CS_DISABLE();
    spi_transfer(0xFF);

    return res1;    
}

void main(void)
{
    print("SD Card Test\r\n");

    uint8_t res[5];

    // start the power up sequence
    sd_power_up_seq();

    // command card to go idle (CMD0)
    res[0] = sd_go_idle_state();
    printv("CMD0 result: ", res[0]);

    // send if conditions (CMD8)
    sd_send_if_cond(res);
    for (int i = 0; i < 5; ++i)
        printv("CMD8 result: ", res[i]);

    // read operation conditions register (CMD58)
    sd_read_ocr(res);
    for (int i = 0; i < 5; ++i)
        printv("CMD58 result: ", res[i]);

    // send operating condition (ACMD41) until no longer in idle
    for (int i = 0; i < 100; ++i) {
        // send app (CMD55)
        res[0] = sd_send_app();
        printv("CMD55 result: ", res[0]);

        res[0] = sd_send_op_cond();
        printv("ACMD41 result: ", res[0]);

        if (res[0] == 0x00 || res[0] != 0x01)
            break;
    }

    if (res[0] == 0x00) {
        print("SD card initialization was successful\r\n");
    } else {
        print("SD card initialization failed\r\n");
        return;
    }


    for (uint32_t block = 0; block < 1000; ++block) {
        printv("Sector: ", block);

        //
        // write sector
        //

        uint8_t sd_buf[SD_BLOCK_LEN], token;
        for (uint16_t i = 0; i < SD_BLOCK_LEN; ++i) {
            sd_buf[i] = 0x55;
        }

        // write 0x55 to address 0x0
        res[0] = sd_write_single_block(block, sd_buf, &token);

        if (res[0] == 0x00 && token == 0x05) {
            print("Sector written successfully\r\n");
        } else {
            printv("Error writing sector: ", token);
            return;
        }

        //
        // read sector
        //
        
        res[0] = sd_read_single_block(block, sd_buf, &token);

        if (res[0] == 0x00 && token == 0xFE) {
            print("Sector read successfully\r\n");
        } else {
            printv("Error reading sector: ", token);
            return;
        }

        // Compare
        for (uint16_t i = 0; i < SD_BLOCK_LEN; ++i) {
            if (sd_buf[i] != 0x55) {
                printv("Mismatch detected at index ", i);
                return;
            }
        }
    }

    print("Success!\r\n");
}
