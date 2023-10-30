PROGRAM = ../../examples/forth/program.hex

VERILATOR = verilator

LDFLAGS := -LDFLAGS "$(shell sdl2-config --libs)"
CFLAGS := -CFLAGS "$(shell sdl2-config --cflags)"

XOSERA_SRCDIR = ../../external/Xosera/rtl
XOSERA_SRC := $(XOSERA_SRCDIR)/xosera_main.sv $(filter-out $(XOSERA_SRCDIR)/xosera_main.sv,$(wildcard $(XOSERA_SRCDIR)/*.sv))

all: sim

clean:
	rm -rf obj_dir

sim: top.sv sim_main.cpp $(PROGRAM)
	cp $(PROGRAM) program.hex
	cp ../../external/Xosera/rtl/*.mem .
	mkdir -p tilesets
	cp ../../external/Xosera/rtl/tilesets/*.mem tilesets
	$(VERILATOR) -cc --exe $(CFLAGS) $(LDFLAGS) --top-module top $(XOSERA_SRC) top.sv sdl_ps2.cpp sim_main.cpp -DSDRAM -DPS2 -DXGA -DEN_PF_B -DEN_PF_B_BLEND -DMODE_848x480 -DNO_COPPER_INIT -I.. -I../../external/xglib/rtl -I../../external/Xosera/rtl -Wno-PINMISSING -Wno-WIDTH -Wno-CASEINCOMPLETE -Wno-TIMESCALEMOD -Wno-NULLPORT -Wno-MULTIDRIVEN
	$(MAKE) -j 4 -C obj_dir -f Vtop.mk

run: sim
	obj_dir/Vtop

.PHONY: all clean
