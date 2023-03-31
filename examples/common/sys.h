// sys.h
// Copyright (c) 2022-2023 Daniel Cliche
// SPDX-License-Identifier: MIT

#ifndef SYS_H
#define SYS_H

#include "fs.h"

#define TIMER_INTR_ENA 0x20000000

#define SYS_TTY_MODE_RAW    0x1
#define SYS_MAX_NB_OPEN_FILES   32

extern void (*irq1_handler)();
extern void (*ecall_handler)();
extern void (*ebreak_handler)();

// TTY
void sys_set_tty_mode(unsigned int mode);
unsigned int sys_get_tty_mode();

// File system
bool sys_fs_format(bool quick);
bool sys_fs_unmount();
uint16_t sys_fs_get_nb_files();
bool sys_fs_get_file_info(uint16_t file_index, fs_file_info_t *file_info);
bool sys_fs_delete(const char *filename);
bool sys_fs_rename(const char *filename, const char *new_filename);

#endif
