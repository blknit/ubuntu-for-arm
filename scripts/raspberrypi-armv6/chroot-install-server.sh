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
echo en_US.UTF-8 UTF-8 > /etc/locale.gen && locale-gen
# locale-gen en_US.UTF-8
update-locale LANG="en_US.UTF-8"

export DEBIAN_FRONTEND=noninteractive

# Download and update
apt-get -y update && apt-get -y install software-properties-common

# Download and update installed packages
apt-get -y update && apt-get -y upgrade && apt-get -y dist-upgrade

# Download and install generic packages
apt-get -y install dmidecode mtd-tools i2c-tools cloud-init network-manager \
bash-completion man-db manpages nano gnupg initramfs-tools fake-hwclock \
dosfstools mtools parted ntfs-3g zip atop p7zip-full htop iotop pciutils \
lshw lsof exfat-fuse hwinfo net-tools wireless-tools pigz rfkill libssl-dev \
openssh-client openssh-server wpasupplicant ifupdown wget curl lm-sensors \
bluez gdisk usb-modeswitch usb-modeswitch-data make gcc libc6-dev bison \
flex flash-kernel

# Remove cryptsetup and needrestart
apt-get -y remove cryptsetup needrestart

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
EOF