#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${BOARD} ]]; then
    echo "Error: BOARD is not set"
    exit 1
fi

if [ "${BOARD}" == raspberrypi-armv6 ]; then
    [ -d cross-pi-gcc-10.3.0-0 ] || wget -qO- --content-disposition -c  'https://sourceforge.net/projects/raspberry-pi-cross-compilers/files/Raspberry Pi GCC Cross-Compiler Toolchains/Bullseye/GCC 10.3.0/Raspberry Pi 1, Zero/cross-gcc-10.3.0-pi_0-1.tar.gz' | tar xvz -C .
    export PATH=$(pwd)/cross-pi-gcc-10.3.0-0/bin:$PATH
fi

if [ "${BOARD}" == raspberrypi-armv6 ]; then
    package_dirs=(linux-image-raspberrypi-armv6 linux-image-raspberrypi-armv7 linux-image-raspberrypi-armv7l)
elif [ "${BOARD}" == raspberrypi-armv7 ]; then
    package_dirs=(linux-image-raspberrypi-armv7 linux-image-raspberrypi-armv7l)
elif [ "${BOARD}" == raspberrypi-armv8 ]; then
    package_dirs=linux-image-raspberrypi-armv8
else
    package_dirs=linux-image-${BOARD}
fi

source ../scripts/utils.sh
for package_dir in "${package_dirs[@]}"; do
    source ../packages/"${package_dir}"/debian/upstream
    mkdir -p "${package_dir}"
    cd "${package_dir}"

    if [ ! -d .git ]; then
        git_source "${GIT}" "${COMMIT}"
        cp -r ../../packages/"${package_dir}"/debian .

        # Apply all patches
        if [ -d "debian/patches" ]; then
            git apply debian/patches/*.patch
        fi
    fi
    dpkg-buildpackage -a "$(cat debian/arch)" -d -b -nc -uc
    cd ..

    rm -f *.buildinfo *.changes linux-libc-dev*

    unset PATH
    source /etc/environment
    export PATH
done