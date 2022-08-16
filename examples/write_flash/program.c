#include <io.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

#define FLASH   0x20007000  

#define SECTOR_SIZE 65536
#define PAGE_SIZE   256

#define PACKET_SIZE 4096

#define CS_BIT      0x2
#define SCLK_BIT    0x4

#define CS_ENABLE()  { g_cs = CS_BIT; MEM_WRITE(FLASH, g_cs); }
#define CS_DISABLE() { g_cs = 0; MEM_WRITE(FLASH, g_cs); }

#define FLASH_PP            0x02 // program
#define FLASH_4PP           0x12
#define FLASH_RD            0x03
#define FLASH_4RD           0x13
#define FLASH_WRDIS         0x04
#define FLASH_RDSR          0x05
#define FLASH_WREN          0x06
#define FLASH_CLSR          0x30 // clear status register
#define FLASH_BE            0x60 // bulk erase
#define FLASH_SE            0xD8 // sector erase (64kB)
#define FLASH_4SE           0xDC // sector erase (64kB)
#define FLASH_RDID          0x9F
#define FLASH_POWER_UP      0xAB
#define FLASH_POWER_DOWN    0xB9

static uint32_t g_cs = 0;

void printv(const char *m, int v, int base)
{
    print(m);
    char s[32];
    itoa(v, s, base);
    print(s);
    print("\r\n");
}

uint8_t spi_transfer(uint8_t mosi)
{
    uint8_t miso = 0;

    for (int i = 0; i < 8; ++i) {
        miso <<= 1;

        uint32_t b = mosi & 0x80 ? 0x1 : 0x0;
        MEM_WRITE(FLASH, g_cs | b);
        MEM_WRITE(FLASH, g_cs | b | SCLK_BIT);

        uint32_t r = MEM_READ(FLASH);
        miso |= (r & 0x1);

        MEM_WRITE(FLASH, g_cs | b);
        mosi <<= 1;

    }

    return miso;
}

void power_up()
{
    uint8_t rx[3];

    CS_ENABLE();
    spi_transfer(0xFF);
    CS_DISABLE();

    CS_ENABLE();
    spi_transfer(FLASH_POWER_UP);
    CS_DISABLE();
}

void read_identifier(uint8_t id[3])
{
    // Read identifier
    CS_ENABLE();
    spi_transfer(FLASH_RDID);
    id[0] = spi_transfer(0xFF);
    id[1] = spi_transfer(0xFF);
    id[2] = spi_transfer(0xFF);
    CS_DISABLE();
}

void power_down()
{
    CS_ENABLE();
    spi_transfer(FLASH_POWER_DOWN);
    CS_DISABLE();
}

uint8_t read_status_register()
{
    uint8_t rx;
    CS_ENABLE();
    spi_transfer(FLASH_RDSR);
    rx = spi_transfer(0xFF);
    CS_DISABLE();
    return rx;
}

void enable_write()
{
    CS_ENABLE();
    spi_transfer(FLASH_WREN);
    CS_DISABLE();
}

uint8_t wait_until_done()
{
    uint8_t rx;
    // wait until WIP is clear
    do {
        rx = read_status_register();
    } while (rx & 1);
    return rx;
}

void erase_all()
{
    enable_write();

    CS_ENABLE();
    spi_transfer(FLASH_BE);
    CS_DISABLE();

    wait_until_done();
}

bool erase_sector(uint32_t addr)
{
    enable_write();

    CS_ENABLE();
    spi_transfer(FLASH_4SE);
    spi_transfer((uint8_t)(addr >> 24));
    spi_transfer((uint8_t)(addr >> 16));
    spi_transfer((uint8_t)(addr >> 8));
    spi_transfer((uint8_t)(addr));
    CS_DISABLE();

    wait_until_done();

    return true;
}

bool program_page(uint32_t addr, uint8_t *data, size_t size)
{
    if (size > PAGE_SIZE) {
        print("Invalid page size\r\n");
        return false;
    }

    enable_write();

    CS_ENABLE();
    spi_transfer(FLASH_4PP);
    spi_transfer((uint8_t)(addr >> 24));
    spi_transfer((uint8_t)(addr >> 16));
    spi_transfer((uint8_t)(addr >> 8));
    spi_transfer((uint8_t)(addr));

    uint8_t *d = data;
    for (size_t i = 0; i < PAGE_SIZE; ++i) {
        if (i < size) {
            spi_transfer(*d);
            d++;
        } else {
            spi_transfer(0xFF);
        }
    }
    CS_DISABLE();

    wait_until_done();

    return true;
}

void read(uint32_t addr, size_t size, uint8_t *data)
{
    CS_ENABLE();
    spi_transfer(FLASH_4RD);
    spi_transfer((uint8_t)(addr >> 24));
    spi_transfer((uint8_t)(addr >> 16));
    spi_transfer((uint8_t)(addr >> 8));
    spi_transfer((uint8_t)(addr));

    uint8_t *d = data;
    for (size_t i = 0; i < size; ++i) {
        *d = spi_transfer(0xFF);
        d++;
    }
    CS_DISABLE();
}

