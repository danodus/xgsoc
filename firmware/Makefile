IVERILOG = iverilog
PYTHON = python3

RISCV_TOOLCHAIN_PATH = /opt/riscv32i/bin/
RISVC_TOOLCHAIN_PREFIX = riscv32-unknown-elf-
AS = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}as
OBJCOPY = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}objcopy
CC = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}gcc

FIRMWARE_SOURCE = start.s firmware.c

all: firmware.hex

firmware: firmware.hex

clean:
	rm -f *.hex *.elf *.bin *.lst

firmware.hex: firmware.bin
	$(PYTHON) makehex.py firmware.bin 1024 > firmware.hex

firmware.bin: firmware.elf
	${OBJCOPY} -O binary firmware.elf firmware.bin

firmware.elf: $(FIRMWARE_SOURCE)
	${CC} -fverbose-asm -Wa,-adhln -nostdlib -O3 -T firmware.ld start.s firmware.c -o firmware.elf > firmware.lst

.PHONY: all clean run firmware
