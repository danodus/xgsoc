PROGRAM = ../../src/test_graphite/program.hex
GRAPHITE_REF_FRAMES = 5
GRAPHITE_TEST_PREFIX = out

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
  	rv32.sv \
	graphite.sv \
	graphite_command_processor.sv \
	graphite_rasterizer.v \
	reciprocal_lerp.v \
	reciprocal_lut.v \
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
	rm -f $(GRAPHITE_TEST_PREFIX)_*.tga

firmware:
	make -C $(FIRMWARE_DIR)
	ln -f -s $(FIRMWARE_DIR)/firmware.hex .

sim: top.sv sim_main.cpp $(PROGRAM)
	$(VERILATOR) -cc --exe $(CFLAGS) $(LDFLAGS) --trace --top-module top -DVIDEO -DVIDEO_FB -DVIDEO_GRAPHITE -DVIDEO_QVGA top.sv sdl_ps2.cpp sim_main.cpp -I.. -I../riscv -I../usb -I../vdu -I../../external/graphite/rtl $(SRC) -Wno-PINMISSING -Wno-WIDTH -Wno-CASEINCOMPLETE -Wno-TIMESCALEMOD -Wno-NULLPORT -Wno-MULTIDRIVEN -Wno-UNOPTFLAT
	$(MAKE) -j 4 -C obj_dir -f Vtop.mk

run: firmware sim
	ln -f -s $(PROGRAM) .
	obj_dir/Vtop

# Compare simulator frame dumps against ref_000.tga .. ref_014.tga (good run).
test-graphite-frames: sim $(PROGRAM)
	@i=0; \
	while [ $$i -lt $(GRAPHITE_REF_FRAMES) ]; do \
		ref=ref_$$(printf '%03d' $$i).tga; \
		if [ ! -f "$$ref" ]; then \
			echo "ERROR: missing reference $$ref"; \
			exit 1; \
		fi; \
		i=$$((i + 1)); \
	done
	rm -f $(GRAPHITE_TEST_PREFIX)_*.tga
	ln -f -s $(PROGRAM) program.hex
	obj_dir/Vtop --dump-frames $(GRAPHITE_REF_FRAMES) --dump-prefix $(GRAPHITE_TEST_PREFIX)
	@fail=0; \
	i=0; \
	while [ $$i -lt $(GRAPHITE_REF_FRAMES) ]; do \
		n=$$(printf '%03d' $$i); \
		ref=ref_$$n.tga; \
		out=$(GRAPHITE_TEST_PREFIX)_$$n.tga; \
		if [ ! -f "$$out" ]; then \
			echo "ERROR: simulator did not write $$out"; \
			fail=1; \
		elif ! cmp -s "$$ref" "$$out"; then \
			echo "ERROR: frame mismatch: $$ref vs $$out"; \
			fail=1; \
		fi; \
		i=$$((i + 1)); \
	done; \
	if [ $$fail -ne 0 ]; then exit 1; fi; \
	echo "OK: $(GRAPHITE_REF_FRAMES) Graphite frames match reference TGAs"

.PHONY: all clean firmware run test-graphite-frames
