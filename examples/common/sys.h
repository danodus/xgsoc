#ifndef SYS_H
#define SYS_H

#define TIMER_INTR_ENA 0x20000000

#define SYS_TTY_MODE_RAW    0x1
#define SYS_MAX_NB_OPEN_FILES   32

extern void (*irq1_handler)();
extern void (*ecall_handler)();
extern void (*ebreak_handler)();

void sys_set_tty_mode(unsigned int mode);
unsigned int sys_get_tty_mode();

#endif
