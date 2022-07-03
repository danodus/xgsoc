#ifndef SYS_H
#define SYS_H

#define SYS_TTY_MODE_RAW    0x1

void sys_set_tty_mode(unsigned int mode);
unsigned int sys_get_tty_mode();

#endif
