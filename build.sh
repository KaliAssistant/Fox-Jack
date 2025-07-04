#!/usr/bin/env bash

set -e

if [ "$EUID" -ne 0 ]
  then echo -e "Please run as root !"
  exit 1
fi

IMAGE_NAME="luckfoxtech/luckfox_pico:1.0"
CONTAINER_NAME="luckfoxpicofoxjackbuild"

do_docker_env() {
  # 1. Check if the image is already pulled
  if [[ "$(docker images -q "$IMAGE_NAME" 2> /dev/null)" == "" ]]; then
    echo "Image '$IMAGE_NAME' not found. Pulling..."
    docker pull "$IMAGE_NAME" || {
      echo "Failed to pull image."
      exit 1
    }
  else
    echo "Image '$IMAGE_NAME' already exists."
  fi

  # 2. Check if container is already running
  if docker ps --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
    echo "Container '$CONTAINER_NAME' is already running."
  else
    # 3. Check if container exists but not running
    if docker ps -a --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
      echo "Container '$CONTAINER_NAME' exists but not running. Starting..."
      docker start "$CONTAINER_NAME"
    else
      echo "Container '$CONTAINER_NAME' does not exist. Creating and starting..."
      docker run -dit --name "$CONTAINER_NAME" --privileged -v "$(realpath ./luckfox-pico):/home" "$IMAGE_NAME" /bin/bash
    fi
  fi
}


do_build_in_docker() {
  # 4. Build something inside the container
  BUILD_OPT=$1
  echo "Running build commands inside container..."
  docker exec "$CONTAINER_NAME" bash -c "cd /home && ./build.sh $1"
  echo "Completed."
}

do_build_pkgs() {
  echo "Build the foxjack pkgs"
  ./buildpatch.sh
  echo "Completed."
}

do_modify_rootfs() {
  echo "Modify rootfs"
  ./modifyrootfs.sh
  echo "Completed."
}

do_out_images() {
  mkdir -p ./IMAGES
  rsync -a --delete ./workspace/build_imgs/ ./IMAGES
}

do_sdcard_flash() {
  cp ./luckfox-pico/tools/linux/Linux_SD_env_flash/blkenvflash ./IMAGES
  cd ./IMAGES
  echo "WARNING: Check the SD card dev path! blkenvflash can overwrite your system drives!"
  echo -n "Enter your SD card dev path... >" && read -r SD_DEV_PATH
  if [ ! -e "$SD_DEV_PATH" ]; then
    echo "ERROR: $SD_DEV_PATH not found."
    return 1
  fi
  ./blkenvflash "$SD_DEV_PATH"
}

if [ $# -ne 0 ]; then
  case $1 in
    all)
      do_docker_env
      do_build_in_docker allsave
      do_build_pkgs
      do_modify_rootfs
      do_out_images
      ;;
    luckfox)
      do_docker_env
      do_build_in_docker $2
      ;;
    foxjackconfig)
      CRDIR=`pwd`
      cd "$CRDIR"/src/extra_config
      make defconfig && make menuconfig
      cd $CRDIR
      ;;
    sdflash)
      do_sdcard_flash
      ;;
    *)
      echo "Usage: $0 [OPTIONS] [luckfox build.sh OPTIONS]"
      echo -e "Available options:\n"
      echo -e "luckfox [luckfox options]          luckfox pico SDK build script options"
      echo -e "foxjackconfig                      foxjack extra_config"
      echo -e "sdflash                            Burn build images to SD card"
      echo -e "\nDefault option is 'all'."
      exit 1
  esac
else
  do_docker_env
  do_build_in_docker allsave
  do_build_pkgs
  do_modify_rootfs
  do_out_images
fi
