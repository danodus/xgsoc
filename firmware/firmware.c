#include <io.h>
#include <sd_card.h>

#define RAM_START 0x10000000

static const uint32_t reg_init[15] = {
        0x000000b3, 0x00000133, 0x000001b3, 0x00000233, 0x000002b3, 0x00000333, 0x000003b3, 0x00000433, 0x000004b3, 0x00000533, 0x000005b3, 0x00000633, 0x000006b3, 0x00000733, 0x000007b3
};

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
    print("XGSoC\r\nCopyright (c) 2022 Daniel Cliche\r\n\r\n");

    bool boot_sd_card = false;
    bool bypass_sd_card = false;

    print("Press a key to bypass the SD card image boot process...\r\n");
    for (int i = 0; i < 300000; ++i) {
        if (MEM_READ(UART_STATUS) & 2) {
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

    if (!boot_sd_card) {
        MEM_WRITE(DISPLAY, 0xFF);
        print("Ready to receive...\r\n");

        // Read program
        unsigned int addr = RAM_START;
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
        MEM_WRITE(DISPLAY, 0x00);
    }

    // sanity check
    // registers initialization expected at the beginning
    for (uint32_t i = 0; i < 15; ++i) {
        if (MEM_READ(RAM_START + i*4) != reg_init[i]) {
            print("Invalid code in RAM\r\n");
            return;
        }
    }

    start_prog();
}
