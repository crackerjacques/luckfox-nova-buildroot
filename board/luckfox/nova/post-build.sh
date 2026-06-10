#!/bin/sh
# Install the extlinux boot menu into the rootfs (U-Boot distro boot reads
# /boot/extlinux/extlinux.conf from partition 1).
set -e

BOARD_DIR="$(dirname "$0")"

mkdir -p "${TARGET_DIR}/boot/extlinux"
install -m 0644 "${BOARD_DIR}/extlinux.conf" "${TARGET_DIR}/boot/extlinux/extlinux.conf"
