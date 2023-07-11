#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

cleanup_loopdev() {
    local loop="$1"

    sync --file-system
    sync

    sleep 1

    if [ -b "${loop}" ]; then
        for part in "${loop}"p*; do
            if mnt=$(findmnt -n -o target -S "$part"); then
                umount "${mnt}"
            fi
        done
        losetup -d "${loop}"
    fi
}

wait_loopdev() {
    local loop="$1"
    local seconds="$2"

    until test $((seconds--)) -eq 0 -o -b "${loop}"; do sleep 1; done

    ((++seconds))

    ls -l "${loop}" &> /dev/null
}

if [ -z "$1" ]; then
    echo "Usage: $0 filename.rootfs.tar.xz"
    exit 1
fi

rootfs="$(readlink -f "$1")"
if [[ "$(basename "${rootfs}")" != *".rootfs.tar.xz" || ! -e "${rootfs}" ]]; then
    echo "Error: $(basename "${rootfs}") must be a rootfs tarfile"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p images build && cd build

if [[ -z ${BOARD} ]]; then
    echo "Error: BOARD is not set"
    exit 1
fi

# raspberrypi not support boot from GPT, so use MBR by default 
# GPT=true

# Create an empty disk image
img="../images/$(basename "${rootfs}" .rootfs.tar.xz).img"
size="$(xz -l "${rootfs}" | tail -n +2 | sed 's/,//g' | awk '{print int($5 + 1)}')"
truncate -s "$(( size + 2048 + 512 ))M" "${img}"

# Cleanup loopdev on early exit
trap 'cleanup_loopdev ${loop}' EXIT

# Create loop device for disk image
loop="$(losetup -f)"
if [ -f /.dockerenv ]; then 
    if [ ! -e $loop ]; then 
        loopdev_major=7 # Driver number for loop device node
        loopdev_minor=$(echo ${loop} | tr -dc '0-9')
        mknod ${loop} b ${loopdev_major} ${loopdev_minor} # Manually create block device file with mknod
    fi
fi
losetup "${loop}" "${img}"
disk="${loop}"

partition_char="$(if [[ ${disk: -1} == [0-9] ]]; then echo p; fi)"

