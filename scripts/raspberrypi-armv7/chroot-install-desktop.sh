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

export DEBIAN_FRONTEND=noninteractive

# Desktop packages
apt-get -y install ubuntu-desktop dbus-x11 xterm pulseaudio pavucontrol qtwayland5 \
gstreamer1.0-plugins-bad gstreamer1.0-plugins-base gstreamer1.0-plugins-good mpv \
gstreamer1.0-tools chromium-browser dvb-tools ir-keytable libgles2-mesa-dev libglx-mesa0 \
libdvbv5-0 libdvbv5-dev libdvbv5-doc libv4l-0 libv4l2rds0 libv4lconvert0 libv4l-dev \
qv4l2 v4l-utils libegl-mesa0 libegl1-mesa-dev libgbm-dev libgl1-mesa-dev mesa-utils \
mesa-common-dev mesa-vulkan-drivers

# apt-get -y install mali-g610-firmware malirun rockchip-multimedia-config librist4 \
# librist-dev rist-tools libv4l-rkmpp librockchip-mpp1 librockchip-mpp-dev \ 
# librockchip-vpu0 rockchip-mpp-demos librga2 librga-dev libwidevinecdm \
# gstreamer1.0-rockchip1 

# Remove cloud-init and landscape-common
apt-get -y purge cloud-init landscape-common

# Chromium uses fixed paths for libv4l2.so
ln -rsf /usr/lib/*/libv4l2.so /usr/lib/
[ -e /usr/lib/aarch64-linux-gnu/ ] && ln -Tsf lib /usr/lib64

# Improve mesa performance 
echo "PAN_MESA_DEBUG=gofaster" >> /etc/environment

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
EOF