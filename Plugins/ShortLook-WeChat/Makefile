TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ShortLook-WeChat

ShortLook-WeChat_FILES = WeChatContactPhotoProvider.m
ShortLook-WeChat_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
ShortLook-WeChat_FRAMEWORKS = Foundation UIKit
ShortLook-WeChat_LIBRARIES = sqlite3
ShortLook-WeChat_INSTALL_PATH = /Library/Dynastic/ShortLook/Plugins/ContactPhotoProviders

include $(THEOS_MAKE_PATH)/bundle.mk
