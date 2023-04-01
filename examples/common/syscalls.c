// syscalls.c
// Copyright (c) 2022-2023 Daniel Cliche
// SPDX-License-Identifier: MIT

// An extremely minimalist syscalls.c for newlib
// Based on riscv newlib libgloss/riscv/sys_*.c
// Initial version written by Clifford Wolf.

#include <sys/stat.h>
#include <sys/time.h>
#include <sys/times.h>
#include <sys/timeb.h>
#include <sys/unistd.h>
#include <sys/errno.h>
#include <sys/signal.h>
#include <stddef.h>
#include <string.h>
#include <fcntl.h>
#include <stdbool.h>

#include "sys.h"

#ifdef XIO
#include "xio.h"
#endif

#include "io.h"

#include "fs.h"

#ifndef STDIN_FILENO
#define STDIN_FILENO	0
#endif

#ifndef STDOUT_FILENO
#define STDOUT_FILENO	1
#endif

#ifndef STDERR_FILENO
#define STDERR_FILENO	2
#endif

#define TTYS0_FILENO	3
#define SDFILE0_FILENO	4

#define SYS_MAX_NB_OPEN_FILES 32

// Fixes the __dso_handle not defined with statically allocated standard library object in C++
// Ref.: https://lists.debian.org/debian-gcc/2003/07/msg00070.html
void* __dso_handle = (void*) &__dso_handle;

extern volatile unsigned int counter;

extern int errno;
static void sys_print(const char *s);

static sd_context_t g_sd_ctx;
static fs_context_t g_fs_ctx;
static bool g_volume_mounted = false;

typedef struct {
	char filename[FS_MAX_FILENAME_LEN + 1];
	size_t current_pos;
} file_entry_t;

static file_entry_t g_file_entries[SYS_MAX_NB_OPEN_FILES];

static unsigned int g_tty_mode = 0x0;

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
	// enable timer interrupts
	MEM_WRITE(TIMER_INTR_ENA, 0x1);
	
	// initialize the file entries
	for (size_t i = 0; i < SYS_MAX_NB_OPEN_FILES; ++i)
		g_file_entries[i].filename[0] = '\0';

#ifdef XIO
	// initialize Xosera
	xinit();
#endif
}

static bool mount_volume_if_required()
{
	if (!g_volume_mounted) {
		if (!sd_init(&g_sd_ctx))
			return false;
		if (!fs_init(&g_sd_ctx, &g_fs_ctx))
			return false;
		g_volume_mounted = true;
	}
	return true;
}

void sys_set_tty_mode(unsigned int mode)
{
	g_tty_mode = mode;
}

unsigned int sys_get_tty_mode()
{
	return g_tty_mode;
}

bool sys_fs_format(bool quick)
{
	if (!sd_init(&g_sd_ctx))
		return false;
	return fs_format(&g_sd_ctx, quick);
}

bool sys_fs_unmount()
{
	if (!g_volume_mounted)
		return false;	// volume not mounted
	g_volume_mounted = false;
	return true;
}

uint16_t sys_fs_get_nb_files()
{
	if (!mount_volume_if_required())
		return 0;
	return fs_get_nb_files(&g_fs_ctx);
}

bool sys_fs_get_file_info(uint16_t file_index, fs_file_info_t *file_info)
{
	if (!mount_volume_if_required())
		return false;
	return fs_get_file_info(&g_fs_ctx, file_index, file_info);
}

bool sys_fs_delete(const char *filename)
{
	if (!mount_volume_if_required())
		return false;
	return fs_delete(&g_fs_ctx, filename);
}

bool sys_fs_rename(const char *filename, const char *new_filename)
{
	if (!mount_volume_if_required())
		return false;
	return fs_rename(&g_fs_ctx, filename, new_filename);
}

static size_t get_nb_open_files()
{
	size_t nb_open_files = 0;
	for (size_t i = 0; i < SYS_MAX_NB_OPEN_FILES; ++i)
		if (g_file_entries[i].filename[0])
			nb_open_files++;
	return nb_open_files;
}

