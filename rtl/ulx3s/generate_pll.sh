#!/bin/sh

ecppll -i 25 -o 125 --clkout2 25 --clkout3 60 -f generated_pll.v
ecppll -i 25 -o 60 --clkout1 6 -n generated_pll_usb -f generated_pll_usb.v