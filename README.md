# Luckfox Nova (RK3308B) buildroot external tree

Fully mainline stack for the Luckfox Nova — **no vendor SDK required**:

- U-Boot **2025.04** (binman; TPL = rkbin DDR blob, BL31 = rkbin ATF) with the
  Nova board patches (SD slot is 1-bit only on this hardware, dw_mmc fixes,
  SARADC recovery key, RockUSB on download key)
- Linux **6.18.y** mainline (or **7.0.y** with `EDGE=1`) + the Nova DTS
  (console ttyS4@1500000, eMMC, microSD 1-bit, 100M ethernet RTL8201F@0,
  USB host/OTG, heartbeat LED) + a fix for a mainline usb2phy
  probe-deferral use-after-free that panicked boot ~2.5s in (100%
  reproducible with PREEMPT_RT)
- On-board mic working through the RK3308**B** internal codec (the
  mainline codec driver rejects version B; patched here), plus the PDM
  digital-mic interface on the P1 header
- Minimal rootfs (dropbear, DHCP on `end0`, root password: `nova`)

## Build

The recommended path is the Docker wrapper (host distro agnostic; rolling
distros like Arch routinely break buildroot's host packages):

```bash
./build.sh           # clones buildroot, builds the container, builds everything
./build.sh menuconfig
./build.sh shell     # poke around inside the build container
EDGE=1 ./build.sh    # mainline 7.0.y kernel instead of 6.18.y longterm
RT=1 ./build.sh      # PREEMPT_RT kernel
DBG=1 ./build.sh     # debugobjects + SLUB poison kernel (debugging only)
HZ=1000 ./build.sh   # kernel tick rate: 100|250|300|1000 (default 250)
JOBS=40 ./build.sh   # per-package make parallelism (default 24)
```

Flags compose (`EDGE=1 RT=1 JOBS=40 ./build.sh`). The wrapper folds them
into a generated defconfig and regenerates `.config` — and dircleans the
kernel when its flavor changed — automatically; no manual `rm .config`
or `linux-dirclean` is ever needed when switching flavors.

Or natively on a stable Linux host:

```bash
git clone https://gitlab.com/buildroot.org/buildroot.git -b 2025.02.x
cd buildroot
make BR2_EXTERNAL=../luckfox-nova-buildroot luckfox_nova_defconfig
make            # first build takes a while (kernel + U-Boot + rootfs)
```

Output: `buildroot/output/images/sdcard.img` and `emmc.img`
(same system, different root PARTUUIDs so SD and eMMC installs can coexist)

## Flash

```bash
# SD card (boots in preference to eMMC; remove the card to boot eMMC again)
sudo dd if=buildroot/output/images/sdcard.img of=/dev/sdX bs=4M conv=fsync

# eMMC (via maskrom/loader mode + Rockchip upgrade_tool)
sudo ./upgrade_tool wl 0 emmc.img && sudo ./upgrade_tool rd
```

## Commands

```bash
novaconfig # activate/deactivate PWM/SPI/I2C util
pwmtest    # test PWM
gpiocheck  # check gpio
mictest    # 10s capture from the on-board mic (mictest 30 / mictest 10 all)
```

## Board variants

This config targets the plain **Luckfox Nova** (no wireless). The **Nova W**
adds an AIC8800-based SDIO WiFi + UART BT module (U1 on the schematic);
supporting it needs the out-of-tree `aic8800_fdrv` driver, firmware blobs,
an SDIO node in the DTS and wpa_supplicant — planned as a separate flavor
(e.g. `W=1 ./build.sh`) so that plain-Nova images stay free of the probe
errors the all-in-one official image throws on boards without the module.

## Mic test

The on-board mic feeds channel 8 of the codec's 8-channel ADC. Mixer
state does not survive a reboot and is left manual by design, so switch
the channel on first:

```bash
amixer -c 0 sset 'MIC8' 100% cap                            # switch on + ALC gain (lower if it clips)
arecord -D mic -r 48000 -f S16_LE -c 1 -d 5 /tmp/t.wav      # mic only, mono
arecord -D hw:0,0 -r 48000 -f S32_LE -c 8 -d 5 /tmp/t8.wav  # all 8 ADC inputs
```

`mic` comes from `/etc/asound.conf` (runs the hardware 8ch/S32 and
extracts channel 8) — picking a single channel is not expressible with
plain `arecord` flags, and low channel counts on `hw:0,0` count up from
MIC1, not the on-board mic. When using `hw:0,0` directly, record
S16_LE or S32_LE: S24_LE arrives MSB-justified on this silicon and
reads 1/256 of the real amplitude.

### PDM digital mics (P1 header)

PDM is disabled by default (the pins are shared with i2s_8ch_0 and
GPIO). Enable it with `novaconfig` -> interfaces -> `pdm` and reboot;
that brings up a `pdm-mics` capture card. Connect a PDM MEMS breakout
to the M2-mux pins:

| breakout | Nova P1 pin |
|----------|-------------|
| CLK      | GPIO2_A6    |
| DAT      | GPIO2_B5 (SDI0) |
| VDD      | 3V3         |
| GND      | GND         |
| SEL/LR   | GND = left, 3V3 = right |

One data line carries a stereo pair, so a single breakout records as 2
channels (`SDI1..3` on GPIO2_B6/B7/C0 add 2 channels each):

```bash
arecord -l                                              # pdm-mics is card 1
arecord -D hw:1,0 -r 48000 -f S32_LE -c 2 -d 10 /tmp/pdm.wav
```

The PDM pins are shared (mux) with the i2s_8ch_0 controller and plain
GPIO on P1 — only one of those functions can use them at a time. The
on-board analog mic (separate codec) is unaffected.

## Kernel patches

Applied from `board/luckfox/nova/patches/linux{,-edge}/` (the two dirs
track the 6.18.y and 7.0.y trees). 0002, 0004 and 0005 are not Nova-
specific and are upstream candidates.

| # | patch | why |
|---|-------|-----|
| 0001 | add luckfox-nova DTS | the board itself |
| 0002 | phy-rockchip-inno-usb2: cancel delayed works on probe failure | fixes a probe-deferral use-after-free that left an armed timer in freed memory → boot panic ~2.5s in (100% with RT) |
| 0003 | luckfox-nova: enable audio | internal codec + i2s_8ch_2 simple-card; sets `#sound-dai-cells` (missing in rk3308.dtsi) and routes MICBIAS2 so the mic is powered |
| 0004 | ASoC rk3308: accept the RK3308B codec | drop the mainline `-EINVAL` on chip version B (B uses the version-A register layout) |
| 0005 | ASoC rk3308: expose mic input-stage gain | adds `MICx Boost` controls (PGA 0/+6.6/+13/+20 dB), left at 0 dB default |
| 0006 | luckfox-nova: add PDM | adds the PDM controller node (absent in rk3308.dtsi) + dmic-codec card, disabled by default, toggled by `novaconfig` |

## Notes

- **The microSD slot only has DAT0 usable** (verified on hardware with two
  cards; 4-bit data transfers fail in both U-Boot and Linux). Everything runs
  1-bit at SD High Speed — do not "fix" bus-width back to 4.
- Kernel point releases are pinned in `build.sh` (`KVER` for 6.18.y,
  `KVER_EDGE` for 7.0.y); the native non-Docker path uses the pin in
  `configs/luckfox_nova_defconfig` instead. Bump them as the series
  advance.
- Don't enable boot-time timer tracepoints (`trace_event=timer:...`) on
  the 7.0.y + PREEMPT_RT combination — it hangs at ~0.009s before SMP
  bringup (6.18.y is fine with the same arguments). Unresolved, see
  f8f9baf.
- `board/luckfox/nova/rkbin/` vendors the two Rockchip blobs (DDR init + BL31)
  from <https://github.com/rockchip-linux/rkbin> (redistributable per its
  LICENSE). No other vendor bits are used.
- The fixed root `PARTUUID` is set in `genimage.cfg` and must match
  `extlinux.conf`. Distinct from Armbian images, so an Armbian eMMC system and
  this SD image can coexist without UUID collisions.
- U-Boot boot order is SD first (`boot_targets=mmc1 mmc0`), so the SD card
  wins whenever inserted; this matches the Armbian setup on the same board.
