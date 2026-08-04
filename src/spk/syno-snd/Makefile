SPK_NAME = syno-snd
SPK_VERS = 1.0
SPK_REV = 12
SPK_ICON = src/$(SPK_NAME).png

DEPENDS = 


UNSUPPORTED_ARCHS = $(OLD_PPC_ARCHS) $(ARMv5_ARCHS)

include ../../mk/spksrc.common.mk

MAINTAINER = RROrg/wjz304
DESCRIPTION = "ALSA sound card driver for Synology NAS"
CHANGELOG = "1. ALSA sound kernel modules (kernel 4.x 5.x) 2. Support HDA Intel, HDMI audio, USB audio, etc."

HOMEPAGE = https://www.kernel.org/
LICENSE  = GPLv2

SPK_DEPENDS = 

WIZARDS_DIR = src/wizard

STARTABLE = yes
SERVICE_SETUP = src/service-setup.sh
SSS_SCRIPT = src/start-stop-status.sh

COPY_TARGET = nop
POST_STRIP_TARGET = syno-snd_strip_target

include ../../mk/spksrc.spk.mk

.PHONY: syno-snd_strip_target
syno-snd_strip_target:
	install -m 755 -d $(STAGING_DIR)/modules/
	cp -r src/modules/* $(STAGING_DIR)/modules/
	find $(STAGING_DIR) -type d -exec chmod 755 {} \;
	find $(STAGING_DIR) -type f -exec chmod 644 {} \;
