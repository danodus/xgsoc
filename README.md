# XGSoC 

FPGA based system on chip with audio, video and 3D acceleration.

# Features

- RISC-V CPU (RV32I)
- UART (115200-N-8-1)
- SDRAM (16MB, ULX3S and MMM only)
- XGA (ULX3S and MMM only):
  - Xosera (audio and video, 128kB VRAM)
  - Graphite (3D acceleration, 16MB frame buffer)
- PS/2 Keyboard (ULX3S and MMM only)
- SD Card (ULX3S and MMM only)
- USB Gamepad (ULX3S only)

# Requirements

- OSS CAD Suite (https://github.com/YosysHQ/oss-cad-suite-build)
- RISC-V GNU compiler toolchain for RV32I (https://github.com/riscv-collab/riscv-gnu-toolchain)
- Python3 with the following PIP3 packages installed: `pyserial`, `pillow`
- SDL2 (for simulation only)

# Getting Started

## Clone and Update

### Clone

```bash
git clone --recurse-submodules https://github.com/dcliche/xgsoc.git
cd xgsoc
```

If the repository has been cloned without the `--recurse-submodules` option, do the following:
```
git submodule update --init
```

### Update

```bash
git pull
git submodule update --recursive
```

## Build Firmware

Copy the example `site.template` file to `site.mk` and edit the paths.

```bash
cd firmware
make
```

## Simulation

Notes:
- Only PS/2 keyboard and XGA (video and 3D acceleration) devices are currently simulated
- Press F12 to restart the simulation

```
cd examples/<example name>
make
cd ../../rtl/sim
make run PROGRAM=../../examples/<example name>/program.hex
```

Suggested example for simulation: forth

## ULX3S

Note: PS/2 PMOD on pins 0-3

```bash
cd rtl/ulx3s
make prog
```

## MMM

Two hardware configurations are supported with the HEX knob:

| Position  | Hardware Configuration                                                        |
| --------- | -------------------------------------------------------------------------------
| 0         | Digilent PS/2 PMOD on EXPMOD2                                                 |
| 1         | - iCEBreaker breakaway PMOD on EXPMOD1 (reset with button 1)<br>- Digilent PS/2 PMOD on EXPMOD2 |

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

| Name         | Description                                         | Compatibility    |
| ------------ | --------------------------------------------------- | ---------------- |
| hello        | Hello message (output on UART)                      | ULX3S, MMM, IB   |
| sinus        | Sinus waveform on (output on UART)                  | ULX3S, MMM, IB   |
| test_mem     | Test 16MB of SDRAM (output on UART)                 | ULX3S, MMM       |
| ps2_kbd_test | Test PS/2 keyboard (output on UART)                 | ULX3S, MMM       |
| sd_card_test | Test SD card (output on UART, card content erased!) | ULX3S, MMM       |
| gamepad_test | Test USB gamepad                                    | ULX3S            |
| forth        | Forth language                                      | SIM, ULX3S, MMM  |
| lua          | Lua language                                        | SIM, ULX3S, MMM  |
| xosera_test  | Video and sound test                                | SIM, ULX3S, MMM  |
| draw_cube    | Draw 3D accelerated cube                            | SIM, ULX3S, MMM  |
| draw_teapot  | Draw 3D accelerated teapot                          | SIM, ULX3S, MMM  |
| draw_img     | Draw image in frame buffer (see README.md)          | ULX3S, MMM       |
| cpp_test     | C++ test with standard library                      | SIM, ULX3S, MMM  |
