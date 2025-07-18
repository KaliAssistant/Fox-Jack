#!/bin/sh

NAME="PAYLOAD2"

init() {
    /etc/init.d/M21networkinit start
    /etc/init.d/M49ntpd start
    /etc/init.d/M50sshd start
    /etc/init.d/M50usbgtgadgets start
    /etc/init.d/M51usbnet start
}

/usr/bin/shmled -c#FFFF00 -lbs50000 &
init
