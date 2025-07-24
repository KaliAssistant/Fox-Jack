#!/usr/bin/env bash

set -e

if [ "$EUID" -ne 0 ]
  then echo -e "Please run as root !"
  exit 1
fi

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIG="$1"

[ ! -f "$CONFIG" ] && echo "Missing .config file!" && exit 1


RK_BUILD_ROOTFS_ROOT_DIR="${SCRIPT_PATH}/../../luckfox-pico/output/out/rootfs_uclibc_rv1106"
RK_BUILD_USERDATA_UDISK_DIR="${SCRIPT_PATH}/../../luckfox-pico/output/out/userdata"

[ ! -d "$RK_BUILD_ROOTFS_ROOT_DIR" ] && echo "Build rootfs not found!" && exit 1
[ ! -d "$RK_BUILD_USERDATA_UDISK_DIR" ] && echo "userdata dir not found!" && exit 1

export PATH="$PATH:${SCRIPT_PATH}/../../luckfox-pico/tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf/bin"

USERDATA_UDISK_SIZE=200 # unit: MiB


get_config() {
    grep "^CONFIG_$1=" "$CONFIG" | cut -d= -f2 | tr -d '"'
}

is_enabled() {
    grep -q "^CONFIG_$1=y" "$CONFIG"
}

enable_init_script() {
    NAME=$1

    if [ -f "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/S$NAME" ]; then
        echo "$NAME is already Enabled. Skip..."
        chmod 755 "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/S$NAME"
        return 0
    elif [ -f "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/M$NAME" ]; then
        mv "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/M$NAME" "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/S$NAME"
        chmod 755 "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/S$NAME"
        echo ">> Enabled $NAME"
        return 0
    elif [ -f "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/D$NAME" ]; then
        mv "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/D$NAME" "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/S$NAME"
        chmod 755 "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/S$NAME"
        echo ">> Enabled $NAME"
        return 0
    else
        echo "$NAME not found! Please check your build rootfs"
        return 1
    fi

}

manual_init_script() {
    NAME=$1

    if [ -f "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/M$NAME" ]; then
        echo "$NAME is already set to Manual mod. Skip..."
        chmod 755 "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/M$NAME"
        return 0
    elif [ -f "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/D$NAME" ]; then
        mv "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/D$NAME" "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/M$NAME"
        chmod 755 "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/M$NAME"
        echo ">> Set Manual $NAME"
        return 0
    elif [ -f "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/S$NAME" ]; then
        mv "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/S$NAME" "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/M$NAME"
        chmod 755 "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/M$NAME"
        echo ">> Set Manual $NAME"
        return 0
    else
        echo "$NAME not found! Please check your build rootfs"
        return 1
    fi

}


disable_init_script() {
    NAME=$1

    if [ -f "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/D$NAME" ]; then
        echo "$NAME is already Disabled. Skip..."
        return 0
    elif [ -f "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/M$NAME" ]; then
        mv "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/M$NAME" "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/D$NAME"
        chmod 755 "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/S$NAME"
        echo ">> Disabled $NAME"
        return 0
    elif [ -f "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/S$NAME" ]; then
        mv "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/S$NAME" "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/D$NAME"
        echo ">> Disabled $NAME"
        return 0
    else
        echo "$NAME not found! Please check your build rootfs"
        return 1
    fi
}


