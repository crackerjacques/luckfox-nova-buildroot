################################################################################
#
# aic8800dc  -  AICSemi AIC8800DC SDIO WiFi driver for the Luckfox Nova W
#
################################################################################

AIC8800DC_VERSION = b4e4a49137f08eab403770d323274fd95514c830
AIC8800DC_SITE = https://github.com/crackerjacques/AIC8800DC
AIC8800DC_SITE_METHOD = git
AIC8800DC_LICENSE = GPL-2.0

# The kbuild tree lives under drivers/aic8800 (recurses into aic_load_fw +
# aic8800_fdrv).
AIC8800DC_MODULE_SUBDIRS = drivers/aic8800

# The repo is an AX300 USB-dongle driver by default; the Nova W module is
# SDIO, so flip the bus before building.
define AIC8800DC_FLIP_TO_SDIO
	$(SED) 's/^CONFIG_SDIO_SUPPORT[[:space:]]*=.*/CONFIG_SDIO_SUPPORT = y/; \
	        s/^CONFIG_USB_SUPPORT[[:space:]]*=.*/CONFIG_USB_SUPPORT = n/' \
		$(@D)/drivers/aic8800/aic8800_fdrv/Makefile
endef
AIC8800DC_PRE_CONFIGURE_HOOKS += AIC8800DC_FLIP_TO_SDIO

# DC firmware + boot-time module load (this rootfs has no module autoloader).
define AIC8800DC_INSTALL_EXTRA
	mkdir -p $(TARGET_DIR)/lib/firmware/aic8800DC
	cp -rf $(@D)/fw/aic8800DC/* $(TARGET_DIR)/lib/firmware/aic8800DC/
	mkdir -p $(TARGET_DIR)/etc/modprobe.d
	printf 'options aic_load_fw aic_fw_path=/lib/firmware\n' \
		> $(TARGET_DIR)/etc/modprobe.d/aic8800dc.conf
endef
AIC8800DC_POST_INSTALL_TARGET_HOOKS += AIC8800DC_INSTALL_EXTRA

define AIC8800DC_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(AIC8800DC_PKGDIR)/S35aic8800dc \
		$(TARGET_DIR)/etc/init.d/S35aic8800dc
endef

$(eval $(kernel-module))
$(eval $(generic-package))
