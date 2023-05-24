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
release=jammy
mirror=http://ports.ubuntu.com/ubuntu-ports

# Install the base system into a directory 
debootstrap=1
if [ -f ${chroot_dir}/var/log/bootstrap.log ]; then
    if grep "0 added, 0 removed; done." ${chroot_dir}/var/log/bootstrap.log > /dev/null; then
        echo Skipping debootstrap because already exists
        debootstrap=0
    fi
fi
if [ $debootstrap -eq 1 ]; then
    debootstrap --arch ${arch} ${release} ${chroot_dir} ${mirror}
fi

# Use a more complete sources.list file 
cat > ${chroot_dir}/etc/apt/sources.list << EOF
# See http://help.ubuntu.com/community/UpgradeNotes for how to upgrade to
# newer versions of the distribution.
deb ${mirror} ${release} main restricted
# deb-src ${mirror} ${release} main restricted

## Major bug fix updates produced after the final release of the
## distribution.
deb ${mirror} ${release}-updates main restricted
# deb-src ${mirror} ${release}-updates main restricted

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team. Also, please note that software in universe WILL NOT receive any
## review or updates from the Ubuntu security team.
deb ${mirror} ${release} universe
# deb-src ${mirror} ${release} universe
deb ${mirror} ${release}-updates universe
# deb-src ${mirror} ${release}-updates universe

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team, and may not be under a free licence. Please satisfy yourself as to
## your rights to use the software. Also, please note that software in
## multiverse WILL NOT receive any review or updates from the Ubuntu
## security team.
deb ${mirror} ${release} multiverse
# deb-src ${mirror} ${release} multiverse
deb ${mirror} ${release}-updates multiverse
# deb-src ${mirror} ${release}-updates multiverse

## N.B. software from this repository may not have been tested as
## extensively as that contained in the main release, although it includes
## newer versions of some applications which may provide useful features.
## Also, please note that software in backports WILL NOT receive any review
## or updates from the Ubuntu security team.
deb ${mirror} ${release}-backports main restricted universe multiverse
# deb-src ${mirror} ${release}-backports main restricted universe multiverse

deb ${mirror} ${release}-security main restricted
# deb-src ${mirror} ${release}-security main restricted
deb ${mirror} ${release}-security universe
# deb-src ${mirror} ${release}-security universe
deb ${mirror} ${release}-security multiverse
# deb-src ${mirror} ${release}-security multiverse
EOF

# Download the raspberry pi firmware
if [ ! -d firmware ]; then
    mkdir -p firmware
    wget -c http://archive.raspberrypi.org/debian/pool/main/r/raspberrypi-firmware/raspberrypi-firmware_1.20230306.orig.tar.xz -q -O - | sudo tar --strip-components=2 -xJ -C firmware
fi

# Board specific changes put here
cp firmware/*.dat ${chroot_dir}/boot/
cp firmware/*.elf ${chroot_dir}/boot/
cp firmware/bcm2710-*.dtb ${chroot_dir}/boot/
cp firmware/bcm2711-*.dtb ${chroot_dir}/boot/
cp firmware/bootcode.bin ${chroot_dir}/boot/
cp -r firmware/overlays ${chroot_dir}/boot/

cat > ${chroot_dir}/boot/cmdline.txt << EOF
console=serial0,115200 dwc_otg.lpm_enable=0 console=tty1 root=LABEL=writable rootfstype=ext4 rootwait fixrtc quiet splash
EOF

# Setup config.txt file
cat > ${chroot_dir}/boot/config.txt << EOF
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

[pi4]
max_framebuffers=2
arm_boost=1

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

# Setup boot.cmd file
cat > ${chroot_dir}/boot/boot.cmd << EOF
# This is a boot script for U-Boot
#
# Recompile with:
# mkimage -A arm -O linux -T script -C none -n "Boot Script" -d boot.cmd boot.scr

echo "Boot script loaded from ${devtype} ${devnum}"

if test -e ${devtype} ${devnum}:${distro_bootpart} /ubuntuEnv.txt; then
	load ${devtype} ${devnum}:${distro_bootpart} ${load_addr} /ubuntuEnv.txt
	env import -t ${load_addr} ${filesize}
fi

load ${devtype} ${devnum}:${distro_bootpart} ${ramdisk_addr_r} /vmlinuz
unzip ${ramdisk_addr_r} ${kernel_addr_r}
load ${devtype} ${devnum}:${distro_bootpart} ${ramdisk_addr_r} /initrd.img

booti ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr}
EOF

export DISTRO=ubuntu-22.04.2