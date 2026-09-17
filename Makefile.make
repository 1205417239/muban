ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = KayokoLite
KayokoLite_FILES = Tweak/Kayoko.xm
KayokoLite_CFLAGS = -fobjc-arc
KayokoLite_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
