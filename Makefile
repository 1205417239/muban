TARGET = iphone:clang:16.5:16.0
ARCHS = arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DynamicXStandardAdjust

DynamicXStandardAdjust_FILES = Tweak.xm
DynamicXStandardAdjust_FRAMEWORKS = UIKit Foundation
DynamicXStandardAdjust_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
