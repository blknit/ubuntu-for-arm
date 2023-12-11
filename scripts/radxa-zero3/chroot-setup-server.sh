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

# Swapfile
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

dd if=/dev/zero of=/tmp/swapfile bs=1024 count=2097152
chmod 600 /tmp/swapfile
mkswap /tmp/swapfile
mv /tmp/swapfile /swapfile
EOF

# DNS
cp ${overwrite_dir}/etc/resolv.conf ${chroot_dir}/etc/resolv.conf

# Hostname
cp ${overwrite_dir}/etc/hostname ${chroot_dir}/etc/hostname

# Hosts file
cp ${overwrite_dir}/etc/hosts ${chroot_dir}/etc/hosts

# Serial console resize script
cp ${overwrite_dir}/etc/profile.d/resize.sh ${chroot_dir}/etc/profile.d/resize.sh

# Enable rc-local
cp ${overwrite_dir}/etc/rc.local ${chroot_dir}/etc/rc.local

# Cloud init config
cp ${overwrite_dir}/etc/cloud/cloud.cfg.d/99-fake_cloud.cfg ${chroot_dir}/etc/cloud/cloud.cfg.d/99-fake_cloud.cfg

# Default adduser config
cp ${overwrite_dir}/etc/adduser.conf ${chroot_dir}/etc/adduser.conf

# Realtek 8811CU/8821CU usb modeswitch support
cp ${chroot_dir}/lib/udev/rules.d/40-usb_modeswitch.rules ${chroot_dir}/etc/udev/rules.d/40-usb_modeswitch.rules
sed '/LABEL="modeswitch_rules_end"/d' -i ${chroot_dir}/etc/udev/rules.d/40-usb_modeswitch.rules
cat >> ${chroot_dir}/etc/udev/rules.d/40-usb_modeswitch.rules <<EOF
# Realtek 8811CU/8821CU Wifi AC USB
ATTR{idVendor}=="0bda", ATTR{idProduct}=="1a2b", RUN+="/usr/sbin/usb_modeswitch -K -v 0bda -p 1a2b"

LABEL="modeswitch_rules_end"
EOF

# Expand root filesystem on first boot
mkdir -p ${chroot_dir}/usr/lib/scripts
cp ${overwrite_dir}/usr/lib/scripts/resize-filesystem.sh ${chroot_dir}/usr/lib/scripts/resize-filesystem.sh
cp ${overwrite_dir}/usr/lib/systemd/system/resize-filesystem.service ${chroot_dir}/usr/lib/systemd/system/resize-filesystem.service
chroot ${chroot_dir} /bin/bash -c "systemctl enable resize-filesystem"

# Set term for serial tty
mkdir -p ${chroot_dir}/lib/systemd/system/serial-getty@.service.d
cp ${overwrite_dir}/usr/lib/systemd/system/serial-getty@.service.d/10-term.conf ${chroot_dir}/usr/lib/systemd/system/serial-getty@.service.d/10-term.conf

# Use gzip compression for the initrd
cp ${overwrite_dir}/etc/initramfs-tools/conf.d/compression.conf ${chroot_dir}/etc/initramfs-tools/conf.d/compression.conf

# Remove release upgrade motd
rm -f ${chroot_dir}/var/lib/ubuntu-release-upgrader/release-upgrade-available
cp ${overwrite_dir}/etc/update-manager/release-upgrades ${chroot_dir}/etc/update-manager/release-upgrades

# Let systemd create machine id on first boot
rm -f ${chroot_dir}/var/lib/dbus/machine-id
true > ${chroot_dir}/etc/machine-id 

# Fix Intel AX210 not working after linux-firmware update
[ -e ${chroot_dir}/usr/lib/firmware/iwlwifi-ty-a0-gf-a0.pnvm ] && mv ${chroot_dir}/usr/lib/firmware/iwlwifi-ty-a0-gf-a0.{pnvm,bak}

# Board specific changes put here

# Update initramfs
chroot ${chroot_dir} /bin/bash -c "update-initramfs -u"
