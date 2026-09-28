TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = roothide
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ShortLook-TikTok

ShortLook-TikTok_FILES = TikTokContactPhotoProvider.m
ShortLook-TikTok_CFLAGS = -fobjc-arc -I../Common
ShortLook-TikTok_FRAMEWORKS = Foundation UIKit
ShortLook-TikTok_INSTALL_PATH = /Library/Dynastic/ShortLook/Plugins/ContactPhotoProviders

include $(THEOS_MAKE_PATH)/bundle.mk
