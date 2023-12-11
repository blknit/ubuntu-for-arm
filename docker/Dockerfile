# Use ubuntu base
FROM ubuntu:22.04 

# Prevent dpkg interactive dialogues
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    bc \
    binfmt-support \
    bison \
    build-essential \
    cpio \
    debootstrap \
    device-tree-compiler \
    dosfstools \
    fakeroot \
    fdisk \
    flex \
    gcc-aarch64-linux-gnu \
    git-lfs \
    kmod \
    libssl-dev \
    parted \
    python-is-python3 \
    python2 \
    python2-dev \
    python3 \
    python3-dev \
    python3-pyelftools \
    python3-setuptools \
    qemu-efi \
    qemu-system-arm \
    qemu-user-static \
    rsync \
    u-boot-tools \
    udev \
    uuid-runtime \
    xz-utils \
    curl \
    swig \
    && curl https://bootstrap.pypa.io/pip/2.7/get-pip.py | python2 && python2 -m pip install pyelftools==0.29 setuptools \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /opt
