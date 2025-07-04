# ======== CONFIG ========
TARGETS     = ws2812d shmled
CC          = arm-rockchip830-linux-uclibcgnueabihf-gcc
CFLAGS      = -static -O3 -Wall -Wextra
INSTALL_BIN = /usr/bin

# ======== RULES ========
.PHONY: all clean install

all: $(TARGETS)

ws2812d: ws2812d.c
	$(CC) $(CFLAGS) -o $@ $<

shmled: shmled.c
	$(CC) $(CFLAGS) -o $@ $<

install: $(TARGETS)
	mkdir -p $(DESTDIR)$(INSTALL_BIN)
	install -m 0755 ws2812d $(DESTDIR)$(INSTALL_BIN)/
	install -m 0755 shmled $(DESTDIR)$(INSTALL_BIN)/

clean:
	rm -f $(TARGETS)

