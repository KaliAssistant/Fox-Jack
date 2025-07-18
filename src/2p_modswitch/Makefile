# ======== CONFIG ========
TARGETS     = modswitchd
CC          = arm-rockchip830-linux-uclibcgnueabihf-gcc
CFLAGS      = -static -O3 -Wall -Wextra
INSTALL_BIN = /usr/bin

# ======== RULES ========
.PHONY: all clean install

all: $(TARGETS)

modswitchd: modswitchd.c
	$(CC) $(CFLAGS) -o $@ $<

install: $(TARGETS)
	mkdir -p $(DESTDIR)$(INSTALL_BIN)
	install -m 0755 modswitchd $(DESTDIR)$(INSTALL_BIN)/
	cp -r ./etc/ $(DESTDIR)/

clean:
	rm -f $(TARGETS)
