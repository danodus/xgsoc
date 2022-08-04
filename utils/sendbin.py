import sys
import serial
import time

def send(ser, bytes):
    ser.write(bytes)

def main(argv):
    if (len(argv) < 2):
        print("Usage: sendbin.py <serial device> <bin file>")
        exit(0)
    else:
        try:
            ser = serial.Serial(argv[0], baudrate=115200)
        except serial.serialutil.SerialException:
            print("Unable to open the serial device {0}".format(argv[0]))
            exit(1)
        file = open(argv[1], 'rb')
        data = file.read()
        length = len(data)
        send(ser, length.to_bytes(4, 'big'))
        send(ser, data)
        ser.close()
    exit(0)


if __name__ == "__main__":
    main(sys.argv[1:])
