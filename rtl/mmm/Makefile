SITE_MK ?= ../../site.mk

-include $(SITE_MK)

YOSYS := $(OSS_CAD_SUITE_PATH)yosys
ECPPACK := $(OSS_CAD_SUITE_PATH)ecppack
NEXTPNR := $(OSS_CAD_SUITE_PATH)nextpnr-ecp5
OPENFPGALOADER := $(OSS_CAD_SUITE_PATH)openFPGALoader

DEVICE := um-85k
PACKAGE := CABGA381
SPEED := 7

PIN_DEF := mmm.lpf
SRC_CORE := ../../external/xglib/rtl/processor.sv \
		../../external/xglib/rtl/alu.sv \
		../../external/xglib/rtl/decoder.sv \
		../../external/xglib/rtl/register_file.sv \
		../../external/xglib/rtl/sdram_ctrl.v \
		../../external/xglib/rtl/async_fifo.sv \
		../../external/xglib/rtl/async_sdram_ctrl.sv \
		../../external/xglib/rtl/framebuffer.sv \
		../bram.sv \
		../sdram.sv \
		../uart.sv \
		../xga.sv \
		../fifo.sv \
		../ps2kbd.v \
		../hdmi_encoder.v \
		../xgsoc.sv \
		generated_pll.v \
		top.sv

SRC_GRAPHITE :=  ../../external/graphite/rtl/graphite.sv \
		../../external/graphite/rtl/reciprocal.sv

SRC_XOSERA := $(wildcard ../../external/Xosera/rtl/*.sv)

SRC := $(SRC_CORE) $(SRC_XOSERA) $(SRC_GRAPHITE)

DEFINES := -DPS2 -DSD_CARD -DSDRAM -DSD_CARD -DXGA -DNO_CS_BUS_DELAY -DNO_SPRAM -DNO_TESTPATTERN

all: top.bin

$(SITE_MK):
	$(info Copy the example site.template file to site.mk and edit the paths.)
	$(error site.mk not found.)

clean:
	rm -f *.hex *.asc *.json *.bin *.log

top.json: $(SRC) ../../firmware/firmware.hex
	cp ../../firmware/firmware.hex .
	$(YOSYS) -ql top.log -p 'verilog_defines $(DEFINES) ; read_verilog -sv $(SRC); synth_ecp5 -top top -abc9 -json top.json'

top.asc: top.json $(PIN_DEF)
	$(NEXTPNR) -l top_nextpnr.log --$(DEVICE) --package $(PACKAGE) --speed $(SPEED) --json top.json --lpf $(PIN_DEF) --textcfg top.asc --randomize-seed

top.bin: top.asc
	$(ECPPACK) --compress --input top.asc --bit top.bin

prog: top.bin
	$(OPENFPGALOADER) --cable ft4232 top.bin

.PHONY: all prog
