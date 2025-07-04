#!/usr/bin/env bash

set -e

if [ "$EUID" -ne 0 ]
  then echo -e "Please run as root !"
  exit 1
fi

REPOPWD=`pwd`

do_trap_cleanup() {
  set +e
  cd $REPOPWD
  umount -lf $(realpath ./workspace/rootfs_mnt) 2>/dev/null || true
  loop_device="$(losetup -j "$(realpath ./workspace/build_imgs/rootfs.img)" | cut -d':' -f1)"
  if [ -n "$loop_device" ]; then
    echo "Detaching loop device: $loop_device"
    losetup -d "$loop_device" 2>/dev/null || true
  fi
}

trap do_trap_cleanup SIGINT SIGTERM ERR

do_mkworkspace() {
  cd $REPOPWD
  mkdir -p workspace
  mkdir -p workspace/rootfs_mnt
  mkdir -p workspace/build_imgs
}

do_cpfiles_to_workspace() {
  cd $REPOPWD/workspace
  rsync -a --delete ../luckfox-pico/output/image/ build_imgs/
  [ ! -f ../src/out/rmtab ] || cp ../src/out/rmtab .
}

do_modify() {
  cd $REPOPWD/workspace
  LOOP_MOUNT_POINT=$(losetup --show -fP build_imgs/rootfs.img)
  mount $LOOP_MOUNT_POINT ./rootfs_mnt

  for i in ../pkg/*.tar.gz; do
    tar xf $i -C ./rootfs_mnt
  done

  cd ./rootfs_mnt

  while read -r filepath; do
        if [ -f "`pwd`$filepath" ]; then
            echo "Deleting: $filepath"
            rm -f "`pwd`$filepath"
        else
            echo "Skip: $filepath (not a file)"
        fi
  done < ../rmtab

  cd ..
  umount $LOOP_MOUNT_POINT
  
  losetup -d $LOOP_MOUNT_POINT

}


do_mkworkspace
do_cpfiles_to_workspace
do_modify
