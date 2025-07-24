#!/bin/sh

NAME="PAYLOAD1"

UDISK_IMAGE_FILE=/userdata/udisk.img
UDISK_IMAGE_MNT=/mnt/udisk

init() {
    mkdir -p "$UDISK_IMAGE_MNT"
    mount -o sync,rw,exec -t vfat "$UDISK_IMAGE_FILE" "$UDISK_IMAGE_MNT"
}

run() {
    for payloads in "$UDISK_IMAGE_MNT"/payloads/mod1.d/E????*.payload; do
        bash $payloads
    done
}

end() {
    sync; sync; sync
    umount -lf "$UDISK_IMAGE_MNT"
}

init
run
end
