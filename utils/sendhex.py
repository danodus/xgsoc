import sys
import serial
import time

def send(ser, bytes):
    ser.write(bytes)
    time.sleep(0.001)

def main(argv):
    if (len(argv) < 2):
        print("Usage: sendhex.py <serial device> <hex file>")
        exit(0)
    else:
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
