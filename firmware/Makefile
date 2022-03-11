IVERILOG = iverilog
PYTHON = python3

RISCV_TOOLCHAIN_PATH = /opt/riscv32i/bin/
RISVC_TOOLCHAIN_PREFIX = riscv32-unknown-elf-
AS = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}as
OBJCOPY = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}objcopy
OBJDUMP = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}objdump
CC = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}gcc

FIRMWARE_SOURCE = start.s firmware.c

all: firmware.hex

firmware: firmware.hex

clean:
	rm -f *.hex *.elf *.bin *.lst

firmware.lst: firmware.elf
	${OBJDUMP} --disassemble firmware.elf > firmware.lst

firmware.hex: firmware.bin
	$(PYTHON) ../utils/makehex.py firmware.bin 1024 > firmware.hex

firmware.bin: firmware.elf firmware.lst
	${OBJCOPY} -O binary firmware.elf firmware.bin

firmware.elf: $(FIRMWARE_SOURCE)
	${CC} -nostartfiles -nostdlib -O3 -T firmware.ld start.s firmware.c -o firmware.elf

.PHONY: all clean firmware
