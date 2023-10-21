#!/bin/sh

ecppll -i 25 -o 75 --clkout2 33.75 -n generated_pll_main -f generated_pll_main.v

# 640x480
#ecppll -i 25 -o 125 --clkout2 25 -n generated_pll_video -f generated_pll_video.v

# 848x480
ecppll -i 25 -o 168.75 --clkout2 33.75 -n generated_pll_video -f generated_pll_video.v

ecppll -i 25 -o 60 --clkout1 6 -n generated_pll_usb -f generated_pll_usb.v