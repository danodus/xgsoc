YOSYS := yosys
ECPPACK := ecppack
NEXTPNR := nextpnr-ecp5
FUJPROG := fujprog

DEVICE := 85k
PACKAGE := CABGA381

PIN_DEF := ulx3s.lpf
SRC := ../../external/cpu/rtl/processor.sv \
		../../external/cpu/rtl/alu.sv \
		../../external/cpu/rtl/decoder.sv \
		../../external/cpu/rtl/register_file.sv \
		../bram.sv \
		../uart.sv \
		../soc.sv \
		top.sv

all: top.bin

clean:
	rm -f *.hex *.asc *.json *.bin *.log

top.json: $(SRC) ../../firmware/firmware.hex
	cp ../../firmware/firmware.hex .
	$(YOSYS) -ql top.log -p 'synth_ecp5 -top top -json top.json' $(SRC)

top.asc: top.json $(PIN_DEF)
	$(NEXTPNR) -l top_nextpnr.log --$(DEVICE) --package $(PACKAGE) --json top.json --lpf $(PIN_DEF) --textcfg top.asc --randomize-seed

top.bin: top.asc
	$(ECPPACK) --compress --input top.asc --bit top.bin

prog: top.bin
	$(FUJPROG) top.bin

.PHONY: all prog
