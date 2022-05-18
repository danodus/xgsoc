
import sys
from PIL import Image
import serial
import time

delay = 0.0003

def send(ser, bytes):
    ser.write(bytes)
    time.sleep(delay)


if len(sys.argv) != 3:
    print('Usage: python sendimg.py <serial device> <image filename>')
    sys.exit(1)

im = Image.open(sys.argv[2])

count = 1

rgb_im = im.convert('RGBA')
width, height = rgb_im.size

ser = serial.Serial(sys.argv[1], baudrate=115200)

for y in range(height):
    for x in range(width):
        rgba = rgb_im.getpixel((x, y))
        a = rgba[3] >> 4
        r = rgba[0] >> 4
        g = rgba[1] >> 4
        b = rgba[2] >> 4
        send(ser, bytearray([(a << 4) | (r & 0xF), (g << 4) | (b & 0xF)]))
