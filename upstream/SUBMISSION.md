# Upstream submission notes

Two independent patches for mainline Linux, extracted from this tree's
kernel patches (board/luckfox/nova/patches/linux/0002 and 0004). They go
to **different subsystems / maintainers**, so send them as two separate
single patches, not a series.

Both were confirmed against `torvalds/master` (2026-06): the usb2phy
delayed works are still only cancelled in `.exit()`, and the rk3308
codec still returns `-EINVAL` for chip version B.

## Before sending (do this in a real kernel tree)

```bash
# rebase onto the right tree, then regenerate so the diffstat/base are real
#   PHY   -> Vinod Koul's phy/next
#   ASoC  -> Mark Brown's sound for-next
git checkout -b rk3308-fixes <base>
git am /path/to/upstream/0001-*.patch        # apply one, build, test, repeat
make drivers/phy/rockchip/ sound/soc/codecs/ # build-test each
scripts/checkpatch.pl --strict 0001-*.patch  # must be clean
scripts/get_maintainer.pl 0001-*.patch       # AUTHORITATIVE To/Cc list
git format-patch -1                           # regenerate with a real hash/base
```

`get_maintainer.pl` on the actual patch is the source of truth for
To/Cc. The lists below are a sanity check only.

## DCO / identity

Both patches sign off as `crackerjacques <jack@supremeoverlordjabs.co>`
(matching your existing Armbian commits). Send from that address so the
From:, Signed-off-by: and send-email envelope all agree. Note kernel DCO
formally expects a real name; this handle matches your other kernel-tree
contributions, so it is consistent, but a maintainer could push back.

## Patch 1 - phy: rockchip-inno-usb2 (USB2 PHY)

File: `0001-phy-rockchip-inno-usb2-cancel-otg-host-delayed-works-on-teardown.patch`

- Bug fix (carries `Fixes: 8dc60f8da22f`), CC stable is reasonable.
- Likely To/Cc (verify with get_maintainer):
  - Vinod Koul <vkoul@kernel.org>
  - Kishon Vijay Abraham I <kishon@kernel.org>
  - Heiko Stuebner <heiko@sntech.de>
  - linux-phy@lists.infradead.org
  - linux-rockchip@lists.infradead.org
  - linux-arm-kernel@lists.infradead.org
  - linux-kernel@vger.kernel.org
- Note for reviewers: `.exit()` already cancels the works, but only on
  PHY power-down; this adds devm cancellation that also covers the
  probe-defer and unbind paths. Armbian already carries an equivalent
  out-of-tree fix (Shlomi Marco), which is independent confirmation but
  is not upstream.

```bash
git send-email \
  --to="Vinod Koul <vkoul@kernel.org>" \
  --cc="Kishon Vijay Abraham I <kishon@kernel.org>" \
  --cc="Heiko Stuebner <heiko@sntech.de>" \
  --cc="linux-phy@lists.infradead.org" \
  --cc="linux-rockchip@lists.infradead.org" \
  --cc="linux-arm-kernel@lists.infradead.org" \
  --cc="linux-kernel@vger.kernel.org" \
  --cc="stable@vger.kernel.org" \
  0001-phy-rockchip-inno-usb2-*.patch
```

## Patch 2 - ASoC: rk3308 (internal codec)

File: `0001-ASoC-rk3308-support-the-RK3308B-codec-variant.patch`

- Feature enablement, **no Fixes tag** (version B was never supported).
- Likely To/Cc (verify with get_maintainer):
  - Luca Ceresoli <luca.ceresoli@bootlin.com>  (rk3308 codec author)
  - Mark Brown <broonie@kernel.org>            (ASoC)
  - Heiko Stuebner <heiko@sntech.de>
  - linux-sound@vger.kernel.org  (and/or alsa-devel@alsa-project.org)
  - linux-rockchip@lists.infradead.org
  - linux-arm-kernel@lists.infradead.org
  - linux-kernel@vger.kernel.org
- Likely review point: Luca may ask whether B needs any of the B-only
  register quirks the vendor driver has (lineout pop, micbias-current,
  detect-grf). Capture works without them; be ready to say playback /
  pop-suppression is untested or to follow up. The mic input-stage gain
  controls (this tree's patch 0005) are a sensible follow-up once this
  lands.

```bash
git send-email \
  --to="Luca Ceresoli <luca.ceresoli@bootlin.com>" \
  --cc="Mark Brown <broonie@kernel.org>" \
  --cc="Heiko Stuebner <heiko@sntech.de>" \
  --cc="linux-sound@vger.kernel.org" \
  --cc="linux-rockchip@lists.infradead.org" \
  --cc="linux-arm-kernel@lists.infradead.org" \
  --cc="linux-kernel@vger.kernel.org" \
  0001-ASoC-rk3308-*.patch
```

## Not being upstreamed (and why)

- 0002 is what becomes Patch 1 above; 0004 becomes Patch 2.
- 0003 / 0006 (Nova DTS audio + PDM) are board-specific; they go via the
  arm-soc / Rockchip DTS path with the board DTS, not here.
- 0005 (mic boost controls) - hold as a follow-up to Patch 2.
