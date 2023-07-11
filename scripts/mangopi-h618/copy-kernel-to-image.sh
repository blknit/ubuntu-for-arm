#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if test "$#" -ne 1; then
    echo "Usage: $0 /tmp/mnt"
	exit 1
fi

mount_point=`readlink -f $@`

cp ${mount_point}/writable/boot/initrd.img-*-mangopi-h618 ${mount_point}/system-boot/initrd.img
cp ${mount_point}/writable/boot/vmlinuz-*-mangopi-h618 ${mount_point}/system-boot/vmlinuz