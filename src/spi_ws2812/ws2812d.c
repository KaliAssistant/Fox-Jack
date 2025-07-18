#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <linux/spi/spidev.h>
#include <sys/ioctl.h>
#include <linux/gpio.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <signal.h>
#include <errno.h>
#include <sys/file.h>  // for flock()


#define SPI_DEV "/dev/spidev0.0"
#define SPI_SPEED 3300000  // 3.3 MHz
#define SPI_BITS 8
#define SHM_PATH "/dev/shm/led_rgb"
#define DELAY_US 2000
#define POWER_PIN_GPIOCHIP "/dev/gpiochip2"
#define POWER_PIN_GPIOCHIP_BASE 64
#define POWER_PIN 72  // 72 --> gpio2_b0_d (17)

int POWER_PIN_GPIO_LINE_OFFEST = (POWER_PIN - POWER_PIN_GPIOCHIP_BASE);

// Lookup table for WS2812 1-bit -> 3 SPI bits
const uint8_t ws2812_lookup[2] = { 0b100, 0b110 };  // 0 = 100, 1 = 110


static volatile int keep_running = 1;

void handle_sigint(int sig) {
    (void)sig;
    keep_running = 0;
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
    int lock_fd = open("/var/run/ws2812d.lock", O_CREAT | O_RDWR, 0644);
    if (lock_fd < 0) {
        perror("open lock file");
        return 1;
    }

    // Try to acquire exclusive lock (non-blocking)
    if (flock(lock_fd, LOCK_EX | LOCK_NB) < 0) {
        if (errno == EWOULDBLOCK) {
            fprintf(stderr, "Another instance is already running.\n");
            return 1;
        } else {
            perror("flock");
            return 1;
        }
    }

    

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
    
    // Optional: Write PID to file
    ftruncate(lock_fd, 0);
    dprintf(lock_fd, "%d\n", getpid());

    // Redirect stdio to /dev/null
    close(0); close(1); close(2);
    open("/dev/null", O_RDONLY);  // stdin
    open("/dev/null", O_WRONLY);  // stdout
    open("/dev/null", O_RDWR);    // stderr

    // Optionally change working dir
    chdir("/");
    
    uint8_t *rgb = init_led_shm();
    if (!rgb) return 1;

    int chip_fd = open(POWER_PIN_GPIOCHIP, O_RDONLY);
    if (chip_fd < 0) {
        perror("open gpiochip");
        return 1;
    }

    struct gpiohandle_request req;
    memset(&req, 0, sizeof(req));
    req.lineoffsets[0] = POWER_PIN_GPIO_LINE_OFFEST;              // GPIO line offset in the chip
    req.flags = GPIOHANDLE_REQUEST_OUTPUT;
    req.default_values[0] = 0;
    req.lines = 1;

    if (ioctl(chip_fd, GPIO_GET_LINEHANDLE_IOCTL, &req) < 0) {
        perror("GPIO_GET_LINEHANDLE_IOCTL");
        close(chip_fd);
        return 1;
    }

    close(chip_fd);  
    
    signal(SIGINT, handle_sigint);

    struct gpiohandle_data g_data = { .values[0] = 1 }; //POWER ON

    if (ioctl(req.fd, GPIOHANDLE_SET_LINE_VALUES_IOCTL, &g_data) < 0) {
        perror("GPIOHANDLE_SET_LINE_VALUES_IOCTL");
        close(req.fd);
        return 1;
    }


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

    while (keep_running) {
        if (memcmp(rgb, last_rgb, 3) != 0) {
            memcpy(last_rgb, rgb, 3);
            send_led(spi_fd, rgb[0], rgb[1], rgb[2]);
        }

        usleep(DELAY_US);  // 10ms polling (can be lower, like 2ms)
    }

    munmap(rgb, 3);
    close(spi_fd);
  
    g_data.values[0] = 0; //POWER OFF
    if (ioctl(req.fd, GPIOHANDLE_SET_LINE_VALUES_IOCTL, &g_data) < 0) {
        perror("GPIOHANDLE_SET_LINE_VALUES_IOCTL");
        close(req.fd);
        return 1;
    }

    close(req.fd);

    return 0;
}

