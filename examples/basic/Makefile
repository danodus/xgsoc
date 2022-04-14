IVERILOG = iverilog
PYTHON = python3

RISCV_TOOLCHAIN_PATH = /opt/riscv32i/bin/
RISVC_TOOLCHAIN_PREFIX = riscv32-unknown-elf-
AS = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}as
OBJCOPY = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}objcopy
OBJDUMP = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}objdump
CC = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}gcc

PROGRAM_SOURCE = ../common/start.s            \
	../common/io.c                            \
	../common/kbd.c                           \
	../common/syscalls.c					  \
	xio.c									  \
	tokenizer.c                               \
	ubasic.c                                  \
	program.c

SERIAL ?= /dev/tty.usbserial-D00039

all: program.hex

run: program.hex
	$(PYTHON) ../../utils/sendhex.py $(SERIAL) program.hex 0.0003

program: program.hex

clean:
	rm -f *.hex *.elf *.bin *.lst

program.lst: program.elf
	${OBJDUMP} --disassemble program.elf > program.lst

program.hex: program.bin
	$(PYTHON) ../../utils/makehex.py program.bin > program.hex

program.bin: program.elf program.lst
	${OBJCOPY} -O binary program.elf program.bin

program.elf: $(PROGRAM_SOURCE)
	${CC} -nostartfiles -O3 -T ../common/program.ld -I ../common -I ../../external/graphite/common $(PROGRAM_SOURCE) -o program.elf -lm

.PHONY: all clean run program
