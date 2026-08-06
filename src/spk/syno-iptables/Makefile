SPK_NAME = syno-iptables
SPK_VERS = 1.0
SPK_REV = 12
SPK_ICON = src/$(SPK_NAME).png

DEPENDS = 


UNSUPPORTED_ARCHS = $(OLD_PPC_ARCHS) $(ARMv5_ARCHS)

include ../../mk/spksrc.common.mk

MAINTAINER = RROrg/wjz304
DESCRIPTION = "iptables/netfilter kernel modules for Synology NAS"
CHANGELOG = "1. iptables/netfilter kernel modules (kernel 4.x 5.x) 2. Support iptable_filter, iptable_nat, iptable_mangle, etc."

HOMEPAGE = https://www.kernel.org/
LICENSE  = GPLv2

SPK_DEPENDS = 

WIZARDS_DIR = src/wizard

STARTABLE = yes
SERVICE_SETUP = src/service-setup.sh
SSS_SCRIPT = src/start-stop-status.sh

COPY_TARGET = nop
POST_STRIP_TARGET = syno-iptables_strip_target

include ../../mk/spksrc.spk.mk

.PHONY: syno-iptables_strip_target
syno-iptables_strip_target:
	@if [ -d src/firmware ]; then \
		install -m 755 -d $(STAGING_DIR)/firmware/; \
		cp -r src/firmware/* $(STAGING_DIR)/firmware/; \
	fi
	@if [ -d src/modules ]; then \
		install -m 755 -d $(STAGING_DIR)/modules/; \
		cp -r src/modules/* $(STAGING_DIR)/modules/; \
	fi
	@if [ -d src/udev ]; then \
		install -m 755 -d $(STAGING_DIR)/udev/; \
		cp -r src/udev/* $(STAGING_DIR)/udev/; \
	fi
	find $(STAGING_DIR) -type d -exec chmod 755 {} \;
	find $(STAGING_DIR) -type f -exec chmod 644 {} \;
	@if [ -d $(STAGING_DIR)/udev ]; then \
		find $(STAGING_DIR)/udev -type f -name "*.sh" -exec chmod 755 {} \;; \
	fi
