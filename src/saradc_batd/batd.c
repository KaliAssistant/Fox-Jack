#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/file.h>
#include <string.h>
#include <errno.h>
#include <dirent.h>
#include <signal.h>
#include <getopt.h>
#include "ini.h"

#define MAX_TABLE 64
#define MAX_PATH 256
#define SHM_PATH "/dev/shm/bat"
#define SHM_SIZE 128
#define IIO_SARADC_PATH "/sys/bus/iio/devices/iio:device0/in_voltage1_raw"
#define IIO_SARADC_SCALE_PATH "/sys/bus/iio/devices/iio:device0/in_voltage_scale"

#define DEFAULT_CONFIG_PATH "/etc/batd.conf"
const char *config_ini = NULL;

struct VoltageEntry {
    int millivolt;
    int percent;
};

struct Config {
    struct VoltageEntry table[MAX_TABLE];
    int table_len;
};

static struct Config g_config = {0};
static volatile bool keep_running = true;

static void handle_sigint(int sig) {
    (void)sig;
    keep_running = false;
}

int voltage_to_percent(struct Config *cfg, int mV) {
    for (int i = 0; i < cfg->table_len - 1; i++) {
        if (mV >= cfg->table[i + 1].millivolt && mV < cfg->table[i].millivolt) {
            int mv1 = cfg->table[i + 1].millivolt;
            int mv2 = cfg->table[i].millivolt;
            int p1 = cfg->table[i + 1].percent;
            int p2 = cfg->table[i].percent;
            return p1 + (mV - mv1) * (p2 - p1) / (mv2 - mv1);
        }
    }
    return (mV >= cfg->table[0].millivolt) ? 100 : 0;
}

static int __ini_handler(void* user, const char* section, const char* name, const char* value) {
    struct Config* cfg = (struct Config*)user;
    if (strcmp(section, "table") == 0 && cfg->table_len < MAX_TABLE) {
        int mv = atoi(name);
        int percent = atoi(value);
        cfg->table[cfg->table_len].millivolt = mv;
        cfg->table[cfg->table_len].percent = percent;
        cfg->table_len++;
    }
    return 1;
}

static int compare_desc(const void* a, const void* b) {
    const struct VoltageEntry* ea = (const struct VoltageEntry*)a;
    const struct VoltageEntry* eb = (const struct VoltageEntry*)b;
    return eb->millivolt - ea->millivolt;
}

uint8_t *init_bat_shm() {
    int fd = open(SHM_PATH, O_RDWR | O_CREAT, 0644);
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

    if (st.st_size < SHM_SIZE) {
        if (ftruncate(fd, SHM_SIZE) < 0) {
            perror("ftruncate");
            close(fd);
            return NULL;
        }
    }

    // mmap
    uint8_t *bat = mmap(NULL, SHM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (bat == MAP_FAILED) {
        perror("mmap");
        close(fd);
        return NULL;
    }

    close(fd);
    return bat;
}


int main(int argc, char* argv[]) {
    int opt;
    while ((opt = getopt(argc, argv, "c:")) != -1) {
        switch (opt) {
            case 'c': config_ini = optarg; break;
            default:
                fprintf(stderr, "Usage: %s -c <batd config file>\n", argv[0]);
                return 1;
        }
    }

    int lock_fd = open("/var/run/batd.lock", O_CREAT | O_RDWR, 0644);
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
    signal(SIGINT, handle_sigint);
    signal(SIGTERM, handle_sigint);

    if (!config_ini) config_ini = DEFAULT_CONFIG_PATH;
    if (ini_parse(config_ini, __ini_handler, &g_config) < 0) {
        fprintf(stderr, "Can't load config file %s\n", config_ini);
        return 1;
    }

    if (g_config.table_len < 2) {
        fprintf(stderr, "At least two entries in [table] required\n");
        return 1;
    }

    qsort(g_config.table, g_config.table_len, sizeof(struct VoltageEntry), compare_desc);

    FILE* f_v = fopen(IIO_SARADC_PATH, "r");
    FILE* f_s = fopen(IIO_SARADC_SCALE_PATH, "r");
    if (!f_v || !f_s) {
        perror("Failed to open ADC sysfs");
        return 1;
    }

    double scale = 0.0;
    fscanf(f_s, "%lf", &scale);
    fclose(f_s);

    uint8_t* shm_ptr = init_bat_shm();
    if (!shm_ptr) return 1;
    
    while (keep_running) {
        rewind(f_v);
        int raw = 0;
        if (fscanf(f_v, "%d", &raw) == 1) {
            double volt_raw = raw * scale / 1000.0;
            double volt = volt_raw / 0.4;
            int mv = volt * 1000;
            int percent = voltage_to_percent(&g_config, mv);
            snprintf((char *)shm_ptr, SHM_SIZE, "%d%%@%.4fv\n", percent, volt);
        }
        usleep(500000); // 0.5s
    }
    fclose(f_v);
    munmap(shm_ptr, SHM_SIZE);
    return 0;
}