cidr_to_netmask() {
    local input="$1"

    # Match x.x.x.x/xx pattern
    if ! [[ "$input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "Error: Input must be in the form x.x.x.x/xx" >&2
        return 1
    fi

    # Split IP and CIDR bits
    local ip="${input%%/*}"
    local bits="${input##*/}"

    # Validate each IP octet is 0–255
    IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
    for octet in "$o1" "$o2" "$o3" "$o4"; do
        if (( octet < 0 || octet > 255 )); then
            echo "Error: Invalid IP address: $ip" >&2
            return 1
        fi
    done

    # Validate CIDR range
    if (( bits < 0 || bits > 32 )); then
        echo "Error: CIDR must be between 0 and 32." >&2
        return 1
    fi

    # Convert CIDR to netmask
    local mask=""
    for i in 1 2 3 4; do
        if (( bits >= 8 )); then
            mask+="255"
            bits=$((bits - 8))
        else
            mask+=$((256 - 2 ** (8 - bits)))
            bits=0
        fi
        [[ $i -lt 4 ]] && mask+="."
    done

    echo "$mask"
}


validate_port() {
  local p="$1"
  [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= 65535 ))
}

is_valid_mac_lowercase() {
    local mac="$1"

    if [[ "$mac" =~ ^([0-9a-f]{2}:){5}[0-9a-f]{2}$ ]]; then
        return 0  # valid
    else
        echo "Invalid MAC address: $mac" >&2
        echo "lower case only, Octets are separated by :" >&2
        return 1
    fi
}


do_init_sshd() {
    if is_enabled FJXX_INITSRV_SSH; then
        if is_enabled FJXX_INITSRV_SSH_MANUAL; then
            manual_init_script 50sshd
        elif is_enabled FJXX_INITSRV_SSH_ENABLE; then
            enable_init_script 50sshd
        else
            echo "UNKNOWN option in Config.in choice FJXX_INITSRV_SSH" >&2
            return 1
        fi
        KEY=$(get_config FJXX_SSH_AUTHKEY_LOGIN_PBK)
        PASSDISABLE=$(get_config FJXX_SSH_DIS_PASSWD_LOGIN)
        LISTEN_PORT=$(get_config FJXX_SSH_LISTEN_PORT)
        mkdir -p "$RK_BUILD_ROOTFS_ROOT_DIR/root/.ssh" -m 755

        if ! validate_port "$LISTEN_PORT"; then
            echo "Bad sshd listen port: $LISTEN_PORT" >&2
            return 1
        else
            sed -i "s/^\s*#\?\s*Port\s\+.*/Port $LISTEN_PORT/" "$RK_BUILD_ROOTFS_ROOT_DIR/etc/ssh/sshd_config"
        fi
  
        if [ "$PASSDISABLE" = "y" ]; then
            sed -i "s/^\s*#\?\s*PasswordAuthentication\s\+.*/PasswordAuthentication no/" "$RK_BUILD_ROOTFS_ROOT_DIR/etc/ssh/sshd_config"
        else
            sed -i "s/^\s*#\?\s*PasswordAuthentication\s\+.*/PasswordAuthentication yes/" "$RK_BUILD_ROOTFS_ROOT_DIR/etc/ssh/sshd_config"
        fi
    
        if [ -n "$KEY" ]; then
            TMPKEY=$(mktemp)
            echo "$KEY" > "$TMPKEY"
            if ssh-keygen -l -f "$TMPKEY" >/dev/null 2>&1; then
                echo "$KEY" > "$RK_BUILD_ROOTFS_ROOT_DIR/root/.ssh/authorized_keys"
                chmod 600 "$RK_BUILD_ROOTFS_ROOT_DIR/root/.ssh/authorized_keys"
            else
                echo "Bad SSH key $KEY (rejected by ssh-keygen)." >&2
                rm -f "$TMPKEY"
                return 1
            fi
            rm -f "$TMPKEY"
        fi

    else
        disable_init_script 50sshd    
    fi
}

do_init_telnet() {
    if is_enabled FJXX_INITSRV_TELNET; then
        if is_enabled FJXX_INITSRV_TELNET_MANUAL; then
            manual_init_script 50telnet
        elif is_enabled FJXX_INITSRV_TELNET_ENABLE; then
            enable_init_script 50telnet
        else
            echo "UNKNOWN option in Config.in choice FJXX_INITSRV_TELNET" >&2
            return 1
        fi
    else
        disable_init_script 50telnet
    fi
}


do_init_sslh() {
    if is_enabled FJXX_INITSRV_SSLH; then
        if is_enabled FJXX_INITSRV_SSLH_MANUAL; then
            manual_init_script 35sslh
        elif is_enabled FJXX_INITSRV_SSLH_ENABLE; then
            enable_init_script 35sslh
        else
            echo "UNKNOWN option in Config.in choice FJXX_INITSRV_SSLH" >&2
            return 1
        fi
    else
        disable_init_script 35sslh
    fi
}


do_init_usb_gadgets(){
    if is_enabled FJXX_INITSRV_USB_GADGETS; then
        if is_enabled FJXX_INITSRV_USB_GADGETS_MANUAL; then
            manual_init_script 50usbdevice
        elif is_enabled FJXX_INITSRV_USB_GADGETS_ENABLE; then
            enable_init_script 50usbdevice
        else
            echo "UNKNOWN option in Config.in choice FJXX_INITSRV_USB_GADGETS" >&2
            return 1
        fi
        
        RNDIS_CIDR=$(get_config FJXX_USB_GADGETS_RNDIS_IPV4_ADDR)
        if ! cidr_to_netmask "$RNDIS_CIDR"; then
            echo "Bad rndis ipaddress input!" >&2
            return 1
        else
            RNDIS_IP=${RNDIS_CIDR%%/*}
            RNDIS_NETMASK=$(cidr_to_netmask "$RNDIS_CIDR")
        fi
        HOST_MAC=$(get_config FJXX_USB_GADGETS_RNDIS_HOST_MAC)
        DEV_MAC=$(get_config FJXX_USB_GADGETS_RNDIS_DEV_MAC)
        if ! is_valid_mac_lowercase "$HOST_MAC"; then
            echo "Bad rndis host macaddress!" >&2
            return 1
        fi
        if ! is_valid_mac_lowercase "$DEV_MAC"; then
            echo "Bad rndis dev macaddress!" >&2
            return 1
        fi
        sed -i "s|^USB_RNDIS_HOSTADDR=.*|USB_RNDIS_HOSTADDR=\"$HOST_MAC\"|" "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/S50usbdevice"
        sed -i "s|^USB_RNDIS_DEVADDR=.*|USB_RNDIS_DEVADDR=\"$DEV_MAC\"|" "$RK_BUILD_ROOTFS_ROOT_DIR/etc/init.d/S50usbdevice"
        echo "USB0_IP=\"$RNDIS_IP\"" > "$RK_BUILD_ROOTFS_ROOT_DIR/etc/usbnet"
        echo "USB0_MASK=\"$RNDIS_NETMASK\"" >> "$RK_BUILD_ROOTFS_ROOT_DIR/etc/usbnet"
    else
        disable_init_script 50usbdevice
    fi
}


do_init_usb_gt_gadgets() {
    if is_enabled FJXX_INITSRV_USB_GT_GADGETS; then
        if is_enabled FJXX_INITSRV_USB_GT_GADGETS_MANUAL; then
            manual_init_script 50usbgtgadgets
        elif is_enabled FJXX_INITSRV_USB_GT_GADGETS_ENABLE; then
            enable_init_script 50usbgtgadgets
        else
            echo "UNKNOWN option in Config.in choice FJXX_INITSRV_USB_GT_GADGETS" >&2
            return 1
        fi
        HOST_MAC=$(get_config FJXX_USB_GT_GADGETS_RNDIS_HOST_MAC)
        DEV_MAC=$(get_config FJXX_USB_GT_GADGETS_RNDIS_DEV_MAC)
        SERIAL_NUMBER=$(head -c 16 /dev/urandom | xxd -p -u | tr -d '\n')

        sed -i \
        -e "s/serialnumber = \".*\"/serialnumber = \"$SERIAL_NUMBER\"/" \
        -e "s/dev_addr = \".*\"/dev_addr = \"$DEV_MAC\"/" \
        -e "s/host_addr = \".*\"/host_addr = \"$HOST_MAC\"/" \
        "$RK_BUILD_ROOTFS_ROOT_DIR/etc/gt/default-rndis.scheme" \
        "$RK_BUILD_ROOTFS_ROOT_DIR/etc/gt/debug.scheme"

    else
        disable_init_script 50usbgtgadgets
    fi
}


do_init_usb_gt_usbnet() {
    if is_enabled FJXX_INITSRV_USB_GT_USBNET; then
        if is_enabled FJXX_INITSRV_USB_GT_USBNET_MANUAL; then
            manual_init_script 51usbnet
        elif is_enabled FJXX_INITSRV_USB_GT_USBNET_ENABLE; then
            enable_init_script 51usbnet
        else
            echo "UNKNOWN option in Config.in choice FJXX_INITSRV_USB_GT_USBNET" >&2
            return 1
        fi

        RNDIS_CIDR=$(get_config FJXX_USB_GT_GADGETS_RNDIS_IPV4_ADDR)
        if ! cidr_to_netmask "$RNDIS_CIDR"; then
            echo "Bad rndis ipaddress input!" >&2
            return 1
        else
            RNDIS_IP=${RNDIS_CIDR%%/*}
            RNDIS_NETMASK=$(cidr_to_netmask "$RNDIS_CIDR")
        fi
        cat <<EOF >> "$RK_BUILD_ROOTFS_ROOT_DIR/etc/usbnet"
USB0_IP="$RNDIS_IP"
USB0_MASK="$RNDIS_NETMASK"
EOF
    else
        disable_init_script 51usbnet
    fi
}

do_init_networkinit() {
    if is_enabled FJXX_INITSRV_ETH_NETWORK_DHCP; then
        if is_enabled FJXX_INITSRV_ETH_NETWORK_DHCP_MANUAL; then
            manual_init_script 21networkinit
        elif is_enabled FJXX_INITSRV_ETH_NETWORK_DHCP_ENABLE; then
            enable_init_script 21networkinit
        else
            echo "UNKNOWN option in Config.in choice FJXX_INITSRV_ETH_NETWORK_DHCP" >&2
            return 1
        fi
    else
        disable_init_script 21networkinit
    fi
}

do_init_ntpd() {
    if is_enabled FJXX_INITSRV_NTPD; then
        if is_enabled FJXX_INITSRV_NTPD_MANUAL; then
            manual_init_script 49ntp
        elif is_enabled FJXX_INITSRV_NTPD_ENABLE; then
            enable_init_script 49ntp
        else
            echo "UNKNOWN option in Config.in choice FJXX_INITSRV_NTPD" >&2
            return 1
        fi
    else
        disable_init_script 49ntp
    fi
}


do_init_ws2812d() {
    if is_enabled FJXX_PHY_WS2812B_DAEMON; then
        enable_init_script 20ws2812d
    else
        disable_init_script 20ws2812d
    fi
}

do_init_modswitchd() {
    if is_enabled FJXX_PHY_GPIO_MODSWITCH_DAEMON; then
        enable_init_script 21modswitchd
    else
        disable_init_script 21modswitchd
    fi
}

do_init_saradc_batd() {
    if is_enabled FJXX_PHY_SARADC_BAT_DAEMON; then
        enable_init_script 19batd
    else
        disable_init_script 19batd
    fi
}

do_copy_motd() {
    cp "$SCRIPT_PATH/motd" "$RK_BUILD_ROOTFS_ROOT_DIR/etc/motd"
}

do_mk_udisk() {
    dd if=/dev/zero of="$RK_BUILD_USERDATA_UDISK_DIR/udisk.img" bs=1M count=$USERDATA_UDISK_SIZE
    mkfs.vfat -F 32 -n "FOX-JACK" "$RK_BUILD_USERDATA_UDISK_DIR/udisk.img"
    sync
    MNT_TMPDIR=$(mktemp -d /tmp/mnt.XXXXXXXXXX)
    mount -o loop "$RK_BUILD_USERDATA_UDISK_DIR/udisk.img" "$MNT_TMPDIR"
    cd "${SCRIPT_PATH}"
    tar zxvf udisk.tar.gz
    cd "$MNT_TMPDIR"
    cp -r "${SCRIPT_PATH}/udisk/"* .
    sync
    umount -lf "$RK_BUILD_USERDATA_UDISK_DIR/udisk.img"
    rmdir "$MNT_TMPDIR"
    cd "${SCRIPT_PATH}"
}

do_install_ws2812d() {
    cd "${SCRIPT_PATH}/../spi_ws2812"
    make && make install DESTDIR="$RK_BUILD_ROOTFS_ROOT_DIR"
    cd "$SCRIPT_PATH"
}

do_install_modswitchd() {
    cd "${SCRIPT_PATH}/../2p_modswitch"
    make && make install DESTDIR="$RK_BUILD_ROOTFS_ROOT_DIR"
    cd "$SCRIPT_PATH"
}

do_install_saradc_batd() {
    cd "${SCRIPT_PATH}/../saradc_batd"
    make && make install DESTDIR="$RK_BUILD_ROOTFS_ROOT_DIR"
    cd "$SCRIPT_PATH"
}

do_install_overlay() {
    cp -r "$SCRIPT_PATH/overlay/"* "$RK_BUILD_ROOTFS_ROOT_DIR"
}

do_install_overlay
do_init_sshd
do_init_telnet
do_init_sslh
do_init_usb_gadgets
do_init_usb_gt_gadgets
do_init_usb_gt_usbnet
do_init_networkinit
do_init_ntpd
do_copy_motd
do_install_ws2812d
do_init_ws2812d
do_install_modswitchd
do_init_modswitchd
do_install_saradc_batd
do_init_saradc_batd
do_mk_udisk
