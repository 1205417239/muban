export THEOS := /var/mobile/theos

TARGET = iphone:clang:16.5:16.0
ARCHS = arm64e
THEOS_PACKAGE_SCHEME = rootless

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DynamicXStandardAdjust
DynamicXStandardAdjust_FILES = Tweak.xm
DynamicXStandardAdjust_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