static file_entry_t *find_empty_file_entry(size_t *file_entry_index)
{
	for (size_t i = 0; i < SYS_MAX_NB_OPEN_FILES; ++i)
		if (!g_file_entries[i].filename[0]) {
			*file_entry_index = i;
			return &g_file_entries[i];
		}
	return NULL;
}

static char sys_read_char(bool force_serial)
{
	bool is_serial = true;
#ifdef XIO
	// keyboard
	if (!force_serial)
		is_serial = false;
#endif
	char c;
	if (is_serial) {
		// serial port
		c = get_chr();
	} else {
#ifdef XIO
		c = xget_chr();
#endif
	}
	return c;
}

static void sys_write_char(bool force_serial, char c)
{
	bool is_serial = true;
#ifdef XIO
	if (!force_serial)
		is_serial = false;
#endif
	if (is_serial) {
		// serial port
		print_chr(c);
	} else {
#ifdef XIO
		// Xosera
		xprint_chr(c);
#endif
	}
}

static void sys_print(const char *s)
{
	while (*s) {
		sys_write_char(false, *s);
		s++;
	}
}

static size_t sys_read_line(bool force_serial, char *s, size_t buffer_len, bool *eof)
{
	*eof = false;
    size_t len = 0;
    while(1) {
        char c = sys_read_char(force_serial);
		if (c == 4) {
			// EOT
			*eof = true;
			break;
		} else if (c == '\b') {
            if (len > 0) {
                s--;
                len--;
                sys_write_char(force_serial, '\b');
                sys_write_char(force_serial, ' ');
                sys_write_char(force_serial, '\b');
            }
        } else if (c == '\r') {
				sys_write_char(force_serial, '\n');
			if (len < buffer_len) {
				*s = '\n';
				s++;
				len++;
			}
			break;
		} else {
			if (len < buffer_len) {
				sys_write_char(force_serial, c);
				*s = c;
				s++;
				len++;
			}
        }
    }

	return len;
}

static bool file_exists(fs_context_t *ctx, const char *filename)
{
	uint16_t nb_files = fs_get_nb_files(ctx);
	for (uint16_t i = 0; i < nb_files; ++i) {
		fs_file_info_t file_info;
		fs_get_file_info(ctx, i, &file_info);
		if (strcmp(file_info.name, filename) == 0)
			return true;
	}
	return false;
}

int _open(const char *pathname, int flags, mode_t mode)
{
	if (strcmp(pathname, "/dev/ttyS0") == 0) {
		// open serial IO
		return TTYS0_FILENO;
	} else {

		// find an available file entry
		size_t file_entry_index = 0;
		file_entry_t *file_entry = find_empty_file_entry(&file_entry_index);

		if (file_entry == NULL) {
			// too many open files
			errno = EMFILE;
			return -1;
		}

		// mount the volume if required
		if (!mount_volume_if_required()) {
			errno = EIO;
			return -1;
		}

		// if read-only and file does not exist, return error
		if (flags == O_RDONLY) {
			if (!file_exists(&g_fs_ctx, pathname)) {
				errno = ENOENT;
				return -1;
			}
		}

		// initialize the file entry
		strncpy(file_entry->filename, pathname, sizeof(file_entry->filename));
		file_entry->current_pos = 0;

		return SDFILE0_FILENO + (int)file_entry_index;
	}
}

