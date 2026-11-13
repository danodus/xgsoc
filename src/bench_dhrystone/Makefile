EXTRA_CC_ARGS = -Wno-switch -Wno-implicit-function-declaration -Wno-implicit-int
include ../program.mk

# Dhrystone 2.1 uses K&R "()" declarations; compile benchmark sources as gnu89 only.
DHRY_SRC = dhry_1.c dhry_2.c
DHRY_OBJ = $(DHRY_SRC:.c=.o)
DHRY_CC_ARGS = -std=gnu89 -Wno-builtin-declaration-mismatch -Wno-old-style-definition

$(DHRY_OBJ): %.o: %.c
	${CC} $(RISCV_CC_OPT) -O3 -I ../lib $(EXTRA_CC_ARGS) $(DHRY_CC_ARGS) -c $< -o $@

LIB_SOURCE = ../lib/start.S ../lib/io.c ../lib/sd_card.c ../lib/fs.c ../lib/syscalls.c

program.elf: $(LIB_SOURCE) $(DHRY_OBJ)
	${CC} $(RISCV_CC_OPT) -nostartfiles -O3 -T $(LDFILE) -I ../lib $(EXTRA_CC_ARGS) $(LIB_SOURCE) $(DHRY_OBJ) -o program.elf -lm

clean:
	rm -f *.hex *.elf *.bin *.lst $(DHRY_OBJ)
