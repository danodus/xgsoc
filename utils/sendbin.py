import sys
import serial
import time

packet_size = 4096

def send(ser, bytes):
    for b in bytes:
        ser.write(b.to_bytes(1, 'big'))
        #time.sleep(0.0003)


def crc32b(a):
    crc = 0xffffffff
    for x in a:
        crc ^= x << 24
        for k in range(8):
            crc = (crc << 1) ^ 0x04c11db7 if crc & 0x80000000 else crc << 1
    crc = ~crc
    crc &= 0xffffffff
    return crc


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

        packet_index = 0
        remaining_bytes = length
        while remaining_bytes > 0:

            time.sleep(0.5)

            packet_index_end = packet_index + packet_size
            if packet_index_end > length:
                packet_index_end = length + 1
                
            packet_data = data[packet_index:packet_index_end]
            packet_crc32 = crc32b(packet_data)

            send(ser, packet_crc32.to_bytes(4, 'big'))
            send(ser, packet_data)
            packet_index = packet_index + packet_size

            if remaining_bytes >= packet_size:
                remaining_bytes = remaining_bytes - packet_size
            else:
                remaining_bytes = 0

            print("Packet sent. Remaining bytes: {0}".format(remaining_bytes))
        ser.close()
    exit(0)


if __name__ == "__main__":
    main(sys.argv[1:])
