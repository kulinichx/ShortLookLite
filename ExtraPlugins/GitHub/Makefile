TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = roothide
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ShortLook-GitHub

ShortLook-GitHub_FILES = GitHubProfilePictureProvider.m
ShortLook-GitHub_CFLAGS = -fobjc-arc -I../Common
ShortLook-GitHub_FRAMEWORKS = Foundation UIKit
ShortLook-GitHub_INSTALL_PATH = /Library/Dynastic/ShortLook/Plugins/ContactPhotoProviders

include $(THEOS_MAKE_PATH)/bundle.mk
