TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ShortLook-QQ

ShortLook-QQ_FILES = QQContactPhotoProvider.m
ShortLook-QQ_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
ShortLook-QQ_FRAMEWORKS = Foundation UIKit
ShortLook-QQ_INSTALL_PATH = /Library/Dynastic/ShortLook/Plugins/ContactPhotoProviders

include $(THEOS_MAKE_PATH)/bundle.mk
