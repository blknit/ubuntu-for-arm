#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if test "$#" -ne 1; then
    echo "Usage: $0 rootfs"
	exit 1
fi

chroot_dir=`readlink -f $@`
mkdir -p ${chroot_dir}

# Debootstrap options
arch=armhf
release=bullseye
mirror=http://raspbian.raspberrypi.org/raspbian
include="--include isc-dhcp-client,rsync,locales,wget,binutils,ca-certificates,gnupg2"
option="--variant minbase --no-check-gpg"
# Install the base system into a directory 
debootstrap=1
if [ -f ${chroot_dir}/var/log/bootstrap.log ]; then
    if grep "0 added, 0 removed; done." ${chroot_dir}/var/log/bootstrap.log > /dev/null; then
        echo Skipping debootstrap because already exists
        debootstrap=0
    fi
fi
if [ $debootstrap -eq 1 ]; then
    qemu-debootstrap --arch ${arch} ${option} ${include} ${release} ${chroot_dir} ${mirror}
    echo "0 added, 0 removed; done." > ${chroot_dir}/var/log/bootstrap.log
fi

# Use a more complete sources.list file 
cat > ${chroot_dir}/etc/apt/sources.list << EOF
deb ${mirror} bullseye main contrib non-free rpi
# Uncomment line below then 'apt-get update' to enable 'apt-get source'
#deb-src ${mirror} bullseye main contrib non-free rpi
EOF

export DISTRO=debian