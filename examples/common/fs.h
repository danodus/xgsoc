// fs.h
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

#ifndef FS_H
#define FS_H

#include <stdint.h>

#include <sd_card.h>

#define FS_MAX_FILENAME_LEN 31      // maximum filename length (excluding the terminating null byte)
#define FS_MAX_NB_FILES     128
#define FS_MAX_NB_BLOCKS    (2*1024*1024 / SD_BLOCK_LEN)       // maximum number of blocks supported by the FS

typedef struct {
    char name[FS_MAX_FILENAME_LEN + 1];     // entry not set if name begins with '\0'
    uint32_t size;                          // size in bytes
    uint32_t first_block_table_index;       // zero if file is empty
} fs_file_info_t;

typedef struct {
    uint8_t magic[2];                               // "FS"
    fs_file_info_t file_infos[FS_MAX_NB_FILES];     // file information entries
    uint16_t blocks[FS_MAX_NB_BLOCKS];              // block table
} fs_fat_t;

typedef struct {
    fs_fat_t fat;
    sd_context_t *sd_ctx;
} fs_context_t;

bool fs_format(sd_context_t *sd_ctx, bool quick);

bool fs_init(sd_context_t *sd_ctx, fs_context_t *fs_ctx);
uint16_t fs_get_nb_files(fs_context_t *ctx);
bool fs_get_file_info(fs_context_t *ctx, uint16_t file_index, fs_file_info_t *file_info);
bool fs_read(fs_context_t *ctx, const char *filename, uint8_t *buf, size_t current_pos, size_t nb_bytes, size_t *nb_read_bytes);
bool fs_write(fs_context_t *ctx, const char *filename, const uint8_t *buf, size_t current_pos, size_t nb_bytes);
bool fs_delete(fs_context_t *ctx, const char *filename);

#endif // FS_H
