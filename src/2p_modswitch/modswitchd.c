#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <signal.h>
#include <errno.h>
#include <linux/gpio.h>
#include <sys/ioctl.h>
#include <sys/file.h>  // for flock()


#define SHM_PATH "/dev/shm/modswitch"
#define DELAY_US 10000
#define GPIOCHIP "/dev/gpiochip2"
#define GPIOCHIP_BASE 64
#define SW1_PIN 67  // 67 --> gpio2_a3_d (27)
#define SW2_PIN 66  // 66 --> gpio2_a2_d (26)
#define GPIO_PULL_MODE 1  // 1 = PULL_UP; 0 = PULL_DOWN
int GPIO_LINE_OFFSETS[2] = {(SW1_PIN - GPIOCHIP_BASE), (SW2_PIN - GPIOCHIP_BASE)};  // offset within chip, e.g., GPIO66, GPIO67 if base is 64



static volatile int keep_running = 1;

void handle_sig_kill(int sig) {
    (void)sig;
    keep_running = 0;
}

uint8_t *init_sw_shm() {
    int fd = open(SHM_PATH, O_RDWR | O_CREAT, 0644);
    if (fd < 0) {
        perror("open/create shared memory");
        return NULL;
    }
    
    struct stat st;
    if (fstat(fd, &st) < 0) {
        perror("fstat");
        close(fd);
        return NULL;
    }

    if (st.st_size < 1) {
        if (ftruncate(fd, 1) < 0) {
            perror("ftruncate");
            close(fd);
            return NULL;
        }
        // Optional: initialize to 0
        write(fd, "\x30", 1);
        lseek(fd, 0, SEEK_SET);
    }

    // mmap
    uint8_t *modswitch = mmap(NULL, 1, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (modswitch == MAP_FAILED) {
        perror("mmap");
        close(fd);
        return NULL;
    }
    
    close(fd);
    return modswitch;
}

int main() {
    int lock_fd = open("/var/run/modswitchd.lock", O_CREAT | O_RDWR, 0644);
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

    
    uint8_t *modswitch = init_sw_shm();
    if (!modswitch) return 1;

    // Open the gpiochip device
    int chip_fd = open(GPIOCHIP, O_RDONLY);
    if (chip_fd < 0) {
        perror("open gpiochip");
        return 1;
    }
  
    struct gpiohandle_request req;
    memset(&req, 0, sizeof(req));

    req.lineoffsets[0] = GPIO_LINE_OFFSETS[0];
    req.lineoffsets[1] = GPIO_LINE_OFFSETS[1];
    req.lines = 2;
    req.flags = GPIOHANDLE_REQUEST_INPUT;

    if (ioctl(chip_fd, GPIO_GET_LINEHANDLE_IOCTL, &req) < 0) {
        perror("GPIO_GET_LINEHANDLE_IOCTL");
        close(chip_fd);
        return 1;
    }

    close(chip_fd); // no longer needed
    
    signal(SIGINT, handle_sig_kill);
    signal(SIGTERM, handle_sig_kill);

    while (keep_running) {
        struct gpiohandle_data data;
        if (ioctl(req.fd, GPIOHANDLE_GET_LINE_VALUES_IOCTL, &data) < 0) {
            perror("GPIOHANDLE_GET_LINE_VALUES_IOCTL");
            break;
        }

        int sw1 = data.values[0];
        int sw2 = data.values[1];

        // Combine into a value 0–3
        uint8_t combined = (((GPIO_PULL_MODE ? !sw2 : sw2) << 1) | (GPIO_PULL_MODE ? !sw1 : sw1)) & 0x03;

        // Write to shared memory
        *modswitch = combined + '0'; // ascii
        usleep(DELAY_US);
    }

    munmap(modswitch, 1);
    close(req.fd);
    return 0;
}



