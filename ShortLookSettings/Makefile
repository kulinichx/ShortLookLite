TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ShortLookSettings

ShortLookSettings_FILES = ShortLookSettings.m
ShortLookSettings_CFLAGS = -fobjc-arc
# Like the original, the bundle links FloraSettings so DDSettingsController (its principal class) is loaded.
# libFloraSettings.tbd points at @loader_path/../FloraSettings.bundle/FloraSettings, which works rootful and roothide.
ShortLookSettings_LDFLAGS = -L. -lFloraSettings
ShortLookSettings_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
