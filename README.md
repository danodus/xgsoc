# SOC 

FPGA based system on chip

# Features

- RISC-V CPU (RV32I)
- UART

# Getting Started

## Requirements

- SDL2
- Verilator 4.213 or above
- RISC-V GNU compiler toolchain for RV32I (https://github.com/riscv-collab/riscv-gnu-toolchain)
- iverilog 12.0 or above (optional)

## Getting Started
```bash
git clone --recurse-submodules https://github.com/dcliche/soc.git
cd firmware
make
cd ../soc/rtl/sim
make run
```
