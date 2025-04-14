#ifndef SD_CARD_H
#define SD_CARD_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

#define SD_BLOCK_LEN  512

typedef struct {
    uint8_t magic[2];     // "XG"
    uint32_t len;
} sd_image_info_t;

bool sd_init(void);
bool sd_read_single_block(uint32_t addr, uint8_t *buf);
bool sd_write_single_block(uint32_t addr, const uint8_t *buf);

#endif // SD_CARD_H
