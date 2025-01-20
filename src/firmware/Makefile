IVERILOG = iverilog
PYTHON = python3

RISCV_TOOLCHAIN_PATH =
RISCV_TOOLCHAIN_PREFIX = riscv-none-elf-

AS = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}as
OBJCOPY = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objcopy
OBJDUMP = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objdump
CC = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}gcc
RISCV_CC_OPT ?= -march=rv32im -mabi=ilp32

FIRMWARE_SOURCE = start.S ../lib/io.c ../lib/sd_card.c firmware.c

all: firmware.hex

firmware: firmware.hex

clean:
	rm -f *.hex *.elf *.bin *.lst

firmware.lst: firmware.elf
	${OBJDUMP} --disassemble firmware.elf > firmware.lst

firmware.hex: firmware.bin
	$(PYTHON) ../../utils/makehex.py firmware.bin 4096 > firmware.hex

firmware.bin: firmware.elf firmware.lst
	${OBJCOPY} -O binary firmware.elf firmware.bin

firmware.elf: $(FIRMWARE_SOURCE) firmware.ld
	${CC} $(RISCV_CC_OPT) -nostartfiles -nostdlib -Os -T firmware.ld -I ../lib $(FIRMWARE_SOURCE) -o firmware.elf

.PHONY: all clean firmware
