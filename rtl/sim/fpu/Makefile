# rv32_fpu against Berkeley SoftFloat (RISC-V canonical NaNs).
#
# SoftFloat lives next to this makefile. Build it with the RISC-V specialization
# so quiet NaNs are 0x7fc00000 and integer overflows match the F extension.

ROOT := ../../riscv
SOFTFLOAT := softfloat
SPECIALIZE := RISCV

VERILATOR ?= verilator
SF_INC := $(abspath $(SOFTFLOAT))

.PHONY: all clean softfloat run

all: run

softfloat:
	$(MAKE) -C $(SOFTFLOAT)/build/Linux-x86_64-GCC SPECIALIZE_TYPE=$(SPECIALIZE) softfloat.a

obj_dir/Vfpu_tb: softfloat fpu_tb.cpp $(ROOT)/rv32_fpu.sv
	$(VERILATOR) --cc --exe --build -j 4 --top-module rv32_fpu \
		-CFLAGS "-I$(SF_INC)/source/include -I$(SF_INC)/source/$(SPECIALIZE) -I$(SF_INC)/build/Linux-x86_64-GCC" \
		-LDFLAGS "$(SF_INC)/build/Linux-x86_64-GCC/softfloat.a" \
		-Wno-WIDTH -Wno-UNOPTFLAT -Wno-UNUSED \
		$(ROOT)/rv32_fpu.sv fpu_tb.cpp -o Vfpu_tb

run: obj_dir/Vfpu_tb
	./obj_dir/Vfpu_tb

clean:
	rm -rf obj_dir
	$(MAKE) -C $(SOFTFLOAT)/build/Linux-x86_64-GCC clean || true
