// An extremely minimalist syscalls.c for newlib
// Based on riscv newlib libgloss/riscv/sys_*.c
// Written by Clifford Wolf.

#include <sys/stat.h>
#include <sys/time.h>
#include <sys/times.h>
#include <sys/timeb.h>
#include <sys/unistd.h>
#include <sys/errno.h>
#include <sys/signal.h>

#ifdef XIO
#include "kbd.h"
#include "xio.h"
#else
#include "io.h"
#endif

extern int errno;
static void sys_print(const char *s);

void ebreak()
{
	sys_print("System halted!\n");
    for(;;);
    __builtin_unreachable();
}

void unimplemented_syscall(const char *fn)
{
	sys_print("Unimplemented system call called!\n");
	sys_print("Function: ");
	sys_print(fn);
	sys_print("\n");
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

static void sys_print(const char *s)
{
	while (*s) {
		sys_write_char(*s);
		s++;
	}
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
	unimplemented_syscall("exit");
	__builtin_unreachable();
}

int _chdir(const char *path)
{
	unimplemented_syscall("chdir");
	__builtin_unreachable();
}

int _chmod(const char *pathname, mode_t mode)
{
	unimplemented_syscall("chmod");
	__builtin_unreachable();
}

int _chown(const char *pathname, uid_t owner, gid_t group)
{
	unimplemented_syscall("chown");
	__builtin_unreachable();
}

int _access(const char *pathname, int mode)
{
	unimplemented_syscall("access");
	__builtin_unreachable();
}

int _kill(pid_t pid, int sig)
{
	unimplemented_syscall("kill");
	__builtin_unreachable();
}

int _execve(const char *pathname, char *const argv[], char *const envp[]) {
	unimplemented_syscall("execve");
	__builtin_unreachable();
}

int _faccessat(int dirfd, const char *pathname, int mode, int flags)
{
	unimplemented_syscall("faccessat");
	__builtin_unreachable();
}

pid_t _fork(void)
{
	unimplemented_syscall("fork");
	__builtin_unreachable();
}

int _fstatat(int dirfd, const char *restrict pathname, struct stat *restrict statbuf, int flags)
{
	unimplemented_syscall("fstatat");
	__builtin_unreachable();
}

int _ftime(struct timeb *tp)
{
	unimplemented_syscall("ftime");
	__builtin_unreachable();
}

char *_getcwd(char *buf, size_t size)
{
	unimplemented_syscall("getcwd");
	__builtin_unreachable();
}

pid_t _getpid(void)
{
	unimplemented_syscall("getpid");
	__builtin_unreachable();
}

int _isatty(int fd)
{
	unimplemented_syscall("isatty");
	__builtin_unreachable();
}

int _link(const char *oldpath, const char *newpath)
{
	unimplemented_syscall("link");
	__builtin_unreachable();
}

off_t _lseek(int fd, off_t offset, int whence)
{
	unimplemented_syscall("lseek");
	__builtin_unreachable();
}

int _lstat(const char *restrict pathname, struct stat *restrict statbuf)
{
	unimplemented_syscall("lstat");
	__builtin_unreachable();
}

int _open(const char *pathname, int flags, mode_t mode)
{
	unimplemented_syscall("open");
	__builtin_unreachable();
}

int _openat(int dirfd, const char *pathname, int flags, mode_t mode)
{
	unimplemented_syscall("openat");
	__builtin_unreachable();
}

int _stat(const char *restrict pathname, struct stat *restrict statbuf)
{
	unimplemented_syscall("stat");
	__builtin_unreachable();
}

int _unlink(const char *pathname)
{
	unimplemented_syscall("unlink");
	__builtin_unreachable();
}

pid_t _wait(int *wstatus)
{
	unimplemented_syscall("wait");
	__builtin_unreachable();
}

clock_t _times(struct tms *buf)
{
	unimplemented_syscall("times");
	__builtin_unreachable();
}

int _utimes(const char *filename, const struct timeval times[2])
{
	unimplemented_syscall("utimes");
	__builtin_unreachable();
}

long _sysconf(int name)
{
	unimplemented_syscall("sysconf");
	__builtin_unreachable();
}