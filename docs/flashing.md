# Flashing the Luckfox Nova (Windows / Linux / macOS)

Two images come out of a build:

| image | target | how |
|-------|--------|-----|
| `buildroot/output/images/sdcard.img` | microSD card | write to the card, boot with the card inserted |
| `buildroot/output/images/emmc.img`   | on-board eMMC | Rockchip maskrom/loader tool over USB-C |

The SD card wins the boot order whenever inserted, so SD is the safe way
to try an image without touching the eMMC. Remove the card to boot eMMC
again.

> Note: the **stock Luckfox image cannot boot from SD** — only images
> from this tree (or Armbian) boot from the card.

---

## 1. microSD card (`sdcard.img`)

### Easiest, all three OSes: balenaEtcher / Raspberry Pi Imager
[balenaEtcher](https://etcher.balena.io/) runs on Windows, macOS and
Linux: *Flash from file* → pick `sdcard.img` → pick the card → Flash.
Raspberry Pi Imager works too (*Use custom* → select the .img). Both
handle unmounting and verification for you — recommended if you are not
comfortable on the command line.

### Windows (command line: Rufus or dd)
- **Rufus** (GUI): SELECT → `sdcard.img` (set filter to *All files*) →
  START → *DD Image mode* if prompted.
- Or **Raspberry Pi Imager** / **balenaEtcher** as above.

Avoid Win32DiskImager with mixed-content images; Rufus/Etcher are safer.

### Linux
```bash
lsblk                                   # find the card, e.g. /dev/sdX or /dev/mmcblkN
sudo dd if=buildroot/output/images/sdcard.img of=/dev/sdX bs=4M conv=fsync status=progress
sync
```
`of=` must be the **whole disk** (`/dev/sdb`, `/dev/mmcblk0`), not a
partition (`/dev/sdb1`). Double-check with `lsblk` before pressing enter —
the wrong device wipes your disk.

`bmaptool copy sdcard.img /dev/sdX` is faster if you have it; GNOME Disks
("Restore Disk Image") is a GUI option.

### macOS
```bash
diskutil list                           # find the card, e.g. /dev/disk4
diskutil unmountDisk /dev/disk4
sudo dd if=buildroot/output/images/sdcard.img of=/dev/rdisk4 bs=4m
sync
```
Use the **raw** node `/dev/rdiskN` (not `/dev/diskN`) — it is far faster.
`diskutil list` again after to confirm; eject with
`diskutil eject /dev/disk4`. Ctrl-T during dd shows progress.

---

## 2. On-board eMMC (`emmc.img`)

eMMC is written over USB-C while the SoC is in **maskrom/loader mode**,
using a Rockchip tool. No SD card involved.

### Enter maskrom mode
Follow Luckfox's "Enter the MaskRom Mode" (section 4.2):
<https://wiki.luckfox.com/Luckfox-Nova/Flash-image/>
Briefly: hold the download/recovery key, plug USB-C into the host, release.
The board should enumerate as a Rockchip device (`2207:...`).

### Linux
Two tools work; pick one.

`rkdeveloptool` (open source):
```bash
sudo rkdeveloptool ld                    # should list a Maskrom/Loader device
sudo rkdeveloptool wl 0 buildroot/output/images/emmc.img
sudo rkdeveloptool rd                    # reboot
```

or the Rockchip `upgrade_tool` (from rkbin / the Luckfox SDK):
```bash
sudo ./upgrade_tool wl 0 emmc.img && sudo ./upgrade_tool rd
```

If `ld` shows nothing: check the USB-C cable (must be data-capable), that
you are really in maskrom mode, and add a udev rule / use sudo.

### Windows
Use Rockchip's **RKDevTool** (GUI, from the Luckfox wiki/SDK):
1. Install the Rockchip USB driver (`DriverAssistant`) so the board shows
   as *Maskrom* device.
2. RKDevTool → *Upgrade Firmware* / *Advanced Function* → load `emmc.img`
   → write. (For a single combined image use *Upgrade*; for raw use the
   write-by-address fields.)

### macOS
`rkdeveloptool` builds/install via Homebrew:
```bash
brew install rkdeveloptool        # or build from github.com/rockchip-linux/rkdeveloptool
rkdeveloptool ld
rkdeveloptool wl 0 emmc.img
rkdeveloptool rd
```
RKDevTool (the GUI) is Windows-only; on macOS use `rkdeveloptool`.

---

## 3. Rolling back to the stock Luckfox firmware

Enter maskrom mode (4.2 above), then write the official image with the
Rockchip tool, exactly like the eMMC step but pointing at Luckfox's `.img`:
```bash
sudo ./upgrade_tool uf Luckfox-xxx-xxx.img    # or: sudo ./rkflash.sh update
```
See <https://wiki.luckfox.com/Luckfox-Nova/Flash-image/>.

---

## Troubleshooting

- **Board won't boot after SD write**: confirm you wrote to the whole
  disk, not a partition, and that the card is seated. The SD slot is
  1-bit only on this hardware (handled in the image) — a stock image that
  assumes 4-bit will not boot.
- **maskrom device not detected**: bad/charge-only USB-C cable is the
  usual cause; also verify the key/timing and (Windows) the Rockchip
  driver.
- **`dd` is slow on macOS**: use `/dev/rdiskN`, not `/dev/diskN`.
- **Verify a card after writing**: re-insert and check the partition
  shows up (`lsblk` / `diskutil list`); the rootfs is ext4.
