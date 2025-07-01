# $smu-mark$ 
# $name: Makefile.in$ 
# $author: Salvatore Sanfilippo 'antirez'$ 
# $copyright: Copyright (C) 1999 by Salvatore Sanfilippo$ 
# $license: This software is under GPL version 2 of license$ 
# $date: Sun Jul 25 17:56:15 MET DST 1999$ 
# $rev: 3$ 

CC= arm-rockchip830-linux-uclibcgnueabihf-gcc
AR= arm-rockchip830-linux-uclibcgnueabihf-ar
RANLIB= arm-rockchip830-linux-uclibcgnueabihf-ranlib
CCOPT= -O2 -Wall  -I../out/tcl/usr/include -I../out/libpcap/usr/include -DUSE_TCL -L../out/libpcap/usr/lib -L../out/tcl/usr/lib
DEBUG= -g
#uncomment the following if you need libpcap based build under linux
#(not raccomanded)
COMPILE_TIME=
INSTALL_MANPATH=
PCAP=-lpcap

ARSOBJ = ars.o apd.o split.o rapd.o

OBJ=	main.o getifname.o getlhs.o \
	parseoptions.o datafiller.o \
	datahandler.o gethostname.o \
	binding.o getusec.o opensockraw.o \
	logicmp.o waitpacket.o resolve.o \
	sendip.o sendicmp.o sendudp.o \
	sendtcp.o cksum.o statistics.o \
	usage.o version.o antigetopt.o \
	sockopt.o listen.o \
	sendhcmp.o memstr.o rtt.o \
	relid.o sendip_handler.o \
	libpcap_stuff.o memlockall.o memunlockall.o \
	memlock.o memunlock.o ip_opt_build.o \
	display_ipopt.o sendrawip.o signal.o send.o \
	strlcpy.o arsglue.o random.o scan.o \
	hstring.o script.o interface.o \
	adbuf.o hex.o apdutils.o sbignum.o \
	sbignum-tables.o $(ARSOBJ)

all: .depend hping3

dep: .depend
.depend:
	@echo Making dependences
	@$(CC) -MM *.c > .depend

libars.a: $(ARSOBJ)
	$(AR) rc $@ $^
	$(RANLIB) $@

hping3: byteorder.h $(OBJ)
	$(CC) -o hping3 $(CCOPT) $(DEBUG) $(OBJ) -L/usr/local/lib $(PCAP)  -ltcl8.6 -lm -lpthread
	@echo
	./hping3 -v
	@echo "use \`make strip' to strip hping3 binary"
	@echo "use \`make install' to install hping3"

hping3-static: byteorder.h $(OBJ)
	$(CC) -static -o hping3-static $(CCOPT) $(DEBUG) $(OBJ) -L/usr/local/lib $(PCAP) ../out/tcl/usr/lib/libtcl8.6-nolibc.a -lm -lpthread -ldl

byteorder.h:
	./configure

.c.o:
	$(CC) -c $(CCOPT) $(DEBUG) $(COMPILE_TIME) $<

clean:
	rm -rf hping3 *.o libars.a

distclean:
	rm -rf hping3 *.o byteorder byteorder.h systype.h Makefile libars.a .depend

install: hping3-static
	[ -d $(DESTDIR)/usr ] || \
		(mkdir -p $(DESTDIR)/usr; chmod 755 $(DESTDIR)/usr)
	[ -d $(DESTDIR)/usr/bin ] || \
		(mkdir -p $(DESTDIR)/usr/bin; chmod 755 $(DESTDIR)/usr/bin)
	[ -d $(DESTDIR)/usr/share ] || \
		(mkdir -p $(DESTDIR)/usr/share; chmod 755 $(DESTDIR)/usr/share)
	[ -d $(DESTDIR)/usr/share/man ] || \
		(mkdir -p $(DESTDIR)/usr/share/man; chmod 755 $(DESTDIR)/usr/share/man)
	[ -d $(DESTDIR)/usr/share/man/man8 ] || \
		(mkdir -p $(DESTDIR)/usr/share/man/man8; chmod 755 $(DESTDIR)/usr/share/man/man8)

	
	cp -f hping3-static $(DESTDIR)/usr/bin/hping3
	chmod 755 $(DESTDIR)/usr/bin/hping3
	cp ./docs/hping3.8 $(DESTDIR)/usr/share/man/man8
	chmod 644 $(DESTDIR)/usr/share/man/man8/hping3.8



strip: hping3
	@ls -l ./hping3
	strip hping3
	@ls -l ./hping3

include .depend
