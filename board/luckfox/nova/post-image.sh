#!/bin/sh
# Assemble the final images with genimage:
#   sdcard.img - rootfs PARTUUID 8b3258a1-...e301
#   emmc.img   - rootfs PARTUUID d3a8f2b6-...e302
# Distinct PARTUUIDs so a buildroot SD card and a buildroot eMMC system can
# coexist; U-Boot prefers SD (boot_targets=mmc1 mmc0) when both are present.
set -e

BOARD_DIR="$(dirname "$0")"

SD_UUID="8b3258a1-71e1-4f60-9f4a-6ab0c5a4e301"
EMMC_UUID="d3a8f2b6-4c71-4e2a-9b58-2f90c1d4e302"

# --- SD image: rootfs.ext4 as built (extlinux already points at SD_UUID) ---
support/scripts/genimage.sh -c "${BOARD_DIR}/genimage.cfg"

# --- eMMC image: same rootfs, extlinux patched to the eMMC PARTUUID --------
cp "${BINARIES_DIR}/rootfs.ext4" "${BINARIES_DIR}/rootfs-emmc.ext4"

sed "s/${SD_UUID}/${EMMC_UUID}/" "${BOARD_DIR}/extlinux.conf" \
    > "${BUILD_DIR}/extlinux-emmc.conf"

cat > "${BUILD_DIR}/debugfs-emmc.cmd" <<EOF
rm /boot/extlinux/extlinux.conf
cd /boot/extlinux
write ${BUILD_DIR}/extlinux-emmc.conf extlinux.conf
EOF
debugfs -w -f "${BUILD_DIR}/debugfs-emmc.cmd" "${BINARIES_DIR}/rootfs-emmc.ext4"

support/scripts/genimage.sh -c "${BOARD_DIR}/genimage-emmc.cfg"
