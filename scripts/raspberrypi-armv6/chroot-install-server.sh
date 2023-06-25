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
apt-get -y install dmidecode network-manager flash-kernel bluez gdisk \
bash-completion man-db manpages nano gnupg initramfs-tools fake-hwclock \
dosfstools mtools parted ntfs-3g zip atop p7zip-full htop iotop pciutils \
lshw lsof exfat-fuse hwinfo net-tools wireless-tools pigz rfkill lm-sensors \
openssh-client openssh-server wpasupplicant ifupdown wget curl usb-modeswitch \
usb-modeswitch-data 

# Download and install developer packages
# build-essential include make gcc g++ dpkg-dev libc6-dev
DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
git binutils build-essential bc bison cmake flex libssl-dev device-tree-compiler \
i2c-tools binfmt-support

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean

# Setup user account
adduser --shell /bin/bash --gecos ubuntu --disabled-password ubuntu
usermod -a -G sudo,video,adm,dialout,cdrom,audio,plugdev ubuntu
mkdir -m 700 /home/ubuntu/.ssh
chown -R ubuntu:ubuntu /home/ubuntu
echo -e "root\nroot" | passwd ubuntu

EOF