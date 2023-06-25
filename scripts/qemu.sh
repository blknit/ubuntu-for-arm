#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

if test "$#" -ne 1; then
    echo "Usage: $0 filename.img.xz"
    exit 1
fi

img="$(readlink -f "$1")"
if [ ! -f "${img}" ]; then
    echo "Error: $1 does not exist"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build && mkdir -p qemu/mnts

# Decompress xz archive
filename="$(basename "${img}")"
if [ "${filename##*.}" == "xz" ]; then
    xz -dc -T0 "${img}" > "${img%.*}"
    img="$(readlink -f "${img%.*}")"
fi

# Ensure img file
filename="$(basename "${img}")"
if [ "${filename##*.}" != "img" ]; then
    echo "Error: ${filename} must be an disk image file"
    exit 1
fi

# Fetch arch and board
desktop=$(echo ${filename} | awk -F- '{print $4}')
board=$(echo ${filename} | awk -F- '{print $5}')
arch=$(echo ${filename} | awk -F- '{print $6}' | awk -F. '{print $1}')

# Setup kernel/initrd/devicetree
if [ ${board} = "raspberrypi" ]; then
    if [ ${arch} = "armv6" ] || [ ${arch} = "armv7" ]; then

        # Prepare kernel/initrd/devicetree
        if [ ! -d qemu/kernel ]; then
            git clone --progress --depth=1 https://github.com/blknit/qemu-rpi-kernel.git ./qemu/kernel
        fi

        # Start qemu parameters (QEMU emulator version 4.2.1 (Debian 1:4.2-3ubuntu6.26))
        qemu-system-arm \
        -machine versatilepb \
        -cpu arm1176 \
        -m 256 \
        -dtb qemu/kernel/versatile-pb-buster-5.4.51.dtb \
        -kernel qemu/kernel/kernel-qemu-5.4.51-buster \
        -append 'root=/dev/vda2 panic=1' \
        -drive file="${img}",if=none,index=0,media=disk,format=raw,id=disk0 \
        -device virtio-blk-pci,drive=disk0,disable-modern=on,disable-legacy=off \
        -net user,hostfwd=tcp::5022-:22 \
        -no-reboot 

    elif [ ${arch} = "armv8" ]; then

        # Setup block loop device
        loop="$(losetup -f)"
        losetup "${loop}" "${img}"
        partprobe "${loop}"
        # Mount loop device
        mount_point=qemu/mnts
        mkdir -p ${mount_point}/{boot,root}
        umount ${loop}* 2> /dev/null || true
        umount ${mount_point}/* 2> /dev/null || true
        mount "${loop}"p1 ${mount_point}/boot
        # copy kernel initrd dtb file
        cp -r ${mount_point}/boot qemu/
        # clean
        umount ${loop}* 2> /dev/null || true
        umount ${mount_point}/* 2> /dev/null || true
        losetup -d ${loop}

        qemu-system-aarch64 \
        -smp 4 \
        -m 1G \
        -machine raspi3 \
        -cpu cortex-a72 \
        -dtb qemu/boot/bcm2710-rpi-3-b-plus.dtb \
        -kernel qemu/boot/vmlinuz-v8 \
        -initrd qemu/boot/initrd-v8.img \
        -sd "${img}" \
        -append "rw earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootdelay=1"

    fi
fi

############
## Method 1:

#     # Resize image
#     qemu-img resize ${img} 16G
#     # Setup block loop device
#     loop="$(losetup -f)"
#     losetup "${loop}" "${img}"
#     partprobe "${loop}"
#     # Mount loop device
#     mount_point=qemu/mnts
#     mkdir -p ${mount_point}/{boot,root}
#     umount ${loop}* 2> /dev/null || true
#     umount ${mount_point}/* 2> /dev/null || true
#     mount "${loop}"p1 ${mount_point}/boot
#     mount "${loop}"p2 ${mount_point}/root
#     # Extract grub arm64-efi to host system 
#     if [ ! -d "/usr/lib/grub/arm64-efi" ]; then
#         rm -f /usr/lib/grub/arm64-efi
#         ln -s ${mount_point}/root/usr/lib/grub/arm64-efi /usr/lib/grub/arm64-efi
#     fi
#     # Install grub
#     mkdir -p ${mount_point}/boot/efi/boot
#     mkdir -p ${mount_point}/boot/boot/grub
#     grub-install --target=arm64-efi --efi-directory=${mount_point}/boot --boot-directory=${mount_point}/boot/boot --removable --recheck
#     # Grub config
#     cat > ${mount_point}/boot/boot/grub/grub.cfg << EOF
# insmod gzio
# set background_color=black
# set default=0
# set timeout=10
# GRUB_RECORDFAIL_TIMEOUT=
# menuentry 'Boot' {
# search --no-floppy --label --set=root system-boot
# linux /vmlinuz-v8 root=LABEL=writable console=serial0,115200 console=tty1 rootfstype=ext4 rootwait rw
# initrd /initrd-v8.img
# }
# EOF
#     # clean
#     umount ${loop}* 2> /dev/null || true
#     umount ${mount_point}/* 2> /dev/null || true
#     losetup -d ${loop}
#
# # For emulated VMs (e.g. x86 host)
# qemu-system-aarch64 \
# -smp 8 \
# -m 4G \
# -machine virt \
# -cpu cortex-a72 \
# -device qemu-xhci \
# -device usb-kbd \
# -device usb-mouse \
# -device virtio-gpu-pci \
# -device virtio-net-pci,netdev=vnet \
# -device virtio-rng-pci,rng=rng0 \
# -device virtio-blk,drive=drive0,bootindex=0 \
# -netdev user,id=vnet,hostfwd=:127.0.0.1:0-:22 \
# -object rng-random,filename=/dev/urandom,id=rng0 \
# -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
# -drive file="${img}",format=raw,if=none,id=drive0,cache=writeback

############
## Method 2:

# require qemu verion 5.1+
# https://www.qemu.org/docs/master/system/arm/raspi.html
# raspi0 raspi1ap : ARM1176JZF-S core, 512 MiB of RAM
# raspi2b  : Cortex-A7 (4 cores), 1 GiB of RAM
# raspi3ap : Cortex-A53 (4 cores), 512 MiB of RAM
# raspi3b  : Cortex-A53 (4 cores), 1 GiB of RAM
# raspi4b2g  : Cortex-A72 (4 cores), 2 GiB of RAM

# qemu-system-aarch64 \
#    -machine raspi3b \
#    -cpu cortex-a72 \
#    -dtb boot/bcm2710-rpi-3-b-plus.dtb \
#    -m 1G -smp 4 -serial stdio \
#    -kernel ./kernel-v8 \
#    -initrd boot/initrd-v8.img \
#    -sd ../../images/ubuntu-22.04.2-preinstalled-desktop-raspberrypi-armv8.img,format=raw \
#    -append "rw earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootdelay=1"