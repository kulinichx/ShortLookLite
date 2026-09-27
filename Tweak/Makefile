TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ShortLook

ShortLook_FILES = Tweak.x $(wildcard *.m)
ShortLook_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function
ShortLook_FRAMEWORKS = UIKit CoreGraphics QuartzCore Contacts UserNotifications

include $(THEOS_MAKE_PATH)/tweak.mk
