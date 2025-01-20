APP          := coremark
MAX_CYCLES   := 100000000

CROSS_PREFIX ?= riscv-none-elf-

PYTHON = python3
SERIAL ?= /dev/tty.usbserial-D00039

###############################################################################

.SUFFIXES:
.PHONY: all bin clean clean_tb run

all: $(APP).hex

$(APP).hex: $(APP).bin
	${PYTHON} ../../utils/makehex.py $(APP).bin > $(APP).hex

bin: $(APP).bin

clean:
	rm -f $(APP).elf $(APP).bin $(APP).lst $(APP).hex
	rm -rf dist/build/

clean_tb: clean
	$(MAKE) -C $(TBDIR) clean

run: $(APP).hex
	$(PYTHON) ../../utils/sendhex.py $(SERIAL) $(APP).hex

write: program.hex
	$(PYTHON) ../../utils/sendhex.py $(SERIAL) program.hex 0 0.1

###############################################################################

$(APP).bin: $(APP).elf
	$(CROSS_PREFIX)objcopy -O binary $^ $@
	$(CROSS_PREFIX)objdump -d $(APP).elf > $(APP).lst

$(APP).elf:
	make -C dist
	cp dist/build/coremark.elf $(APP).elf
