YOSYS := $(OSS_CAD_SUITE_PATH)yosys
ECPPACK := $(OSS_CAD_SUITE_PATH)ecppack
NEXTPNR := $(OSS_CAD_SUITE_PATH)nextpnr-ecp5
OPENFPGALOADER := $(OSS_CAD_SUITE_PATH)openFPGALoader

VIDEO = vga
CONF = bvgkm

# 12 25 45 85
DEVICE := 25k
PACKAGE := CABGA256

PIN_DEF := icepi-zero.lpf
TOP_MODULE = icepi_zero_top
TOP_MODULE_FILE = $(TOP_MODULE).sv

FIRMWARE_DIR ?= ../../src/firmware

SRC = \
  $(TOP_MODULE_FILE) \
  pll_main.v \
  ../soc_top.sv \
  ../prom.v \
  ../cache_controller.v \
  ../sdram.v \
  ../ps2kbd.v \
  ../ps2mouse.v \
  ../uart_rx.v \
  ../uart_tx.v \
  ../spi.v \
  ../riscv/processor.v \
  ../video.v \
  ../rgb565_to_rgb888.sv \
  ../bram32bit.v \
  ../lattice/ecp5pll.sv \
  ../bram_true2p_2clk.v \
  ../vqueue.v \
  ../vdu/vdu.sv \
  ../vdu/vdu_vram.sv \
  ../vdu/vdu_display_timings.sv \
  ../dvi/hdmi_interface.v \
  ../../external/graphite/rtl/graphite.sv \
  ../../external/graphite/rtl/reciprocal.sv \
  ../../external/graphite/rtl/div.sv

DEFINES =

ifneq (,$(findstring v,$(CONF)))
  DEFINES += -DVIDEO

  ifneq (,$(findstring d,$(CONF)))
    DEFINES += -DVIDEO_VDU
  else
    DEFINES += -DVIDEO_FB
  endif

  ifneq (,$(findstring g,$(CONF)))
    DEFINES += -DVIDEO_GRAPHITE
  endif

  ifeq ($(VIDEO),qvga)
  DEFINES += -DVIDEO_QVGA
  endif

  ifeq ($(VIDEO),vga)
  DEFINES += -DVIDEO_VGA
  endif

  ifeq ($(VIDEO),480p)
  DEFINES += -DVIDEO_480P
  endif

  ifeq ($(VIDEO),720p)
  DEFINES += -DVIDEO_720P
  endif

  ifeq ($(VIDEO),1080p)
  DEFINES += -DVIDEO_1080P
  endif

endif

ifneq (,$(findstring k,$(CONF)))
  DEFINES += -DPS2_KBD
endif

ifneq (,$(findstring m,$(CONF)))
  DEFINES += -DPS2_MOUSE
endif

all: firmware top.bin

clean:
	rm -f *.hex *.asc *.json *.bin *.log

firmware:
	make -C $(FIRMWARE_DIR)
	cp $(FIRMWARE_DIR)/firmware.hex .

top.json: $(SRC)
	$(YOSYS) -ql top.log -p 'verilog_defines $(DEFINES) ; read_verilog -sv $(SRC); synth_ecp5 -top $(TOP_MODULE) -json top.json -abc9'

top.asc: top.json $(PIN_DEF)
	$(NEXTPNR) -l top_nextpnr.log --$(DEVICE) --package $(PACKAGE) --json top.json --lpf $(PIN_DEF) --textcfg top.asc --randomize-seed --timing-allow-fail

top.bin: top.asc
	$(ECPPACK) --compress --input top.asc --bit top.bin

prog: firmware top.bin
	$(OPENFPGALOADER) -cft231X --pins=7:3:5:6 top.bin

flash: firmware top.bin
	$(OPENFPGALOADER) -cft231X --pins=7:3:5:6 top.bin --write-flash

.PHONY: all prog flash firmware
