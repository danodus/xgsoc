# XGSoC 

FPGA based system on chip.

The documentation is available here: https://danodus.github.io/xgsoc/

# Features

- RISC-V (RV32IM)
- UART (1000000-N-8-1)
- SDRAM (32MiB shared between CPU and video)
- Set associative cache (4-way with LRU replacement policy)
- VGA (60 Hz), 480p (60Hz), 720p (60Hz) or 1080p (30Hz) HDMI video output with framebuffer (RGB565)
- Graphite 2D/3D graphics accelerator (textured triangles)
- PS/2 Keyboard
- PS/2 Mouse
- USB host for keyboard and mouse (experimental)
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
make clean;make CONF=<conf> VIDEO=<video mode> prog # for example, CONF=bvkm VIDEO=vga (see below)
cd ../../src/hello
make run SERIAL=<serial device>
picocom -b 1000000 <serial device>
```

### Configurations

| Identifier | Description           |
| ---------- | --------------------- |
| b          | Base (UART, SD Card)  |
| v          | Video                 |
| g          | Graphite              |
| k          | PS/2 Keyboard         |
| m          | PS/2 Mouse            |
| u          | USB Host (*)          |

(*) USB host requires a CPU clock of 48 MHz instead of the default 50 MHz.

By default, the configuration is `bvgkm`.

The following video modes are available:
| Video Mode     | Description    |
| -------------- | ---------------|
| vga            | 640x480 60Hz   |
| 480p           | 848x480 60Hz   |
| 720p           | 1280x720 60Hz  |
| 1080p          | 1920x1080 30Hz |

By default, the video mode is `vga`.

For a 2x zoom, add `2x` at the end of the video mode (for example: `480p2x`).

## System Simulation

```bash
cd src/test_video
make
cd ../../rtl/sim
make run PROGRAM=../../src/test_video/program.hex
```

## Programs

To upload and run the program to the FPGA platform:

```bash
cd src/<program name>
make run SERIAL=<serial device>
picocom -b 1000000 <serial device>
```

The following programs are available:

| Name            | Description                                         | Min. Config.  |
| --------------- | --------------------------------------------------- | ------------- |
| test_mem        | Test memory                                         | `b`           |
| test_fs         | Test filesystem (SD card content erased)            | `b`           |
| bench_dhrystone | Benchmark Dhrystone                                 | `b`           |
| write_sd_image  | Write bootable SD card image (see section below)    | `b`           |
| hello           | Hello world example                                 | `b`           |
| factorial       | Factorial example                                   | `b`           |
| sinus           | Sinus example                                       | `b`           |
| forth           | Forth language                                      | `b`           |
| lua             | Lua language                                        | `b`           |
| test_ps2_kbd    | Test PS/2 keyboard                                  | `bk`          |
| test_ps2_mouse  | Test PS/2 mouse                                     | `bm`          |
| test_usb        | Test USB host                                       | `bu`          |
| test_video      | Test video display                                  | `bv`          |
| test_graphite   | Test graphite subsystem                             | `bvg`         |

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

## Acknowledgements

- The SoC is based on the Oberon project for the ULX3S available here: https://github.com/emard/oberon
- The USB host is based on usb_host available here: https://gitlab.com/pnru/usb_host
