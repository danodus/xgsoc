# SOC 

FPGA based system on chip

# Features

- RISC-V CPU (RV32I)
- UART (115200-N-8-1)
- Xosera (audio and video)
- Graphite (3D acceleration)
- PS/2 Keyboard
- USB Gamepad (ULX3S only)

# Requirements

- OSS CAD Suite (https://github.com/YosysHQ/oss-cad-suite-build)
- RISC-V GNU compiler toolchain for RV32I (https://github.com/riscv-collab/riscv-gnu-toolchain)
- SDL2 (for simulation only)

# Getting Started

## Clone and Update

### Clone

```bash
git clone --recurse-submodules https://github.com/dcliche/soc.git
cd soc
```

### Update

```bash
git pull
git submodule update --recursive
```

## Build Firmware

```bash
cd firmware
make
```

## Simulation

Note: Only PS/2 keyboard and Xosera (video) devices are currently simulated.

```
cd examples/<example name>
make
cd ../../rtl/sim
make run PROGRAM=../../examples/<example name>/program.hex
```

## ULX3S

Note: PS/2 PMOD on pins 0-3

```bash
cd rtl/ulx3s
make prog
```

## MMM

Notes:
- iCEBreaker breakaway PMOD (3 buttons) on EXPMOD1
- Digilent PS/2 PMOD on EXPMOD2

```bash
cd rtl/mmm
make prog
```

### iCEBreaker

Note: Only UART

```bash
cd rtl/icebreaker
make prog
```

### Tiny FPGA B2

Notes:
 - Only UART
 - 8 kB of RAM

```bash
cd rtl/tinyfpga_b2
make prog
```

## Examples

To upload the program to the FPGA platform:

```bash
cd examples/<example name>
make run SERIAL=<serial device>
```

The following examples are available:

| Name         | Description                                 | Compatibility    |
| ------------ | ------------------------------------------- | ---------------- |
| hello        | Hello message on UART                       | ULX3S, MMM, IB   |
| sinus        | Sinus waveform on UART                      | ULX3S, MMM, IB   |
| ps2_kbd_test | Test PS/2 keyboard                          | ULX3S, MMM       |
| gamepad_test | Test USB gamepad                            | ULX3S            |
| forth        | Forth language                              | SIM, ULX3S, MMM  |
| basic        | Basic language (WIP)                        | SIM, ULX3S, MMM  |
| xosera_test  | Video and sound test                        | SIM, ULX3S, MMM  |
| draw_cube    | Draw 3D accelerated cube                    | ULX3S, MMM       |
| draw_img     | Draw image in frame buffer (see README.md)  | ULX3S, MMM       |
