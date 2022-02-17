IVERILOG = iverilog
PYTHON = python3

RISCV_TOOLCHAIN_PATH = /opt/riscv32i/bin/
RISVC_TOOLCHAIN_PREFIX = riscv32-unknown-elf-
AS = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}as
OBJCOPY = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}objcopy
CC = ${RISCV_TOOLCHAIN_PATH}${RISVC_TOOLCHAIN_PREFIX}gcc

PROGRAM_SOURCE = start.s program.c
SOC_TB_SOURCE = ../../external/cpu/rtl/alu.sv ../../external/cpu/rtl/register_file.sv ../../external/cpu/rtl/decoder.sv ../../external/cpu/rtl/processor.sv ../memory.sv ../uart.sv ../soc.sv soc_tb.sv

all: firmware.hex soc_tb.out

firmware.hex: ../../firmware/firmware.hex
	cp ../../firmware/firmware.hex .

clean:
	rm -f *.out *.vcd *.hex *.elf *.bin *.lst

soc_tb.out: $(SOC_TB_SOURCE)
	$(IVERILOG) -g2012 -o soc_tb.out $(SOC_TB_SOURCE)

run: firmware.hex soc_tb.out
	vvp soc_tb.out

.PHONY: all clean run
