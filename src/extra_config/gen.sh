#!/usr/bin/env bash

set -e

if [ "$EUID" -ne 0 ]
  then echo -e "Please run as root !"
  exit 1
fi


CONFIG="$1"

[ ! -f "$CONFIG" ] && echo "Missing .config file!" && exit 1

OUTDIR=$(realpath ../out/extra_config)

mkdir -p "$OUTDIR"

TEMPLATES_DIR=$(realpath ./templates)

echo -n "" > ../out/rmtab

get_config() {
    grep "^CONFIG_$1=" "$CONFIG" | cut -d= -f2 | tr -d '"'
}

is_enabled() {
    grep -q "^CONFIG_$1=y" "$CONFIG"
}

enable_init_script() {
    NAME=$1
    cp "$TEMPLATES_DIR/etc_init.d_S$NAME" "$OUTDIR/etc/init.d/S$NAME" && echo ">> Enabled $NAME"
}

disable_init_script() {
    NAME=$1
    echo "/etc/init.d/S$NAME" >> ../out/rmtab
    cp "$TEMPLATES_DIR/etc_init.d_S$NAME" "$OUTDIR/etc/init.d/D$NAME"  && echo ">> Disabled $NAME"
}

cidr_to_netmask() {
    local bits=$1
    local mask=""
    for i in 1 2 3 4; do
        if [ "$bits" -ge 8 ]; then
            mask="$mask"255
            bits=$((bits - 8))
        else
            val=$((256 - 2**(8 - bits)))
            mask="$mask$val"
            bits=0
        fi
        [ "$i" -lt 4 ] && mask="$mask."
    done
    echo "$mask"
}



mkdir -p "$OUTDIR/etc/init.d" -m 755 

### === SSH === ###
if is_enabled FJXX_INITSRV_SSH; then
    enable_init_script 50sshd

    KEY=$(get_config FJXX_SSH_AUTHKEY_LOGIN_PBK)
    PASSDISABLE=$(get_config FJXX_SSH_DIS_PASSWD_LOGIN)

    mkdir -p "$OUTDIR/etc/ssh" -m 755
    mkdir -p "$OUTDIR/root/.ssh" -m 755

    cp "$TEMPLATES_DIR/etc_ssh_sshd_config" "$OUTDIR/etc/ssh/sshd_config"

    if [ "$PASSDISABLE" = "y" ]; then
        sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$OUTDIR/etc/ssh/sshd_config"
    fi

    if [ -n "$KEY" ]; then
        echo "$KEY" > "$OUTDIR/root/.ssh/authorized_keys"
        chmod 600 "$OUTDIR/root/.ssh/authorized_keys"
    fi
else
    disable_init_script 50sshd
fi

### === Telnet === ###
if is_enabled FJXX_INITSRV_TELNET; then
    enable_init_script 50telnet
else
    disable_init_script 50telnet
fi

### === SSLh === ###
if is_enabled FJXX_INITSRV_SSLH; then
    enable_init_script 35sslh
else
    disable_init_script 35sslh
fi

### === USB Gadget === ###
if is_enabled FJXX_INITSRV_USB_GADGETS; then
    enable_init_script 50usbdevice
    enable_init_script 99usb0config

    RNDIS_CIDR=$(get_config FJXX_USB_GADGETS_RNDIS_IPV4_ADDR)
    RNDIS_IP=${RNDIS_CIDR%%/*}
    RNDIS_MASKBITS=${RNDIS_CIDR##*/}
    RNDIS_NETMASK=$(cidr_to_netmask "$RNDIS_MASKBITS")
    HOST_MAC=$(get_config FJXX_USB_GADGETS_RNDIS_HOST_MAC)
    DEV_MAC=$(get_config FJXX_USB_GADGETS_RNDIS_DEV_MAC)

    sed -i "s|^USB_RNDIS_HOSTADDR=.*|USB_RNDIS_HOSTADDR=\"$HOST_MAC\"|" "$OUTDIR/etc/init.d/S50usbdevice"
    sed -i "s|^USB_RNDIS_DEVADDR=.*|USB_RNDIS_DEVADDR=\"$DEV_MAC\"|" "$OUTDIR/etc/init.d/S50usbdevice"
    echo "USB0_IP=\"$RNDIS_IP\"" > "$OUTDIR/etc/usbnet"
    echo "USB0_MASK=\"$RNDIS_NETMASK\"" >> "$OUTDIR/etc/usbnet"

else
    disable_init_script 50usbdevice
    disable_init_script 99usb0config
fi


disable_init_script 21appinit
enable_init_script 21networkinit
enable_init_script 20ws2812d

echo "/etc/profile.d/RkEnv.sh" >> ../out/rmtab

cp "$TEMPLATES_DIR/etc_motd" "$OUTDIR/etc/motd"
