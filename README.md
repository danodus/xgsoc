# XGSoC 

FPGA based system on chip.

# Features

- RISC-V (RV32IM)
- UART (2000000-N-8-1)
- SDRAM (32MiB shared between CPU and video)
- Set associative cache (4-way with LRU replacement policy)
- VGA (60 Hz), 480p (60Hz), 720p (60Hz) or 1080p (30Hz) HDMI video output with framebuffer (RGB565)
- 2D/3D graphics accelerator (textured triangles)
- USB host for keyboard and mouse
- SD Card with hardware SPI

# Requirements

- OSS CAD Suite (https://github.com/YosysHQ/oss-cad-suite-build) (*)
- xPack RISC-V Embedded GCC (https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases) (*)
- Python3 with the following PIP3 packages installed: `pyserial`
- picocom
- SDL2 (for simulation only)

(*) Extract and add the `bin` directory to the path.

Note: Tested with `oss-cad-suite-darwin-arm64-20240810` and `xpack-riscv-none-elf-gcc-14.2.0-1-darwin-arm64`.

# Getting Started

## Clone and Update

### Clone

```bash
git clone --recurse-submodules https://github.com/danodus/xgsoc.git
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

## Getting Started on ULX3S

```bash
cd rtl/ulx3s
make clean;make VIDEO=<video mode> prog
cd ../../src/examples/test_graphite
make run SERIAL=<serial device>
picocom -b 2000000 <serial device>
```

and press 'h' for help.

The following video modes are available:
| Video Mode     | Description    |
| -------------- | ---------------|
| vga (default)  | 640x480 60Hz   |
| 480p           | 848x480 60Hz   |
| 720p           | 1280x720 60Hz  |
| 1080p          | 1920x1080 30Hz |

## System Simulation

```bash
cd src/test_video
make
cd ../../rtl/sim
make run PROGRAM=../../src/test_video/program.hex
```

## Programs

To upload the program to the FPGA platform:

```bash
cd src/<program name>
make run SERIAL=<serial device>
```

The following programs are available:

| Name            | Description                                         | Compatibility    |
| --------------- | --------------------------------------------------- | ---------------- |
| test_video      | Test video display                                  | ULX3S, MMM       |
| test_graphite   | Test graphite subsystem                             | ULX3S, MMM       |
| write_sd_image  | Write bootable SD card image (see section below)    | ULX3S, MMM       |

# Write Bootable Image

- Insert the SD card
- Open a serial terminal
- Start the image writer utility:
```bash
cd src/write_sd_image
make run SERIAL=<serial device>
```
- Send the data to write:
```
cd ../<program name>
make write SERIAL=<serial device>
```
Press a key when completed. The SD card image will automatically be read and executed unless a key is sent via UART during the first seconds of the boot process.
