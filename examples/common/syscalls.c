// An extremely minimalist syscalls.c for newlib
// Based on riscv newlib libgloss/riscv/sys_*.c
// Written by Clifford Wolf.

#include <sys/stat.h>
#include <sys/time.h>
#include <sys/timeb.h>
#include <errno.h>

#ifdef XIO
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

ssize_t _read(int file, void *ptr, size_t len)
{
    // not implemented
    // always EOF
    return 0;
}

ssize_t _write(int file, const void *ptr, size_t len)
{
    const void *eptr = ptr + len;
    while (ptr != eptr) {
#ifdef XIO
        putchar(*(char*) (ptr++));
#else
		print_chr(*(char*) (ptr++));
#endif		
	}
    return len;
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