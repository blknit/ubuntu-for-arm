#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${BOARD} ]]; then
    echo "Error: BOARD is not set"
    exit 1
fi

source ../scripts/${BOARD}/chroot-install-kernel-uboot.sh
chroot_dir=rootfs

function chroot_init {
    # These env vars can cause issues with chroot
    unset TMP
    unset TEMP
    unset TMPDIR

    # Clean chroot dir and make sure folder is not mounted
    umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
    umount -lf ${chroot_dir}/* 2> /dev/null || true

    # Mount the temporary API filesystems
    mkdir -p ${chroot_dir}/{proc,sys,run,dev,dev/pts}
    mount -t proc /proc ${chroot_dir}/proc
    mount -t sysfs /sys ${chroot_dir}/sys
    mount -o bind /dev ${chroot_dir}/dev
    mount -o bind /dev/pts ${chroot_dir}/dev/pts
}

function chroot_deinit {
    # Umount the temporary API filesystems
    umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
    umount -lf ${chroot_dir}/* 2> /dev/null || true
}

# Clean chroot dir and make sure folder is not mounted
chroot_deinit
rm -rf ${chroot_dir}
mkdir -p ${chroot_dir}

# Debootstrap base filesystem into directory 
source ../scripts/${BOARD}/debootstrap.sh ${chroot_dir}

# init chroot environment
chroot_init

# Install server packages
../scripts/${BOARD}/chroot-install-server.sh ${chroot_dir}

# Setup server filesystem
../scripts/${BOARD}/chroot-setup-server.sh ${chroot_dir}

# Install kernel and uboot
chroot_install_kernel_uboot ${chroot_dir}

# deinit chroot environment
chroot_deinit

# Tar the entire rootfs
cd ${chroot_dir} && XZ_OPT="-0 -T0" tar -cpJf ../${DISTRO}-preinstalled-server-"${BOARD}".rootfs.tar.xz . && cd ..
../scripts/build-image.sh ${DISTRO}-preinstalled-server-"${BOARD}".rootfs.tar.xz

# init chroot environment
chroot_init

# Install desktop packages
../scripts/${BOARD}/chroot-install-desktop.sh ${chroot_dir}

# Setup desktop filesystem
../scripts/${BOARD}/chroot-setup-desktop.sh ${chroot_dir}

# deinit chroot environment
chroot_deinit

# Tar the entire rootfs
cd ${chroot_dir} && XZ_OPT="-0 -T0" tar -cpJf ../${DISTRO}-preinstalled-desktop-"${BOARD}".rootfs.tar.xz . && cd ..
../scripts/build-image.sh ${DISTRO}-preinstalled-desktop-"${BOARD}".rootfs.tar.xz