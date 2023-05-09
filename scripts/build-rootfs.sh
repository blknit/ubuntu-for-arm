#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${BOARD} ]]; then
    echo "Error: BOARD is not set"
    exit 1
fi

kernel_deb=$(cd ../packages/linux-image-${BOARD}/debian; KDEB_PKGVERSION=$(dpkg-parsechangelog -SVersion -l changelog); source upstream; arch=$(cat arch); echo linux-image-${VERSION}-${BOARD}_${KDEB_PKGVERSION}_${arch}.deb)
uboot_deb=$(cd ../packages/uboot-${BOARD}/debian; KDEB_PKGVERSION=$(dpkg-parsechangelog -SVersion -l changelog); arch=$(cat arch); echo uboot-${BOARD}_${KDEB_PKGVERSION}_${arch}.deb)
kernel_version=$(echo ${kernel_deb} | cut -c 13- | cut -d'_' -f1)
arch=$(echo ${kernel_deb} | cut -d'_' -f3 | cut -d'.' -f1)

if [[ ${LAUNCHPAD} != "Y" ]]; then
    if [ ! -f "$kernel_deb" ]; then
        echo "Error: missing kernel debs, please run build-kernel.sh"
        exit 1
    fi
    if [ ! -f "$uboot_deb" ]; then
        echo "Error: missing u-boot deb, please run build-u-boot.sh"
        exit 1
    fi
fi

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

function chroot_install_kernel_uboot {
    if [[ ${LAUNCHPAD}  == "Y" ]]; then
        chroot ${chroot_dir} /bin/bash -c "apt-get -y install ${kernel_deb} ${uboot_deb}"
    else
        cp ${kernel_deb} ${chroot_dir}/tmp
        chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/${kernel_deb} && rm -rf /tmp/*"

        cp ${uboot_deb} ${chroot_dir}/tmp
        chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/${uboot_deb} && rm -rf /tmp/*"
    fi

    # Finish kernel install
    cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Generate kernel module dependencies
depmod -a ${kernel_version}

# Create kernel and component symlinks
cd /boot 
rm -f initrd.img; ln -s initrd.img-${kernel_version} initrd.img
rm -f System.map; ln -s System.map-${kernel_version} System.map
rm -f vmlinuz; ln -s vmlinuz-${kernel_version} vmlinuz
rm -f config; ln -s config-${kernel_version} config
EOF
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
chroot_install_kernel_uboot

# deinit chroot environment
chroot_deinit

# Tar the entire rootfs
cd ${chroot_dir} && XZ_OPT="-0 -T0" tar -cpJf ../${DISTRO}-preinstalled-server-${arch}-"${BOARD}".rootfs.tar.xz . && cd ..
../scripts/build-image.sh ${DISTRO}-preinstalled-server-${arch}-"${BOARD}".rootfs.tar.xz

# init chroot environment
chroot_init

# Install desktop packages
../scripts/${BOARD}/chroot-install-desktop.sh ${chroot_dir}

# Setup desktop filesystem
../scripts/${BOARD}/chroot-setup-desktop.sh ${chroot_dir}

# deinit chroot environment
chroot_deinit

# Tar the entire rootfs
cd ${chroot_dir} && XZ_OPT="-0 -T0" tar -cpJf ../${DISTRO}-preinstalled-desktop-${arch}-"${BOARD}".rootfs.tar.xz . && cd ..
../scripts/build-image.sh ${DISTRO}-preinstalled-desktop-${arch}-"${BOARD}".rootfs.tar.xz