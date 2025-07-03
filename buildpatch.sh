#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]
  then echo -e "Please run as root !"
  exit 1
fi

REPOPWD=`pwd`

if [ ! -d ${REPOPWD}/luckfox-pico/tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf/bin ]; then
  echo -e "Toolchain not found!!! Run ./dep.sh first!"
  exit 1
fi

set -e

export PATH="$PATH:${REPOPWD}/luckfox-pico/tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf/bin"
export SYSROOT="${REPOPWD}/luckfox-pico/tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf/arm-rockchip830-linux-uclibcgnueabihf/sysroot"

mkdir -p ${REPOPWD}/src/out

do_build_hping() {

  cd "$REPOPWD"/src/libpcap-1.10.5
  autoreconf -i
  ./configure --host=arm-rockchip830-linux-uclibcgnueabihf --prefix=/usr
  make -j $(nproc) && make install DESTDIR=$(realpath ../out/libpcap)

  cd ../out/libpcap/usr/include
  mkdir -p net
  cp ./pcap/bpf.h ./net

  cd "$REPOPWD"/src/tcl-8.6.0/unix
  

  ./configure \
    --host=arm-rockchip830-linux-uclibcgnueabihf \
    --build=$(uname -m)-linux-gnu \
    --prefix=/usr \
    --disable-shared \
    --enable-static \
    --disable-symbols \
    --disable-threads \
    --disable-langinfo \
    --disable-dll-unloading \
    --disable-load \
    --disable-rpath \
    --enable-64bit=no \
    --with-system-malloc \
    --with-tcl-library=/usr/lib/tcl8.6\
    ac_cv_func_strtod=yes \
    ac_cv_func_strstr=yes \
    ac_cv_func_memcmp=yes \
    ac_cv_func_strtoul=yes \
    CC="arm-rockchip830-linux-uclibcgnueabihf-gcc --sysroot=$SYSROOT" \
    CFLAGS="-Os -ffunction-sections -fdata-sections" \
    LDFLAGS="-Wl,--gc-sections"

  make -j $(nproc) && make install DESTDIR=$(realpath ../../out/tcl)

  cd ../../out/tcl/usr/lib
  mkdir -p strip-tcl && cd strip-tcl
  arm-rockchip830-linux-uclibcgnueabihf-ar x ../libtcl8.6.a
  rm strtoul.o memcmp.o strstr.o 
  arm-rockchip830-linux-uclibcgnueabihf-ar rc ../libtcl8.6-nolibc.a *.o
  arm-rockchip830-linux-uclibcgnueabihf-ranlib ../libtcl8.6-nolibc.a
  
  cd "$REPOPWD"/src/hping
  make hping3-static -j $(nproc) && make install DESTDIR=$(realpath ../out/hping)
  
  
  cd "$REPOPWD"
  mkdir -p pkg && cd pkg
  mkdir -p hping && cd hping
  rsync -a ../../src/out/hping/ ./
  rsync -a ../../src/out/tcl/ ./
  cd ..
  tar czf foxjack-hping.tar.gz -C hping .
  rm -rf hping
}

do_extra_config() {
  [ ! -d "$REPOPWD"/src/out/extra_config ] || rm -rf "$REPOPWD"/src/out/extra_config

  cd "$REPOPWD"/src/extra_config

  make defconfig && make

  cd "$REPOPWD"
  mkdir -p pkg && cd pkg
  mkdir -p extra_config && cd extra_config
  rsync -a  ../../src/out/extra_config/ ./
  cd ..
  tar czf foxhack-extra-config.tar.gz -C extra_config .
  rm -rf extra_config
}


do_build_hping
do_extra_config

cd "$REPOPWD"
