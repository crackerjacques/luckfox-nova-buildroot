# Luckfox Nova (RK3308B) buildroot external tree

Fully mainline stack for the Luckfox Nova — **no vendor SDK required**:

- U-Boot **2025.04** (binman; TPL = rkbin DDR blob, BL31 = rkbin ATF) with the
  Nova board patches (SD slot is 1-bit only on this hardware, dw_mmc fixes,
  SARADC recovery key, RockUSB on download key)
- Linux **6.18.y** mainline + the Nova DTS (console ttyS4@1500000, eMMC,
  microSD 1-bit, 100M ethernet RTL8201F@0, USB host/OTG, heartbeat LED)
- Minimal rootfs (dropbear, DHCP on `end0`, root password: `nova`)

## Build (on a Linux host)

```bash
git clone https://gitlab.com/buildroot.org/buildroot.git -b 2025.02.x
git clone <this repo> luckfox-nova-buildroot

cd buildroot
make BR2_EXTERNAL=../luckfox-nova-buildroot luckfox_nova_defconfig
make            # first build takes a while (kernel + U-Boot + rootfs)
```

Output: `output/images/sdcard.img`

## Flash

```bash
# SD card (boots in preference to eMMC; remove the card to boot eMMC again)
sudo dd if=output/images/sdcard.img of=/dev/sdX bs=4M conv=fsync

# eMMC (via maskrom/loader mode + Rockchip upgrade_tool)
sudo ./upgrade_tool wl 0 sdcard.img && sudo ./upgrade_tool rd
```

## Notes

- **The microSD slot only has DAT0 usable** (verified on hardware with two
  cards; 4-bit data transfers fail in both U-Boot and Linux). Everything runs
  1-bit at SD High Speed — do not "fix" bus-width back to 4.
- Kernel point release is pinned in `configs/luckfox_nova_defconfig`
  (`BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE`) — bump as 6.18.y advances.
- `board/luckfox/nova/rkbin/` vendors the two Rockchip blobs (DDR init + BL31)
  from <https://github.com/rockchip-linux/rkbin> (redistributable per its
  LICENSE). No other vendor bits are used.
- The fixed root `PARTUUID` is set in `genimage.cfg` and must match
  `extlinux.conf`. Distinct from Armbian images, so an Armbian eMMC system and
  this SD image can coexist without UUID collisions.
- U-Boot boot order is SD first (`boot_targets=mmc1 mmc0`), so the SD card
  wins whenever inserted; this matches the Armbian setup on the same board.
