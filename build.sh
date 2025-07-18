#!/usr/bin/env bash

set -e

if [ "$EUID" -ne 0 ]
  then echo -e "Please run as root !"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#IMAGE_NAME="debian:testing-backports@sha256:f9a865a60bffbfcc5ef80cbf2be85ab4d7a58ace445ea6f8ddb9049ea4c1be07"
#CONTAINER_NAME="luckfoxpicofoxjackbuild-debian"

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
#  docker exec -ti "$CONTAINER_NAME" bash -c "apt update && apt install -y wget gcc g++ gawk libtool libtool-bin automake autoconf make cmake device-tree-compiler texinfo gperf g++-multilib gcc-multilib bc dc bison pkg-config git python3-dev libncurses-dev bzip2 unzip xz-utils cpio rsync flex openssl libssl-dev"
  docker exec -ti "$CONTAINER_NAME" bash -c "export FORCE_UNSAFE_CONFIGURE=1;cd /home && ./build.sh $1"
  echo "Completed."
}

do_extra_config() {
  cd "$REPO_DIR"/src/extra_config
  [ -f .config ] || make defconfig
  make

  cd "$REPO_DIR"
}

do_out_images() {
  mkdir -p ./IMAGES
  rsync -a --delete ./luckfox-pico/output/image/ ./IMAGES
  echo "Done. run \`build.sh sdflash\` to flash images."
}

do_sdcard_flash() {
  cp ./luckfox-pico/tools/linux/Linux_SD_env_flash/blkenvflash ./IMAGES
  cd ./IMAGES
  echo "WARNING: Check the SD card dev path! blkenvflash can overwrite your system drives!"
  echo -n "Enter your SD card dev path (/dev/sxx)... >" && read -r SD_DEV_PATH
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
      do_build_in_docker all
      do_extra_config
      do_build_in_docker firmware
      do_out_images
      ;;
    luckfox)
      do_docker_env
      do_build_in_docker $2
      ;;
    foxjackconfig)
      cd "$REPO_DIR"/src/extra_config
      [ -f .config ] || make defconfig
      make menuconfig
      cd $REPO_DIR
      ;;
    sdflash)
      do_sdcard_flash
      ;;
    *)
      echo "Usage: $0 [OPTIONS] [luckfox build.sh OPTIONS]"
      echo -e "Available options:\n"
      echo -e "all                                build foxjack images and flash"
      echo -e "luckfox [luckfox options]          luckfox pico SDK build script options"
      echo -e "foxjackconfig                      foxjack extra_config"
      echo -e "sdflash                            Burn build images to SD card"
      echo -e "\nDefault option is 'all'."
      exit 1
  esac
else
  do_docker_env
  do_build_in_docker all
  do_extra_config
  do_build_in_docker firmware
  do_out_images
  do_sdcard_flash
fi
