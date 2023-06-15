#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [[ -z ${BOARD} ]]; then
    echo "Error: BOARD is not set"
    exit 1
fi

kernel_dir=../packages/linux-image-${BOARD}
uboot_dir=../packages/uboot-${BOARD}

export kernel_deb=$(cd ${kernel_dir}/debian; KDEB_PKGVERSION=$(dpkg-parsechangelog -SVersion -l changelog); source upstream; arch=$(cat arch); echo linux-image-${VERSION}-raspberrypi_${KDEB_PKGVERSION}_arm64.deb)
export kernel_version=$(echo ${kernel_deb} | cut -c 13- | cut -d'_' -f1)

if [[ ${LAUNCHPAD} != "Y" ]]; then
    if [ ! -f "$kernel_deb" ]; then
        echo "Error: missing kernel debs(${kernel_deb}), please run build-kernel.sh"
        exit 1
    fi
fi

function chroot_install_kernel_uboot {
    chroot_dir=`readlink -f $@`

    if [ ! -d ${chroot_dir} ]; then
        echo "Error: missing rootfs directory, please run from build-rootfs.sh"
        exit 1
    fi

    if [[ ${LAUNCHPAD}  == "Y" ]]; then
        chroot ${chroot_dir} /bin/bash -c "apt-get -y install ${kernel_deb} ${uboot_deb}"
    else
        cp ${kernel_deb} ${chroot_dir}/tmp
        chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/${kernel_deb} && rm -rf /tmp/*"
    fi

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