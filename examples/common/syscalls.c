// An extremely minimalist syscalls.c for newlib
// Based on riscv newlib libgloss/riscv/sys_*.c
// Written by Clifford Wolf.

#include <sys/stat.h>
#include <sys/time.h>
#include <sys/timeb.h>
#include <sys/unistd.h>
#include <sys/errno.h>

#ifdef XIO
#include "kbd.h"
#include "xio.h"
#else
#include "io.h"
#endif

extern int errno;

#define UNIMPL_FUNC(_f) ".globl " #_f "\n.type " #_f ", @function\n" #_f ":\n"

asm (
	".text\n"
	".align 2\n"
	UNIMPL_FUNC(_open)
	UNIMPL_FUNC(_openat)
	UNIMPL_FUNC(_lseek)
	UNIMPL_FUNC(_stat)
	UNIMPL_FUNC(_lstat)
	UNIMPL_FUNC(_fstatat)
	UNIMPL_FUNC(_isatty)
	UNIMPL_FUNC(_access)
	UNIMPL_FUNC(_faccessat)
	UNIMPL_FUNC(_link)
	UNIMPL_FUNC(_unlink)
	UNIMPL_FUNC(_execve)
	UNIMPL_FUNC(_getpid)
	UNIMPL_FUNC(_fork)
	UNIMPL_FUNC(_kill)
	UNIMPL_FUNC(_wait)
	UNIMPL_FUNC(_times)
	UNIMPL_FUNC(_ftime)
	UNIMPL_FUNC(_utime)
	UNIMPL_FUNC(_chown)
	UNIMPL_FUNC(_chmod)
	UNIMPL_FUNC(_chdir)
	UNIMPL_FUNC(_getcwd)
	UNIMPL_FUNC(_sysconf)
	"j unimplemented_syscall\n"
);

void ebreak()
{
    asm volatile(
        "lui x15,0x00000\n"
        "addi x15,x15,0\n"
        "jalr x0,x15,0\n"
    );
    __builtin_unreachable();
}

void unimplemented_syscall()
{
#ifdef XIO
	xprint("Unimplemented system call called!\n");
#else
	print("Unimplemented system call called!\n");
#endif
    ebreak();
	__builtin_unreachable();
}

void sysinit()
{
#ifdef XIO
	xinit();
#endif
}

static char sys_read_char()
{
#ifdef XIO
	// keyboard
	return kbd_get_char();
#else
	// serial port
	while (1) {
		if (MEM_READ(UART_STATUS) & 2) {
            unsigned int c = MEM_READ(UART_DATA);
			return (char)c;
		}
	}	
#endif
}

static void sys_write_char(char c)
{
#ifdef XIO
	// Xosera
	xprint_chr(c);
#else
	// serial port
	if (c == '\n') {
		while(MEM_READ(UART_STATUS) & 1);
		MEM_WRITE(UART_DATA, (unsigned int)'\r');
	}
	while(MEM_READ(UART_STATUS) & 1);
    MEM_WRITE(UART_DATA, (unsigned int)c);
#endif
}

static size_t sys_read_line(char *s, size_t buffer_len)
{
    size_t len = 0;
    while(1) {
        char c = sys_read_char();
        if (c == '\b') {
            if (len > 0) {
                s--;
                len--;
                sys_write_char('\b');
                sys_write_char(' ');
                sys_write_char('\b');
            }
        } else if (c == '\r') {
				sys_write_char('\n');
			if (len < buffer_len) {
				*s = '\n';
				s++;
				len++;
			}
			break;
		} else {
			if (len < buffer_len) {
				sys_write_char(c);
				*s = c;
				s++;
				len++;
			}
        }
    }

	return len;
}

ssize_t _read(int file, void *ptr, size_t len)
{
	if (file == STDIN_FILENO) {
		char buf[256];
		size_t c = sys_read_line(buf, 256);
		if (c > len)
			c = len;
		char *p = (char *)ptr;
		for (size_t i = 0; i < c; ++i)
			p[i] = buf[i];
		return c;
	}
	errno = EBADF;
    return -1;
}

ssize_t _write(int file, const void *ptr, size_t len)
{
	if (file == STDOUT_FILENO || file == STDERR_FILENO) {
	    const void *eptr = ptr + len;
		while (ptr != eptr)
			sys_write_char(*(char*) (ptr++));
    	return len;
	}
	errno = EBADF;
	return -1;
}

int _close(int file)
{
    // not implemented
    // close is called before _exit()
    return 0;
}

int _gettimeofday(struct timeval *restrict tv, struct timezone *restrict tz)
{
	// not implemented
	return 0;
}

int _fstat(int file, struct stat *st)
{
	// not implemented
	// fstat is called during libc startup
	errno = ENOENT;
	return -1;
}

void *_sbrk(ptrdiff_t incr)
{
	extern unsigned char _end[];   // Defined by linker
    extern unsigned char __stacktop[];

	static unsigned long heap_end;

	if (heap_end == 0)
		heap_end = (unsigned long)_end;

    if (heap_end + incr > (unsigned long)__stacktop) {
        errno = ENOMEM;
        return (void *)0;
    }

	heap_end += incr;
	return (void *)(heap_end - incr);
}

void _exit(int exit_status)
{
    ebreak();
    __builtin_unreachable();
}