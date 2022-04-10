PROGRAM = ../../examples/xosera_test/program.hex

VERILATOR = verilator

LDFLAGS := -LDFLAGS "$(shell sdl2-config --libs)"
CFLAGS := -CFLAGS "$(shell sdl2-config --cflags)"

all: sim

clean:
	rm -rf obj_dir

sim: top.sv sim_main.cpp $(PROGRAM)
	cp $(PROGRAM) program.hex
	cp ../../external/Xosera/rtl/*.mem .
	mkdir -p tilesets
	cp ../../external/Xosera/rtl/tilesets/*.mem tilesets
	$(VERILATOR) -cc --exe $(CFLAGS) $(LDFLAGS) top.sv sim_main.cpp -DVGA -DPS2 -DXOSERA -DNO_CS_BUS_DELAY -I.. -I../../external/cpu/rtl -I../../external/graphite/rtl -I../../external/Xosera/rtl -Wno-PINMISSING -Wno-WIDTH -Wno-CASEINCOMPLETE -Wno-TIMESCALEMOD -Wno-NULLPORT
	$(MAKE) -j 4 -C obj_dir -f Vtop.mk

run: sim
	obj_dir/Vtop

.PHONY: all clean
