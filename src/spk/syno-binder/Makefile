SPK_NAME = syno-binder
SPK_VERS = 1.0
SPK_REV = 1
SPK_ICON = src/$(SPK_NAME).png

DEPENDS = 


UNSUPPORTED_ARCHS = $(OLD_PPC_ARCHS) $(ARMv5_ARCHS)

include ../../mk/spksrc.common.mk

MAINTAINER = RROrg/wjz304
DESCRIPTION = "Binder/Ashmem driver for Synology NAS"
CHANGELOG = "Binder is a Linux kernel module that allows processes to communicate with each other using shared memory. It is used to implement inter-process communication IPC in Android and other operating systems."

HOMEPAGE = https://www.kernel.org/
LICENSE  = GPLv2

SPK_DEPENDS = 

WIZARDS_DIR = src/wizard

STARTABLE = yes
SERVICE_SETUP = src/service-setup.sh
SSS_SCRIPT = src/start-stop-status.sh

COPY_TARGET = nop
POST_STRIP_TARGET = syno-binder_strip_target

include ../../mk/spksrc.spk.mk

.PHONY: syno-binder_strip_target
syno-binder_strip_target:
#	install -m 755 -d $(STAGING_DIR)/firmware/
#	cp -r src/firmware/* $(STAGING_DIR)/firmware/
	install -m 755 -d $(STAGING_DIR)/modules/
	cp -r src/modules/* $(STAGING_DIR)/modules/
#	install -m 755 -d $(STAGING_DIR)/udev/
#	cp -r src/udev/* $(STAGING_DIR)/udev/
	find $(STAGING_DIR) -type d -exec chmod 755 {} \;
	find $(STAGING_DIR) -type f -exec chmod 644 {} \;
#	find $(STAGING_DIR)/udev -type f -name "*.sh" -exec chmod 755 {} \;
