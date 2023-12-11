#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${BOARD} ]]; then
    echo "Error: BOARD is not set"
    exit 1
fi

if [ "${BOARD:0:11}" == "raspberrypi" ]; then
    exit 0
fi

source ../scripts/utils.sh
package_dir=uboot-${BOARD}
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

# Compile u-boot into a deb package
dpkg-buildpackage -a "$(cat debian/arch)" -d -b -nc -uc

rm -f ../*.buildinfo ../*.changes