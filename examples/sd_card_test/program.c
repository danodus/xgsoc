#include <io.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <sd_card.h>

void printv(const char *m, int v)
{
    print(m);
    char s[32];
    itoa(v, s, 16);
    print(s);
    print("\r\n");
}

void main(void)
{
    print("SD Card Test\r\n");

    //
    // Initialize
    //

    sd_context_t sd_ctx;
    if (!sd_init(&sd_ctx)) {
        print("SD card initialization failed\r\n");
        return;
    }

    for (uint32_t block = 0; block < 1000; ++block) {
        printv("Sector: ", block);

        //
        // write sector
        //

        uint8_t sd_buf[SD_BLOCK_LEN];
        for (uint16_t i = 0; i < SD_BLOCK_LEN; ++i) {
            sd_buf[i] = 0x55;
        }

        if (sd_write_single_block(&sd_ctx, block, sd_buf, SD_BLOCK_LEN)) {
            print("Sector written successfully\r\n");
        } else {
            print("Error writing sector\r\n");
            return;
        }

        //
        // read sector
        //
        
        if (sd_read_single_block(&sd_ctx, block, sd_buf, SD_BLOCK_LEN)) {
            print("Sector read successfully\r\n");
        } else {
            print("Error reading sector\r\n");
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
