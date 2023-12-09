#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if test "$#" -ne 1; then
    echo "Usage: $0 rootfs"
	exit 1
fi

chroot_dir=`readlink -f $@`
overwrite_dir=../overwrite

if [ ! -d ${chroot_dir} ]; then
    echo "Error: missing rootfs directory, please run from build-rootfs.sh"
    exit 1
fi

# Set default HDMI audio as default
echo "set-default-sink alsa_output.platform-hdmi0-sound.stereo-fallback" >> ${chroot_dir}/etc/pulse/default.pa

# Adjust hostname for desktop
echo "localhost.localdomain" > ${chroot_dir}/etc/hostname

# Adjust hosts file for desktop
sed -i 's/127.0.0.1 localhost/127.0.0.1\tlocalhost.localdomain\tlocalhost\n::1\t\tlocalhost6.localdomain6\tlocalhost6/g' ${chroot_dir}/etc/hosts
sed -i 's/::1 ip6-localhost ip6-loopback/::1     localhost ip6-localhost ip6-loopback/g' ${chroot_dir}/etc/hosts
sed -i "/ff00::0 ip6-mcastprefix\b/d" ${chroot_dir}/etc/hosts

# Config file for xorg
mkdir -p ${chroot_dir}/etc/X11/xorg.conf.d
cp ${overwrite_dir}/etc/X11/xorg.conf.d/20-modesetting.conf ${chroot_dir}/etc/X11/xorg.conf.d/20-modesetting.conf

# Networking interfaces
cp ${overwrite_dir}/etc/NetworkManager/NetworkManager.conf ${chroot_dir}/etc/NetworkManager/NetworkManager.conf
cp ${overwrite_dir}/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf ${chroot_dir}/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf
cp ${overwrite_dir}/usr/lib/NetworkManager/conf.d/10-override-wifi-random-mac-disable.conf ${chroot_dir}/usr/lib/NetworkManager/conf.d/10-override-wifi-random-mac-disable.conf
cp ${overwrite_dir}/usr/lib/NetworkManager/conf.d/20-override-wifi-powersave-disable.conf ${chroot_dir}/usr/lib/NetworkManager/conf.d/20-override-wifi-powersave-disable.conf

# Set chromium inital prefrences
mkdir -p ${chroot_dir}/usr/lib/chromium-browser
cp ${overwrite_dir}/usr/lib/chromium-browser/initial_preferences ${chroot_dir}/usr/lib/chromium-browser/initial_preferences

# Set chromium default launch args
mkdir -p ${chroot_dir}/etc/chromium-browser
cp ${overwrite_dir}/etc/chromium-browser/default ${chroot_dir}/etc/chromium-browser/default

# Have plymouth use the framebuffer
mkdir -p ${chroot_dir}/etc/initramfs-tools/conf-hooks.d
cp ${overwrite_dir}/etc/initramfs-tools/conf-hooks.d/plymouth ${chroot_dir}/etc/initramfs-tools/conf-hooks.d/plymouth

# Fix Intel AX210 not working after linux-firmware update
[ -e ${chroot_dir}/usr/lib/firmware/iwlwifi-ty-a0-gf-a0.pnvm ] && mv ${chroot_dir}/usr/lib/firmware/iwlwifi-ty-a0-gf-a0.{pnvm,bak}

# Update initramfs
chroot ${chroot_dir} /bin/bash -c "update-initramfs -u"
