TARGET = iphone:clang:17.5:16.0
ARCHS = arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DynamicXStandardAdjust

DynamicXStandardAdjust_FILES = Tweak.xm
DynamicXStandardAdjust_CFLAGS = -fobjc-arc -Wno-objc-method-access

include $(THEOS_MAKE_PATH)/tweak.mk
