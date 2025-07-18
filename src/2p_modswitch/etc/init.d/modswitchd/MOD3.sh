#!/bin/sh

NAME="PAYLOAD3"

init() {
    /etc/init.d/M21networkinit start
    /etc/init.d/M49ntpd start
    /etc/init.d/M50sshd start
    /etc/init.d/M50usbgtgadgets start
    /etc/init.d/M51usbnet start
}

/usr/bin/shmled -lrs24000 &
init
