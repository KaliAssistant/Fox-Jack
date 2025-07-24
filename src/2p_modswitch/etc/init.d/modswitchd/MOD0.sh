#!/bin/sh

NAME="DEBUG"

init() {
    /etc/init.d/M21networkinit start
    /etc/init.d/M49ntp start
    /etc/init.d/M50sshd start
    /etc/init.d/M50usbgtgadgets start /etc/gt/debug.scheme
    /etc/init.d/M51usbnet start
}

/usr/bin/shmled -c#0011FF -lds1000000 &
init