ssize_t _read(int file, void *ptr, size_t len)
{
	if (file == STDIN_FILENO || file == TTYS0_FILENO) {
		if (len == 0)
			return 0;

		if (g_tty_mode & SYS_TTY_MODE_RAW) {
			((char *)ptr)[0] = sys_read_char(file == TTYS0_FILENO);
			return 1;
		}

		char buf[256];
		static bool eof = false;
		if (eof) {
			eof = false;
			if (file == TTYS0_FILENO)
				return 0;
		}
		size_t c = sys_read_line(file == TTYS0_FILENO, buf, 256, &eof);
		if (c > len)
			c = len;
		char *p = (char *)ptr;
		for (size_t i = 0; i < c; ++i)
			p[i] = buf[i];
		return c;
	} else if (file >= SDFILE0_FILENO && file < (SDFILE0_FILENO + SYS_MAX_NB_OPEN_FILES)) {
		if (len == 0)
			return 0;

		size_t file_entry_index = file - SDFILE0_FILENO;
		file_entry_t *file_entry = &g_file_entries[file_entry_index];
		
		size_t nb_read_bytes;
		if (!fs_read(&g_fs_ctx, file_entry->filename, (uint8_t *)ptr, file_entry->current_pos, len, &nb_read_bytes)) {
			errno = EIO;
			return -1;
		}
		file_entry->current_pos += len;
		return nb_read_bytes;
	}
	errno = EBADF;
    return -1;
}

ssize_t _write(int file, const void *ptr, size_t len)
{
	if (file == STDOUT_FILENO || file == STDERR_FILENO || file == TTYS0_FILENO) {
		bool is_serial = true;

#ifdef XIO
		if (file != TTYS0_FILENO)
			is_serial = false;
#endif		

		if (is_serial) {
			// serial port
			print_buf(ptr, len);
		} else {
#ifdef XIO
			// Xosera
			xprint_buf(ptr, len);
#endif
		}
    	return len;
	} else if (file >= SDFILE0_FILENO && file < (SDFILE0_FILENO + SYS_MAX_NB_OPEN_FILES)) {

		size_t file_entry_index = file - SDFILE0_FILENO;
		file_entry_t *file_entry = &g_file_entries[file_entry_index];

		if (!fs_write(&g_fs_ctx, file_entry->filename, (uint8_t *)ptr, file_entry->current_pos, len)) {
			errno = EIO;
			return -1;
		}
		file_entry->current_pos += len;
		return len;
	}
	errno = EBADF;
	return -1;
}

int _close(int file)
{
	if (file >= SDFILE0_FILENO && file < (SDFILE0_FILENO + SYS_MAX_NB_OPEN_FILES)) {
		size_t file_entry_index = file - SDFILE0_FILENO;
		file_entry_t *file_entry = &g_file_entries[file_entry_index];
    	file_entry->filename[0] = '\0';

		if (get_nb_open_files() == 0)
			g_volume_mounted = false;

	    return 0;
	}
	errno = EBADF;
	return -1;
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
	if (fd == SDFILE0_FILENO && fd < (SDFILE0_FILENO + SYS_MAX_NB_OPEN_FILES)) {
		size_t file_entry_index = fd - SDFILE0_FILENO;
		file_entry_t *file_entry = &g_file_entries[file_entry_index];
		switch (whence) {
			case SEEK_SET:
				file_entry->current_pos = (size_t)offset;
				return (off_t)file_entry->current_pos;
			case SEEK_CUR:
				file_entry->current_pos = (size_t)((off_t)file_entry->current_pos + offset);
				return (off_t)file_entry->current_pos;
			case SEEK_END:
				{
					uint16_t nb_files = fs_get_nb_files(&g_fs_ctx);
					for (uint16_t i = 0; i < nb_files; ++i) {
						fs_file_info_t fi;
						fs_get_file_info(&g_fs_ctx, i, &fi);
						if (strcmp(fi.name, file_entry->filename) == 0) {
							file_entry->current_pos = (size_t)((off_t)fi.size + offset);
							return (off_t)file_entry->current_pos;
						}
					}
					errno = EBADF;
					return -1;
				}
			default:
				errno = EINVAL;
				return -1;
		}
	}
	errno = EBADF;
	return -1;
}

int _lstat(const char *restrict pathname, struct stat *restrict statbuf)
{
	unimplemented_syscall("lstat");
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
	clock_t c = (unsigned long long)(counter) * CLK_TCK / 1000;
	if (buf) {
		buf->tms_utime = c;
		buf->tms_stime = 0;
		buf->tms_cutime = 0;
		buf->tms_cstime = 0;
	}
	return c;
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