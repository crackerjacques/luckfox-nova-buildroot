#!/bin/sh
# Install the extlinux boot menu into the rootfs (U-Boot distro boot reads
# /boot/extlinux/extlinux.conf from partition 1).
set -e

BOARD_DIR="$(dirname "$0")"

mkdir -p "${TARGET_DIR}/boot/extlinux"
install -m 0644 "${BOARD_DIR}/extlinux.conf" "${TARGET_DIR}/boot/extlinux/extlinux.conf"

# Authoritative network config: ifupdown-scripts only regenerates its file on
# package rebuild (BR2_SYSTEM_DHCP changes don't propagate), and without udev
# there is no end0 rename - the interface is plain eth0.
cat > "${TARGET_DIR}/etc/network/interfaces" <<'EOF'
# interface file managed by board/luckfox/nova/post-build.sh

auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
  pre-up /etc/network/nfs_check
  wait-delay 15
  hostname $(hostname)
EOF
