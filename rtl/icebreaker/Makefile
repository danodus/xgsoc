SITE_MK ?= ../../site.mk

-include $(SITE_MK)

YOSYS := $(OSS_CAD_SUITE_PATH)yosys
ICEPACK := $(OSS_CAD_SUITE_PATH)icepack
NEXTPNR := $(OSS_CAD_SUITE_PATH)nextpnr-ice40
ICEPROG := $(OSS_CAD_SUITE_PATH)iceprog

DEVICE := up5k
PACKAGE := sg48

PIN_DEF := icebreaker.pcf
SRC := ../../external/xglib/rtl/riscv/processor.sv \
		../../external/xglib/rtl/riscv/alu.sv \
		../../external/xglib/rtl/riscv/decoder.sv \
		../../external/xglib/rtl/riscv/register_file.sv \
		../../external/xglib/rtl/riscv/multiplier.v \
		../../external/xglib/rtl/riscv/divider.v \
		../bram.sv \
		../spram.sv \
		../fifo.sv \
		../uart.sv \
		../ps2kbd.v \
		../ps2mouse.v \
		../xgsoc.sv \
		top.sv

DEFINES := -DSPRAM -DSD_CARD -DPS2

all: top.bin

$(SITE_MK):
	$(info Copy the example site.template file to site.mk and edit the paths.)
	$(error site.mk not found.)

clean:
	rm -f *.hex *.asc *.json *.bin *.log

top.json: $(SRC) ../../firmware/firmware.hex
	cp ../../firmware/firmware.hex .
	$(YOSYS) -ql top.log -p 'verilog_defines $(DEFINES) ; read_verilog -sv $(SRC); synth_ice40 -dsp -top top -json top.json' $(SRC)

top.asc: top.json $(PIN_DEF)
	$(NEXTPNR) -l top_nextpnr.log --$(DEVICE) --package $(PACKAGE) --json top.json --pcf $(PIN_DEF) --asc top.asc --randomize-seed

top.bin: top.asc
	$(ICEPACK) -s top.asc top.bin

prog: top.bin
	$(ICEPROG) top.bin

.PHONY: all prog
