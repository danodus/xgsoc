PROGRAM = ../../src/test_video/program.hex

VERILATOR = verilator

LDFLAGS := -LDFLAGS "$(shell sdl2-config --libs)"
CFLAGS := -CFLAGS "-std=c++14 $(shell sdl2-config --cflags)"

FIRMWARE_DIR ?= ../../src/firmware

SRC = bram32bit.v \
	prom.v \
	uart_tx.v \
	uart_rx.v \
	bram_true2p_2clk.v \
	ps2kbd.v \
	ps2mouse.v \
	spi.v \
	cache_controller.v \
	sdram.v \
	soc_top.sv \
	video.v \
	vqueue.v \
	rgb565_to_rgb888.sv \
	processor.sv \
	bus_arbiter.sv \
  	rv32.sv \
	graphite.sv \
	reciprocal.sv \
	div.sv \
	usb/phy.v \
	usb/regs.v \
	usb/sie.v \
	vdu/vdu.sv \
	vdu/vdu_vram.sv \
	vdu/vdu_display_timings.sv

all: sim

clean:
	rm -rf obj_dir
	rm -f firmware.hex
	rm -f program.hex

firmware:
	make -C $(FIRMWARE_DIR)
	ln -f -s $(FIRMWARE_DIR)/firmware.hex .

sim: top.sv sim_main.cpp $(PROGRAM)
	$(VERILATOR) -cc --exe $(CFLAGS) $(LDFLAGS) --trace --top-module top -DVIDEO -DVIDEO_FB -DVIDEO_GRAPHITE -DVIDEO_QVGA top.sv sdl_ps2.cpp sim_main.cpp -I.. -I../riscv -I../usb -I../vdu -I../../external/graphite/rtl $(SRC) -Wno-PINMISSING -Wno-WIDTH -Wno-TIMESCALEMOD -Wno-NULLPORT
	$(MAKE) -j 4 -C obj_dir -f Vtop.mk

run: firmware sim
	ln -f -s $(PROGRAM) .
	obj_dir/Vtop

.PHONY: all clean firmware
