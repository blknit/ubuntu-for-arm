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

# # Install the PIXEL Desktop
# apt-get -y install xserver-xorg raspberrypi-ui-mods
# # Install the KDE Desktop
# apt-get -y install kde-plasma-desktop
# # Install LXDE Desktop
# apt-get -y install lxde-core lxappearance
# # Install XFACE Desktop
# apt-get -y install xfce4 xfce4-terminal
# Install MATE Desktop
apt-get -y install lightdm lightdm-gtk-greeter mate-desktop-environment # mate-desktop-environment-core
# # Install Cinnamon Desktop
# apt-get -y install install cinnamon-desktop-environment

apt-get -y install libegl-mesa0 libgbm1 mesa-utils \
libgl1-mesa-dev libgl1-mesa-dri libglapi-mesa libglx-mesa0 libosmesa6 \
mesa-opencl-icd mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers 

# Remove cloud-init
# apt-get -y purge cloud-init

# Chromium uses fixed paths for libv4l2.so
ln -rsf /usr/lib/*/libv4l2.so /usr/lib/
[ -e /usr/lib/aarch64-linux-gnu/ ] && ln -Tsf lib /usr/lib64

# Improve mesa performance 
echo "PAN_MESA_DEBUG=gofaster" >> /etc/environment

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
EOF