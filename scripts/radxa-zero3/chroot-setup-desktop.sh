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

# Setup and configure oem installer
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

addgroup --gid 29999 oem || true
adduser --gecos "OEM Configuration (temporary user)" --add_extra_groups --disabled-password --gid 29999 --uid 29999 oem || true
usermod -a -G adm,sudo -p "$(date +%s | sha256sum | base64 | head -c 32)" oem

apt-get -y install --no-install-recommends oem-config-slideshow-ubuntu oem-config \
oem-config-gtk ubiquity-frontend-gtk ubiquity-ubuntu-artwork ubiquity 

mkdir -p /var/log/installer
touch /var/log/{syslog,installer/debug}
oem-config-prepare --quiet

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
EOF

# Set gstreamer environment variables
cp ${overwrite_dir}/etc/profile.d/gst.sh ${chroot_dir}/etc/profile.d/gst.sh

# Set cogl to use gles2
cp ${overwrite_dir}/etc/profile.d/cogl.sh ${chroot_dir}/etc/profile.d/cogl.sh

# Set qt to use wayland
cp ${overwrite_dir}/etc/profile.d/qt.sh ${chroot_dir}/etc/profile.d/qt.sh

# Config file for mpv
cp ${overwrite_dir}/etc/mpv/mpv.conf ${chroot_dir}/etc/mpv/mpv.conf

# Use mpv as the default video player
sed -i 's/org\.gnome\.Totem\.desktop/mpv\.desktop/g' ${chroot_dir}/usr/share/applications/gnome-mimeapps.list 

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

# Enable wayland session
cp ${overwrite_dir}/etc/gdm3/custom.conf ${chroot_dir}/etc/gdm3/custom.conf

# Set chromium inital prefrences
mkdir -p ${chroot_dir}/usr/lib/chromium-browser
cp ${overwrite_dir}/usr/lib/chromium-browser/initial_preferences ${chroot_dir}/usr/lib/chromium-browser/initial_preferences

# Set chromium default launch args
mkdir -p ${chroot_dir}/etc/chromium-browser
cp ${overwrite_dir}/etc/chromium-browser/default ${chroot_dir}/etc/chromium-browser/default

# Set chromium as default browser
chroot ${chroot_dir} /bin/bash -c "update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/chromium-browser 500"
chroot ${chroot_dir} /bin/bash -c "update-alternatives --set x-www-browser /usr/bin/chromium-browser"
sed -i 's/firefox-esr\.desktop/chromium-browser\.desktop/g;s/firefox\.desktop;//g' ${chroot_dir}/usr/share/applications/gnome-mimeapps.list 

# Add chromium to favorites bar
mkdir -p ${chroot_dir}/etc/dconf/db/local.d
cp ${overwrite_dir}/etc/dconf/db/local.d/00-favorite-apps ${chroot_dir}/etc/dconf/db/local.d/00-favorite-apps
cp ${overwrite_dir}/etc/dconf/profile/user ${chroot_dir}/etc/dconf/profile/user
chroot ${chroot_dir} /bin/bash -c "dconf update"

# Have plymouth use the framebuffer
mkdir -p ${chroot_dir}/etc/initramfs-tools/conf-hooks.d
cp ${overwrite_dir}/etc/initramfs-tools/conf-hooks.d/plymouth ${chroot_dir}/etc/initramfs-tools/conf-hooks.d/plymouth

# Fix Intel AX210 not working after linux-firmware update
[ -e ${chroot_dir}/usr/lib/firmware/iwlwifi-ty-a0-gf-a0.pnvm ] && mv ${chroot_dir}/usr/lib/firmware/iwlwifi-ty-a0-gf-a0.{pnvm,bak}

# Update initramfs
chroot ${chroot_dir} /bin/bash -c "update-initramfs -u"
