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
    debootstrap --arch ${arch} ${option} ${include} ${release} ${chroot_dir} ${mirror}
    echo "0 added, 0 removed; done." > ${chroot_dir}/var/log/bootstrap.log
fi

# Use a more complete sources.list file 
cat > ${chroot_dir}/etc/apt/sources.list << EOF
deb ${mirror} bullseye main contrib non-free rpi
# Uncomment line below then 'apt-get update' to enable 'apt-get source'
#deb-src ${mirror} bullseye main contrib non-free rpi
EOF

# Download the raspberry pi firmware
if [ ! -d firmware ]; then
    mkdir -p firmware
    wget -c http://archive.raspberrypi.org/debian/pool/main/r/raspberrypi-firmware/raspberrypi-firmware_1.20230306.orig.tar.xz -q -O - | sudo tar --strip-components=2 -xJ -C firmware
fi

# Board specific changes put here
cp firmware/*.dat ${chroot_dir}/boot/
cp firmware/*.elf ${chroot_dir}/boot/
cp firmware/bcm2708-*.dtb ${chroot_dir}/boot/
cp firmware/bcm2710-*.dtb ${chroot_dir}/boot/
cp firmware/bcm2711-*.dtb ${chroot_dir}/boot/
cp firmware/bootcode.bin ${chroot_dir}/boot/
cp -r firmware/overlays ${chroot_dir}/boot/

cat > ${chroot_dir}/boot/cmdline.txt << EOF
console=serial0,115200 dwc_otg.lpm_enable=0 console=tty1 root=LABEL=writable rootfstype=ext4 rootwait fixrtc quiet splash
EOF

# Setup config.txt file
cat > ${chroot_dir}/boot/config.txt << EOF
[pi0]
kernel=vmlinuz-v6
initramfs initrd-v6.img followkernel

[pi1]
kernel=vmlinuz-v6
initramfs initrd-v6.img followkernel

[pi2]
kernel=vmlinuz-v7
initramfs initrd-v7.img followkernel

[pi3]
kernel=vmlinuz-v7
initramfs initrd-v7.img followkernel

[pi02]
kernel=vmlinuz-v7
initramfs initrd-v7.img followkernel

[pi4]
kernel=vmlinuz-v7l
initramfs initrd-v7l.img followkernel

[all]
# Enable the audio output, I2C and SPI interfaces on the GPIO header. As these
# parameters related to the base device-tree they must appear *before* any
# other dtoverlay= specification
dtparam=audio=on
dtparam=i2c_arm=on
dtparam=spi=on

# Comment out the following line if the edges of the desktop appear outside
# the edges of your display
disable_overscan=1

# If you have issues with audio, you may try uncommenting the following line
# which forces the HDMI output into HDMI mode instead of DVI (which doesn't
# support audio output)
#hdmi_drive=2

[cm4]
# Enable the USB2 outputs on the IO board (assuming your CM4 is plugged into
# such a board)
dtoverlay=dwc2,dr_mode=host

[all]
cmdline=cmdline.txt

# Enable the KMS ("full" KMS) graphics overlay, leaving GPU memory as the
# default (the kernel is in control of graphics memory with full KMS)
dtoverlay=vc4-kms-v3d

# Autoload overlays for any recognized cameras or displays that are attached
# to the CSI/DSI ports. Please note this is for libcamera support, *not* for
# the legacy camera stack
camera_auto_detect=1
display_auto_detect=1

# Config settings specific to arm64
dtoverlay=dwc2

# Enable 4' screen (https://www.amazon.com/Miuzei-Raspberry-Full-Angle-Heatsinks-Raspbian/dp/B07XBVF1C9)co
# uncomment following configuration
# hdmi_group=2
# hdmi_mode=87
# display_rotate=3
# hdmi_cvt 480 800 60 6 0 0 0
EOF

export DISTRO=debian-11