#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

kernel_dirs=(../packages/linux-image-raspberrypi-armv7 ../packages/linux-image-raspberrypi-armv7l) 

for kernel_dir in ${kernel_dirs[@]}; do
    kernel_deb=$(cd ${kernel_dir}/debian; KDEB_PKGVERSION=$(dpkg-parsechangelog -SVersion -l changelog); source upstream; echo linux-image-${VERSION}-raspberrypi_${KDEB_PKGVERSION}_armhf.deb)
    export kernel_debs+=( ${kernel_deb} )
    export kernel_versions+=( $(echo ${kernel_deb} | cut -c 13- | cut -d'_' -f1) )
done

if [[ ${LAUNCHPAD} != "Y" ]]; then
    for kernel_deb in ${kernel_debs[@]}; do
        if [ ! -f "$kernel_deb" ]; then
            echo "Error: missing kernel deb(${kernel_deb}), please run build-kernel.sh"
            exit 1
        fi
    done
fi

function chroot_install_kernel_uboot {
    chroot_dir=`readlink -f $@`

    if [ ! -d ${chroot_dir} ]; then
        echo "Error: missing rootfs directory, please run from build-rootfs.sh"
        exit 1
    fi

    if [[ ${LAUNCHPAD}  == "Y" ]]; then
        for kernel_deb in ${kernel_debs[@]}; do
            chroot ${chroot_dir} /bin/bash -c "apt-get -y install ${kernel_deb}"
        done
    else
        for kernel_deb in ${kernel_debs[@]}; do
            cp ${kernel_deb} ${chroot_dir}/tmp
            chroot ${chroot_dir} /bin/bash -c "dpkg -i --force-overwrite /tmp/${kernel_deb} && rm -rf /tmp/*"
        done
    fi

    cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Generate kernel module dependencies
depmod -a ${kernel_versions[0]}
depmod -a ${kernel_versions[1]}

# Create kernel and component symlinks
cd /boot 
rm -f initrd-v7.img; ln -s initrd.img-${kernel_versions[0]} initrd-v7.img
rm -f System-v7.map; ln -s System.map-${kernel_versions[0]} System-v7.map
rm -f vmlinuz-v7; ln -s vmlinuz-${kernel_versions[0]} vmlinuz-v7
rm -f config-v7; ln -s config-${kernel_versions[0]} config-v7

rm -f initrd-v7l.img; ln -s initrd.img-${kernel_versions[1]} initrd-v7l.img
rm -f System-v7l.map; ln -s System.map-${kernel_versions[1]} System-v7l.map
rm -f vmlinuz-v7l; ln -s vmlinuz-${kernel_versions[1]} vmlinuz-v7l
rm -f config-v7l; ln -s config-${kernel_versions[1]} config-v7l
EOF
}