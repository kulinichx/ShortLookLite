TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = FloraSettings

FloraSettings_FILES = DDBaseSettingsController.m DDSettingsController.m DDSettingsSubController.m DDSettingsNavigationTitleView.m UIColor+EasyDynamic.m
FloraSettings_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
FloraSettings_FRAMEWORKS = UIKit CoreGraphics
FloraSettings_PRIVATE_FRAMEWORKS = Preferences
FloraSettings_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
