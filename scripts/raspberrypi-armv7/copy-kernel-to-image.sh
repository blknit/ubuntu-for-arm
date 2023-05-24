#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if test "$#" -ne 1; then
    echo "Usage: $0 /tmp/mnt"
	exit 1
fi

mount_point=`readlink -f $@`

cp -L ${mount_point}/writable/boot/{initrd-v7.img,initrd-v7l.img} ${mount_point}/system-boot/
cp -L ${mount_point}/writable/boot/{vmlinuz-v7,vmlinuz-v7l} ${mount_point}/system-boot/