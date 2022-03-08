YOSYS := yosys
ICEPACK := icepack
NEXTPNR := nextpnr-ice40
ICEPROG := iceprog

DEVICE := up5k
PACKAGE := sg48

PIN_DEF := icebreaker.pcf
SRC := ../../external/cpu/rtl/processor.sv \
		../../external/cpu/rtl/alu.sv \
		../../external/cpu/rtl/decoder.sv \
		../../external/cpu/rtl/register_file.sv \
		../bram.sv \
		../spram.sv \
		../uart.sv \
		../soc.sv \
		../vga_timings.sv \
		../vga.sv \
		clock_gen_480p.sv \
		top.sv

all: top.bin

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
	$(ICEPROG) top.bin

.PHONY: all prog
