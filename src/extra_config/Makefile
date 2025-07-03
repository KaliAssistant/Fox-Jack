KCONFIG_CONFIG ?= .config
DEFCONFIG ?= foxjack_defconfig
KBUILD_CONF := $(shell which kconfig-conf || which conf)
KBUILD_MENUCONFIG := $(shell which kconfig-mconf || which menuconfig)
GEN_SCRIPT := ./gen.sh


.PHONY: all menuconfig defconfig clean

all:
	@echo "Use: make defconfig → make menuconfig"
	@$(GEN_SCRIPT) $(KCONFIG_CONFIG)
# Load defaults from defconfig into .config
defconfig:
	KCONFIG_CONFIG=$(KCONFIG_CONFIG) $(KBUILD_CONF) --defconfig=$(DEFCONFIG) Config.in

# Edit .config with GUI
menuconfig:
	KCONFIG_CONFIG=$(KCONFIG_CONFIG) $(KBUILD_MENUCONFIG) Config.in

savedefconfig:
	KCONFIG_CONFIG=$(KCONFIG_CONFIG) $(KBUILD_CONF) --savedefconfig=$(DEFCONFIG) Config.in

# Do not touch defconfig; only clean .config
clean:
	rm -f .config .config.old
	rm -rf ../out/extra_config
	echo > ../out/rmtab
