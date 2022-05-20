SITE_MK ?= ../../site.mk

-include $(SITE_MK)

YOSYS := $(OSS_CAD_SUITE_PATH)yosys
ICEPACK := $(OSS_CAD_SUITE_PATH)icepack
NEXTPNR := $(OSS_CAD_SUITE_PATH)nextpnr-ice40
TINYPROG := $(OSS_CAD_SUITE_PATH)tinyfpgab

DEVICE := lp8k
PACKAGE := cm81

PIN_DEF := tinyfpga_b2.pcf
SRC := ../../external/xglib/rtl/processor.sv \
		../../external/xglib/rtl/alu.sv \
		../../external/xglib/rtl/decoder.sv \
		../../external/xglib/rtl/register_file.sv \
		../bram.sv \
		../uart.sv \
		../xgsoc.sv \
		top.sv

all: top.bin

$(SITE_MK):
	$(info Copy the example site.template file to site.mk and edit the paths.)
	$(error site.mk not found.)

clean:
	rm -f *.hex *.asc *.json *.bin *.log

top.json: $(SRC) ../../firmware/firmware.hex
	cp ../../firmware/firmware.hex .
	$(YOSYS) -ql top.log -p 'synth_ice40 -top top -json top.json' $(SRC)

top.asc: top.json $(PIN_DEF)
	$(NEXTPNR) -l top_nextpnr.log --$(DEVICE) --package $(PACKAGE) --json top.json --pcf $(PIN_DEF) --asc top.asc --randomize-seed

top.bin: top.asc
	$(ICEPACK) -s top.asc top.bin

prog: top.bin
	$(TINYPROG) -p top.bin

.PHONY: all prog
