# SOC 

FPGA based system on chip

# Features

- RISC-V CPU (RV32I)
- UART (115200-N-8-1)
- Xosera (audio and video)
- Graphite (3d acceleration)
- PS/2 Keyboard
- USB Gamepad (ULX3S only)

# Requirements

- OSS CAD Suite (https://github.com/YosysHQ/oss-cad-suite-build)
- RISC-V GNU compiler toolchain for RV32I (https://github.com/riscv-collab/riscv-gnu-toolchain)
- SDL2 (for simulation only)

# Getting Started

## Clone 

```bash
git clone --recurse-submodules https://github.com/dcliche/soc.git
```

## Build Firmware

```bash
cd soc/firmware
make
```

## Simulation

```
cd rtl/sim
make run
```

## ULX3S

Note: PS/2 PMOD on pins 0-3

```bash
cd rtl/ulx3s
make prog
```

## MMM

Note: PS/2 PMOD on EXPMOD2

```bash
cd rtl/mmm
make prog
```

## Running Examples

```bash
cd examples/<example name>
make run SERIAL=<serial device>
```

The following examples are available:

| Name         | Description            | Compatibility |
| ------------ | ---------------------- | ------------- |
| hello        | Hello message on UART  | all           |
| sinus        | Sinus waveform on UART | all           |
| ps2_kbd_test | Test PS/2 keyboard     | ULX3S, MMM    |
| gamepad_test | Test USB gamepad       | ULX3S         |
| forth        | Forth language         | ULX3S, MMM    |
| basic        | Basic language (WIP)   | ULX3S, MMM    |
