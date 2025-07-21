TARGETS     = batd
CC          = arm-rockchip830-linux-uclibcgnueabihf-gcc
CFLAGS      = -static -O3 -Wall -Wextra
INSTALL_BIN = /usr/bin

.PHONY: all clean install
all: $(TARGETS)

batd: batd.c ini.c
	$(CC) $(CFLAGS) -o $@ batd.c ini.c

install: $(TARGETS)
	mkdir -p $(DESTDIR)$(INSTALL_BIN)
	install -m 0755 batd $(DESTDIR)$(INSTALL_BIN)/
	cp -r ./etc $(DESTDIR)/

clean:
	rm -f $(TARGETS)

