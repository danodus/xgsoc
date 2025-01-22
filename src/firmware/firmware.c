// firmware.c
// Copyright (c) 2023-2025 Daniel Cliche
// SPDX-License-Identifier: MIT

#include <io.h>
#include <sd_card.h>

#define RAM_START   0x00000000

#define BASE_VIDEO  0x1000000

#define MEM_WRITE(_addr_, _value_) (*((volatile unsigned int *)(_addr_)) = _value_)
#define MEM_READ(_addr_) *((volatile unsigned int *)(_addr_))

unsigned int read_word()
{
    unsigned int word = 0;
    for (int i = 0; i < 4; ++i) {
        word <<= 8;
        while(!(MEM_READ(UART_STATUS) & 1));
        unsigned int c = MEM_READ(UART_DATA);
        word |= c;
    }
    return word;
}

void echo()
{
    for (;;) {
        while(!(MEM_READ(UART_STATUS) & 1));
        unsigned int c = MEM_READ(UART_DATA);
        while(!(MEM_READ(UART_STATUS) & 2));
        MEM_WRITE(UART_DATA, c);
    }
}

void flush_cache(void)
{
    // Flush cache
    MEM_WRITE(CONFIG, 0x1);
}

void clear(int color)
{
    unsigned int res = MEM_READ(CONFIG);
    unsigned hres = res >> 16;
    unsigned vres = res & 0xffff;

    unsigned int *fb = (unsigned int *)BASE_VIDEO;
    unsigned int c = color << 16 | color;
    for (unsigned int y = 0; y < vres; y++)
        for (unsigned int x = 0; x < hres / 2; x++) {
            *fb = c;
            fb++;
        }

    flush_cache();
}

void main(void)
{
    print("XGSoC\r\nCopyright (c) 2022-2025 Daniel Cliche\r\n\r\n");

    clear(0x8410);  // Gray

#if ECHO_TEST
    
    echo();

#else // ECHO_TEST

    bool boot_sd_card = false;
    bool bypass_sd_card = false;

    print("Press a key to bypass the SD card image boot process...\r\n");
    for (int i = 0; i < 1000000; ++i) {
        if (MEM_READ(UART_STATUS) & 1) {
            MEM_READ(UART_DATA);
            bypass_sd_card = true;
            break;
        }
    }

    sd_context_t sd_ctx;
    if (!bypass_sd_card && sd_init(&sd_ctx)) {
        print("SD card available\r\n");

        uint8_t buf[SD_BLOCK_LEN];
        sd_image_info_t *image_info = (sd_image_info_t *)buf;
        if (sd_read_single_block(&sd_ctx, 0, buf)) {
            if (image_info->magic[0] == 'X' && image_info->magic[1] == 'G') {
                size_t remaining_bytes = (size_t)image_info->len;
                uint32_t sd_addr = 1;
                uint8_t *mem = (uint8_t *)RAM_START;
                while(remaining_bytes > 0) {
                    print(".");
                    size_t s = remaining_bytes > SD_BLOCK_LEN ? SD_BLOCK_LEN : remaining_bytes;
                    if (!sd_read_single_block(&sd_ctx, sd_addr, mem)) {
                        print("\r\nFailed to read SD card image\r\n");
                        break;
                    }
                    remaining_bytes -= s;
                    mem += s;
                    sd_addr++;  // next block
                }
                if (remaining_bytes == 0) {
                    print("\r\nSD card image read successfully\r\n");
                    boot_sd_card = true;
                }
            } else {
                print("No image found\r\n");
            }

        } else {
            print("Unable to read the boot sector\r\n");
        }
    }

    for (;;) {
        if (!boot_sd_card) {
            MEM_WRITE(LED, 0xFF);
            print("Ready to receive...\r\n");

            // Read program
            unsigned int addr = RAM_START;
            unsigned int size;
            size = read_word();

            if (size == 0) {
                MEM_WRITE(LED, 0x01);
                return;
            }

            for (unsigned int i = 0; i < size; ++i) {
                unsigned int word = read_word();
                MEM_WRITE(addr, word);
                addr += 4;
                MEM_WRITE(LED, i << 1);        
            }
            MEM_WRITE(LED, 0x00);
        }

        // start program
        void (*program)(void) = (void (*)(void))RAM_START;
        program();
    }

#endif // ECHO_TEST
}
