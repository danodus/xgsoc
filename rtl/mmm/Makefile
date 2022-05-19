YOSYS := yosys
ECPPACK := ecppack
NEXTPNR := nextpnr-ecp5
OPENFPGALOADER := openFPGALoader

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
		../uart.sv \
		../vga_timings.sv \
		../vga.sv \
		../vram2.sv \
		../fifo.sv \
		../ps2kbd.v \
		../hdmi_encoder.v \
		../soc.sv \
		generated_pll.v \
		top.sv

SRC_GRAPHITE :=  ../../external/graphite/rtl/graphite.sv \
		../../external/graphite/rtl/reciprocal.sv		

SRC_XOSERA := $(wildcard ../../external/Xosera/rtl/*.sv)

SRC := $(SRC_CORE) $(SRC_XOSERA) $(SRC_GRAPHITE)

DEFINES := -DPS2 -DVGA -DXOSERA -DNO_CS_BUS_DELAY -DGRAPHITE

all: top.bin

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
	$(OPENFPGALOADER) --verbose --cable ft4232 top.bin

.PHONY: all prog
