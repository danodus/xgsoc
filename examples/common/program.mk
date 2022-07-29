SITE_MK ?= ../../site.mk

-include $(SITE_MK)

IVERILOG = iverilog
PYTHON = python3

AS = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}as
OBJCOPY = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objcopy
OBJDUMP = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objdump
CC = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}gcc
RISCV_CC_OPT ?= -march=rv32im -mabi=ilp32

PROGRAM_SOURCE = ../common/start.s ../common/fs.c ../common/syscalls.c ../../lib/io.c ../../lib/sd_card.c program.c
SERIAL ?= /dev/tty.usbserial-ibNy7k1v1

LDFILE ?= ../common/program.ld

all: program.hex

$(SITE_MK):
	$(info Copy the example site.template file to site.mk and edit the paths.)
	$(error site.mk not found.)

run: program.hex
	$(PYTHON) ../../utils/sendhex.py $(SERIAL) program.hex

write: program.hex
	$(PYTHON) ../../utils/sendhex.py $(SERIAL) program.hex 0 0.1

program: program.hex

clean:
	rm -f *.hex *.elf *.bin *.lst

program.lst: program.elf
	${OBJDUMP} --disassemble program.elf > program.lst

program.hex: program.bin
	$(PYTHON) ../../utils/makehex.py program.bin > program.hex

program.bin: program.elf program.lst
	${OBJCOPY} -O binary program.elf program.bin

program.elf: $(PROGRAM_SOURCE) $(EXTRA_SOURCE)
	${CC} $(RISCV_CC_OPT) -nostartfiles -O3 -T $(LDFILE) -I ../../lib -I ../common $(EXTRA_CC_ARGS) $(PROGRAM_SOURCE) $(EXTRA_SOURCE) -o program.elf -lm

.PHONY: all clean run write program