if [ -f /.dockerenv ]; then 
    base_sector=2048
    parted -s $disk \
        mklabel msdos \
        mkpart primary fat32 $(expr ${base_sector} \* 1)s $(expr ${base_sector} \* 2 - 1)s \
        mkpart primary fat32 $(expr ${base_sector} \* 2)s $(expr ${base_sector} \* 3 - 1)s \
        mkpart primary fat32 $(expr ${base_sector} \* 3)s $(expr ${base_sector} \* 4 - 1)s \
        mkpart primary fat32 $(expr ${base_sector} \* 4)s $(expr ${base_sector} \* 5 - 1)s

    part_major=259 # Block device extended major number for additional partitions 
    part_minors=( $(lsblk $disk -no MAJ:MIN | grep $part_major | cut -d ':' -f2) )
    for (( i = 0; i < ${#part_minors[@]}; ++i )); do
        partition_file="${disk}${partition_char}$(expr $i + 1)"

        if [ ! -e $partition_file ]; then # If pathname already exists, or is a symbolic link, mknod will fail with an EEXIST error
            mknod $partition_file b $part_major ${part_minors[i]}
        fi
    done

    # Free partitions fdisk can re-partition with the exact extracted partition minor numbers being created here
    parted -s $disk rm 1 rm 2 rm 3 rm 4
fi

# Ensure disk is not mounted
mount_point=/tmp/mnt
umount "${disk}"* 2> /dev/null || true
umount ${mount_point}/* 2> /dev/null || true
mkdir -p ${mount_point}

# Setup partition table
if [ ! -z ${GPT} ]; then
    dd if=/dev/zero of="${disk}" count=4096 bs=512
    parted --script "${disk}" \
    mklabel gpt \
    mkpart primary fat16 16MiB 528MiB \
    mkpart primary ext4 528MiB 100%
else
    dd if=/dev/zero of="${disk}" count=4096 bs=512
    parted --script $disk \
    mklabel msdos \
    mkpart primary fat32 16MiB 528MiB \
    mkpart primary ext4 528MiB 100%
fi


set +e

if [ ! -z ${GPT} ]; then
# Create partitions
fdisk "${disk}" << EOF
t
1
BC13C2FF-59E6-4262-A352-B275FD6F7172
t
2
0FC63DAF-8483-4772-8E79-3D69D8477DE4
w
EOF
else
fdisk $disk << EOF
t
1
c
t
2
83
a
1
w
EOF
fi

set -eE

partprobe "${disk}"

sleep 1

wait_loopdev "${disk}${partition_char}2" 60 || {
    echo "Failure to create ${disk}${partition_char}1 in time"
    exit 1
}

sleep 1

wait_loopdev "${disk}${partition_char}1" 60 || {
    echo "Failure to create ${disk}${partition_char}1 in time"
    exit 1
}

sleep 1

# Generate random uuid for bootfs
boot_uuid=$(uuidgen | head -c8)

# Generate random uuid for rootfs
root_uuid=$(uuidgen)

# Create filesystems on partitions
# mkfs.vfat -i "${boot_uuid}" -F16 -n system-boot "${disk}${partition_char}1"
mkfs.vfat -i "${boot_uuid}" -F32 -n system-boot "${disk}${partition_char}1"
dd if=/dev/zero of="${disk}${partition_char}2" bs=1KB count=10 > /dev/null
mkfs.ext4 -U "${root_uuid}" -L writable "${disk}${partition_char}2"

# Mount partitions
mkdir -p ${mount_point}/{system-boot,writable} 
mount "${disk}${partition_char}1" ${mount_point}/system-boot
mount "${disk}${partition_char}2" ${mount_point}/writable

# Copy the rootfs to root partition
echo -e "Decompressing $(basename "${rootfs}")\n"
tar -xpJf "${rootfs}" -C ${mount_point}/writable

# Set boot args for the splash screen
[ -z "${img##*desktop*}" ] && bootargs="quiet splash plymouth.ignore-serial-consoles" || bootargs=""

# Create fstab entries
boot_uuid="${boot_uuid:0:4}-${boot_uuid:4:4}"
mkdir -p ${mount_point}/writable/boot/firmware
if [ ! -z ${GPT} ]; then
cat > ${mount_point}/writable/etc/fstab << EOF
# <file system>     <mount point>  <type>  <options>   <dump>  <fsck>
UUID=${boot_uuid^^} /boot/firmware vfat    defaults    0       2
UUID=${root_uuid,,} /              ext4    defaults    0       1
/swapfile           none           swap    sw          0       0
EOF

# Uboot env
cat > ${mount_point}/system-boot/ubuntuEnv.txt << EOF
bootargs=root=UUID=${root_uuid} rootfstype=ext4 rootwait rw console=ttyS2,1500000 console=tty1 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 systemd.unified_cgroup_hierarchy=0 ${bootargs}
overlays=
EOF

else
cat > ${mount_point}/writable/etc/fstab << EOF
# <file system>     <mount point>   <type>  <options>   <dump>  <fsck>
LABEL=system-boot   /boot/firmware  vfat    defaults    0       2
LABEL=writable      /               ext4    discard,x-systemd.growfs    0       1
/swapfile           none            swap    sw          0       0
EOF

# Uboot env
cat > ${mount_point}/system-boot/ubuntuEnv.txt << EOF
bootargs=root=LABEL=writable rootfstype=ext4 rootwait rw console=ttyS2,1500000 console=tty1 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 systemd.unified_cgroup_hierarchy=0 ${bootargs}
overlays=
EOF

fi

# Copy uboot script
if [ "${BOARD:0:11}" != "raspberrypi" ]; then
    cp ${mount_point}/writable/boot/boot.cmd ${mount_point}/system-boot
    mkimage -A arm64 -O linux -T script -C none -n "Boot Script" -d "${mount_point}/system-boot/boot.cmd" "${mount_point}/system-boot/boot.scr"
fi

# Copy kernel and initrd to boot partition
../scripts/${BOARD}/copy-kernel-to-image.sh ${mount_point}

# Copy device trees to boot partition
cp -r ${mount_point}/writable/boot/*.dtb ${mount_point}/system-boot

# Copy overlays
if [ -d ${mount_point}/writable/boot/overlays ]; then
    cp -r ${mount_point}/writable/boot/overlays ${mount_point}/system-boot
fi

# Write bootloader to disk image
if [[ "${BOARD}" == radxa-zero ]]; then
    uboot=${mount_point}/writable/boot/u-boot.bin.sd.bin # boot from sd card
    # uboot=${mount_point}/writable/boot/u-boot.bin # boot from emmc
    dd if=${uboot} of="${loop}" conv=fsync,notrunc bs=1 count=444
    dd if=${uboot} of="${loop}" conv=fsync,notrunc bs=512 skip=1 seek=1
elif [[ "${BOARD}" == mangopi-h616 ]]; then
    uboot=${mount_point}/writable/boot/u-boot-sunxi-with-spl.bin
    dd if=/dev/zero of="${loop}" bs=1k count=1023 seek=1 status=noxfer
    dd if=${uboot} of="${loop}" bs=1k seek=8 conv=fsync
elif [[ "${BOARD}" == mangopi-h618 ]]; then
    uboot=${mount_point}/writable/boot/u-boot-sunxi-with-spl.bin
    dd if=/dev/zero of="${loop}" bs=1k count=1023 seek=1 status=noxfer
    dd if=${uboot} of="${loop}" bs=1k seek=8 conv=fsync
else
    cp -r ${mount_point}/writable/boot/{bootcode.bin,cmdline.txt,config.txt} ${mount_point}/system-boot
    cp -r ${mount_point}/writable/boot/*.bin ${mount_point}/system-boot
    cp -r ${mount_point}/writable/boot/*.dat ${mount_point}/system-boot
    cp -r ${mount_point}/writable/boot/*.elf ${mount_point}/system-boot
fi

# Cloud init config for server image
[ -z "${img##*server*}" ] && cp ../overwrite/boot/firmware/{meta-data,user-data,network-config} ${mount_point}/system-boot

sync --file-system
sync

# Umount partitions
umount "${disk}${partition_char}1"
umount "${disk}${partition_char}2"

# Remove loop device
losetup -d "${loop}"

# Remove loop device create in docker
if [ -f /.dockerenv ]; then 
    rm "${disk}"*
fi

# Exit trap is no longer needed
trap '' EXIT

echo -e "\nCompressing $(basename "${img}.xz")\n"
xz -3 --force --keep --quiet --threads=0 "${img}"
rm -f "${img}"
cd ../images && sha256sum "$(basename "${img}.xz")" > "$(basename "${img}.xz.sha256")"