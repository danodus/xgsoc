SITE_MK ?= ../../site.mk

-include $(SITE_MK)

YOSYS := $(OSS_CAD_SUITE_PATH)yosys
ECPPACK := $(OSS_CAD_SUITE_PATH)ecppack
NEXTPNR := $(OSS_CAD_SUITE_PATH)nextpnr-ecp5
FUJPROG := $(OSS_CAD_SUITE_PATH)fujprog

DEVICE := 85k
PACKAGE := CABGA381

PIN_DEF := ulx3s.lpf
SRC_CORE := ../../external/xglib/rtl/riscv/processor.sv \
		../../external/xglib/rtl/riscv/alu.sv \
		../../external/xglib/rtl/riscv/decoder.sv \
		../../external/xglib/rtl/riscv/register_file.sv \
		../../external/xglib/rtl/riscv/multiplier.v \
		../../external/xglib/rtl/riscv/divider.v \
		../../external/xglib/rtl/sdram_ctrl.v \
		../../external/xglib/rtl/cache_ctrl.v \
		../../external/xglib/rtl/display_timings.sv \
		../sdram.sv \
		../bram.sv \
		../uart.sv \
		../xga.sv \
		../vga.sv \
		../fifo.sv \
		../ps2kbd.v \
		../ps2mouse.v \
		../hdmi_encoder.v \
		../xgsoc.sv \
		../usb/usb_phy.v \
		../usb/usb_rx_phy.v \
		../usb/usb_tx_phy.v \
		../usb/usbh_crc5.v \
		../usb/usbh_crc16.v \
		../usb/usbh_host_hid.v \
		../usb/usbh_sie.v \
		generated_pll_main.v \
		generated_pll_video.v \
		generated_pll_usb.v \
		top.sv

SRC_XOSERA := $(wildcard ../../external/Xosera/rtl/*.sv)

SRC := $(SRC_CORE) $(SRC_XOSERA)
#SRC := $(SRC_CORE)

DEFINES := -DUSB -DPS2 -DSDRAM -DSD_CARD -DFLASH -DXGA -DNO_TESTPATTERN -DEN_PF_B -DEN_PF_B_BLEND -DEN_AUDIO=4 -DMODE_848x480
#DEFINES := -DUSB -DPS2 -DSDRAM -DSD_CARD -DVGA

all: top.bin

$(SITE_MK):
	$(info Copy the example site.template file to site.mk and edit the paths.)
	$(error site.mk not found.)

clean:
	rm -f *.hex *.asc *.json *.bin *.log

top.json: $(SRC) ../../firmware/firmware.hex
	cp ../../firmware/firmware.hex .
	$(YOSYS) -ql top.log -p 'verilog_defines $(DEFINES) ; read_verilog -sv $(SRC); synth_ecp5 -top top -json top.json'

top.asc: top.json $(PIN_DEF)
	$(NEXTPNR) -l top_nextpnr.log --$(DEVICE) --package $(PACKAGE) --json top.json --lpf $(PIN_DEF) --textcfg top.asc --randomize-seed

top.bin: top.asc
	$(ECPPACK) --compress --input top.asc --bit top.bin

prog: top.bin
	$(FUJPROG) -T bit top.bin

.PHONY: all prog
