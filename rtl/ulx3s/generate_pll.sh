#!/bin/sh

# 640x480
#ecppll -i 25 -o 125 --clkout2 25 --clkout3 75 -f generated_pll.v

# 848x480
ecppll -i 25 -o 168.75 --clkout2 33.75 --clkout3 75 -f generated_pll.v

ecppll -i 25 -o 60 --clkout1 6 -n generated_pll_usb -f generated_pll_usb.v