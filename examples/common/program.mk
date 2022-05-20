SITE_MK ?= ../../site.mk

-include $(SITE_MK)

IVERILOG = iverilog
PYTHON = python3

RISCV_TOOLCHAIN_PATH = /opt/riscv32i/bin/
RISVC_TOOLCHAIN_PREFIX = riscv32-unknown-elf-
AS = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}as
OBJCOPY = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}objcopy
OBJDUMP = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}objdump
CC = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}gcc

PROGRAM_SOURCE = ../common/start.s ../common/syscalls.c ../common/io.c ../common/gamepad.c ../common/kbd.c program.c
SERIAL ?= /dev/tty.usbserial-ibNy7k1v1

LDFILE ?= ../common/program.ld

all: program.hex

$(SITE_MK):
	$(info Copy the example site.template file to site.mk and edit the paths.)
	$(error site.mk not found.)

run: program.hex
	$(PYTHON) ../../utils/sendhex.py $(SERIAL) program.hex $(SEND_DELAY)

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
	${CC} -nostartfiles -O3 -T $(LDFILE) -I ../common $(EXTRA_CC_ARGS) $(PROGRAM_SOURCE) $(EXTRA_SOURCE) -o program.elf -lm

.PHONY: all clean run program
