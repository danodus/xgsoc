VERILATOR = verilator

LDFLAGS := -LDFLAGS "$(shell sdl2-config --libs)"
CFLAGS := -CFLAGS "$(shell sdl2-config --cflags)"

all: sim

clean:
	rm -rf obj_dir

sim: top.sv sim_main.cpp ../../firmware/firmware.hex
	cp ../../firmware/firmware.hex .
	$(VERILATOR) -cc --exe $(CFLAGS) $(LDFLAGS) top.sv sim_main.cpp -I.. -I../../external/cpu/rtl -Wno-PINMISSING -Wno-WIDTH -Wno-CASEINCOMPLETE
	$(MAKE) -j 4 -C obj_dir -f Vtop.mk

run: sim
	obj_dir/Vtop

.PHONY: all clean
