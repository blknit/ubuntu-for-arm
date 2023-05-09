## Overview

This repository provides a pre-installed Ubuntu 22.04 desktop/server image for the [radxa-zero](https://wiki.radxa.com/Zero), [Raspberrypi-zero-w](https://www.raspberrypi.com/products/raspberry-pi-zero/), [Raspberrypi-zero-2](https://www.raspberrypi.com/products/raspberry-pi-zero-2-w/), [Raspberrypi-3b+](https://www.raspberrypi.com/products/raspberry-pi-3-model-b-plus/) and [Raspberrypi-4b](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/), offering a default Ubuntu experience. With this port, you can experience the power and stability of Ubuntu on your Raspberry Pi, making it an excellent choice for a wide range of projects and applications. 

This device is still new and undergoing continuous development. As a result, you may encounter bugs or missing features. I'll do my best to update this project with the most recent changes and fixes. If you find problems, please report them in the issues section, and I will be happy to assist!

<img src="https://images.prismic.io/rpf-products/3a15d4da-46e3-4940-8be6-9fc7d201affe_RPi_4B_FEATURED.jpg?ixlib=gatsbyFP&auto=compress%2Cformat&fit=max&w=600&h=400" width="400">

## Highlights

* Package management via apt using the official Ubuntu repositories
* Receive kernel, firmware, and bootloader updates through apt
* Desktop first-run wizard for user setup and configuration
* Uses the 5.15.92 Linux kernel

## Prepare an SD Card

Make sure you use a good, reliable, and fast SD card. For example, suppose you encounter boot or stability troubles. Most of the time, this is due to either an insufficient power supply or related to your SD card (bad card, bad card reader, something went wrong when burning the image, or the card is too slow).

## Boot the System

Insert your SD card into the slot on the board and power on the device. The first boot may take up to two minutes, so please be patient.

## Login Information

For the server image you will be able to login through HDMI or a serial console connection. The predefined user is `ubuntu` and the password is `ubuntu`.

For the desktop image you must connect through HDMI and follow the setup-wizard.

## Build Requirements

To to set up the build environment, please use a Ubuntu 22.04 machine, then install the below packages:

```
sudo apt-get install -y build-essential gcc-aarch64-linux-gnu bison \
qemu-user-static qemu-system-arm qemu-efi u-boot-tools binfmt-support \
debootstrap flex libssl-dev bc rsync kmod cpio xz-utils fakeroot parted \
udev dosfstools uuid-runtime git-lfs device-tree-compiler python2 python3 \
python-is-python3 fdisk curl
```

## Building

To checkout the source and build:

```
git clone https://github.com/blknit/ubuntu-for-arm.git
cd ubuntu-for-arm
# build for raspberry zero 2, 3b+, 4b
sudo ./build.sh --board=raspberrypi-arm64
# build for raspberry zero w
sudo ./build.sh --board=raspberrypi-armhf
# build for radxa zero
sudo ./build.sh --board=radxa zero
```

## Known Limitations

1. 