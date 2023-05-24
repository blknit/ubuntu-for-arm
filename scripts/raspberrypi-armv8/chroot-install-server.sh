#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if test "$#" -ne 1; then
    echo "Usage: $0 rootfs"
	exit 1
fi

chroot_dir=`readlink -f $@`

if [ ! -d ${chroot_dir} ]; then
    echo "Error: missing rootfs directory, please run from build-rootfs.sh"
    exit 1
fi

cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Update localisation files
locale-gen en_US.UTF-8
update-locale LANG="en_US.UTF-8"

export DEBIAN_FRONTEND=noninteractive

# Download and update  
# apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 871920D1991BC93C
apt-get -y update && apt-get -y install software-properties-common

# Download and update installed packages
apt-get -y update && apt-get -y upgrade && apt-get -y dist-upgrade

# Download and install generic packages
apt-get -y install dmidecode mtd-tools i2c-tools u-boot-tools cloud-init \
bash-completion man-db manpages nano gnupg initramfs-tools linux-firmware \
dosfstools mtools parted ntfs-3g zip atop p7zip-full htop iotop pciutils \
lshw lsof landscape-common exfat-fuse hwinfo net-tools wireless-tools pigz \
openssh-client openssh-server wpasupplicant ifupdown wget curl lm-sensors \
bluez gdisk usb-modeswitch usb-modeswitch-data make gcc libc6-dev bison \
libssl-dev flex flash-kernel fake-hwclock rfkill libraspberrypi-bin \
ubuntu-drivers-common ubuntu-server

# Remove cryptsetup and needrestart
apt-get -y remove cryptsetup needrestart

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
EOF