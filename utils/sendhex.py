import sys
import serial
import time

delay = 0.001

def send(ser, bytes):
    ser.write(bytes)
    time.sleep(delay)

def main(argv):
    if (len(argv) < 2):
        print("Usage: sendhex.py <serial device> <hex file> [delay per word in ms]")
        exit(0)
    else:
        if (len(argv) >= 3):
            global delay
            delay = float(argv[2])

        ser = serial.Serial(argv[0], baudrate=115200)
        file = open(argv[1], 'r')
        lines = file.read().splitlines()
        lines = list(filter(None, lines))   # remove empty lines

        length = len(lines)
        send(ser, length.to_bytes(4, 'big'))

        for line in lines:
            if (line == '0'):
                line = '00000000'
            send(ser, bytearray.fromhex(line))
        ser.close()
    exit(0)


if __name__ == "__main__":
    main(sys.argv[1:])
