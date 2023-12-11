# This is a boot script for U-Boot
#
# Recompile with:
# mkimage -A arm64 -O linux -T script -C none -n "Boot Script" -d boot.cmd boot.scr

echo "Boot script loaded from ${devtype} ${devnum}"

# set boot device and partition
setenv devtype mmc
setenv devnum 1
setenv distro_bootpart 1
setenv bootargs "console=serial0,115200 dwc_otg.lpm_enable=0 console=tty1 root=LABEL=writable rootfstype=ext4 rootwait fixrtc quiet splash"

# set boot arguments
setenv load_addr "0x32000000"
setenv kernel_addr_r "0x34000000"
setenv fdt_addr_r "0x4080000"

# reload kernel arguments required
if test -e ${devtype} ${devnum}:${distro_bootpart} /ubuntuEnv.txt; then
	load ${devtype} ${devnum}:${distro_bootpart} ${load_addr} /ubuntuEnv.txt
	env import -t ${load_addr} ${filesize}
fi

# parameter for spi dev
setenv param_spidev_spi_bus "0"
setenv param_spidev_max_freq "10000000"

echo bootargs=${bootargs}

# load fdt
load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} meson-g12a-radxa-zero.dtb

# load fixup
fdt addr ${fdt_addr_r}
fdt resize 65536

echo "Applying overlay meson-g12a-uart-ao-a-on-gpioao-0-gpioao-1.dtbo"
load ${devtype} ${devnum}:${distro_bootpart} ${load_addr} overlays/meson-g12a-uart-ao-a-on-gpioao-0-gpioao-1.dtbo
fdt apply ${load_addr}

echo "Applying overlay meson-g12a-spi-spidev.dtbo"
load ${devtype} ${devnum}:${distro_bootpart} ${load_addr} overlays/meson-g12a-spi-spidev.dtbo
fdt apply ${load_addr}

if load ${devtype} ${devnum}:${distro_bootpart} ${load_addr} overlays/meson-fixup.scr; then
    echo "Applying kernel provided DT fixup script (overlay/meson-fixup.scr)"
    source ${load_addr}
fi

echo "load kernel"
load ${devtype} ${devnum}:${distro_bootpart} ${ramdisk_addr_r} vmlinuz
unzip ${ramdisk_addr_r} ${kernel_addr_r}

echo "load initrd"
load ${devtype} ${devnum}:${distro_bootpart} ${ramdisk_addr_r} initrd.img

echo "booting"
booti ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr_r}
