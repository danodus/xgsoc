SITE_MK ?= ../../site.mk

-include $(SITE_MK)

IVERILOG = iverilog
PYTHON = python3

AS = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}as
OBJCOPY = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}objcopy
OBJDUMP = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}objdump
CC = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}gcc
CXX = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}g++

SRCS = ../common/start.s ../common/syscalls.c ../common/io.c ../common/gamepad.c ../common/kbd.c program.cpp
OBJS := $(SRCS:%=./%.o)
DEPS := $(OBJS:.o=.d)

SERIAL ?= /dev/tty.usbserial-ibNy7k1v1

all: program.hex

$(SITE_MK):
	$(info Copy the example site.template file to site.mk and edit the paths.)
	$(error site.mk not found.)

run: program.hex
	$(PYTHON) ../../utils/sendhex.py $(SERIAL) program.hex 0.0003

program: program.hex

clean:
	rm -f *.hex *.elf *.bin *.lst ../common/*.o *.o

program.lst: program.elf
	${OBJDUMP} --disassemble program.elf > program.lst

program.hex: program.bin
	$(PYTHON) ../../utils/makehex.py program.bin > program.hex

program.bin: program.elf program.lst
	${OBJCOPY} -O binary program.elf program.bin

%.s.o: %.s
	$(AS) -march=rv32i -c $< -o $@

%.c.o: %.c
	${CC} -march=rv32i -O3 -I ../common -c $< -o $@

%.cpp.o: %.cpp
	${CXX} -march=rv32i -O3 -I ../common -c $< -o $@

program.elf: $(OBJS)
	${CC} -march=rv32i -O3 -nostartfiles -T program.ld $(OBJS) -o program.elf -lm -lstdc++

-include $(DEPS)

.PHONY: all clean run program
