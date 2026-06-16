#!/bin/sh
# Install the extlinux boot menu into the rootfs (U-Boot distro boot reads
# /boot/extlinux/extlinux.conf from partition 1).
set -e

BOARD_DIR="$(dirname "$0")"

mkdir -p "${TARGET_DIR}/boot/extlinux"
install -m 0644 "${BOARD_DIR}/extlinux.conf" "${TARGET_DIR}/boot/extlinux/extlinux.conf"

# Recompile the board DTB with symbols (dtc -@) so U-Boot can apply overlays
# that reference base-DTB labels (novaconfig i2s_rx). This kernel does not emit
# a /__symbols__ node for base DTBs (no OF_OVERLAY rule in scripts/Makefile.lib,
# CONFIG_OF_OVERLAY alone does nothing), so rebuild it from the preprocessed
# source - which still carries the labels - with the kernel's own dtc.
DTS_TMP="$(ls -t "${BUILD_DIR}"/linux-*/arch/arm64/boot/dts/rockchip/.rk3308-luckfox-nova.dtb.dts.tmp 2>/dev/null | head -n1)"
if [ -n "${DTS_TMP}" ] && [ -f "${TARGET_DIR}/boot/rk3308-luckfox-nova.dtb" ]; then
	DTC="${DTS_TMP%/arch/*}/scripts/dtc/dtc"
	[ -x "${DTC}" ] || DTC=dtc
	"${DTC}" -@ -q -I dts -O dtb \
		-o "${TARGET_DIR}/boot/rk3308-luckfox-nova.dtb" "${DTS_TMP}"
	echo "post-build: rebuilt rk3308-luckfox-nova.dtb with /__symbols__ (dtc -@)"
fi

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
