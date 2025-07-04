#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <linux/spi/spidev.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <signal.h>
#include <errno.h>


#define SPI_DEV "/dev/spidev0.0"
#define SPI_SPEED 3300000  // 3.3 MHz
#define SPI_BITS 8
#define SHM_PATH "/dev/shm/led_rgb"
#define DELAY_US 2000
#define POWER_PIN 72  // 72 --> gpio2_b0_d (17)

// Lookup table for WS2812 1-bit -> 3 SPI bits
const uint8_t ws2812_lookup[2] = { 0b100, 0b110 };  // 0 = 100, 1 = 110


int export_led_pwr_pin() {
    FILE *export_file = fopen("/sys/class/gpio/export", "w");
    if (export_file == NULL) {
        perror("Failed to open GPIO export file");
        return -1;
    }
    fprintf(export_file, "%d", POWER_PIN);
    fclose(export_file);

    char direction_path[50];
    snprintf(direction_path, sizeof(direction_path), "/sys/class/gpio/gpio%d/direction", POWER_PIN);
    FILE *direction_file = fopen(direction_path, "w");
    if (direction_file == NULL) {
        perror("Failed to open GPIO direction file");
        return -1;
    }
    fprintf(direction_file, "out");
    fclose(direction_file);

    char value_path[50];
    snprintf(value_path, sizeof(value_path), "/sys/class/gpio/gpio%d/value", POWER_PIN);
    FILE *value_file = fopen(value_path, "w");
    if (value_file == NULL) {
        perror("Failed to open GPIO value file");
        return -1;
    }
    fprintf(value_file, "1");
    fclose(value_file);
    return 0;
}

int unexport_led_pwr_pin() {
    FILE *unexport_file = fopen("/sys/class/gpio/unexport", "w");
    if (unexport_file == NULL) {
        perror("Failed to open GPIO unexport file");
        return -1;
    }
    fprintf(unexport_file, "%d", POWER_PIN);
    fclose(unexport_file);
    return 0;
}

uint8_t *init_led_shm() {
    int fd = open(SHM_PATH, O_RDWR | O_CREAT, 0666);
    if (fd < 0) {
        perror("open/create shared memory");
        return NULL;
    }

    // Check file size, resize if needed
    struct stat st;
    if (fstat(fd, &st) < 0) {
        perror("fstat");
        close(fd);
        return NULL;
    }

    if (st.st_size < 3) {
        if (ftruncate(fd, 3) < 0) {
            perror("ftruncate");
            close(fd);
            return NULL;
        }
        // Optional: initialize to 0
        write(fd, "\x00\x00\x00", 3);
        lseek(fd, 0, SEEK_SET);
    }

    // mmap
    uint8_t *rgb = mmap(NULL, 3, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (rgb == MAP_FAILED) {
        perror("mmap");
        close(fd);
        return NULL;
    }

    close(fd);
    return rgb;
}

// Encode a single WS2812 byte (8 bits) into 24 SPI bits
void encode_byte(uint8_t byte, uint8_t *spi_bits, int *bit_index) {
    for (int i = 7; i >= 0; i--) {
        uint8_t bit = (byte >> i) & 1;
        uint8_t pattern = ws2812_lookup[bit];
        for (int j = 2; j >= 0; j--) {
            int idx = *bit_index / 8;
            int shift = 7 - (*bit_index % 8);
            spi_bits[idx] |= ((pattern >> j) & 1) << shift;
            (*bit_index)++;
        }
    }
}


void send_led(int spi_fd, uint8_t r, uint8_t g, uint8_t b) {
    uint8_t spi_data[9] = {0};  // 3 colors * 8 bits * 3 = 72 bits = 9 bytes
    int bit_index = 0;

    encode_byte(g, spi_data, &bit_index);  // GRB order
    encode_byte(r, spi_data, &bit_index);
    encode_byte(b, spi_data, &bit_index);

    struct spi_ioc_transfer tr = {
        .tx_buf = (unsigned long)spi_data,
        .len = sizeof(spi_data),
        .speed_hz = SPI_SPEED,
        .bits_per_word = SPI_BITS,
    };

    ioctl(spi_fd, SPI_IOC_MESSAGE(1), &tr);
    usleep(80);  // WS2812 latch (>50us)
}

int main() {

    pid_t pid = fork();
    if (pid < 0) {
        perror("fork failed");
        return 1;
    }
    if (pid > 0) {
        // Parent exits, child continues
        return 0;
    }

    // Become session leader
    if (setsid() < 0) {
        perror("setsid failed");
        return 1;
    }

    // Redirect stdio to /dev/null
    close(0); close(1); close(2);
    open("/dev/null", O_RDONLY);  // stdin
    open("/dev/null", O_WRONLY);  // stdout
    open("/dev/null", O_RDWR);    // stderr

    // Optionally change working dir
    chdir("/");
    
    int init_led_power = export_led_pwr_pin();
    if (init_led_power != 0) return 1;

    uint8_t *rgb = init_led_shm();
    if (!rgb) return 1;


    int spi_fd = open(SPI_DEV, O_WRONLY);
    if (spi_fd < 0) {
        perror("open SPI");
        return 1;
    }

    // Setup SPI
    uint8_t mode = SPI_MODE_0;
    ioctl(spi_fd, SPI_IOC_WR_MODE, &mode);
    ioctl(spi_fd, SPI_IOC_WR_BITS_PER_WORD, &(uint8_t){SPI_BITS});
    ioctl(spi_fd, SPI_IOC_WR_MAX_SPEED_HZ, &(uint32_t){SPI_SPEED});

    // Background loop
    uint8_t last_rgb[3] = {255, 255, 255};  // force initial update

    while (1) {
        if (memcmp(rgb, last_rgb, 3) != 0) {
            memcpy(last_rgb, rgb, 3);
            send_led(spi_fd, rgb[0], rgb[1], rgb[2]);
        }

        usleep(DELAY_US);  // 10ms polling (can be lower, like 2ms)
    }

    munmap(rgb, 3);
    close(spi_fd);
    int deinit_led_power = unexport_led_pwr_pin();
    if (deinit_led_power != 0) return 1;

    return 0;
}

