#include <io.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <sd_card.h>

void printv(const char *m, int v)
{
    print(m);
    char s[32];
    itoa(v, s, 10);
    print(s);
    print("\r\n");
}

unsigned int read_word()
{
    unsigned int word = 0;
    for (int i = 0; i < 4; ++i) {
        word <<= 8;
        while(!(MEM_READ(UART_STATUS) & 2));
        // dequeue
        MEM_WRITE(UART_STATUS, 0x1);        
        unsigned int c = MEM_READ(UART_DATA);
        word |= c;
    }
    return word;
}

void main(void)
{
    print("Write Image\r\n");

    //
    // Initialize
    //

    sd_context_t sd_ctx;
    while (!sd_init(&sd_ctx)) {
        print("Insert a SD card and press a key...\r\n");
        while (!(MEM_READ(UART_STATUS) & 2));
        // dequeue
        MEM_WRITE(UART_STATUS, 0x1);        
        MEM_READ(UART_DATA);
    }

    uint8_t buf[SD_BLOCK_LEN];
    sd_image_info_t *image_info = (sd_image_info_t *)buf;

    // Initialize image
    print("Initializing image...\r\n");
    image_info->magic[0] = 0;
    image_info->magic[1] = 0;
    if (!sd_write_single_block(&sd_ctx, 0, buf)) {
        print("Unable to write image info\r\n");
        return;
    }

    print("Ready to receive...\r\n");

    // Read program
    uint32_t size;
    size = read_word();

    if (size == 0) {
        return;
    }

    uint32_t *bufw = (uint32_t *)buf;
    size_t remaining_words = (size_t)size;
    uint32_t sd_addr = 1;
    while (remaining_words > 0) {
        size_t s = remaining_words > (SD_BLOCK_LEN / 4) ? (SD_BLOCK_LEN / 4) : remaining_words;

        for (size_t i = 0; i < (SD_BLOCK_LEN / 4); ++i) {
            bufw[i] = i < s ? read_word() : 0xFFFFFFFF;
        }

        printv("Remaining words: ", remaining_words);

        if (!sd_write_single_block(&sd_ctx, sd_addr, buf)) {
            print("Unable to write block\r\n");
            return;
        }

        remaining_words -= s;
        sd_addr++;  // next block
    }

    print("Writing image info...\r\n");
    image_info->magic[0] = 'X';
    image_info->magic[1] = 'G';
    image_info->len = size * 4; // length in bytes
    if (!sd_write_single_block(&sd_ctx, 0, buf)) {
        print("Unable to write image info\r\n");
        return;
    }

    print("The image has been written succesfully.\r\n");
    print("Press a key to continue...\r\n");
    while (!(MEM_READ(UART_STATUS) & 2));
    // dequeue
    MEM_WRITE(UART_STATUS, 0x1);    
    MEM_READ(UART_DATA);
}