// Note: size must be a multiple of a sector size
bool program(uint32_t start_addr, size_t size, uint8_t *data, bool erase, bool program, bool verify)
{
    if (erase) {
        // erase sectors
        for (uint32_t addr = start_addr; addr < start_addr + size; addr += SECTOR_SIZE) {
            printv("Erasing sector at address ", addr, 16);
            if (!erase_sector(addr)) {
                print("Unable to erase sector\r\n");
                return false;
            }
        }
    }

    if (program) {
        // program pages
        uint8_t *d = data;
        for (uint32_t addr = start_addr; addr < start_addr + size; addr += PAGE_SIZE) {
            printv("Programming page at address ", addr, 16);
            if (!program_page(addr, d, start_addr + size - addr >= PAGE_SIZE ? PAGE_SIZE : start_addr + size - addr)) {
                print("Unable to program page\r\n");
                return false; 
            }
            d += PAGE_SIZE;
        }
    }

    if (verify) {
        // verify
        uint8_t *d = data;
        for (uint32_t addr = start_addr; addr < start_addr + size; addr += PAGE_SIZE) {
            printv("Verifying data at address ", addr, 16);
            uint8_t rb[PAGE_SIZE];
            read(addr, PAGE_SIZE, rb);
            for (size_t i = 0; i < PAGE_SIZE; i++) {
                uint8_t c = addr + i < start_addr + size ? d[i] : 0xFF;
                if (rb[i] != c) {
                    print("Mismatch detected\r\n");
                    printv("Expected: ", c, 16);
                    printv("Read: ", rb[i], 16);
                    return false;
                }
            }
            d += PAGE_SIZE;
        }
    }

    return true;
}

void dump_mem(uint8_t *b, size_t size)
{
    for (uint32_t addr = 0; addr < size; addr += PAGE_SIZE) {
        printv("Address: ", addr, 16);
        for (size_t i = 0; i < PAGE_SIZE; i++) {
            char s[32];
            itoa(*b, s, 16);
            print(s);
            print(" ");
            b++;
        }
        print("\r\n");
    }
}

void dump_flash(uint32_t start_addr, size_t size)
{
    for (uint32_t addr = start_addr; addr < start_addr + size; addr += PAGE_SIZE) {
        printv("Address: ", addr, 16);
        uint8_t rb[PAGE_SIZE];
        read(addr, PAGE_SIZE, rb);
        for (size_t i = 0; i < PAGE_SIZE; i++) {
            char s[32];
            itoa(rb[i], s, 16);
            print(s);
            print(" ");
        }
        print("\r\n");
    }
}

uint8_t uart_read_byte()
{
    while(!(MEM_READ(UART_STATUS) & 2));
    // dequeue
    MEM_WRITE(UART_STATUS, 0x1);
    return MEM_READ(UART_DATA);
}

uint32_t uart_read_word()
{
    uint32_t word = 0;
    for (int i = 0; i < 4; ++i) {
        word <<= 8;
        uint8_t c = uart_read_byte();
        word |= c;
    }
    return word;
}

// Ref.: https://stackoverflow.com/questions/50842434/crc32-in-python-vs-crc32b
uint32_t crc32b(uint32_t crc, void const *mem, size_t len) {
    unsigned char const *data = mem;
    if (data == NULL)
        return 0;
    crc = ~crc;
    while (len--) {
        crc ^= (unsigned)(*data++) << 24;
        for (unsigned k = 0; k < 8; k++)
            crc = crc & 0x80000000 ? (crc << 1) ^ 0x4c11db7 : crc << 1;
    }
    crc = ~crc;
    return crc;
}

bool uart_read(uint8_t **buf, uint32_t *size)
{
    uint32_t rx_size = uart_read_word();
    printv("Size: ", rx_size, 10);

    *size = rx_size;

    uint32_t nb_packets = (rx_size + (PACKET_SIZE - 1)) / PACKET_SIZE;

    *buf = malloc(*size);
    if (*buf == NULL) {
        print("Unable to allocate the buffer\r\n");
        return false;
    }

    uint8_t *b = *buf;
    uint8_t *packet_start = *buf;
    uint32_t remaining_bytes = rx_size;
    while (remaining_bytes > 0) {
        uint32_t packet_size = remaining_bytes >= PACKET_SIZE ? PACKET_SIZE : remaining_bytes;
        uint32_t expected_crc32 = uart_read_word();
        for (uint32_t i = 0; i < packet_size; ++i) {
            *b = uart_read_byte();
            b++;
        }

        // Compare CRC-32
        uint32_t crc32 = crc32b(0, packet_start, packet_size);
        if (crc32 != expected_crc32) {
            print("CRC-32 mismatch detected\r\n");
            printv("expected: 0x", expected_crc32, 16);
            printv("received: 0x", crc32, 16);
            return false;
        }

        packet_start += PACKET_SIZE;
        remaining_bytes -= packet_size;

        printv("Packet OK. Remaining bytes: ", remaining_bytes, 10);
    }

    print("Valid payload received.\r\n");

    return true;
}

void main(void)
{
    print("Write Flash\r\n");

    power_up();

    uint8_t id[3];
    read_identifier(id);
    printv("ID[0]: ", id[0], 16);
    printv("ID[1]: ", id[1], 16);
    printv("ID[2]: ", id[2], 16);

    //print("Erase all...\r\n");
    //erase_all();

    print("Ready to receive the bitstream...\r\n");

    uint8_t *buf = NULL;
    uint32_t size;
    if (!uart_read(&buf, &size))
        goto exit;

    print("Bitstream received.\r\n");

    //dump_mem(buf, SECTOR_SIZE);    

    print("Writing to flash...\r\n");

    if (!program(0, size, buf, true, true, true)) {
        print("Unable to program\r\n");
        goto exit;            
    }

    //dump_flash(0, SECTOR_SIZE);

    print("Success!\r\n");

exit:

    if (buf)
        free(buf);

    power_down();

    print("Press reset button...\r\n");
    for (;;);
}
