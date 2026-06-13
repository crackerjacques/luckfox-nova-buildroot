################################################################################
#
# aic8800dc  -  AICSemi AIC8800DC SDIO WiFi driver for the Luckfox Nova W
#
################################################################################

# Fork of LYU4662/aic8800-sdio-linux-1.0 (SDIO-native, DC, bsp+fdrv+btlpm)
# with the kernel 6.16+ / cfg80211 compat fixups committed in-tree, so no
# external patches are needed and the source can't disappear upstream.
AIC8800DC_VERSION = 2ef197fb6771b0852f544b19c60eac22ccd65e4b
AIC8800DC_SITE = https://github.com/crackerjacques/aic8800-sdio-linux-1.0
AIC8800DC_SITE_METHOD = git
AIC8800DC_LICENSE = GPL-2.0

# Top Makefile builds aic8800_bsp + aic8800_fdrv (+ btlpm) via obj-m.
AIC8800DC_MODULE_SUBDIRS = .

# - BT (btlpm) is not wired up on the Nova yet -> don't build it.
# - point the firmware path at where we install the DC blobs.
define AIC8800DC_TUNE_BUILD
	$(SED) 's/^CONFIG_AIC8800_BTLPM_SUPPORT[[:space:]]*:=.*/CONFIG_AIC8800_BTLPM_SUPPORT := n/' \
		$(@D)/Makefile
	$(SED) 's@^CONFIG_AIC_FW_PATH[[:space:]]*?=.*@CONFIG_AIC_FW_PATH ?= "/lib/firmware/aic8800_sdio/aic8800DC"@' \
		$(@D)/aic8800_bsp/Makefile
endef
AIC8800DC_PRE_CONFIGURE_HOOKS += AIC8800DC_TUNE_BUILD

# Firmware + a modprobe.d fallback fw-path option (this rootfs has no module
# autoloader; the S35 script loads the modules at boot).
define AIC8800DC_INSTALL_EXTRA
	mkdir -p $(TARGET_DIR)/lib/firmware/aic8800_sdio
	cp -rf $(@D)/firmware/aic8800_sdio/* $(TARGET_DIR)/lib/firmware/aic8800_sdio/
	mkdir -p $(TARGET_DIR)/etc/modprobe.d
	printf 'options aic8800_bsp aic_fw_path=/lib/firmware/aic8800_sdio/aic8800DC\n' \
		> $(TARGET_DIR)/etc/modprobe.d/aic8800dc.conf
endef
AIC8800DC_POST_INSTALL_TARGET_HOOKS += AIC8800DC_INSTALL_EXTRA

define AIC8800DC_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(AIC8800DC_PKGDIR)/S35aic8800dc \
		$(TARGET_DIR)/etc/init.d/S35aic8800dc
endef

$(eval $(kernel-module))
$(eval $(generic-package))
