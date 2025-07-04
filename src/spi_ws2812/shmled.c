#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <getopt.h>
#include <math.h>

#define SHM_PATH "/dev/shm/led_rgb"

uint8_t color[3] = {0, 0, 0};
int loop = 0;
int blink = 0;
int fade = 0;
int rainbow = 0;
int delay_us = 500000;
const char *input_file = NULL;

int parse_hex_color(const char *hex) {
    if (hex[0] != '#' || strlen(hex) != 7) return -1;
    for (int i = 1; i < 7; ++i)
        if (!isxdigit(hex[i])) return -1;

    sscanf(hex + 1, "%2hhx%2hhx%2hhx", &color[0], &color[1], &color[2]);  // R G B
    return 0;
}

int write_rgb(uint8_t r, uint8_t g, uint8_t b) {
    int fd = open(SHM_PATH, O_WRONLY);
    if (fd < 0) {
        perror("open");
        return -1;
    }

    uint8_t buf[3] = {r, g, b};
    int res = pwrite(fd, buf, 3, 0);
    close(fd);
    return res == 3 ? 0 : -1;
}

void do_blink() {
    while (1) {
        write_rgb(color[0], color[1], color[2]);
        usleep(delay_us);
        write_rgb(0, 0, 0);
        usleep(delay_us);
    }
}

void do_fade() {
    while (1) {
        for (int i = 0; i <= 255; ++i) {
            write_rgb((color[0] * i) / 255, (color[1] * i) / 255, (color[2] * i) / 255);
            usleep(delay_us / 256);
        }
        for (int i = 255; i >= 0; --i) {
            write_rgb((color[0] * i) / 255, (color[1] * i) / 255, (color[2] * i) / 255);
            usleep(delay_us / 256);
        }
    }
}

void hsv2rgb(float h, float s, float v, uint8_t *r, uint8_t *g, uint8_t *b) {
    float c = v * s;
    float x = c * (1 - fabs(fmodf(h / 60.0, 2) - 1));
    float m = v - c;
    float r_, g_, b_;

    if (h < 60)       { r_ = c; g_ = x; b_ = 0; }
    else if (h < 120) { r_ = x; g_ = c; b_ = 0; }
    else if (h < 180) { r_ = 0; g_ = c; b_ = x; }
    else if (h < 240) { r_ = 0; g_ = x; b_ = c; }
    else if (h < 300) { r_ = x; g_ = 0; b_ = c; }
    else              { r_ = c; g_ = 0; b_ = x; }

    *r = (r_ + m) * 255;
    *g = (g_ + m) * 255;
    *b = (b_ + m) * 255;
}

void do_rainbow() {
    float h = 0;
    while (1) {
        for (h = 0; h < 360; h+=2) {
          uint8_t r, g, b;
          hsv2rgb(h, 1.0, 1.0, &r, &g, &b);
          write_rgb(r, g, b);
          usleep(delay_us);
        }
    }
}

int do_file_playback(bool loop) {
    while (1) {
        FILE *f = fopen(input_file, "rb");
        if (!f) {
            perror("fopen input");
            return 1;
        }

        uint8_t buf[3];
        while (fread(buf, 1, 3, f) == 3) {
            if (write_rgb(buf[0], buf[1], buf[2]) != 0) {
                fprintf(stderr, "write failed\n");
                fclose(f);
                return 1;
            }
            usleep(delay_us);
        }

        fclose(f);
        if (!loop) break;
    }
    
    return 0;
}

void usage(char *prog_name) {
    if (!prog_name) return;
    fprintf(stderr, "shmLED - WS2812 RGB NEOPIXEL SHM WRITER\n\n");
    fprintf(stderr, "Usage: %s -c #RRGGBB -i <rgb bin file input> [-l -i|-b|-d|-r] [-s µs]\n\n", prog_name);
    fprintf(stderr, "-c :\t#RRGGBB, rgb hex code\n");
    fprintf(stderr, "-i :\t<input.bin>, rgb bin file input, format: \\xRR\\xGG\\xBB ...\n\n");
    fprintf(stderr, "-l :\tloop mode:\n");
    fprintf(stderr, "    -b :\tblink\n");
    fprintf(stderr, "    -d :\tfade\n");
    fprintf(stderr, "    -r :\trainbow\n");
    fprintf(stderr, "    -i :\tsame as rgb file input, but loop mode\n\n");
    fprintf(stderr, "-s :\tdelay µs per frame\n");
    fprintf(stderr, "-h :\tshow this help\n\n");
    return;
}

int main(int argc, char *argv[]) {
    int opt;
    while ((opt = getopt(argc, argv, "c:i:lbdhrs:")) != -1) {
        switch (opt) {
            case 'c':
                if (parse_hex_color(optarg) != 0) {
                    fprintf(stderr, "Invalid color format: %s\n", optarg);
                    return 1;
                }
                break;
            case 'h': usage(argv[0]); return 0;
            case 'l': loop = 1; break;
            case 'b': blink = 1; break;
            case 'd': fade = 1; break;
            case 'r': rainbow = 1; break;
            case 's': delay_us = atoi(optarg); break;
            case 'i': input_file = optarg; break;

            default:
                fprintf(stderr, "Usage: %s -c #RRGGBB -i [rgb input bin file] [-l -i|-b|-d|-r] [-s µs]\n", argv[0]);
                return 1;
        }
    }

    if (!loop) {
        // One-time color set
        if (input_file) return do_file_playback(0);

        return write_rgb(color[0], color[1], color[2]);
    }

    // Loop modes
    
    if (input_file) return do_file_playback(1);

    if (blink) return do_blink(), 0;
    if (fade)  return do_fade(),  0;
    if (rainbow) return do_rainbow(), 0;

    fprintf(stderr, "Loop mode enabled, but no -b, -d, -r or -i <input> specified\n");
    return 1;
}

