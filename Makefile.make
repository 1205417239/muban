TARGET = iphone:clang:17.5:16.0
ARCHS = arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DynamicXStandardAdjust

DynamicXStandardAdjust_FILES = Tweak.xm
DynamicXStandardAdjust_FRAMEWORKS = UIKit Foundation
DynamicXStandardAdjust_CFLAGS = -fobjc-arc -stdlib=libc++ -Wno-module-import-in-extern-c
DynamicXStandardAdjust_LDFLAGS = -stdlib=libc++

include $(THEOS_MAKE_PATH)/tweak.mk
